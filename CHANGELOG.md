# 0.3.0

 - added `__offset` field:
    
    ```ruby
    X = IOStruct.new('LL')
    io = StringIO.new('x'*1000)
    X.read(io).__offset # => 0
    X.read(io).__offset # => 8
    X.read(io).__offset # => 16
    ```
