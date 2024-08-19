require 'avro'
require 'bitstring'

# class responsible for converting bitmaps into human-readable
class EventHeaderParser
  def process_bitmap(avro_schema, bitmap_fields)
    fields = []
    unless bitmap_fields.empty?
      # replace top field level bitmap with list of fields
      if bitmap_fields.first.start_with?("0x")
        bitmap = bitmap_fields.first
        fields += get_fieldnames_from_bitstring(bitmap, avro_schema)
        bitmap_fields.shift
      end

      # replace parentPos-nested Nulled BitMap with list of fields too
      if bitmap_fields.any? && bitmap_fields.last.include?("-")
        bitmap_fields.each do |bitmap_field|
          next if bitmap_field.nil? || !bitmap_field.include?("-")
          
          bitmap_strings = bitmap_field.split("-")
          parent_field = avro_schema.fields[bitmap_strings[0].to_i]
          child_schema = get_value_schema(parent_field.type)

          if child_schema.type && child_schema.type == 'record'
            nested_size = child_schema.fields.length
            parent_field_name = parent_field.name

            full_field_names = get_fieldnames_from_bitstring(bitmap_strings[1], child_schema)
            full_field_names = append_parent_name(parent_field_name, full_field_names)
            fields += full_field_names unless full_field_names.empty?
          end
        end
      end
    end
    fields
  end

  private

  def convert_hexbinary_to_bitset(bitmap)
    bit_array = Bitstring.new(hex: bitmap[2..-1])
    binary_string = bit_array.to_s
    binary_string.reverse
  end

  def append_parent_name(parent_field_name, full_field_names)
    full_field_names.map { |field_name| "#{parent_field_name}.#{field_name}" }
  end

  def get_fieldnames_from_bitstring(bitmap, avro_schema)
    bitmap_field_name = []
    fields_list = avro_schema.fields.to_a
    binary_string = convert_hexbinary_to_bitset(bitmap)
    indexes = find('1', binary_string)

    indexes.each do |index|
      bitmap_field_name << fields_list[index].name
    end
    bitmap_field_name
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

class Bitstring
  def initialize(hex: nil)
    @hex = hex
  end

  def to_s
    @hex.to_i(16).to_s(2).rjust(@hex.size * 4, '0')
  end
end