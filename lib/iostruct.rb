# frozen_string_literal: true

module IOStruct

  # https://apidock.com/ruby/String/unpack
  FMTSPEC = {
    'C' => [1, Integer ], # 8-bit unsigned (unsigned char)
    'S' => [2, Integer ], # 16-bit unsigned, native endian (uint16_t)
    'I' => [4, Integer ], # 32-bit unsigned, native endian (uint32_t)
    'L' => [4, Integer ], # 32-bit unsigned, native endian (uint32_t)
    'Q' => [8, Integer ], # 64-bit unsigned, native endian (uint64_t)

    'c' => [1, Integer ], # 8-bit signed (signed char)
    's' => [2, Integer ], # 16-bit signed, native endian (int16_t)
    'i' => [4, Integer ], # 32-bit signed, native endian (int32_t)
    'l' => [4, Integer ], # 32-bit signed, native endian (int32_t)
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

  FieldInfo = Struct.new :type, :size, :offset

  def self.new fmt, *names, inspect: :hex, inspect_name_override: nil, **renames
    fields, size = parse_format(fmt, names)
    names = auto_names(fields, size) if names.empty?
    names.map!{ |n| renames[n] || n } if renames.any?

    Struct.new( *names ).tap do |x|
      x.const_set 'FIELDS', names.zip(fields).to_h
      x.const_set 'FORMAT', fmt
      x.const_set 'SIZE',  size
      x.extend ClassMethods
      x.include InstanceMethods
      x.include HexInspect if inspect == :hex
      x.define_singleton_method(:name) { inspect_name_override } if inspect_name_override
    end
  end # self.new

  def self.parse_format(fmt, names)
    offset = 0
    fields = []
    fmt.scan(/([a-z])(\d*)/i).map do |type,len|
      size, klass = FMTSPEC[type] || raise("Unknown field type #{type.inspect}")
      len = len.empty? ? 1 : len.to_i
      case type
      when 'A', 'a', 'x', 'Z'
        fields << FieldInfo.new(klass, size*len, offset) if klass
        offset += len
      when 'H', 'h'
        # XXX ruby's String#unpack length for hex strings is in characters, not bytes, i.e. "x".unpack("H2") => ["78"]
        fields << FieldInfo.new(klass, size*len/2, offset) if klass
        offset += len/2
      else
        len.times do |i|
          fields << FieldInfo.new(klass, size, offset)
          offset += size
        end
      end
    end
    [fields, offset]
  end

  def self.auto_names fields, size
    names = []
    offset = 0
    fields.each do |f|
      names << sprintf("f%x", offset).to_sym
      offset += f.size
    end
    #raise "size mismatch: #{size} != #{offset}" if size != offset
    names
  end

  module ClassMethods
    # src can be IO or String, or anything that responds to :read or :unpack
    def read src, size = nil
      pos = nil
      size ||= const_get 'SIZE'
      data =
        if src.respond_to?(:read)
          pos = src.tell
          src.read(size).to_s
        elsif src.respond_to?(:unpack)
          src
        else
          raise "[?] don't know how to read from #{src.inspect}"
        end
#      if data.size < size
#        $stderr.puts "[!] #{self.to_s} want #{size} bytes, got #{data.size}"
#      end
      new(*data.unpack(const_get('FORMAT'))).tap{ |x| x.__offset = pos }
    end

    def size
      self::SIZE
    end

    def name
      self.to_s
    end
  end # ClassMethods

  module InstanceMethods
    attr_accessor :__offset

    def pack
      to_a.pack self.class.const_get('FORMAT')
    end

    def empty?
      to_a.all?{ |t| t == 0 || t.nil? || t.to_s.tr("\x00","").empty? }
    end

    # allow initializing individual struct members by name, like:
    #   PEdump::IMAGE_SECTION_HEADER.new(
    #     :VirtualSize    => 0x100,
    #     :VirtualAddress => 0x100000
    #   )
    def initialize *args
      if args.size == 1 && args.first.is_a?(Hash)
        super()
        args.first.each do |k,v|
          send "#{k}=", v
        end
      else
        super
      end
    end
  end # InstanceMethods

  module HexInspect
    def to_s
      "<#{self.class.name} " + to_h.map do |k, v|
        if v.is_a?(Integer) && v > 9
          "#{k}=0x%x" % v
        else
          "#{k}=#{v.inspect}"
        end
      end.join(' ') + ">"
    end

    def to_table
      @fmtstr_tbl = "<#{self.class.name} " + self.class.const_get('FIELDS').map do |name, f|
        fmt =
          case 
          when f.type == Integer
            "%#{f.size*2}x"
          when f.type == Float
            "%8.3f"
          else
            "%s"
          end
        "#{name}=#{fmt}"
      end.join(' ') + ">"
      sprintf @fmtstr_tbl, *to_a.map{ |v| v.is_a?(String) ? v.inspect : (v||0) } # "||0" to avoid "`sprintf': can't convert nil into Integer" error
    end

    def inspect
      to_s
    end
  end
end # IOStruct
