-- RIGS: three large hydro extraction panels.
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local I = require "ui.icons"
local lg = V.lg
local C, col, fmt, clamp = H.C, H.col, H.fmt, H.clamp
local TAU = math.pi * 2
local Sc = {}

local function rig(i, x, y, w, h)
  local S = G.S
  local Fo = H.fonts
  local r = S.rigs[i]
  col(C.panel, 0.92); lg.rectangle("fill", x, y, w, h)
  if not r.on then
    H.hatch(x, y, w, h, C.red, 0.12, 9)
    H.brackets(x, y, w, h, 12, C.red, 0.7)
    lg.setFont(Fo.xl); col(C.red); lg.print("R" .. i, x + 20, y + 16)
    lg.setFont(Fo.m); col(C.red); lg.print("RIG OFFLINE // DAMAGED", x + 20, y + 60)
    H.label("Restore it to open a new hydro stream.", x + 20, y + 86, C.dim)
    local cost = D.RIG_UNLOCK[i]
    H.button(x + 40, y + h / 2 - 30, w - 80, 60, "RESTORE // " .. fmt(cost) .. " ENERGY", S.stardust >= cost,
      function() G.unlockRig(i) end, C.red, Fo.m, nil, true)
    return
  end
  local cap, rate = G.rigCap(i), G.rigRate(i)
  local f = clamp(r.tank / cap, 0, 1)
  local full = f >= 1
  local rc = full and C.orange or C.line
  H.brackets(x, y, w, h, 12, rc)
  if full then col(C.orange, 0.05 + 0.04 * math.sin(G.time * 5)); lg.rectangle("fill", x, y, w, h) end
  -- header
  lg.setFont(Fo.xl); col(C.white); lg.print("R" .. i, x + 20, y + 12)
  H.label("LEVEL", x + 74, y + 14, C.dim)
  lg.setFont(Fo.l); col(C.line); lg.print(tostring(r.lvl), x + 74, y + 26)
  lg.setFont(Fo.xl); col(full and C.orange or C.white); lg.printf(fmt(math.floor(r.tank)), x, y + 12, w - 20, "right")
  H.label("/ " .. fmt(math.floor(cap)) .. " H2O", x + w - 120, y + 46, C.dim)
  col(C.line, 0.3); lg.line(x + 16, y + 66, x + w - 16, y + 66)
  -- glyph + gauges
  local cx, ty = x + w / 2, y + 80
  local poly = {cx - 70, ty, cx + 70, ty, cx + 36, ty + 52, cx - 36, ty + 52}
  col(C.teal, 0.35); lg.polygon("fill", poly)
  if full and math.floor(G.time * 3) % 2 == 0 then H.hatch(cx - 70, ty, 140, 52, C.red, 0.55, 5) end
  col(C.line, 0.9); lg.polygon("line", poly)
  col(C.red); lg.rectangle("fill", cx - 7, ty + 5, 14, 9)
  for s = -1, 1, 2 do
    local gx, gy = cx + s * 100, ty + 26
    col(C.line, 0.4); lg.circle("line", gx, gy, 16, 24)
    col(rc); lg.setLineWidth(3)
    lg.arc("line", "open", gx, gy, 16, -math.pi / 2, -math.pi / 2 + f * TAU, 24)
    lg.setLineWidth(1)
  end
  -- stats
  local sy = y + 150
  local rows = {
    {"FLOW", string.format("%.2f H2O / MIN", rate * 60)},
    {"FILL ETA", full and "FULL // COLLECT NOW" or H.fmtTime((cap - r.tank) / rate)},
    {"PRESSURE", string.format("%d%%", f * 100)},
    {"TEMP", string.format("%.1f C", 14 + f * 62 + math.sin(G.time * 2 + i) * 0.4)},
  }
  for k, row in ipairs(rows) do
    H.label(row[1], x + 20, sy + (k - 1) * 18, C.dim)
    lg.setFont(Fo.xs); col((k == 2 and full) and C.orange or C.white)
    lg.printf(row[2], x, sy + (k - 1) * 18, w - 20, "right")
  end
  -- tank: horizontal segments
  local mx, my, mw, mh = x + 20, sy + 82, w - 40, 150
  local segs = 16
  local sh = (mh - (segs - 1) * 3) / segs
  for k = 0, segs - 1 do
    local yy = my + mh - (k + 1) * sh - k * 3
    local lit = clamp(f * segs - k, 0, 1)
    col(C.faint, 0.5); lg.rectangle("fill", mx, yy, mw, sh)
    if lit > 0 then col(k >= segs - 2 and C.white or rc, 0.85); lg.rectangle("fill", mx, yy, mw * lit, sh) end
  end
  -- CLCT + buttons
  local by = my + mh + 12
  H.brackets(x + 20, by, w - 40, 30, 6, rc)
  H.label("CLCT", x + 32, by + 9, C.dim)
  lg.setFont(Fo.m); col(rc); lg.printf(string.format("%d%%", f * 100), x + 20, by + 6, w - 54, "right")
  H.button(x + 20, by + 40, w - 40, 44, full and "COLLECT // +25% PEAK BONUS" or "COLLECT", r.tank >= 1,
    function() G.collectRig(i) end, full and C.orange or C.line, Fo.m, nil, full)
  local uc = G.rigUpCost(i)
  H.button(x + 20, by + 90, w - 40, 32, "UPGRADE TO LV " .. (r.lvl + 1) .. " // " .. fmt(uc) .. " ENERGY", S.stardust >= uc,
    function() G.upgradeRig(i) end, C.line, Fo.xs, nil, false, true)
end

function Sc.draw()
  local S = G.S
  local Fo = H.fonts
  lg.setFont(Fo.l); col(C.white); lg.print("HYDRO EXTRACTION", 24, 62)
  local flow, any = 0, false
  for i, r in ipairs(S.rigs) do
    if r.on then
      flow = flow + G.rigRate(i)
      if r.tank >= 1 then any = true end
    end
  end
  H.label(fmt(math.floor(S.hydro)) .. " H2O IN RESERVE  //  " .. string.format("%.1f", flow * 60) .. " H2O / MIN" ..
    (G.eventActive("HYDRO") and "  //  HYDRO SURGE x5" or ""), 260, 70, G.eventActive("HYDRO") and C.orange or C.dim)
  H.button(1256 - 500, 64, 160, 30, "AUTO-UPGRADE: " .. (S.autoRigUp and "ON" or "OFF"), true,
    function() S.autoRigUp = not S.autoRigUp; FX.play("tick", 1.2) end, S.autoRigUp and C.orange or C.dim, Fo.xs)
  if H.mouseIn(1256 - 500, 64, 160, 30) then H.setTip("RIG AUTO-UPGRADE", "Restores offline rigs and levels the cheapest rig automatically. Never spends more than half of your energy at once.") end
  local ok, need = G.hasArchive("autoRigs")
  H.button(1256 - 330, 64, 160, 30, ok and ("AUTO-COLLECT: " .. (S.autoRigs and "ON" or "OFF")) or ("AUTO // " .. need .. " LOGS"),
    ok, function() S.autoRigs = not S.autoRigs end, S.autoRigs and C.orange or C.dim, Fo.xs)
  H.button(1256 - 160, 64, 160, 30, "COLLECT ALL", any, function() for i = 1, 3 do G.collectRig(i) end end, C.orange, Fo.xs, nil, any)
  local w = (1232 - 2 * 16) / 3
  for i = 1, 3 do rig(i, 24 + (i - 1) * (w + 16), 106, w, 526) end
end

return Sc
