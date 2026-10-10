-- Full-screen tactical MAP (modeled on the Oblivion "scav activity plot" screen).
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local lg = V.lg
local C, col, fmt, clamp = H.C, H.col, H.fmt, H.clamp
local TAU = math.pi * 2
local Tac = {}

local MX0, MY0, CS = G.TAC.MX0, G.TAC.MY0, G.TAC.CS
local MW, MH = G.MW, G.MH
local RX, RW = 988, 276 -- right column
local hovEnemy, hovCrate, hovCell

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------
local function emblem(x, y, s, c, a, fill)
  local pts = {x - s, y - s * 0.8, x + s, y - s * 0.8, x + s, y + s * 0.1, x, y + s, x - s, y + s * 0.1}
  if fill then col(c, (a or 1) * 0.35); lg.polygon("fill", pts) end
  col(c, a or 1)
  lg.polygon("line", pts)
  lg.line(x - s * 0.5, y - s * 0.3, x, y + s * 0.25, x + s * 0.5, y - s * 0.3)
end

-- radiation trefoil
local function trefoil(x, y, r, c, a)
  col(c, a)
  lg.circle("fill", x, y, r * 0.22, 10)
  for k = 0, 2 do
    local a0 = -math.pi / 2 + k * TAU / 3 - 0.5
    lg.arc("fill", x, y, r, a0, a0 + 1.0, 8)
  end
  col(C.bg, a)
  lg.circle("fill", x, y, r * 0.4, 10)
  col(c, a)
  lg.circle("fill", x, y, r * 0.22, 10)
end

local function enemyColor(e)
  local id = e.def.id
  if id == "SCOUT" then return C.line elseif id == "RAIDER" then return C.red
  elseif id == "BRUTE" then return C.orange end
  return C.red
end

local function playIcon(kind, x, y, s, c)
  col(c)
  if kind == "rew" then
    lg.polygon("line", x - 2, y, x + s * 0.5 - 2, y - s * 0.5, x + s * 0.5 - 2, y + s * 0.5)
    lg.polygon("line", x - s * 0.5 - 2, y, x - 2, y - s * 0.5, x - 2, y + s * 0.5)
  elseif kind == "prev" then
    lg.polygon("fill", x - s * 0.5, y, x + s * 0.4, y - s * 0.6, x + s * 0.4, y + s * 0.6)
  elseif kind == "stop" then
    lg.rectangle("line", x - s * 0.45, y - s * 0.45, s * 0.9, s * 0.9)
  elseif kind == "next" then
    lg.polygon("line", x + s * 0.5, y, x - s * 0.4, y - s * 0.6, x - s * 0.4, y + s * 0.6)
  elseif kind == "ff" then
    lg.polygon("line", x + 2, y, x - s * 0.5 + 2, y - s * 0.5, x - s * 0.5 + 2, y + s * 0.5)
    lg.polygon("line", x + s * 0.5 + 2, y, x + 2, y - s * 0.5, x + 2, y + s * 0.5)
  end
end

local function cycleTarget(dir)
  if #G.enemies == 0 then FX.play("err") return end
  local cur = 0
  if G.tacSel and G.tacSel.kind == "enemy" then
    for k, e in ipairs(G.enemies) do if e.uid == G.tacSel.uid then cur = k end end
  end
  local k = (cur - 1 + dir) % #G.enemies + 1
  G.tacSel = {kind = "enemy", uid = G.enemies[k].uid}
  FX.play("tick", 1.2)
end

----------------------------------------------------------------------
-- top strip: zone readout + playback controls
----------------------------------------------------------------------
local function topStrip()
  local S = G.S
  local F = H.fonts
  local x = 24
  H.label("ZONE", x, 58)
  lg.setFont(F.xl); col(C.white); lg.print(string.format("%02d", S.zone), x - 2, 68)
  lg.setFont(F.m); col(C.line); lg.print(D.zoneName(S.zone), x + 50, 62)
  H.label("THREAT x" .. string.format("%.2f", G.zoneF()) .. "  //  LOOT ILVL " .. S.zone .. "  //  CLEARED " .. S.zoneBest, x + 50, 84)
  -- scav activity readout, right of the controls
  local activity = #G.enemies / G.enemyCap() * 100
  for _, e in ipairs(G.enemies) do activity = activity + e.raid * 20 + (e.def.boss and 50 or 0) end
  local ax = 770
  H.label("SCAV ACTIVITY", ax, 60, G.raidAlert and C.red or C.dim)
  H.label(G.eventActive("INVASION") and "INVASION EVENT" or "REPORTING", ax, 72, G.eventActive("INVASION") and C.red or C.faint)
  lg.setFont(F.xl); col(G.raidAlert and C.red or C.white); lg.printf(string.format("%.1f", activity), ax, 64, 202, "right")

  -- playback-style controls
  local btns = {
    {"rew", "RECALL", function() G.recallAll() end},
    {"prev", "PREV", function() cycleTarget(-1) end},
    {"stop", "CLAIM", function() G.dispatchAll() end},
    {"next", "NEXT", function() cycleTarget(1) end},
    {"ff", "AUTO", function() S.autoHunt = not S.autoHunt; FX.play("tick", S.autoHunt and 1.4 or 0.8) end},
  }
  local bx0 = MX0 + MW * CS / 2 - 128
  H.brackets(bx0 - 6, 56, 5 * 52 + 8, 50, 8, C.line, 0.6)
  for k, b in ipairs(btns) do
    local x, y, w, h = bx0 + (k - 1) * 52, 60, 46, 30
    local hov = H.mouseIn(x, y, w, h)
    local on = (b[1] == "ff" and S.autoHunt)
    col(C.line, on and 0.25 or (hov and 0.15 or 0.04)); lg.rectangle("fill", x, y, w, h)
    col(on and C.white or C.dim, 0.8); lg.rectangle("line", x, y, w, h)
    playIcon(b[1], x + w / 2, y + h / 2, 16, (hov or on) and C.white or C.line)
    H.label(b[2], x + w / 2 - F.xs:getWidth(b[2]) / 2, y + h + 2, on and C.white or C.dim)
    H.addHit(x, y, w, h, b[3])
  end
end

