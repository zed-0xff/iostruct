require 'spec_helper'
require 'stringio'

describe IOStruct do
  describe ".get_type_size" do
    it "returns size for known types" do
      expect(described_class.get_type_size('int')).to eq 4
      expect(described_class.get_type_size('char')).to eq 1
      expect(described_class.get_type_size('short')).to eq 2
      expect(described_class.get_type_size('long long')).to eq 8
      expect(described_class.get_type_size('double')).to eq 8
      expect(described_class.get_type_size('float')).to eq 4
    end

    it "works with symbol input" do
      expect(described_class.get_type_size(:int)).to eq 4
    end

    it "returns nil for unknown types" do
      expect(described_class.get_type_size('unknown')).to be_nil
    end
  end

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

    it "packs nested structs" do
      point = described_class.new(fields: { x: "int", y: :int })
      rect = described_class.new(fields: { topLeft: point, bottomRight: point })

      r = rect.read([10, 20, 100, 200].pack('i*'))
      packed = r.pack
      reparsed = rect.read(packed)

      expect(reparsed.topLeft.x).to eq 10
      expect(reparsed.topLeft.y).to eq 20
      expect(reparsed.bottomRight.x).to eq 100
      expect(reparsed.bottomRight.y).to eq 200
    end

    it "supports nested struct arrays" do
      point = described_class.new(fields: { x: "int", y: :int })
      polygon = described_class.new(
        fields: {
          num_points: 'int',
          points: { type: point, count: 3 },
        }
      )
      expect(polygon.size).to eq(4 + 8 * 3)

      data = [3, 10, 20, 30, 40, 50, 60].pack('i*')
      p = polygon.read(data)

      expect(p.num_points).to eq 3
      expect(p.points.size).to eq 3
      expect(p.points[0]).to be_instance_of(point)
      expect(p.points[0].x).to eq 10
      expect(p.points[0].y).to eq 20
      expect(p.points[1].x).to eq 30
      expect(p.points[1].y).to eq 40
      expect(p.points[2].x).to eq 50
      expect(p.points[2].y).to eq 60

      # Test round-trip
      reparsed = polygon.read(p.pack)
      expect(reparsed.points[2].y).to eq 60
    end

    it "packs arrays" do
      klass = described_class.new(
        fields: {
          x: "int",
          a: { type: 'int', count: 3 },
          y: :int,
        }
      )

      v = klass.read([1, 2, 3, 4, 5].pack('i*'))
      packed = v.pack
      reparsed = klass.read(packed)

      expect(reparsed.x).to eq 1
      expect(reparsed.a).to eq [2, 3, 4]
      expect(reparsed.y).to eq 5
    end

    context "error handling" do
      it "raises on unknown field type" do
        expect do
          described_class.new(fields: { x: "unknown_type" })
        end.to raise_error(/unknown field type/)
      end

      it "raises on invalid type format" do
        expect do
          described_class.new(fields: { x: 12345 })
        end.to raise_error(/unexpected field desc type/)
      end

      it "raises when forced size is smaller than actual" do
        expect do
          described_class.new(
            fields: { x: "int", y: "int", z: "int" },
            size: 4
          )
        end.to raise_error(/actual struct size .* is greater than forced size/)
      end
    end

    context "C type aliases" do
      it "supports uint types" do
        klass = described_class.new(fields: {
                                      a: 'uint8_t',
                                      b: 'uint16_t',
                                      c: 'uint32_t',
                                      d: 'uint64_t'
                                    })
        expect(klass.size).to eq(1 + 2 + 4 + 8)
      end

      it "supports int types" do
        klass = described_class.new(fields: {
                                      a: 'int8_t',
                                      b: 'int16_t',
                                      c: 'int32_t',
                                      d: 'int64_t'
                                    })
        expect(klass.size).to eq(1 + 2 + 4 + 8)
      end

      it "supports _BYTE type" do
        klass = described_class.new(fields: { a: '_BYTE' })
        expect(klass.size).to eq 1
        expect(klass.read("\xff").a).to eq 255 # unsigned
      end
    end
  end
end
