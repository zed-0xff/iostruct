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

  it "skips on 'x'" do
    a = [12345, 56789]
    data = a.pack('L2')
    x = IOStruct.new('x4L', :y).read(data)
    expect(x.y).to eq a[1]
  end

  it "unpacks big-endian" do
    a = [12345, 56789]
    data = a.pack('nN')
    x = IOStruct.new('nN', :x, :y).read(data)
    expect(x.x).to eq a[0]
    expect(x.y).to eq a[1]
  end

  it "unpacks little-endian" do
    a = [12345, 56789]
    data = a.pack('vV')
    x = IOStruct.new('vV', :x, :y).read(data)
    expect(x.x).to eq a[0]
    expect(x.y).to eq a[1]
  end

  it "throws exception on unknown format" do
    expect { IOStruct.new('K', :x) }.to raise_error('Unknown fmt "K"')
  end
end
