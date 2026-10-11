-- THE REACTOR. One instrument in four zones, read from the outside in:
--   INTAKE  outer ring, one port per unit type. Energy streams from the ports into the core, brighter where a
--           unit type contributes more of your output: idle production made visible.
--   SURGE   24 cells. Taps fill it; full = output x3, the ring spins and counts down.
--   HEAT    a 270 degree gauge hugging the core. Gold band = sweet spot (tap bonus, rhythm builds along it),
--           red band = overheat. The readout sits in the gauge's gap, not off to the side.
--   CORE    the tap target. Its colour is the heat (ice -> gold -> red, dark while venting), its brightness
--           the tapping; each tap compresses it. The Tower 07 mark sits in the nucleus.
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local F = require "ui.frame"
local lg = V.lg
local C, col, clamp, fmt = H.C, H.col, H.clamp, H.fmt
local TAU = math.pi * 2
local R = {}

local R_CORE, R_HEAT, R_SURGE, R_INTAKE = 46, 80, 114, 152
local A0, A1 = math.pi * 0.75, math.pi * 2.25 -- heat gauge: 270 degrees, open at the bottom
local function ang(t) return A0 + (A1 - A0) * clamp(t, 0, 1) end
local function portAngle(i) return -math.pi / 2 + (i - 1) / #D.GENS * TAU end

local function lerp3(a, b, t) return {a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t} end

-- heat colour: ice below the sweet spot, gold inside it, red above / overheated
local function heatColor()
  if G.overheatT > 0 then return C.red end
  local h = G.heat
  if h < G.SWEET_LO then return lerp3(C.line, C.gold, clamp((h - G.SWEET_LO + 0.25) / 0.25, 0, 1)) end
  if h <= G.SWEET_HI then return C.gold end
  return lerp3(C.gold, C.red, clamp((h - G.SWEET_HI) / 0.05, 0, 1))
end

----------------------------------------------------------------------
-- intake streams
----------------------------------------------------------------------
local motes, spawnAcc, lastT = {}, 0, nil
local function shares()
  local S = G.S
  local out, total = {}, 0
  for i = 1, #D.GENS do
    local v = (S.gens[i] or 0) > 0 and (G.genEach[i] or 0) * S.gens[i] or 0
    out[i] = v; total = total + v
  end
  if total > 0 then for i = 1, #out do out[i] = out[i] / total end end
  return out, total
end

