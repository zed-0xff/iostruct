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
