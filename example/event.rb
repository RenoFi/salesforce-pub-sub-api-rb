require_relative 'binary_handler'

class Event
  ACTIONS = %w[CREATE UPDATE DELETE UNDELETE].freeze

  def initialize(decoded_event, json_schema)
    @event = decoded_event
    @json_schema = json_schema
  end

  ACTIONS.each do |action|
    define_method("#{action.downcase}?") { @event['ChangeEventHeader']['changeType'] == action }
  end

  def to_json(*_args)
    { decoded_event: @event, readable_changed_fields: changed_fields }.compact
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
    bitmap_fields = @event['ChangeEventHeader']['changedFields']
    Example::BinaryHandler.new(@json_schema).process_bitmap(bitmap_fields) unless bitmap_fields.empty?
  end
end
