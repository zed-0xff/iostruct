require 'spec_helper'
require 'stringio'

describe IOStruct do
  describe "#pack" do
    it "serializes struct back to binary" do
      struct = described_class.new('L S C', :a, :b, :c)
      obj = struct.new(a: 0x12345678, b: 0xABCD, c: 0xEF)
      expect(obj.pack).to eq [0x12345678, 0xABCD, 0xEF].pack('L S C')
    end

    it "round-trips correctly" do
      struct = described_class.new('L S C', :a, :b, :c)
      data = [123, 456, 78].pack('L S C')
      obj = struct.read(data)
      expect(obj.pack).to eq data
    end
  end

  describe "#empty?" do
    let(:struct) { described_class.new('L S', :a, :b) }

    it "returns true when all fields are zero" do
      expect(struct.new(a: 0, b: 0)).to be_empty
    end

    it "returns true when all fields are nil" do
      expect(struct.new).to be_empty
    end

    it "returns false when any field is non-zero" do
      expect(struct.new(a: 1, b: 0)).not_to be_empty
    end

    it "returns true for null-filled strings" do
      str_struct = described_class.new('a4', :name)
      expect(str_struct.new(name: "\x00\x00\x00\x00")).to be_empty
    end

    it "returns false for non-empty strings" do
      str_struct = described_class.new('a4', :name)
      expect(str_struct.new(name: "test")).not_to be_empty
    end
  end

  describe "#inspect" do
    [nil, "MyClass"].each do |struct_name|
      context "when struct_name is #{struct_name.inspect}" do
        [:hex, :dec].each do |inspect_mode|
          context "when inspect is :#{inspect_mode}" do
            context "for IOStruct" do
              it "shows default struct name" do
                struct = described_class.new('L S C', :a, :b, :c, inspect: inspect_mode, struct_name: struct_name)
                cname = struct_name || "struct"
                expect(struct.new.inspect).to match(/<#{cname} a=/)
              end
            end

            context "for IOStruct anonymous subclass" do
              it "shows default struct name" do
                struct = Class.new( described_class.new('L S C', :a, :b, :c, inspect: inspect_mode, struct_name: struct_name) )
                cname = struct_name || "struct"
                expect(struct.new.inspect).to match(/<#{cname} a=/)
              end
            end

            context "for named IOStruct subclass" do
              it "shows custom struct name" do
                stub_const("C1", described_class.new('L S C', :a, :b, :c, inspect: inspect_mode, struct_name: struct_name) )
                cname = struct_name || "C1"
                expect(C1.new.inspect).to match(/<#{cname} a=/)
              end
            end
          end
        end
      end
    end
  end

  describe "hash-style initialization" do
    let(:struct) { described_class.new('L S C', :a, :b, :c) }

    it "initializes fields by name" do
      obj = struct.new(a: 100, c: 50)
      expect(obj.a).to eq 100
      expect(obj.b).to be_nil
      expect(obj.c).to eq 50
    end
  end

  describe "auto-generated field names" do
    it "generates names based on offset" do
      struct = described_class.new('C S L')
      expect(struct.members).to eq [:f0, :f1, :f3]
    end
  end

  describe "field renaming" do
    it "renames auto-generated fields via kwargs" do
      struct = described_class.new('C S L', f0: :byte_field, f3: :long_field)
      expect(struct.members).to eq [:byte_field, :f1, :long_field]
    end

    it "renames named fields via kwargs" do
      struct = described_class.new('C S L', :a, :b, :c, a: :first, c: :last)
      expect(struct.members).to eq [:first, :b, :last]
    end
  end

  describe "float types" do
    it "unpacks single-precision float (f/F)" do
      data = [3.14159].pack('f')
      struct = described_class.new('f', :val)
      expect(struct.read(data).val).to be_within(0.0001).of(3.14159)
      expect(struct::SIZE).to eq 4
    end

    it "unpacks double-precision float (d/D)" do
      data = [3.141592653589793].pack('d')
      struct = described_class.new('d', :val)
      expect(struct.read(data).val).to be_within(0.0000001).of(3.141592653589793)
      expect(struct::SIZE).to eq 8
    end

    it "unpacks little-endian floats (e/E)" do
      data = [2.5].pack('e')
      struct = described_class.new('e', :val)
      expect(struct.read(data).val).to be_within(0.0001).of(2.5)
    end

    it "unpacks big-endian floats (g/G)" do
      data = [2.5].pack('G')
      struct = described_class.new('G', :val)
      expect(struct.read(data).val).to be_within(0.0001).of(2.5)
    end

    it "formats floats in to_table" do
      struct = described_class.new('f', :val)
      obj = struct.new(val: 3.14159)
      expect(obj.to_table).to match(/val=\s*3\.142/)
    end
  end

  describe "signed integer types" do
    it "reads signed 8-bit (c)" do
      struct = described_class.new('c', :val)
      expect(struct.read("\x80").val).to eq(-128)
      expect(struct.read("\x7f").val).to eq(127)
    end

    it "reads signed 16-bit (s)" do
      struct = described_class.new('s', :val)
      expect(struct.read("\x00\x80").val).to eq(-32768)
    end

    it "reads signed 32-bit (i)" do
      struct = described_class.new('i', :val)
      expect(struct.read("\x00\x00\x00\x80").val).to eq(-2147483648)
    end

    it "reads signed 64-bit (q)" do
      struct = described_class.new('q', :val)
      expect(struct.read("\x00\x00\x00\x00\x00\x00\x00\x80").val).to eq(-9223372036854775808)
    end
  end

  describe "string types" do
    it "unpacks space-padded string (A)" do
      struct = described_class.new('A8', :name)
      obj = struct.read("hello   ")
      expect(obj.name).to eq "hello"
    end

    it "unpacks null-terminated string (Z)" do
      struct = described_class.new('Z8', :name)
      obj = struct.read("hello\x00\x00\x00")
      expect(obj.name).to eq "hello"
    end

    it "unpacks raw string (a)" do
      struct = described_class.new('a8', :name)
      obj = struct.read("hello\x00\x00\x00")
      expect(obj.name).to eq "hello\x00\x00\x00"
    end
  end

  describe "error handling" do
    it "raises when no fmt and no :fields" do
      expect { described_class.new }.to raise_error(/no fmt and no :fields/)
    end

    it "raises when reading from unsupported source" do
      struct = described_class.new('L', :val)
      expect { struct.read(12345) }.to raise_error(/don't know how to read/)
    end
  end

  describe "inspect_name_override (deprecated)" do
    it "works as alias for struct_name" do
      struct = described_class.new('L', :val, inspect_name_override: 'MyStruct')
      expect(struct.new.inspect).to match(/<MyStruct/)
    end
  end

  describe ":name" do
    context "when set" do
      it "uses the custom name" do
        x = described_class.new('LL', :x, :y, struct_name: 'Point')
        expect(x.new.inspect).to match(/<Point x=nil y=nil>/)
      end
    end

    context "when not set" do
      it "has default name" do
        x = described_class.new('LL', :x, :y)
        expect(x.new.inspect).to match(/<struct x=nil y=nil>/)
      end
    end
  end

  describe "read" do
    let(:a) { [12345, 56789] }
    let(:data) { a.pack('L2') }

    it "reads from IO" do
      x = described_class.new('LL', :x, :y).read(StringIO.new(data))
      expect(x.x).to eq a[0]
      expect(x.y).to eq a[1]
    end

    it "reads from String" do
      x = described_class.new('LL', :x, :y).read(data)
      expect(x.x).to eq a[0]
      expect(x.y).to eq a[1]
    end

    it "creates a new instance of a subclass" do
      klass = Class.new( described_class.new('LL', :x, :y) )
      x = klass.read(data)
      expect(x).to be_a klass
    end
  end

  context "zero-length strings" do
    let(:data) { [1, 2].pack('CC') }
    let(:struct) { described_class.new('C a0 C', :a, :b, :c) }

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
      io = StringIO.new(data * 2)
      struct.read(io)
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
    x = described_class.new('x4L', :y).read(data)
    expect(x.y).to eq a[1]
  end

  it "unpacks hex-string (H)" do
    data = "1234"
    struct = described_class.new('H8', :x).read(data)
    expect(struct.x).to eq "31323334"
    expect(struct.pack).to eq data
  end

  it "unpacks reverse-nibbled hex-string (h)" do
    data = "1234"
    struct = described_class.new('h8', :x).read(data)
    expect(struct.x).to eq "13233343"
    expect(struct.pack).to eq data
  end

  # rubocop:disable RSpec/RepeatedExample
  ['n', 'N', 'S>', 'L>', 'I>'].each do |fmt|
    it "unpacks unsigned big-endian '#{fmt}'" do
      a = [12345]
      data = a.pack(fmt)
      x = described_class.new(fmt, :x).read(data)
      expect(x.x).to eq a[0]
      expect(x.pack).to eq data
    end
  end

  ['v', 'V', 'S<', 'L<', 'I<'].each do |fmt|
    it "unpacks unsigned little-endian '#{fmt}'" do
      a = [12345]
      data = a.pack(fmt)
      x = described_class.new(fmt, :x).read(data)
      expect(x.x).to eq a[0]
      expect(x.pack).to eq data
    end
  end
  # rubocop:enable RSpec/RepeatedExample

  it "throws exception on unknown format" do
    expect { described_class.new('K', :x) }.to raise_error('Unknown field type "K"')
  end

  context '__offset field' do
    let(:data) { 0x100.times.to_a.pack('L*') }
    let(:io) { StringIO.new(data) }
    let(:struct) { described_class.new('LLLL', :a, :b, :c, :d) }

    context 'when src is an IO' do
      it 'is set to the current IO position' do
        a = []
        a << struct.read(io) until io.eof?
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
        signed_struct = described_class.new('c s i q', inspect: :hex)
        expect(signed_struct.new.to_table).to eq(
          "<struct f0= 0 f1=   0 f3=       0 f7=               0>"
        )
        expect(signed_struct.read("\xff" * 16).to_table).to eq(
          "<struct f0=ff f1=ffff f3=ffffffff f7=ffffffffffffffff>"
        )
      end

      it "formats unsigned struct as table" do
        unsigned_struct = described_class.new('C S I Q', inspect: :hex)
        expect(unsigned_struct.new.to_table).to eq(
          "<struct f0= 0 f1=   0 f3=       0 f7=               0>"
        )
        expect(unsigned_struct.read("\xff" * 16).to_table).to eq(
          "<struct f0=ff f1=ffff f3=ffffffff f7=ffffffffffffffff>"
        )
      end

      it "works with unknown types" do
        struct = described_class.new('C', :a, :name, inspect: :hex)
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
        signed_struct = described_class.new('c s i q', inspect: :dec)
        expect(signed_struct.new.to_table).to eq(
          "<struct f0=   0 f1=     0 f3=          0 f7=                   0>"
        )
        expect(signed_struct.read("\xff" * 16).to_table).to eq(
          "<struct f0=  -1 f1=    -1 f3=         -1 f7=                  -1>"
        )
        expect(signed_struct.read("\x80\x00\x80\x00\x00\x00\x80\x00\x00\x00\x00\x00\x00\x00\x80").to_table).to eq(
          "<struct f0=-128 f1=-32768 f3=-2147483648 f7=-9223372036854775808>"
        )
      end

      it "formats unsigned struct as table" do
        unsigned_struct = described_class.new('C S I Q', inspect: :dec)
        expect(unsigned_struct.new.to_table).to eq(
          "<struct f0=   0 f1=     0 f3=          0 f7=                   0>"
        )
        expect(unsigned_struct.read("\xff" * 16).to_table).to eq(
          "<struct f0= 255 f1= 65535 f3= 4294967295 f7=18446744073709551615>"
        )
      end

      it "works with unknown types" do
        struct = described_class.new('C', :a, :name, inspect: :dec)
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
