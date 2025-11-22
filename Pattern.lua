local component = require "component"
local sides = require "sides"
local filesystem = require "filesystem"

-- Configuration
local configPath = "/home/config.lua"
local shrcPath = "/home/.shrc"

-- Default values
local ITEM_BATCH_SIZE = 64
local ITEM_THRESHOLD = 128
local FLUID_BATCH_SIZE = 1
local FLUID_THRESHOLD = 1000

-- Function to automatically detect the chest
local function findChest()
    if not component.isAvailable("inventory_controller") then
        error("Inventory Controller not found!")
    end
    
    local inv = component.inventory_controller
    -- For Adapter: sides are 0-5 (not sides.top, etc)
    local allSides = {
        {name = "bottom", side = 0},
        {name = "top", side = 1},
        {name = "back", side = 2},
        {name = "front", side = 3},
        {name = "right", side = 4},
        {name = "left", side = 5}
    }
    
    print("Searching for chest on all sides...")
    for _, sideInfo in ipairs(allSides) do
        local success, size = pcall(inv.getInventorySize, sideInfo.side)
        if success and size and size > 0 then
            print("Chest found on side: " .. sideInfo.name .. " (side " .. sideInfo.side .. ")!")
            return sideInfo.side
        end
    end
    
    -- If no chest found, ask user manually
    print("\nNo chest detected automatically.")
    print("Available sides:")
    print("0 = bottom, 1 = top, 2 = back, 3 = front, 4 = right, 5 = left")
    io.write("Enter side number where chest is located: ")
    local input = io.read()
    local sideNum = tonumber(input)
    
    if sideNum and sideNum >= 0 and sideNum <= 5 then
        local success, size = pcall(inv.getInventorySize, sideNum)
        if success and size and size > 0 then
            print("Using side: " .. sideNum)
            return sideNum
        else
            error("No valid inventory found on side " .. sideNum)
        end
    end
    
    error("Invalid side number or no chest found connected to the Adapter")
end

local function parseExpression(str)
    if type(str) ~= "string" then return nil, "not a string" end

    -- Support for 1k, 1m, 1g, 1t, 1p
    str = str:gsub("([0-9%.]+)%s*[kK]", "%1*1000")
    str = str:gsub("([0-9%.]+)%s*[mM]", "%1*1000000")
    str = str:gsub("([0-9%.]+)%s*[gG]", "%1*1000000000")
    str = str:gsub("([0-9%.]+)%s*[tT]", "%1*1000000000000")
    str = str:gsub("([0-9%.]+)%s*[pP]", "%1*1000000000000000")

    str = str:gsub("%s+", "")

    if str:match("[^0-9%+%-%*/%.%(%)]+") then
        return nil, "invalid characters"
    end

    local f, err = load("return " .. str)
    if not f then return nil, err end

    local ok, result = pcall(f)
    if not ok or type(result) ~= "number" then
        return nil, "invalid expression"
    end

    return math.floor(result)
end

local function loadConfig()
    local cfg = {}
    if filesystem.exists(configPath) then
        local ok, chunk = pcall(loadfile, configPath)
        if ok and chunk then
            local status, result = pcall(chunk)
            if status and type(result) == "table" then
                cfg = result
            end
        end
    end
    if not cfg.items then cfg.items = {} end
    if not cfg.sleep then cfg.sleep = 10 end
    return cfg
end

local function askValue(prompt, default)
    io.write(prompt .. " [" .. tostring(default) .. "]: ")
    local input = io.read()
    if input == nil or input == "" then
        return default
    end

    local value, err = parseExpression(input)
    if not value then
        print("Error: " .. tostring(err) .. ". Using default value.")
        return default
    end
    return value
end

local function serializeTable(tbl) 
    local str = "{ "
    for k,v in pairs(tbl) do
        str = str .. k .. " = \"" .. tostring(v) .. "\", "
    end
    if #str > 2 then
        str = str:sub(1, -3)
    end
    str = str .. " }"
    return str
end

