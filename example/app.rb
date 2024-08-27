require_relative 'event.rb'
require_relative 'binary_handler.rb'

module Example
  class App
    TOPIC = ENV.fetch('SF_TOPIC').freeze
    BATCH_NUMBER_OF_EVENTS = 5

    attr_reader :cdc_listener

    def initialize
      @cdc_listener = PubSub.new
      @cdc_listener.auth
    end

    def run
      @cdc_listener.subscribe(TOPIC, "LATEST", "", BATCH_NUMBER_OF_EVENTS, method(:process_response))
    end

    def process_response(response, pubsub)
      @cdc_listener.current_pending_events = response.pending_num_requested
      @cdc_listener.lock = false

      puts "Number of events received #{response.events.length}"

      response.events.each do |evt|
        payload_blob = evt.event.payload
        schema_id = evt.event.schema_id

        decoded_event = BinaryHandler.decode(@cdc_listener.json_schema(schema_id), payload_blob)
        event = Event.new(decoded_event)

        handle_event(event)
      end
    end

    def handle_event(event)
      puts "Received event payload: \n#{event.to_json}"
      return if event.unprocessable?
    end
  end
end