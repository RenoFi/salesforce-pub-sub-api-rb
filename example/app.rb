require 'json'
require 'time'

def run
  cdc_listener = PubSub.new
  cdc_listener.auth

  cdc_listener.subscribe('/data/Game__ChangeEvent', "LATEST", "", 1, method(:process_order))
end

def make_publish_request(schema_id, record_id, obj)
  req = {
    topic_name: my_publish_topic,
    events: generate_producer_events(schema_id, record_id, obj)
  }
  req
end

def generate_producer_events(schema_id, record_id, obj)
  # Codifica os dados a serem enviados no evento e cria um ProducerEvent conforme o arquivo proto.
  schema = obj.get_schema_json(schema_id)
  dt = Time.now + (5 * 24 * 60 * 60) # 5 dias no futuro
  payload = {
    "CreatedDate" => Time.now.to_i,
    "CreatedById" => '005R0000000cw06IAA',
    "OpptyRecordId__c" => record_id,
    "EstimatedDeliveryDate__c" => dt.to_i,
    "Weight__c" => 58.2
  }
  req = {
    "schema_id" => schema_id,
    "payload" => obj.encode(schema, payload.to_json)
  }
  [req]
end

def process_event(event, pubsub)
  # Este é um callback passado para o método `PubSub.subscribe()`.
  # Decodifica o payload do evento recebido e extrai o ID da oportunidade.
  # Em seguida, chama uma função auxiliar para publicar o evento `/event/NewOrderConfirmation__e`.
  if event[:events]
    puts "Number of events received in FetchResponse: #{event[:events].length}"
    
    if event[:pending_num_requested].zero?
      pubsub.release_subscription_semaphore
    end

    event[:events].each do |evt|
      payload_bytes = evt[:event][:payload]
      schema_id = evt[:event][:schema_id]
      json_schema = pubsub.get_schema_json(schema_id)
      decoded_event = pubsub.decode(json_schema, payload_bytes)

      puts "Received event payload: \n#{decoded_event}"

      if decoded_event['ChangeEventHeader']
        changed_fields = decoded_event['ChangeEventHeader']['changedFields']
        converted_changed_fields = process_bitmap(avro.schema.parse(json_schema), changed_fields)
        puts "Change Type: #{decoded_event['ChangeEventHeader']['changeType']}"
        puts "=========== Changed Fields ============="
        puts converted_changed_fields
        puts "========================================="

        if decoded_event['ChangeEventHeader']['changeOrigin'].include?('client=SalesforceListener')
          puts "Skipping change event because it is an update to the delivery date by SalesforceListener."
          return
        end
      end

      record_id = decoded_event['ChangeEventHeader']['recordIds'][0]

      if $DEBUG
        sleep(10)
      end
      puts "> Received new order! Processing order..."
      sleep(4) if $DEBUG
      puts "  Done! Order replicated in inventory system."
      sleep(2) if $DEBUG
      puts "> Calculating estimated delivery date..."
      sleep(2) if $DEBUG
      puts "  Done! Sending estimated delivery date back to Salesforce."
      sleep(10) if $DEBUG

      topic_info = pubsub.get_topic(topic_name: my_publish_topic)

      res = pubsub.stub.Publish(make_publish_request(topic_info.schema_id, record_id, pubsub),
                                metadata: pubsub.metadata)
      if res.results[0].replay_id
        puts "> Event published successfully."
      else
        puts "> Failed publishing event."
      end
    end
  else
    puts "[#{Time.now.strftime('%b %d, %Y %l:%M%p %Z')}] The subscription is active."
  end

  event[:latest_replay_id]
end
