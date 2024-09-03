require_relative 'event'
require_relative 'binary_handler'

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

    def process_response(response, _pubsub)
      @cdc_listener.current_pending_events = response.pending_num_requested
      @cdc_listener.lock = false

      puts "Number of events received #{response.events.length}"

      response.events.each do |evt|
        payload_blob = evt.event.payload
        schema_id = evt.event.schema_id

        decoded_event = BinaryHandler.new(@cdc_listener.json_schema(schema_id)).decode(payload_blob)
        event = Event.new(decoded_event, @cdc_listener.json_schema(schema_id))

        handle_event(event)
      end
    end

    def handle_event(event)
      puts "Received event payload: \n#{event.to_json}"
      nil if event.unprocessable?
    end
  end
end
