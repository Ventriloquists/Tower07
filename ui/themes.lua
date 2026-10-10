-- Color schemes. Applying one mutates the shared palette (H.C) in place, so every screen follows.
local H = require "lib.hud"
local T = {}

T.LIST = {
  {id = "oblivion", name = "OBLIVION", desc = "The default tower HUD.", c = {
    bg = {0.024, 0.036, 0.048}, panel = {0.035, 0.058, 0.075}, line = {0.55, 0.86, 0.96}, white = {0.90, 0.97, 1.00},
    dim = {0.36, 0.52, 0.60}, faint = {0.16, 0.27, 0.32}, red = {1.00, 0.27, 0.22}, orange = {1.00, 0.58, 0.20},
    teal = {0.13, 0.42, 0.52}, sea = {0.03, 0.075, 0.095}, gold = {1.00, 0.84, 0.36}}},
  {id = "amber", name = "AMBER TERMINAL", desc = "1983 called. It wants its monitor back.", c = {
    bg = {0.035, 0.025, 0.012}, panel = {0.065, 0.045, 0.02}, line = {1.00, 0.72, 0.28}, white = {1.00, 0.93, 0.78},
    dim = {0.62, 0.45, 0.22}, faint = {0.30, 0.20, 0.08}, red = {1.00, 0.32, 0.18}, orange = {1.00, 0.90, 0.40},
    teal = {0.45, 0.30, 0.10}, sea = {0.07, 0.05, 0.02}, gold = {1.00, 0.97, 0.62}}},
  {id = "phosphor", name = "PHOSPHOR", desc = "Green CRT. Follow the white rabbit.", c = {
    bg = {0.010, 0.030, 0.015}, panel = {0.020, 0.060, 0.030}, line = {0.35, 1.00, 0.50}, white = {0.86, 1.00, 0.88},
    dim = {0.25, 0.60, 0.32}, faint = {0.10, 0.25, 0.13}, red = {1.00, 0.38, 0.30}, orange = {0.95, 1.00, 0.40},
    teal = {0.10, 0.40, 0.20}, sea = {0.02, 0.07, 0.04}, gold = {1.00, 0.90, 0.40}}},
  {id = "synthwave", name = "SYNTHWAVE", desc = "Neon sunset over the harvest platforms.", c = {
    bg = {0.050, 0.020, 0.080}, panel = {0.090, 0.040, 0.130}, line = {0.30, 0.90, 1.00}, white = {1.00, 0.90, 1.00},
    dim = {0.60, 0.45, 0.75}, faint = {0.27, 0.15, 0.35}, red = {1.00, 0.25, 0.35}, orange = {1.00, 0.38, 0.78},
    teal = {0.35, 0.15, 0.50}, sea = {0.07, 0.03, 0.12}, gold = {1.00, 0.85, 0.30}}},
  {id = "deepsea", name = "DEEP SEA", desc = "Hydro rig night shift. Bioluminescent.", c = {
    bg = {0.010, 0.040, 0.060}, panel = {0.020, 0.070, 0.100}, line = {0.30, 0.95, 0.85}, white = {0.86, 1.00, 0.98},
    dim = {0.30, 0.60, 0.62}, faint = {0.10, 0.25, 0.30}, red = {1.00, 0.40, 0.42}, orange = {1.00, 0.62, 0.45},
    teal = {0.05, 0.40, 0.45}, sea = {0.02, 0.08, 0.12}, gold = {1.00, 0.90, 0.50}}},
  {id = "noir", name = "NOIR", desc = "Black and white. One red for danger.", c = {
    bg = {0.030, 0.030, 0.030}, panel = {0.070, 0.070, 0.070}, line = {0.82, 0.82, 0.82}, white = {1.00, 1.00, 1.00},
    dim = {0.55, 0.55, 0.55}, faint = {0.25, 0.25, 0.25}, red = {1.00, 0.30, 0.30}, orange = {1.00, 0.92, 0.72},
    teal = {0.30, 0.30, 0.30}, sea = {0.06, 0.06, 0.06}, gold = {1.00, 0.95, 0.70}}},
  {id = "cbsafe", name = "COLORBLIND SAFE", desc = "Okabe-Ito palette: readable for all color vision types.", c = {
    bg = {0.020, 0.030, 0.050}, panel = {0.040, 0.060, 0.090}, line = {0.34, 0.71, 0.91}, white = {0.95, 0.95, 0.95},
    dim = {0.50, 0.58, 0.65}, faint = {0.20, 0.25, 0.30}, red = {0.84, 0.37, 0.00}, orange = {0.94, 0.89, 0.26},
    teal = {0.00, 0.45, 0.70}, sea = {0.03, 0.06, 0.10}, gold = {0.80, 0.47, 0.65}}},
  {id = "golden", name = "GOLDEN HOARD", desc = "Everything is loot.", lock = "Open a MYTHIC crate",
    unlocked = function(S) return (S.mythic or 0) >= 1 end, c = {
    bg = {0.040, 0.030, 0.010}, panel = {0.080, 0.060, 0.020}, line = {1.00, 0.82, 0.40}, white = {1.00, 0.97, 0.86},
    dim = {0.65, 0.52, 0.28}, faint = {0.30, 0.24, 0.10}, red = {1.00, 0.35, 0.25}, orange = {1.00, 1.00, 0.60},
    teal = {0.40, 0.30, 0.10}, sea = {0.06, 0.05, 0.02}, gold = {1.00, 1.00, 0.85}}},
  {id = "bloodmoon", name = "BLOOD MOON", desc = "The motherships remember you.", lock = "Destroy a MOTHERSHIP",
    unlocked = function(S) return (S.bosses or 0) >= 1 end, c = {
    bg = {0.050, 0.010, 0.015}, panel = {0.090, 0.020, 0.030}, line = {1.00, 0.38, 0.38}, white = {1.00, 0.90, 0.88},
    dim = {0.65, 0.30, 0.32}, faint = {0.30, 0.10, 0.12}, red = {1.00, 0.88, 0.30}, orange = {1.00, 0.62, 0.30},
    teal = {0.40, 0.08, 0.10}, sea = {0.07, 0.02, 0.03}, gold = {1.00, 0.92, 0.55}}},
  {id = "void", name = "VOID PROTOCOL", desc = "Seen too many reboots.", lock = "Complete 5 REBOOTS",
    unlocked = function(S) return (S.prestiges or 0) >= 5 end, c = {
    bg = {0.000, 0.000, 0.000}, panel = {0.040, 0.030, 0.060}, line = {0.72, 0.56, 1.00}, white = {0.96, 0.93, 1.00},
    dim = {0.45, 0.38, 0.60}, faint = {0.18, 0.14, 0.26}, red = {1.00, 0.30, 0.45}, orange = {0.55, 1.00, 0.85},
    teal = {0.25, 0.15, 0.40}, sea = {0.03, 0.02, 0.05}, gold = {1.00, 0.85, 0.40}}},
}

function T.get(id)
  for _, t in ipairs(T.LIST) do if t.id == id then return t end end
  return T.LIST[1]
end

function T.isUnlocked(t, S)
  return not t.unlocked or (S and t.unlocked(S))
end

function T.apply(id)
  local t = T.get(id)
  for k, v in pairs(t.c) do
    local dst = H.C[k]
    if dst then dst[1], dst[2], dst[3] = v[1], v[2], v[3] end
  end
end

return T
