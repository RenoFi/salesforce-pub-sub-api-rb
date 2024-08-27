class Event
  ACTIONS = %w[CREATE UPDATE DELETE UNDELETE].freeze

  def initialize(decoded_event)
    @event = decoded_event
  end

  ACTIONS.each do |action|
    define_method("#{action.downcase}?") { @event['ChangeEventHeader']['changeType'] == action }
  end

  def to_json
    @event
  end

  def unprocessable?
    @event['ChangeEventHeader']['changeOrigin'].include?('client=OurClient')
  end
  
  def record_ids
    @event['ChangeEventHeader']['recordIds']
  end

  def record_fields
    @event.except('ChangeEventHeader')
  end

  def changed_fields
    # The changedFields field contains the fields that were changed. The changedFields field is a bitmap field that isn't readable.
    # It must be decoded first by the client. 
    # ChangeEventHeaderUtility.new.process_bitmap(Avro::Schema.parse(json_schema), changed_fields)
    @event['ChangeEventHeader']['changedFields']
  end
end