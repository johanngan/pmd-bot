-- Message reporting utils

messages = {}

-- Reports a message on screen until a new message is set
local MESSAGE_X = 2
local MESSAGE_Y = 183
function messages.report(text)
    gui.register(function() gui.text(MESSAGE_X, MESSAGE_Y, text) end)
end

-- Clears any messages being reported
function messages.clear()
    gui.register(nil)
end

-- Report a message if the verbose flag is true
function messages.reportIfVerbose(text, verbose)
    if verbose then messages.report(text) end
end

-- Make sure messages get cleared after the script exits
emu.registerexit(messages.clear)

return messages