----------------------------------------------------------------------
-- left: fleet list + scav alert gauge
----------------------------------------------------------------------
local function fleetList()
  local S = G.S
  local F = H.fonts
  local x, y, w = 24, 108, 208
  local top, bottom = y + 22, 512
  col(C.panel, 0.7); lg.rectangle("fill", x, y, w, bottom - y)
  H.brackets(x, y, w, bottom - y, 8, C.line, 0.6)
  H.label("FC ID", x + 8, y + 6)
  H.label("STATUS", x + 96, y + 6)
  H.label("HULL", x + 168, y + 6)
  H.scrollRegion(x, top, w, bottom - top, "fleet")
  lg.setScissor(x, top, w, bottom - top)
  local now = G.now()
  local rowH = 26
  local yy = top - G.scroll.fleet
  for k, d in ipairs(S.drones) do
    local rc = C[D.RARITY[d.r].col]
    local st = G.droneStatus(d)
    local sel = G.tacSel and G.tacSel.kind == "drone" and G.tacSel.id == d.id
    if sel then col(C.line, 0.12); lg.rectangle("fill", x + 2, yy, w - 4, rowH - 2) end
    col(rc); lg.circle("line", x + 14, yy + 12, 9, 20)
    lg.setFont(F.xs); col(C.white); lg.printf(string.format("%02d", k), x + 5, yy + 6, 18, "center")
    lg.setFont(F.s); col(rc); lg.print(tostring(d.id), x + 28, yy + 4)
    local sc = st == "MISSING" and C.red or (st == "HUNT" and C.orange or (st == "CLAIM" and C.white or C.line))
    col(sc); lg.rectangle("line", x + 84, yy + 4, 76, 16)
    lg.setFont(F.xs)
    local txt = st
    if st == "MISSING" then txt = "MIA " .. math.ceil(d.down - now)
    elseif st == "CLAIM" then txt = "CLAIM " .. math.ceil(math.max(0, d.mission.ends - now)) end
    lg.printf(txt, x + 84, yy + 6, 76, "center")
    H.segbar(x + 166, yy + 9, 34, 6, st == "MISSING" and 0 or (d.hp or 1) / G.droneMaxHp(d), 4,
      (d.hp or 1) < G.droneMaxHp(d) * 0.35 and C.red or C.line)
    H.addHit(x, yy, w, rowH - 2, function()
      G.tacSel = {kind = "drone", id = d.id}
      FX.play("tick")
    end, {top, bottom})
    yy = yy + rowH
  end
  if #S.drones == 0 then
    H.label("NO DRONES IN FLEET", x + 8, top + 10, C.red)
    H.label("FABRICATE IN DRONES", x + 8, top + 26, C.dim)
  end
  lg.setScissor()
  G.maxScroll.fleet = math.max(0, #S.drones * rowH - (bottom - top))

  -- scav alert ring
  local cx, cy = 64, 590
  local n = 24
  local ratio = G.boss() and 1 or (S.bossDown and 0 or math.max(0, S.alert or 0))
  H.label("SCAV ALERT", 24, 522, (ratio >= 0.75 or G.raidAlert) and C.red or C.dim)
  if H.mouseIn(24, 520, 90, 100) then H.setTip("SCAV ALERT", "Claiming sectors and destroying scavs raise the alert. At 100% the mothership arrives. More territory also means more scavs spawning.") end
  for k = 0, n - 1 do
    local a = -math.pi / 2 + k / n * TAU
    local lit = k / n < ratio
    col(lit and (ratio > 0.75 and C.red or C.line) or C.faint, lit and 1 or 0.6)
    lg.circle(lit and "fill" or "line", cx + math.cos(a) * 30, cy + math.sin(a) * 30, 2.5, 8)
  end
  lg.setFont(F.s); col(ratio >= 0.75 and C.red or C.white); lg.printf(math.floor(ratio * 100) .. "%", cx - 30, cy - 12, 60, "center")
  lg.setFont(F.xs); col(C.dim); lg.printf(#G.enemies .. "/" .. G.enemyCap(), cx - 30, cy + 4, 60, "center")
  local stats = {{"KILLS", fmt(S.kills)}, {"RAIDS", fmt(S.raidsRepelled)}, {"BOSSES", fmt(S.bosses)}}
  for k, st in ipairs(stats) do
    local yy2 = 546 + (k - 1) * 34
    col(C.line, 0.4); lg.line(cx + 34, cy, 116, yy2 + 8)
    col(C.line, 0.7); lg.rectangle("line", 118, yy2, 114, 18)
    H.label(st[1], 120, yy2 - 11, C.dim)
    lg.setFont(F.xs); col(C.white); lg.printf(st[2], 118, yy2 + 3, 110, "right")
  end
end

----------------------------------------------------------------------
-- map
----------------------------------------------------------------------
----------------------------------------------------------------------
-- terrain chart: coastline, elevation contours, depth soundings, hillshade.
-- Built from the same height field as the land and cached per map / window scale / theme.
----------------------------------------------------------------------
local chart = {}
-- marching squares: corner bits tl=8 tr=4 br=2 bl=1 -> crossed edges
local MS = {
  [1] = {{"l", "b"}}, [2] = {{"b", "r"}}, [3] = {{"l", "r"}}, [4] = {{"t", "r"}}, [5] = {{"t", "r"}, {"l", "b"}},
  [6] = {{"t", "b"}}, [7] = {{"t", "l"}}, [8] = {{"t", "l"}}, [9] = {{"t", "b"}}, [10] = {{"t", "l"}, {"b", "r"}},
  [11] = {{"t", "r"}}, [12] = {{"l", "r"}}, [13] = {{"b", "r"}}, [14] = {{"l", "b"}},
}
local function terrainChart()
  local S = G.S
  local s = V.s
  local key = table.concat({S.map.seed, s, C.line[1], C.line[2], C.teal[1], C.bg[1]}, "|")
  if chart.key == key then return chart.canvas end
  if chart.canvas then chart.canvas:release() end
  local g = love.graphics
  local R = 4 -- height samples per sector
  local nx, ny, step = MW * R, MH * R, CS / R
  local h = {}
  for j = 0, ny do
    h[j] = {}
    for i = 0, nx do h[j][i] = G.terrainH(0.5 + i / R, 0.5 + j / R) end
  end
  local cv = g.newCanvas(math.ceil(MW * CS * s), math.ceil(MH * CS * s))
  g.push("all")
  g.setCanvas(cv)
  g.setScissor()
  g.clear(0, 0, 0, 0)
  g.origin()
  g.scale(s)
  -- hillshade on land, light from the top-left
  for j = 1, ny - 1 do
    for i = 1, nx - 1 do
      if h[j][i] > 0.46 then
        local sh = (h[j][i - 1] - h[j][i + 1]) + (h[j - 1][i] - h[j + 1][i])
        if sh > 0 then g.setColor(1, 1, 1, math.min(0.07, sh * 0.9)) else g.setColor(0, 0, 0, math.min(0.14, -sh * 1.3)) end
        g.rectangle("fill", i * step - step / 2, j * step - step / 2, step, step)
      end
    end
  end
  local function contour(L, c, a, lw, dash)
    g.setColor(c[1], c[2], c[3], a)
    g.setLineWidth(lw / s)
    local n = 0
    for j = 0, ny - 1 do
      for i = 0, nx - 1 do
        local tl, tr, br, bl = h[j][i], h[j][i + 1], h[j + 1][i + 1], h[j + 1][i]
        local id = (tl > L and 8 or 0) + (tr > L and 4 or 0) + (br > L and 2 or 0) + (bl > L and 1 or 0)
        local cases = MS[id]
        if cases then
          local x0, y0 = i * step, j * step
          local e = {
            t = {x0 + (L - tl) / (tr - tl) * step, y0}, r = {x0 + step, y0 + (L - tr) / (br - tr) * step},
            b = {x0 + (L - bl) / (br - bl) * step, y0 + step}, l = {x0, y0 + (L - tl) / (bl - tl) * step},
          }
          for _, sg in ipairs(cases) do
            n = n + 1
            if not dash or n % 3 ~= 0 then
              local p, q = e[sg[1]], e[sg[2]]
              g.line(p[1], p[2], q[1], q[2])
            end
          end
        end
      end
    end
  end
  -- sea: dashed depth soundings
  contour(0.40, C.teal, 0.22, 1, true)
  contour(0.33, C.teal, 0.14, 1, true)
  contour(0.26, C.teal, 0.10, 1, true)
  -- land: elevation contours, every second one stronger (index contours)
  for k, L in ipairs({0.52, 0.58, 0.64, 0.70, 0.76}) do contour(L, C.line, k % 2 == 0 and 0.24 or 0.13, 1) end
  -- coastline with a soft halo
  contour(0.46, C.line, 0.08, 4)
  contour(0.46, C.line, 0.55, 1.3)
  -- peak markers
  g.setLineWidth(1 / s)
  for j = 2, ny - 2, 2 do
    for i = 2, nx - 2, 2 do
      local v = h[j][i]
      if v > 0.68 and v >= h[j][i - 2] and v >= h[j][i + 2] and v >= h[j - 2][i] and v >= h[j + 2][i] then
        local x, y = i * step, j * step
        g.setColor(C.line[1], C.line[2], C.line[3], 0.45)
        g.polygon("line", x - 3, y + 2, x + 3, y + 2, x, y - 3)
      end
    end
  end
  g.pop()
  chart.key, chart.canvas = key, cv
  return cv
end

local function drawMap()
  local S = G.S
  local F = H.fonts
  for x = 1, MW do H.label(string.char(64 + x), MX0 + (x - 1) * CS + 11, MY0 - 13) end
  for y = 1, MH do H.label(tostring(y), MX0 - 16, MY0 + (y - 1) * CS + 9) end
  local vx, vy = V.mouse()
  local inMap = vx >= MX0 and vx < MX0 + MW * CS and vy >= MY0 and vy < MY0 + MH * CS and not G.modal
  hovEnemy, hovCrate, hovCell = nil, nil, nil
  if inMap then
    hovCell = G.idx(math.floor((vx - MX0) / CS) + 1, math.floor((vy - MY0) / CS) + 1)
    for _, e in ipairs(G.enemies) do
      local px, py = G.toPx(e.x, e.y)
      if (px - vx) ^ 2 + (py - vy) ^ 2 < (e.def.boss and 26 or 15) ^ 2 then hovEnemy = e end
    end
    if not hovEnemy then
      for k, c in ipairs(S.crateList) do
        local px, py = G.toPx(c.x, c.y)
        if (px - vx) ^ 2 + (py - vy) ^ 2 < 13 ^ 2 then hovCrate = k end
      end
    end
  end
  local blink = math.floor(G.time * 3) % 2 == 0
  col(C.bg); lg.rectangle("fill", MX0, MY0, MW * CS, MH * CS)
  for y = 1, MH do
    for x = 1, MW do
      local i = G.idx(x, y)
      local st = S.map.cells[i]
      local land = G.land[i]
      local cx, cy = MX0 + (x - 1) * CS, MY0 + (y - 1) * CS
      if st == 0 then
        if land then
          col(C.faint, 0.28); lg.rectangle("fill", cx, cy, CS, CS)
          col(C.dim, 0.16)
          for d = 4, CS - 2, 8 do lg.rectangle("fill", cx + d, cy + (d * 7 + i) % (CS - 4) + 2, 1.5, 1.5) end
        end
      elseif not land then
        col(C.sea); lg.rectangle("fill", cx, cy, CS, CS)
        col(C.teal, 0.12)
        for ly = cy + 4, cy + CS - 2, 6 do lg.line(cx + 3, ly, cx + CS - 3, ly) end
      elseif st == 2 then
        col(C.teal, 0.42); lg.rectangle("fill", cx, cy, CS, CS)
        col(C.white, 0.45); lg.line(cx + 12, cy + 15, cx + 18, cy + 15); lg.line(cx + 15, cy + 12, cx + 15, cy + 18)
      elseif st == 3 then
        col(C.orange, 0.12); lg.rectangle("fill", cx, cy, CS, CS)
        H.hatch(cx, cy, CS, CS, C.orange, blink and 0.6 or 0.3, 5)
      else
        local front = G.adjClaimed(i)
        col(C.red, 0.07); lg.rectangle("fill", cx, cy, CS, CS)
        H.hatch(cx, cy, CS, CS, C.red, front and 0.55 or 0.25, 5)
        col(C.red, front and 0.6 or 0.3); lg.rectangle("line", cx + 0.5, cy + 0.5, CS - 1, CS - 1)
        if G.cellLoot(i) then
          col(C.orange, 0.6 + 0.4 * math.sin(G.time * 4 + i))
          lg.polygon("fill", cx + CS - 8, cy + 3, cx + CS - 4, cy + 7, cx + CS - 8, cy + 11, cx + CS - 12, cy + 7)
        end
      end
    end
  end
  -- the terrain chart over the sector fills; unscanned sectors stay fogged
  local tc = terrainChart()
  if tc then lg.setColor(1, 1, 1, 1); lg.draw(tc, MX0, MY0, 0, 1 / V.s) end
  col(C.bg, 0.55)
  for y = 1, MH do
    for x = 1, MW do
      if S.map.cells[G.idx(x, y)] == 0 then lg.rectangle("fill", MX0 + (x - 1) * CS, MY0 + (y - 1) * CS, CS, CS) end
    end
  end
  col(C.line, 0.08)
  for x = 0, MW do lg.line(MX0 + x * CS, MY0, MX0 + x * CS, MY0 + MH * CS) end
  for y = 0, MH do lg.line(MX0, MY0 + y * CS, MX0 + MW * CS, MY0 + y * CS) end
  -- radiation trefoils on scanned sectors + map layer overlays
  local layer = G.mapLayer or "terrain"
  local bestClaim = 0
  for _, d in ipairs(S.drones) do bestClaim = math.max(bestClaim, G.claimPower(d)) end
  for y = 1, MH do
    for x = 1, MW do
      local i = G.idx(x, y)
      local st = S.map.cells[i]
      local cx, cy = MX0 + (x - 1) * CS, MY0 + (y - 1) * CS
      if st ~= 0 and G.isRadiation(i) and layer ~= "radiation" then
        trefoil(cx + 8, cy + 8, 4, C.gold, st == 2 and 0.4 or 0.85)
      end
      if layer == "threat" and st ~= 0 and G.land[i] and i ~= G.TIDX and st ~= 2 then
        local f = clamp(G.threat(i) / math.max(1, bestClaim), 0, 2) / 2
        local c = f <= 0.5 and C.line or (f < 0.75 and C.orange or C.red)
        col(c, 0.35); lg.rectangle("fill", cx + 1, cy + 1, CS - 2, CS - 2)
        lg.setFont(F.xs); col(C.white, 0.9); lg.printf(fmt(G.threat(i)), cx, cy + 9, CS, "center")
      elseif layer == "loot" and st ~= 0 and st ~= 2 then
        local loot = G.cellLoot(i)
        if loot then
          col(C.bg, 0.6); lg.rectangle("fill", cx + 1, cy + 1, CS - 2, CS - 2)
          local lc = loot == "ARTIFACT" and C.gold or (loot == "WRECK" and C.red or (loot == "SALVAGE" and C.white or C.orange))
          col(lc); lg.rectangle("line", cx + 3, cy + 3, CS - 6, CS - 6)
          lg.setFont(F.xs); col(lc); lg.printf(loot:sub(1, 3), cx, cy + 9, CS, "center")
        end
      elseif layer == "radiation" and G.isRadiation(i) then
        H.hatch(cx, cy, CS, CS, C.gold, st == 0 and 0.2 or 0.5, 4)
        trefoil(cx + CS / 2, cy + CS / 2, 7, C.gold, st == 0 and 0.5 or 1)
      end
    end
  end

  -- weather on the map
  local wd = G.weather.def.id
  if wd == "FOG" then
    for k = 0, 5 do
      local fx = MX0 + ((G.time * 12 + k * 137) % (MW * CS + 200)) - 100
      local fy = MY0 + (k * 83) % (MH * CS)
      col(C.dim, 0.08); lg.ellipse("fill", fx, fy, 160, 50, 32)
    end
  elseif wd == "STORM" then
    col(C.bg, 0.25); lg.rectangle("fill", MX0, MY0, MW * CS, MH * CS)
    if math.floor(G.time * 7) % 23 == 0 then
      local lx = MX0 + (math.sin(math.floor(G.time * 7)) * 0.5 + 0.5) * MW * CS
      col(C.white, 0.8)
      local px, py = lx, MY0
      for _ = 1, 8 do
        local nx, ny = px + H.rnd(-18, 18), py + MH * CS / 8
        lg.line(px, py, nx, ny); px, py = nx, ny
      end
      col(C.white, 0.06); lg.rectangle("fill", MX0, MY0, MW * CS, MH * CS)
    end
  elseif wd == "TAILWIND" then
    local a = G.weather.wind
    col(C.line, 0.12)
    for k = 0, 24 do
      local px = MX0 + (k * 97 + G.time * 60 * math.cos(a)) % (MW * CS)
      local py = MY0 + (k * 53 + G.time * 60 * math.sin(a)) % (MH * CS)
      lg.line(px, py, px + math.cos(a) * 20, py + math.sin(a) * 20)
    end
  end

  -- sweep
  local sx = MX0 + (G.time * 90) % (MW * CS)
  for k = 0, 12 do col(C.line, 0.2 * (1 - k / 12)); lg.line(sx - k * 2, MY0, sx - k * 2, MY0 + MH * CS) end
  H.brackets(MX0 - 4, MY0 - 4, MW * CS + 8, MH * CS + 8, 16, C.line)

  -- tower + turret range
  local tx, ty = G.toPx(G.TX, G.TY)
  local range = ((S.pupg.turret and 3.5 or 2.5) + 0.5 * G.tr("map_turret")) * CS
  col(C.line, 0.25)
  for k = 0, 47, 2 do lg.arc("line", "open", tx, ty, range, k / 48 * TAU + G.time * 0.1, (k + 1) / 48 * TAU + G.time * 0.1, 3) end
  col(C.white); lg.setLineWidth(2)
  lg.polygon("line", tx - 9, ty - 7, tx + 9, ty - 7, tx, ty + 9)
  lg.setLineWidth(1)
  if G.turretBeam then
    local bx, by = G.toPx(G.turretBeam.x, G.turretBeam.y)
    col(C.white, 0.9); lg.setLineWidth(2); lg.line(tx, ty, bx, by); lg.setLineWidth(1)
  end

  -- crates with loot beams
  for k, c in ipairs(S.crateList) do
    local px, py = G.toPx(c.x, c.y)
    local L = D.LOOT[c.r]
    local cc = C[L.col]
    local pulse = 0.6 + 0.4 * math.sin(G.time * 5 + k)
    if c.r >= 3 then
      for j = 0, 9 do
        col(cc, (0.35 - j * 0.035) * pulse)
        lg.rectangle("fill", px - 1.5, py - 6 - j * 4, 3, 4)
      end
    end
    if c.r >= 5 then
      lg.setBlendMode("add")
      col(cc, 0.18 * pulse); lg.circle("fill", px, py, 16 + 4 * pulse, 24)
      lg.setBlendMode("alpha")
    end
    lg.push(); lg.translate(px, py); lg.rotate(math.pi / 4 + (c.r >= 4 and G.time or 0))
    col(cc, 0.3); lg.rectangle("fill", -5, -5, 10, 10)
    col(cc); lg.rectangle("line", -5, -5, 10, 10)
    lg.pop()
    if c.r >= 4 or hovCrate == k then H.label(L.name, px + 9, py - 5, cc) end
    if hovCrate == k then H.brackets(px - 10, py - 10, 20, 20, 4, C.white) end
  end

  -- drones
  for _, d in ipairs(S.drones) do
    if not G.isDown(d) then
      local px, py = G.toPx(d.px, d.py)
      local rc = C[D.RARITY[d.r].col]
      if d.hunt and (d.beam or 0) > 0 then
        local e = G.findEnemy(d.hunt)
        if e then
          local ex, ey = G.toPx(e.x, e.y)
          col(rc, 0.9); lg.line(px, py, ex, ey)
        end
      elseif d.mission then
        local cx, cy = G.xy(d.mission.cell)
        local ex, ey = G.toPx(cx, cy)
        col(C.orange, 0.3)
        for s = 0, 9, 2 do
          lg.line(tx + (ex - tx) * s / 10, ty + (ey - ty) * s / 10, tx + (ex - tx) * (s + 1) / 10, ty + (ey - ty) * (s + 1) / 10)
        end
      end
      col(rc)
      lg.polygon("fill", px, py - 4, px + 4, py, px, py + 4, px - 4, py)
      local sel = G.tacSel and G.tacSel.kind == "drone" and G.tacSel.id == d.id
      if sel then
        H.brackets(px - 9, py - 9, 18, 18, 4, C.white)
        H.label(G.droneLabel(d), px + 8, py - 12, C.white)
      end
    end
  end

  -- enemies
  for _, e in ipairs(G.enemies) do
    local px, py = G.toPx(e.x, e.y)
    local cx, cy = math.floor(e.x + 0.5), math.floor(e.y + 0.5)
    local fog = (cx >= 1 and cx <= MW and cy >= 1 and cy <= MH and S.map.cells[G.idx(cx, cy)] == 0) or G.fogged(e)
    local ec = e.flash > 0.5 and C.white or enemyColor(e)
    if fog and not e.def.boss then
      col(C.dim, 0.5 + 0.3 * math.sin(G.time * 6 + e.uid))
      lg.rectangle("line", px - 4, py - 4, 8, 8)
      H.label("?", px + 6, py - 6, C.dim)
    else
      if e.def.boss then
        emblem(px, py, 18, ec, 1, true)
        lg.push(); lg.translate(px, py); lg.rotate(G.time)
        H.brackets(-28, -28, 56, 56, 9, C.red)
        lg.pop()
      elseif e.def.id == "ELITE" then
        emblem(px, py, 9, ec, 1, true)
      else
        local s = e.def.id == "BRUTE" and 7 or (e.def.id == "RAIDER" and 5 or 4)
        col(ec, 0.35); lg.rectangle("fill", px - s, py - s, s * 2, s * 2)
        col(ec); lg.rectangle("line", px - s, py - s, s * 2, s * 2)
        lg.line(px - s * 0.5, py - s * 0.5, px + s * 0.5, py + s * 0.5)
        lg.line(px + s * 0.5, py - s * 0.5, px - s * 0.5, py + s * 0.5)
      end
      H.label("x " .. e.code, px + (e.def.boss and 24 or 9), py - 6, ec, 0.8)
      if e.hp < e.max then
        local bw = e.def.boss and 56 or 22
        col(C.bg, 0.8); lg.rectangle("fill", px - bw / 2, py - (e.def.boss and 34 or 14), bw, 3)
        col(C.red); lg.rectangle("fill", px - bw / 2, py - (e.def.boss and 34 or 14), bw * clamp(e.hp / e.max, 0, 1), 3)
      end
      if e.raid > 0 then
        lg.setLineWidth(2); col(C.red, blink and 1 or 0.5)
        lg.arc("line", "open", px, py, e.def.boss and 32 or 14, -math.pi / 2, -math.pi / 2 + e.raid * TAU, 24)
        lg.setLineWidth(1)
      end
    end
    local sel = G.tacSel and G.tacSel.kind == "enemy" and G.tacSel.uid == e.uid
    if sel or hovEnemy == e then
      lg.push(); lg.translate(px, py); lg.rotate(sel and G.time * 2 or 0)
      local r = e.def.boss and 34 or 15
      H.brackets(-r, -r, r * 2, r * 2, 5, sel and C.orange or C.white)
      lg.pop()
    end
  end

  -- selected cell
  if G.tacSel and G.tacSel.kind == "cell" then
    local x, y = G.xy(G.tacSel.i)
    H.brackets(MX0 + (x - 1) * CS - 2, MY0 + (y - 1) * CS - 2, CS + 4, CS + 4, 6, C.white)
  end
  if hovCell and not hovEnemy and not hovCrate then
    local x, y = G.xy(hovCell)
    col(C.white, 0.4); lg.rectangle("line", MX0 + (x - 1) * CS, MY0 + (y - 1) * CS, CS, CS)
  end

  -- TET strike beam
  if G.tetBeam then
    local b = G.tetBeam
    local a = 1 - b.t / 0.8
    lg.setBlendMode("add")
    col(C.white, a * 0.8); lg.rectangle("fill", b.x - 6 * a, MY0, 12 * a, b.y - MY0)
    col(C.line, a * 0.4); lg.rectangle("fill", b.x - 16 * a, MY0, 32 * a, b.y - MY0)
    col(C.white, a * 0.5); lg.circle("line", b.x, b.y, 3 * CS * (0.4 + b.t), 48)
    lg.setBlendMode("alpha")
  end

  -- hover coordinate readout (lat/long style, like the field maps)
  if hovCell then
    local x, y = G.xy(hovCell)
    local lat = 29.1 + (G.MH - y) * 0.0137 + (S.map.seed % 1) * 0.01
    local lon = -82.7 - (G.MW - x) * 0.0119
    local txt = string.format("%s  //  %.6f  %.6f", G.cellName(hovCell), lat, lon)
    local tw = F.xs:getWidth(txt) + 16
    local bx = math.min(vx + 14, MX0 + MW * CS - tw - 2)
    local by = vy + 18 > MY0 + MH * CS - 40 and vy - 34 or vy + 18
    col(C.bg, 0.85); lg.rectangle("fill", bx, by, tw, 16)
    col(C.red, 0.9); lg.rectangle("fill", bx, by, 3, 16)
    lg.setFont(F.xs); col(C.white); lg.print(txt, bx + 8, by + 2)
  end

  H.addHit(MX0, MY0, MW * CS, MH * CS, function(px, py)
    if hovEnemy then
      G.tacSel = {kind = "enemy", uid = hovEnemy.uid}
      G.strike(hovEnemy)
    elseif hovCrate then
      G.openCrate(hovCrate)
    else
      local i = G.idx(math.floor((px - MX0) / CS) + 1, math.floor((py - MY0) / CS) + 1)
      if G.tacSel and G.tacSel.kind == "cell" and G.tacSel.i == i and G.claimable(i) then
        if G.deploy(i) then FX.play("signal", 1.4, 0.5) else FX.play("err") end
      else
        G.tacSel = {kind = "cell", i = i}
        FX.play("tick")
      end
    end
  end)
  -- map layer chips (bottom-left, inside the frame)
  local layers = {{"terrain", "TERRAIN"}, {"threat", "THREAT"}, {"loot", "LOOT"}, {"radiation", "RADIATION"}}
  local lx, ly = MX0 + 6, MY0 + MH * CS - 26
  col(C.bg, 0.75); lg.rectangle("fill", lx - 4, ly - 4, 4 * 84 + 6, 28)
  for k, l in ipairs(layers) do
    local bx = lx + (k - 1) * 84
    local on = layer == l[1]
    local hov = H.mouseIn(bx, ly, 80, 20)
    local lc = l[1] == "radiation" and C.gold or C.line
    col(lc, on and 0.35 or (hov and 0.15 or 0.05)); lg.rectangle("fill", bx, ly, 80, 20)
    H.brackets(bx, ly, 80, 20, 4, on and C.white or lc, on and 1 or 0.6)
    lg.setFont(F.xs); col(on and C.white or lc); lg.printf(l[2], bx, ly + 4, 80, "center")
    H.addHit(bx, ly, 80, 20, function() G.mapLayer = l[1]; FX.play("tick", 1.2) end)
  end

  -- mothership indicator: approach line, pulsing rings, alert strip (click to target)
  local boss = G.boss()
  local sw, sx, sy = 420, MX0 + MW * CS / 2 - 210, MY0 + 4
  if boss then
    local bx, by = G.toPx(boss.x, boss.y)
    local tx, ty = G.toPx(G.TX, G.TY)
    local b = 0.5 + 0.5 * math.sin(G.time * 6)
    local dist = math.sqrt((bx - tx) ^ 2 + (by - ty) ^ 2)
    col(C.red, 0.5)
    for d = (G.time * 40) % 16, dist, 16 do
      local p = d / dist
      lg.line(tx + (bx - tx) * p, ty + (by - ty) * p, tx + (bx - tx) * math.min(1, p + 6 / dist), ty + (by - ty) * math.min(1, p + 6 / dist))
    end
    for j = 0, 2 do
      local p = (G.time * 0.8 + j / 3) % 1
      col(C.red, (1 - p) * 0.7); lg.circle("line", bx, by, 30 + p * 60, 48)
    end
    local tag = (boss.bounty or 0) > 0 and ("BOUNTY " .. H.fmtTime(boss.bounty)) or "BOUNTY EXPIRED"
    local tw = F.xs:getWidth(tag) + 16
    col(C.bg, 0.85); lg.rectangle("fill", bx - tw / 2, by + 40, tw, 16)
    col(C.red, 0.6 + 0.4 * b); lg.rectangle("line", bx - tw / 2 + 0.5, by + 40.5, tw - 1, 15)
    lg.setFont(F.xs); col((boss.bounty or 0) > 0 and C.gold or C.dim); lg.printf(tag, bx - tw / 2, by + 42, tw, "center")
    -- alert strip
    local hov = H.mouseIn(sx, sy, sw, 24)
    col(C.red, 0.25 + 0.15 * b + (hov and 0.1 or 0)); lg.rectangle("fill", sx, sy, sw, 24)
    H.hatch(sx, sy, 6, 24, C.red, 0.9, 3); H.hatch(sx + sw - 6, sy, 6, 24, C.red, 0.9, 3)
    H.brackets(sx, sy, sw, 24, 5, C.red)
    lg.setFont(F.s); col(C.white)
    lg.printf("MOTHERSHIP // HULL " .. math.ceil(boss.hp / boss.max * 100) .. "% // " .. tag .. "  >> TARGET", sx, sy + 4, sw, "center")
    H.bar(sx + 10, sy + 20, sw - 20, 2, boss.hp / boss.max, C.red)
    H.addHit(sx, sy, sw, 24, function() G.tacSel = {kind = "enemy", uid = boss.uid}; FX.play("tick", 1.3) end)
  elseif not S.bossDown and (S.alert or 0) >= 0.6 then
    -- pre-warning so the spawn is something to look forward to
    local frac = S.alert
    col(C.orange, 0.15); lg.rectangle("fill", sx, sy, sw, 24)
    H.brackets(sx, sy, sw, 24, 5, C.orange, 0.7)
    lg.setFont(F.s); col(C.orange)
    lg.printf(string.format("MOTHERSHIP INBOUND  //  SCAV ALERT %d%%", frac * 100), sx, sy + 4, sw, "center")
    H.bar(sx + 10, sy + 20, sw - 20, 2, frac, C.orange)
  end
end

----------------------------------------------------------------------
-- right column: target feed, actions, loot log
----------------------------------------------------------------------
local function targetFeed()
  local S = G.S
  local F = H.fonts
  local x, y, w, h = RX, 58, RW, 206
  local cx, cy = x + w / 2, y + h / 2 + 4
  col(C.panel, 0.8); lg.rectangle("fill", x, y, w, h)
  -- the big ( ) brackets and reticle frame a target; drone diagnostics use the full width instead
  local droneView = G.tacSel and G.tacSel.kind == "drone"
  if not droneView then
    col(C.white, 0.9); lg.setLineWidth(2)
    lg.arc("line", "open", cx + 14, cy, 88, math.pi * 0.76, math.pi * 1.24, 20)
    lg.arc("line", "open", cx - 14, cy, 88, -math.pi * 0.24, math.pi * 0.24, 20)
    lg.setLineWidth(1)
  end
  col(C.white, 0.7)
  lg.line(x + 22, y + 20, x + w - 22, y + 20)
  lg.line(x + 22, y + h - 14, x + w - 22, y + h - 14)
  col(C.teal, 0.8); lg.rectangle("fill", cx - 52, y + 6, 70, 16)
  lg.setFont(F.xs); col(C.white); lg.printf("TARGET > FEED", cx - 52, y + 8, 70, "center")
  col(C.red); lg.rectangle("fill", cx + 20, y + 6, 16, 16)
  col(C.white); lg.printf(tostring(#G.enemies), cx + 20, y + 8, 16, "center")
  -- reticle corners
  local r = 46
  if not droneView then
    col(C.white, 0.7)
    lg.line(cx - r, cy - r + 10, cx - r, cy - r, cx - r + 10, cy - r)
    lg.line(cx + r - 10, cy - r, cx + r, cy - r, cx + r, cy - r + 10)
    lg.line(cx - r, cy + r - 10, cx - r, cy + r, cx - r + 10, cy + r)
    lg.line(cx + r - 10, cy + r, cx + r, cy + r, cx + r, cy + r - 10)
  end

  local sel = G.tacSel
  local e = sel and sel.kind == "enemy" and G.findEnemy(sel.uid)
  if sel and sel.kind == "enemy" and not e then G.tacSel = nil; sel = nil end
  if e then
    local shake = e.flash * 3
    local ox, oy = H.rnd(-shake, shake), H.rnd(-shake, shake)
    if e.def.boss or e.def.id == "ELITE" then emblem(cx + ox, cy + oy - 4, e.def.boss and 26 or 18, enemyColor(e), 1, true)
    else
      local s = 14
      local ec = enemyColor(e)
      col(ec, 0.3); lg.rectangle("fill", cx - s + ox, cy - s + oy, s * 2, s * 2)
      col(ec); lg.rectangle("line", cx - s + ox, cy - s + oy, s * 2, s * 2)
    end
    col(C.white, 0.6); lg.line(cx - 60, cy + 30, cx - 10, cy + 30); lg.line(cx + 10, cy + 30, cx + 60, cy + 30)
    lg.setFont(F.s); col(enemyColor(e)); lg.printf("SCAV " .. e.def.id .. "  //  " .. e.code, x, y + 26, w, "center")
    H.segbar(x + 40, y + h - 46, w - 80, 6, clamp(e.hp / e.max, 0, 1), 20, C.red)
    H.label("HULL " .. fmt(math.max(0, e.hp)) .. " / " .. fmt(e.max) .. "   DPS " .. fmt(e.dps), x + 40, y + h - 36, C.white)
    H.label("LOOT CLASS " .. D.LOOT[e.def.tier].name .. "+  x" .. e.def.crates, x + 40, y + h - 26, C[D.LOOT[e.def.tier].col])
  elseif sel and sel.kind == "drone" then
    local d
    for _, x2 in ipairs(S.drones) do if x2.id == sel.id then d = x2 end end
    if d then
      -- drone diagnostics: schematic in a scanning ring, status bars, position data
      local rc = C[D.RARITY[d.r].col]
      lg.setFont(F.s); col(rc)
      lg.printf(G.droneLabel(d) .. "  //  " .. D.RARITY[d.r].name .. " MK" .. d.mk .. " LV" .. d.lvl, x, y + 26, w, "center")
      local sx, sy = x + 66, cy + 4
      col(rc, 0.25); lg.circle("line", sx, sy, 44, 40)
      col(rc, 0.7)
      for k = 0, 11 do
        local a = G.time * 0.8 + k / 12 * TAU
        lg.arc("line", "open", sx, sy, 38, a, a + 0.25, 4)
      end
      for k = 0, 5 do
        local a = -G.time * 0.5 + k / 6 * TAU
        lg.line(sx + math.cos(a) * 44, sy + math.sin(a) * 44, sx + math.cos(a) * 50, sy + math.sin(a) * 50)
      end
      H.droneIcon(sx, sy - 4, 1.15, rc)
      -- status bars
      local bx, by = x + 128, y + 52
      local maxHp = G.droneMaxHp(d)
      local bars = {
        {"HULL", math.max(0, d.hp or 0) / maxHp, (d.hp or 0) < maxHp * 0.35 and C.red or C.line},
        {"POWER", math.min(1, G.dronePower(d) / math.max(1, G.fleetPower) * 3), C.white},
        {"SPEED", math.min(1, G.droneSpeed(d) / 4), C.orange},
      }
      for k, b in ipairs(bars) do
        H.label(b[1], bx, by + (k - 1) * 22, C.dim)
        H.segbar(bx, by + (k - 1) * 22 + 12, w - 140, 5, b[2], 10, b[3])
      end
      -- position data: drone relative to the tower
      local pcx, pcy = x + w - 30, y + h - 32
      col(C.line, 0.3)
      for r = 6, 18, 6 do lg.circle("line", pcx, pcy, r, 20) end
      lg.line(pcx - 20, pcy, pcx + 20, pcy); lg.line(pcx, pcy - 20, pcx, pcy + 20)
      local ddx, ddy = (d.px - G.TX) / 12, (d.py - G.TY) / 8
      col(rc); lg.circle("fill", pcx + clamp(ddx, -1, 1) * 18, pcy + clamp(ddy, -1, 1) * 18, 2.5, 8)
      H.label("POS " .. G.cellName(G.idx(clamp(math.floor(d.px + 0.5), 1, G.MW), clamp(math.floor(d.py + 0.5), 1, G.MH))),
        x + 10, y + h - 22, C.dim)
      H.label(H.fit(F.xs, table.concat(d.traits, " + "), w - 140), bx, by + 68, C.orange)
      H.label(H.fit(F.xs, G.droneStatus(d) .. "  //  DPS " .. fmt(G.droneDps(d)), w - 140), bx, by + 82, C.white)
    else
      G.tacSel = nil
    end
  elseif sel and sel.kind == "cell" then
    local i = sel.i
    local st, land = S.map.cells[i], G.land[i]
    lg.setFont(F.l); col(C.white); lg.printf("SECTOR " .. G.cellName(i), x, cy - 30, w, "center")
    local status, sc
    if i == G.TIDX then status, sc = "TOWER 07 // HOME", C.white
    elseif st == 0 then status, sc = "NO DATA // UNSCANNED", C.dim
    elseif not land then status, sc = "OCEAN // NO TARGET", C.line
    elseif st == 2 then status, sc = "SECURED", C.line
    elseif st == 3 then status, sc = "DRONE EN ROUTE", C.orange
    elseif G.adjClaimed(i) then status, sc = "HOSTILE // IN RANGE", C.red
    else status, sc = "HOSTILE // OUT OF RANGE", C.red end
    lg.setFont(F.s); col(sc); lg.printf(status, x, cy, w, "center")
    if land and st ~= 0 and i ~= G.TIDX then
      local loot = G.cellLoot(i)
      H.label("THREAT " .. fmt(G.threat(i)) .. "   ETA " .. H.fmtTime(G.missionTime(i)) ..
        "   " .. (st == 2 and "LOOTED" or (loot and "ANOMALOUS" or "NO SIGNATURE")), x + 30, y + h - 34, loot and C.orange or C.dim)
    end
  else
    local blink = math.floor(G.time * 2) % 2 == 0
    col(C.white, 0.6); lg.line(cx - 40, cy, cx + 40, cy); lg.line(cx, cy - 30, cx, cy + 30)
    lg.setFont(F.s); col(C.dim, blink and 1 or 0.5); lg.printf("NO TARGET // CLICK A CONTACT", x, y + 30, w, "center")
  end
  local t = os.date("*t")
  local stamp = string.format("%02d:%02d:%02d:%02d", t.hour, t.min, t.sec, math.floor((G.time * 30) % 30))
  col(C.panel); lg.rectangle("fill", cx - 40, y + h - 8, 80, 16)
  col(C.line, 0.6); lg.rectangle("line", cx - 40, y + h - 8, 80, 16)
  lg.setFont(F.xs); col(C.white); lg.printf(stamp, cx - 40, y + h - 6, 80, "center")
end

local function rightColumn()
  local S = G.S
  local F = H.fonts
  targetFeed()
  local y = 272
  local sel = G.tacSel
  local e = sel and sel.kind == "enemy" and G.findEnemy(sel.uid)
  if e then
    H.button(RX, y, 134, 30, "ENGAGE BEST", true, function() G.engage(e) end, C.orange, F.xs)
    H.button(RX + 142, y, 134, 30, "ALL DRONES", true, function() G.engage(e, true) end, C.red, F.xs)
  elseif sel and sel.kind == "cell" and G.claimable(sel.i) then
    local d = G.bestDroneFor(sel.i)
    H.button(RX, y, RW, 30, d and ("DEPLOY DRONE " .. d.id .. " // CLAIM " .. G.cellName(sel.i)) or ("NEED IDLE DRONE PWR " .. fmt(G.threat(sel.i)) .. "+"),
      d ~= nil, function() if G.deploy(sel.i) then FX.play("signal", 1.4, 0.5) end end, C.orange, F.xs)
  else
    H.label("Click scavs to fire orbital strikes. Click crates to loot.", RX, y + 2, C.dim)
    H.label("Click a sector twice to deploy a claim drone.", RX, y + 16, C.dim)
  end
  y = y + 38
  -- OFF / ON indicator pairs (from the field consoles)
  local function onoff(px, label, on, fn)
    H.label(label, px, y, C.dim)
    local ofx, onx, by = px, px + 66, y + 13
    local hov = H.mouseIn(px, by, 130, 20)
    col(on and C.faint or C.red, on and 0.5 or 0.9); lg.rectangle("fill", ofx, by + 5, 10, 10)
    lg.setFont(F.s); col(on and C.dim or C.white); lg.print("OFF", ofx + 15, by + 1)
    col(on and C.line or C.faint, on and 0.95 or 0.5); lg.rectangle("fill", onx, by + 5, 10, 10)
    col(on and C.white or C.dim); lg.print("ON", onx + 15, by + 1)
    if hov then H.brackets(px - 4, by - 2, 130, 24, 4, C.white, 0.6) end
    H.addHit(px - 4, by - 2, 130, 24, fn)
  end
  onoff(RX, "AUTO-HUNT", S.autoHunt, function() S.autoHunt = not S.autoHunt; FX.play("tick", 1.3) end)
  onoff(RX + 142, "AUTO-CLAIM", S.autoClaim, function() S.autoClaim = not S.autoClaim; FX.play("tick", 1.3) end)

  -- sub-tabbed instrument panel
  y = y + 44
  local tabs = {{"log", "SALVAGE LOG"}, {"weather", "WEATHER"}, {"tet", "TET UPLINK"}}
  local tw = RW / #tabs
  G.mapPanel = G.mapPanel or "log"
  for k, t in ipairs(tabs) do
    local tx = RX + (k - 1) * tw
    local on = G.mapPanel == t[1]
    local hov = H.mouseIn(tx, y, tw - 4, 22)
    local alert = (t[1] == "tet" and G.tetReady()) or (t[1] == "weather" and G.weather.def.id ~= "CLEAR")
    col(C.line, on and 0.25 or (hov and 0.1 or 0.03)); lg.rectangle("fill", tx, y, tw - 4, 22)
    if on then col(C.white); lg.rectangle("fill", tx, y + 20, tw - 4, 2) end
    lg.setFont(F.xs); col(on and C.white or C.dim); lg.printf(t[2], tx, y + 5, tw - 4, "center")
    if alert and math.floor(G.time * 3) % 2 == 0 then col(t[1] == "tet" and C.white or C.orange); lg.rectangle("fill", tx + tw - 12, y + 2, 5, 5) end
    H.addHit(tx, y, tw - 4, 22, function() G.mapPanel = t[1]; FX.play("tick", 1.2) end)
  end
  local py, ph = y + 26, 164
  H.brackets(RX, py, RW, ph, 6, C.line, 0.6)
  if G.mapPanel == "log" then
    H.label("LOOT LUCK +" .. math.floor(G.luck * 100) .. "%  STRIKE CRIT " .. math.floor(G.critChance * 100) .. "%", RX + 8, py + 6, C.orange)
    for k, f in ipairs(G.lootFeed) do
      if k > 9 then break end
      local age = G.time - f.t
      local a = clamp(1 - (age - 30) / 60, 0.35, 1)
      lg.setFont(F.xs); col(f.c, a)
      lg.print(H.fit(F.xs, f.text, RW - 16), RX + 8, py + 8 + k * 16)
    end
  elseif G.mapPanel == "weather" then
    -- WIND SYSTEM: concentric half-arcs + heading needle
    local w = G.weather
    local wc = w.def.id == "STORM" and C.red or (w.def.id == "CLEAR" and C.line or C.orange)
    H.label("WIND SYSTEM", RX + 8, py + 6, C.dim)
    local cx, cy = RX + 70, py + 104
    for r = 1, 4 do
      col(wc, 0.15 + r * 0.12)
      lg.setLineWidth(r == 4 and 2 or 1)
      lg.arc("line", "open", cx, cy, 14 + r * 12, math.pi, TAU, 24)
    end
    lg.setLineWidth(1)
    col(C.white)
    local a = math.pi + (math.sin(w.wind) * 0.5 + 0.5) * math.pi
    lg.line(cx, cy, cx + math.cos(a) * 60, cy + math.sin(a) * 60)
    lg.circle("fill", cx, cy, 3, 8)
    col(wc, 0.5); lg.line(cx - 66, cy, cx + 66, cy)
    lg.setFont(F.l); col(wc); lg.print(w.def.id, RX + 150, py + 24)
    H.label(string.format("WIND %d KT  //  HDG %03d", w.windSpeed, math.floor(math.deg(a - math.pi)) % 360), RX + 150, py + 52, C.white)
    H.richf(w.def.desc, RX + 150, py + 70, RW - 160, "left", C.line, 1, F.xs)
    H.label("NEXT FRONT IN " .. H.fmtTime(w.t), RX + 150, py + ph - 22, C.dim)
    H.segbar(RX + 8, py + ph - 10, RW - 16, 3, w.t / w.dur, 20, wc)
  else
    -- TET SYSTEM: orbit wheel showing charge
    local ch = G.S.tetCharge or 0
    local ready = G.tetReady()
    H.label("TET SYSTEM // ORBITAL UPLINK", RX + 8, py + 6, C.dim)
    local cx, cy = RX + 66, py + 92
    col(C.line, 0.2); lg.circle("line", cx, cy, 46, 48)
    lg.setLineWidth(10)
    col(C.faint, 0.6); lg.arc("line", "open", cx, cy, 36, -math.pi / 2, TAU - math.pi / 2, 48)
    col(ready and C.white or C.line, ready and (0.7 + 0.3 * math.sin(G.time * 8)) or 0.9)
    lg.arc("line", "open", cx, cy, 36, -math.pi / 2, -math.pi / 2 + ch * TAU, 48)
    lg.setLineWidth(1)
    -- the station orbiting
    local oa = G.time * 0.6
    col(C.white); lg.polygon("fill", cx + math.cos(oa) * 52, cy + math.sin(oa) * 52 - 4,
      cx + math.cos(oa) * 52 + 4, cy + math.sin(oa) * 52 + 3, cx + math.cos(oa) * 52 - 4, cy + math.sin(oa) * 52 + 3)
    lg.setFont(F.m); col(C.white); lg.printf(math.floor(ch * 100) .. "%", cx - 30, cy - 9, 60, "center")
    -- VELOCITY VECTOR fan (decorative: aim toward the target)
    local t = G.tetTarget()
    local vx, vy = RX + 200, py + 78
    col(C.line, 0.25)
    for k = -4, 4 do
      local a = -math.pi / 2 + k * 0.12
      lg.line(vx, vy + 22, vx + math.cos(a) * 40, vy + 22 + math.sin(a) * 40)
    end
    col(t and C.red or C.dim); lg.polygon("line", vx - 13, vy - 12, vx + 13, vy - 12, vx, vy + 22)
    H.label(t and ("TARGET " .. t.def.id) or "NO TARGET", RX + 150, py + 24, t and C.red or C.dim)
    H.label("RADIUS 3 SECTORS", RX + 150, py + 38, C.dim)
    H.button(RX + 130, py + ph - 42, RW - 138, 34, ready and "FIRE TET STRIKE" or ("CHARGING " .. math.floor(ch * 100) .. "%"),
      ready and t ~= nil, G.tetStrike, C.white, F.s, nil, ready and t ~= nil)
  end

  -- crates + zone advance
  y = 590
  if S.bossDown then
    H.button(RX, y - 38, RW, 32, "ADVANCE TO ZONE " .. (S.zone + 1) .. " // " .. D.zoneName(S.zone + 1),
      true, G.requestAdvance, C.gold, F.xs, nil, true)
  end
  local n = #S.crateList
  H.label("CRATES", RX, y)
  lg.setFont(F.l); col(n > 0 and C.orange or C.dim); lg.print(tostring(n), RX, y + 12)
  if S.pupg.tractor then H.label("AUTO", RX + 14 + F.l:getWidth(tostring(n)), y + 22, C.line) end
  H.button(RX + 100, y + 2, RW - 100, 40, "OPEN ALL CRATES", n > 0, G.openAllCrates, C.orange, F.s, nil, n > 0)
end

----------------------------------------------------------------------
-- bottom: quad readouts + mission day
----------------------------------------------------------------------
local function wave(x, y, w, h, values, c)
  local maxv = 1
  for _, v in ipairs(values) do if v > maxv then maxv = v end end
  col(c, 0.85)
  local pts = {}
  for k, v in ipairs(values) do
    pts[#pts + 1] = x + (k - 1) / math.max(1, #values - 1) * w
    pts[#pts + 1] = y + h - v / maxv * h
  end
  if #pts >= 4 then lg.line(pts) end
end

local function bottomStrip()
  local S = G.S
  local F = H.fonts
  local x0, y, qw, qh = MX0, 578, 174, 54
  local quads = {"QUAD Z1 // ZONE", "QUAD K7 // KILLS", "QUAD L4 // LOOT", "QUAD F2 // FLEET"}
  for k, q in ipairs(quads) do
    local x = x0 + (k - 1) * (qw + 8)
    col(C.panel, 0.8); lg.rectangle("fill", x, y, qw, qh)
    col(C.line, 0.3); lg.rectangle("line", x, y, qw, qh)
    H.label(q, x + 6, y + 4)
  end
  -- zone
  local frac = G.landCount > 0 and G.claimed / G.landCount or 0
  local alert = math.max(0, S.alert or 0)
  lg.setFont(F.m); col(alert >= 0.75 and C.red or C.white); lg.print(string.format("%d%%", alert * 100), x0 + 6, y + 18)
  H.label(string.format("LAND %d%%", frac * 100), x0 + qw - 60, y + 4, C.dim)
  local bossTxt, bc = "MOTHERSHIP AT 100%", C.dim
  for _, e in ipairs(G.enemies) do if e.def.boss then bossTxt, bc = "MOTHERSHIP ACTIVE", C.red end end
  if S.bossDown then bossTxt, bc = "ZONE CLEARED", C.gold end
  H.label(bossTxt, x0 + 60, y + 22, bc)
  H.segbar(x0 + 6, y + 44, qw - 12, 6, alert, 20, alert >= 0.75 and C.red or C.orange)
  -- kills
  local x = x0 + qw + 8
  lg.setFont(F.m); col(C.white); lg.print(fmt(S.kills), x + 6, y + 18)
  wave(x + 70, y + 18, qw - 80, 36, G.killHist, C.line)
  -- loot
  x = x0 + (qw + 8) * 2
  local counts = {0, 0, 0, 0, 0, 0, 0}
  for _, c in ipairs(S.crateList) do counts[c.r] = counts[c.r] + 1 end
  for _, m in ipairs(S.modules) do counts[m.r] = counts[m.r] + 1 end
  local maxc = 1
  for _, v in ipairs(counts) do if v > maxc then maxc = v end end
  for k = 1, #D.LOOT do
    local bh = counts[k] / maxc * 34
    col(C[D.LOOT[k].col], 0.9); lg.rectangle("fill", x + 8 + (k - 1) * 12, y + 54 - bh, 9, math.max(1, bh))
  end
  H.label("OPENED " .. fmt(S.crates), x + 90, y + 18, C.white)
  H.label("LEGEND " .. S.legendary, x + 90, y + 32, C.red)
  H.label("MYTHIC " .. S.mythic, x + 90, y + 46, C.gold)
  -- fleet
  x = x0 + (qw + 8) * 3
  local hunting, down = 0, 0
  for _, d in ipairs(S.drones) do
    if d.hunt then hunting = hunting + 1 end
    if G.isDown(d) then down = down + 1 end
  end
  lg.setFont(F.m); col(C.white); lg.print(fmt(G.fleetPower), x + 6, y + 18)
  H.label("PWR", x + 6, y + 40)
  H.label("HUNTING " .. hunting, x + 80, y + 18, C.orange)
  H.label("CLAIMING " .. (#S.drones - G.idleCount() - hunting - down), x + 80, y + 32, C.white)
  H.label("MISSING " .. down, x + 80, y + 46, down > 0 and C.red or C.dim)
end

function Tac.draw()
  topStrip()
  fleetList()
  drawMap()
  rightColumn()
  bottomStrip()
end

-- used by main for wheel scrolling of the fleet list
function Tac.overFleet(x, y) return x >= 16 and x <= 244 and y >= 120 and y <= 566 end

return Tac