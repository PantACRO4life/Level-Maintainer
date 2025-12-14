local component = require("component")
local ME = component.me_interface
local gpu = component.gpu

local AE2 = {}

local itemCache = {}
local cacheTimestamp = 0
local CACHE_DURATION = 600 -- 10 minutes

function AE2.printColoredAfterColon(line, color)
  if type(line) ~= "string" then line = tostring(line) end
  local before, after = line:match("^(.-):%s*(.+)$")
  if not before then
    io.write(line .. "\n")
    return
  end

  local old = gpu.getForeground()
  io.write(before .. ": ")
  if color then gpu.setForeground(color) end
  io.write(after .. "\n")
  gpu.setForeground(old)
end

local function formatNumber(num)
  if type(num) ~= "number" then return tostring(num) end
  local str = tostring(num)
  local parts = {}
  local len = #str
  local firstGroup = len % 3
  if firstGroup == 0 then firstGroup = 3 end
  table.insert(parts, str:sub(1, firstGroup))
  local i = firstGroup + 1
  while i <= len do
    table.insert(parts, str:sub(i, i + 2))
    i = i + 3
  end
  return table.concat(parts, "_")
end

local function getCraftableForItem(itemName)
  local currentTime = os.time()
  if currentTime - cacheTimestamp >= CACHE_DURATION then
    itemCache = {}
    cacheTimestamp = currentTime
  else
    if itemCache[itemName] then
      return itemCache[itemName]
    end
  end
  local craftables = ME.getCraftables({label = itemName})
  local craftable = craftables and craftables[1] or nil
  itemCache[itemName] = craftable
  return craftable
end

-- Auto-detect if item is a fluid based on name
local function isFluidDrop(itemName)
  return itemName:lower():find("drop") ~= nil
end

-- Extract fluid tag from item name
local function getFluidTagFromName(itemName)
  local fluidName = itemName:gsub("^[Dd]rop [Oo]f ", "")
  fluidName = fluidName:gsub("^[Mm]olten ", "molten.")
  fluidName = fluidName:gsub(" ", ".")
  return fluidName:lower()
end

-- changed NBT to Label
-- Returns: success:boolean, message:string
function AE2.requestItem(name, data, threshold, count)
  local craftable = getCraftableForItem(name)
  if not craftable then
    return false, "is not craftable!"
  end

  if threshold and threshold > 0 then
    local currentStock = 0
    
    local itemsFound = ME.getItemsInNetwork({ label = name })
    if itemsFound then
      for _, i in pairs(itemsFound) do
        currentStock = currentStock + i.size
      end
    end

    local fluids = ME.getFluidsInNetwork()
    if fluids then
        local cleanName = name:gsub("^[Dd]rop [Oo]f ", ""):gsub("^[Mm]olten ", ""):lower()
        local targetNameLower = name:lower()
        
        for _, f in pairs(fluids) do
            local labelLower = (f.label or ""):lower()
            if labelLower == targetNameLower or labelLower == cleanName then
                currentStock = currentStock + f.amount
            end
        end
    end

    if currentStock >= threshold then
      local currentFmt = formatNumber(currentStock)
      local thresholdFmt = formatNumber(threshold)
      return false, "The amount (" .. currentFmt .. ") >= threshold (" .. thresholdFmt .. ")! Aborting request."
    end
  end

  if craftable then
    local craft = craftable.request(count)
    
    local timeout = 5
    while craft.isComputing() and timeout > 0 do 
        os.sleep(0.1) 
        timeout = timeout - 1
    end

    if craft.hasFailed() then
      local reason = "Unknown"
      pcall(function() reason = tostring(craft.hasFailed()) end)
      return false, "Failed to request " .. formatNumber(count) .. " [" .. reason .. "]"
    else
      return true, "Requested " .. formatNumber(count)
    end
  end

  return false, "is not craftable! (Generic Error)"
end

function AE2.checkIfCrafting()
  local items = {}
  for _, cpu in pairs(ME.getCpus()) do
    local final = cpu.cpu.finalOutput()
    if final then
      items[final.label] = true
    end
  end
  return items
end

function AE2.clearCache()
  itemCache = {}
  cacheTimestamp = 0
end

return AE2