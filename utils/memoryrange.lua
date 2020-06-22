-- Extra utilities for reading bytes
memoryrange = {}

-- Converts a little-endian byte range to an unsigned int
function memoryrange.bytesToUnsigned(bytes)
    local val = 0
    for i = #bytes, 1, -1 do
        val = 256*val + bytes[i]
    end
    return val
end

-- Converts an n-byte unsigned to signed, assuming the last bit is the sign bit
function memoryrange.unsignedToSigned(unsigned, n)
    local lastbit = 2^(8*n - 1)
    local signed = AND(lastbit - 1, unsigned)
    return signed - math.abs(AND(lastbit, unsigned))
end

-- Converts a little-endian byte range to a signed int
function memoryrange.bytesToSigned(bytes)
    return memoryrange.unsignedToSigned(memoryrange.bytesToUnsigned(bytes), #bytes)
end

-- Reads a little-endian byte range and converts it to an unsigned int
function memoryrange.readbytesUnsigned(address, length)
    return memoryrange.bytesToUnsigned(memory.readbyterange(address, length))
end

-- Reads a little-endian byte range and converts it to a signed int
function memoryrange.readbytesSigned(address, length)
    return memoryrange.bytesToSigned(memory.readbyterange(address, length), length)
end

return memoryrange