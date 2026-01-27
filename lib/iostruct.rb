# frozen_string_literal: true

require_relative 'iostruct/pack_fmt'
require_relative 'iostruct/hash_fmt'

module IOStruct
  extend PackFmt
  extend HashFmt

  FieldInfo = Struct.new :type, :size, :offset, :count, :fmt

  def self.new fmt=nil, *names, inspect: :hex, inspect_name_override: nil, struct_name: nil, **kwargs
    struct_name ||= inspect_name_override # XXX inspect_name_override is deprecated
    if fmt
      renames = kwargs
      finfos, size = parse_pack_format(fmt, names)
      names = auto_names(finfos, size) if names.empty?
      names.map! { |n| renames[n] || n } if renames.any?
    elsif kwargs[:fields]
      fmt, names, finfos, size = parse_hash_format(name: struct_name, **kwargs)
    else
      raise "IOStruct: no fmt and no :fields specified"
    end

    # if first argument to Struct.new() is a string - it creates a named struct in the Struct:: namespace
    # convert all just for the case
    names = names.map(&:to_sym)

    Struct.new( *names ) do
      const_set 'FIELDS', names.zip(finfos).to_h
      const_set 'FORMAT', fmt
      const_set 'SIZE', size
      extend ClassMethods
      include InstanceMethods
      include NestedInstanceMethods if finfos.any?(&:fmt)
      if inspect == :hex
        include HexInspect 
      else
        include DecInspect 
      end
      define_singleton_method(:to_s) { struct_name } if struct_name
      define_singleton_method(:name) { struct_name } if struct_name
    end
  end # self.new

  private

  def self.auto_names fields, _size
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
      new(*data.unpack(const_get('FORMAT'))).tap { |x| x.__offset = pos }
    end

    def name
      'struct'
    end

    def size
      self::SIZE
    end
  end # ClassMethods

  module InstanceMethods
    attr_accessor :__offset

    def pack
      to_a.pack self.class.const_get('FORMAT')
    end

    def empty?
      to_a.all? { |t| t == 0 || t.nil? || t.to_s.tr("\x00", "").empty? }
    end

    # allow initializing individual struct members by name, like:
    #   PEdump::IMAGE_SECTION_HEADER.new(
    #     :VirtualSize    => 0x100,
    #     :VirtualAddress => 0x100000
    #   )
    def initialize *args
      if args.size == 1 && args.first.is_a?(Hash)
        super()
        args.first.each do |k, v|
          send "#{k}=", v
        end
      else
        super
      end
    rescue ArgumentError => e
      if e.message == "struct size differs"
        raise ArgumentError.new("struct size differs: class=#{self.class.name} format=#{self.class::FORMAT.inspect} fields_count=#{self.class::FIELDS.size} args=#{args.inspect}")
      else
        raise
      end
    end
  end # InstanceMethods

  # initialize nested structures / arrays
  module NestedInstanceMethods
    def initialize *args
      super
      self.class::FIELDS.each do |k, v|
        next unless v.fmt

        if value = self[k]
          self[k] = v.fmt.is_a?(String) ? value.unpack(v.fmt) : v.fmt.read(value)
        end
      end
    end
  end

  module DecInspect
    def to_table
      values = self.to_a
      "<#{self.class.name} " + self.class::FIELDS.map.with_index do |el, idx|
        v = values[idx]
        fname, f = el

        "#{fname}=" +
          case 
          when f.nil? # unknown field type
            v.inspect
          when f.type == Integer
            v = 0 if v.nil? # avoid "`sprintf': can't convert nil into Integer" error
            # display as unsigned, because signed %x looks ugly: "..f" for -1
            case f.size
            when 1 then "%4d" % v
            when 2 then "%6d" % v
            when 4 then "%11d" % v
            when 8 then "%20d" % v
            else
              raise "Unsupported Integer size #{f.size} for field #{fname}"
            end
          when f.type == Float
            0 if v.nil? # avoid "`sprintf': can't convert nil into Float" error
            "%8.3f"
          else
            v.inspect
          end
      end.join(' ') + ">"
    end
  end

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
      values = self.to_a
      "<#{self.class.name} " + self.class::FIELDS.map.with_index do |el, idx|
        v = values[idx]
        fname, f = el

        "#{fname}=" +
          case 
          when f.nil? # unknown field type
            v.inspect
          when f.type == Integer
            v = 0 if v.nil? # avoid "`sprintf': can't convert nil into Integer" error
            # display as unsigned, because signed %x looks ugly: "..f" for -1
            case f.size
            when 1 then "%2x" % (v & 0xff)
            when 2 then "%4x" % (v & 0xffff)
            when 4 then "%8x" % (v & 0xffffffff)
            when 8 then "%16x" % (v & 0xffffffffffffffff)
            else
              raise "Unsupported Integer size #{f.size} for field #{fname}"
            end
          when f.type == Float
            0 if v.nil? # avoid "`sprintf': can't convert nil into Float" error
            "%8.3f"
          else
            v.inspect
          end
      end.join(' ') + ">"
    end

    def inspect
      to_s
    end
  end
end # IOStruct
