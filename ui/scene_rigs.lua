-- RIGS: a flow diagram. Hydro is extracted into each rig's tank (intake pipes run while it fills), and
-- collecting drains the tank down the manifold into your reserve (a pulse travels the pipe). The reserve
-- says what the water is for: drone fabrications.
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local I = require "ui.icons"
local lg = V.lg
local C, col, fmt, clamp = H.C, H.col, H.fmt, H.clamp
local Sc = {}

-- everything sits on the 40px background grid: tank edges, tops, bottoms, the manifold and the reserve
local TANK_W, TANK_TOP, TANK_BOT = 160, 160, 440
local MANIFOLD_Y = 600
local RES_X = 920
local prevTank, pulse = {}, {}

local function cxOf(i) return 160 + (i - 1) * 280 end -- tank left edges at 80, 360, 640

-- liquid with a moving surface
local function liquid(x, y0, w, y1, f, c)
  local top = y1 - (y1 - y0) * f
  if f <= 0.002 then return top end
  local t = H.reduced and 0 or love.timer.getTime()
  local pts = {x, y1, x + w, y1}
  for k = 16, 0, -1 do
    local px = x + w * k / 16
    pts[#pts + 1] = px
    pts[#pts + 1] = math.max(y0, top + math.sin(t * 2.2 + k * 0.7) * (f < 0.999 and 2 or 0.6))
  end
  col(c, 0.22); lg.polygon("fill", pts)
  col(c, 0.9); lg.setLineWidth(1.5)
  local surf = {}
  for k = 5, #pts, 1 do surf[#surf + 1] = pts[k] end
  lg.line(surf); lg.setLineWidth(1)
  return top
end

-- dashes travelling along a polyline segment (flow direction a -> b)
local function flowLine(ax, ay, bx, by, c, speed, a)
  col(C.faint); lg.line(ax, ay, bx, by)
  if speed <= 0 then return end
  local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
  local off = H.reduced and 0 or (love.timer.getTime() * speed) % 16
  col(c, a or 0.8)
  for d = off, len - 4, 16 do
    local f0, f1 = d / len, math.min(1, (d + 6) / len)
    lg.line(ax + (bx - ax) * f0, ay + (by - ay) * f0, ax + (bx - ax) * f1, ay + (by - ay) * f1)
  end
end

local function tank(i)
  local S = G.S
  local Fo = H.fonts
  local r = S.rigs[i]
  local cx = cxOf(i)
  local x = cx - TANK_W / 2
  if not r.on then
    -- offline: a ghost of the tank and the one action that matters
    col(C.red, 0.5)
    for d = TANK_TOP, TANK_BOT, 10 do lg.line(x, d, x, d + 5); lg.line(x + TANK_W, d, x + TANK_W, d + 5) end
    for d = x, x + TANK_W, 10 do lg.line(d, TANK_BOT, d + 5, TANK_BOT) end
    lg.setFont(Fo.dxl); col(C.red); lg.printf("R" .. i, x, TANK_TOP + 60, TANK_W, "center")
    H.label("OFFLINE // DAMAGED", x + TANK_W / 2 - 52, TANK_TOP + 100, C.red)
    local cost = D.RIG_UNLOCK[i]
    H.button(x, TANK_TOP + 120, TANK_W, 40, "RESTORE  //  " .. fmt(cost), S.stardust >= cost, function() G.unlockRig(i) end, C.red, Fo.s, nil, true)
    H.label("Opens a new hydro stream.", x + 14, TANK_TOP + 168, C.dim)
    return
  end
  local cap, rate = G.rigCap(i), G.rigRate(i)
  local f = clamp(r.tank / cap, 0, 1)
  local full = f >= 1
  local rc = full and C.orange or C.line
  -- detect a collect (tank dropped) and send a pulse down the pipe
  if prevTank[i] and r.tank < prevTank[i] - 0.5 then pulse[i] = love.timer.getTime() end
  prevTank[i] = r.tank
  -- intake from above: runs while the tank fills
  flowLine(cx, 96, cx, TANK_TOP, C.line, full and 0 or 18 + rate * 20, 0.6)
  -- the vessel
  col(C.panel, 0.9); lg.rectangle("fill", x, TANK_TOP, TANK_W, TANK_BOT - TANK_TOP)
  local top = liquid(x + 1, TANK_TOP + 1, TANK_W - 2, TANK_BOT - 1, f, rc)
  col(full and C.orange or C.faint, full and 0.9 or 1); lg.rectangle("line", x + 0.5, TANK_TOP + 0.5, TANK_W - 1, TANK_BOT - TANK_TOP - 1)
  -- level scale
  for k = 0, 10 do
    local ty = TANK_BOT - (TANK_BOT - TANK_TOP) * k / 10
    col(C.dim, k % 5 == 0 and 0.8 or 0.4); lg.line(x + TANK_W, ty, x + TANK_W + (k % 5 == 0 and 8 or 4), ty)
  end
  H.label("PEAK", x + TANK_W + 10, TANK_TOP - 5, full and C.orange or C.dim)
  -- readout inside the tank
  lg.setFont(Fo.dxl); col(full and C.orange or C.white)
  lg.printf(math.floor(f * 100) .. "%", x, math.min(TANK_BOT - 70, math.max(TANK_TOP + 14, top - 44)), TANK_W, "center")
  lg.setFont(Fo.xs); col(full and C.orange or C.dim)
  lg.printf(fmt(math.floor(r.tank)) .. " / " .. fmt(math.floor(cap)) .. " H2O", x, TANK_BOT - 20, TANK_W, "center")
  if full then
    local p = H.reduced and 1 or (0.6 + 0.4 * math.sin(G.time * 4))
    lg.setFont(Fo.s); col(C.orange, p); lg.printf("AT PEAK  //  +25% ON COLLECT", x - 20, TANK_BOT + 8, TANK_W + 40, "center")
  else
    lg.setFont(Fo.xs); col(C.dim); lg.printf("FULL IN " .. H.fmtTime((cap - r.tank) / rate), x, TANK_BOT + 10, TANK_W, "center")
  end
  -- identity and controls
  local by = TANK_BOT + 34
  lg.setFont(Fo.d3); col(C.white); lg.print("R" .. i, x, by)
  H.label("LV " .. r.lvl .. "  //  " .. string.format("%.1f", rate * 60) .. " H2O / MIN", x + 30, by + 4, C.dim)
  H.button(x, by + 26, TANK_W, 34, full and "COLLECT +25%" or "COLLECT", r.tank >= 1, function() G.collectRig(i) end, rc, Fo.s, nil, full)
  local uc = G.rigUpCost(i)
  H.button(x, by + 66, TANK_W, 26, "UPGRADE LV " .. (r.lvl + 1) .. "  //  " .. fmt(uc), S.stardust >= uc, function() G.upgradeRig(i) end, C.line, Fo.xs, nil, false, true)
  if H.mouseIn(x, by + 66, TANK_W, 26) then H.setTip("UPGRADE RIG R" .. i, "Higher level: bigger tank and faster flow. Hold to keep upgrading.") end
  -- outlet to the manifold (drawn behind the controls column, along its right edge)
  local ox = x + TANK_W + 40
  local p = pulse[i] and (love.timer.getTime() - pulse[i]) / 0.7 or 2
  flowLine(ox, TANK_BOT - 10, ox, MANIFOLD_Y, rc, 0)
  col(C.faint); lg.line(x + TANK_W, TANK_BOT - 10, ox, TANK_BOT - 10)
  if p < 1 then
    -- the collected water racing down to the reserve
    local total = (MANIFOLD_Y - TANK_BOT) + (RES_X - ox)
    local d = p * total
    local px, py
    if d < MANIFOLD_Y - TANK_BOT then px, py = ox, TANK_BOT + d else px, py = ox + d - (MANIFOLD_Y - TANK_BOT), MANIFOLD_Y end
    col(C.white); lg.rectangle("fill", px - 3, py - 3, 6, 6)
    col(rc, 0.4); lg.circle("fill", px, py, 9, 16)
  end
  return ox
end

local function reserve()
  local S = G.S
  local Fo = H.fonts
  local x, y, w, h = RES_X, 120, 1240 - RES_X, 480
  H.card(x, y, w, h, "RESERVE", C.line, "HYDRO")
  lg.setFont(Fo.huge); col(C.white); lg.print(fmt(math.floor(S.hydro)), x + 18, y + 34)
  H.label("H2O IN STORAGE", x + 20, y + 94, C.dim)
  local flow = 0
  for i, r in ipairs(S.rigs) do if r.on then flow = flow + G.rigRate(i) end end
  local surge = G.eventActive("HYDRO")
  H.label(string.format("%.1f", flow * 60) .. " H2O / MIN EXTRACTED" .. (surge and "  //  SURGE x5" or ""), x + 20, y + 112, surge and C.orange or C.line)
  col(C.faint); lg.line(x + 16, y + 136, x + w - 16, y + 136)
  -- what it is for
  local fab = G.fabCost()
  local n = fab > 0 and math.floor(S.hydro / fab) or 0
  H.label("BUYS", x + 20, y + 148, C.dim)
  lg.setFont(Fo.d2); col(n > 0 and C.orange or C.dim); lg.print(fmt(n), x + 20, y + 162)
  lg.setFont(Fo.s); col(C.white); lg.print("DRONE FABRICATION" .. (n == 1 and "" or "S"), x + 30 + Fo.d2:getWidth(fmt(n)), y + 168)
  H.label("at " .. fmt(fab) .. " H2O each, in the HANGAR", x + 20, y + 194, C.dim)
  if G.unlocked("hangar") then
    H.button(x + 20, y + 214, w - 40, 30, "GO TO HANGAR  >", true, function() G.tab = "hangar"; FX.play("tap", 1.6, 0.4) end, C.line, Fo.xs)
  end
  col(C.faint); lg.line(x + 16, y + 260, x + w - 16, y + 260)
  -- automation
  H.label("AUTOMATION", x + 20, y + 272, C.dim)
  H.button(x + 20, y + 290, w - 40, 30, "AUTO-UPGRADE: " .. (S.autoRigUp and "ON" or "OFF"), true,
    function() S.autoRigUp = not S.autoRigUp; FX.play("tick", 1.2) end, S.autoRigUp and C.orange or C.dim, Fo.xs)
  if H.mouseIn(x + 20, y + 290, w - 40, 30) then H.setTip("RIG AUTO-UPGRADE", "Restores offline rigs and levels the cheapest rig automatically. Never spends more than half of your energy at once.") end
  local ok, need = G.hasArchive("autoRigs")
  H.button(x + 20, y + 326, w - 40, 30, ok and ("AUTO-COLLECT: " .. (S.autoRigs and "ON" or "OFF")) or ("AUTO-COLLECT  //  " .. need .. " LOGS"),
    ok, function() S.autoRigs = not S.autoRigs end, S.autoRigs and C.orange or C.dim, Fo.xs)
  local any = false
  for i, r in ipairs(S.rigs) do if r.on and r.tank >= 1 then any = true end end
  H.button(x + 20, y + h - 60, w - 40, 40, "COLLECT ALL RIGS", any, function() for i = 1, #S.rigs do G.collectRig(i) end end,
    C.orange, Fo.m, nil, any)
end

function Sc.draw()
  local S = G.S
  local Fo = H.fonts
  lg.setFont(Fo.d2); col(C.white); lg.print("HYDRO EXTRACTION", 24, 58)
  H.label("Rigs fill their tanks on their own. Collect at peak for +25%. The water fabricates drones.", 260, 70, C.dim)
  -- manifold into the reserve
  local lastOut = 0
  for i = 1, #S.rigs do
    local ox = tank(i)
    if ox then lastOut = math.max(lastOut, ox) end
  end
  local firstOut = cxOf(1) + TANK_W / 2 + 40
  col(C.faint); lg.rectangle("fill", math.min(firstOut, lastOut > 0 and lastOut or RES_X), MANIFOLD_Y, RES_X - math.min(firstOut, RES_X), 1)
  col(C.line, 0.6); lg.polygon("fill", RES_X - 8, MANIFOLD_Y - 4, RES_X, MANIFOLD_Y, RES_X - 8, MANIFOLD_Y + 4)
  reserve()
end

return Sc
