-- Extra utilities for reading byte ranges
memoryrange = {}

-- Reads a little-endian byte range and converts it to an unsigned int
function memoryrange.readbytesUnsigned(address, length)
    local bytes = memory.readbyterange(address, length)
    local val = 0
    for i = #bytes, 1, -1 do
        val = 256*val + bytes[i]
    end
    return val
end

-- Reads a little-endian byte range and converts it to a signed int
function memoryrange.readbytesSigned(address, length)
    local unsigned = memoryrange.readbytesUnsigned(address, length)
    local lastbit = 2^(8*length - 1)
    local signed = AND(lastbit - 1, unsigned)
    return (AND(lastbit, unsigned) == 0) and signed or -signed
end

return memoryrange