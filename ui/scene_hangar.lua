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
  lg.setFont(Fo.xl); col(C.white); lg.printf("FABRICATION", x, y + 150, w, "center")
  lg.setFont(Fo.s); col(C.orange); lg.printf("EVERY BATCH: PICK 1 OF 3", x, y + 186, w, "center")
  if G.eventActive("FRENZY") then
    col(C.white, 0.9); lg.rectangle("fill", x, y + h - 20, w, 20)
    lg.setFont(Fo.xs); col(C.bg); lg.printf("FAB FRENZY ACTIVE // -50% COST", x, y + h - 17, w, "center")
  end
  -- odds
  y = y + h + 10
  local o = G.odds()
  local p = {o[1], o[2] - o[1], o[3] - o[2], o[4] - o[3], 1 - o[4]}
  for k, r in ipairs(D.RARITY) do
    local yy = y + (k - 1) * 17
    col(C[r.col]); lg.rectangle("fill", x + 4, yy + 3, 8, 8)
    H.label(r.name, x + 20, yy, C[r.col])
    H.label(string.format("%.1f%% PER CARD", p[k] * 100), x + 100, yy, C.dim)
    local owned = 0
    for _, d in ipairs(S.drones) do if d.r == k then owned = owned + 1 end end
    H.label("OWN " .. owned, x + 262, yy, owned > 0 and C.white or C.faint)
  end
  -- pity
  y = y + 92
  H.label("ELITE+ GUARANTEED IN " .. math.max(1, 10 - S.pity), x + 4, y, C.orange)
  H.segbar(x + 4, y + 14, w - 8, 5, S.pity / 10, 10, C.orange)
  H.label("PROTO+ GUARANTEED IN " .. math.max(1, 50 - S.pityP), x + 4, y + 26, C.red)
  H.segbar(x + 4, y + 40, w - 8, 5, S.pityP / 50, 25, C.red)
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
end

