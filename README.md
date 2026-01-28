# IOStruct

A Ruby Struct that can read/write itself from/to IO-like objects. Perfect for parsing binary file formats, network protocols, and other structured binary data.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'iostruct'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install iostruct
```

## Usage

### Basic Usage with Pack Format

Define structs using Ruby's [pack/unpack format strings](https://ruby-doc.org/core/String.html#method-i-unpack):

```ruby
require 'iostruct'

# Define a struct with two 32-bit unsigned integers
Point = IOStruct.new('LL', :x, :y)

# Read from binary data
data = [100, 200].pack('LL')
point = Point.read(data)
point.x  # => 100
point.y  # => 200

# Write back to binary
point.pack  # => "\x64\x00\x00\x00\xC8\x00\x00\x00"
```

### Hash-Based Definition with C Types

For more readable code, define structs using C-style type names:

```ruby
Point = IOStruct.new(
  struct_name: 'Point',
  fields: {
    x: 'int',
    y: 'int',
    z: 'int',
  }
)

point = Point.read(binary_data)
point.inspect  # => "<Point x=0x64 y=0xc8 z=0x0>"
```

#### Supported C Types

| Type | Aliases | Size |
|------|---------|------|
| `uint8_t` | `unsigned char`, `_BYTE` | 1 |
| `uint16_t` | `unsigned short` | 2 |
| `uint32_t` | `unsigned int`, `unsigned` | 4 |
| `uint64_t` | `unsigned long long` | 8 |
| `int8_t` | `char`, `signed char` | 1 |
| `int16_t` | `short`, `signed short` | 2 |
| `int32_t` | `int`, `signed int`, `signed` | 4 |
| `int64_t` | `long long`, `signed long long` | 8 |
| `float` | | 4 |
| `double` | | 8 |

### Reading from IO or String

```ruby
Header = IOStruct.new('L S S', :magic, :version, :flags)

# Read from a File
File.open('binary_file', 'rb') do |f|
  header = Header.read(f)
  puts header.magic
end

# Read from a String
header = Header.read("\x7fELF\x01\x00\x00\x00")

# Track file position with __offset
io = StringIO.new(data)
record = MyStruct.read(io)
record.__offset  # => position where the record was read from
```

### Explicit Field Offsets

Specify exact byte offsets for fields (useful for structs with padding or gaps):

```ruby
MyStruct = IOStruct.new(
  fields: {
    magic: 'uint32_t',
    flags: { type: 'uint16_t', offset: 0x10 },  # starts at byte 16
    data:  { type: 'uint32_t', offset: 0x20 },  # starts at byte 32
  }
)
```

### Arrays

Define fixed-size arrays within structs:

```ruby
Matrix = IOStruct.new(
  fields: {
    rows: 'int',
    cols: 'int',
    data: { type: 'float', count: 16 },  # 16-element float array
  }
)

m = Matrix.read(binary_data)
m.data  # => [1.0, 2.0, 3.0, ...]
m.pack  # serializes back to binary
```

### Nested Structs

Compose complex structures from simpler ones:

```ruby
Point = IOStruct.new(fields: { x: 'int', y: 'int' })

Rect = IOStruct.new(
  struct_name: 'Rect',
  fields: {
    top_left: Point,
    bottom_right: Point,
  }
)

rect = Rect.read([0, 0, 100, 100].pack('i*'))
rect.top_left.x       # => 0
rect.bottom_right.x   # => 100
rect.pack             # serializes entire structure including nested structs
```

### Inspect Modes

Choose between hexadecimal (default) or decimal display:

```ruby
# Hex display (default)
HexStruct = IOStruct.new('L L', :a, :b, inspect: :hex)
HexStruct.new(a: 255, b: 256).inspect
# => "<struct a=0xff b=0x100>"

# Decimal display
DecStruct = IOStruct.new('L L', :a, :b, inspect: :dec)
DecStruct.new(a: 255, b: 256).inspect
# => "#<struct DecStruct a=255, b=256>"

# Table format for aligned output
struct.to_table
# => "<struct a=  ff b= 100>"
```

### Auto-Generated Field Names

If you don't specify field names, they're generated based on byte offset:

```ruby
s = IOStruct.new('C S L')
s.members  # => [:f0, :f1, :f3]  (offsets 0, 1, 3)
```

### Field Renaming

Rename auto-generated or explicit field names:

```ruby
# Rename auto-generated names
IOStruct.new('C S L', f0: :byte_val, f3: :long_val)

# Rename explicit names
IOStruct.new('C S L', :a, :b, :c, a: :first, c: :last)
```

## API Reference

### Class Methods

| Method | Description |
|--------|-------------|
| `IOStruct.new(fmt, *names, **options)` | Create a new struct class with pack format |
| `IOStruct.new(fields:, **options)` | Create a new struct class with hash definition |
| `IOStruct.get_type_size(typename)` | Get byte size for a C type name |
| `MyStruct.read(io_or_string)` | Read and parse binary data |
| `MyStruct.size` | Return struct size in bytes |
| `MyStruct::SIZE` | Struct size constant |
| `MyStruct::FORMAT` | Pack format string |
| `MyStruct::FIELDS` | Hash of field names to FieldInfo |

### Instance Methods

| Method | Description |
|--------|-------------|
| `#pack` | Serialize to binary string |
| `#empty?` | True if all fields are zero/nil/empty |
| `#to_table` | Formatted string with aligned values |
| `#__offset` | File position where struct was read (nil if from string) |

### Constructor Options

| Option | Description |
|--------|-------------|
| `struct_name:` | Custom name for inspect output |
| `inspect:` | `:hex` (default) or `:dec` for display format |
| `size:` | Override calculated struct size |
| `fields:` | Hash defining fields (for hash-based definition) |

## Examples

### Parsing a BMP File Header

```ruby
BMPHeader = IOStruct.new(
  struct_name: 'BMPHeader',
  fields: {
    magic:      { type: 'uint16_t' },
    file_size:  { type: 'uint32_t' },
    reserved:   { type: 'uint32_t' },
    data_offset: { type: 'uint32_t' },
  }
)

File.open('image.bmp', 'rb') do |f|
  header = BMPHeader.read(f)
  puts "File size: #{header.file_size} bytes"
  puts "Pixel data starts at: #{header.data_offset}"
end
```

### Network Protocol Packet

```ruby
Packet = IOStruct.new('n n N', :src_port, :dst_port, :sequence,
  struct_name: 'TCPHeader'
)

# Big-endian format for network byte order
packet = Packet.read(socket.read(8))
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

MIT License - see [LICENSE.txt](LICENSE.txt) for details.
