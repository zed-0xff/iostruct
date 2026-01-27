require 'spec_helper'
require 'stringio'

describe IOStruct do
  describe "hash format ctor" do
    it "works" do
      klass = described_class.new(
        fields: {
          x: "int",
          y: :int,
          z: { type: :int },
        },
        struct_name: 'Point'
      )
      expect(klass.new.inspect).to match(/<Point x=nil y=nil z=nil>/)
      expect(klass.size).to eq(12)
      expect(klass::SIZE).to eq(12)
    end

    it "respects :name" do
      klass = described_class.new(
        fields: {
          x: "int",
          y: :int,
          z: { type: :int },
        },
        struct_name: 'Point'
      )
      expect(klass.new.inspect).to match(/<Point x=nil y=nil z=nil>/)
    end

    it "respects :offset" do
      klass = described_class.new(
        struct_name: 'Point',
        fields: {
          x: "int",
          y: :int,
          z: { type: :int, offset: 0x10 },
        }
      )
      expect(klass.new.inspect).to match(/<Point x=nil y=nil z=nil>/)
      expect(klass.size).to eq(0x14)

      obj = klass.read((0..0x20).to_a.pack('i*'))
      expect(obj.x).to eq(0)
      expect(obj.y).to eq(1)
      expect(obj.z).to eq(4)
    end

    context 'when two fields have same offset' do
      it 'fails' do
        expect do
          described_class.new(
            struct_name: 'Point',
            fields: {
              x: { type: :int, offset: 0 },
              y: { type: :char, offset: 0 },
            }
          )
        end.to raise_error(RuntimeError)
      end
    end

    it "can override size" do
      klass = described_class.new(
        fields: {
          x: "int",
          y: :int,
          z: { type: 'int' },
        },
        size: 0x100
      )
      expect(klass.size).to eq(0x100)
    end

    it "supports arrays" do
      klass = described_class.new(
        fields: {
          x: "int",
          a: { type: 'int', count: 3 },
          y: :int,
        },
      )
      expect(klass.size).to eq(4 * 5)

      v = klass.read([1, 2, 3, 4, 5, 6, 7].pack('i*'))

      expect(v.x).to eq(1)
      expect(v.a).to eq([2, 3, 4])
      expect(v.y).to eq(5)
    end

    it "supports nesting" do
      point = described_class.new( fields: { x: "int", y: :int } )
      rect = described_class.new(
        struct_name: 'Rect',
        fields: {
          topLeft: point,
          bottomRight: point,
        }
      )
      expect(rect.size).to eq(16)

      r = rect.read([10, 20, 100, 200].pack('i*'))
      expect(r.topLeft).to be_instance_of(point)
      expect(r.bottomRight).to be_instance_of(point)
      expect(r.topLeft.x).to eq(10)
      expect(r.topLeft.y).to eq(20)
      expect(r.bottomRight.x).to eq(100)
      expect(r.bottomRight.y).to eq(200)
    end
  end
end
