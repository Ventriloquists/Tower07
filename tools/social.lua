-- Dev tool: renders GitHub social preview images (1280x640) with the game's own renderer.
--   love . --social   -> social-1-hero.png ... social-4-signal-lock.png in the save folder (tower_harvest_social)
-- Not part of the release build (release.bat only packs conf.lua, main.lua, game, lib, ui).
local V = require "lib.view"
local H = require "lib.hud"
local G = require "game.core"
local D = require "game.data"
local FX = require "game.fx"
local F = require "ui.frame"
local I = require "ui.icons"
local Th = require "ui.themes"
local Reactor = require "ui.reactor"
local lg = V.lg
local C, col = H.C, H.col
local TAU = math.pi * 2
local W, HH = 1280, 640
local S = {}

local big, mid, kick, shot
local canvases = {}

----------------------------------------------------------------------
-- shared pieces
----------------------------------------------------------------------
local function background(noFrame)
  col(C.bg); lg.rectangle("fill", 0, 0, W, HH)
  local glow = F.glowMesh()
  col(C.line, 0.09); love.graphics.draw(glow, 640, -160, 0, 1000, 560)
  col(C.orange, 0.05); love.graphics.draw(glow, 1180, 700, 0, 700, 420)
  col(C.faint, 0.10)
  for x = 0, W, 40 do lg.line(x, 0, x, HH) end
  for y = 0, HH, 40 do lg.line(0, y, W, y) end
  col(C.dim, 0.22)
  for x = 0, W, 160 do for y = 0, HH, 160 do lg.line(x - 3, y, x + 3, y); lg.line(x, y - 3, x, y + 3) end end
  if noFrame then return end
  -- frame: corner brackets on the safe area
  lg.setLineWidth(2); col(C.line, 0.55)
  local m, L = 28, 46
  lg.line(m, m + L, m, m, m + L, m); lg.line(W - m - L, m, W - m, m, W - m, m + L)
  lg.line(m, HH - m - L, m, HH - m, m + L, HH - m); lg.line(W - m - L, HH - m, W - m, HH - m, W - m, HH - m - L)
  lg.setLineWidth(1)
end

local function titleBlock(x, y, scale, tagline)
  scale = scale or 1
  lg.setFont(H.fonts.xs); col(C.line); lg.print("AN IDLE GAME  //  BUILT WITH LOVE", x, y)
  col(C.line); lg.rectangle("fill", x, y + 18, 44, 2)
  lg.setFont(big); col(C.white); lg.print("TOWER 07", x - 4, y + 26)
  lg.setFont(mid); col(C.orange); lg.print("HARVEST PROTOCOL", x, y + 26 + big:getHeight() - 6)
  if tagline then
    H.richf(tagline, x, y + 46 + big:getHeight() + mid:getHeight(), 520, "left", C.dim, 1, H.fonts.m, true)
  end
end

local function chips(x, y, list)
  local f = H.fonts.xs
  for _, t in ipairs(list) do
    local w = f:getWidth(t) + 22
    col(C.panel, 0.95); H.chamfer("fill", x, y, w, 26, 6)
    col(C.faint); H.chamfer("line", x + 0.5, y + 0.5, w - 1, 25, 6)
    col(C.line); lg.rectangle("fill", x + 1, y + 8, 2, 10)
    lg.setFont(f); col(C.white); lg.printf(t, x, y + 7, w, "center")
    x = x + w + 10
  end
end

-- the live tower reactor, placed with its centre (640, 330) at (cx, cy)
local function tower(cx, cy, sc)
  lg.push()
  love.graphics.translate(cx, cy)
  love.graphics.scale(sc)
  love.graphics.translate(-640, -330)
  Reactor.draw()
  lg.pop()
end

----------------------------------------------------------------------
-- 1. HERO: title left, the tower right
----------------------------------------------------------------------
local function hero()
  background()
  tower(905, 330, 1.02)
  titleBlock(84, 150, 1, "Tap the reactor. Build the fleet. Loot the wastes. Reboot the cycle.")
  chips(84, 488, {"20 UNIT TIERS", "DRONE FLEET", "TACTICAL MAP", "PRESTIGE TREE"})
end

----------------------------------------------------------------------
-- 2. SCREENSHOT: title on top, the game below bleeding off the edge
----------------------------------------------------------------------
local function screenshot()
  background()
  lg.setFont(H.fonts.xs); col(C.line); lg.print("AN IDLE GAME  //  BUILT WITH LOVE", 84, 64)
  lg.setFont(mid); col(C.white); lg.print("TOWER 07", 84, 84)
  local tw = mid:getWidth("TOWER 07")
  col(C.orange); lg.print("// HARVEST PROTOCOL", 84 + tw + 16, 84)
  lg.setFont(H.fonts.m); col(C.dim)
  lg.printf("Tap the reactor. Build the fleet. Reboot the cycle.", 0, 92, W - 84, "right")
  local x, y, sc = 160, 152, 0.75
  local iw, ih = shot:getWidth() * sc, shot:getHeight() * sc
  local glow = F.glowMesh()
  col(C.line, 0.14); love.graphics.draw(glow, x + iw / 2, y + 120, 0, iw * 0.7, 260)
  col(C.bg); lg.rectangle("fill", x - 6, y - 6, iw + 12, ih + 12)
  love.graphics.setColor(1, 1, 1); love.graphics.draw(shot, x, y, 0, sc, sc)
  col(C.line, 0.8); lg.setLineWidth(2); lg.rectangle("line", x - 6, y - 6, iw + 12, ih + 12); lg.setLineWidth(1)
  col(C.orange); lg.rectangle("fill", x - 6, y - 8, 120, 3)
