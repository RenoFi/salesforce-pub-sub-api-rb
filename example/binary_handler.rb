require 'avro'
require_relative '../utils/event_header_parser'

module Example
  class BinaryHandler
    extend Forwardable

    def initialize(json_schema)
      @avro_schema = Avro::Schema.parse(json_schema)
      @event_header_parser = EventHeaderParser.new(@avro_schema)
    end

    def_delegators :@event_header_parser, :process_bitmap

    def encode(payload)
      buf = StringIO.new("".force_encoding("BINARY"))
      writer = Avro::IO::DatumWriter.new(@avro_schema)
      encoder = Avro::IO::BinaryEncoder.new(buf)
      writer.write(payload, encoder)
      buf.string
    end

    def decode(payload)
      buf = StringIO.new(payload)
      reader = Avro::IO::DatumReader.new(@avro_schema)
      decoder = Avro::IO::BinaryDecoder.new(buf)
      reader.read(decoder)
    end
  end
end
