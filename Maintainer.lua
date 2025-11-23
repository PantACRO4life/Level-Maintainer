local term = require("term")
local event = require("event")
local component = require("component")
local gpu = component.gpu
local ae2 = require("src.AE2")
local cfg = require("config")

local items = cfg.items
local sleepInterval = cfg.sleep
local timezone = cfg.timezone or 0  -- Default 0 (UTC) if not set

-- Auto-update check
pcall(function()
  local shell = require("shell")
  shell.execute("updater silent")
end)

-- Function to get time with timezone offset
local function getLocalTime()
  return os.date("%H:%M:%S", os.time() + (timezone * 3600))
end

local function exitMaintainer()
  term.clear()
  term.setCursor(1, 1)
  print("Exit from Maintainer...")
  os.exit(0.5)
end

local function logInfoColoredAfterColon(msg, color)
  if type(msg) ~= "string" then msg = tostring(msg) end
  local before, after = msg:match("^(.-):%s*(.+)$")
  if not before then
    print(msg)
    return
  end

  local old = gpu.getForeground()
  io.write("[" .. getLocalTime() .. "] " .. before .. ": ")
  if color then gpu.setForeground(color) end
  io.write(after .. "\n")
  gpu.setForeground(old)
end

local function logInfo(msg)
  print("[" .. getLocalTime() .. "] " .. msg)
end

while true do
  term.clear()
  term.setCursor(1, 1)
  print("Press Q to exit. Item inspection interval: " .. sleepInterval .. " sec.\n")

  local itemsCrafting = ae2.checkIfCrafting()

  for item, cfgItem in pairs(items) do
    if itemsCrafting[item] then
      logInfo(item .. ": is already being crafted, skipping...")
    else
      -- Support both formats:
      -- Old: {{item_id = "...", item_meta = ...}, threshold, batch_size}
      -- New: {threshold, batch_size}
      local data, threshold, batch_size
      
      if type(cfgItem[1]) == "table" then
        -- Old format
        data = cfgItem[1]
        threshold = cfgItem[2]
        batch_size = cfgItem[3]
      else
        -- New simplified format
        data = nil  -- Will be auto-detected
        threshold = cfgItem[1]
        batch_size = cfgItem[2]
      end
      
      local success, msg = ae2.requestItem(item, data, threshold, batch_size)
      
      local color = nil
      if msg:find("^Failed to request") then
        color = 0xFF0000 -- red
      elseif msg:find("^Requested") then
        color = 0xFFFF00 -- yellow
      elseif msg:find("The amount %(") and msg:find("Aborting request%.$") then
        color = 0x00FF00 -- green
      end

      logInfoColoredAfterColon(item .. ": " .. msg, color)
    end
  end

  local _, _, _, code = event.pull(sleepInterval, "key_down")
  if code == 0x10 then -- Q key
    exitMaintainer()
  end
end