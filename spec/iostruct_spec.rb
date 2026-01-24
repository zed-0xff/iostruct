require 'spec_helper'
require 'stringio'

describe IOStruct do
  describe ":name" do
    context "when set" do
      it "uses the custom name" do
        x = IOStruct.new('LL', :x, :y, struct_name: 'Point')
        expect(x.new.inspect).to match /<Point x=nil y=nil>/
      end
    end

    context "when not set" do
      it "has default name" do
        x = IOStruct.new('LL', :x, :y)
        expect(x.new.inspect).to match /<struct x=nil y=nil>/
      end
    end
  end

  describe "#read" do
    let(:a) { [12345, 56789] }
    let(:data) { a.pack('L2') }

    it "reads from IO" do
      x = IOStruct.new('LL', :x, :y).read(StringIO.new(data))
      expect(x.x).to eq a[0]
      expect(x.y).to eq a[1]
    end

    it "reads from String" do
      x = IOStruct.new('LL', :x, :y).read(data)
      expect(x.x).to eq a[0]
      expect(x.y).to eq a[1]
    end

    it "creates a new instance of a subclass" do
      klass = Class.new( IOStruct.new('LL', :x, :y) )
      x = klass.read(data)
      expect(x).to be_a klass
    end
  end

  context "zero-length strings" do
    let(:data) { [1, 2].pack('CC') }
    let(:struct) { IOStruct.new('C a0 C', :a, :b, :c) }

    it "deserializes" do
      x = struct.read(data)
      expect(x.a).to eq 1
      expect(x.b).to eq ""
      expect(x.c).to eq 2
    end

    it "has correct SIZE" do
      expect(struct::SIZE).to eq 2
    end

    it "has correct size" do
      expect(struct.size).to eq 2
    end

    it "reads correct number of bytes from IO" do
      io = StringIO.new(data*2)
      x = struct.read(io)
      expect(io.pos).to eq 2
    end

    it "serializes" do
      x = struct.read(data)
      expect(x.pack).to eq data
    end
  end

  it "skips on 'x'" do
    a = [12345, 56789]
    data = a.pack('L2')
    x = IOStruct.new('x4L', :y).read(data)
    expect(x.y).to eq a[1]
  end

  it "unpacks hex-string (H)" do
    data = "1234"
    struct = IOStruct.new('H8', :x).read(data)
    expect(struct.x).to eq "31323334"
    expect(struct.pack).to eq data
  end

  it "unpacks reverse-nibbled hex-string (h)" do
    data = "1234"
    struct = IOStruct.new('h8', :x).read(data)
    expect(struct.x).to eq "13233343"
    expect(struct.pack).to eq data
  end

  ['n', 'N', 'S>', 'L>', 'I>'].each do |fmt|
    it "unpacks unsigned big-endian '#{fmt}'" do
      a = [12345]
      data = a.pack(fmt)
      x = IOStruct.new(fmt, :x).read(data)
      expect(x.x).to eq a[0]
      expect(x.pack).to eq data
    end
  end

  ['v', 'V', 'S<', 'L<', 'I<'].each do |fmt|
    it "unpacks unsigned little-endian '#{fmt}'" do
      a = [12345]
      data = a.pack(fmt)
      x = IOStruct.new(fmt, :x).read(data)
      expect(x.x).to eq a[0]
      expect(x.pack).to eq data
    end
  end

  it "throws exception on unknown format" do
    expect { IOStruct.new('K', :x) }.to raise_error('Unknown field type "K"')
  end

  context '__offset field' do
    let(:data) { 0x100.times.to_a.pack('L*') }
    let(:io) { StringIO.new(data) }
    let(:struct) { IOStruct.new('LLLL', :a, :b, :c, :d) }

    context 'when src is an IO' do
      it 'is set to the current IO position' do
        a = []
        while !io.eof?
          a << struct.read(io)
        end
        expect(a.map(&:__offset)).to eq (0...0x400).step(0x10).to_a
      end
    end

    context 'when src is a string' do
      it 'is nil' do
        x = struct.read(data)
        expect(x.__offset).to be_nil
      end
    end
  end

  describe "to_table" do
    context "when inspect is :hex" do
      it "formats signed struct as table" do
        signed_struct = IOStruct.new('c s i q', inspect: :hex)
        expect(signed_struct.new.to_table).to eq(
          "<struct f0= 0 f1=   0 f3=       0 f7=               0>"
        )
        expect(signed_struct.read("\xff"*16).to_table).to eq(
          "<struct f0=ff f1=ffff f3=ffffffff f7=ffffffffffffffff>"
        )
      end

      it "formats unsigned struct as table" do
        unsigned_struct = IOStruct.new('C S I Q', inspect: :hex)
        expect(unsigned_struct.new.to_table).to eq(
          "<struct f0= 0 f1=   0 f3=       0 f7=               0>"
        )
        expect(unsigned_struct.read("\xff"*16).to_table).to eq(
          "<struct f0=ff f1=ffff f3=ffffffff f7=ffffffffffffffff>"
        )
      end

      it "works with unknown types" do
        struct = IOStruct.new('C', :a, :name, inspect: :hex)
        s = struct.new
        expect(s.to_table).to eq(
          "<struct a= 0 name=nil>"
        )
        s.name = "test"
        expect(s.to_table).to eq(
          '<struct a= 0 name="test">'
        )
      end
    end

    context "when inspect is not :hex" do
      it "formats signed struct as table" do
        signed_struct = IOStruct.new('c s i q', inspect: :dec)
        expect(signed_struct.new.to_table).to eq(
          "<struct f0=   0 f1=     0 f3=          0 f7=                   0>"
        )
        expect(signed_struct.read("\xff"*16).to_table).to eq(
          "<struct f0=  -1 f1=    -1 f3=         -1 f7=                  -1>"
        )
        expect(signed_struct.read("\x80\x00\x80\x00\x00\x00\x80\x00\x00\x00\x00\x00\x00\x00\x80").to_table).to eq(
          "<struct f0=-128 f1=-32768 f3=-2147483648 f7=-9223372036854775808>"
        )
      end

      it "formats unsigned struct as table" do
        unsigned_struct = IOStruct.new('C S I Q', inspect: :dec)
        expect(unsigned_struct.new.to_table).to eq(
          "<struct f0=   0 f1=     0 f3=          0 f7=                   0>"
        )
        expect(unsigned_struct.read("\xff"*16).to_table).to eq(
          "<struct f0= 255 f1= 65535 f3= 4294967295 f7=18446744073709551615>"
        )
      end

      it "works with unknown types" do
        struct = IOStruct.new('C', :a, :name, inspect: :dec)
        s = struct.new
        expect(s.to_table).to eq(
          "<struct a=   0 name=nil>"
        )
        s.name = "test"
        expect(s.to_table).to eq(
          '<struct a=   0 name="test">'
        )
      end
    end
  end
end
