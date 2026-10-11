-- Tactical map systems: scav enemies, drone combat, tower turret, loot crates, modules, zones.
-- Extends the G table from game/core.lua.
local H = require "lib.hud"
local FX = require "game.fx"
local D = require "game.data"
local G = require "game.core"

local C, fmt, rnd, clamp = H.C, H.fmt, H.rnd, H.clamp
local RAR, LOOT = D.RARITY, D.LOOT

G.TAC = {MX0 = 252, MY0 = 120, CS = 30}
local function onMap() return G.tab == "map" end
G.tacSel = nil
G.turretBeam = nil
G.strikeCombo, G.lastStrike = 0, -10
G.killHist, G.killAcc, G.killT = {}, 0, 0
for i = 1, 30 do G.killHist[i] = 0 end

local euid = 0
local spawnT, turretT, huntT, claimT = 6, 0, 0, 0
local frontierT = 0

-- map cell coords (cell centers at integers) -> virtual pixels
function G.toPx(x, y) return G.TAC.MX0 + (x - 0.5) * G.TAC.CS, G.TAC.MY0 + (y - 0.5) * G.TAC.CS end

function G.addFeed(text, c)
  table.insert(G.lootFeed, 1, {text = text, c = c or C.line, t = G.time})
  if #G.lootFeed > 14 then table.remove(G.lootFeed) end
end

----------------------------------------------------------------------
-- Modules
----------------------------------------------------------------------
function G.modDef(t)
  for _, m in ipairs(D.MODS) do if m.t == t then return m end end
end
function G.modScore(m) local d = G.modDef(m.t) return m.v / d.base * d.weight end
function G.modText(m) return string.format(G.modDef(m.t).fmt, math.floor(m.v * 100 + 0.5)) end
function G.modSalvage(m) return math.ceil(6 * D.RMUL[m.r] * (1 + 0.2 * (m.ilvl - 1)) * (1 + 0.3 * G.tr("sv_salv"))) end
function G.vaultCap() return 40 + (G.S.pupg.vault and 40 or 0) + 20 * G.tr("sv_vault") end

function G.salvageModule(k, quiet)
  local S = G.S
  local m = table.remove(S.modules, k)
  if not m then return 0 end
  local p = G.modSalvage(m)
  S.parts = S.parts + p
  if not quiet then FX.play("err", 0.7) end
  return p
end
function G.salvageBelow(r)
  local S = G.S
  local total, n = 0, 0
  for k = #S.modules, 1, -1 do
    if S.modules[k].r <= r then total = total + G.salvageModule(k, true); n = n + 1 end
  end
  if n > 0 then
    FX.play("collect", 1.3)
    FX.toast("SALVAGE COMPLETE", n .. " modules recycled into " .. fmt(total) .. " parts.", C.line)
  else FX.play("err") end
end

----------------------------------------------------------------------
-- Module forge (vault modules only)
--   item level: 3 of the same type + rarity + IL -> 1 at IL+1, keeping the best roll of the three
--     (+20% per IL step like a natural drop, +~7% from best-of-3 => roughly +25% per fusion early on)
--   rarity:     10 of one rarity (any type) -> 1 of the next rarity (x1.6 value), IL = floor(average IL)
--     10:1 is a little stingier than natural drop odds (3-7x per tier) and matches the 10:1 Mythic Altar
----------------------------------------------------------------------
G.FORGE_IL, G.FORGE_RARITY = 3, 10
function G.ilMult(il) return 1 + 0.2 * (il - 1) end
local function addForged(t, r, il, v)
  local S = G.S
  S.modUid = S.modUid + 1
  local m = {uid = S.modUid, t = t, r = r, ilvl = il, v = v}
  table.insert(S.modules, m)
  return m
end
local function removeMods(set)
  local S = G.S
  for k = #S.modules, 1, -1 do if set[S.modules[k]] then table.remove(S.modules, k) end end
