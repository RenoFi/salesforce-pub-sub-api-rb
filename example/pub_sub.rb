require 'thread'
require 'avro'
require 'grpc'
require 'faraday'
require 'certifi'
require 'ruby-limiter'
require_relative '../proto/pubsub_api_services_pb.rb'

class PubSub
  extend Limiter::Mixin

  attr_accessor :current_pending_events, :lock
  attr_reader :url,:metadata, :stub, :access_token, :topic_name

  limit_method :fetch_request, rate: 60, balanced: true

  def initialize
    @url = ENV.fetch('SF_HOST')
    @grpc_host = ENV.fetch('PUBSUB_HOST')
    @grpc_port = ENV.fetch('PUBSUB_PORT')
    @pubsub_url = "#{@grpc_host}:#{@grpc_port}"
    @stub = Eventbus::V1::PubSub::Stub.new(@pubsub_url, grpc_secure_channel_credentials)
    @topic_name = ENV.fetch('SF_TOPIC')
    @lock = true
  end

  def auth
    auth_url = ENV.fetch('SF_HOST') + ENV.fetch('SF_AUTH_ENDPOINT')

    response = Faraday.post(auth_url) do |req|
      req.body = { grant_type: 'client_credentials', client_id: ENV.fetch('SF_CLIENT_ID'), client_secret: ENV.fetch('SF_CLIENT_SECRET') }
    end

    body = JSON.parse(response.body)
    @access_token = body.fetch('access_token')
    @metadata = { 'accesstoken' => @access_token, 'instanceurl' => body.fetch('instance_url'), 'tenantid' => ENV.fetch('TENANT_ID') }
  end

  def release_subscription
    @stop_subscription = true
  end

  def fetch_request(topic, replay_type, replay_id, num_requested)
    replay_preset = case replay_type
                    when 'LATEST'
                      Eventbus::V1::ReplayPreset::LATEST
                    when 'EARLIEST'
                      Eventbus::V1::ReplayPreset::EARLIEST
                    when 'CUSTOM'
                      Eventbus::V1::ReplayPreset::CUSTOM
                    else
                      raise 'Invalid Replay Type ' + replay_type
                    end

    Eventbus::V1::FetchRequest.new(
      topic_name: topic,
      replay_preset: replay_preset,
      replay_id: [replay_id].pack('H*'),
      num_requested: num_requested
    )
  end

  def fetch_request_stream(topic, replay_type, replay_id, num_requested)
    Enumerator.new do |yielder|
      # initial request
      yielder << fetch_request(topic, replay_type, replay_id, num_requested)

      loop do
        if request_more_events?(num_requested)
          puts "All requested events were received, requesting a new round of events - waiting for #{num_requested} more events"
          yielder << fetch_request(topic, replay_type, replay_id, num_requested) 
          @lock = true
        end
      end
    end
  end

  def encode(schema_id, payload)
    schema = Avro::Schema.parse(json_schema(schema_id))
    buf = StringIO.new("".force_encoding("BINARY"))
    writer = Avro::IO::DatumWriter.new(schema)
    encoder = Avro::IO::BinaryEncoder.new(buf)
    writer.write(payload, encoder)
    buf.string
  end

  def decode(schema_id, payload)
    schema = Avro::Schema.parse(json_schema(schema_id))
    buf = StringIO.new(payload)
    reader = Avro::IO::DatumReader.new(schema)
    decoder = Avro::IO::BinaryDecoder.new(buf)
    reader.read(decoder)
  end

  def get_topic(topic_name)
    @stub.get_topic(Eventbus::V1::TopicRequest.new(topic_name: topic_name), metadata: @metadata)
  end

  def json_schema(schema_id)
    @json_schema ||= {}
    @json_schema[schema_id] ||= begin
      res = @stub.get_schema(Eventbus::V1::SchemaRequest.new(schema_id: schema_id), metadata: @metadata)
      res.schema_json
    end
  end

  def generate_producer_events(payload, schema_id)
    [{
      schema_id: schema_id,
      payload: encode(
        json_schema(schema_id),
        payload
      )
    }]
  end

  def subscribe(topic, replay_type, replay_id, num_requested, callback)
    sub_stream = @stub.subscribe(fetch_request_stream(topic, replay_type, replay_id, num_requested), metadata: @metadata)
    puts "Subscribed to #{topic}"

    sub_stream.each do |event|
      callback.call(event, self)
    end
  end

  def publish(topic_name, payload, schema_id)
    @stub.publish(Eventbus::V1::PublishRequest.new(
      topic_name: topic_name,
      events: generate_producer_events(payload, schema_id)
    ), metadata: @metadata)
  end

  private

  def grpc_secure_channel_credentials
    cert_file = File.read(Certifi.where)
    GRPC::Core::ChannelCredentials.new(cert_file)
  end

  def request_more_events?(num_requested)
    current_pending_events == 0 && !lock
  end
end