local function scanChest(chestSide, existingItems)
    if not component.isAvailable("inventory_controller") then
        error("Inventory Controller not found!")
    end
    local inv = component.inventory_controller
    local size = inv.getInventorySize(chestSide)
    if not size or size < 1 then 
        error("Could not read chest or it is empty") 
    end

    local items = {}
    local addedCount = 0
    
    -- Items to ignore (computer components, upgrades, etc)
    local ignorePatterns = {
        "card",
        "upgrade",
        "cpu",
        "memory",
        "disk",
        "eeprom",
        "floppy",
        "hard drive",
        "graphics card",
        "internet card",
        "redstone card",
        "network card",
        "screen",
        "keyboard",
        "tablet",
        "drone",
        "robot",
        "computer",
        "server",
        "case"
    }
    
    local function shouldIgnoreItem(itemName)
        if not itemName then return true end
        local lowerName = itemName:lower()
        for _, pattern in ipairs(ignorePatterns) do
            if lowerName:find(pattern) then
                return true
            end
        end
        return false
    end

    print("Scanning chest with " .. size .. " slots...")
    
    for slot=1,size do
        local stack = inv.getStackInSlot(chestSide, slot)
        if stack and stack.size and stack.size > 0 then
            local item_name = stack.label or stack.name
            
            if item_name and not existingItems[item_name] and not shouldIgnoreItem(item_name) then
                local threshold = ITEM_THRESHOLD
                local batch_size = ITEM_BATCH_SIZE
                local fluid_name = nil

                -- Check if it's a fluid drop
                if string.find(item_name:lower(), "drop") then
                    threshold = FLUID_THRESHOLD
                    batch_size = FLUID_BATCH_SIZE
                    
                    -- Try to get fluid tag safely
                    if stack.fluidDrop and stack.fluidDrop.name then
                        fluid_name = stack.fluidDrop.name
                    else
                        -- Fallback: extract from item name
                        fluid_name = item_name:lower():gsub("drop of ", ""):gsub(" ", "_")
                    end
                end

                print("\nNew item found: " .. item_name)
                threshold = askValue(item_name .. " threshold (enter 'nil' for none)", threshold)
                batch_size = askValue(item_name .. " batch_size", batch_size)
                
                -- SIMPLIFIED FORMAT: only threshold and batch_size
                -- Pattern.lua will generate: items[name] = {threshold, batch_size}
                items[item_name] = {threshold, batch_size}
                addedCount = addedCount + 1
                
                return items, addedCount
            elseif item_name and shouldIgnoreItem(item_name) then
                print("Ignoring: " .. item_name .. " (computer component)")
            end
        end
    end
    return items, addedCount
end

local function serializeItems(tbl)
    local result = {}
    local ind = "  "
    table.insert(result, "{")
    for k,v in pairs(tbl) do
        local key = string.format("[\"%s\"]", k)
        local threshold_str = (v[1] == nil) and "nil" or tostring(v[1])
        local batch_str = tostring(v[2] or 0)
        table.insert(result, string.format("%s%s = {%s, %s},", ind, key, threshold_str, batch_str))
    end
    table.insert(result, "}")
    return table.concat(result, "\n")
end

local function updateConfigItems(newItems)
    local content = ""
    local f = io.open(configPath, "r")
    if f then
        content = f:read("*a")
        f:close()
    end

    local startPos, bracePos = content:find('cfg%["items"%]%s*=%s*{')
    if not startPos then
        error("Array cfg[\"items\"] not found in config.lua")
    end

    local openBraces = 1
    local i = bracePos + 1
    local endPos = nil
    while i <= #content do
        local c = content:sub(i,i)
        if c == "{" then 
            openBraces = openBraces + 1
        elseif c == "}" then
            openBraces = openBraces - 1
            if openBraces == 0 then
                endPos = i
                break
            end
        end
        i = i + 1
    end
    if not endPos then 
        error("Could not determine end of cfg[\"items\"] array") 
    end

    local serialized = serializeItems(newItems)
    local updatedContent = content:sub(1, startPos-1) .. "cfg[\"items\"] = " .. serialized .. content:sub(endPos+1)

    local f = io.open(configPath, "w")
    f:write(updatedContent)
    f:close()
end

local function ensureAutorun()
    local f = io.open(shrcPath, "r")
    if not f then
        print("WARNING: .shrc file not found, skipping autorun setup")
        return
    end
    
    local content = f:read("*a")
    f:close()

    if content:match("Maintainer") then
        return
    end

    io.write("Add Maintainer.lua to autostart? (y/n): ")
    local answer = io.read()
    if answer and answer:lower() == "y" then
        local fw = io.open(shrcPath, "a")
        fw:write("\nMaintainer\n")
        fw:close()
        print("Maintainer.lua added to autostart")
    end
end

-- Main function
local function main()
    print("=== Chest Scanner ===")
    print("Level Maintainer - Pattern Configuration Tool")
    print("")
    
    -- Automatically detect the chest
    local chestSide = findChest()
    
    print("\nScanning items...")
    local cfg = loadConfig()
    local newItems, addedCount = scanChest(chestSide, cfg.items)

    for k,v in pairs(newItems) do
        cfg.items[k] = v
    end

    if addedCount > 0 then
        updateConfigItems(cfg.items)
        print("\n" .. string.rep("=", 50))
        print("config.lua updated successfully!")
        print("Items added: " .. tostring(addedCount))
        print(string.rep("=", 50))
    else
        print("\nNo new items found to add.")
    end

    ensureAutorun()
    
    io.write("\nReboot now? (y/n): ")
    local reboot = io.read()
    if reboot and reboot:lower() == "y" then
        os.execute("reboot")
    end
end

main()