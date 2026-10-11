-- HANGAR: fabrication banner (gacha), drone roster, drone detail + module vault.
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

G.hangarSel = nil
G.drag = nil          -- {id, sx, sy, active} while dragging a roster card
Sc.cards = {}         -- roster card rects of the last frame (drop targets)
G.salvageMode = false

local function selected()
  local S = G.S
  for k, d in ipairs(S.drones) do if d.id == G.hangarSel then return d, k end end
  if S.drones[1] then G.hangarSel = S.drones[1].id return S.drones[1], 1 end
end

----------------------------------------------------------------------
local function banner()
  local S = G.S
  local Fo = H.fonts
  local x, y, w = 24, 100, 320
  -- art
  local h = 226
  col(C.panel, 0.95); lg.rectangle("fill", x, y, w, h)
  lg.push("all")
  lg.intersectScissor(x, y, w, h)
  lg.setBlendMode("add")
  for k = 0, 11 do
    local a = G.time * 0.15 + k / 12 * TAU
    col(C.line, 0.05)
    lg.polygon("fill", x + w / 2, y + 96, x + w / 2 + math.cos(a - 0.1) * 300, y + 96 + math.sin(a - 0.1) * 300,
      x + w / 2 + math.cos(a + 0.1) * 300, y + 96 + math.sin(a + 0.1) * 300)
  end
  lg.pop()
  H.hatch(x, y, w, h, C.line, 0.05, 8)
  H.brackets(x, y, w, h, 12, C.line)
  H.droneIcon(x + w / 2, y + 92, 2.6, C.white)
  lg.setFont(Fo.dxl); col(C.white); lg.printf("FABRICATION", x, y + 150, w, "center")
  lg.setFont(Fo.s); col(C.orange); lg.printf("EVERY BATCH: PICK 1 OF 3", x, y + 186, w, "center")
  if G.eventActive("FRENZY") then
    col(C.white, 0.9); lg.rectangle("fill", x, y + h - 20, w, 20)
    lg.setFont(Fo.xs); col(C.bg); lg.printf("FAB FRENZY ACTIVE // -50% COST", x, y + h - 17, w, "center")
  end
  -- odds
  y = y + h + 10
  local o = G.odds()
  local p = {o[1]}
  for k = 2, #o do p[k] = o[k] - o[k - 1] end
  p[#o + 1] = 1 - o[#o]
  for k, r in ipairs(D.RARITY) do
    local yy = y + (k - 1) * 15
    col(C[r.col]); lg.rectangle("fill", x + 4, yy + 3, 8, 8)
    H.label(r.name, x + 20, yy, C[r.col])
    H.label(p[k] and string.format("%.1f%% PER CARD", p[k] * 100) or "DROP ONLY // BEST CRATES", x + 100, yy, p[k] and C.dim or C.holo)
    local owned = 0
    for _, d in ipairs(S.drones) do if d.r == k then owned = owned + 1 end end
    H.label("OWN " .. owned, x + 262, yy, owned > 0 and C.white or C.faint)
  end
  -- pity
  y = y + 92
  local pe, pp = G.pityCaps()
  H.label("ELITE+ GUARANTEED IN " .. math.max(1, pe - S.pity), x + 4, y, C.orange)
  H.segbar(x + 4, y + 14, w - 8, 5, S.pity / pe, pe, C.orange)
  H.label("PROTO+ GUARANTEED IN " .. math.max(1, pp - S.pityP), x + 4, y + 26, C.red)
  H.segbar(x + 4, y + 40, w - 8, 5, S.pityP / pp, 25, C.red)
  -- actions
  y = y + 56
  local fc = G.fabCost()
  local space = #S.drones + #G.choiceQueue < G.bayCap()
  H.button(x, y, w, 50, space and ("FABRICATE // " .. fc .. " H2O") or "BAY FULL // SCRAP A DRONE", space and S.hydro >= fc,
    function() G.fabricate(1) end, C.line, Fo.m, nil, true)
  H.button(x, y + 56, w / 2 - 4, 36, "x5 // " .. fmt(fc * 5) .. "+ H2O", space and S.hydro >= fc * 2,
    function() G.fabricate(5) end, C.line, Fo.xs)
  H.button(x + w / 2 + 4, y + 56, w / 2 - 4, 36, "USE TOKEN (" .. S.tokens .. ")", space and S.tokens > 0,
    function() G.fabricate(1, true) end, C.orange, Fo.xs, nil, S.tokens > 0)
  -- mass fabrication (the LOOT FIESTA screen): x10-x100 pulls, auto-pick, fusion cascade
  local fu, need = G.fiestaUnlocked()
  if fu then col(C.gold, 0.08 + 0.1 * (0.5 + 0.5 * math.sin(G.time * 4))); lg.rectangle("fill", x - 3, y + 95, w + 6, 50) end
  H.button(x, y + 98, w, 44, fu and "MASS FABRICATE  //  x10 - x100" or ("MASS FABRICATE  //  " .. S.fabsTotal .. " / " .. need .. " FABS"),
    fu, G.openFiesta, C.gold, Fo.s, nil, fu)
  if H.mouseIn(x, y + 98, w, 44) then H.setTip("MASS FABRICATE", "Opens the LOOT FIESTA: fabricate 10 to 100 drones at once with free bonus pulls, keep the best of every 3, then auto-fuse the rest.") end
end

----------------------------------------------------------------------
local function roster()
  local S = G.S
  local Fo = H.fonts
  local x, w = 360, 500
  local top, bot = 100, 630
  H.label("ROSTER // " .. #S.drones .. " / " .. G.bayCap() .. "  //  IDLE " .. G.idleCount(), x, 82, C.white)
  H.label("DRAG ONTO SAME RARITY TO COMBINE", x + w - 200, 82, C.orange, 0.8)
  Sc.cards = {}
  H.scrollRegion(x, top, w, bot - top, "roster")
  lg.setScissor(x - 2, top, w + 4, bot - top)
  local cols, gap = 4, 8
  local cw, ch = (w - (cols - 1) * gap) / cols, 116
  local y0 = top - G.scroll.roster
  local cap = G.bayCap()
  local sel = selected()
  local clip = {top, bot}
  for k = 1, math.max(cap, #S.drones) do -- a PRISM drop can overfill the bay; never hide it
    local c, r = (k - 1) % cols, math.floor((k - 1) / cols)
    local cx, cy = x + c * (cw + gap), y0 + r * (ch + gap)
    local d = S.drones[k]
    if cy + ch >= top and cy <= bot then
      if d then
        local rr = D.RARITY[d.r]
        local rc = C[rr.col]
        local on = d == sel
        local hov = H.mouseIn(cx, cy, cw, ch, clip)
        col(C.panel, 0.95); lg.rectangle("fill", cx, cy, cw, ch)
        if on then col(rc, 0.14); lg.rectangle("fill", cx, cy, cw, ch) end
        if d.r == #D.RARITY then H.holoFX(cx, cy, cw, ch, 0.8) end
        if hov then col(C.white, 0.05); lg.rectangle("fill", cx, cy, cw, ch) end
        -- rarity strip sits between the corner brackets
        if d.r >= 3 then H.hatch(cx + 10, cy + 2, cw - 20, 5, rc, 0.8, 4) else col(rc, 0.8); lg.rectangle("fill", cx + 10, cy + 2, cw - 20, 3) end
        H.brackets(cx, cy, cw, ch, 6, on and C.white or rc, on and 1 or 0.8)
        lg.setFont(Fo.l); col(C.white); lg.print(tostring(d.id), cx + 8, cy + 10)
        H.label(H.fit(Fo.xs, d.name or "", cw - 46), cx + 8, cy + 36, C.white)
        H.label(rr.name .. " MK" .. d.mk .. "  LV " .. d.lvl, cx + 8, cy + 50, rc)
        if cy + ch > top and cy < bot then Sc.cards[#Sc.cards + 1] = {x = cx, y = cy, w = cw, h = ch, id = d.id} end
        -- drop-target feedback while dragging
        local dg = G.drag and G.drag.active and G.findDrone(G.drag.id)
        if dg and dg.id == d.id then
          col(C.bg, 0.65); lg.rectangle("fill", cx, cy, cw, ch)
        elseif dg and hov then
          local ok = dg.r == d.r and G.canCombine(dg) and G.canCombine(d)
          col(ok and C.orange or C.red, 0.25); lg.rectangle("fill", cx, cy, cw, ch)
          H.brackets(cx - 3, cy - 3, cw + 6, ch + 6, 8, ok and C.orange or C.red)
          lg.setFont(Fo.s); col(ok and C.orange or C.red)
          lg.printf(ok and "COMBINE" or (dg.r ~= d.r and "SAME RARITY ONLY" or "BUSY / MAX"), cx, cy + ch / 2 - 8, cw, "center")
        end
        H.droneIcon(cx + cw - 26, cy + 26, 0.75, rc)
        if d.lock then I.draw("lock", cx + cw - 12, cy + 56, 5, C.gold) end
        local st = G.droneStatus(d)
        local sc = st == "MISSING" and C.red or (st == "HUNT" and C.orange or (st == "CLAIM" and C.white or C.line))
        col(sc, 0.8); lg.rectangle("line", cx + 8, cy + 70, cw - 16, 16)
        lg.setFont(Fo.xs); col(sc); lg.printf(st == "MISSING" and "MIA" or st, cx + 8, cy + 72, cw - 16, "center")
        for s = 1, rr.slots do
          local m = d.mods[s]
          col(m and C[D.LOOT[m.r].col] or C.faint)
          lg.rectangle(m and "fill" or "line", cx + 8 + (s - 1) * 12, cy + 96, 9, 9)
        end
        lg.setFont(Fo.xs); col(C.dim); lg.printf(fmt(G.dronePower(d)), cx, cy + 95, cw - 8, "right")
        H.addHit(cx, cy, cw, ch, function() G.hangarSel = d.id; FX.play("tick") end, clip)
      else
        col(C.faint, 0.3); lg.rectangle("line", cx + 0.5, cy + 0.5, cw - 1, ch - 1)
        H.droneIcon(cx + cw / 2, cy + ch / 2 - 6, 0.8, C.faint, 0.4)
        H.label("EMPTY", cx + cw / 2 - 16, cy + ch - 22, C.faint)
      end
    end
  end
  lg.setScissor()
  G.maxScroll.roster = math.max(0, math.ceil(math.max(cap, #S.drones) / cols) * (ch + gap) - (bot - top))
end

----------------------------------------------------------------------
local function detail()
  local S = G.S
  local Fo = H.fonts
  local x, y, w, h = 876, 100, 380, 272
  local d, k = selected()
  col(C.panel, 0.95); lg.rectangle("fill", x, y, w, h)
  if not d then
    H.brackets(x, y, w, h, 10, C.faint)
    lg.setFont(Fo.m); col(C.dim); lg.printf("NO DRONES YET", x, y + 100, w, "center")
    H.label("Fabricate your first drone with hydro from the rigs.", x + 40, y + 130, C.dim)
    return
  end
  local rr = D.RARITY[d.r]
  local rc = C[rr.col]
  H.brackets(x, y, w, h, 10, rc)
  if d.r >= 3 then H.hatch(x, y, w, h, rc, 0.05, 8) end
  if d.r == #D.RARITY then H.holoFX(x, y, w, h, 0.6) end
  H.droneIcon(x + 60, y + 60, 1.7, rc)
  lg.setFont(Fo.dxl); col(C.white); lg.print(tostring(d.id), x + 120, y + 8)
  lg.setFont(Fo.m); col(C.white); lg.print(H.fit(Fo.m, d.name or "", w - 270), x + 190, y + 16)
  H.button(x + w - 76, y + 10, 64, 22, d.lock and "LOCKED" or "LOCK", true, function() d.lock = not d.lock or nil; FX.play("tick", d.lock and 1.3 or 0.9) end,
    d.lock and C.gold or C.dim, Fo.xs)
  if H.mouseIn(x + w - 76, y + 10, 64, 22) then H.setTip("DRONE LOCK", "Locked drones are never auto-fused, used in a loot fiesta cascade or scrapped.") end
  lg.setFont(Fo.s); col(rc); lg.print(rr.name .. "  MK" .. d.mk .. "  LV " .. d.lvl, x + 120, y + 48)
  H.label("STATUS // " .. G.droneStatus(d), x + 120, y + 68, C.dim)
  -- stats
  local stats = {
    {"POWER", fmt(G.dronePower(d))}, {"DPS", fmt(G.droneDps(d))},
    {"HULL", fmt(G.droneMaxHp(d))}, {"SPEED", string.format("%.1f", G.droneSpeed(d))},
    {"DRONE YIELD", "+" .. math.floor(G.droneBonus(d) * 100 + 0.5) .. "%"}, {"CLAIM POWER", fmt(G.claimPower(d))},
  }
  for n, s in ipairs(stats) do
    local sx = x + 16 + ((n - 1) % 2) * 180
    local sy = y + 112 + math.floor((n - 1) / 2) * 16
    H.label(s[1], sx, sy, C.dim)
    lg.setFont(Fo.xs); col(C.white); lg.printf(s[2], sx, sy, 164, "right")
  end
  -- traits
  local ty = y + 163
  for _, tid in ipairs(d.traits) do
    local desc = ""
    for _, t in ipairs(D.TRAITS) do if t.id == tid then desc = t.desc end end
    H.label(tid, x + 16, ty, C.orange)
    H.label(desc, x + 110, ty, C.line)
    ty = ty + 12
  end
  -- module slots
  local sw = (w - 32 - (rr.slots - 1) * 6) / rr.slots
  for s = 1, rr.slots do
    local sx, sy = x + 16 + (s - 1) * (sw + 6), y + 202
    local m = d.mods[s]
    if m then
      local mc = C[D.LOOT[m.r].col]
      local hov = H.mouseIn(sx, sy, sw, 30)
      col(mc, hov and 0.25 or 0.12); lg.rectangle("fill", sx, sy, sw, 30)
      H.brackets(sx, sy, sw, 30, 4, mc)
      lg.setFont(Fo.xs); col(mc); lg.print(m.t, sx + 6, sy + 3)
      col(C.white); lg.print(H.fit(Fo.xs, G.modText(m), sw - 10), sx + 6, sy + 16)
      if hov then H.setTip(D.LOOT[m.r].name .. " " .. G.modDef(m.t).name:upper(), G.modText(m) .. "  //  click to unequip") end
      H.addHit(sx, sy, sw, 30, function() G.unequip(k, s) end)
    else
      col(C.faint, 0.6); lg.rectangle("line", sx + 0.5, sy + 0.5, sw - 1, 29)
      H.label(G.unlocked("vault") and "EMPTY SLOT" or "LOCKED", sx + 6, sy + 9, C.faint)
    end
  end
  -- actions
  local uc = G.droneUpCost(d)
  H.button(x + 16, y + h - 38, 150, 28, "UPGRADE // " .. fmt(uc) .. " P", S.parts >= uc, function() G.upgradeDrone(k) end,
    C.line, Fo.xs, nil, S.parts >= uc, true)
  local canC = G.canCombine(d)
  H.button(x + 172, y + h - 38, 86, 28, "COMBINE", canC, function() G.openCombine({d.id}) end, C.orange, Fo.xs)
  local conf = G.scrapConfirm and G.scrapConfirm.id == d.id
  H.button(x + 264, y + h - 38, 100, 28, d.lock and "LOCKED" or (conf and "CONFIRM?" or ("SCRAP +" .. D.RARITY[d.r].scrap * d.lvl .. "P")), not d.lock, function()
    if conf then G.scrapDrone(k) else G.scrapConfirm = {id = d.id, t = 3} end
  end, C.red, Fo.xs)
end

----------------------------------------------------------------------
local function vault()
  local S = G.S
  local Fo = H.fonts
  local x, y, w = 876, 384, 380
  local bot = 630
  if not G.unlocked("vault") then
    local _, need = G.unlocked("vault")
    col(C.panel, 0.8); lg.rectangle("fill", x, y, w, bot - y)
    H.hatch(x, y, w, bot - y, C.red, 0.1, 8)
    H.brackets(x, y, w, bot - y, 10, C.red, 0.6)
    I.draw("lock", x + w / 2, y + 100, 14, C.red)
    lg.setFont(Fo.m); col(C.red); lg.printf("MODULE VAULT // " .. need .. " LOGS", x, y + 130, w, "center")
    return
  end
  -- vault card: a summary of the inventory; everything else lives on the full VAULT screen
  local h = bot - y
  local myth = #G.altarMythics()
  local ready = myth >= G.ALTAR_COST
  local mc = C[D.LOOT[D.MYTHIC].col]
  local pulse = 0.5 + 0.5 * math.sin(G.time * 4)
  local hov = H.mouseIn(x, y, w, h)
  col(C.panel, 0.95); lg.rectangle("fill", x, y, w, h)
  if hov then col(C.line, 0.05); lg.rectangle("fill", x, y, w, h) end
  H.hatch(x, y, w, 28, C.line, 0.1, 6)
  H.brackets(x, y, w, h, 10, ready and mc or C.line, hov and 1 or 0.7)
  lg.setFont(Fo.m); col(C.white); lg.print("MODULE VAULT", x + 12, y + 5)
  lg.setFont(Fo.s); col(#S.modules >= G.vaultCap() and C.red or C.dim)
  lg.printf(#S.modules .. " / " .. G.vaultCap(), x, y + 7, w - 12, "right")
  -- rarity breakdown as one stacked bar
  local counts = {0, 0, 0, 0, 0, 0, 0}
  for _, m in ipairs(S.modules) do counts[m.r] = counts[m.r] + 1 end
  local by, bw = y + 40, w - 24
  col(C.faint, 0.3); lg.rectangle("fill", x + 12, by, bw, 8)
  local bx = x + 12
  for r = #D.LOOT, 1, -1 do
    if counts[r] > 0 then
      local seg = bw * counts[r] / G.vaultCap()
      col(C[D.LOOT[r].col]); lg.rectangle("fill", bx, by, seg - 1, 8)
      bx = bx + seg
    end
  end
  for r = 1, #D.LOOT do
    local lx = x + 12 + (r - 1) * (bw / #D.LOOT)
    col(C[D.LOOT[r].col]); lg.rectangle("fill", lx, by + 16, 6, 6)
    H.label(counts[r] .. " " .. D.LOOT[r].name:sub(1, 3), lx + 10, by + 13, counts[r] > 0 and C[D.LOOT[r].col] or C.faint)
  end
  -- best modules in storage
  local best = {}
  for _, m in ipairs(S.modules) do best[#best + 1] = m end
  table.sort(best, function(a, b) if a.r ~= b.r then return a.r > b.r end return G.modScore(a) > G.modScore(b) end)
  local cw = (w - 24 - 3 * 6) / 4
  for k = 1, 4 do
    local m = best[k]
    local cx, cy = x + 12 + (k - 1) * (cw + 6), y + 78
    if m then
      local c = C[D.LOOT[m.r].col]
      col(c, 0.08); lg.rectangle("fill", cx, cy, cw, 40)
      H.brackets(cx, cy, cw, 40, 4, c, 0.8)
      lg.setFont(Fo.s); col(C.white); lg.print(m.t, cx + 6, cy + 4)
      H.label(H.fit(Fo.xs, G.modText(m), cw - 10), cx + 6, cy + 22, c)
    else
      col(C.faint, 0.4); lg.rectangle("line", cx + 0.5, cy + 0.5, cw - 1, 39)
    end
  end
  -- autopilot status + altar progress
  H.label("AUTO-LOADOUT " .. (S.autoLoadout and "ON" or "OFF") .. "   //   AUTO-SALVAGE " .. G.autoSalvageLabel(), x + 12, y + 128,
    S.autoLoadout and C.line or C.dim)
  local ay = y + 150
  H.label("MYTHIC ALTAR", x + 12, ay, mc)
  for k = 1, G.ALTAR_COST do
    local on = k <= myth
    col(on and mc or C.faint, on and (ready and 0.6 + 0.4 * pulse or 1) or 0.5)
    lg.rectangle(on and "fill" or "line", x + 110 + (k - 1) * 15, ay + 1, 10, 10)
  end
  H.label(ready and "READY" or (math.min(myth, G.ALTAR_COST) .. "/" .. G.ALTAR_COST), x + 268, ay, ready and mc or C.dim)
  -- the one clear way in
  local bh = 44
  if ready then col(mc, 0.1 + 0.12 * pulse); lg.rectangle("fill", x + 8, bot - bh - 12, w - 16, bh + 8) end
  H.addHit(x, y, w, h - bh - 16, G.openVault)
  local fr = G.forgeReady()
  H.button(x + 12, bot - bh - 8, w - 24, bh, ready and "OPEN VAULT  //  ALTAR READY" or (fr > 0 and ("OPEN VAULT  //  " .. fr .. " FORGES READY") or "OPEN VAULT"), true, G.openVault,
    ready and mc or C.line, Fo.m, nil, ready or fr > 0) -- filled only when there is something to collect
end

----------------------------------------------------------------------
-- drag & drop to combine
----------------------------------------------------------------------
local function cardAt(x, y)
  for _, r in ipairs(Sc.cards) do
    if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return r end
  end
end
function Sc.press(x, y)
  local r = cardAt(x, y)
  if r then G.drag = {id = r.id, sx = x, sy = y, active = false} end
end
function Sc.update()
  local g = G.drag
  if not g then return end
  if not love.mouse.isDown(1) then G.drag = nil return end
  local mx, my = V.mouse()
  if not g.active and (math.abs(mx - g.sx) > 8 or math.abs(my - g.sy) > 8) then g.active = true; FX.play("tick", 0.9) end
end
function Sc.release(x, y)
  local g = G.drag
  G.drag = nil
  if not g or not g.active then return end
  local r = cardAt(x, y)
  if not r or r.id == g.id then return end
  local a, b = G.findDrone(g.id), G.findDrone(r.id)
  if a and b and a.r == b.r and G.canCombine(a) and G.canCombine(b) then
    G.openCombine({b.id, a.id})
  else
    FX.play("err")
  end
end
local function ghost()
  local g = G.drag
  local d = g and g.active and G.findDrone(g.id)
  if not d then return end
  local mx, my = V.mouse()
  local rc = C[D.RARITY[d.r].col]
  local w, h = 130, 60
  col(C.panel, 0.92); lg.rectangle("fill", mx - w / 2, my - h / 2, w, h)
  H.brackets(mx - w / 2, my - h / 2, w, h, 6, rc)
  H.droneIcon(mx - 38, my, 0.6, rc)
  lg.setFont(H.fonts.s); col(C.white); lg.print(tostring(d.id), mx - 12, my - 20)
  H.label(H.fit(H.fonts.xs, d.name or "", 70), mx - 12, my, rc)
end

function Sc.draw()
  local Fo = H.fonts
  lg.setFont(Fo.d2); col(C.white); lg.print("HANGAR", 24, 58)
  H.button(360, 56, 230, 22, "AUTO-FUSE // " .. G.autoFuseLabel(), true, G.cycleAutoFuse,
    (G.S.autoFuse or 0) > 0 and C.gold or C.dim, Fo.xs)
  H.button(600, 56, 200, 22, "AUTO-UPGRADE // " .. (G.S.autoUpgrade and "ON" or "OFF"), true,
    function() G.S.autoUpgrade = not G.S.autoUpgrade; FX.play("tick", 1.2) end, G.S.autoUpgrade and C.line or C.dim, Fo.xs)
  if H.mouseIn(600, 56, 200, 22) then H.setTip("AUTO-UPGRADE", "Spends parts on the cheapest drone upgrade, a few times per second.") end
  banner()
  Sc.update()
  roster()
  detail()
  vault()
  ghost()
end

return Sc
