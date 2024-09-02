require 'avro'
require 'bitstring'

class Bitstring
  def initialize(hex: nil)
    @hex = hex
  end

  def to_s
    @hex.to_i(16).to_s(2).rjust(@hex.size * 4, '0')
  end
end

class EventHeaderParser
  def initialize(avro_schema)
    @avro_schema = avro_schema
  end

  def process_bitmap(bitmap_fields)
    fields = []

    bitmap_fields.each do |bitmap_field|
      next if bitmap_field.nil?

      if bitmap_field.start_with?("0x")
        fields += get_fieldnames_from_bitstring(bitmap_field)
      elsif bitmap_field.include?("-")
        fields += get_nested_fieldnames(bitmap_field)
      end
    end

    fields
  end

  private

  def get_fieldnames_from_bitstring(bitmap)
    binary_string = convert_hexbinary_to_bitset(bitmap)
    indexes = find('1', binary_string)

    indexes.map { |index| @avro_schema.fields[index].name }
  end

  def get_nested_fieldnames(bitmap_field)
    parent_index, bitmap_string = bitmap_field.split("-")
    parent_field = @avro_schema.fields[parent_index.to_i]
    child_schema = get_value_schema(parent_field.type)

    return [] unless child_schema.type == 'record'

    full_field_names = get_fieldnames_from_bitstring(bitmap_string, child_schema)
    append_parent_name(parent_field.name, full_field_names)
  end

  def convert_hexbinary_to_bitset(bitmap)
    Bitstring.new(hex: bitmap[2..-1]).to_s.reverse
  end

  def append_parent_name(parent_field_name, full_field_names)
    full_field_names.map { |field_name| "#{parent_field_name}.#{field_name}" }
  end

  def get_value_schema(parent_field)
    if parent_field.type.type_sym == :union
      schemas = parent_field.type.schemas

      if schemas.length == 2 && schemas.first.type_sym == :null
        return schemas.last
      elsif schemas.length == 2 && schemas.first.type_sym == :string
        return schemas.last
      elsif schemas.length == 3 && schemas.first.type_sym == :null && schemas[1].type_sym == :string
        return schemas.last
      end
    end

    parent_field.type
  end

  def find(to_find, binary_string)
    binary_string.chars.each_with_index.map { |char, i| i if char == to_find }.compact
  end
end
