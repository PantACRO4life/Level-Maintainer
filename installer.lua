local shell = require("shell")
local filesystem = require("filesystem")

local repo = "https://raw.githubusercontent.com/Armagedon13/Level-Maintainer/"
local branch = "master"

local files = {
  "src/AE2.lua",
  "src/Utility.lua", 
  "Maintainer.lua",
  "Pattern.lua",
  "updater.lua",
  "version.lua",
  "send_config.lua",
}

local dirs = {"src", "lib"}

print("Installing Level Maintainer...")

-- Create directories
for _, dir in ipairs(dirs) do
  local path = shell.getWorkingDirectory() .. "/" .. dir
  if not filesystem.exists(path) then
    filesystem.makeDirectory(path)
  end
end

-- Download all files
for _, file in ipairs(files) do
  local url = repo .. branch .. "/" .. file
  local path = shell.getWorkingDirectory() .. "/" .. file
  
  if filesystem.exists(path) then
    filesystem.remove(path)
  end
  
  print("Downloading " .. file .. "...")
  shell.execute("wget -fq " .. url .. " " .. path)
end

-- Download config only if it doesn't exist
local configPath = shell.getWorkingDirectory() .. "/config.lua"
if not filesystem.exists(configPath) then
  print("Downloading default config.lua...")
  shell.execute("wget -fq " .. repo .. branch .. "/config.lua " .. configPath)
else
  print("Config.lua already exists - preserved")
end

print("\nInstallation complete!")
os.sleep(2)
shell.execute("reboot")