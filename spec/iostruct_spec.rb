require 'spec_helper'
require 'stringio'

describe IOStruct do
  describe "#read" do
    it "reads from IO" do
      a = [12345,56789]
      data = a.pack('L2')
      x = IOStruct.new('LL', :x, :y).read(StringIO.new(data))
      x.x.should == a[0]
      x.y.should == a[1]
    end

    it "reads from String" do
      a = [12345,56789]
      data = a.pack('L2')
      x = IOStruct.new('LL', :x, :y).read(data)
      x.x.should == a[0]
      x.y.should == a[1]
    end
  end

  it "skips on 'x'" do
    a = [12345,56789]
    data = a.pack('L2')
    x = IOStruct.new('x4L', :y).read(data)
    x.y.should == a[1]
  end
end
