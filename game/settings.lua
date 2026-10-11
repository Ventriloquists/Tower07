-- Player settings. Stored separately from the game save (settings.lua) so a save reset keeps them.
local Set = {}

Set.defaults = {
  -- display
  vsync = true, fpsCap = 0, showFps = false, scanlines = true, vignette = true, reticle = false, numFormat = "short",
  -- audio
  master = 0.8, vUi = 1, vReward = 1, vAlert = 1, ambient = 0.3, muteUnfocused = false, memeSounds = false, memeCaptions = true,
  -- gameplay
  confirmReboot = true, fastReveal = false, holdSpeed = 1, anyKey = false, ticker = "all", autosave = 15, lazy = false,
  -- comfort
  shake = 1, flash = 1, confetti = 1, reducedMotion = false, tooltips = true, keywords = true,
  -- wellbeing
  grass = 45, nap = 5, eco = true, bossKey = true, disguise = "sheet",
  -- theme
  theme = "command", designV = 0,
}

local function copy(t)
  local c = {}
  for k, v in pairs(t) do c[k] = v end
  return c
end
Set.v = copy(Set.defaults)

local function ser(t)
  local parts = {}
  for k, v in pairs(t) do
    local val
    if type(v) == "number" then val = string.format("%.17g", v)
    elseif type(v) == "boolean" then val = tostring(v)
    elseif type(v) == "string" then val = string.format("%q", v) end
    if val then parts[#parts + 1] = "[" .. string.format("%q", k) .. "]=" .. val end
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

function Set.load()
  if not love.filesystem.getInfo("settings.lua") then return end
  local data = love.filesystem.read("settings.lua")
  local fn = data and loadstring("return " .. data)
  if not fn then return end
  setfenv(fn, {})
  local ok, t = pcall(fn)
  if not ok or type(t) ~= "table" then return end
  for k, v in pairs(t) do
    if Set.defaults[k] ~= nil and type(Set.defaults[k]) == type(v) then Set.v[k] = v end
  end
end

function Set.save() love.filesystem.write("settings.lua", ser(Set.v)) end

function Set.reset()
  Set.v = copy(Set.defaults)
  Set.save()
end

return Set
