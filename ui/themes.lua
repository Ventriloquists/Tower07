-- Color schemes. Applying one mutates the shared palette (H.C) in place, so every screen follows.
local H = require "lib.hud"
local V = require "lib.view"

local T = {}

T.LIST = {
  -- house style: graphite surfaces, ice-white interface light, one warm signal accent
  {id = "command", name = "COMMAND", desc = "Tower 07 house style. Graphite, ice light, signal amber.", c = {
    bg = {0.030, 0.034, 0.040}, panel = {0.060, 0.067, 0.078}, line = {0.70, 0.84, 0.90}, white = {0.94, 0.95, 0.94},
    dim = {0.47, 0.53, 0.57}, faint = {0.17, 0.20, 0.23}, red = {0.98, 0.29, 0.25}, orange = {1.00, 0.60, 0.22},
    teal = {0.22, 0.38, 0.45}, sea = {0.040, 0.055, 0.068}, gold = {0.98, 0.81, 0.42}}},
  {id = "oblivion", name = "OBLIVION", desc = "The original tower HUD. Cyan on midnight.", c = {
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
  ---------------------------------------------------------------- creative
  {id = "blueprint", name = "BLUEPRINT", desc = "Approved by engineering. Not by legal.", c = {
    bg = {0.05, 0.22, 0.48}, panel = {0.07, 0.27, 0.55}, line = {0.92, 0.96, 1.00}, white = {1, 1, 1},
    dim = {0.65, 0.78, 0.95}, faint = {0.25, 0.45, 0.72}, red = {1.00, 0.55, 0.45}, orange = {1.00, 0.88, 0.45},
    teal = {0.15, 0.38, 0.68}, sea = {0.06, 0.25, 0.52}, gold = {1.00, 0.95, 0.60}}},
  {id = "sakura", name = "SAKURA", desc = "Cherry blossoms over the scav wastes.", c = {
    bg = {0.09, 0.06, 0.08}, panel = {0.15, 0.09, 0.13}, line = {1.00, 0.72, 0.82}, white = {1.00, 0.95, 0.97},
    dim = {0.72, 0.52, 0.62}, faint = {0.32, 0.20, 0.27}, red = {1.00, 0.35, 0.45}, orange = {0.75, 0.95, 0.65},
    teal = {0.40, 0.22, 0.32}, sea = {0.12, 0.07, 0.11}, gold = {1.00, 0.88, 0.62}}},
  {id = "toxic", name = "TOXIC WASTE", desc = "Glows in the dark. Do not lick.", c = {
    bg = {0.05, 0.02, 0.07}, panel = {0.09, 0.04, 0.12}, line = {0.65, 1.00, 0.10}, white = {0.92, 1.00, 0.85},
    dim = {0.55, 0.40, 0.70}, faint = {0.22, 0.13, 0.30}, red = {1.00, 0.25, 0.70}, orange = {1.00, 0.95, 0.10},
    teal = {0.30, 0.12, 0.40}, sea = {0.08, 0.03, 0.10}, gold = {0.80, 1.00, 0.30}}},
  {id = "arctic", name = "ARCTIC STATION", desc = "Minus 40. The coffee froze.", c = {
    bg = {0.06, 0.09, 0.14}, panel = {0.10, 0.15, 0.22}, line = {0.80, 0.94, 1.00}, white = {1, 1, 1},
    dim = {0.55, 0.68, 0.80}, faint = {0.22, 0.30, 0.40}, red = {1.00, 0.45, 0.50}, orange = {0.55, 0.85, 1.00},
    teal = {0.20, 0.35, 0.50}, sea = {0.08, 0.13, 0.20}, gold = {0.95, 0.98, 1.00}}},
  {id = "newsprint", name = "MORNING PAPER", desc = "Extra! Extra! Tower 07 hits record output!", c = {
    bg = {0.93, 0.90, 0.82}, panel = {0.88, 0.84, 0.74}, line = {0.10, 0.10, 0.10}, white = {0.05, 0.05, 0.05},
    dim = {0.35, 0.33, 0.30}, faint = {0.68, 0.64, 0.56}, red = {0.70, 0.08, 0.08}, orange = {0.45, 0.30, 0.10},
    teal = {0.75, 0.72, 0.64}, sea = {0.82, 0.80, 0.72}, gold = {0.50, 0.38, 0.05}}},
  {id = "miami", name = "MIAMI NIGHTS", desc = "Pastel suits mandatory. Synth bass included.", c = {
    bg = {0.04, 0.05, 0.10}, panel = {0.07, 0.08, 0.16}, line = {0.20, 0.95, 0.90}, white = {1.00, 0.95, 0.98},
    dim = {0.95, 0.50, 0.75}, faint = {0.25, 0.20, 0.35}, red = {1.00, 0.25, 0.55}, orange = {1.00, 0.60, 0.25},
    teal = {0.10, 0.40, 0.45}, sea = {0.05, 0.08, 0.15}, gold = {1.00, 0.90, 0.50}}},
  ---------------------------------------------------------------- joke palettes (colours only)
  {id = "shrek", name = "GET OUT OF MY SWAMP", desc = "Towers have layers. Like onions.", c = {
    bg = {0.10, 0.13, 0.04}, panel = {0.17, 0.21, 0.07}, line = {0.66, 0.80, 0.18}, white = {0.95, 0.95, 0.75},
    dim = {0.55, 0.45, 0.25}, faint = {0.28, 0.25, 0.10}, red = {0.80, 0.35, 0.15}, orange = {0.85, 0.70, 0.35},
    teal = {0.30, 0.35, 0.10}, sea = {0.20, 0.22, 0.10}, gold = {0.95, 0.85, 0.40}}},
  {id = "dirt", name = "PUNCH TREE GET WOOD", desc = "Mining harvest, crafting tower.", c = {
    bg = {0.35, 0.24, 0.15}, panel = {0.45, 0.31, 0.20}, line = {0.45, 0.80, 0.25}, white = {1, 1, 1},
    dim = {0.75, 0.62, 0.48}, faint = {0.28, 0.19, 0.12}, red = {0.85, 0.15, 0.10}, orange = {0.95, 0.75, 0.25},
    teal = {0.30, 0.55, 0.20}, sea = {0.20, 0.35, 0.75}, gold = {0.35, 0.85, 0.95}}},
  {id = "hotdog", name = "HOTDOG STAND", desc = "The worst Windows 3.1 theme, lovingly restored.", c = {
    bg = {1.00, 1.00, 0.00}, panel = {1.00, 0.00, 0.00}, line = {0.00, 0.00, 0.00}, white = {0, 0, 0},
    dim = {0.45, 0.10, 0.00}, faint = {0.85, 0.75, 0.00}, red = {0.70, 0.00, 0.00}, orange = {1, 1, 1},
    teal = {1.00, 0.30, 0.00}, sea = {1.00, 0.85, 0.00}, gold = {1, 1, 1}}},
  {id = "mspaint", name = "MS PAINT", desc = "Made in 4 minutes. Signed by the artist.", c = {
    bg = {1, 1, 1}, panel = {0.95, 0.95, 0.95}, line = {0.0, 0.0, 1.0}, white = {0, 0, 0},
    dim = {0.30, 0.30, 0.30}, faint = {0.75, 0.75, 0.75}, red = {1.0, 0.0, 0.0}, orange = {0.0, 0.70, 0.0},
    teal = {0.70, 0.85, 1.00}, sea = {0.55, 0.80, 1.00}, gold = {0.85, 0.70, 0.0}}},
  {id = "bliss", name = "BLISS.JPG", desc = "Green hill. Blue sky. Windows XP is starting.", c = {
    bg = {0.30, 0.55, 0.90}, panel = {0.25, 0.55, 0.20}, line = {1, 1, 1}, white = {1, 1, 1},
    dim = {0.85, 0.92, 1.00}, faint = {0.45, 0.70, 0.95}, red = {0.95, 0.30, 0.20}, orange = {1.0, 0.85, 0.3},
    teal = {0.30, 0.62, 0.25}, sea = {0.20, 0.45, 0.85}, gold = {1.0, 0.95, 0.5}}},
  {id = "cheeto", name = "CHEETO DUST", desc = "Your keyboard is orange now. Forever.", c = {
    bg = {0.20, 0.08, 0.00}, panel = {0.32, 0.13, 0.00}, line = {1.00, 0.55, 0.05}, white = {1.00, 0.85, 0.55},
    dim = {0.85, 0.45, 0.10}, faint = {0.45, 0.20, 0.02}, red = {1.00, 0.30, 0.00}, orange = {1.00, 0.75, 0.20},
    teal = {0.55, 0.25, 0.02}, sea = {0.28, 0.11, 0.00}, gold = {1.00, 0.90, 0.40}}},
  {id = "baby", name = "BABY MODE", desc = "Soft colors for a soft tower. Goo goo.", c = {
    bg = {0.92, 0.95, 1.00}, panel = {1.00, 0.92, 0.95}, line = {0.45, 0.60, 0.95}, white = {0.25, 0.25, 0.40},
    dim = {0.60, 0.55, 0.70}, faint = {0.85, 0.82, 0.92}, red = {1.00, 0.50, 0.60}, orange = {0.95, 0.75, 0.30},
    teal = {0.80, 0.90, 1.00}, sea = {0.85, 0.92, 1.00}, gold = {0.95, 0.80, 0.35}}},
  {id = "beige", name = "CORPORATE BEIGE", desc = "Synergy-driven harvest solutions. Per my last email.", c = {
    bg = {0.85, 0.80, 0.70}, panel = {0.80, 0.75, 0.64}, line = {0.45, 0.40, 0.32}, white = {0.25, 0.22, 0.18},
    dim = {0.55, 0.50, 0.42}, faint = {0.72, 0.67, 0.57}, red = {0.65, 0.40, 0.30}, orange = {0.60, 0.52, 0.35},
    teal = {0.75, 0.70, 0.60}, sea = {0.78, 0.73, 0.62}, gold = {0.62, 0.55, 0.35}}},
  {id = "rainbowroad", name = "RAINBOW ROAD", desc = "Every line is a different color every second.", anim = "rainbow",
    lock = "Own a PRISM drone", unlocked = function(S) return (S.prismEver or 0) >= 1 end, c = {
    bg = {0.02, 0.01, 0.05}, panel = {0.05, 0.03, 0.10}, line = {1.00, 0.40, 0.40}, white = {1, 1, 1},
    dim = {0.70, 0.60, 0.90}, faint = {0.20, 0.15, 0.30}, red = {1.00, 0.30, 0.50}, orange = {0.40, 1.00, 0.60},
    teal = {0.25, 0.15, 0.45}, sea = {0.05, 0.03, 0.12}, gold = {1.00, 0.95, 0.40}}},
  {id = "disco", name = "DISCO INFERNO", desc = "Burn, baby, burn. The whole HUD is the dance floor.", anim = "disco", c = {
    bg = {0.20, 0.00, 0.20}, panel = {0.25, 0.05, 0.25}, line = {1, 1, 1}, white = {1, 1, 1},
    dim = {1.00, 0.80, 1.00}, faint = {0.50, 0.30, 0.50}, red = {1.00, 0.30, 0.30}, orange = {1.00, 0.90, 0.20},
    teal = {0.40, 0.10, 0.40}, sea = {0.22, 0.02, 0.22}, gold = {1.00, 0.95, 0.50}}},
  {id = "deepfried", name = "DEEP FRIED", desc = "Saturation 900%. Crispy around the edges.", anim = "fried",
    lock = "Overheat the core 10 times", unlocked = function(S) return (S.overheats or 0) >= 10 end, c = {
    bg = {0.30, 0.05, 0.00}, panel = {0.55, 0.12, 0.00}, line = {1.00, 1.00, 0.00}, white = {1, 1, 1},
    dim = {1.00, 0.60, 0.00}, faint = {0.75, 0.25, 0.00}, red = {1.00, 0.00, 0.00}, orange = {1.00, 0.45, 0.00},
    teal = {0.80, 0.20, 0.00}, sea = {0.45, 0.08, 0.00}, gold = {1.00, 1.00, 0.30}}},
  ---------------------------------------------------------------- really dumb (the whole screen misbehaves; F9 escapes)
  {id = "australia", name = "G'DAY MATE", desc = "Australian edition. Everything is the right way up now. [F9 escapes]",
    cursed = true, screen = "upsidedown", c = {
    bg = {0.10, 0.04, 0.02}, panel = {0.17, 0.07, 0.03}, line = {1.00, 0.62, 0.25}, white = {1.00, 0.93, 0.82},
    dim = {0.75, 0.50, 0.32}, faint = {0.35, 0.18, 0.09}, red = {1.00, 0.30, 0.20}, orange = {1.00, 0.80, 0.30},
    teal = {0.40, 0.20, 0.08}, sea = {0.05, 0.12, 0.20}, gold = {1.00, 0.85, 0.35}}},
  {id = "mirror", name = "MIRROR DIMENSION", desc = "Same tower, other side of the glass. Text included. [F9 escapes]",
    cursed = true, screen = "mirror", c = {
    bg = {0.05, 0.02, 0.08}, panel = {0.09, 0.04, 0.13}, line = {0.78, 0.60, 1.00}, white = {0.96, 0.93, 1.00},
    dim = {0.55, 0.45, 0.70}, faint = {0.22, 0.15, 0.30}, red = {1.00, 0.35, 0.50}, orange = {0.60, 1.00, 0.90},
    teal = {0.25, 0.15, 0.40}, sea = {0.07, 0.04, 0.10}, gold = {1.00, 0.88, 0.50}}},
  {id = "drunk", name = "ONE TOO MANY", desc = "The tower is fine. You are swaying. [F9 escapes]", cursed = true, screen = "drunk", c = {
    bg = {0.08, 0.05, 0.01}, panel = {0.14, 0.09, 0.02}, line = {1.00, 0.78, 0.25}, white = {1.00, 0.97, 0.85},
    dim = {0.70, 0.55, 0.25}, faint = {0.30, 0.22, 0.08}, red = {1.00, 0.40, 0.25}, orange = {1.00, 0.95, 0.70},
    teal = {0.35, 0.25, 0.08}, sea = {0.10, 0.07, 0.02}, gold = {1.00, 0.95, 0.55}}},
  {id = "wide", name = "WIDE TOWER", desc = "Wide tower. Wide tower. Wide tower. [F9 escapes]", cursed = true, screen = "wide", c = {
    bg = {0.024, 0.036, 0.048}, panel = {0.035, 0.058, 0.075}, line = {0.55, 0.86, 0.96}, white = {0.90, 0.97, 1.00},
    dim = {0.36, 0.52, 0.60}, faint = {0.16, 0.27, 0.32}, red = {1.00, 0.27, 0.22}, orange = {1.00, 0.58, 0.20},
    teal = {0.13, 0.42, 0.52}, sea = {0.03, 0.075, 0.095}, gold = {1.00, 0.84, 0.36}}},
  {id = "beyblade", name = "LET IT RIP", desc = "The HUD is a beyblade now. 3, 2, 1... [F9 escapes]", cursed = true, screen = "spin", c = {
    bg = {0.02, 0.04, 0.10}, panel = {0.04, 0.08, 0.18}, line = {0.30, 0.70, 1.00}, white = {1, 1, 1},
    dim = {0.45, 0.60, 0.85}, faint = {0.15, 0.22, 0.38}, red = {1.00, 0.35, 0.20}, orange = {1.00, 0.70, 0.10},
    teal = {0.10, 0.25, 0.50}, sea = {0.03, 0.06, 0.14}, gold = {1.00, 0.85, 0.30}}},
  {id = "earthquake", name = "EARTHQUAKE", desc = "Magnitude 7.4 and the tower keeps harvesting. [F9 escapes]", cursed = true, screen = "quake", c = {
    bg = {0.09, 0.07, 0.05}, panel = {0.15, 0.12, 0.09}, line = {0.90, 0.75, 0.55}, white = {1.00, 0.95, 0.88},
    dim = {0.62, 0.52, 0.40}, faint = {0.30, 0.24, 0.18}, red = {1.00, 0.38, 0.25}, orange = {1.00, 0.70, 0.35},
    teal = {0.32, 0.25, 0.18}, sea = {0.11, 0.09, 0.07}, gold = {1.00, 0.88, 0.50}}},
  {id = "tilted", name = "TILTED", desc = "Like you after the third bad pull in a row.", screen = "tilt", c = {
    bg = {0.03, 0.03, 0.05}, panel = {0.06, 0.06, 0.09}, line = {0.95, 0.40, 0.40}, white = {1, 0.95, 0.95},
    dim = {0.60, 0.45, 0.48}, faint = {0.24, 0.17, 0.19}, red = {1.00, 0.25, 0.25}, orange = {1.00, 0.65, 0.30},
    teal = {0.30, 0.14, 0.16}, sea = {0.06, 0.04, 0.05}, gold = {1.00, 0.85, 0.40}}},
  {id = "breathe", name = "BREATHE IN", desc = "The tower breathes. In for four. Out for four.", screen = "breathe", c = {
    bg = {0.03, 0.07, 0.07}, panel = {0.05, 0.11, 0.11}, line = {0.45, 0.90, 0.80}, white = {0.90, 1.00, 0.97},
    dim = {0.40, 0.62, 0.58}, faint = {0.14, 0.26, 0.24}, red = {1.00, 0.45, 0.45}, orange = {0.85, 0.95, 0.60},
    teal = {0.10, 0.32, 0.30}, sea = {0.04, 0.09, 0.09}, gold = {1.00, 0.92, 0.60}}},
  {id = "partyhard", name = "PARTY HARD", desc = "120 BPM. The whole HUD is on the beat. [F9 escapes]", cursed = true, screen = "party", anim = "disco", c = {
    bg = {0.20, 0.00, 0.20}, panel = {0.25, 0.05, 0.25}, line = {1, 1, 1}, white = {1, 1, 1},
    dim = {1.00, 0.80, 1.00}, faint = {0.50, 0.30, 0.50}, red = {1.00, 0.30, 0.30}, orange = {1.00, 0.90, 0.20},
    teal = {0.40, 0.10, 0.40}, sea = {0.22, 0.02, 0.22}, gold = {1.00, 0.95, 0.50}}},
  {id = "dvd", name = "DVD SCREENSAVER", desc = "Will it hit the corner? It will. Eventually. [F9 escapes]", cursed = true, screen = "dvd", anim = "dvd", c = {
    bg = {0, 0, 0}, panel = {0.06, 0.06, 0.06}, line = {0.30, 0.55, 1.00}, white = {1, 1, 1},
    dim = {0.60, 0.60, 0.65}, faint = {0.20, 0.20, 0.22}, red = {1.00, 0.30, 0.30}, orange = {1.00, 0.75, 0.25},
    teal = {0.15, 0.25, 0.45}, sea = {0.04, 0.04, 0.06}, gold = {1.00, 0.90, 0.40}}},
  {id = "comicsans", name = "COMIC SANS PRO", desc = "For serious business decisions only.", font = "comic.ttf", c = {
    bg = {1.00, 0.98, 0.90}, panel = {1.00, 0.95, 0.80}, line = {0.20, 0.45, 0.95}, white = {0.15, 0.10, 0.30},
    dim = {0.45, 0.40, 0.55}, faint = {0.88, 0.82, 0.70}, red = {0.95, 0.20, 0.30}, orange = {1.00, 0.50, 0.10},
    teal = {0.75, 0.88, 1.00}, sea = {0.85, 0.92, 1.00}, gold = {0.85, 0.60, 0.00}}},
  ---------------------------------------------------------------- cursed: barely or not playable. F9 always escapes.
  {id = "fiftyshades", name = "50 SHADES OF GRAY", desc = "Everything is gray. Good luck. [F9 escapes]", cursed = true, c = {
    bg = {0.50, 0.50, 0.50}, panel = {0.51, 0.51, 0.51}, line = {0.53, 0.53, 0.53}, white = {0.55, 0.55, 0.55},
    dim = {0.52, 0.52, 0.52}, faint = {0.505, 0.505, 0.505}, red = {0.54, 0.53, 0.53}, orange = {0.54, 0.54, 0.53},
    teal = {0.51, 0.51, 0.52}, sea = {0.50, 0.50, 0.51}, gold = {0.56, 0.56, 0.55}}},
  {id = "blackout", name = "BLACKOUT", desc = "Who turned off the lights? [F9 escapes]", cursed = true, c = {
    bg = {0, 0, 0}, panel = {0.01, 0.01, 0.01}, line = {0.03, 0.03, 0.03}, white = {0.05, 0.05, 0.05},
    dim = {0.03, 0.03, 0.03}, faint = {0.015, 0.015, 0.015}, red = {0.06, 0.02, 0.02}, orange = {0.05, 0.04, 0.02},
    teal = {0.01, 0.02, 0.02}, sea = {0.005, 0.01, 0.01}, gold = {0.06, 0.06, 0.04}}},
  {id = "flashbang", name = "FLASHBANG", desc = "OUT! MY! EYES! [F9 escapes]", cursed = true, c = {
    bg = {1, 1, 1}, panel = {1, 1, 1}, line = {0.97, 0.97, 0.97}, white = {0.95, 0.95, 0.95},
    dim = {0.97, 0.97, 0.97}, faint = {0.99, 0.99, 0.99}, red = {1.00, 0.94, 0.94}, orange = {1.00, 0.97, 0.92},
    teal = {0.98, 0.98, 1.00}, sea = {0.99, 0.99, 1.00}, gold = {1.00, 0.98, 0.90}}},
  {id = "greenscreen", name = "CHROMA KEY", desc = "We will add the UI in post. [F9 escapes]", cursed = true, c = {
    bg = {0.0, 0.85, 0.0}, panel = {0.0, 0.85, 0.0}, line = {0.0, 0.92, 0.0}, white = {0.0, 1.0, 0.0},
    dim = {0.0, 0.88, 0.0}, faint = {0.0, 0.86, 0.0}, red = {0.1, 0.9, 0.0}, orange = {0.05, 0.95, 0.0},
    teal = {0.0, 0.84, 0.05}, sea = {0.0, 0.83, 0.02}, gold = {0.15, 1.0, 0.1}}},
  {id = "missing", name = "404 THEME NOT FOUND", desc = "Missing texture. Please reinstall reality. [F9 escapes]", cursed = true, anim = "missing", c = {
    bg = {1, 0, 1}, panel = {0, 0, 0}, line = {1, 0, 1}, white = {0, 0, 0},
    dim = {1, 0, 1}, faint = {0, 0, 0}, red = {1, 0, 1}, orange = {0, 0, 0},
    teal = {1, 0, 1}, sea = {0, 0, 0}, gold = {1, 0, 1}}},
  {id = "stickynote", name = "STICKY NOTE IN THE SUN", desc = "Yellow on yellow. Very readable. [F9 escapes]", cursed = true, c = {
    bg = {1.00, 0.95, 0.40}, panel = {1.00, 0.93, 0.35}, line = {1.00, 1.00, 0.55}, white = {1.00, 0.98, 0.70},
    dim = {0.98, 0.90, 0.40}, faint = {1.00, 0.92, 0.38}, red = {1.00, 0.85, 0.35}, orange = {1.00, 0.96, 0.50},
    teal = {0.98, 0.92, 0.42}, sea = {1.00, 0.94, 0.45}, gold = {1.00, 1.00, 0.60}}},
  {id = "camo", name = "TACTICAL CAMO", desc = "The UI is hiding. From the scavs. And from you. [F9 escapes]", cursed = true, c = {
    bg = {0.28, 0.32, 0.20}, panel = {0.30, 0.33, 0.21}, line = {0.33, 0.36, 0.23}, white = {0.36, 0.38, 0.25},
    dim = {0.31, 0.34, 0.22}, faint = {0.29, 0.33, 0.21}, red = {0.35, 0.33, 0.22}, orange = {0.34, 0.35, 0.22},
    teal = {0.27, 0.31, 0.20}, sea = {0.26, 0.30, 0.19}, gold = {0.37, 0.38, 0.24}}},
  {id = "colorblindhard", name = "RED/GREEN HARD MODE", desc = "Every alert is red. Or green. Who knows. [F9 escapes]", cursed = true, c = {
    bg = {0.12, 0.10, 0.04}, panel = {0.16, 0.14, 0.06}, line = {0.55, 0.50, 0.15}, white = {0.60, 0.55, 0.18},
    dim = {0.45, 0.42, 0.14}, faint = {0.25, 0.22, 0.08}, red = {0.58, 0.48, 0.12}, orange = {0.52, 0.52, 0.14},
    teal = {0.20, 0.20, 0.07}, sea = {0.14, 0.13, 0.05}, gold = {0.60, 0.56, 0.16}}},
  {id = "seasick", name = "SEASICK", desc = "The whole palette drifts. Bring a bucket. [F9 escapes]", cursed = true, anim = "seasick", c = {
    bg = {0.05, 0.10, 0.08}, panel = {0.08, 0.15, 0.12}, line = {0.50, 0.85, 0.60}, white = {0.90, 1.00, 0.90},
    dim = {0.40, 0.60, 0.45}, faint = {0.15, 0.25, 0.18}, red = {0.90, 0.50, 0.30}, orange = {0.80, 0.85, 0.30},
    teal = {0.15, 0.35, 0.25}, sea = {0.06, 0.12, 0.10}, gold = {0.90, 0.95, 0.50}}},
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

-- screen warps: the silly themes move the whole HUD (input is mapped back, so everything stays clickable)
local dvd = {x = 120, y = 80, vx = 150, vy = 110, hue = 0.6, last = nil}
T.SCREEN = {
  upsidedown = function(t) return {rot = math.pi} end,
  mirror = function(t) return {sx = -1} end,
  drunk = function(t)
    return {rot = 0.05 * math.sin(t * 0.9) + 0.02 * math.sin(t * 2.3), dx = 22 * math.sin(t * 0.7), dy = 12 * math.sin(t * 1.13),
      sx = 1 + 0.03 * math.sin(t * 0.5), sy = 1 + 0.03 * math.sin(t * 0.61)}
  end,
  wide = function(t) return {sx = 1.45, sy = 0.82} end,
  spin = function(t) return {rot = t * 0.6, sx = 0.78, sy = 0.78} end,
  quake = function(t)
    local r = love.math.random
    return {dx = (r() * 2 - 1) * 7, dy = (r() * 2 - 1) * 7, rot = (r() * 2 - 1) * 0.008}
  end,
  tilt = function(t) return {rot = 0.14, sx = 0.88, sy = 0.88} end,
  breathe = function(t) local s = 1 + 0.045 * math.sin(t * math.pi / 4) return {sx = s, sy = s} end,
  party = function(t)
    local beat = (t * 2) % 1                       -- 120 bpm
    local kick = math.max(0, 1 - beat * 4)
    local side = math.floor(t * 2) % 2 == 0 and 1 or -1
    return {sx = 1 + 0.05 * kick, sy = 1 + 0.07 * kick, rot = 0.035 * side * kick, dy = -10 * kick}
  end,
  dvd = function(t)
    -- the whole game bounces around like the logo; every wall changes colour, a corner is a celebration
    local now = love.timer.getTime()
    local dt = math.min(0.1, now - (dvd.last or now))
    dvd.last = now
    local s = 0.42
    local hw, hh = 1280 * s / 2, 720 * s / 2
    dvd.x, dvd.y = dvd.x + dvd.vx * dt, dvd.y + dvd.vy * dt
    local hitX, hitY = false, false
    if dvd.x < -640 + hw then dvd.x = -640 + hw; dvd.vx = math.abs(dvd.vx); hitX = true end
    if dvd.x > 640 - hw then dvd.x = 640 - hw; dvd.vx = -math.abs(dvd.vx); hitX = true end
    if dvd.y < -360 + hh then dvd.y = -360 + hh; dvd.vy = math.abs(dvd.vy); hitY = true end
    if dvd.y > 360 - hh then dvd.y = 360 - hh; dvd.vy = -math.abs(dvd.vy); hitY = true end
    if hitX or hitY then dvd.hue = (dvd.hue + 0.17 + love.math.random() * 0.2) % 1 end
    if hitX and hitY then
      local FX = require "game.fx"
      FX.slam("CORNER!!!", 640, 300, H.C.gold, true)
      FX.toast("IT HIT THE CORNER", "Everyone in the office stands up and cheers.", H.C.gold)
    end
    return {sx = s, sy = s, dx = dvd.x, dy = dvd.y}
  end,
}

-- animated themes recolour the live palette every frame (the theme's c table stays the base / preview)
local hue = function(h) return H.hue(h) end
T.ANIM = {
  rainbow = function(t, C)
    C.line[1], C.line[2], C.line[3] = hue(t * 0.30)
    C.orange[1], C.orange[2], C.orange[3] = hue(t * 0.30 + 0.33)
    C.red[1], C.red[2], C.red[3] = hue(t * 0.30 + 0.55)
    C.gold[1], C.gold[2], C.gold[3] = hue(t * 0.30 + 0.75)
    C.dim[1], C.dim[2], C.dim[3] = hue(t * 0.30 + 0.15)
  end,
  disco = function(t, C)
    local r, g, b = hue(t * 0.18)
    C.bg[1], C.bg[2], C.bg[3] = r * 0.22, g * 0.22, b * 0.22
    C.panel[1], C.panel[2], C.panel[3] = r * 0.32, g * 0.32, b * 0.32
    C.sea[1], C.sea[2], C.sea[3] = r * 0.25, g * 0.25, b * 0.25
    C.line[1], C.line[2], C.line[3] = hue(t * 0.18 + 0.5)
  end,
  fried = function(t, C)
    -- slow "jpeg crunch" wobble of the warm colors
    local w = 0.5 + 0.5 * math.sin(t * 2.3)
    C.line[2] = 0.85 + 0.15 * w
    C.panel[1] = 0.45 + 0.15 * math.sin(t * 1.7)
    C.orange[2] = 0.35 + 0.2 * math.sin(t * 3.1)
  end,
  dvd = function(t, C)
    local r, g, b = hue(dvd.hue)
    C.line[1], C.line[2], C.line[3] = r, g, b
    C.orange[1], C.orange[2], C.orange[3] = hue(dvd.hue + 0.5)
  end,
  missing = function(t, C)
    -- checkerboard flip: magenta and black swap roles every 1.5 seconds
    local on = math.floor(t / 1.5) % 2 == 0
    local a, b = on and {1, 0, 1} or {0, 0, 0}, on and {0, 0, 0} or {1, 0, 1}
    for _, k in ipairs({"bg", "line", "dim", "red", "teal", "gold"}) do C[k][1], C[k][2], C[k][3] = a[1], a[2], a[3] end
    for _, k in ipairs({"panel", "white", "faint", "orange", "sea"}) do C[k][1], C[k][2], C[k][3] = b[1], b[2], b[3] end
  end,
  seasick = function(t, C)
    -- every color slowly drifts around the hue wheel at a different speed
    local keys = {"bg", "panel", "line", "white", "dim", "faint", "red", "orange", "teal", "sea", "gold"}
    for i, k in ipairs(keys) do
      local r, g, b = hue(t * (0.04 + i * 0.013) + i * 0.09)
      local base = T.current and T.current.c[k] or C[k]
      local m = (base[1] + base[2] + base[3]) / 3
      C[k][1], C[k][2], C[k][3] = r * m * 1.3, g * m * 1.3, b * m * 1.3
    end
  end,
}
function T.animate(t)
  local th = T.current
  if th and th.anim and T.ANIM[th.anim] then T.ANIM[th.anim](t, H.C) end
  V.fx = th and th.screen and T.SCREEN[th.screen] and T.SCREEN[th.screen](t) or nil
end

function T.get(id)
  for _, t in ipairs(T.LIST) do if t.id == id then return t end end
  return T.LIST[1]
end

function T.isUnlocked(t, S)
  return not t.unlocked or (S and t.unlocked(S))
end

function T.apply(id)
  local t = T.get(id)
  T.current = t
  -- every theme is a HUD theme: palette, optional typeface, optional sound pack
  H.style = nil
  require("game.fx").soundPack = t.cursed and "stupid" or nil
  V.setFace(t.font)
  V.chamfer = H.CUT
  for k, v in pairs(t.c) do
    local dst = H.C[k]
    if dst then dst[1], dst[2], dst[3] = v[1], v[2], v[3] end
  end
end

return T
