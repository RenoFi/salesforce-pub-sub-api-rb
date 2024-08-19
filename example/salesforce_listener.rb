require 'json'
require 'time'
require 'net/http'
require_relative '../utils/change_event_header_utility'
require_relative '../utils/client_util'
require_relative 'pub_sub'

class SalesforceListener
  def self.process_confirmation(event, pubsub)
    if event.events.any?
      puts "Number of events received in FetchResponse: #{event.events.size}"

      # If all requested events are delivered, release the semaphore
      # so that a new FetchRequest gets sent by `PubSub.fetch_req_stream()`.
      pubsub.release_subscription_semaphore if event.pending_num_requested.zero?

      event.events.each do |evt|
        payload_bytes = evt.event.payload
        json_schema = pubsub.get_schema_json(evt.event.schema_id)
        decoded_event = pubsub.decode(json_schema, payload_bytes)

        if decoded_event.key?('ChangeEventHeader')
          changed_fields = decoded_event['ChangeEventHeader']['changedFields']
          puts "Change Type: #{decoded_event['ChangeEventHeader']['changeType']}"
          puts "=========== Changed Fields ============="
          puts ChangeEventHeaderUtility.new.process_bitmap(Avro::Schema.parse(json_schema), changed_fields)
          puts "========================================="
        end

        puts "> Received order confirmation! Updating estimated delivery date..."
        sleep(2) if $DEBUG

        day = Time.at(decoded_event['EstimatedDeliveryDate__c']).strftime('%Y-%m-%d')
        uri = URI("#{pubsub.url}/services/data/v#{pubsub.api_version}/sobjects/Opportunity/#{decoded_event['OpptyRecordId__c']}")
        request_body = { 'Description' => "Estimated Delivery Date: #{day}" }.to_json
        response = Faraday.patch(url) do |request|
          request.headers['Authorization'] = "Bearer #{pubsub.access_token}"
          request.headers['Content-Type'] = 'application/json'
          request.headers['Sforce-Call-Options'] = 'client=SalesforceListener'
          request.body = request_body
        end

        puts "  Done!", res
      end
    else
      puts "[#{Time.now.strftime('%b %d, %Y %l:%M%p %Z')}] The subscription is active."
    end

    # The replay_id is used to resubscribe after this position in the stream if the client disconnects.
    # Implement storage of replay for resubscribe!!!
    event.latest_replay_id
  end

  def self.run(argument_dict)
    sfdc_updater = PubSub.new(argument_dict)
    sfdc_updater.auth

    # Subscribe to /event/NewOrderConfirmation__e events
    sfdc_updater.subscribe('/event/NewOrderConfirmation__e', 'LATEST', '', 1, method(:process_confirmation))
  end
end

if __FILE__ == $PROGRAM_NAME
  argument_dict = ClientUtil.command_line_input(ARGV)
  SalesforceListener.run(argument_dict)
end
