local component = require("component")
local transforms = require("transforms")
local computer = require("computer")
local filesystem = require("filesystem")
local os = require("os")
local Serial = require("serialization")
local math = require("math")
local gpu = component.gpu

local basew,baseh=160,50
gpu.setResolution(basew/2,baseh/2)
local w, h = gpu.getResolution()
local ME = component.me_interface
local refreshtime=1 --s
local item_table={}
local i=""
local name=""
local id = ""
local damage=""
local new_size=0
local new_dsize=0
local d2size=0
local last_update = computer.uptime() 
local initial=true
local stats_fh=""
local stats_alltime_table={}
local stats_timestep_table={}
local si=""
local sq=0
local alltimechanged=False
local xcolors = {           
    red = 0xFF0000,
    lime = 0x00FF00,
    blue = 0x0000FF,
    magenta = 0xFF00FF,
    yellow = 0xFFFF00,
    cyan = 0x00FFFF,
    greenYellow = 0xADFF2F,
    green = 0x008000,
    darkOliveGreen = 0x556B2F,
    indigo = 0x4B0082,
    purple = 0x800080,
    electricBlue = 0x00A6FF,
    dodgerBlue = 0x1E90FF,
    steelBlue = 0x4682B4,
    darkSlateBlue = 0x483D8B,
    midnightBlue = 0x191970,
    darkBlue = 0x000080,
    darkOrange = 0xFFA500,
    rosyBrown = 0xBC8F8F,
    golden = 0xDAA520,
    maroon = 0x800000,
    black = 0x000000,
    white = 0xFFFFFF,
    gray = 0x3C5B72,
    lightGray = 0xA9A9A9,
    darkGray = 0x181828,
    darkSlateGrey = 0x2F4F4F
}

local function max(t, colname) --gets max of a column
    local function fn(a,b) return a < b end
    local key, value = initial, -9999999999
    for k, v in pairs(t) do 
        if v[colname] > value then
            key, value = k, v[colname]
        end
    end
    return key, value
end

local function min(t, colname) --gets max of a column
    local function fn(a,b) return a < b end
    local key, value = initial, 9999999999
    for k, v in pairs(t) do 
        if v[colname] < value then
            key, value = k, v[colname]
        end
    end
    return key, value
end

local function initializeTable(nascent)
   
    nascent['Max x']={statitem='initial',statquant=0}
    nascent['Max Dx']={statitem='initial',statquant=0}
    nascent['Min Dx']={statitem='initial',statquant=0}
    nascent['Max DDx']={statitem='initial',statquant=0}
    nascent['Min DDx']={statitem='initial',statquant=0}
    return nascent
end

--read/make stats_alltime file
if not filesystem.exists("stats_alltime.dat") then
    
    --make initial table
    initializeTable(stats_alltime_table)
    
    --save it to file
    stats_alltime_fh = io.open("stats_alltime.dat","w")
    stats_alltime_fh:write(Serial.serialize(stats_alltime_table))
    stats_alltime_fh:close()
    
else
    --read in table
    stats_alltime_fh = io.open("stats_alltime.dat","r")
    stats_alltime_table = Serial.unserialize(stats_alltime_fh:read())
    stats_alltime_fh:close()
end

--make initial timestep table
initializeTable(stats_timestep_table)


--initial graphics. assumes 160x50 (5x3 screens) base resolution
gpu.fill(1, 1, w, h, " ") --clear screen 
--draw partitions
gpu.setBackground(xcolors.electricBlue)
gpu.fill(1, h/2-2, w, 1, " ") 
gpu.setBackground(xcolors.golden)
gpu.fill(w/2, 1, 1, h/2-1, " ")
gpu.setBackground(xcolors.rosyBrown)
gpu.fill(w/2+1, 1, 1, h/2-1, " ")
gpu.setBackground(xcolors.black)

gpu.setForeground(xcolors.golden)
gpu.set((w/4)-4,1,"All Time")
gpu.setForeground(xcolors.rosyBrown)
local timestepTitle=refreshtime.." s"
gpu.set((3*w/4)-(math.floor(#timestepTitle/2)),1,timestepTitle)
gpu.setForeground(xcolors.lightGray)


--run main cycle
while true do
    if computer.uptime() - last_update > refreshtime or initial then
        --print("Refreshing")
        local last_update = computer.uptime()
        local total_types=#ME.getItemsInNetwork()
        local item_iter=ME.allItems()
        --iterate through items
        for n = 1, total_types, 1 do
            i=item_iter()
            if not i then
                break
            end
            name=i.label
            damage=i.damage
            id=name..'('..damage..')'
            new_size=i.size
            if item_table[id] then
                --get old x from last cycle
                if item_table[id].size then
                    old_size=item_table[id].size
                else
                    old_size=new_size
                end
                new_dsize=new_size - old_size
                --get old dx from last cycle
                if item_table[id].dsize then
                    old_dsize=item_table[id].dsize
                else
                    old_dsize=new_dsize
                end
                d2size=new_dsize - old_dsize
            else
                new_dsize=0
                d2size=0
            end
            item_table[id]={size=new_size, dsize=new_dsize, d2size=d2size}
            --if id == 'Plastic Circuit Board(32106)' then
            --    stats_fh:write(id,'       ', new_size,'       ', new_dsize,'       ', d2size,'\n')
            --end
            
        end
        initial=false
        
        --assign highest values to timestep stats
        
        si,sq=max(item_table, size)
        stats_timestep_table['Max x']={statitem=si,statquant=sq}
        si,sq=max(item_table, dsize)
        stats_timestep_table['Max Dx']={statitem=si,statquant=sq}
        si,sq=min(item_table, dsize)
        stats_timestep_table['Min Dx']={statitem=si,statquant=sq}
        si,sq=max(item_table, d2size)
        stats_timestep_table['Max DDx']={statitem=si,statquant=sq}
        si,sq=min(item_table, d2size)
        stats_timestep_table['Min DDx']={statitem=si,statquant=sq}
        
        --assign highest values to alltime stats if necessary
        for k,v in pairs(stats_timestep_table) do 
            if string.find(k,"Max") then
                if stats_timestep_table[k].statquant > stats_alltime_table[k].statquant then
                    stats_alltime_table[k] = stats_timestep_table[k]
                    alltimechanged=True
                end
            elseif string.find(k,"Min") then
                if stats_timestep_table[k].statquant < stats_alltime_table[k].statquant then
                    stats_alltime_table[k] = stats_timestep_table[k]
                    alltimechanged=True
                end
            end
        end
        
        if alltimechanged then
            stats_alltime_fh = io.open("stats_alltime.dat","w")
            stats_alltime_fh:write(Serial.serialize(stats_alltime_table))
            stats_alltime_fh:close()
        end

        
    --display timestep and alltime tables
        
        
     end
--    print(computer.uptime() - last_update)
    os.sleep(refreshtime)
 end
    

--get stats (from file)


