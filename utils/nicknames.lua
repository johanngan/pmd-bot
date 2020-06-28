-- Mess with Pokemon nicknames

require 'string'
require 'utils.scriptexit'

nicknames = {}

-- Gets the nickname of the leader
local maxNameLength = 10
local nameAddr = 0x022B51AA
function nicknames.getLeaderNickname()
    local bytestr = memory.readbyterange(nameAddr, maxNameLength)
    local name = ''
    for _, byte in ipairs(bytestr) do
        if byte == 0x00 then break end -- Early null terminator
        name = name .. string.char(byte)
    end
    return name
end

-- Sets the nickname of the leader. If name is more than 10 characters,
-- characters past the 10th are ignored
function nicknames.setLeaderNickname(name)
    for i=1,maxNameLength do
        local byte = string.byte(name, i)
        memory.writebyte(nameAddr+i-1, byte or 0x00)
    end
end

-- Temporarily set the nickname of the leader while the bot is running.
function nicknames.setLeaderNicknameTemp(name)
    local leaderName = nicknames.getLeaderNickname()
    nicknames.setLeaderNickname(name)
    scriptexit.registerexit(function() nicknames.setLeaderNickname(leaderName) end)
end

return nicknames