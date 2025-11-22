local component = require("component")
local shell = require("shell")
local filesystem = require("filesystem")
local term = require("term")

local Updater = {}

function Updater.new()
  local obj = {}
  obj.repository = "Armagedon13/Level-Maintainer"
  obj.branch = "master"
  obj.currentVersion = Updater.getCurrentVersion()
  
  setmetatable(obj, {__index = Updater})
  return obj
end

-- Get current local version
function Updater.getCurrentVersion()
  local versionPath = shell.getWorkingDirectory() .. "/version.lua"
  if not filesystem.exists(versionPath) then
    return {programVersion = "0.0.0", configVersion = 0}
  end
  
  local success, version = pcall(dofile, versionPath)
  if success and version then
    return version
  end
  return {programVersion = "0.0.0", configVersion = 0}
end

-- Get latest version from GitHub
function Updater:getLatestVersion()
  if not component.isAvailable("internet") then
    return nil, "Internet card not found"
  end
  
  local internet = require("internet")
  local url = "https://raw.githubusercontent.com/" .. self.repository .. "/refs/heads/" .. self.branch .. "/version.lua"
  
  local request = internet.request(url)
  if not request then
    return nil, "Failed to connect to GitHub"
  end
  
  local result = ""
  for chunk in request do
    result = result .. chunk
  end
  
  local success, remoteVersion = pcall(load(result))
  if not success or not remoteVersion then
    return nil, "Failed to parse remote version"
  end
  
  return remoteVersion
end

-- Check if update is needed
function Updater:isUpdateNeeded()
  local remoteVersion, err = self:getLatestVersion()
  if not remoteVersion then
    return false, false, nil, err
  end
  
  -- Compare program versions (remove non-digits for comparison)
  local currentProgramVersion = self.currentVersion.programVersion:gsub("[%D]", "")
  local latestProgramVersion = remoteVersion.programVersion:gsub("[%D]", "")
  
  local isProgramUpdateNeeded = tonumber(latestProgramVersion) > tonumber(currentProgramVersion)
  local isConfigUpdateNeeded = remoteVersion.configVersion > self.currentVersion.configVersion
  
  return isProgramUpdateNeeded, isConfigUpdateNeeded, remoteVersion
end

-- Download and update files
function Updater:downloadFiles()
  local repo = "https://raw.githubusercontent.com/" .. self.repository .. "/" .. self.branch .. "/"
  
  local files = {
    "src/AE2.lua",
    "src/Utility.lua",
    "Maintainer.lua",
    "Pattern.lua",
    "updater.lua",
    "version.lua"
  }
  
  print("Downloading files...")
  for _, file in ipairs(files) do
    local url = repo .. file
    local path = shell.getWorkingDirectory() .. "/" .. file
    
    -- Remove old file
    if filesystem.exists(path) then
      filesystem.remove(path)
    end
    
    -- Download new file
    local success = shell.execute("wget -fq " .. url .. " " .. path)
    if success then
      print("  ✓ " .. file)
    else
      print("  ✗ " .. file .. " (failed)")
    end
  end
end

-- Backup config
function Updater:backupConfig()
  local configPath = shell.getWorkingDirectory() .. "/config.lua"
  local backupPath = shell.getWorkingDirectory() .. "/config.old.lua"
  
  if filesystem.exists(configPath) then
    if filesystem.exists(backupPath) then
      filesystem.remove(backupPath)
    end
    shell.execute("cp " .. configPath .. " " .. backupPath)
    return true
  end
  return false
end

-- Restore config
function Updater:restoreConfig()
  local configPath = shell.getWorkingDirectory() .. "/config.lua"
  local backupPath = shell.getWorkingDirectory() .. "/config.old.lua"
  
  if filesystem.exists(backupPath) then
    if filesystem.exists(configPath) then
      filesystem.remove(configPath)
    end
    shell.execute("mv " .. backupPath .. " " .. configPath)
    return true
  end
  return false
end

-- Main update function
function Updater:checkAndUpdate(silent)
  local isProgramUpdate, isConfigUpdate, remoteVersion, err = self:isUpdateNeeded()
  
  if err then
    if not silent then
      print("Update check failed: " .. err)
    end
    return false
  end
  
  if not isProgramUpdate then
    if not silent then
      print("Already up to date (v" .. self.currentVersion.programVersion .. ")")
    end
    return false
  end
  
  -- New version available
  term.clear()
  term.setCursor(1, 1)
  print("===========================================")
  print("  New version available!")
  print("===========================================")
  print("Current version: " .. self.currentVersion.programVersion)
  print("Latest version:  " .. remoteVersion.programVersion)
  print("")
  
  if isConfigUpdate then
    print("⚠ WARNING: This update changes the config format!")
    print("Your current config will be backed up to config.old.lua")
    print("You will need to manually update your config.lua")
    print("")
  end
  
  io.write("Do you want to update? (y/n): ")
  local answer = io.read()
  
  if not answer or answer:lower() ~= "y" then
    print("Update cancelled")
    return false
  end
  
  -- Backup config
  print("\nBacking up config...")
  self:backupConfig()
  
  -- Download files
  print("\nDownloading updates...")
  self:downloadFiles()
  
  -- Handle config
  if isConfigUpdate then
    print("\n⚠ Config format changed!")
    print("Your old config is saved as config.old.lua")
    print("Please manually update config.lua with your settings")
    print("\nPress Enter to continue...")
    io.read()
  else
    print("\nRestoring config...")
    self:restoreConfig()
    print("✓ Config preserved")
    
    print("\nUpdate complete! Rebooting...")
    os.sleep(2)
    shell.execute("reboot")
  end
  
  return true
end

-- Run updater
local function main()
  local args = {...}
  local silent = args[1] == "silent" or args[1] == "-s"
  
  local updater = Updater.new()
  updater:checkAndUpdate(silent)
end

main()