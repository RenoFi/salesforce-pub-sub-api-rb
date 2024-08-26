require_relative 'decoded_event.rb'
require_relative 'event_mapper.rb'

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

        decoded_event = DecodedEvent.new(pubsub.decode(schema_id, payload_blob))

        puts "Received event payload: \n#{decoded_event.to_json}"
        return if decoded_event.already_processed?

        handle_event(decoded_event, schema_id)
      end
    end

    def handle_event(decoded_event, schema_id)
      if decoded_event.create?
        return # publish is in WIP, this return will be removed when publish is done

        puts "Received a CREATE event, adding the record into the app..."
        sobject_id = decoded_event.record_ids.first

        # find or initialize the object given the sobject_id and persists it
        puts "Creating the new record in back-end with the attributes: #{decoded_event.record_fields}"
        record_uuid = SecureRandom.uuid # just an example of a persisted id after creating the record
        
        res = @cdc_listener.stub.publish(publish_changes(schema_id, decoded_event), metadata: @cdc_listener.metadata)

        if res.results.first.replay_id
          puts "Event published successfully."
        else
          puts "Failed publishing event."
        end
      end
    end

    # experiment changes - testing purposes, it will be migrate entirely to pubsub
    def publish_changes(schema_id, decoded_event)
      payload = EventMapper.build(decoded_event)

      Eventbus::V1::PublishRequest.new(
        topic_name: TOPIC,
        events: generate_producer_events(schema_id, payload)
      )
    end

    def generate_producer_events(schema_id, payload)
      req = {
        "schema_id" => schema_id,
        "payload" => @cdc_listener.encode(schema_id, payload)
      }

      [req]
    end
  end
end