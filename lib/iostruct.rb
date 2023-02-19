# frozen_string_literal: true

module IOStruct

  # https://apidock.com/ruby/String/unpack
  FIELD_SIZES = {
    'C' => 1,      # Integer | 8-bit unsigned (unsigned char)
    'S' => 2,      # Integer | 16-bit unsigned, native endian (uint16_t)
    'L' => 4,      # Integer | 32-bit unsigned, native endian (uint32_t)
    'Q' => 8,      # Integer | 64-bit unsigned, native endian (uint64_t)
    'c' => 1,      # Integer | 8-bit signed (signed char)
    's' => 2,      # Integer | 16-bit signed, native endian (int16_t)
    'l' => 4,      # Integer | 32-bit signed, native endian (int32_t)
    'q' => 8,      # Integer | 64-bit signed, native endian (int64_t)

    'n' => 2,      # Integer | 16-bit unsigned, network (big-endian) byte order
    'N' => 4,      # Integer | 32-bit unsigned, network (big-endian) byte order
    'v' => 2,      # Integer | 16-bit unsigned, VAX (little-endian) byte order
    'V' => 4,      # Integer | 32-bit unsigned, VAX (little-endian) byte order

    'A' => 1,      # String  | arbitrary binary string (remove trailing nulls and ASCII spaces)
    'a' => 1,      # String  | arbitrary binary string

    'D' => 8,      # Float   | double-precision, native format
    'd' => 8,
    'F' => 4,      # Float   | single-precision, native format
    'f' => 4,
    'E' => 8,      # Float   | double-precision, little-endian byte order
    'e' => 4,      # Float   | single-precision, little-endian byte order
    'G' => 8,      # Float   | double-precision, network (big-endian) byte order
    'g' => 4,      # Float   | single-precision, network (big-endian) byte order

    'x' => 1,      # ---     | skip forward one byte
  }.freeze

  def self.new fmt, *args
    size = fmt.scan(/([a-z])(\d*)/i).map do |f,len|
      if (field_size = FIELD_SIZES[f])
        [len.to_i, 1].max * field_size
      else
        raise "Unknown fmt #{f.inspect}"
      end
    end.inject(&:+)

    Struct.new( *args ).tap do |x|
      x.const_set 'FORMAT', fmt
      x.const_set 'SIZE',  size
      x.class_eval do
        include InstanceMethods
      end
      x.extend ClassMethods
    end
  end # self.new

  module ClassMethods
    # src can be IO or String, or anything that responds to :read or :unpack
    def read src, size = nil
      size ||= const_get 'SIZE'
      data =
        if src.respond_to?(:read)
          src.read(size).to_s
        elsif src.respond_to?(:unpack)
          src
        else
          raise "[?] don't know how to read from #{src.inspect}"
        end
      if data.size < size
        $stderr.puts "[!] #{self.to_s} want #{size} bytes, got #{data.size}"
      end
      new(*data.unpack(const_get('FORMAT')))
    end
  end # ClassMethods

  module InstanceMethods
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
end # IOStruct