----------------------------------------------------------------------
local function roster()
  local S = G.S
  local Fo = H.fonts
  local x, w = 360, 500
  local top, bot = 100, 630
  H.label("ROSTER // " .. #S.drones .. " / " .. G.bayCap() .. "  //  IDLE " .. G.idleCount(), x, 82, C.white)
  H.scrollRegion(x, top, w, bot - top, "roster")
  lg.setScissor(x - 2, top, w + 4, bot - top)
  local cols, gap = 4, 8
  local cw, ch = (w - (cols - 1) * gap) / cols, 116
  local y0 = top - G.scroll.roster
  local cap = G.bayCap()
  local sel = selected()
  local clip = {top, bot}
  for k = 1, cap do
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
        if hov then col(C.white, 0.05); lg.rectangle("fill", cx, cy, cw, ch) end
        -- rarity strip sits between the corner brackets
        if d.r >= 3 then H.hatch(cx + 10, cy + 2, cw - 20, 5, rc, 0.8, 4) else col(rc, 0.8); lg.rectangle("fill", cx + 10, cy + 2, cw - 20, 3) end
        H.brackets(cx, cy, cw, ch, 6, on and C.white or rc, on and 1 or 0.8)
        lg.setFont(Fo.l); col(C.white); lg.print(tostring(d.id), cx + 8, cy + 10)
        H.label(rr.name .. " MK" .. d.mk, cx + 8, cy + 36, rc)
        H.label("LV " .. d.lvl, cx + 8, cy + 50, C.dim)
        H.droneIcon(cx + cw - 26, cy + 26, 0.75, rc)
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
  G.maxScroll.roster = math.max(0, math.ceil(cap / cols) * (ch + gap) - (bot - top))
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
  H.droneIcon(x + 60, y + 60, 1.7, rc)
  lg.setFont(Fo.xl); col(C.white); lg.print(tostring(d.id), x + 120, y + 12)
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
  local ty = y + 166
  for _, tid in ipairs(d.traits) do
    local desc = ""
    for _, t in ipairs(D.TRAITS) do if t.id == tid then desc = t.desc end end
    H.label(tid, x + 16, ty, C.orange)
    H.label(desc, x + 110, ty, C.line)
    ty = ty + 15
  end
  -- module slots
  local sw = (w - 32 - (rr.slots - 1) * 6) / rr.slots
  for s = 1, rr.slots do
    local sx, sy = x + 16 + (s - 1) * (sw + 6), y + 200
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
  H.button(x + 16, y + h - 38, 230, 28, "UPGRADE // " .. fmt(uc) .. " PARTS", S.parts >= uc, function() G.upgradeDrone(k) end,
    C.line, Fo.xs, nil, S.parts >= uc, true)
  local conf = G.scrapConfirm and G.scrapConfirm.id == d.id
  H.button(x + 254, y + h - 38, 110, 28, conf and "CONFIRM?" or ("SCRAP +" .. D.RARITY[d.r].scrap * d.lvl .. "P"), true, function()
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
  H.label("VAULT // " .. #S.modules .. " / " .. G.vaultCap(), x, y, C.white)
  H.button(x, y + 16, 120, 26, "AUTO-EQUIP", #S.drones > 0, G.autoEquip, C.line, Fo.xs, nil, #S.modules > 0)
  H.button(x + 126, y + 16, 124, 26, "SALVAGE <= RARE", #S.modules > 0, function() G.salvageBelow(3) end, C.dim, Fo.xs)
  H.button(x + 256, y + 16, 124, 26, G.salvageMode and "SALVAGE MODE ON" or "SALVAGE MODE", true,
    function() G.salvageMode = not G.salvageMode end, G.salvageMode and C.red or C.dim, Fo.xs)
  local top = y + 50
  H.scrollRegion(x, top, w, bot - top, "vault")
  lg.setScissor(x - 2, top, w + 4, bot - top)
  local order = {}
  for k = 1, #S.modules do order[k] = k end
  table.sort(order, function(a, b)
    local ma, mb = S.modules[a], S.modules[b]
    if ma.r ~= mb.r then return ma.r > mb.r end
    return G.modScore(ma) > G.modScore(mb)
  end)
  local cols, gap = 4, 6
  local cw, ch = (w - (cols - 1) * gap) / cols, 58
  local y0 = top - G.scroll.vault
  local clip = {top, bot}
  local _, selK = selected()
  for n, k in ipairs(order) do
    local m = S.modules[k]
    local c, r = (n - 1) % cols, math.floor((n - 1) / cols)
    local cx, cy = x + c * (cw + gap), y0 + r * (ch + gap)
    if cy + ch >= top and cy <= bot then
      local mc = C[D.LOOT[m.r].col]
      local hov = H.mouseIn(cx, cy, cw, ch, clip)
      col(C.panel, 0.95); lg.rectangle("fill", cx, cy, cw, ch)
      if hov then col(G.salvageMode and C.red or mc, 0.15); lg.rectangle("fill", cx, cy, cw, ch) end
      if m.r >= 4 then H.hatch(cx + 7, cy + 2, cw - 14, 4, mc, 0.8, 3) else col(mc, 0.8); lg.rectangle("fill", cx + 7, cy + 2, cw - 14, 2) end
      H.brackets(cx, cy, cw, ch, 4, mc, hov and 1 or 0.7)
      lg.setFont(Fo.m); col(C.white); lg.print(m.t, cx + 6, cy + 6)
      H.label("IL" .. m.ilvl, cx + cw - 26, cy + 8, C.dim)
      H.label(H.fit(Fo.xs, G.modText(m), cw - 10), cx + 6, cy + 28, mc)
      H.label(D.LOOT[m.r].name, cx + 6, cy + 41, C.dim)
      if hov then
        H.setTip(D.LOOT[m.r].name .. " " .. G.modDef(m.t).name:upper(), G.modText(m) .. "  //  ILVL " .. m.ilvl ..
          "  //  " .. (G.salvageMode and ("click to salvage +" .. G.modSalvage(m) .. " parts") or "click to equip on selected drone"))
      end
      H.addHit(cx, cy, cw, ch, function()
        for kk, mm in ipairs(S.modules) do
          if mm == m then
            if G.salvageMode then
              local p = G.salvageModule(kk)
              local mx, my = V.mouse()
              FX.floater(mx, my - 10, "+" .. p .. " PARTS", C.line)
            elseif selK then G.equipModule(kk, selK)
            else FX.play("err") end
            break
          end
        end
      end, clip)
    end
  end
  lg.setScissor()
  G.maxScroll.vault = math.max(0, math.ceil(#S.modules / cols) * (ch + gap) - (bot - top))
  if #S.modules == 0 then
    H.label("EMPTY // OPEN CRATES ON THE MAP TO FIND MODULES", x, top + 10, C.orange)
  end
end

function Sc.draw()
  local Fo = H.fonts
  lg.setFont(Fo.l); col(C.white); lg.print("HANGAR", 24, 62)
  banner()
  roster()
  detail()
  vault()
end

return Sc
