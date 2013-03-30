module IOStruct
  def self.new fmt, *args
    size = fmt.scan(/([a-z])(\d*)/i).map do |f,len|
      [len.to_i, 1].max *
        case f
        when /[AaCcx]/ then 1
        when 'v' then 2
        when 'V','l','L' then 4
        when 'Q' then 8
        else raise "unknown fmt #{f.inspect}"
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