end
-- groups of identical type + rarity + IL, best groups first
function G.forgeGroups()
  local g, list = {}, {}
  for _, m in ipairs(G.S.modules) do
    local key = m.t .. "|" .. m.r .. "|" .. m.ilvl
    if not g[key] then g[key] = {key = key, t = m.t, r = m.r, il = m.ilvl, mods = {}}; list[#list + 1] = g[key] end
    table.insert(g[key].mods, m)
  end
  table.sort(list, function(a, b)
    local fa, fb = #a.mods >= G.FORGE_IL, #b.mods >= G.FORGE_IL
    if fa ~= fb then return fa end
    if a.r ~= b.r then return a.r > b.r end
    if a.il ~= b.il then return a.il > b.il end
    return a.t < b.t
  end)
  return list
end
-- value of the IL+1 result: the best roll, rescaled to the next item level
function G.forgeILPreview(grp)
  local best = 0
  for _, m in ipairs(grp.mods) do best = math.max(best, m.v) end
  return best, best / G.ilMult(grp.il) * G.ilMult(grp.il + 1) * (1 + 0.05 * G.tr("sv_forge"))
end
function G.forgeIL(key, quiet)
  local grp
  for _, x in ipairs(G.forgeGroups()) do if x.key == key then grp = x end end
  if not grp or #grp.mods < G.FORGE_IL then if not quiet then FX.play("err") end return end
  table.sort(grp.mods, function(a, b) return a.v > b.v end)
  -- the best module plus the two weakest: middle rolls stay for later fusions
  local a, b, c = grp.mods[1], grp.mods[#grp.mods], grp.mods[#grp.mods - 1]
  local _, nv = G.forgeILPreview({mods = {a}, il = grp.il})
  removeMods({[a] = true, [b] = true, [c] = true})
  local m = addForged(grp.t, grp.r, grp.il + 1, nv)
  G.S.forged = (G.S.forged or 0) + 1
  if not quiet then
    FX.play("buy", 1.3)
    FX.toast("FORGED // " .. grp.t .. " IL" .. m.ilvl, "3 x IL" .. grp.il .. " became " .. G.modText(m) .. " (" .. D.LOOT[m.r].name .. ").", C[D.LOOT[m.r].col])
  end
  return m
end
function G.forgeILAll()
  local n = 0
  for _ = 1, 999 do
    local done = false
    for _, grp in ipairs(G.forgeGroups()) do
      if #grp.mods >= G.FORGE_IL then G.forgeIL(grp.key, true); n = n + 1; done = true; break end
    end
    if not done then break end
  end
  return n
end

G.promoteType = {}  -- per rarity: nil = AUTO (most common type among the inputs)
function G.promoteInputs(r)
  local list = {}
  for _, m in ipairs(G.S.modules) do if m.r == r then list[#list + 1] = m end end
  table.sort(list, function(a, b) return G.modScore(a) < G.modScore(b) end) -- weakest first
  return list
end
function G.promote(r, quiet)
  local list = G.promoteInputs(r)
  -- PRISMATIC is drop-only: promotion stops at MYTHIC
  if r >= D.MYTHIC or #list < G.FORGE_RARITY then if not quiet then FX.play("err") end return end
  local use, cnt, il = {}, {}, 0
  for k = 1, G.FORGE_RARITY do
    local m = list[k]
    use[m] = true
    cnt[m.t] = (cnt[m.t] or 0) + 1
    il = il + m.ilvl
  end
  local t = G.promoteType[r]
  if not t then
    local bn = 0
    for _, d in ipairs(D.MODS) do if (cnt[d.t] or 0) > bn then t, bn = d.t, cnt[d.t] end end
  end
  il = math.floor(il / G.FORGE_RARITY)
  removeMods(use)
  local m = addForged(t, r + 1, il, G.modDef(t).base * D.RMUL[r + 1] * G.ilMult(il) * rnd(0.85, 1.15))
  G.S.promoted = (G.S.promoted or 0) + 1
  if not quiet then
    local c = C[D.LOOT[r + 1].col]
    FX.play(r + 1 >= 5 and "jackpot" or "unlock", 1.1)
    if r + 1 >= 5 then FX.flashTo(c, 0.3) end
    FX.toast("PROMOTED // " .. D.LOOT[r + 1].name .. " " .. t, G.FORGE_RARITY .. " " .. D.LOOT[r].name .. " modules became " .. G.modText(m) .. ".", c)
  end
  return m
end
function G.promoteAll()
  local n = 0
  for r = 1, D.MYTHIC - 1 do
    while #G.promoteInputs(r) >= G.FORGE_RARITY do G.promote(r, true); n = n + 1 end
  end
  return n
end
-- everything at once: level fusions first (they keep rarity), then promotions climb the ladder
function G.forgeEverything()
  local a = G.forgeILAll()
  local b = G.promoteAll()
  a = a + G.forgeILAll()
  if a + b == 0 then FX.play("err") return end
  FX.play("jackpot", 1.2)
  FX.toast("FORGE COMPLETE", a .. " level fusions, " .. b .. " rarity promotions.", C.gold)
end
function G.forgeReady()
  local n = 0
  for _, grp in ipairs(G.forgeGroups()) do n = n + math.floor(#grp.mods / G.FORGE_IL) end
  for r = 1, D.MYTHIC - 1 do n = n + math.floor(#G.promoteInputs(r) / G.FORGE_RARITY) end
  return n
end

function G.newModule(r)
  local S = G.S
  S.modUid = S.modUid + 1
  local def = D.MODS[love.math.random(#D.MODS)]
  local m = {uid = S.modUid, t = def.t, r = r, ilvl = S.zone, v = def.base * D.RMUL[r] * (1 + 0.2 * (S.zone - 1)) * rnd(0.85, 1.15)}
  table.insert(S.modules, m)
  if #S.modules > G.vaultCap() then
    local wi, ws
    for k, x in ipairs(S.modules) do
      local sc = G.modScore(x)
      if not ws or sc < ws then wi, ws = k, sc end
    end
    G.salvageModule(wi, true)
  end
  return m
end

function G.equipModule(vi, di)
  local S = G.S
  local d, m = S.drones[di], S.modules[vi]
  if not d or not m then return end
  local slots = RAR[d.r].slots
  if #d.mods >= slots then
    local wi, ws
    for k, x in ipairs(d.mods) do
      local sc = G.modScore(x)
      if not ws or sc < ws then wi, ws = k, sc end
    end
    table.insert(S.modules, table.remove(d.mods, wi))
  end
  for k, x in ipairs(S.modules) do if x == m then table.remove(S.modules, k) break end end
  table.insert(d.mods, m)
  G.recalc()
  d.hp = math.min(d.hp or 0, G.droneMaxHp(d))
  FX.play("buy", 1.4)
end
function G.unequip(di, k)
  local S = G.S
  local d = S.drones[di]
  if not d or not d.mods[k] then return end
  table.insert(S.modules, table.remove(d.mods, k))
  G.recalc()
  d.hp = math.min(d.hp or 0, G.droneMaxHp(d))
  FX.play("tick")
end
function G.autoEquip(quiet)
  local S = G.S
  local all = {}
  for _, m in ipairs(S.modules) do all[#all + 1] = m end
  for _, d in ipairs(S.drones) do
    for _, m in ipairs(d.mods) do all[#all + 1] = m end
    d.mods = {}
  end
  table.sort(all, function(a, b) return G.modScore(a) > G.modScore(b) end)
  local ds = {}
  for _, d in ipairs(S.drones) do ds[#ds + 1] = d end
  table.sort(ds, function(a, b)
    return RAR[a.r].power * 1.6 ^ (a.mk - 1) * a.lvl > RAR[b.r].power * 1.6 ^ (b.mk - 1) * b.lvl
  end)
  local i = 1
  for _, d in ipairs(ds) do
    while #d.mods < RAR[d.r].slots and all[i] do
      d.mods[#d.mods + 1] = all[i]
      i = i + 1
    end
  end
  S.modules = {}
  for k = i, #all do S.modules[#S.modules + 1] = all[k] end
  G.recalc()
  for _, d in ipairs(S.drones) do d.hp = math.min(d.hp or 0, G.droneMaxHp(d)) end
  if quiet then return end
  FX.play("unlock", 1.2)
  FX.toast("AUTO-EQUIP COMPLETE", "Best modules assigned to your strongest drones.", C.line)
end

----------------------------------------------------------------------
-- Loot crates
----------------------------------------------------------------------
function G.rollTier(min)
  local t = math.min(#LOOT, min + (G.eventActive("INVASION") and 1 or 0) + (G.weather.def.id == "FOG" and 1 or 0))
  -- loot luck is capped at x1.75 on climb chances, and PRISMATIC (the last step) never benefits from luck
  local luck = math.min(1.75, (1 + G.luck) * (1 + 0.1 * G.tr("sv_tier")))
  while t < #LOOT and love.math.random() < D.LOOT_UP[t + 1] * (t + 1 == #LOOT and 1 or luck) do t = t + 1 end
  return t
end

function G.dropCrate(x, y, tier)
  local S = G.S
  table.insert(S.crateList, {x = clamp(x, 1, G.MW), y = clamp(y, 1, G.MH), r = tier, t = 0})
  if tier >= 4 then
    FX.play("crate", 0.8)
    G.addFeed(LOOT[tier].name .. " CRATE DETECTED", C[LOOT[tier].col])
  end
  while #S.crateList > 30 do G.openCrate(1, true) end
end

-- open a crate of a given tier right now (season pass / directives), effects at screen pos
function G.grantCrate(tier, px, py)
  local S = G.S
  table.insert(S.crateList, {x = G.TX, y = G.TY, r = tier, t = 0})
  G.openCrate(#S.crateList, false, px, py)
end

function G.openCrate(k, quiet, sx, sy)
  local S = G.S
  local c = table.remove(S.crateList, k)
  if not c then return end
  local L = LOOT[c.r]
  local F = 1.35 ^ (S.zone - 1)
  local sal = 1
  for _, d in ipairs(S.drones) do if G.hasTrait(d, "SALVAGER") then sal = 1.5 break end end
  S.crates = S.crates + 1
  if c.r >= 5 then S.legendary = S.legendary + 1 end
  if c.r >= 6 then S.mythic = S.mythic + 1 end
  if c.r >= 7 then S.prismatic = (S.prismatic or 0) + 1 end
  local lines = {}
  local e = math.max(50, G.baseCps * L.secs)
  G.gain(e)
  lines[#lines + 1] = "+" .. fmt(e) .. " ENERGY"
  local pa = math.floor(L.parts * F * sal * rnd(0.8, 1.2) * (1 + 0.2 * G.tr("sv_parts")) * 1.3 ^ G.tr("od_salv"))
  local hy = math.floor(L.hydro * F * sal * rnd(0.8, 1.2))
  S.parts, S.hydro = S.parts + pa, S.hydro + hy
  lines[#lines + 1] = "+" .. fmt(pa) .. " PARTS  +" .. fmt(hy) .. " H2O"
  local tk = math.floor(L.tokens)
  if love.math.random() < L.tokens - tk then tk = tk + 1 end
  if tk > 0 then S.tokens = S.tokens + tk; lines[#lines + 1] = "+" .. tk .. " FAB TOKEN" .. (tk > 1 and "S" or "") end
  local bestMod
  if love.math.random() < L.mods then
    for n = 1, L.nmods do
      local m = G.newModule(n == 1 and c.r or math.max(1, c.r - love.math.random(1, 2)))
      if not bestMod or m.r > bestMod.r then bestMod = m end
    end
    lines[#lines + 1] = LOOT[bestMod.r].name .. " " .. G.modDef(bestMod.t).name:upper() .. " (" .. G.modText(bestMod) .. ")"
  end
  if c.r >= 5 and S.dmTotal > 0 then
    local cd = math.max(1, math.floor(S.dmTotal * 0.01 * (c.r - 4)))
    S.dm, S.dmTotal = S.dm + cd, S.dmTotal + cd
    lines[#lines + 1] = "+" .. fmt(cd) .. " CORE DATA"
  end
  -- PRISM drones only ever come out of crates (and only the best ones)
  local pc = ({[5] = 0.0005, [6] = 0.004, [7] = 0.05})[c.r]
  local prismDrone
  if pc and love.math.random() < pc then
    prismDrone = G.makeDrone(#RAR)
    G.addDrone(prismDrone)
    lines[#lines + 1] = "PRISM DRONE " .. G.droneLabel(prismDrone)
  end
  G.addXP(5 * c.r)
  G.recalc()
  local col = C[L.col]
  G.addFeed(L.name .. " // " .. (bestMod and lines[#lines] or lines[2]), col)
  local px, py = G.toPx(c.x, c.y)
  if sx then px, py = sx, sy end
  if quiet or (not sx and not onMap()) then
    if c.r >= 7 or prismDrone then FX.prismEvent(prismDrone and "PRISM" or L.name, 640, 360) end
    return
  end
  -- SIGNAL LOCK: the headline is the best thing inside (prism drone > module > materials), the rest are detail lines
  local head, rest = lines[2], {}
  if prismDrone then head = lines[#lines]
  elseif bestMod then
    for _, l in ipairs(lines) do if l:find(G.modDef(bestMod.t).name:upper(), 1, true) then head = l end end
  end
  for _, l in ipairs(lines) do if l ~= head and #rest < 3 then rest[#rest + 1] = l end end
  local isPrism = c.r >= 7 or prismDrone
  FX.lock(px, py, isPrism and 7 or c.r, col, L.name .. " CACHE", head, {lines = rest, map = true})
  if G.meme and c.r == 5 then G.meme("legendary") elseif G.meme and c.r == 6 then G.meme("mythic") end
  if isPrism then FX.prismEvent(prismDrone and "PRISM" or L.name, px, py)
  elseif c.r == 6 then FX.lootSound(2)
  elseif c.r == 5 then FX.lootSound(1)
  else FX.play("crate", 0.8 + c.r * 0.12) end
end
function G.openAllCrates()
  local S = G.S
  local n = #S.crateList
  if n == 0 then FX.play("err") return end
  -- open from worst to best so the best one gets the last, loudest reveal
  table.sort(S.crateList, function(a, b) return a.r > b.r end)
  for k = #S.crateList, 2, -1 do G.openCrate(k, true) end
  G.openCrate(1)
  FX.toast("ALL CRATES OPENED", n .. " crates looted. See the loot feed.", C.line)
end

----------------------------------------------------------------------
-- Enemies
----------------------------------------------------------------------
-- more territory = a bigger scav presence
function G.landFrac() return G.landCount > 0 and G.claimed / G.landCount or 0 end
function G.enemyCap()
  return math.floor(math.min(16, 4 + G.S.zone) * (1 + 1.5 * G.landFrac())) * (G.eventActive("INVASION") and 2 or 1)
end
-- SCAV ALERT: claiming sectors and killing scavs raise it; at 100% the mothership arrives.
-- Claims alone give ~45% at 60% land, kills supply the rest, so a strong fleet gets there in minutes.
G.KILL_ALERT = {SCOUT = 0.006, RAIDER = 0.01, BRUTE = 0.02, ELITE = 0.04}
G.KILL_CRATE = {SCOUT = 0.1, RAIDER = 0.2, BRUTE = 0.4, ELITE = 0.7, MOTHERSHIP = 1}
function G.raiseAlert(v)
  local S = G.S
  if S.bossDown or G.boss() then return end
  S.alert = math.min(1, math.max(0, S.alert or 0) + v * (1 + 0.2 * G.tr("map_alert")))
end
function G.claimAlert() return 0.45 / math.max(20, 0.6 * G.landCount) end
function G.findEnemy(uid)
  for _, e in ipairs(G.enemies) do if e.uid == uid then return e end end
end
local function enemyDef(id)
  for _, e in ipairs(D.ENEMIES) do if e.id == id then return e end end
end

function G.spawnEnemy(kind)
  local S = G.S
  local cands = {}
  for i = 1, G.MW * G.MH do
    if G.land[i] and S.map.cells[i] ~= 2 and S.map.cells[i] ~= 3 and G.dist(i) >= 4 then cands[#cands + 1] = i end
  end
  if #cands == 0 then
    -- everything is secured: scavs fly in over the sea / map edge
    for i = 1, G.MW * G.MH do
      if S.map.cells[i] ~= 2 and S.map.cells[i] ~= 3 and G.dist(i) >= 4 then cands[#cands + 1] = i end
    end
    if #cands == 0 then return end
  end
  local def
  if kind then def = enemyDef(kind)
  else
    local total = 0
    for _, e in ipairs(D.ENEMIES) do total = total + e.w end
    local x = love.math.random() * total
    for _, e in ipairs(D.ENEMIES) do
      x = x - e.w
      if e.w > 0 and x <= 0 then def = e break end
    end
    def = def or D.ENEMIES[1]
  end
  local i = cands[love.math.random(#cands)]
  local x, y = G.xy(i)
  local F = G.zoneF()
  euid = euid + 1
  local e = {uid = euid, def = def, x = x + rnd(-0.3, 0.3), y = y + rnd(-0.3, 0.3), hp = def.hp * F, max = def.hp * F,
    dps = def.dps * F, code = string.format("%02d %03d", love.math.random(10, 99), love.math.random(0, 999)),
    raid = 0, flash = 0, wob = rnd(0, 6)}
  table.insert(G.enemies, e)
  if def.boss and G.meme then G.meme("bossSpawn") end
  if def.boss then
    e.bounty = G.BOUNTY_TIME + 60 * G.tr("map_bounty")
    G.rankBanner = {t = 0, title = "MOTHERSHIP INBOUND", text = "Destroy it within " .. H.fmtTime(G.BOUNTY_TIME) .. " for the BOUNTY: a LEGENDARY crate + 3 fab tokens.", c = C.red}
    FX.toast("!! MOTHERSHIP DETECTED !!", "Bounty clock is running. Check the MAP.", C.red)
    FX.play("raid")
    FX.shake = math.max(FX.shake, 10)
  end
  return e
end

function G.damageEnemy(e, dmg)
  if e.dead then return end
  if e.def.boss then dmg = dmg * (1 + 0.5 * G.tr("map_boss")) end
  e.hp = e.hp - dmg
  e.flash = 1
  if e.hp <= 0 then G.killEnemy(e) end
end

function G.killEnemy(e)
  local S = G.S
  e.dead = true
  for k, x in ipairs(G.enemies) do if x == e then table.remove(G.enemies, k) break end end
  S.kills = S.kills + 1
  G.killAcc = G.killAcc + 1
  if not e.def.boss then G.raiseAlert(G.KILL_ALERT[e.def.id] or 0.01) end
  S.tetCharge = math.min(1, (S.tetCharge or 0) + (e.def.boss and 0.3 or 0.04))
  if e.raid > 0 then S.raidsRepelled = S.raidsRepelled + 1 end
  G.addXP(e.def.xp)
  -- one crate at most per kill; bigger scavs are more likely to carry one
  local chance = (G.KILL_CRATE[e.def.id] or 0.3) + 0.05 * G.tr("sv_crate")
  if love.math.random() < chance then G.dropCrate(e.x + rnd(-0.4, 0.4), e.y + rnd(-0.4, 0.4), G.rollTier(e.def.tier)) end
  local px, py = G.toPx(e.x, e.y)
  local big = e.def.boss and 3 or (e.def.tier >= 3 and 2 or 1)
  if onMap() then
    FX.burst(px, py, 20 * big, C.orange, 200 * big, 2)
    FX.burst(px, py, 10 * big, C.white, 120 * big, 1.5)
    FX.wave(px, py, 4, C.orange, 120 * big, 0.5)
    FX.play("boom", 1.3 - big * 0.2, 0.7)
  end
  if G.tacSel and G.tacSel.uid == e.uid then G.tacSel = nil end
  if e.def.boss then
    S.bosses = S.bosses + 1
    S.bossDown = true
    if G.meme then G.meme((e.bounty or 0) > 0 and "bounty" or "bossKill") end
    if (e.bounty or 0) > 0 then
      S.bounties = (S.bounties or 0) + 1
      S.tokens = S.tokens + 3
      G.dropCrate(e.x, e.y, 5)
      FX.toast("BOUNTY CLAIMED", "Mothership down with " .. H.fmtTime(e.bounty) .. " to spare: a LEGENDARY crate + 3 fab tokens.", C.gold)
    end
    if S.zone > S.zoneBest then S.zoneBest = S.zone end
    G.recalc()
    FX.flashTo(C.orange, 0.8)
    FX.shake = 30
    if onMap() then FX.ray(px, py, C.orange, 3, 600) end
    FX.play("mythic")
    G.rankBanner = {t = 0, title = "ZONE " .. S.zone .. " CLEARED", text = "Mothership destroyed. +25% output per zone cleared. Advance when ready.", c = C.gold}
    FX.toast("ZONE " .. S.zone .. " CLEARED", "Advance to zone " .. (S.zone + 1) .. " from the MAP screen for stronger loot.", C.gold)
  end
end

function G.strike(e)
  local now = G.time
  if now - G.lastStrike < 0.6 then G.strikeCombo = G.strikeCombo + 1 else G.strikeCombo = 1 end
  G.lastStrike = now
  local dmg = (math.max(1, G.fleetPower * 0.25) + 2 * G.zoneF()) * (1 + math.min(G.strikeCombo, 40) * 0.05) * (1 + 0.5 * G.tr("map_strike")) * 1.2 ^ G.tr("od_map")
  local crit = love.math.random() < G.critChance
  if crit then dmg = dmg * 5 end
  local px, py = G.toPx(e.x, e.y)
  G.damageEnemy(e, dmg)
  FX.floater(px + rnd(-8, 8), py - 14, (crit and "CRIT " or "") .. fmt(dmg), crit and C.red or C.white, crit and H.fonts.m or H.fonts.xs, 0.8)
  FX.burst(px, py, crit and 18 or 6, crit and C.red or C.orange, 160)
  FX.play("hit", crit and 0.7 or (1 + rnd(-0.1, 0.1)), crit and 1 or 0.7)
  if crit then FX.shake = math.max(FX.shake, 4) end
end

function G.engage(e, all)
  local S = G.S
  local best
  for _, d in ipairs(S.drones) do
    if not d.mission and not G.isDown(d) then
      if all then d.hunt = e.uid
      elseif not d.hunt and (not best or G.droneDps(d) > G.droneDps(best)) then best = d end
    end
  end
  if best then best.hunt = e.uid end
  if all or best then FX.play("signal", 1.5, 0.5) else FX.play("err") end
end
function G.recallAll()
  for _, d in ipairs(G.S.drones) do d.hunt = nil end
  FX.play("tick", 0.7)
end

function G.advanceZone()
  local S = G.S
  if not S.bossDown then FX.play("err") return end
  if G.meme then G.meme("zoneClear") end
  S.zone = S.zone + 1
  G.newMap()
  G.recalc()
  FX.flashTo(C.white, 0.7)
  FX.play("unlock")
  G.rankBanner = {t = 0, title = "ZONE " .. S.zone .. " // " .. D.zoneName(S.zone), text = "Threat x" ..
    string.format("%.1f", G.zoneF()) .. ". New drones fabricate at MK" .. S.zone .. ". Loot item level " .. S.zone .. ".", c = C.white}
  G.save()
end

----------------------------------------------------------------------
-- Update
----------------------------------------------------------------------
local function nearestClaimed(ex, ey)
  local S = G.S
  local best, bd
  for i = 1, G.MW * G.MH do
    if S.map.cells[i] == 2 and i ~= G.TIDX then
      local x, y = G.xy(i)
      local d = (x - ex) ^ 2 + (y - ey) ^ 2
      if not bd or d < bd then best, bd = i, d end
    end
  end
  return best
end

local function moveToward(o, tx, ty, speed, dt)
  local dx, dy = tx - o.x, ty - o.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 1e-6 then return 0 end
  local step = math.min(dist, speed * dt)
  o.x, o.y = o.x + dx / dist * step, o.y + dy / dist * step
  return dist - step
end

----------------------------------------------------------------------
-- Radiation sectors: deterministic per map seed. Claims take 2x longer but drop an extra crate.
----------------------------------------------------------------------
function G.isRadiation(i)
  if not G.land[i] or i == G.TIDX or G.dist(i) < 3.5 then return false end
  local x, y = G.xy(i)
  local sd = G.S.map.seed
  return love.math.noise(x * 0.31 + sd * 2.1, y * 0.31 - sd * 1.7) > 0.86
end

----------------------------------------------------------------------
-- Weather: cycles every few minutes and changes how the fleet behaves
----------------------------------------------------------------------
G.WEATHER = {
  {id = "CLEAR",    desc = "Calm skies. Normal operations.",                       speed = 1.0, mission = 1.0, strike = 1.0},
  {id = "TAILWIND", desc = "Drone speed +30%, claim missions 25% faster.",         speed = 1.3, mission = 0.75, strike = 1.0},
  {id = "FOG",      desc = "Scavs outside your territory are hidden. Crates +1 rarity.", speed = 1.0, mission = 1.0, strike = 1.0},
  {id = "STORM",    desc = "Drone speed -25%. Orbital strikes deal x2 (lightning).", speed = 0.75, mission = 1.2, strike = 2.0},
}
G.weather = {def = G.WEATHER[1], t = 120, dur = 120, wind = 0, windSpeed = 8}
local function nextWeather()
  local w = G.WEATHER[love.math.random(#G.WEATHER)]
  local dur = rnd(100, 200)
  G.weather = {def = w, t = dur, dur = dur, wind = rnd(0, math.pi * 2),
    windSpeed = w.id == "STORM" and rnd(40, 70) or (w.id == "TAILWIND" and rnd(25, 40) or rnd(4, 15))}
  if G.tab == "map" then FX.play("signal", 0.7, 0.4) end
  G.addFeed("WEATHER // " .. w.id, w.id == "STORM" and C.red or C.line)
end
function G.weatherSpeed() return G.weather.def.speed end
function G.weatherMission() return G.weather.def.mission end
function G.fogged(e)
  if G.weather.def.id ~= "FOG" then return false end
  -- visible only within 1 cell of your territory
  local cx, cy = math.floor(e.x + 0.5), math.floor(e.y + 0.5)
  for dy = -1, 1 do
    for dx = -1, 1 do
      local nx, ny = cx + dx, cy + dy
      if nx >= 1 and nx <= G.MW and ny >= 1 and ny <= G.MH and G.S.map.cells[G.idx(nx, ny)] == 2 then return false end
    end
  end
  return true
end

----------------------------------------------------------------------
-- TET uplink: charges over time and from kills; fires a satellite strike on an area
----------------------------------------------------------------------
G.tetBeam = nil
function G.tetReady() return (G.S.tetCharge or 0) >= 1 end
function G.tetTarget()
  -- selected scav, else the biggest threat (boss > raider on a sector > highest hp)
  local sel = G.tacSel and G.tacSel.kind == "enemy" and G.findEnemy(G.tacSel.uid)
  if sel then return sel end
  local best, bs
  for _, e in ipairs(G.enemies) do
    local s = (e.def.boss and 1e9 or 0) + e.raid * 1e6 + e.hp
    if not bs or s > bs then best, bs = e, s end
  end
  return best
end
function G.tetStrike()
  local S = G.S
  local t = G.tetTarget()
  if not G.tetReady() or not t then FX.play("err") return end
  S.tetCharge = 0
  S.tetStrikes = (S.tetStrikes or 0) + 1
  if G.meme then G.meme("tet") end
  local tx, ty = t.x, t.y
  local hit = 0
  for k = #G.enemies, 1, -1 do
    local e = G.enemies[k]
    if (e.x - tx) ^ 2 + (e.y - ty) ^ 2 <= 3 * 3 then
      local dmg = e.def.boss and e.max * 0.15 or math.max(e.max * 0.75, G.fleetPower * 4)
      G.damageEnemy(e, dmg * G.weather.def.strike)
      hit = hit + 1
    end
  end
  local px, py = G.toPx(tx, ty)
  G.tetBeam = {x = px, y = py, t = 0}
  FX.flashTo(C.white, 0.5)
  FX.shake = math.max(FX.shake, 18)
  FX.burst(px, py, 120, C.white, 500, 3)
  FX.burst(px, py, 80, C.line, 300, 2)
  for k = 1, 3 do FX.wave(px, py, 10 * k, C.white, 260 + k * 80, 0.9) end
  FX.play("boom", 0.6, 1)
  FX.play("surge", 1.4, 0.7)
  G.addFeed("TET STRIKE // " .. hit .. " CONTACTS HIT", C.white)
end

function G.mapExtraUpdate(dt)
  for _, e in ipairs(G.enemies) do
    if e.bounty and e.bounty > 0 then
      e.bounty = e.bounty - dt
      if e.bounty <= 0 then FX.toast("BOUNTY EXPIRED", "The mothership still has to go down to clear the zone.", C.dim) end
    end
  end
  local S = G.S
  local w = G.weather
  w.t = w.t - dt
  w.wind = w.wind + dt * 0.05
  if w.t <= 0 then nextWeather() end
  S.tetCharge = math.min(1, (S.tetCharge or 0) + dt / 150 * (1 + 0.25 * G.tr("map_tet")))
  if G.tetBeam then
    G.tetBeam.t = G.tetBeam.t + dt
    if G.tetBeam.t > 0.8 then G.tetBeam = nil end
  end
end

function G.tacUpdate(dt)
  local S = G.S
  if G.modal or not G.unlocked("map") then return end
  G.mapExtraUpdate(dt)
  local now = G.now()

  -- kill history (10 s buckets)
  G.killT = G.killT + dt
  if G.killT >= 10 then
    G.killT = 0
    table.insert(G.killHist, G.killAcc)
    G.killAcc = 0
    if #G.killHist > 30 then table.remove(G.killHist, 1) end
  end

  -- spawning
  spawnT = spawnT - dt
  if spawnT <= 0 then
    local frac = G.landFrac()
    spawnT = math.max(2, 14 - S.zone * 0.5) * rnd(0.7, 1.3) / (1 + 3 * frac) / (1 + 0.15 * G.tr("map_spawn")) / (G.eventActive("INVASION") and 3 or 1)
    local group = 1 + math.floor(frac * 3 + love.math.random() * 0.8)
    for _ = 1, group do if #G.enemies < G.enemyCap() then G.spawnEnemy() end end
  end
  -- safety net: if nothing is left to claim, the mothership comes anyway (a zone can never dead-end)
  frontierT = frontierT - dt
  if frontierT <= 0 then
    frontierT = 3
    G.noFrontier = false
    if not S.bossDown and G.claimed > 0 then
      G.noFrontier = true
      for i = 1, G.MW * G.MH do
        if S.map.cells[i] == 3 or G.claimable(i) then G.noFrontier = false break end
      end
    end
  end
  if (S.alert or 0) < 0 then S.alert = math.min(0.9, G.landFrac()) end -- saves from before the alert meter
  if not S.bossDown and G.landCount > 0 and ((S.alert or 0) >= 1 or G.noFrontier) then
    local alive = false
    for _, e in ipairs(G.enemies) do if e.def.boss then alive = true break end end
    if not alive then G.spawnEnemy("MOTHERSHIP") end
  end

  -- enemies: march on the nearest secured sector and raid it
  for _, e in ipairs(G.enemies) do
    e.flash = math.max(0, e.flash - dt * 4)
    if not e.tgt or S.map.cells[e.tgt] ~= 2 then
      e.tgt = nearestClaimed(e.x, e.y)
      e.raid, e.warned = 0, false
    end
    if e.tgt then
      local tx, ty = G.xy(e.tgt)
      local left = moveToward(e, tx, ty, e.def.spd, dt)
      if left < 0.2 then
        e.raid = e.raid + dt / (e.def.boss and 6 or 12)
        if not e.warned then
          e.warned = true
          FX.toast("SECTOR " .. G.cellName(e.tgt) .. " UNDER ATTACK", e.def.id .. " raiding. Engage before the sector falls.", C.red)
          FX.play("raid", 1, 0.7)
          G.raidAlert = 3
        end
        if e.raid >= 1 then
          S.map.cells[e.tgt] = 1
          G.addFeed("SECTOR " .. G.cellName(e.tgt) .. " LOST TO " .. e.def.id, C.red)
          FX.toast("SECTOR " .. G.cellName(e.tgt) .. " LOST", "Scavs overran the sector. Re-secure it with a drone.", C.red)
          FX.play("err", 0.5)
          G.recalc()
          e.tgt, e.raid = nil, 0
        end
      end
    else
      e.wob = e.wob + dt
      moveToward(e, G.TX + math.cos(e.wob * 0.3) * 5, G.TY + math.sin(e.wob * 0.4) * 4, e.def.spd * 0.5, dt)
    end
  end
  if G.raidAlert then
    G.raidAlert = G.raidAlert - dt
    if G.raidAlert <= 0 then G.raidAlert = nil end
  end

  -- tower turret
  turretT = turretT - dt
  if G.turretBeam then
    G.turretBeam.t = G.turretBeam.t - dt
    if G.turretBeam.t <= 0 then G.turretBeam = nil end
  end
  if turretT <= 0 then
    turretT = 0.6
    local range = (S.pupg.turret and 3.5 or 2.5) + 0.5 * G.tr("map_turret")
    local best, bd
    for _, e in ipairs(G.enemies) do
      local d = math.sqrt((e.x - G.TX) ^ 2 + (e.y - G.TY) ^ 2)
      if d <= range and (not bd or d < bd) then best, bd = e, d end
    end
    if best then
      G.turretBeam = {x = best.x, y = best.y, t = 0.15}
      G.damageEnemy(best, 3 * G.zoneF() * (S.pupg.turret and 5 or 1) * (1 + 0.5 * G.tr("map_turret")) * 1.2 ^ G.tr("od_map") * 0.6 * (1 + 0.05 * S.rank))
      if onMap() then FX.play("laser", 0.8, 0.5) end
    end
  end

  -- drones
  local engaged = {}
  for _, d in ipairs(S.drones) do
    d.beam = math.max(0, (d.beam or 0) - dt)
    local maxHp = G.droneMaxHp(d)
    d.hp = d.hp or maxHp
    if G.isDown(d) then
      d.px, d.py, d.hunt = G.TX, G.TY, nil
    elseif d.mission then
      local m = d.mission
      local p = clamp((now - m.start) / math.max(1, m.ends - m.start), 0, 1)
      local cx, cy = G.xy(m.cell)
      d.px, d.py = G.TX + (cx - G.TX) * math.min(1, p * 1.6), G.TY + (cy - G.TY) * math.min(1, p * 1.6)
    elseif d.hunt then
      local e = G.findEnemy(d.hunt)
      if not e then
        d.hunt = nil
      else
        local o = {x = d.px, y = d.py}
        local left = moveToward(o, e.x, e.y, G.droneSpeed(d), dt)
        d.px, d.py = o.x, o.y
        if left < 0.55 then
          engaged[e] = engaged[e] or {}
          table.insert(engaged[e], d)
          d.fire = (d.fire or 0) - dt
          if d.fire <= 0 then
            d.fire = 0.5
            d.beam = 0.12
            G.damageEnemy(e, G.droneDps(d) * 0.5)
          end
        end
      end
    else
      local o = {x = d.px, y = d.py}
      local left = moveToward(o, G.TX, G.TY, G.droneSpeed(d), dt)
      d.px, d.py = o.x, o.y
      if left < 0.1 then d.hp = math.min(maxHp, d.hp + maxHp * 0.15 * dt) end
    end
  end
  -- scavs hit back
  for e, ds in pairs(engaged) do
    if not e.dead then
      local per = e.dps * dt / #ds
      for _, d in ipairs(ds) do
        d.hp = d.hp - per
        if d.hp <= 0 then
          d.down = now + (S.pupg.repair and 14 or 40)
          if G.meme then G.meme("mia") end
          d.hunt = nil
          d.hp = G.droneMaxHp(d)
          if onMap() then
            local px, py = G.toPx(d.px, d.py)
            FX.burst(px, py, 30, C.red, 220)
            FX.play("boom", 1.6, 0.5)
          end
          G.addFeed("DRONE " .. d.id .. " MISSING IN ACTION", C.red)
        end
      end
    end
  end

  -- automation: auto-claim and auto-hunt
  claimT = claimT - dt
  if claimT <= 0 then
    claimT = 2
    if S.autoClaim then
      -- keep enough drones fighting: up to 40% of the fleet (one per scav), counting those already hunting
      local hunters = 0
      for _, d in ipairs(S.drones) do if d.hunt then hunters = hunters + 1 end end
      local want = math.min(#G.enemies, math.floor(#S.drones * 0.4))
      G.dispatchAll(true, math.max(0, want - hunters))
    end
  end
  huntT = huntT - dt
  if huntT <= 0 then
    huntT = 0.5
    if S.autoHunt and #G.enemies > 0 then
      local hunters = {}
      for _, d in ipairs(S.drones) do if d.hunt then hunters[d.hunt] = (hunters[d.hunt] or 0) + 1 end end
      for _, d in ipairs(S.drones) do
        if G.droneReady(d) and d.hp >= G.droneMaxHp(d) * 0.6 then
          local best, bs
          for _, e in ipairs(G.enemies) do
            local dist = math.sqrt((e.x - d.px) ^ 2 + (e.y - d.py) ^ 2)
            local sc = dist + (hunters[e.uid] or 0) * 2.5 - (e.raid > 0 and 6 or 0) - (e.def.boss and 4 or 0)
            if not bs or sc < bs then best, bs = e, sc end
          end
          if best then
            d.hunt = best.uid
            hunters[best.uid] = (hunters[best.uid] or 0) + 1
          end
        end
      end
    end
  end

  -- crates: tractor beam auto-opens
  for k = #S.crateList, 1, -1 do
    local c = S.crateList[k]
    c.t = (c.t or 0) + dt
    if S.pupg.tractor and c.t >= 8 then G.openCrate(k, c.r < 4) end
  end
end

----------------------------------------------------------------------
-- Mothership + fleet autopilot (auto-loadout, auto-upgrade, auto-salvage)
----------------------------------------------------------------------
G.BOUNTY_TIME = 300
function G.boss()
  for _, e in ipairs(G.enemies) do if e.def.boss then return e end end
end

G.SALVAGE_STEPS = {0, 1, 2, 3, 4}
function G.cycleAutoSalvage()
  local S = G.S
  local cur = 1
  for k, v in ipairs(G.SALVAGE_STEPS) do if v == (S.autoSalvage or 0) then cur = k end end
  S.autoSalvage = G.SALVAGE_STEPS[cur % #G.SALVAGE_STEPS + 1]
  FX.play("tick", 1.2)
end
function G.autoSalvageLabel()
  local v = G.S.autoSalvage or 0
  return v == 0 and "OFF" or ("<= " .. LOOT[v].name)
end

-- the drone whose next upgrade is cheapest, strongest drones first on ties
local function upgradeTarget()
  local S = G.S
  local best, bk, bc
  for k, d in ipairs(S.drones) do
    local c = G.droneUpCost(d)
    if not bc or c < bc or (c == bc and G.dronePower(d) > G.dronePower(best)) then best, bk, bc = d, k, c end
  end
  return best, bk, bc
end

local pilotT = 0
function G.autopilotUpdate(dt)
  local S = G.S
  pilotT = pilotT + dt
  if pilotT < 1 then return end
  pilotT = 0
  if G.modal or G.drag then return end
  -- upgrades: spend parts on the cheapest upgrade, a few per second
  if S.autoUpgrade then
    local n = 0
    while n < 5 do
      local d, _, c = upgradeTarget()
      if not d or S.parts < c then break end
      S.parts = S.parts - c
      d.lvl = d.lvl + 1
      d.hp = G.droneMaxHp(d)
      n = n + 1
    end
    if n > 0 then G.addXP(8 * n); G.recalc() end
  end
  -- modules: best modules always sit on the strongest drones
  if S.autoLoadout and G.unlocked("vault") and #S.drones > 0 then G.autoEquip(true) end
  -- salvage what is left in the vault at or below the chosen rarity
  if (S.autoSalvage or 0) > 0 then
    local total = 0
    for k = #S.modules, 1, -1 do
      if S.modules[k].r <= S.autoSalvage then total = total + G.salvageModule(k, true) end
    end
    if total > 0 then G.salvaged = (G.salvaged or 0) + total end
  end
end

return G
