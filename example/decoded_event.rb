class DecodedEvent
  def initialize(decoded_event)
    @decoded_event = decoded_event
  end

  def to_json
    @decoded_event
  end

  def to_s
    @decoded_event.to_s
  end

  def create?
    @decoded_event['ChangeEventHeader']['changeType'] == 'CREATE'
  end

  def already_processed?
    @decoded_event['ChangeEventHeader']['changeOrigin'].include?('client=OurClient')
  end
  
  def record_ids
    @decoded_event['ChangeEventHeader']['recordIds']
  end

  def record_fields
    @decoded_event.except('ChangeEventHeader')
  end

  def changed_fields
    # The changedFields field contains the fields that were changed. The changedFields field is a bitmap field that isn't readable.
    # It must be decoded first by the client. 
    # ChangeEventHeaderUtility.new.process_bitmap(Avro::Schema.parse(json_schema), changed_fields)
    @decoded_event['ChangeEventHeader']['changedFields']
  end
end