end

----------------------------------------------------------------------
-- 3. SPINE: giant outlined 07, the station line with live readouts
----------------------------------------------------------------------
local function spine()
  background()
  -- outlined numerals
  lg.setFont(kick)
  local nx, ny = 70, 40
  col(C.line, 0.55)
  for k = 0, 15 do
    local a = k / 16 * TAU
    lg.print("07", nx + math.cos(a) * 2.5, ny + math.sin(a) * 2.5)
  end
  col(C.bg); lg.print("07", nx, ny)
  col(C.line, 0.06); lg.print("07", nx, ny)
  -- title
  local tx = 640
  lg.setFont(H.fonts.xs); col(C.line); lg.print("AN IDLE GAME  //  BUILT WITH LOVE", tx, 128)
  col(C.line); lg.rectangle("fill", tx, 146, 44, 2)
  lg.setFont(big); col(C.white); lg.print("TOWER 07", tx - 4, 154)
  lg.setFont(mid); col(C.orange); lg.print("HARVEST PROTOCOL", tx, 154 + big:getHeight() - 6)
  H.richf("Eight stations on one line. Every one tells you what it needs.", tx, 196 + big:getHeight() + mid:getHeight() - 30, 540, "left", C.dim, 1, H.fonts.m, true)
  -- the line
  local stations = {
    {"CORE", "+68.45K/S"}, {"BUILD", "110 TECH READY", "attn"}, {"RIGS", "1 AT PEAK", "attn"}, {"HANGAR", "33 TOKENS", "attn"},
    {"MAP", "MOTHERSHIP", "alert"}, {"OPS", "4 READY", "attn"}, {"REBOOT", "+25 CD", "alert"}, {"ARCHIVE", "145/375"},
  }
  local x0, x1, ly = 96, 1184, 516
  local step = (x1 - x0) / (#stations - 1)
  col(C.dim, 0.7); lg.rectangle("fill", x0, ly, x1 - x0, 1)
  local glow = F.glowMesh()
  col(C.line, 0.18); love.graphics.draw(glow, x0, ly, 0, 120, 40)
  for k, s in ipairs(stations) do
    local cx = x0 + (k - 1) * step
    local lc = s[3] == "alert" and C.red or (s[3] == "attn" and C.orange or nil)
    local r = k == 1 and 7 or 5
    col(C.bg); lg.polygon("fill", cx, ly - r - 3, cx + r + 3, ly, cx, ly + r + 3, cx - r - 3, ly)
    if k == 1 then
      col(C.white); lg.polygon("fill", cx, ly - r, cx + r, ly, cx, ly + r, cx - r, ly)
      col(C.line, 0.8); lg.polygon("line", cx, ly - r - 5, cx + r + 5, ly, cx, ly + r + 5, cx - r - 5, ly)
    else
      col(lc or C.dim); lg.polygon(lc and "fill" or "line", cx, ly - r, cx + r, ly, cx, ly + r, cx - r, ly)
    end
    lg.setFont(H.fonts.s); col(k == 1 and C.white or C.dim); lg.printf(s[1], cx - 80, ly + 16, 160, "center")
    lg.setFont(H.fonts.xs); col(lc or C.dim); lg.printf(s[2], cx - 80, ly + 34, 160, "center")
  end
end

----------------------------------------------------------------------
-- 4. SIGNAL LOCK: a reticle locked on a mythic crate, the readout decoded
----------------------------------------------------------------------
local function signalLock()
  background(true)
  -- a slice of the tactical map: claimed sectors around the drop
  local ox, oy, cs = 560, 104, 38 -- under 40px the HUD keeps cells square, like the real map
  local claimed = {{2, 2}, {3, 2}, {4, 2}, {5, 2}, {1, 3}, {2, 3}, {3, 3}, {4, 3}, {5, 3}, {6, 3}, {2, 4}, {3, 4}, {4, 4}, {5, 4}, {6, 4}, {7, 4},
    {3, 5}, {4, 5}, {5, 5}, {6, 5}, {4, 6}, {5, 6}, {2, 5}, {6, 2}}
  for _, c in ipairs(claimed) do
    local x, y = ox + c[1] * cs, oy + c[2] * cs
    col(C.red, 0.14); lg.rectangle("fill", x + 1, y + 1, cs - 2, cs - 2)
    H.hatch(x + 1, y + 1, cs - 2, cs - 2, C.red, 0.35, 6)
    col(C.red, 0.5); lg.rectangle("line", x + 0.5, y + 0.5, cs - 1, cs - 1)
  end
  -- the crate and the lock
  local gx, gy = ox + 4.5 * cs, oy + 3.5 * cs
  local mc = C.gold
  col(mc); lg.polygon("fill", gx, gy - 9, gx + 9, gy, gx, gy + 9, gx - 9, gy)
  col(C.white); lg.polygon("line", gx, gy - 9, gx + 9, gy, gx, gy + 9, gx - 9, gy)
  lg.setLineWidth(2)
  local s = 25
  col(mc)
  lg.line(gx - s, gy - s + 8, gx - s, gy - s, gx - s + 8, gy - s); lg.line(gx + s - 8, gy - s, gx + s, gy - s, gx + s, gy - s + 8)
  lg.line(gx - s, gy + s - 8, gx - s, gy + s, gx - s + 8, gy + s); lg.line(gx + s - 8, gy + s, gx + s, gy + s, gx + s, gy + s - 8)
  -- leader + readout
  local ax, ay = gx + s, gy - s
  local lx, ly = ax + 26, ay - 24
  col(mc, 0.85); lg.line(ax, ay, lx, ly)
  local lines = {"+343.71Oc ENERGY", "+438.19B PARTS  +750 H2O", "+3 FAB TOKENS"}
  local cw, ch = 360, 38 + #lines * 14
  local cx, cy = lx, ly - 14
  col(C.bg, 0.95); lg.rectangle("fill", cx, cy, cw, ch)
  col(mc); lg.rectangle("fill", cx, cy, 2, ch)
  col(C.faint); lg.rectangle("line", cx + 0.5, cy + 0.5, cw - 1, ch - 1)
  lg.setFont(H.fonts.xs); col(mc); lg.print("MYTHIC CACHE", cx + 11, cy + 5)
  lg.setFont(H.fonts.s); col(C.white); lg.print("MYTHIC TARGETING CHIP (+36% STRIKE CRIT)", cx + 11, cy + 18)
  lg.setFont(H.fonts.xs); col(C.dim)
  for k, l in ipairs(lines) do lg.print(l, cx + 11, cy + 22 + k * 14) end
  -- mythic frame: gold brackets close in on the screen corners
  lg.setLineWidth(3); col(mc, 0.9)
  local m, L = 14, 80
  lg.line(m, m + L, m, m, m + L, m); lg.line(W - m - L, m, W - m, m, W - m, m + L)
  lg.line(m, HH - m - L, m, HH - m, m + L, HH - m); lg.line(W - m - L, HH - m, W - m, HH - m, W - m, HH - m - L)
  lg.setLineWidth(1)
  -- title
  titleBlock(84, 330, 1, "Every drop gets a signal lock. Mythic ones get the whole screen.")
end

----------------------------------------------------------------------
local CARDS = {{"social-1-hero.png", hero}, {"social-2-screenshot.png", screenshot}, {"social-3-spine.png", spine}, {"social-4-signal-lock.png", signalLock}}

function S.start()
  love.filesystem.setIdentity("tower_harvest_social")
  G.selftest = true
  G.init(true)
  G.dailyPending = false
  Th.apply("command")
  H.reduced, H.snap = false, true
  H.keywords = false -- no glossary underlines in a static image
  -- render at exactly 1:1 into 1280x640
  V.resize(1280, 720)
  V.winH = HH
  V.fakeMouse = {-500, -500}
  big, mid, kick = V.newFont(104, true), V.newFont(34, true), V.newFont(330, true)
  shot = love.graphics.newImage("docs/screenshot.png")
  shot:setFilter("linear", "linear")
  for k = 1, #CARDS do canvases[k] = love.graphics.newCanvas(W, HH, {msaa = 4}) end
  -- a mid-game tower: several unit types feeding the crown, heat in the sweet spot, surge filling
  local St = G.S
  for i = 1, 12 do St.gens[i] = math.max(1, 140 - i * 9) end
  St.clicks = 500
  G.recalc()
  local frame = 0
  love.update = function(dt)
    frame = frame + 1
    G.time = G.time + dt
    G.heat, G.overheatT, G.surge, G.combo, G.sweetT, G.coreKick = 0.86, 0, 0.62, 0, 6, 0.02
  end
  love.draw = function()
    H.beginFrame()
    for k, c in ipairs(CARDS) do
      love.graphics.setCanvas(canvases[k])
      love.graphics.clear(C.bg[1], C.bg[2], C.bg[3], 1)
      love.graphics.setColor(1, 1, 1)
      c[2]()
      love.graphics.setCanvas()
    end
    -- preview on screen while it warms up (the reactor's energy streams need a couple of seconds)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvases[1], 0, 0, 0, love.graphics.getWidth() / W, love.graphics.getWidth() / W)
    if frame == 180 then
      for k, c in ipairs(CARDS) do canvases[k]:newImageData():encode("png", c[1]) end
      love.event.quit()
    end
  end
end

return S
