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
  {id = "contrast", name = "HIGH CONTRAST", desc = "Pure black, bright text. Maximum readability.", c = {
    bg = {0, 0, 0}, panel = {0.06, 0.06, 0.06}, line = {0.0, 0.95, 1.0}, white = {1, 1, 1},
    dim = {0.85, 0.85, 0.85}, faint = {0.55, 0.55, 0.55}, red = {1.0, 0.25, 0.25}, orange = {1.0, 0.9, 0.0},
    teal = {0.0, 0.45, 0.6}, sea = {0.0, 0.1, 0.25}, gold = {1.0, 0.65, 0.0}}},
  {id = "contrastlight", name = "HIGH CONTRAST LIGHT", desc = "Black on white. For bright rooms.", c = {
    bg = {1, 1, 1}, panel = {0.93, 0.93, 0.93}, line = {0.0, 0.25, 0.75}, white = {0, 0, 0},
    dim = {0.15, 0.15, 0.15}, faint = {0.55, 0.55, 0.55}, red = {0.8, 0.0, 0.0}, orange = {0.75, 0.35, 0.0},
    teal = {0.6, 0.8, 0.95}, sea = {0.82, 0.9, 1.0}, gold = {0.55, 0.4, 0.0}}},
  {id = "stonks", name = "STONKS", desc = "Number go up. Green candles only.", c = {
    bg = {0.01, 0.02, 0.01}, panel = {0.03, 0.06, 0.03}, line = {0.0, 0.9, 0.35}, white = {0.95, 1.0, 0.95},
    dim = {0.35, 0.6, 0.4}, faint = {0.12, 0.25, 0.14}, red = {0.95, 0.15, 0.2}, orange = {0.3, 1.0, 0.5},
    teal = {0.05, 0.35, 0.15}, sea = {0.02, 0.06, 0.03}, gold = {1.0, 0.85, 0.2}}},
  {id = "gamer", name = "GAMER RGB", desc = "+15 FPS. Scientifically proven.", c = {
    bg = {0.03, 0.0, 0.06}, panel = {0.07, 0.0, 0.12}, line = {0.0, 1.0, 0.9}, white = {1, 1, 1},
    dim = {0.9, 0.3, 1.0}, faint = {0.3, 0.1, 0.45}, red = {1.0, 0.1, 0.4}, orange = {1.0, 1.0, 0.0},
    teal = {0.5, 0.0, 0.8}, sea = {0.08, 0.0, 0.15}, gold = {0.2, 1.0, 0.2}}},
  {id = "vaporwave", name = "A E S T H E T I C", desc = "H A R V E S T   I N   P A S T E L .", c = {
    bg = {0.12, 0.06, 0.2}, panel = {0.2, 0.1, 0.3}, line = {1.0, 0.6, 0.85}, white = {1.0, 0.95, 1.0},
    dim = {0.6, 0.8, 1.0}, faint = {0.4, 0.3, 0.55}, red = {1.0, 0.4, 0.55}, orange = {0.45, 1.0, 0.95},
    teal = {0.35, 0.25, 0.55}, sea = {0.18, 0.12, 0.3}, gold = {1.0, 0.95, 0.6}}},
  {id = "bsod", name = "BLUE SCREEN", desc = "A problem has been detected. Keep harvesting.", c = {
    bg = {0.0, 0.47, 0.84}, panel = {0.0, 0.4, 0.75}, line = {1, 1, 1}, white = {1, 1, 1},
    dim = {0.8, 0.9, 1.0}, faint = {0.35, 0.65, 0.95}, red = {1.0, 0.85, 0.3}, orange = {1, 1, 1},
    teal = {0.0, 0.3, 0.6}, sea = {0.0, 0.35, 0.7}, gold = {1.0, 1.0, 0.6}}},
  {id = "dark", name = "DARK MODE", desc = "Like regular mode, but you're a developer now.", c = {
    bg = {0.12, 0.12, 0.13}, panel = {0.17, 0.17, 0.19}, line = {0.55, 0.75, 1.0}, white = {0.9, 0.9, 0.92},
    dim = {0.55, 0.57, 0.62}, faint = {0.28, 0.29, 0.32}, red = {0.95, 0.45, 0.45}, orange = {0.9, 0.7, 0.4},
    teal = {0.25, 0.35, 0.5}, sea = {0.14, 0.16, 0.2}, gold = {0.95, 0.85, 0.5}}},
  {id = "matrix", name = "THERE IS NO SPOON", desc = "You took the green pill. Wrong movie.", c = {
    bg = {0, 0, 0}, panel = {0, 0.04, 0}, line = {0.0, 1.0, 0.25}, white = {0.7, 1.0, 0.7},
    dim = {0.0, 0.6, 0.15}, faint = {0.0, 0.25, 0.05}, red = {0.6, 1.0, 0.6}, orange = {0.85, 1.0, 0.85},
    teal = {0.0, 0.3, 0.08}, sea = {0.0, 0.06, 0.01}, gold = {1, 1, 1}}},
  {id = "barbie", name = "HI BARBIE", desc = "Hi Ken. The tower is pink now.", c = {
    bg = {0.2, 0.02, 0.12}, panel = {0.3, 0.05, 0.2}, line = {1.0, 0.45, 0.75}, white = {1.0, 0.92, 0.97},
    dim = {0.95, 0.6, 0.8}, faint = {0.5, 0.15, 0.35}, red = {1.0, 0.2, 0.45}, orange = {1.0, 0.85, 0.95},
    teal = {0.55, 0.1, 0.35}, sea = {0.3, 0.05, 0.2}, gold = {1.0, 0.9, 0.4}}},
  {id = "coffee", name = "THIRD COFFEE", desc = "It's 3 AM. Just one more reboot.", c = {
    bg = {0.08, 0.05, 0.03}, panel = {0.14, 0.09, 0.06}, line = {0.85, 0.65, 0.45}, white = {0.98, 0.92, 0.85},
    dim = {0.6, 0.45, 0.32}, faint = {0.3, 0.2, 0.13}, red = {0.9, 0.35, 0.25}, orange = {1.0, 0.85, 0.6},
    teal = {0.35, 0.22, 0.14}, sea = {0.12, 0.08, 0.05}, gold = {1.0, 0.9, 0.7}}},
  {id = "doom", name = "DOOMSCROLL", desc = "Red alert. Everything is fine.", c = {
    bg = {0.06, 0.0, 0.0}, panel = {0.12, 0.01, 0.01}, line = {1.0, 0.2, 0.15}, white = {1.0, 0.85, 0.8},
    dim = {0.7, 0.3, 0.25}, faint = {0.3, 0.06, 0.05}, red = {1.0, 0.95, 0.3}, orange = {1.0, 0.55, 0.1},
    teal = {0.35, 0.05, 0.03}, sea = {0.1, 0.0, 0.0}, gold = {1.0, 0.9, 0.3}}},
  {id = "gameboy", name = "POCKET MONSTER", desc = "Four shades of green. 1989 vibes.", c = {
    bg = {0.06, 0.22, 0.06}, panel = {0.19, 0.38, 0.19}, line = {0.61, 0.74, 0.06}, white = {0.80, 0.86, 0.45},
    dim = {0.55, 0.67, 0.06}, faint = {0.19, 0.38, 0.19}, red = {0.80, 0.86, 0.45}, orange = {0.70, 0.80, 0.30},
    teal = {0.19, 0.38, 0.19}, sea = {0.10, 0.28, 0.10}, gold = {0.85, 0.92, 0.55}}},
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
