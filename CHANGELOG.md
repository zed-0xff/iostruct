# 0.7.0

- added big-endian and little-endian type support in hash format:

   ```ruby
   IOStruct.new(fields: {
     be_val: 'uint16_be',  # or 'be16', 'uint16_t_be'
     le_val: 'uint32_le',  # or 'le32', 'uint32_t_le'
   })
   ```

- added nested struct arrays:

   ```ruby
   Point = IOStruct.new(fields: { x: 'int', y: 'int' })
   Polygon = IOStruct.new(fields: {
     num_points: 'int',
     points: { type: Point, count: 3 },  # array of 3 nested structs
   })
   p = Polygon.read(data)
   p.points[0].x  # access nested struct in array
   p.pack         # packing works too!
   ```

- added endian-specific float types: `float_le`, `float_be`, `double_le`, `double_be`
- improved class name handling in inspect for subclasses
- `DecInspect` now defines `to_s` for consistent behavior with `HexInspect`

# 0.6.0

- added alternative hash-based struct definition with C type names:

   ```ruby
   Point = IOStruct.new(
     struct_name: 'Point',
     fields: {
       x: 'int',
       y: :int,
       z: { type: :int, offset: 0x10 },  # explicit offset
     }
   )

   # supports nested structs
   Rect = IOStruct.new(fields: { topLeft: Point, bottomRight: Point })

   # supports arrays
   IOStruct.new(fields: { values: { type: 'int', count: 10 } })
   ```

- added `pack` support for nested structs and arrays:

   ```ruby
   r = Rect.read(data)
   r.pack  # now works!
   ```

- added `to_table` method with decimal formatting (`:inspect => :dec`)
- added `get_type_size` helper method
- deprecated `inspect_name_override` in favor of `struct_name`
- fixed `to_table` handling of unknown field types
- fixed `_BYTE` type alias (was incorrectly mapped to both signed and unsigned)
- fixed operator precedence bug in `format_integer` methods

# 0.5.0

 - added `inspect_name_override` constructor param, useful for dynamic declarations:

    ```ruby
    IOStruct.new("NN").new.inspect                                 # "<#<Class:0x000000011c45fa20> f0=nil f4=nil>"
    IOStruct.new("NN", inspect_name_override: "Point").new.inspect # "<Point f0=nil f4=nil>"
    ```

# 0.4.0

 - added `size` class method that returns SIZE constant
    
    ```ruby
    X = IOStruct.new('LL')
    X::SIZE # 8
    X.size  # 8
    ```

# 0.3.0

 - added `__offset` field:
    
    ```ruby
    X = IOStruct.new('LL')
    io = StringIO.new('x'*1000)

    X.read(io).__offset     # 0
    X.read(io).__offset     # 8
    X.read(io).__offset     # 16

    X.read('abcd').__offset # nil
    ```
