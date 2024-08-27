require 'avro'

module Example
  class BinaryHandler
    class << self
      def encode(json_schema, payload)
        schema = Avro::Schema.parse(json_schema)
        buf = StringIO.new("".force_encoding("BINARY"))
        writer = Avro::IO::DatumWriter.new(schema)
        encoder = Avro::IO::BinaryEncoder.new(buf)
        writer.write(payload, encoder)
        buf.string
      end
    
      def decode(json_schema, payload)
        schema = Avro::Schema.parse(json_schema)
        buf = StringIO.new(payload)
        reader = Avro::IO::DatumReader.new(schema)
        decoder = Avro::IO::BinaryDecoder.new(buf)
        reader.read(decoder)
      end
    end
  end
end