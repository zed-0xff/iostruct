require 'spec_helper'
require 'stringio'

describe IOStruct do
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

    it "has correct size" do
      expect(struct::SIZE).to eq 2
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
end
