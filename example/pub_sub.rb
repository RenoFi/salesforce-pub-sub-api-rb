require 'thread'
require 'avro'
require 'grpc'
require_relative '../proto/pubsub_api_pb'
require 'faraday'
require 'certifi'

class PubSub
  attr_accessor :url,:metadata, :stub, :access_token, :topic_name, :api_version, :semaphore

  def initialize(argument_hash)
    @url = ENV.fetch('SF_HOST')
    @grpc_host = ENV.fetch['PUBSUB_HOST']
    @grpc_port = ENV.fetch['PUBSUB_PORT']
    @pubsub_url = "#{@grpc_host}:#{@grpc_port}"
    @stub = PubSubApi::PubSub::Stub.new(@pubsub_url, grpc_secure_channel_credentials)
    @pb2 = PubSubApi
    @topic_name = ENV.fetch('SF_TOPIC')
    @api_version = '57.0'
    @semaphore = Mutex.new
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

  def release_subscription_semaphore
    @semaphore.unlock
  end

  def make_fetch_request(topic, replay_type, replay_id, num_requested)
    replay_preset = case replay_type
                    when 'LATEST'
                      PubSubApi::ReplayPreset::LATEST
                    when 'EARLIEST'
                      PubSubApi::ReplayPreset::EARLIEST
                    when 'CUSTOM'
                      PubSubApi::ReplayPreset::CUSTOM
                    else
                      raise 'Invalid Replay Type ' + replay_type
                    end

    PubSubApi::FetchRequest.new(
      topic_name: topic,
      replay_preset: replay_preset,
      replay_id: [replay_id].pack('H*'),
      num_requested: num_requested
    )
  end

  def fetch_req_stream(topic, replay_type, replay_id, num_requested)
    Enumerator.new do |yielder|
      loop do
        @semaphore.lock
        puts 'Sending Fetch Request'
        yielder << make_fetch_request(topic, replay_type, replay_id, num_requested)
      end
    end
  end

  def encode(schema, payload)
    schema = Avro::Schema.parse(schema)
    buf = StringIO.new
    writer = Avro::IO::DatumWriter.new(schema)
    encoder = Avro::IO::BinaryEncoder.new(buf)
    writer.write(payload, encoder)
    buf.string
  end

  def decode(schema, payload)
    schema = Avro::Schema.parse(schema)
    buf = StringIO.new(payload)
    reader = Avro::IO::DatumReader.new(schema)
    decoder = Avro::IO::BinaryDecoder.new(buf)
    reader.read(decoder)
  end

  def get_topic(topic_name)
    @stub.get_topic(PubSubApi::TopicRequest.new(topic_name: topic_name), metadata: @metadata)
  end

  def get_schema_json(schema_id)
    @json_schema_dict ||= {}
    @json_schema_dict[schema_id] ||= begin
      res = @stub.get_schema(PubSubApi::SchemaRequest.new(schema_id: schema_id), metadata: @metadata)
      res.schema_json
    end
  end

  def generate_producer_events(schema, schema_id)
    payload = {
      'CreatedDate' => Time.now.to_i,
      'CreatedById' => '005R0000000cw06IAA',
      'textt__c' => 'Hello World'
    }
    [{
      schema_id: schema_id,
      payload: encode(schema, payload)
    }]
  end

  def subscribe(topic, replay_type, replay_id, num_requested, callback)
    sub_stream = @stub.subscribe(fetch_req_stream(topic, replay_type, replay_id, num_requested), metadata: @metadata)
    puts "> Subscribed to #{topic}"
    sub_stream.each do |event|
      callback.call(event, self)
    end
  end

  def publish(topic_name, schema, schema_id)
    @stub.publish(PubSubApi::PublishRequest.new(
      topic_name: topic_name,
      events: generate_producer_events(schema, schema_id)
    ), metadata: @metadata)
  end

  private

  def grpc_secure_channel_credentials
    cert_file = File.read(certifi.where)
    GRPC::Core::ChannelCredentials.new(cert_file)
  end
end
