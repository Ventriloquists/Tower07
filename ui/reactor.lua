-- The reactor core (CORE scene centerpiece).
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local lg = V.lg
local C, col, clamp = H.C, H.col, H.clamp
local TAU = math.pi * 2
local R = {}

R.K = 0.76 -- ring scale

function R.draw()
  local S = G.S
  local OX, OY, CR, k = G.OX, G.OY, G.CORE_R, R.K
  local hov = H.mouseIn(OX - CR * 1.5, OY - CR * 1.5, CR * 3, CR * 3) and not G.modal
  local kick = G.coreKick
  local pr = CR * (1 + 0.02 * math.sin(G.time * 2) - kick * 0.6)
  local pulse = 0.5 + 0.5 * math.sin(G.time * 2)
  local surging = G.hasBuff("CORE SURGE")

  col(C.line, 0.1)
  lg.line(OX - 240 * k, OY, OX + 240 * k, OY)
  lg.line(OX, OY - 230 * k, OX, OY + 230 * k)

  H.tickRing(OX, OY, 214 * k, 120, 5 * k, G.time * 0.03, C.line, 0.35, 10)
  col(C.line, 0.18)
  lg.circle("line", OX, OY, 212 * k, 128)

  -- unit ring: one segment per unit type
  local n = #D.GENS
  for i, g in ipairs(D.GENS) do
    local a0 = -math.pi / 2 + (i - 1) / n * TAU + 0.02
    local a1 = a0 + TAU / n - 0.04
    local c = S.gens[i]
    lg.setLineWidth(5)
    if c > 0 then col(C.line, clamp(0.25 + math.log10(c + 1) * 0.3, 0.25, 1)) else col(C.faint, 0.35) end
    lg.arc("line", "open", OX, OY, 192 * k, a0, a1, 16)
    lg.setLineWidth(1)
    if c > 0 then
      local am = (a0 + a1) / 2
      lg.setFont(H.fonts.xs); col(C.dim, 0.8)
      lg.printf(g.code, OX + math.cos(am) * 175 * k - 20, OY + math.sin(am) * 175 * k - 6, 40, "center")
    end
  end

  for i = 1, 6 do
    local c = S.gens[i]
    if c > 0 then
      local rad = (128 + i * 6) * k
      local cnt = math.min(c, 18)
      local spd = (i % 2 == 0 and -1 or 1) * 0.35 / (1 + i * 0.2)
      col(C.white, 0.7)
      for j = 1, cnt do
        local a = G.time * spd + j * TAU / cnt + i
        lg.rectangle("fill", OX + math.cos(a) * rad - 1, OY + math.sin(a) * rad - 1, 2, 2)
      end
    end
  end

  col(C.line, 0.45)
  for i = 0, 35 do
    local a = -G.time * 0.25 + i / 36 * TAU
    lg.arc("line", "open", OX, OY, 122 * k, a, a + TAU / 36 * 0.5, 4)
  end

  if G.combo > 1 then
    lg.setLineWidth(3); col(C.red, 0.9)
    lg.arc("line", "open", OX, OY, 113 * k, -math.pi / 2, -math.pi / 2 + math.min(G.combo, 200) / 200 * TAU, 64)
    lg.setLineWidth(1)
  end
  local sf = surging and 1 or G.surge
  if sf > 0 then
    lg.setLineWidth(surging and 5 or 3)
    col(C.orange, surging and (0.6 + 0.4 * math.sin(G.time * 12)) or 0.85)
    lg.arc("line", "open", OX, OY, 104 * k, math.pi / 2, math.pi / 2 + sf * TAU, 64)
    lg.setLineWidth(1)
  end

  -- core
  if hov then
    lg.setBlendMode("add")
    col(C.line, 0.06); lg.circle("fill", OX, OY, pr * 1.25, 48)
    lg.setBlendMode("alpha")
  end
  col(surging and C.orange or C.teal, 0.25 + kick * 2 + (hov and 0.1 or 0))
  lg.circle("fill", OX, OY, pr, 64)
  for r = 0.3, 1.0, 0.175 do col(C.line, 0.18); lg.circle("line", OX, OY, pr * r, 64) end
  col(C.line, hov and 1 or 0.8)
  lg.setLineWidth(1.5); lg.circle("line", OX, OY, pr, 64); lg.setLineWidth(1)
  col(C.line, 0.12)
  for i = 0, 11 do
    local a = i / 12 * TAU + G.time * 0.05
    lg.line(OX + math.cos(a) * pr * 0.3, OY + math.sin(a) * pr * 0.3, OX + math.cos(a) * pr, OY + math.sin(a) * pr)
  end
  local sw = G.time * (surging and 5 or 1.4)
  for j = 0, 14 do
    col(surging and C.orange or C.line, 0.18 * (1 - j / 14))
    local a = sw - j * 0.04
    lg.line(OX, OY, OX + math.cos(a) * pr, OY + math.sin(a) * pr)
  end
  local hx = {}
  for i = 0, 5 do
    local a = i / 6 * TAU + math.pi / 6 - G.time * 0.2
    hx[#hx + 1] = OX + math.cos(a) * pr * 0.62
    hx[#hx + 1] = OY + math.sin(a) * pr * 0.62
  end
  col(C.line, 0.55); lg.polygon("line", hx)
  local s = pr * 0.38 * (1 + kick)
  local tri = {OX - s, OY - s * 0.55, OX + s, OY - s * 0.55, OX, OY + s * 0.85}
  col(C.white, 0.08 + kick * 3 + pulse * 0.05); lg.polygon("fill", tri)
  col(C.white, 0.95); lg.setLineWidth(2.5); lg.polygon("line", tri); lg.setLineWidth(1)
  local s2 = s * 0.5
  col(C.white, 0.7)
  lg.polygon("line", OX - s2, OY - s2 * 0.45, OX + s2, OY - s2 * 0.45, OX, OY + s2 * 0.75)

  FX.drawWaves()

  if S.clicks < 5 then
    lg.setFont(H.fonts.s)
    col(C.orange, 0.6 + pulse * 0.4)
    lg.printf("<< CLICK THE CORE TO HARVEST >>", OX - 200, OY + 120, 400, "center")
  end
end

function R.hit(x, y) return (x - G.OX) ^ 2 + (y - G.OY) ^ 2 < (G.CORE_R * 1.55) ^ 2 end

return R
