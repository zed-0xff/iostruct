# frozen_string_literal: true

module IOStruct
  module HashFmt
    KNOWN_FIELD_TYPES_REVERSED = {
      'C' => ['uint8_t',  'unsigned char', '_BYTE'],
      'S' => ['uint16_t', 'unsigned short'],
      'I' => ['uint32_t', 'unsigned', 'unsigned int'],
      'L' => ['unsigned long'],
      'Q' => ['uint64_t', 'unsigned long long'],

      'c' => ['int8_t',  'char', 'signed char'],
      's' => ['int16_t', 'short', 'signed short'],
      'i' => ['int32_t', 'int', 'signed', 'signed int'],
      'l' => ['long',    'signed long'],
      'q' => ['int64_t', 'long long', 'signed long long'],

      # Big-endian (network byte order)
      'n' => ['uint16_be', 'uint16_t_be', 'be16'],
      'N' => ['uint32_be', 'uint32_t_be', 'be32'],

      # Little-endian (VAX byte order)
      'v' => ['uint16_le', 'uint16_t_le', 'le16'],
      'V' => ['uint32_le', 'uint32_t_le', 'le32'],

      # Floats
      'd' => ['double'],
      'f' => ['float'],
      'E' => ['double_le'],  # double-precision, little-endian
      'e' => ['float_le'],   # single-precision, little-endian
      'G' => ['double_be'],  # double-precision, big-endian
      'g' => ['float_be'],   # single-precision, big-endian
    }.freeze

    KNOWN_FIELD_TYPES = KNOWN_FIELD_TYPES_REVERSED.map { |t, a| a.map { |v| [v, t] } }.flatten.each_slice(2).to_h

    # for external use
    def get_type_size(typename)
      type_code = KNOWN_FIELD_TYPES[typename.to_s]
      f_size, = PackFmt::FMTSPEC[type_code]
      f_size
    end

    private

    def parse_hash_format(fields:, size: nil, name: nil)
      struct_name = name
      offset = 0
      names = []
      fmt_arr = []
      finfos = fields.map do |f_name, type|
        f_offset = offset
        f_count = 1
        klass = f_fmt = type_code = nil

        if type.is_a?(Hash)
          f_offset = type.fetch(:offset, offset)
          if f_offset > offset
            fmt_arr << "x#{f_offset - offset}"
          elsif f_offset < offset
            raise "#{struct_name}: field #{f_name.inspect} overlaps previous field"
          end
          f_count = type.fetch(:count, f_count)
          type = type[:type]
        end

        case type
        when String
          # noop
        when Symbol
          type = type.to_s
        when Class
          klass = type
          f_size = klass.size
          f_fmt = klass
          type_code = "a#{f_size}"
        else
          raise "#{f_name}: unexpected field desc type #{type.class}"
        end

        unless type_code
          type_code = KNOWN_FIELD_TYPES[type]
          raise "#{f_name}: unknown field type #{type.inspect}" unless type_code

          f_size, klass = PackFmt::FMTSPEC[type_code] || raise("Unknown field type code #{type_code.inspect}")
        end

        if f_count != 1
          if f_fmt.is_a?(Class)
            # Nested struct array: keep f_fmt as the Class, just update size and type_code
            f_size *= f_count
            type_code = "a#{f_size}"
          else
            # Primitive array: set f_fmt to pack format string (e.g., "i3")
            f_fmt = "#{type_code}#{f_count}"
            f_size *= f_count
            type_code = "a#{f_size}"
          end
        end

        offset = f_offset + f_size
        fmt_arr << type_code
        names << f_name

        FieldInfo.new(klass, f_size, f_offset, f_count, f_fmt)
      end
      raise "#{struct_name}: actual struct size #{offset} is greater than forced size #{size}: #{fields.inspect}" if size && offset > size

      [fmt_arr.join, names, finfos, size || offset]
    end
  end
end
