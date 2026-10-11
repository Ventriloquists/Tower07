-- MODULE VAULT: full inventory, filters, salvage tools, autopilot and the entrance to the Mythic Altar.
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local lg = V.lg
local C, col, fmt = H.C, H.col, H.fmt
local TAU = math.pi * 2
local Va = {}

-- the vault is a view of the HANGAR station (FLEET | VAULT), drawn in the content area, not a pop-up
local X0, Y0, W, HH = 24, 90, 1232, 540
local GX, GY, GW = X0 + 20, Y0 + 92, 800   -- module grid
local GB = Y0 + HH - 20
local PX, PW = X0 + 840, W - 860           -- right column
G.vaultOpen = false
G.vaultFilter, G.vaultSort = 0, "rarity"
local salvageArm -- two-click confirm for bulk salvage

function G.openVault()
  if not G.unlocked("vault") then FX.play("err") return end
  G.vaultOpen = true
  G.scroll.vaultfull = 0
  FX.play("unlock", 1.1)
end
local function close() G.vaultOpen = false; FX.play("tick", 0.8) end

local function shown()
  local S = G.S
  local list = {}
  for k, m in ipairs(S.modules) do
    if G.vaultFilter == 0 or m.r == G.vaultFilter then list[#list + 1] = {m = m, k = k} end
  end
  table.sort(list, function(a, b)
    local ma, mb = a.m, b.m
    if G.vaultSort == "type" and ma.t ~= mb.t then return ma.t < mb.t end
    if G.vaultSort ~= "score" and ma.r ~= mb.r then return ma.r > mb.r end
    return G.modScore(ma) > G.modScore(mb)
  end)
  return list
end

local function moduleCard(m, x, y, w, h, hov)
  local mc = C[D.LOOT[m.r].col]
  col(C.panel, 0.95); lg.rectangle("fill", x, y, w, h)
  if m.r == #D.LOOT then H.holoFX(x, y, w, h) end
  if hov then col(G.salvageMode and C.red or mc, 0.18); lg.rectangle("fill", x, y, w, h) end
  if m.r >= 4 then H.hatch(x + 7, y + 2, w - 14, 4, mc, 0.8, 3) else col(mc, 0.8); lg.rectangle("fill", x + 7, y + 2, w - 14, 2) end
  H.brackets(x, y, w, h, 4, mc, hov and 1 or 0.7)
  lg.setFont(H.fonts.m); col(C.white); lg.print(m.t, x + 6, y + 6)
  H.label("IL" .. m.ilvl, x + w - 26, y + 8, C.dim)
  H.label(H.fit(H.fonts.xs, G.modText(m), w - 10), x + 6, y + 28, mc)
  H.label(D.LOOT[m.r].name, x + 6, y + 41, C.dim)
end

local function altarPanel(y)
  local S, Fo = G.S, H.fonts
  local mc = C[D.LOOT[D.MYTHIC].col]
  local myth = #G.altarMythics()
  local ready = myth >= G.ALTAR_COST
  local h = 196
  local pulse = 0.5 + 0.5 * math.sin(G.time * 4)
  col(mc, ready and (0.08 + 0.06 * pulse) or 0.04); lg.rectangle("fill", PX, y, PW, h)
  H.hatch(PX, y, PW, 26, mc, 0.2, 6)
  H.brackets(PX, y, PW, h, 10, mc, ready and 1 or 0.6)
  lg.setFont(Fo.m); col(mc); lg.print("MYTHIC ALTAR", PX + 12, y + 4)
  -- mini ring of sockets
  local cx, cy, r = PX + 70, y + 92, 42
  col(mc, 0.3); lg.circle("line", cx, cy, r, 48)
  for k = 1, G.ALTAR_COST do
    local a = -math.pi / 2 + (k - 1) / G.ALTAR_COST * TAU + G.time * 0.15
    local on = k <= myth
    col(on and mc or C.faint, on and 1 or 0.5)
    lg.rectangle(on and "fill" or "line", cx + math.cos(a) * r - 5, cy + math.sin(a) * r - 5, 10, 10)
  end
  lg.setFont(Fo.l); col(ready and mc or C.dim); lg.printf(math.min(myth, G.ALTAR_COST) .. "/" .. G.ALTAR_COST, cx - 40, cy - 12, 80, "center")
  H.label(G.ALTAR_COST .. " MYTHIC MODULES", PX + 136, y + 50, C.white)
  H.label(">> 1 PERK POINT", PX + 136, y + 66, mc)
  H.label("every card ENHANCED+", PX + 136, y + 82, C.dim)
  H.label("MYTHICS IN VAULT " .. myth, PX + 136, y + 106, C.white)
  if (S.mythicRolls or 0) > 0 then H.label("BOOSTED PICKS WAITING " .. S.mythicRolls, PX + 136, y + 122, C.gold) end
  if ready then col(mc, 0.1 + 0.15 * pulse); lg.rectangle("fill", PX + 8, y + h - 52, PW - 16, 44) end
  H.button(PX + 12, y + h - 48, PW - 24, 36, ready and "OPEN ALTAR // READY" or "OPEN ALTAR", true, G.openAltar, mc, Fo.m, nil, ready)
end

G.vaultMode = "inventory"
function Va.tabs()
  local Fo = H.fonts
  local n = G.forgeReady()
  local tabs = {{"inventory", "INVENTORY"}, {"forge", n > 0 and ("FORGE // " .. n .. " READY") or "FORGE"}}
  local labels, sel = {}, 1
  for k, t in ipairs(tabs) do labels[k] = t[2]; if G.vaultMode == t[1] then sel = k end end
  H.segmented(X0 + W - 340, Y0 + 8, 326, 24, labels, sel, function(k) G.vaultMode = tabs[k][1]; FX.play("tick", 1.2) end,
    "vaulttabs", n > 0 and C.gold or C.line)
end

local function modChip(t, r, x, y, w, h)
  local c = C[D.LOOT[r].col]
  col(c, 0.15); lg.rectangle("fill", x, y, w, h)
  H.brackets(x, y, w, h, 4, c)
  lg.setFont(H.fonts.s); col(C.white); lg.printf(t, x, y + h / 2 - 8, w, "center")
end

function Va.forge()
  local S, Fo = G.S, H.fonts
  -- item level forge
  local y = Y0 + 50
  lg.setFont(Fo.m); col(C.white); lg.print("ITEM LEVEL FORGE", GX, y)
  H.label("3 OF THE SAME TYPE + RARITY + IL  >>  1 AT IL+1, KEEPS THE BEST ROLL", GX, y + 22, C.dim)
  local groups = G.forgeGroups()
  local ready = 0
  for _, g in ipairs(groups) do ready = ready + math.floor(#g.mods / G.FORGE_IL) end
  H.button(GX + GW - 330, y, 180, 28, "FORGE EVERYTHING", G.forgeReady() > 0, G.forgeEverything, C.gold, Fo.xs, nil, G.forgeReady() > 0)
  H.button(GX + GW - 142, y, 142, 28, "ALL LEVELS (" .. ready .. ")", ready > 0, function()
    local n = G.forgeILAll()
    FX.play("unlock", 1.3)
    FX.toast("LEVEL FORGE", n .. " fusions done.", C.line)
  end, C.line, Fo.xs)
  local top, bot = y + 42, Y0 + 350
  local rows = {}
  for _, g in ipairs(groups) do if #g.mods >= 2 then rows[#rows + 1] = g end end
  H.scrollRegion(GX, top, GW, bot - top, "forgeil")
  lg.setScissor(GX - 2, top, GW + 4, bot - top)
  local rh = 32
  local yy0 = top - G.scroll.forgeil
  local clip = {top, bot}
  for n, g in ipairs(rows) do
    local ry = yy0 + (n - 1) * (rh + 4)
    if ry + rh >= top and ry <= bot then
      local can = #g.mods >= G.FORGE_IL
      local c = C[D.LOOT[g.r].col]
      col(C.panel, 0.9); lg.rectangle("fill", GX, ry, GW, rh)
      if can then col(c, 0.06); lg.rectangle("fill", GX, ry, GW, rh) end
      modChip(g.t, g.r, GX + 4, ry + 3, 56, rh - 6)
      H.label(D.LOOT[g.r].name, GX + 70, ry + 4, c)
      lg.setFont(Fo.s); col(C.white); lg.print("IL" .. g.il .. "  x" .. #g.mods, GX + 70, ry + 15)
      if can then
        local best, nv = G.forgeILPreview(g)
        local fmtv = G.modDef(g.t).fmt
        local txt = string.format(fmtv, math.floor(best * 100 + 0.5)) .. "   >>   IL" .. (g.il + 1) .. "  " .. string.format(fmtv, math.floor(nv * 100 + 0.5))
        H.label(txt, GX + 190, ry + 6, C.white)
        H.label("+" .. math.floor((nv / best - 1) * 100 + 0.5) .. "% on the best roll  //  " .. math.floor(#g.mods / G.FORGE_IL) .. " fusion(s) possible",
          GX + 190, ry + 18, C.dim)
        H.button(GX + GW - 100, ry + 4, 96, rh - 8, "FUSE 3", true, function() G.forgeIL(g.key) end, c, Fo.xs, clip, true)
      else
        H.label("one more identical module to fuse", GX + 190, ry + 12, C.faint)
      end
    end
  end
  lg.setScissor()
  G.maxScroll.forgeil = math.max(0, #rows * (rh + 4) - (bot - top))
  if #rows == 0 then
    H.label("No identical modules yet. Matching type + rarity + item level stack up here.", GX + 10, top + 10, C.dim)
  end

  -- rarity forge
  y = Y0 + 362
  lg.setFont(Fo.m); col(C.white); lg.print("RARITY FORGE", GX, y)
  H.label(G.FORGE_RARITY .. " OF ONE RARITY (ANY TYPE)  >>  1 OF THE NEXT  //  WEAKEST USED FIRST  //  IL = AVERAGE", GX, y + 22, C.dim)
  local prom = 0
  for r = 1, D.MYTHIC - 1 do prom = prom + math.floor(#G.promoteInputs(r) / G.FORGE_RARITY) end
  H.button(GX + GW - 142, y, 142, 28, "PROMOTE ALL (" .. prom .. ")", prom > 0, function()
    local n = G.promoteAll()
    FX.play("jackpot", 1.2)
    FX.toast("RARITY FORGE", n .. " promotions done.", C.gold)
  end, C.gold, Fo.xs)
  local types = {false}
  for _, d in ipairs(D.MODS) do types[#types + 1] = d.t end
  for r = 1, #D.LOOT do
    local ry = y + 40 + (r - 1) * 21
    local c = C[D.LOOT[r].col]
    local cnt = #G.promoteInputs(r)
    col(c); lg.rectangle("fill", GX, ry + 6, 8, 8)
    H.label(D.LOOT[r].name, GX + 14, ry + 4, c)
    lg.setFont(Fo.s); col(cnt > 0 and C.white or C.faint); lg.print("x" .. cnt, GX + 110, ry + 2)
    if r < D.MYTHIC then
      H.segbar(GX + 160, ry + 7, 220, 6, math.min(1, cnt / G.FORGE_RARITY), 10, c)
      local nc = C[D.LOOT[r + 1].col]
      H.label(">> " .. D.LOOT[r + 1].name .. string.format("  x%.1f VALUE", D.RMUL[r + 1] / D.RMUL[r]), GX + 392, ry + 4, nc)
      local cur = G.promoteType[r]
      H.button(GX + GW - 230, ry, 110, 19, "TYPE: " .. (cur or "AUTO"), true, function()
        local k = 1
        for i, t in ipairs(types) do if t == (cur or false) then k = i end end
        G.promoteType[r] = types[k % #types + 1] or nil
        FX.play("tick")
      end, C.dim, Fo.xs)
      H.button(GX + GW - 112, ry, 112, 19, cnt >= G.FORGE_RARITY and "PROMOTE" or (G.FORGE_RARITY - cnt % G.FORGE_RARITY .. " MORE"),
        cnt >= G.FORGE_RARITY, function() G.promote(r) end, nc, Fo.xs, nil, cnt >= G.FORGE_RARITY)
    else
      H.label(r == D.MYTHIC and ("Feeds the MYTHIC ALTAR (right): " .. G.ALTAR_COST .. " = 1 perk point") or "DROP ONLY. Cannot be forged.", GX + 160, ry + 4, c)
    end
  end
end

function Va.draw()
  local S, Fo = G.S, H.fonts
  H.card(X0, Y0, W, HH, nil, C.line)
  lg.setFont(Fo.d3); col(C.white); lg.print("MODULE VAULT", X0 + 18, Y0 + 10)
  H.label(#S.modules .. " / " .. G.vaultCap() .. " STORED  //  WHEN FULL, THE WEAKEST MODULE IS SALVAGED", X0 + 230, Y0 + 15, C.dim)

  local list = shown()
  local target, tk = G.findDrone(G.hangarSel or -1)
  Va.tabs()
  if G.vaultMode == "forge" then Va.forge() else
  -- rarity filters
  local counts = {0, 0, 0, 0, 0, 0, 0}
  for _, m in ipairs(S.modules) do counts[m.r] = counts[m.r] + 1 end
  local fx, fy = GX, Y0 + 52
  local chips = {{0, "ALL", #S.modules, C.line}}
  for r = 1, #D.LOOT do chips[#chips + 1] = {r, D.LOOT[r].name, counts[r], C[D.LOOT[r].col]} end
  for _, c in ipairs(chips) do
    local w = Fo.xs:getWidth(c[2] .. " " .. c[3]) + 18
    local on = G.vaultFilter == c[1]
    local hov = H.mouseIn(fx, fy, w, 22)
    col(c[4], on and 0.3 or (hov and 0.12 or 0.04)); lg.rectangle("fill", fx, fy, w, 22)
    H.brackets(fx, fy, w, 22, 4, on and C.white or c[4], on and 1 or 0.6)
    lg.setFont(Fo.xs); col(on and C.white or c[4]); lg.printf(c[2] .. " " .. c[3], fx, fy + 5, w, "center")
    H.addHit(fx, fy, w, 22, function() G.vaultFilter = c[1]; G.scroll.vaultfull = 0; FX.play("tick", 1.1) end)
    fx = fx + w + 6
  end
  local sorts = {rarity = "SORT: RARITY", type = "SORT: TYPE", score = "SORT: STRENGTH"}
  local nextSort = {rarity = "type", type = "score", score = "rarity"}
  H.button(GX + GW - 130, fy, 130, 22, sorts[G.vaultSort], true, function() G.vaultSort = nextSort[G.vaultSort]; FX.play("tick") end, C.dim, Fo.xs)

  -- grid
  H.scrollRegion(GX, GY, GW, GB - GY, "vaultfull")
  lg.setScissor(GX - 2, GY, GW + 4, GB - GY)
  local cols, gap = 7, 6
  local cw, ch = (GW - (cols - 1) * gap) / cols, 58
  local yy0 = GY - G.scroll.vaultfull
  local clip = {GY, GB}
  for n, e in ipairs(list) do
    local m = e.m
    local c, r = (n - 1) % cols, math.floor((n - 1) / cols)
    local cx, cy = GX + c * (cw + gap), yy0 + r * (ch + gap)
    if cy + ch >= GY and cy <= GB then
      local hov = H.mouseIn(cx, cy, cw, ch, clip)
      moduleCard(m, cx, cy, cw, ch, hov)
      if hov then
        H.setTip(D.LOOT[m.r].name .. " " .. G.modDef(m.t).name:upper(), G.modText(m) .. "  //  ILVL " .. m.ilvl .. "  //  " ..
          (G.salvageMode and ("click to salvage +" .. G.modSalvage(m) .. " parts") or
          (target and ("click to equip on " .. G.droneLabel(target)) or "select a drone in the hangar to equip")))
      end
      H.addHit(cx, cy, cw, ch, function()
        for kk, mm in ipairs(S.modules) do
          if mm == m then
            if G.salvageMode then
              local p = G.salvageModule(kk)
              local mx, my = V.mouse()
              FX.floater(mx, my - 10, "+" .. p .. " PARTS", C.line)
            elseif tk then G.equipModule(kk, tk)
            else FX.play("err") end
            break
          end
        end
      end, clip)
    end
  end
  lg.setScissor()
  G.maxScroll.vaultfull = math.max(0, math.ceil(#list / cols) * (ch + gap) - (GB - GY))
  if #list == 0 then
    lg.setFont(Fo.m); col(C.dim); lg.printf("NOTHING HERE // OPEN CRATES ON THE MAP TO FIND MODULES", GX, GY + 120, GW, "center")
  end

  end
  -- right column: equip target + tools
  local y = Y0 + 52
  H.label("EQUIP TARGET", PX, y, C.dim)
  -- cycle the target without leaving the vault
  if #S.drones > 1 then
    local function step(d)
      local _, k = G.findDrone(G.hangarSel or -1)
      k = ((k or 1) - 1 + d) % #S.drones + 1
      G.hangarSel = S.drones[k].id
      FX.play("tick", 1.3)
    end
    H.button(PX + PW - 64, y - 4, 30, 22, "<", true, function() step(-1) end, C.dim, Fo.xs)
    H.button(PX + PW - 30, y - 4, 30, 22, ">", true, function() step(1) end, C.dim, Fo.xs)
  end
  if target then
    local rc = C[D.RARITY[target.r].col]
    lg.setFont(Fo.m); col(C.white); lg.print(H.fit(Fo.m, G.droneLabel(target), PW - 10), PX, y + 14)
    H.label(D.RARITY[target.r].name .. "  //  " .. #target.mods .. " / " .. D.RARITY[target.r].slots .. " SLOTS USED", PX, y + 36, rc)
  else
    H.label("Select a drone in the hangar first.", PX, y + 16, C.dim)
  end
  if S.autoLoadout then H.label("AUTO-LOADOUT is on: manual equips get reassigned.", PX, y + 52, C.orange) end
  y = y + 74
  local bw = (PW - 8) / 2
  H.button(PX, y, bw, 30, S.autoLoadout and "AUTO-LOADOUT ON" or "AUTO-LOADOUT OFF", true, function()
    S.autoLoadout = not S.autoLoadout; FX.play("tick", 1.2)
    if S.autoLoadout then G.autoEquip() end
  end, S.autoLoadout and C.line or C.dim, Fo.xs, nil, S.autoLoadout)
  H.button(PX + bw + 8, y, bw, 30, "AUTO-SALVAGE " .. G.autoSalvageLabel(), true, G.cycleAutoSalvage,
    (S.autoSalvage or 0) > 0 and C.orange or C.dim, Fo.xs)
  H.button(PX, y + 38, bw, 30, "EQUIP BEST NOW", #S.drones > 0, G.autoEquip, C.line, Fo.xs)
  H.button(PX + bw + 8, y + 38, bw, 30, G.salvageMode and "SALVAGE MODE ON" or "SALVAGE MODE", true,
    function() G.salvageMode = not G.salvageMode; FX.play("tick") end, G.salvageMode and C.red or C.dim, Fo.xs)
  -- bulk salvage of what is shown (never MYTHIC)
  local bulk, bulkP = 0, 0
  for _, e in ipairs(list) do if e.m.r < D.MYTHIC then bulk = bulk + 1; bulkP = bulkP + G.modSalvage(e.m) end end
  local armed = salvageArm and G.time - salvageArm < 3
  H.button(PX, y + 76, PW, 30, armed and ("CONFIRM // SALVAGE " .. bulk .. " FOR +" .. fmt(bulkP) .. " PARTS") or
    ("SALVAGE SHOWN (" .. bulk .. ", NO MYTHICS)"), bulk > 0, function()
    if not armed then salvageArm = G.time; FX.play("tick") return end
    salvageArm = nil
    local set = {}
    for _, e in ipairs(list) do if e.m.r < D.MYTHIC then set[e.m] = true end end
    local total = 0
    for k = #S.modules, 1, -1 do if set[S.modules[k]] then total = total + G.salvageModule(k, true) end end
    FX.play("collect", 1.3)
    FX.toast("SALVAGE COMPLETE", bulk .. " modules recycled into " .. fmt(total) .. " parts.", C.line)
  end, armed and C.red or C.dim, Fo.xs)
  -- the altar
  altarPanel(y + 122)
end

function Va.escape() close() end

return Va
