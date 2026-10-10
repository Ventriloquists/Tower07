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
function G.modSalvage(m) return math.ceil(6 * D.RMUL[m.r] * (1 + 0.2 * (m.ilvl - 1))) end
function G.vaultCap() return 40 + (G.S.pupg.vault and 40 or 0) end

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
function G.autoEquip()
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
  FX.play("unlock", 1.2)
  FX.toast("AUTO-EQUIP COMPLETE", "Best modules assigned to your strongest drones.", C.line)
end

----------------------------------------------------------------------
-- Loot crates
----------------------------------------------------------------------
function G.rollTier(min)
  local t = math.min(6, min + (G.eventActive("INVASION") and 1 or 0))
  local luck = 1 + G.luck
  while t < 6 and love.math.random() < D.LOOT_UP[t + 1] * luck do t = t + 1 end
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
  if c.r == 6 then S.mythic = S.mythic + 1 end
  local lines = {}
  local e = math.max(50, G.baseCps * L.secs)
  G.gain(e)
  lines[#lines + 1] = "+" .. fmt(e) .. " ENERGY"
  local pa = math.floor(L.parts * F * sal * rnd(0.8, 1.2))
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
  G.addXP(5 * c.r)
  G.recalc()
  local col = C[L.col]
  G.addFeed(L.name .. " // " .. (bestMod and lines[#lines] or lines[2]), col)
  local px, py = G.toPx(c.x, c.y)
  if sx then px, py = sx, sy end
  if quiet or (not sx and not onMap()) then return end
  FX.burst(px, py, 12 + c.r * 14, col, 160 + c.r * 60, 2)
  for i, l in ipairs(lines) do
    FX.floater(px, py - 16 - (i - 1) * 16, l, i == 1 and col or C.white, i == 1 and H.fonts.s or H.fonts.xs, 1.6 + c.r * 0.2)
  end
  if c.r >= 3 then FX.ray(px, py, col, 0.8 + c.r * 0.3, 80 + c.r * 50) end
  if c.r >= 4 then
    FX.flashTo(col, 0.15 * (c.r - 3))
    FX.shake = math.max(FX.shake, (c.r - 3) * 7)
    FX.wave(px, py, 10, col, 300, 0.8)
  end
  if c.r >= 5 then
    G.rankBanner = {t = 0, title = L.name .. " CACHE", text = table.concat(lines, "   //   "), c = col}
    FX.play(c.r == 6 and "mythic" or "jackpot")
  else
    FX.play("crate", 0.8 + c.r * 0.12)
  end
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
function G.enemyCap() return math.min(16, 4 + G.S.zone) * (G.eventActive("INVASION") and 2 or 1) end
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
  if def.boss then
    G.rankBanner = {t = 0, title = "MOTHERSHIP INBOUND", text = "Destroy it to clear " .. D.zoneName(S.zone) .. ". Guaranteed EPIC+ loot.", c = C.red}
    FX.toast("!! MOTHERSHIP DETECTED !!", "Massive scav carrier entering the sector.", C.red)
    FX.play("raid")
    FX.shake = math.max(FX.shake, 10)
  end
  return e
end

function G.damageEnemy(e, dmg)
  if e.dead then return end
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
  if e.raid > 0 then S.raidsRepelled = S.raidsRepelled + 1 end
  G.addXP(e.def.xp)
  local n = e.def.crates
  if love.math.random() < G.luck * 0.5 then n = n + 1 end
  for _ = 1, n do G.dropCrate(e.x + rnd(-0.4, 0.4), e.y + rnd(-0.4, 0.4), G.rollTier(e.def.tier)) end
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
  local dmg = (math.max(1, G.fleetPower * 0.25) + 2 * G.zoneF()) * (1 + math.min(G.strikeCombo, 40) * 0.05)
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

function G.tacUpdate(dt)
  local S = G.S
  if G.modal or not G.unlocked("map") then return end
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
    spawnT = math.max(3, 14 - S.zone * 0.5) * rnd(0.7, 1.3) / (G.eventActive("INVASION") and 3 or 1)
    if #G.enemies < G.enemyCap() then G.spawnEnemy() end
  end
  if not S.bossDown and G.landCount > 0 and G.claimed / G.landCount >= 0.6 then
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
    local range = S.pupg.turret and 3.5 or 2.5
    local best, bd
    for _, e in ipairs(G.enemies) do
      local d = math.sqrt((e.x - G.TX) ^ 2 + (e.y - G.TY) ^ 2)
      if d <= range and (not bd or d < bd) then best, bd = e, d end
    end
    if best then
      G.turretBeam = {x = best.x, y = best.y, t = 0.15}
      G.damageEnemy(best, 3 * G.zoneF() * (S.pupg.turret and 5 or 1) * 0.6 * (1 + 0.05 * S.rank))
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
    if S.autoClaim and #G.enemies < 3 then G.dispatchAll(true) end
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

return G