local function intake(OX, OY, share, total, dt)
  -- the ring and its ports
  col(C.faint, 0.9); lg.circle("line", OX, OY, R_INTAKE, 96)
  for i = 1, #D.GENS do
    local a = portAngle(i)
    local s = share[i] or 0
    local open = G.revealedGen(i)
    local ca, sa = math.cos(a), math.sin(a)
    if s > 0 then
      local k = 0.35 + 0.65 * math.min(1, s * 3)
      lg.setLineWidth(3); col(C.line, k)
      lg.line(OX + ca * (R_INTAKE - 4), OY + sa * (R_INTAKE - 4), OX + ca * (R_INTAKE + 8), OY + sa * (R_INTAKE + 8))
      lg.setLineWidth(1)
    else
      col(open and C.dim or C.faint, open and 0.6 or 0.5)
      lg.line(OX + ca * R_INTAKE, OY + sa * R_INTAKE, OX + ca * (R_INTAKE + 5), OY + sa * (R_INTAKE + 5))
    end
  end
  -- streams: spawn rate follows output (log scale), the source port follows each unit type's share
  if total > 0 and not H.reduced then
    local rate = 6 + math.min(40, math.log10(total + 1) * 2.4)
    spawnAcc = spawnAcc + dt * rate
    while spawnAcc >= 1 and #motes < 70 do
      spawnAcc = spawnAcc - 1
      local r, pick = love.math.random(), 1
      for i = 1, #share do r = r - share[i]; if r <= 0 then pick = i break end end
      motes[#motes + 1] = {a = portAngle(pick) + (love.math.random() - 0.5) * 0.05, r = R_INTAKE - 2, v = 60 + love.math.random() * 40}
    end
    spawnAcc = math.min(spawnAcc, 1)
  end
  for k = #motes, 1, -1 do
    local m = motes[k]
    m.r = m.r - m.v * dt
    m.v = m.v + 70 * dt -- accelerating into the core
    if m.r <= R_CORE + 4 then
      table.remove(motes, k)
    else
      local f = (m.r - R_CORE) / (R_INTAKE - R_CORE)
      local a = math.min(1, (1 - f) * 3) * math.min(1, f * 4)
      local ca, sa = math.cos(m.a), math.sin(m.a)
      col(C.line, 0.75 * a)
      lg.line(OX + ca * m.r, OY + sa * m.r, OX + ca * (m.r + 7), OY + sa * (m.r + 7))
    end
  end
end

----------------------------------------------------------------------
-- flanks: the plant around the reactor. Both are instruments, not decoration.
--   left  COOLANT LOOP  tank level = 1 - heat; drains while venting; coolant flows in faster the hotter it runs
--   right OUTPUT BUS    capacitor stack charged from the ring; cycle speed follows energy/sec, orange in a surge
----------------------------------------------------------------------
local FLANK = 232 -- distance from the core to each module's centre
local busPhase = 0

-- a conduit: two rails, with dashes travelling a -> b (horizontal only)
local function conduit(ax, bx, y, c, speed, a)
  col(C.faint); lg.line(ax, y - 4, bx, y - 4); lg.line(ax, y + 4, bx, y + 4)
  if speed <= 0 then return end
  local dir = bx > ax and 1 or -1
  local len = math.abs(bx - ax)
  local off = H.reduced and 0 or (love.timer.getTime() * speed) % 14
  col(c, a or 0.7)
  for d = off, len - 6, 14 do lg.rectangle("fill", ax + dir * d - (dir < 0 and 6 or 0), y - 1, 6, 2) end
end
local function clamp4(x, y) col(C.dim, 0.8); lg.rectangle("line", x - 3, y - 8, 6, 16) end

local function coolant(OX, OY, dt)
  local Fo = H.fonts
  local hot = G.overheatT > 0
  local cx = OX - FLANK
  local tw, th = 30, 150
  local tx, ty = cx - tw / 2, OY - th / 2
  local level = clamp(1 - G.heat, 0, 1)
  local lc = (hot or G.heat > G.SWEET_HI) and C.red or C.line
  -- loop into the ring: flows faster the hotter the core runs
  conduit(tx + tw, OX - R_INTAKE - 2, OY, C.line, hot and 0 or (12 + G.heat * 70), 0.55)
  clamp4(OX - R_INTAKE - 8, OY)
  -- tank
  col(C.panel, 0.9); lg.rectangle("fill", tx, ty, tw, th, 6, 6)
  local top = ty + th - th * level
  if level > 0.01 then
    col(lc, 0.28); lg.rectangle("fill", tx + 2, top, tw - 4, ty + th - top - 2, 4, 4)
    col(lc, 0.9); lg.line(tx + 3, top, tx + tw - 3, top)
  end
  col(C.faint); lg.rectangle("line", tx + 0.5, ty + 0.5, tw - 1, th - 1, 6, 6)
  for k = 1, 4 do col(C.dim, 0.5); lg.line(tx - 6, ty + th * k / 5, tx - 2, ty + th * k / 5) end
  -- vent at the top: steam while the core is venting
  col(C.dim, 0.8); lg.line(cx, ty, cx, ty - 10); lg.line(cx - 6, ty - 10, cx + 6, ty - 10)
  if hot and not H.reduced then
    local t = love.timer.getTime()
    for k = 1, 5 do
      local p = (t * 1.1 + k / 5) % 1
      col(C.white, 0.22 * (1 - p)); lg.circle("fill", cx + math.sin(k * 1.7 + t * 2) * 6, ty - 14 - p * 46, 2 + p * 7, 10)
    end
  end
  lg.setFont(Fo.xs); col(C.dim); lg.printf("COOLANT", cx - 40, ty + th + 8, 80, "center")
  col(lc); lg.printf(math.floor(level * 100) .. "%", cx - 40, ty + th + 22, 80, "center")
  if H.mouseIn(tx - 10, ty - 20, tw + 20, th + 56) then
    H.setTip("COOLANT LOOP", "Coolant drops as the core heats up. In the gold sweet spot it runs low on purpose; at 0% the core overheats and vents.")
  end
end

local function outputBus(OX, OY, dt)
  local Fo = H.fonts
  local cx = OX + FLANK
  local surging = G.hasBuff("CORE SURGE")
  local bc = surging and C.orange or C.line
  local cps = G.getCps()
  local speed = (0.25 + math.min(1.2, math.log10(cps + 1) * 0.05)) * (surging and 2 or 1)
  if not H.reduced then busPhase = (busPhase + dt * speed) % 1 end
  local n, cw, ch, gap = 10, 34, 11, 4
  local th = n * ch + (n - 1) * gap
  local tx, ty = cx - cw / 2, OY - th / 2
  conduit(OX + R_INTAKE + 2, tx, OY, bc, 20 + speed * 40, 0.6)
  clamp4(OX + R_INTAKE + 8, OY)
  -- the stack charges bottom-up, then discharges in one flash
  local lit = H.reduced and n or math.floor(busPhase * (n + 2))
  local flash = (not H.reduced and lit > n) and (1 - (busPhase * (n + 2) - n) / 2) or 0
  for k = 0, n - 1 do
    local y = ty + th - (k + 1) * ch - k * gap
    col(C.panel, 0.9); lg.rectangle("fill", tx, y, cw, ch)
    if k < lit and lit <= n then col(bc, 0.35 + 0.5 * (k + 1) / n); lg.rectangle("fill", tx + 2, y + 2, cw - 4, ch - 4) end
    if flash > 0 then col(C.white, 0.5 * flash); lg.rectangle("fill", tx + 2, y + 2, cw - 4, ch - 4) end
    col(C.faint); lg.rectangle("line", tx + 0.5, y + 0.5, cw - 1, ch - 1)
  end
  -- bus terminals
  col(C.dim, 0.8); lg.line(cx, ty, cx, ty - 10); lg.line(cx - 8, ty - 10, cx + 8, ty - 10); lg.line(cx - 4, ty - 14, cx + 4, ty - 14)
  lg.setFont(Fo.xs); col(C.dim); lg.printf("OUTPUT BUS", cx - 45, ty + th + 8 + (150 - th) / 2, 90, "center")
  local boost = G.buffMult("prod")
  col(boost > 1 and C.orange or C.line); lg.printf(boost > 1 and ("BOOST x" .. fmt(boost)) or "NOMINAL", cx - 45, ty + th + 22 + (150 - th) / 2, 90, "center")
  if H.mouseIn(tx - 10, ty - 20, cw + 20, th + 56) then
    H.setTip("OUTPUT BUS", "The reactor charges the bus; it cycles faster the more energy per second you make, twice as fast in a Core Surge. Shows any active output boost.")
  end
end

----------------------------------------------------------------------
-- surge ring
----------------------------------------------------------------------
local function surgeRing(OX, OY)
  local Fo = H.fonts
  local surging, left = false, 0
  for _, b in ipairs(G.buffs) do if b.name == "CORE SURGE" then surging, left = true, b.t end end
  local n, gap = 24, 0.035
  local fill = surging and 1 or G.surge
  local spin = (surging and not H.reduced) and love.timer.getTime() * 1.6 or 0
  lg.setLineWidth(5)
  for k = 0, n - 1 do
    local a0 = -math.pi / 2 + k / n * TAU + gap + spin
    local a1 = a0 + TAU / n - gap * 2
    local lit = clamp(fill * n - k, 0, 1)
    col(C.faint, 0.7); lg.arc("line", "open", OX, OY, R_SURGE, a0, a1, 6)
    if lit > 0 then
      col(C.orange, surging and (0.65 + 0.35 * math.abs(math.sin(k * 0.5 + love.timer.getTime() * 3))) or 0.9)
      lg.arc("line", "open", OX, OY, R_SURGE, a0, a0 + (a1 - a0) * lit, 6)
    end
  end
  lg.setLineWidth(1)
  -- label sits in the band between surge and intake, at the top
  lg.setFont(Fo.xs)
  if surging then
    col(C.orange); lg.printf("SURGE  x3  //  " .. math.ceil(left) .. "S", OX - 80, OY - R_SURGE - 21, 160, "center")
  else
    col(C.dim); lg.printf("SURGE " .. math.floor(G.surge * 100) .. "%", OX - 80, OY - R_SURGE - 21, 160, "center")
  end
  if H.mouseIn(OX - 60, OY - R_SURGE - 24, 120, 18) then
    H.setTip("CORE SURGE", "Every tap fills the surge ring (double inside the heat sweet spot). Full: all output x3 for 15s.")
  end
end

----------------------------------------------------------------------
-- heat gauge
----------------------------------------------------------------------
local function heatGauge(OX, OY, hc)
  local Fo = H.fonts
  local heat, hot, sweet = G.heat, G.overheatT > 0, G.inSweetSpot()
  lg.setLineWidth(7)
  col(C.faint, 0.6); lg.arc("line", "open", OX, OY, R_HEAT, A0, A1, 48)
  col(C.gold, sweet and 0.45 or 0.22); lg.arc("line", "open", OX, OY, R_HEAT, ang(G.SWEET_LO), ang(G.SWEET_HI), 12)
  col(C.red, 0.3); lg.arc("line", "open", OX, OY, R_HEAT, ang(G.SWEET_HI), A1, 6)
  lg.setLineWidth(3)
  if heat > 0.005 then
    local blink = (hot and not H.reduced) and (0.5 + 0.5 * math.sin(love.timer.getTime() * 14)) or 1
    col(hc, blink); lg.arc("line", "open", OX, OY, R_HEAT, A0, ang(heat), 48)
  end
  -- rhythm: builds along the inside of the gold band while you hold the sweet spot
  if G.sweetT > 0 then
    lg.setLineWidth(2); col(C.gold, 0.9)
    local a = ang(G.SWEET_LO)
    lg.arc("line", "open", OX, OY, R_HEAT - 8, a, a + (ang(G.SWEET_HI) - a) * clamp(G.sweetT / G.RHYTHM_TIME, 0, 1), 16)
  end
  lg.setLineWidth(1)
  -- needle
  local a = ang(heat)
  col(C.white); lg.setLineWidth(2)
  lg.line(OX + math.cos(a) * (R_HEAT - 7), OY + math.sin(a) * (R_HEAT - 7), OX + math.cos(a) * (R_HEAT + 9), OY + math.sin(a) * (R_HEAT + 9))
  lg.setLineWidth(1)
  -- readout in the open bottom of the gauge, between the core and the surge ring
  local ty = OY + R_CORE + 8
  lg.setFont(Fo.m); col(hc); lg.printf(math.floor(heat * 100 + 0.5) .. "%", OX - 60, ty - 2, 120, "center")
  lg.setFont(Fo.xs)
  local state, sc = "HEAT", C.dim
  if hot then state, sc = string.format("VENTING %.1fS", G.overheatT), C.red
  elseif sweet then state, sc = "SWEET SPOT x" .. G.SWEET_MULT, C.gold
  elseif heat > G.SWEET_HI then state, sc = "TOO HOT", C.red end
  col(sc); lg.printf(state, OX - 70, ty + 17, 140, "center")
  if H.mouseIn(OX - 50, ty - 4, 100, 34) then
    H.setTip("CORE HEAT", "Every tap heats the core; it cools on its own. Keep it in the gold band (" ..
      math.floor(G.SWEET_LO * 100) .. "-" .. math.floor(G.SWEET_HI * 100) .. "%) for x" .. G.SWEET_MULT ..
      " tap power and double surge fill. " .. math.floor(G.RHYTHM_TIME) .. "s in a row ignites a Core Surge. 100% = overheat: taps lock for " ..
      G.OVERHEAT_TIME .. "s.")
  end
end

----------------------------------------------------------------------
-- the core
----------------------------------------------------------------------
local function core(OX, OY, hc, ht, down, dt)
  local kick = G.coreKick
  local hot = G.overheatT > 0
  local t = love.timer.getTime()
  local breathe = H.reduced and 0 or 0.02 * math.sin(t * 2)
  local r = R_CORE * (1 + breathe + kick * 0.5 - (down and 0.05 or 0))
  local glow = F.glowMesh()
  local energy = hot and 0.25 or (0.55 + math.min(0.45, kick * 4) + 0.15 * ht)
  -- corona
  lg.setBlendMode("add")
  col(hc, 0.10 * energy); love.graphics.draw(glow, OX, OY, 0, r * 2.4, r * 2.4)
  col(hc, 0.28 * energy); love.graphics.draw(glow, OX, OY, 0, r * 1.35, r * 1.35)
  lg.setBlendMode("alpha")
  -- body
  col(C.bg, 0.85); lg.circle("fill", OX, OY, r, 64)
  col(hc, hot and 0.12 or 0.22); lg.circle("fill", OX, OY, r, 64)
  -- plasma filaments: slow counter-rotating arcs inside the body
  if not hot then
    lg.setLineWidth(1.5)
    for k = 1, 5 do
      local rr = r * (0.42 + k * 0.1)
      local s = (k % 2 == 0 and -1 or 1) * (0.4 + k * 0.15)
      local a = (H.reduced and 0 or t * s) + k * 1.3
      col(hc, 0.35 + 0.1 * k * energy)
      lg.arc("line", "open", OX, OY, rr, a, a + 0.9 + 0.25 * k, 16)
    end
    lg.setLineWidth(1)
  else
    -- venting: dark core, steam rising
    for k = 1, 6 do
      local p = ((t * 0.8 + k / 6) % 1)
      col(C.white, 0.25 * (1 - p)); lg.circle("fill", OX + math.sin(k * 2.1 + t) * 14, OY - r * 0.2 - p * 60, 3 + p * 8, 12)
    end
  end
  -- rim
  col(hc, 0.7 + 0.3 * ht); lg.setLineWidth(1.5 + ht); lg.circle("line", OX, OY, r, 64); lg.setLineWidth(1)
  -- nucleus with the tower mark cut out of it
  local nr = r * (0.42 + kick * 1.2)
  col(C.white, hot and 0.3 or (0.75 + 0.25 * energy)); lg.circle("fill", OX, OY, nr, 40)
  local s = nr * 0.62
  col(C.bg); lg.polygon("fill", OX - s, OY - s * 0.5, OX + s, OY - s * 0.5, OX, OY + s * 0.8)
  col(C.white, hot and 0.3 or 0.9); local s2 = s * 0.45
  lg.polygon("fill", OX - s2, OY - s * 0.5 + s2 * 0.15, OX + s2, OY - s * 0.5 + s2 * 0.15, OX, OY - s * 0.5 + s2 * 1.35)
end

----------------------------------------------------------------------
function R.draw()
  local S = G.S
  local Fo = H.fonts
  local OX, OY = G.OX, G.OY
  local now = love.timer.getTime()
  local dt = lastT and math.min(0.05, now - lastT) or 0
  lastT = now
  local mx, my = V.mouse()
  local hov = R.hit(mx, my) and not G.modal
  local down = hov and love.mouse.isDown(1)
  local ht = H.tween("reactorHov", hov and 1 or 0, H.MO.fast)
  local hc = heatColor()
  if G.hasBuff("CORE SURGE") and G.overheatT <= 0 and G.heat < G.SWEET_LO then hc = C.orange end
  -- a dark well separates the instrument from the grid
  local glow = F.glowMesh()
  col(C.bg, 0.75); love.graphics.draw(glow, OX, OY, 0, R_INTAKE + 40, R_INTAKE + 40)
  coolant(OX, OY, dt)
  outputBus(OX, OY, dt)
  local share, total = shares()
  intake(OX, OY, share, total, dt)
  surgeRing(OX, OY)
  heatGauge(OX, OY, hc)
  -- target lock: brackets close in on the clickable edge (also shown to brand-new players)
  local first = S.clicks < 5
  local lockT = math.max(ht, first and (0.55 + 0.25 * math.sin(G.time * 3)) or 0)
  if lockT > 0.01 then
    local rr = R.hitR() + (1 - lockT) * 12
    lg.setLineWidth(2); col(down and C.white or C.line, lockT)
    for i = 0, 3 do
      local a = i * TAU / 4 + TAU / 8
      lg.arc("line", "open", OX, OY, rr, a - 0.16, a + 0.16, 8)
    end
    lg.setLineWidth(1)
  end
  core(OX, OY, hc, ht, down, dt)
  -- tap chain: only while it is alive, right above the core
  if G.combo > 1 then
    lg.setFont(Fo.xs); col(C.red); lg.printf(string.format("CHAIN x%.2f", 1 + math.min(G.combo, 200) * 0.005), OX - 60, OY - R_HEAT - 20, 120, "center")
  end
  FX.drawWaves()
  if first then
    local cy = OY + R_INTAKE + 8
    local txt = "TAP THE CORE TO HARVEST"
    local tw = Fo.xs:getWidth(txt) + 20
    col(C.bg, 0.85); lg.rectangle("fill", OX - tw / 2, cy, tw, 17)
    col(C.orange); lg.rectangle("fill", OX - tw / 2, cy, 2, 17)
    lg.setFont(Fo.xs); col(C.orange); lg.printf(txt, OX - tw / 2, cy + 3, tw, "center")
  end
end

function R.hitR() return 100 end
function R.hit(x, y) return (x - G.OX) ^ 2 + (y - G.OY) ^ 2 < R.hitR() ^ 2 end

return R
