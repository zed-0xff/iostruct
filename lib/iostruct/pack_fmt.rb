# frozen_string_literal: true

module IOStruct
  module PackFmt
    # https://apidock.com/ruby/String/unpack
    FMTSPEC = {
      'C' => [1, Integer ], # 8-bit unsigned                 (uint8_t, unsigned char)
      'S' => [2, Integer ], # 16-bit unsigned, native endian (uint16_t)
      'I' => [4, Integer ], # 32-bit unsigned, native endian (uint32_t, unsigned int)
      'L' => [4, Integer ], # 32-bit unsigned, native endian (unsigned long)
      'Q' => [8, Integer ], # 64-bit unsigned, native endian (uint64_t)

      'c' => [1, Integer ], # 8-bit signed                 (int8_t, signed char)
      's' => [2, Integer ], # 16-bit signed, native endian (int16_t)
      'i' => [4, Integer ], # 32-bit signed, native endian (int32_t, int)
      'l' => [4, Integer ], # 32-bit signed, native endian (long)
      'q' => [8, Integer ], # 64-bit signed, native endian (int64_t)

      'n' => [2, Integer ], # 16-bit unsigned, network (big-endian) byte order
      'N' => [4, Integer ], # 32-bit unsigned, network (big-endian) byte order
      'v' => [2, Integer ], # 16-bit unsigned, VAX (little-endian) byte order
      'V' => [4, Integer ], # 32-bit unsigned, VAX (little-endian) byte order

      'A' => [1, String  ], # arbitrary binary string (remove trailing nulls and ASCII spaces)
      'a' => [1, String  ], # arbitrary binary string
      'Z' => [1, String  ], # arbitrary binary string (remove trailing nulls)
      'H' => [1, String  ], # hex string (high nibble first)
      'h' => [1, String  ], # hex string (low nibble first)

      'D' => [8, Float   ], # double-precision, native format
      'd' => [8, Float   ],
      'F' => [4, Float   ], # single-precision, native format
      'f' => [4, Float   ],
      'E' => [8, Float   ], # double-precision, little-endian byte order
      'e' => [4, Float   ], # single-precision, little-endian byte order
      'G' => [8, Float   ], # double-precision, network (big-endian) byte order
      'g' => [4, Float   ], # single-precision, network (big-endian) byte order

      'x' => [1, nil     ], # skip forward one byte
    }.freeze

    private
    def parse_pack_format(fmt, names)
      offset = 0
      fields = []
      fmt.scan(/([a-z])(\d*)/i).map do |type,len|
        size, klass = FMTSPEC[type] || raise("Unknown field type #{type.inspect}")
        len = len.empty? ? 1 : len.to_i
        case type
        when 'A', 'a', 'x', 'Z'
          fields << FieldInfo.new(klass, size * len, offset) if klass
          offset += len
        when 'H', 'h'
          # XXX ruby's String#unpack length for hex strings is in characters, not bytes, i.e. "x".unpack("H2") => ["78"]
          fields << FieldInfo.new(klass, size * len / 2, offset) if klass
          offset += len / 2
        else
          len.times do |i|
            fields << FieldInfo.new(klass, size, offset)
            offset += size
          end
        end
      end
      [fields, offset]
    end
  end
end
