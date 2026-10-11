-- THE TOWER. Tower 07 in elevation, above the cloud layer; its crown is the reactor core you tap.
--   CROWN   the tap target. Its colour is the heat (ice -> gold -> red, dark while venting); heat haze rises
--           above it, the heat gauge wraps it, and each tap compresses it and rolls a shockwave over the clouds.
--   MAST    surge collars: taps light them bottom-up; when they reach the deck the crown ignites (output x3).
--   BEAMS   production: one beam rises out of the clouds for every unit type you run, brighter the more it
--           contributes, energy travelling up it into the tower.
--   CALLOUTS heat (left) and surge (right) are engineering annotations with leader lines, so the flanks carry
--           information instead of decoration.
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

-- geometry (the crown centre is G.OX, G.OY; the tap effects in game/core.lua originate there)
local CLOUD_Y = 452          -- top of the cloud layer
local DECK_Y = 318           -- the platform deck
local HUB_Y = DECK_Y + 6     -- where the beams meet the tower
local CROWN_R = 40           -- the crown sphere
local GAUGE_R = 54           -- heat gauge around the crown
local A0, A1 = math.pi * 0.72, math.pi * 2.28 -- gauge: open at the bottom where the crown sits on its neck
local function ang(t) return A0 + (A1 - A0) * clamp(t, 0, 1) end
local COLLARS = 7

local function lerp3(a, b, t) return {a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t} end
local function heatColor()
  if G.overheatT > 0 then return C.red end
  local h = G.heat
  if h < G.SWEET_LO then return lerp3(C.line, C.gold, clamp((h - G.SWEET_LO + 0.25) / 0.25, 0, 1)) end
  if h <= G.SWEET_HI then return C.gold end
  return lerp3(C.gold, C.red, clamp((h - G.SWEET_HI) / 0.05, 0, 1))
end

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

-- where unit type i's beam leaves the clouds: alternating left/right, spreading outward with the tier
local function beamX(i)
  local side = (i % 2 == 1) and -1 or 1
  local k = math.floor((i - 1) / 2) -- 0..9
  return G.OX + side * (84 + k * 24)
end

-- mast width at a height (tapers toward the deck)
local function mastHalf(y) return 5 + 9 * clamp((y - DECK_Y) / (CLOUD_Y - DECK_Y), 0, 1) end

----------------------------------------------------------------------
-- beams + motes
----------------------------------------------------------------------
local motes, spawnAcc, lastT = {}, 0, nil
-- a vertical light shaft: bright at the cloud tops, fading upward (drawn additive, tinted by setColor)
local shaftMesh
local function shaft()
  if shaftMesh then return shaftMesh end
  shaftMesh = love.graphics.newMesh({
    {-0.5, 0, 0, 0, 1, 1, 1, 0}, {0, 0, 0, 0, 1, 1, 1, 1}, {0.5, 0, 0, 0, 1, 1, 1, 0},
    {0.5, -1, 0, 0, 1, 1, 1, 0}, {0, -1, 0, 0, 1, 1, 1, 0}, {-0.5, -1, 0, 0, 1, 1, 1, 0},
  }, "triangles", "static")
  shaftMesh:setVertexMap(1, 2, 5, 1, 5, 6, 2, 3, 4, 2, 4, 5)
  return shaftMesh
