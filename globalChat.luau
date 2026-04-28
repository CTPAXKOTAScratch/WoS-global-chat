--[[MBEE_HEADER__DO_NOT_EDIT]]
if game then
	PilotLua = require(game.ReplicatedStorage.PilotLua)
	Beep, FileSystem, GetCPUTime, GetPart, GetPartFromPort, GetParts, GetPartsFromPort, GetPort, GetPorts, JSONDecode, JSONEncode, Microcontroller, Network, RawFileSystem, SandboxID, SandboxRunID, TriggerPort, logError, pilot = PilotLua()
end
--[[MBEE_HEADER__DO_NOT_EDIT]]

local screen = assert(Network:GetPart("Screen") or Network:GetPart("TouchScreen"), "no screen connected")
local keyboard = assert(Network:GetPart("Keyboard"), "no keyboard connected")
local modem = assert(Network:GetPart("Modem"), "no modem connected")

-- Alphabet order MUST match font atlas image grid
local alphabet = [[abcdefghijklmnopqrstuvwxyz0123456789.,:;/-+%()!?=<>'"_#@&*[]{}~ $\\^`|■]]

-- Precompute character positions
local charPositions = {}
for i = 1, #alphabet do
    charPositions[alphabet:sub(i, i)] = i
end

-- Grid settings
local columns = 10
local letterWidth = 38
local letterHeight = 64
local scale = 0.25
local scrollOffset = 0
local couX = 0
local couY = 0

screen:ClearElements()

local outerCanvas = screen:GetCanvas()
local absoluteCanvasSize = outerCanvas.AbsoluteSize

local canvas = Instance.new("Frame")
canvas.Size = UDim2.new(0, absoluteCanvasSize.X - 50, 0, absoluteCanvasSize.Y)
canvas.BackgroundColor3 = Color3.new(0, 0, 0)
canvas.Parent = outerCanvas

local canvasSize = canvas.AbsoluteSize

function StampCharacter(chara)
    if not chara then return end
    if chara == " " then
        couX = couX + letterWidth
        return
    end
    
    local posl = charPositions[chara]
    if not posl then
        print("Character not in font atlas: " .. chara)
        return
    end
    posl = posl - 1
    
    local x = posl % columns
    local y = math.floor(posl / columns)
    
    local ImageLabel = Instance.new("ImageLabel")
    ImageLabel.Image = "rbxassetid://76229246862262"
    ImageLabel.Position = UDim2.new(0, couX * scale, 0, (couY * scale) + scrollOffset)
    ImageLabel.ImageColor3 = Color3.fromRGB(255, 255, 255)
    ImageLabel.ImageRectOffset = Vector2.new(x * letterWidth, y * letterHeight)
    ImageLabel.ImageRectSize = Vector2.new(letterWidth, letterHeight)
    ImageLabel.Size = UDim2.new(0, letterWidth * scale, 0, letterHeight * scale)
    ImageLabel.ScaleType = Enum.ScaleType.Stretch
    ImageLabel.BorderSizePixel = 0
    ImageLabel.BackgroundTransparency = 1
    ImageLabel.Parent = canvas
    
    couX = couX + letterWidth
    
    if couX + letterWidth > canvasSize.X / scale then
        couX = 0
        couY = couY + letterHeight
    end
end

function EndLine()
    couY = couY + letterHeight
    couX = 0
end

function ClearScreen()
    couY = 0
    couX = 0
    for _, child in ipairs(canvas:GetChildren()) do
        child:Destroy()
    end
end

function Scroll(offset)
    scrollOffset = scrollOffset + offset
    for _, child in ipairs(canvas:GetChildren()) do
        local p = child.Position
        if p then
            child.Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset + offset)
        end
    end
end

function Console(text)
    text = string.lower(text)
    for i = 1, #text do
        local c = text:sub(i, i)
        if c == "\n" then
            EndLine()
        else
            StampCharacter(c)
        end
    end
end

-- Scroll buttons
local scrollUpButton = Instance.new("TextButton")
scrollUpButton.Position = UDim2.new(0, absoluteCanvasSize.X - 50, 0, 0)
scrollUpButton.Size = UDim2.new(0, absoluteCanvasSize.X - 50, 0.5, 0)
scrollUpButton.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
scrollUpButton.Text = "▲"
scrollUpButton.Parent = outerCanvas

local scrollDownButton = Instance.new("TextButton")
scrollDownButton.Position = UDim2.new(0, absoluteCanvasSize.X - 50, 0.5, 0)
scrollDownButton.Size = UDim2.new(0, absoluteCanvasSize.X - 50, 0.5, 0)
scrollDownButton.BackgroundColor3 = Color3.new(0.5, 0.5, 0.5)
scrollDownButton.Text = "▼"
scrollDownButton.Parent = outerCanvas

scrollUpButton.MouseButton1Click:Connect(function()
    Scroll((letterHeight * scale) * 0.75)
end)
scrollDownButton.MouseButton1Click:Connect(function()
    Scroll(-(letterHeight * scale) * 0.75)
end)

local justSent = ""
local justReceived = ""

-- Command handler
keyboard.TextInputted:Connect(function(input)
    input = input:gsub("\n$", "")
    if input == "" then return end
    
    local space = input:find(" ")
    local cmd, arg
    if space then
        cmd = input:sub(1, space - 1):lower()
        arg = input:sub(space + 1)
    else
        cmd = input:lower()
    end
    
    if cmd == "channel" and arg then
        modem.NetworkID = arg
        Console("Set modem channel to " .. arg)
    elseif cmd == "localmsg" and arg then
        modem:SendLocalMessage(arg)
        justSent = arg
        Console("[LOCALMSG] " .. arg .. "\n")
    elseif cmd == "help" then
        Console("commands:\n  localmsg: local server message (NOT GLOBAL) \n channel: change modem channel (global chat channel) \n")
    else
        Console("[SENT] " .. input .. "\n")
        justSent = input
        modem:SendMessage(input)
    end
end)

modem.MessageSent:Connect(function(msg)
    local str = tostring(msg)
    if str then
        if str == justSent then
            local oldJsent = justSent
            task.delay(0.5, function()
                if oldJsent == justSent then
                    justSent = ""
                end
            end)
            return
        elseif justReceived == str then
            return
        else
            justReceived = str
            local oldJsRec = justReceived
            task.delay(0.5, function()
                if oldJsRec == justReceived then
                    justSent = ""
                end
            end)
        end
        justReceived = str
        Console("[RECEIVED] " .. str .. "\n")
    else
        Console("Error occured stringing message")
    end
end)

Console("Global chat (prototype)\n 'help' for cmds, just print to send\n")

coroutine.yield()
