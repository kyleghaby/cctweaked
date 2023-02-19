local component = require("component")
local computer = require("computer")
local event = require("event")
local os = require("os")
local gpu = component.gpu
local tp = component.telepad
local io = require("io")
local Serial = require("serialization")
local term=require("term")
local thread = require("thread")

gpu.setResolution(56,30)
w,h=gpu.getResolution()

local function logTeleport(infoMsg)
    local logFile = io.open("teleport_log.txt", "a")
    logFile:write(infoMsg)
    logFile:flush()
    logFile:close()
end

local function displayTeleportLog()

    local logFile = io.open("teleport_log.txt", "r")
    if logFile == nil then
        return
    end
    local logText = logFile:read("*all")
    logFile:close()
    print(logText)
end

local function getRowText(y,w)
    local rowText=""
    for x=1,w,1 do 
        local char=gpu.get(x,y)
        rowText=rowText..char
    end
    return rowText
end

local function highlightRow(color,y,rowText)
    --needs color as hex eg 0x000000
    gpu.setBackground(color)
    gpu.set(1,y,rowText)
    gpu.setBackground(0x000000)
end

local function changeBackground(color,w,h)
    --needs color as hex eg 0x000000
    gpu.setBackground(color)
    for row=1,h,1 do
        local rowText=getRowText(row,w)
        gpu.set(1,row,rowText)
    end
end


local function extractCoords(infoMsg)
    local startIndex, endIndex = string.find(infoMsg, "%b{}")
    local coords = string.sub(infoMsg, startIndex, endIndex)
    return Serial.unserialize(coords)
end
    
local function extractDimension(infoMsg)
    local _, endIndex = string.find(infoMsg, "Dim")
    local dim = string.sub(infoMsg, endIndex + 2)
    return tonumber(dim)
end
   
local function dragonRow(w)
    gpu.setBackground(0xFF0000) -- set background color to red
    gpu.fill(1, 1, w, 1, " ") -- fill the first row with red background

    local message = "SNEAK+RMB FOR NEW CHAOS ISLAND"
    local x = math.floor(w / 2 - string.len(message) / 2 + 1) -- center the message
    gpu.set(x, 1, message) -- set the message in the first row
    gpu.setBackground(0x000000)
end

local function getNewIsland()
    local newCoords={10000,100,0} --starting coords
    local logFile = io.open("teleport_log.txt", "r")
    if logFile then
        for line in logFile:lines() do
            local coords=extractCoords(infoMsg)
            if newCoords==coords then
                while newCoords[1]==coords[1] do
                    newCoords[1]=newCoords[1]+10000
                end
            end
        end
        logFile:close()
    end
    return newCoords
end

local touchThread=thread.create(function()
    while true do 
        local _, _, x, y = event.pull("touch")
        -- code to handle screen touch
        if x and y then
            changeBackground(0x000000,w,h)
            local rowText = getRowText(y,w)
            if string.find(rowText,"TP to") then
                highlightRow(0x3C5B72,y,rowText)
                dragonRow(w)
                local coords = extractCoords(rowText)
                local dim = extractDimension(rowText)
                tp.setCoords(coords[1],coords[2],coords[3])
                tp.setDimension(dim)
            elseif string.find(rowText,"CHAOS") then
                local coords=getNewIsland()
                highlightRow(0x3C5B72,y,rowText)
                tp.setCoords(coords[1],coords[2],coords[3])
                tp.setDimension(1) --end dim
            else
                dragonRow(w)
            end
        end 
        os.sleep()
    end
end)

gpu.setBackground(0x000000)
gpu.setForeground(0xFFFFFF)
gpu.fill(1, 1, w, h, " ") -- clears the screen
dragonRow(w)
term.setCursor(1, 2)
displayTeleportLog()
while true do
    if tp.getProgress() > 0 then
        changeBackground(0x000000,w,h)
        local coords = Serial.serialize({tp.getCoords()})
        local dim = tostring(tp.getDimension())
        local infoMsg = os.date()..": TP to "..coords.." in Dim "..dim
        print(infoMsg)
        dragonRow(w)
        logTeleport(infoMsg.."\n")
    end
    os.sleep()
end