end
local SHAFT_TOP = DECK_Y + 24
local function beams(share, total, dt)
  local OX = G.OX
  local mesh = shaft()
  lg.setBlendMode("add")
  for i = 1, #D.GENS do
    local s = share[i] or 0
    if s > 0 then
      local bx = beamX(i)
      local k = math.min(1, s * 3)
      col(C.line, 0.10 + 0.22 * k)
      love.graphics.draw(mesh, bx, CLOUD_Y + 6, 0, 10 + 14 * k, CLOUD_Y + 6 - SHAFT_TOP)
    end
  end
  lg.setBlendMode("alpha")
  if total > 0 and not H.reduced then
    local rate = 5 + math.min(36, math.log10(total + 1) * 2.2)
    spawnAcc = spawnAcc + dt * rate
    while spawnAcc >= 1 and #motes < 60 do
      spawnAcc = spawnAcc - 1
      local r, pick = love.math.random(), 1
      for i = 1, #share do r = r - share[i]; if r <= 0 then pick = i break end end
      motes[#motes + 1] = {i = pick, p = 0, v = 0.45 + love.math.random() * 0.3, j = (love.math.random() - 0.5) * 6}
    end
    spawnAcc = math.min(spawnAcc, 1)
  end
  -- energy rises up its shaft, then streaks across to the tower at deck height
  for k = #motes, 1, -1 do
    local m = motes[k]
    m.p = m.p + m.v * dt
    if m.p >= 1 then
      table.remove(motes, k)
    else
      local bx = beamX(m.i) + m.j
      local x, y
      if m.p < 0.6 then
        local q = m.p / 0.6
        x, y = bx, CLOUD_Y + 4 + (SHAFT_TOP - CLOUD_Y - 4) * q
      else
        local q = H.ease.inOutCubic((m.p - 0.6) / 0.4)
        x, y = bx + (OX - bx) * q, SHAFT_TOP + (HUB_Y - SHAFT_TOP) * q
      end
      local a = math.min(1, m.p * 6) * math.min(1, (1 - m.p) * 8)
      col(m.p < 0.6 and C.line or C.white, 0.85 * a); lg.rectangle("fill", x - 1.5, y - 1.5, 3, 3)
    end
  end
end

----------------------------------------------------------------------
-- clouds: layered drifting ridges; taps roll a ripple across them
----------------------------------------------------------------------
local ripples = {}
local function clouds(dt)
  local x0, x1 = 330, 950
  local t = H.reduced and 0 or love.timer.getTime()
  -- body of the cloud layer hides the beam roots and the tower base
  local glow = F.glowMesh()
  col(C.bg, 0.9); love.graphics.draw(glow, G.OX, CLOUD_Y + 34, 0, 360, 44)
  -- soft drifting puffs give the layer volume (faded out toward both ends)
  for k = 1, 11 do
    local span = x1 - x0
    local px = x0 + ((k * 97 + t * (4 + k % 3)) % span)
    local edge = math.min(1, (px - x0) / 90, (x1 - px) / 90)
    col(C.dim, 0.10 * edge); love.graphics.draw(glow, px, CLOUD_Y + 8 + math.sin(k * 1.9) * 5, 0, 46 + (k % 4) * 16, 9 + (k % 3) * 3)
  end
  for layer = 0, 3 do
    local y = CLOUD_Y + layer * 9
    local amp = 3 + layer
    local pts = {}
    for x = x0, x1, 10 do
      local edge = math.min(1, (x - x0) / 120, (x1 - x) / 120)
      pts[#pts + 1] = x
      pts[#pts + 1] = y + math.sin(x * 0.03 + t * (0.25 + layer * 0.08) + layer * 1.7) * amp * edge
    end
    col(C.dim, (0.42 - layer * 0.08)); lg.line(pts)
  end
  -- tap ripples: flat ellipses spreading over the cloud tops from under the tower
  for k = #ripples, 1, -1 do
    local r = ripples[k]
    r.t = r.t + dt
    if r.t > 1.1 then table.remove(ripples, k) else
      local p = r.t / 1.1
      col(r.c, 0.5 * (1 - p)); lg.ellipse("line", G.OX, CLOUD_Y + 6, 30 + p * 300, 4 + p * 18, 48)
    end
  end
end

----------------------------------------------------------------------
-- the tower: legs, mast with surge collars, deck with nav lights
----------------------------------------------------------------------
local function tower(hc)
  local OX = G.OX
  local surging, left = false, 0
  for _, b in ipairs(G.buffs) do if b.name == "CORE SURGE" then surging, left = true, b.t end end
  -- legs disappearing into the clouds
  col(C.dim, 0.9)
  lg.line(OX - 14, CLOUD_Y, OX - 34, CLOUD_Y + 26); lg.line(OX + 14, CLOUD_Y, OX + 34, CLOUD_Y + 26)
  -- mast
  local top, bot = DECK_Y + 6, CLOUD_Y + 6
  col(C.panel); lg.polygon("fill", OX - mastHalf(top), top, OX + mastHalf(top), top, OX + mastHalf(bot), bot, OX - mastHalf(bot), bot)
  col(C.dim); lg.polygon("line", OX - mastHalf(top), top, OX + mastHalf(top), top, OX + mastHalf(bot), bot, OX - mastHalf(bot), bot)
  col(C.faint); lg.line(OX, top + 4, OX, bot)
  -- surge collars climb the mast
  local fill = surging and 1 or G.surge
  local spin = (surging and not H.reduced) and love.timer.getTime() * 6 or 0
  for k = 1, COLLARS do
    local y = bot - 12 - (k - 1) * ((bot - top - 24) / (COLLARS - 1))
    local w = mastHalf(y) + 7
    local lit = clamp(fill * COLLARS - (k - 1), 0, 1)
    col(C.faint); lg.ellipse("line", OX, y, w, 3.5, 20)
    if lit > 0 then
      local a = surging and (0.6 + 0.4 * math.abs(math.sin(spin - k * 0.6))) or (0.4 + 0.6 * lit)
      lg.setLineWidth(2.5); col(C.orange, a); lg.ellipse("line", OX, y, w, 3.5, 20); lg.setLineWidth(1)
    end
  end
  -- deck
  col(C.panel); lg.ellipse("fill", OX, DECK_Y, 118, 9, 48)
  col(C.dim); lg.ellipse("line", OX, DECK_Y, 118, 9, 48)
  col(C.faint); lg.line(OX - 118, DECK_Y + 1, OX - 60, DECK_Y + 12); lg.line(OX + 118, DECK_Y + 1, OX + 60, DECK_Y + 12)
  lg.line(OX - 60, DECK_Y + 12, OX + 60, DECK_Y + 12)
  -- nav lights blink at the deck tips
  local blink = H.reduced and 1 or (math.floor(love.timer.getTime() * 1.3) % 2 == 0 and 1 or 0.15)
  col(C.red, blink); lg.circle("fill", OX - 118, DECK_Y, 2.5, 8); lg.circle("fill", OX + 118, DECK_Y, 2.5, 8)
  -- neck carrying the crown
  col(C.dim); lg.rectangle("line", OX - 6, G.OY + CROWN_R - 2, 12, DECK_Y - (G.OY + CROWN_R) + 2)
  return surging, left
end

----------------------------------------------------------------------
-- crown (the core), heat gauge and haze
----------------------------------------------------------------------
local function crown(hc, ht, down)
  local OX, OY = G.OX, G.OY
  local kick = G.coreKick
  local hot = G.overheatT > 0
  local t = love.timer.getTime()
  local r = CROWN_R * (1 + (H.reduced and 0 or 0.015 * math.sin(t * 2)) + kick * 0.5 - (down and 0.05 or 0))
  local glow = F.glowMesh()
  local energy = hot and 0.2 or (0.55 + math.min(0.45, kick * 4) + 0.15 * ht)
  -- heat haze: shimmer columns above the crown, stronger the hotter it runs
  if not H.reduced and G.heat > 0.15 then
    for k = -2, 2 do
      local pts = {}
      for y = 0, 30, 5 do
        pts[#pts + 1] = OX + k * 11 + math.sin(y * 0.25 + t * 5 + k) * 3 * G.heat
        pts[#pts + 1] = OY - r - 8 - y
      end
      col(hc, 0.18 * G.heat * (1 - math.abs(k) * 0.25)); lg.line(pts)
    end
  end
  lg.setBlendMode("add")
  col(hc, 0.12 * energy); love.graphics.draw(glow, OX, OY, 0, r * 2.6, r * 2.6)
  col(hc, 0.30 * energy); love.graphics.draw(glow, OX, OY, 0, r * 1.4, r * 1.4)
  lg.setBlendMode("alpha")
  col(C.bg, 0.9); lg.circle("fill", OX, OY, r, 64)
  col(hc, hot and 0.1 or 0.24); lg.circle("fill", OX, OY, r, 64)
  if not hot then
    lg.setLineWidth(1.5)
    for k = 1, 4 do
      local rr = r * (0.45 + k * 0.12)
      local s = (k % 2 == 0 and -1 or 1) * (0.4 + k * 0.18)
      local a = (H.reduced and 0 or t * s) + k * 1.4
      col(hc, 0.35 + 0.1 * k * energy); lg.arc("line", "open", OX, OY, rr, a, a + 1 + 0.2 * k, 16)
    end
    lg.setLineWidth(1)
  else
    for k = 1, 6 do
      local p = ((t * 0.8 + k / 6) % 1)
      col(C.white, 0.25 * (1 - p)); lg.circle("fill", OX + math.sin(k * 2.1 + t) * 12, OY - r * 0.3 - p * 50, 3 + p * 7, 12)
    end
  end
  col(hc, 0.7 + 0.3 * ht); lg.setLineWidth(1.5 + ht); lg.circle("line", OX, OY, r, 64); lg.setLineWidth(1)
  -- nucleus with the tower mark
  local nr = r * (0.42 + kick * 1.2)
  col(C.white, hot and 0.3 or (0.75 + 0.25 * energy)); lg.circle("fill", OX, OY, nr, 40)
  local s = nr * 0.62
  col(C.bg); lg.polygon("fill", OX - s, OY - s * 0.5, OX + s, OY - s * 0.5, OX, OY + s * 0.8)
end

local function gauge(hc)
  local OX, OY = G.OX, G.OY
  local heat, hot, sweet = G.heat, G.overheatT > 0, G.inSweetSpot()
  lg.setLineWidth(5)
  col(C.faint, 0.6); lg.arc("line", "open", OX, OY, GAUGE_R, A0, A1, 48)
  col(C.gold, sweet and 0.45 or 0.22); lg.arc("line", "open", OX, OY, GAUGE_R, ang(G.SWEET_LO), ang(G.SWEET_HI), 12)
  col(C.red, 0.3); lg.arc("line", "open", OX, OY, GAUGE_R, ang(G.SWEET_HI), A1, 6)
  lg.setLineWidth(2.5)
  if heat > 0.005 then
    local blink = (hot and not H.reduced) and (0.5 + 0.5 * math.sin(love.timer.getTime() * 14)) or 1
    col(hc, blink); lg.arc("line", "open", OX, OY, GAUGE_R, A0, ang(heat), 48)
  end
  if G.sweetT > 0 then
    lg.setLineWidth(2); col(C.gold, 0.9)
    local a = ang(G.SWEET_LO)
    lg.arc("line", "open", OX, OY, GAUGE_R - 7, a, a + (ang(G.SWEET_HI) - a) * clamp(G.sweetT / G.RHYTHM_TIME, 0, 1), 16)
  end
  lg.setLineWidth(1)
  local a = ang(heat)
  col(C.white); lg.setLineWidth(2)
  lg.line(OX + math.cos(a) * (GAUGE_R - 6), OY + math.sin(a) * (GAUGE_R - 6), OX + math.cos(a) * (GAUGE_R + 7), OY + math.sin(a) * (GAUGE_R + 7))
  lg.setLineWidth(1)
end

----------------------------------------------------------------------
-- callouts: engineering annotations with leader lines
----------------------------------------------------------------------
local function callout(ax, ay, lx, ly, side, label, value, vc, state, sc)
  local Fo = H.fonts
  col(C.dim, 0.7)
  lg.line(ax, ay, lx, ly); lg.line(lx, ly, lx + side * 30, ly)
  lg.circle("fill", ax, ay, 2, 8)
  local tx = side < 0 and (lx - 30 - 150) or (lx + 30)
  local align = side < 0 and "right" or "left"
  lg.setFont(Fo.xs); col(C.dim); lg.printf(label, tx, ly - 26, 150, align)
  lg.setFont(Fo.d2); col(vc); lg.printf(value, tx, ly - 14, 150, align)
  if state then lg.setFont(Fo.xs); col(sc or C.dim); lg.printf(state, tx, ly + 14, 150, align) end
  return tx
end

local function callouts(hc, surging, left)
  local OX, OY = G.OX, G.OY
  local heat, hot, sweet = G.heat, G.overheatT > 0, G.inSweetSpot()
  local state, sc = "IDEAL " .. math.floor(G.SWEET_LO * 100) .. "-" .. math.floor(G.SWEET_HI * 100) .. "%", C.dim
  if hot then state, sc = string.format("VENTING %.1fS", G.overheatT), C.red
  elseif sweet then state, sc = "SWEET SPOT x" .. G.SWEET_MULT, C.gold
  elseif heat > G.SWEET_HI then state, sc = "TOO HOT", C.red end
  local ha = math.pi * 1.08
  local tx = callout(OX + math.cos(ha) * (GAUGE_R + 8), OY + math.sin(ha) * (GAUGE_R + 8), OX - 150, OY - 30, -1,
    "CORE HEAT", math.floor(heat * 100 + 0.5) .. "%", hc, state, sc)
  if H.mouseIn(tx, OY - 60, 160, 80) then
    H.setTip("CORE HEAT", "Every tap heats the crown; it cools on its own. Keep it in the gold band of the gauge (" ..
      math.floor(G.SWEET_LO * 100) .. "-" .. math.floor(G.SWEET_HI * 100) .. "%) for x" .. G.SWEET_MULT ..
      " tap power and double surge fill. " .. math.floor(G.RHYTHM_TIME) .. "s in a row ignites a Core Surge. 100% = overheat: taps lock for " ..
      G.OVERHEAT_TIME .. "s.")
  end
  local my = (DECK_Y + CLOUD_Y) / 2
  local sx = callout(G.OX + mastHalf(my) + 8, my, OX + 140, my - 30, 1,
    "CORE SURGE", surging and "x3" or (math.floor(G.surge * 100) .. "%"), surging and C.orange or C.white,
    surging and (math.ceil(left) .. "S LEFT") or "TAPS CLIMB THE MAST", surging and C.orange or C.dim)
  if H.mouseIn(sx, my - 60, 160, 80) then
    H.setTip("CORE SURGE", "Every tap lights the collars up the mast (double inside the heat sweet spot). When they reach the deck the crown ignites: all output x3 for 15s.")
  end
  if G.combo > 1 then
    lg.setFont(H.fonts.xs); col(C.red)
    lg.printf(string.format("CHAIN x%.2f", 1 + math.min(G.combo, 200) * 0.005), OX - 60, OY - GAUGE_R - 22, 120, "center")
  end
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
  -- a tap rolls a ripple over the clouds
  if G.coreKick > 0.08 and (R.lastKick or 0) <= 0.08 then ripples[#ripples + 1] = {t = 0, c = hc} end
  R.lastKick = G.coreKick
  local share, total = shares()
  beams(share, total, dt)
  local surging, left = tower(hc)
  clouds(dt)
  gauge(hc)
  -- target lock on the crown
  local first = S.clicks < 5
  local lockT = math.max(ht, first and (0.55 + 0.25 * math.sin(G.time * 3)) or 0)
  if lockT > 0.01 then
    local rr = R.hitR() + 4 + (1 - lockT) * 10
    lg.setLineWidth(2); col(down and C.white or C.line, lockT)
    for i = 0, 3 do
      local a = i * TAU / 4 + TAU / 8
      lg.arc("line", "open", OX, OY, rr, a - 0.18, a + 0.18, 8)
    end
    lg.setLineWidth(1)
  end
  crown(hc, ht, down)
  callouts(hc, surging, left)
  FX.drawWaves()
  if first then
    local cy = CLOUD_Y + 40
    local txt = "TAP THE CROWN TO HARVEST"
    local tw = Fo.xs:getWidth(txt) + 20
    col(C.bg, 0.85); lg.rectangle("fill", OX - tw / 2, cy, tw, 17)
    col(C.orange); lg.rectangle("fill", OX - tw / 2, cy, 2, 17)
    lg.setFont(Fo.xs); col(C.orange); lg.printf(txt, OX - tw / 2, cy + 3, tw, "center")
  end
end

function R.hitR() return 62 end
function R.hit(x, y) return (x - G.OX) ^ 2 + (y - G.OY) ^ 2 < R.hitR() ^ 2 end

return R
