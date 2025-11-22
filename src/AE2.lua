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

-- Returns: success:boolean, message:string
function AE2.requestItem(name, data, threshold, count)
  local craftable = getCraftableForItem(name)
  if not craftable then
    return false, "is not craftable!"
  end

  local item = craftable.getItemStack()
  local itemInSystem = nil

  if threshold and threshold > 0 then
    -- If data is provided (old format), use it
    if data then
      if data.fluid_tag then
        itemInSystem = ME.getItemInNetwork('ae2fc:fluid_drop', 0, "{Fluid:\"" .. data.fluid_tag .. "\"}")
      else
        itemInSystem = ME.getItemInNetwork(data.item_id, tonumber(data.item_meta))
      end
    else
      -- New format: auto-detect based on item name and craftable data
      if isFluidDrop(name) then
        -- It's a fluid - try to get fluid tag from craftable item
        local fluidTag = getFluidTagFromName(name)
        itemInSystem = ME.getItemInNetwork('ae2fc:fluid_drop', 0, "{Fluid:\"" .. fluidTag .. "\"}")
      else
        -- It's a regular item
        if item.name then
          itemInSystem = ME.getItemInNetwork(item.name, item.damage or 0)
        end
      end
    end

    if itemInSystem and itemInSystem.size >= threshold then
      local currentAmount = formatNumber(itemInSystem.size)
      local thresholdFmt = formatNumber(threshold)
      return false, "The amount (" .. currentAmount .. ") >= threshold (" .. thresholdFmt .. ")! Aborting request."
    end
  end

  if item and item.label == name then
    local craft = craftable.request(count)
    while craft.isComputing() do os.sleep(1) end

    if craft.hasFailed() then
      return false, "Failed to request " .. formatNumber(count)
    else
      return true, "Requested " .. formatNumber(count)
    end
  end

  return false, "is not craftable!"
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