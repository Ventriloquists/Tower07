-- REBOOT: prestige panel (left) + protocol skill tree (right): drag to pan, wheel to zoom, click to inspect/buy.
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local I = require "ui.icons"
local T = require "game.tree"
local Set = require "game.settings"
local lg = V.lg
local C, col, fmt, clamp = H.C, H.col, H.fmt, H.clamp
local TAU = math.pi * 2
local Sc = {}

local VX, VY, VW, VH = 340, 92, 916, 538      -- tree viewport
local BASE_U = 90                            -- pixels per tree unit at zoom 1
local FIT_Z = 0.17
G.treeView = G.treeView or {x = 0, y = 0, z = 0.9}
G.treeSel = nil
local drag, panelRect, screenPos = nil, nil, {}

-- a fixed starfield behind the tree (parallax while panning)
local stars = {}
do
  local rng = love.math.newRandomGenerator(7)
  for k = 1, 240 do
    stars[k] = {x = rng:random() * 3000, y = rng:random() * 3000, s = 0.6 + rng:random() * 1.6, p = rng:random() * TAU, d = 0.2 + rng:random() * 0.4}
  end
end

----------------------------------------------------------------------
local function prestige()
  local S = G.S
  local Fo = H.fonts
  local x, y, w, h = 24, 92, 300, 538
  local g = G.dmGain()
  local can = g >= 1
  H.card(x, y, w, h, "REBOOT PROTOCOL", C.red)
  H.label("CORE DATA IN BANK", x + 14, y + 40, C.dim)
  lg.setFont(Fo.dxl); col(C.white); lg.print(fmt(S.dm), x + 14, y + 52)
  H.label("LIFETIME " .. fmt(S.dmTotal) .. "  //  OUTPUT x" .. fmt(G.cdBonus()), x + 14, y + 94, C.dim)
  -- the big preview
  local py = y + 116
  col(C.red, can and 0.12 or 0.04); lg.rectangle("fill", x + 14, py, w - 28, 112)
  H.brackets(x + 14, py, w - 28, 112, 8, can and C.red or C.faint)
  H.label("REBOOT NOW FOR", x + 26, py + 8, C.dim)
  lg.setFont(Fo.huge); col(can and C.orange or C.faint); lg.printf("+" .. fmt(g), x, py + 20, w, "center")
  H.label("CORE DATA" .. (G.dmMult() > 1 and string.format("  (x%.1f DATA COMPRESSION)", G.dmMult()) or ""), x + 26, py + 76, can and C.orange or C.faint)
  local cdNow = G.cdBonus(); local keep = S.dmTotal; S.dmTotal = S.dmTotal + g; local cdNext = G.cdBonus(); S.dmTotal = keep
  H.label("CORE DATA BONUS x" .. fmt(cdNow) .. "  ->  x" .. fmt(cdNext), x + 26, py + 92, can and C.white or C.dim)
  local nextAt = (((G.dmPotential() + 1) / G.dmMult()) ^ (1 / G.DM_EXP)) * G.DM_BASE
  local capped = G.dmPotential() - S.dmTotal > g
  local charge = G.runCharge()
  if capped and charge < 1 then
    -- the cap is still charging: show how long until this run is worth its full reboot
    H.label("RUN CHARGE " .. math.floor(charge * 100) .. "%  //  FULL VALUE IN " .. H.clock(G.RUN_CHARGE - S.runTime):sub(4), x + 14, py + 124, C.orange)
    H.bar(x + 14, py + 140, w - 28, 4, charge, C.orange)
  else
    H.label(capped and "CAPPED  //  MAX x3 CORE DATA PER REBOOT" or ("NEXT CORE DATA AT " .. fmt(nextAt) .. " ENERGY"), x + 14, py + 124, capped and C.orange or C.dim)
    H.bar(x + 14, py + 140, w - 28, 4, capped and 1 or S.totalEarned / nextAt, capped and C.orange or C.red)
  end
  -- resets / keeps
  local ly = py + 158
  H.label("RESETS", x + 14, ly, C.red)
  H.label("KEEPS", x + 156, ly, C.line)
  local resets = {"Energy", "Units", "Tech upgrades", "Sector map"}
  local keeps = {"Rank + perks", "Drones + modules", "Rigs, logs, pass", "Zone, Core Data"}
  for k = 1, 4 do
    H.label("- " .. resets[k], x + 14, ly + 2 + k * 16, C.dim)
    H.label("+ " .. keeps[k], x + 156, ly + 2 + k * 16, C.dim)
  end
  -- tree summary (endless OVERDRIVE ranks are counted separately)
  local owned, ranks, maxr, od = 0, 0, 0, 0
  for _, n in ipairs(T.NODES) do
    local r = G.tr(n.id)
    if r > 0 then owned = owned + 1 end
    if n.endless then od = od + r else ranks, maxr = ranks + r, maxr + n.max end
  end
  local ty = ly + 92
  H.label("PROTOCOLS " .. owned .. " / " .. #T.NODES .. "   //   RANKS " .. ranks .. " / " .. maxr, x + 14, ty, C.white)
  H.segbar(x + 14, ty + 16, w - 28, 5, ranks / maxr, 30, C.orange)
  H.label("OVERDRIVE RANKS " .. od, x + 14, ty + 28, od > 0 and C.holo or C.dim)
  local rd = G.treeReady()
  H.button(x + 14, y + h - 122, w - 28, 38, rd > 0 and ("SPEND ALL CORE DATA // " .. rd .. " READY") or "SPEND ALL CORE DATA", rd > 0,
    G.treeSpendAll, C.orange, Fo.s, nil, rd > 0)
  if H.mouseIn(x + 14, y + h - 122, w - 28, 38) then
    H.setTip("SPEND ALL CORE DATA", "Keeps installing the cheapest affordable rank until the bank runs dry. Spreads Core Data across the whole tree, including the endless OVERDRIVE nodes.")
  end
  local label = can and (G.novaConfirm > 0 and "CONFIRM REBOOT?" or "INITIATE REBOOT") or "NOT ENOUGH ENERGY YET"
  H.button(x + 14, y + h - 76, w - 28, 60, label, can, function()
    if G.novaConfirm > 0 or not Set.v.confirmReboot then G.novaConfirm = 0; G.doReboot()
    else G.novaConfirm = 3; FX.play("signal", 0.6, 0.6) end
  end, C.red, Fo.l, nil, can)
end

----------------------------------------------------------------------
-- tree
----------------------------------------------------------------------
local function unit() return BASE_U * G.treeView.z end
local function center() return VX + VW / 2 + G.treeView.x, VY + VH / 2 + G.treeView.y end
local function toScreen(tx, ty)
  local cx, cy = center()
  return cx + tx * unit(), cy + ty * unit()
end
local function nodeR(n)
  local s = clamp(G.treeView.z, 0.5, 1.4)
  return (n.endless and 22 or (n.big and 19 or (n.max == 1 and 14 or 11))) * s
end
local function nodeState(n)
  local r = G.tr(n.id)
  local avail = G.treeAvail(n)
  return r, avail, r >= n.max, G.treeCan(n)
end
local BICON = {}
for _, b in ipairs(T.BRANCHES) do BICON[b.id] = b.icon end

local function shadowText(text, x, y, w, c, a)
  col(C.bg, 0.9 * (a or 1)); lg.printf(text, x + 1, y + 1, w, "center")
  col(c, a or 1); lg.printf(text, x, y, w, "center")
end

local function drawNode(n, sx, sy, hov)
  local Fo = H.fonts
  local r, avail, maxed, can = nodeState(n)
  local c = C[n.col]
  local z = G.treeView.z
  local sel = G.treeSel == n.id
  local rad = nodeR(n) * (hov and 1.12 or 1)
  -- glow: owned nodes shine in their branch colour, affordable ones pulse orange
  lg.setBlendMode("add")
  if r > 0 then col(c, (maxed or n.endless) and 0.2 or 0.1); lg.circle("fill", sx, sy, rad * 2, 32) end
  if can then col(C.orange, 0.08 + 0.07 * math.sin(G.time * 4 + n.x * 3)); lg.circle("fill", sx, sy, rad * 1.8, 32) end
  lg.setBlendMode("alpha")
  -- body
  col(C.bg); lg.circle("fill", sx, sy, rad + 2, 32)
  col(C.panel); lg.circle("fill", sx, sy, rad, 32)
  if r > 0 then
    col(c, n.endless and 0.5 or (maxed and 0.8 or 0.42)); lg.circle("fill", sx, sy, rad * 0.8, 32)
    col(C.white, 0.18); lg.circle("fill", sx - rad * 0.22, sy - rad * 0.26, rad * 0.28, 16)
  end
  -- rings
  local ringC = sel and C.white or (r > 0 and c or (can and C.orange or (avail and C.dim or C.faint)))
  lg.setLineWidth((n.big or n.endless) and 2.4 or 1.7)
  col(ringC, avail and 1 or 0.5); lg.circle("line", sx, sy, rad, 32)
  if n.big or n.endless then col(ringC, 0.45); lg.circle("line", sx, sy, rad + 4, 32) end
  if n.endless then
    lg.setLineWidth(2); col(c, 0.8)
    for k = 0, 5 do
      local a = G.time * 0.6 + k / 6 * TAU
      lg.arc("line", "open", sx, sy, rad + 9, a, a + 0.35, 6)
    end
  end
  -- rank progress for multi-rank nodes
  if n.max > 1 and not n.endless then
    lg.setLineWidth(2.5)
    col(C.faint, 0.6); lg.circle("line", sx, sy, rad + 4, 32)
    if r > 0 then col(c); lg.arc("line", "open", sx, sy, rad + 4, -math.pi / 2, -math.pi / 2 + r / n.max * TAU, 32) end
  end
  lg.setLineWidth(1)
  -- glyph
  if not avail then I.draw("lock", sx, sy, 4.5 * clamp(z, 0.6, 1.3), C.faint)
  elseif n.endless then
    lg.setLineWidth(2); col(C.white, 0.9)
    lg.circle("line", sx - rad * 0.26, sy, rad * 0.24, 16); lg.circle("line", sx + rad * 0.26, sy, rad * 0.24, 16)
    lg.setLineWidth(1)
  elseif n.big then I.draw(BICON[n.b], sx, sy, rad * 0.42, r > 0 and C.white or C.line, r > 0 and 1 or 0.7)
  elseif maxed and n.max == 1 then I.draw("check", sx, sy, 5 * clamp(z, 0.6, 1.3), C.white) end
  -- selection marker
  if sel then
    lg.setLineWidth(2); col(C.white)
    for k = 0, 3 do
      local a = -G.time * 1.5 + k * math.pi / 2
      lg.arc("line", "open", sx, sy, rad + 12, a, a + 0.5, 6)
    end
    lg.setLineWidth(1)
  end
  -- labels only where they help: capstones, the hovered / selected node, or when zoomed in close
  if sel or hov or ((n.big or n.endless) and z >= 0.55) or z >= 1.25 then
    lg.setFont(Fo.xs)
    local ly = sy + rad + (n.endless and 14 or 8)
    shadowText(n.name:upper(), sx - 90, ly, 180, r > 0 and C.white or (avail and C.line or C.dim))
    local sub
    if n.endless then sub = "RANK " .. r .. "  //  " .. fmt(G.treeCost(n)) .. " CD"
    elseif maxed then sub = "MAX"
    elseif sel or hov or n.big then sub = (n.max > 1 and (r .. "/" .. n.max .. "  //  ") or "") .. fmt(G.treeCost(n)) .. " CD" end
    if sub then shadowText(sub, sx - 90, ly + 13, 180, maxed and c or (can and C.orange or (avail and C.red or C.faint))) end
  end
end

local function detail()
  local Fo = H.fonts
  local n = G.treeSel and T.BYID[G.treeSel]
  if not n then panelRect = nil return end
  local r, avail, maxed, can = nodeState(n)
  local c = C[n.col]
  local x, y, w, h = VX + 12, VY + VH - 162, 340, 150
  panelRect = {x, y, w, h}
  col(C.bg, 0.95); lg.rectangle("fill", x, y, w, h)
  H.hatch(x, y, w, 6, c, 0.8, 5)
  H.brackets(x, y, w, h, 8, c)
  lg.setFont(Fo.m); col(C.white); lg.print(H.fit(Fo.m, n.name:upper(), w - 24), x + 12, y + 12)
  local rk = n.endless and ("  //  RANK " .. r .. "  //  ENDLESS") or (n.max > 1 and ("  //  RANK " .. r .. " / " .. n.max) or (r > 0 and "  //  INSTALLED" or ""))
  H.label(n.b .. rk, x + 12, y + 36, c)
  H.richf(n.desc, x + 12, y + 54, w - 24, "left", C.line)
  if n.now then
    H.label("NOW " .. (r > 0 and n.now(r) or "-") .. (maxed and "" or ("   >>   NEXT " .. n.now(r + 1))), x + 12, y + 88, C.white)
  end
  if maxed then
    H.label("FULLY INSTALLED", x + 12, y + h - 30, c)
  elseif not avail then
    H.label("Requires " .. T.BYID[n.req].name:upper(), x + 12, y + h - 30, C.red)
  elseif n.max > 1 then
    local bw = (w - 30) / 2
    H.button(x + 12, y + h - 40, bw, 30, "INSTALL // " .. fmt(G.treeCost(n)) .. " CD", can, function() G.treeBuy(n) end, C.orange, Fo.xs, nil, can)
    H.button(x + 18 + bw, y + h - 40, bw, 30, "INSTALL MAX", can, function() G.treeBuyMax(n) end, C.gold, Fo.xs)
  else
    H.button(x + 12, y + h - 40, w - 24, 30, "INSTALL // " .. fmt(G.treeCost(n)) .. " CD", can, function() G.treeBuy(n) end, C.orange, Fo.s, nil, can)
  end
end

local function tree()
  local S, Fo = G.S, H.fonts
  local z = G.treeView.z
  col(C.bg, 1); lg.rectangle("fill", VX, VY, VW, VH)
  H.brackets(VX, VY, VW, VH, 12, C.line)
  lg.setScissor(VX, VY, VW, VH)
  local cx, cy = center()
  local U = unit()
  -- starfield
  for _, s in ipairs(stars) do
    local x = VX + (s.x + G.treeView.x * s.d) % VW
    local y = VY + (s.y + G.treeView.y * s.d) % VH
    col(C.white, 0.12 + 0.12 * math.sin(G.time * 1.5 + s.p))
    lg.rectangle("fill", x, y, s.s, s.s)
  end
  -- soft core nebula
  lg.setBlendMode("add")
  for k = 1, 4 do col(C.red, 0.02); lg.circle("fill", cx, cy, U * k * 0.7, 48) end
  lg.setBlendMode("alpha")
  -- branch titles at the tip of each spoke
  for _, b in ipairs(T.BRANCHES) do
    local far, ranks = 0, 0
    for _, n in ipairs(T.NODES) do if n.b == b.id then far = math.max(far, n.d); ranks = ranks + G.tr(n.id) end end
    local a = math.rad(b.a)
    local d = far * T.SPREAD * U + 34 + 30 * clamp(z, 0.5, 1.4) -- pixels past the tip node, at any zoom
    local lx, ly = cx + math.cos(a) * d, cy + math.sin(a) * d
    lg.setFont(z >= 0.4 and Fo.l or Fo.m)
    shadowText(b.id, lx - 120, ly - 14, 240, C[b.col], 0.7)
    lg.setFont(Fo.xs); shadowText(ranks .. " RANKS", lx - 120, ly + (z >= 0.4 and 14 or 8), 240, C.dim)
  end
  -- connections
  for _, n in ipairs(T.NODES) do
    local px, py = 0, 0
    if n.req ~= "root" then local p = T.BYID[n.req]; px, py = p.x, p.y end
    local x1, y1 = toScreen(px, py)
    local x2, y2 = toScreen(n.x, n.y)
    local r = G.tr(n.id)
    local c = C[n.col]
    if r > 0 then
      lg.setBlendMode("add"); lg.setLineWidth(6); col(c, 0.1); lg.line(x1, y1, x2, y2); lg.setBlendMode("alpha")
      lg.setLineWidth(2.4); col(c, 0.95); lg.line(x1, y1, x2, y2)
      local f = (G.time * 0.6 + n.x * 0.37 + n.y * 0.21) % 1
      lg.setBlendMode("add"); col(C.white, 0.9 * math.sin(f * math.pi))
      lg.circle("fill", x1 + (x2 - x1) * f, y1 + (y2 - y1) * f, 2.2, 8); lg.setBlendMode("alpha")
    elseif G.treeAvail(n) then
      lg.setLineWidth(1.6); col(c, 0.35); lg.line(x1, y1, x2, y2)
    else
      lg.setLineWidth(1); col(C.faint, 0.25); lg.line(x1, y1, x2, y2)
    end
  end
  lg.setLineWidth(1)
  -- hub
  local hr = 30 * clamp(z, 0.55, 1.3)
  lg.setBlendMode("add"); col(C.red, 0.12 + 0.05 * math.sin(G.time * 2)); lg.circle("fill", cx, cy, hr * 1.8, 48); lg.setBlendMode("alpha")
  col(C.bg); lg.circle("fill", cx, cy, hr + 2, 48)
  col(C.panel); lg.circle("fill", cx, cy, hr, 48)
  lg.setLineWidth(2); col(C.red); lg.circle("line", cx, cy, hr, 48)
  col(C.red, 0.5); lg.arc("line", "open", cx, cy, hr + 6, G.time * 0.4, G.time * 0.4 + math.pi * 0.6, 16)
  lg.arc("line", "open", cx, cy, hr + 6, G.time * 0.4 + math.pi, G.time * 0.4 + math.pi * 1.6, 16)
  lg.setLineWidth(1)
  lg.setFont(Fo.xs); col(C.dim); lg.printf("CORE DATA", cx - 60, cy - 13, 120, "center")
  lg.setFont(Fo.s); col(C.white); lg.printf(fmt(S.dm), cx - 60, cy, 120, "center")
  -- nodes
  local mx, my = V.mouse()
  local inView = mx >= VX and mx <= VX + VW and my >= VY + 28 and my <= VY + VH and not G.modal
  local hovN
  screenPos = {}
  for _, n in ipairs(T.NODES) do
    local sx, sy = toScreen(n.x, n.y)
    screenPos[#screenPos + 1] = {n = n, x = sx, y = sy, r = nodeR(n)}
    if inView and (mx - sx) ^ 2 + (my - sy) ^ 2 <= (nodeR(n) + 5) ^ 2 then hovN = n end
  end
  for _, p in ipairs(screenPos) do
    if p.n ~= hovN and p.x > VX - 80 and p.x < VX + VW + 80 and p.y > VY - 60 and p.y < VY + VH + 60 then drawNode(p.n, p.x, p.y, false) end
  end
  if hovN then local sx, sy = toScreen(hovN.x, hovN.y); drawNode(hovN, sx, sy, true) end -- hovered on top
  lg.setScissor()
  if hovN and not (panelRect and mx >= panelRect[1] and mx <= panelRect[1] + panelRect[3] and my >= panelRect[2] and my <= panelRect[2] + panelRect[4]) then
    local r = G.tr(hovN.id)
    H.setTip(hovN.name:upper() .. (hovN.endless and ("  //  RANK " .. r) or (hovN.max > 1 and ("  //  " .. r .. "/" .. hovN.max) or "")),
      hovN.desc .. (hovN.now and r > 0 and ("  //  now " .. hovN.now(r)) or "") ..
      (r < hovN.max and ("  //  " .. fmt(G.treeCost(hovN)) .. " CD") or "  //  MAX") ..
      (G.treeAvail(hovN) and "" or ("  //  requires " .. T.BYID[hovN.req].name)))
  end
  -- header + view controls
  col(C.bg, 0.85); lg.rectangle("fill", VX + 1, VY + 1, VW - 2, 26)
  H.label("PROTOCOL TREE  //  DRAG TO PAN  //  WHEEL TO ZOOM  //  CLICK A NODE, CLICK AGAIN TO INSTALL", VX + 12, VY + 8, C.white)
  local bx = VX + VW - 112
  H.button(bx, VY + 3, 32, 20, "-", true, function() Sc.zoom(-1, VX + VW / 2, VY + VH / 2) end, C.line, Fo.s)
  H.button(bx + 36, VY + 3, 32, 20, "+", true, function() Sc.zoom(1, VX + VW / 2, VY + VH / 2) end, C.line, Fo.s)
  H.button(bx + 72, VY + 3, 36, 20, "FIT", true, function() G.treeView = {x = 0, y = 14, z = FIT_Z} end, C.line, Fo.xs)
  H.scrollRegion(VX, VY, VW, VH, "treeZoom")
  detail()
end

-- view controls (called from main.lua)
function Sc.zoom(dy, mx, my)
  local v = G.treeView
  local nz = clamp(v.z * 1.15 ^ dy, FIT_Z * 0.85, 2.2)
  -- keep the point under the cursor fixed
  local cx, cy = VX + VW / 2 + v.x, VY + VH / 2 + v.y
  local k = nz / v.z
  v.x = v.x + (mx - cx) * (1 - k)
  v.y = v.y + (my - cy) * (1 - k)
  v.z = nz
end
local function inPanel(x, y)
  return panelRect and x >= panelRect[1] and x <= panelRect[1] + panelRect[3] and y >= panelRect[2] and y <= panelRect[2] + panelRect[4]
end
function Sc.press(x, y)
  if x < VX or x > VX + VW or y < VY + 28 or y > VY + VH or inPanel(x, y) then return end
  drag = {sx = x, sy = y, ox = G.treeView.x, oy = G.treeView.y, moved = false}
end
local function updateDrag()
  if not drag then return end
  if not love.mouse.isDown(1) then drag = nil return end
  local mx, my = V.mouse()
  if not drag.moved and (math.abs(mx - drag.sx) > 5 or math.abs(my - drag.sy) > 5) then drag.moved = true end
  if drag.moved then
    G.treeView.x = drag.ox + mx - drag.sx
    G.treeView.y = drag.oy + my - drag.sy
  end
end
function Sc.release(x, y)
  local d = drag
  drag = nil
  if not d or d.moved then return end
  for _, p in ipairs(screenPos) do
    if (x - p.x) ^ 2 + (y - p.y) ^ 2 <= (p.r + 5) ^ 2 then
      if G.treeSel == p.n.id then
        if G.treeBuy(p.n) then FX.burst(p.x, p.y, 30, C[p.n.col], 240) end
      else
        G.treeSel = p.n.id
        FX.play("tick", 1.2)
      end
      return
    end
  end
  G.treeSel = nil
end

function Sc.draw()
  local Fo = H.fonts
  H.screenTitle("REBOOT")
  updateDrag()
  prestige()
  tree()
end

return Sc
