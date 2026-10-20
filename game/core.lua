-- Game state and economy / progression logic. Tactical map logic lives in game/tac.lua.
local H = require "lib.hud"
local FX = require "game.fx"
local D = require "game.data"

local G = {}
local C, fmt, rnd, clamp = H.C, H.fmt, H.rnd, H.clamp
local GENS, UPGRADES, ACH, RAR = D.GENS, D.UPGRADES, D.ACH, D.RARITY
local R = 1.15
local S

G.OX, G.OY, G.CORE_R = 640, 262, 40 -- the tower crown (ui/reactor.lua)
G.MW, G.MH, G.TX, G.TY = 24, 15, 12, 8
G.TIDX = (G.TY - 1) * G.MW + G.TX
G.BUYMODES = {1, 10, 100, "MAX"}
G.buyMode = 1
G.tab = "core"
-- scroll offsets per scrollable region (default 0)
G.scroll = setmetatable({}, {__index = function() return 0 end})
G.maxScroll = setmetatable({}, {__index = function() return 0 end})
G.time, G.sessionTime, G.warp = 0, 0, 0
G.buffs = {}
G.combo, G.lastClick, G.surge = 0, -10, 0
G.signal, G.signalTimer = nil, 25
G.coreKick = 0
G.hist, G.histAcc, G.histT = {}, 0, 0
G.choiceQueue = {}
G.report = nil
G.dailyPending = false
G.rankBanner = nil
G.novaConfirm = 0
G.scrapConfirm = nil
G.mapSel = nil
G.modal = false
G.genEach, G.genUp = {}, {}
G.baseCps, G.globalMult, G.clickMult, G.clickCpsPct, G.cometFreq, G.cometDur, G.achCount = 0, 1, 1, 0, 1, 1, 0
G.autoRate, G.hydroMult, G.droneMult, G.claimed, G.landCount = 0, 1, 1, 0, 0
G.luck, G.critChance, G.fleetPower = 0, 0.05, 0
G.land = {}
G.dispDust = 0
G.rigFull = {}
G.enemies, G.lootFeed = {}, {}

local clockBase, timerBase = os.time(), love.timer.getTime()
function G.now() return clockBase + (love.timer.getTime() - timerBase) + G.warp end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
function G.newState()
  local s = {stardust = 0, runEarned = 0, runTime = 0, totalEarned = 0, clicks = 0, comets = 0, maxCombo = 0,
    upBought = 0, bestCps = 0, gens = {}, ubt = {}, upg = {}, ach = {}, pupg = {}, dm = 0, dmTotal = 0,
    prestiges = 0, playTime = 0, lastSave = os.time(), startTime = os.time(), unitsBought = 0,
    xp = 0, rank = 1, tokens = 0, hydro = 0, parts = 0,
    rigs = {{on = true, lvl = 1, tank = 0}, {on = false, lvl = 1, tank = 0}, {on = false, lvl = 1, tank = 0}},
    rigCollects = 0, drones = {}, fabsTotal = 0, pity = 0, pityP = 0, protoEver = 0, omegaEver = 0,
    claimsTotal = 0, artifacts = 0, map = {seed = 0, cells = {}}, directives = {}, dirDone = 0, rerollAt = 0,
    daily = {last = "", streak = 0}, bestStreak = 0, jackpots = 0, archive = 0,
    zone = 1, zoneBest = 0, bossDown = false, kills = 0, bosses = 0, crates = 0, legendary = 0, mythic = 0,
    raidsRepelled = 0, modules = {}, crateList = {}, modUid = 0,
    autoTech = false, autoUnits = false, autoRigs = false, autoRigUp = false, autoHunt = true, autoClaim = false,
    combines = 0, tetCharge = 0, tetStrikes = 0, autoFuse = 0, fiestas = 0, fiestaPulls = 0, bestChain = 0, alert = -1,
    autoLoadout = true, autoUpgrade = false, autoSalvage = 0, bounties = 0, rhythms = 0, overheats = 0, mythicRolls = 0, transmutes = 0, forged = 0, promoted = 0,
    perks = {}, perkPoints = 0, sxp = 0, passTier = 0, passClaimed = 0, achClaim = {}, logClaims = 0,
    rarityEver = {0, 0, 0, 0, 0, 0}, prismEver = 0, prismatic = 0, respects = 0, over9000 = false, doubled = 0}
  for i = 1, #GENS do s.gens[i] = 0; s.ubt[i] = 0 end
  return s
end

function G.unlocked(tab)
  for _, a in ipairs(D.ARCHIVE) do
    if a.unlock == tab then return G.achCount >= a.n, a.n end
  end
  return true
end
function G.perk(id) return (S and S.perks[id]) or 0 end
function G.eventActive(id) return G.event ~= nil and G.event.def.id == id end
function G.hasArchive(key)
  for _, a in ipairs(D.ARCHIVE) do
    if a[key] then return G.achCount >= a.n, a.n end
  end
  return false, 0
end

----------------------------------------------------------------------
-- Map grid
----------------------------------------------------------------------
function G.idx(x, y) return (y - 1) * G.MW + x end
function G.xy(i) return (i - 1) % G.MW + 1, math.floor((i - 1) / G.MW) + 1 end
function G.cellName(i) local x, y = G.xy(i) return string.char(64 + x) .. y end
function G.dist(i) local x, y = G.xy(i) return math.sqrt((x - G.TX) ^ 2 + (y - G.TY) ^ 2) end
function G.zoneF() return 1.6 ^ (S.zone - 1) end
function G.baseThreat(i) return math.max(1, math.floor(G.dist(i) * 0.9)) end
function G.threat(i) return G.baseThreat(i) * G.zoneF() end

-- terrain height field (continuous, in cell units); land is where it is above 0.46
function G.terrainH(x, y)
  local sd = S.map.seed
  return love.math.noise(x * 0.14 + sd, y * 0.14 + sd * 0.7) * 0.7 + love.math.noise(x * 0.4 + sd * 1.3, y * 0.4 - sd) * 0.3
end
function G.buildTerrain()
  local sd = S.map.seed
  G.land, G.landCount = {}, 0
  for y = 1, G.MH do
    for x = 1, G.MW do
      local n = love.math.noise(x * 0.14 + sd, y * 0.14 + sd * 0.7) * 0.7
        + love.math.noise(x * 0.4 + sd * 1.3, y * 0.4 - sd) * 0.3
      local d = math.sqrt((x - G.TX) ^ 2 + (y - G.TY) ^ 2)
      local land = n > 0.46 or d < 1.6
      G.land[G.idx(x, y)] = land
    end
  end
  -- every island gets a land bridge to the tower's territory, so all land can be claimed
  -- (otherwise unreachable land counts against the 60% mothership threshold and the zone soft-locks)
  for _ = 1, 50 do
    local seen = G.reachableLand()
    local bi, bj, bd
    for i = 1, G.MW * G.MH do
      if G.land[i] and not seen[i] then
        local x, y = G.xy(i)
        for j in pairs(seen) do
          local x2, y2 = G.xy(j)
          local d = (x - x2) ^ 2 + (y - y2) ^ 2
          if not bd or d < bd then bi, bj, bd = i, j, d end
        end
      end
    end
    if not bi then break end
    local x, y = G.xy(bj)
    local tx, ty = G.xy(bi)
    while x ~= tx or y ~= ty do
      x = x + (tx > x and 1 or (tx < x and -1 or 0))
      y = y + (ty > y and 1 or (ty < y and -1 or 0))
      G.land[G.idx(x, y)] = true
    end
  end
  for i = 1, G.MW * G.MH do if G.land[i] then G.landCount = G.landCount + 1 end end
  G.landCount = G.landCount - 1 -- tower
end

-- land cells connected to the tower (8-neighbour flood fill, the same adjacency claims use)
function G.reachableLand()
  local seen, stack, n = {[G.TIDX] = true}, {G.TIDX}, 0
  while #stack > 0 do
    local i = table.remove(stack)
    n = n + 1
    local x, y = G.xy(i)
    for dy = -1, 1 do
      for dx = -1, 1 do
        local nx, ny = x + dx, y + dy
        if nx >= 1 and nx <= G.MW and ny >= 1 and ny <= G.MH then
          local j = G.idx(nx, ny)
          if G.land[j] and not seen[j] then seen[j] = true; stack[#stack + 1] = j end
        end
      end
    end
  end
  return seen, n
end

-- dev: --mapdiag writes why the map might be stuck
function G.mapReport()
  local _, reach = G.reachableLand()
  local best = 0
  for _, d in ipairs(S.drones) do best = math.max(best, G.claimPower(d)) end
  local claimable, minT, ok = 0, math.huge, 0
  for i = 1, G.MW * G.MH do
    if G.claimable(i) then
      claimable = claimable + 1
      minT = math.min(minT, G.threat(i))
      if G.threat(i) <= best then ok = ok + 1 end
    end
  end
  local boss = G.boss and G.boss()
  return string.format("zone=%d land=%d reachable=%d claimed=%d (%.0f%% of land) alert=%.0f%% bossDown=%s boss=%s\n" ..
    "claimable=%d affordable=%d minThreat=%s bestClaimPower=%s drones=%d enemies=%d",
    S.zone, G.landCount, reach - 1, G.claimed, G.landCount > 0 and G.claimed / G.landCount * 100 or 0, (S.alert or 0) * 100, tostring(S.bossDown),
    boss and string.format("hp %.3g/%.3g", boss.hp, boss.max) or "none", claimable, ok, fmt(minT), fmt(best), #S.drones, #G.enemies)
end

function G.revealAround(cx, cy, r)
  for y = 1, G.MH do
    for x = 1, G.MW do
      if (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r then
        local i = G.idx(x, y)
        if S.map.cells[i] == 0 then S.map.cells[i] = 1 end
      end
    end
  end
end

function G.newMap()
  S.map = {seed = love.math.random() * 1000, cells = {}}
  for i = 1, G.MW * G.MH do S.map.cells[i] = 0 end
  G.buildTerrain()
  G.revealAround(G.TX, G.TY, (S.pupg.carto and 4 or 2) + G.tr("map_scan"))
  S.map.cells[G.TIDX] = 2
  S.bossDown = false
  S.alert = 0
  G.enemies = {}
  for _, d in ipairs(S.drones) do
    d.mission, d.hunt = nil, nil
    d.px, d.py = G.TX, G.TY
  end
end

function G.cellLoot(i)
  if not G.land[i] or i == G.TIDX then return nil end
  local v = math.sin(i * 12.9898 + S.map.seed * 78.233) * 43758.5453
  local h = v - math.floor(v)
  if h < 0.03 then return "ARTIFACT" elseif h < 0.06 then return "WRECK"
  elseif h < 0.16 then return "SALVAGE" elseif h < 0.30 then return "CACHE" end
end

function G.adjClaimed(i)
  local x, y = G.xy(i)
  local rg = 1 + G.tr("map_range")
  for dy = -rg, rg do
    for dx = -rg, rg do
      local nx, ny = x + dx, y + dy
      if (dx ~= 0 or dy ~= 0) and nx >= 1 and nx <= G.MW and ny >= 1 and ny <= G.MH
        and S.map.cells[G.idx(nx, ny)] == 2 then return true end
    end
  end
  return false
end
function G.claimable(i) return G.land[i] and S.map.cells[i] == 1 and G.adjClaimed(i) end

----------------------------------------------------------------------
-- Drones
----------------------------------------------------------------------
function G.hasTrait(d, t)
  for _, x in ipairs(d.traits) do if x == t then return true end end
  return false
end
function G.modSum(d, t)
  local s = 0
  for _, m in ipairs(d.mods) do if m.t == t then s = s + m.v end end
  return s
end
function G.dronePower(d)
  return RAR[d.r].power * 1.6 ^ (d.mk - 1) * (1 + 0.5 * (d.lvl - 1)) * (1 + G.modSum(d, "PWR")) * (1 + 0.1 * G.perk("HUNTER")) * (1 + 0.2 * G.tr("fl_power")) * 1.2 ^ G.tr("od_fleet")
end
function G.droneBonus(d)
  local b = RAR[d.r].bonus * (1 + 0.5 * (d.lvl - 1)) * (1 + G.modSum(d, "YLD")) * (1 + 0.15 * G.tr("fl_yield"))
  if G.hasTrait(d, "HARVESTER") then b = b * 2 end
  return b
end
function G.droneMaxHp(d)
  local h = 10 * G.dronePower(d) * (1 + G.modSum(d, "ARM")) * (1 + 0.25 * G.tr("fl_hull"))
  if G.hasTrait(d, "JUGGERNAUT") then h = h * 2 end
  return h
end
function G.droneSpeed(d)
  local s = 1.5 * (1 + G.modSum(d, "SPD")) * (1 + 0.1 * G.tr("fl_speed"))
  if G.hasTrait(d, "SPRINTER") then s = s * 1.6 end
  return s * (G.weatherSpeed and G.weatherSpeed() or 1)
end
function G.droneDps(d)
  local p = G.dronePower(d) * (1 + 0.2 * G.tr("fl_dps")) * 1.2 ^ G.tr("od_map")
  if G.hasTrait(d, "HUNTER") then p = p * 1.6 end
  return p
end
function G.claimPower(d)
  local p = G.dronePower(d)
  if G.hasTrait(d, "ENGINEER") then p = p * 1.5 end
  return p
end
function G.isDown(d) return d.down and G.now() < d.down end
function G.droneStatus(d)
  if G.isDown(d) then return "MISSING" end
  if d.mission then return "CLAIM" end
  if d.hunt then return "HUNT" end
  return "IDLE"
end
function G.droneReady(d) return not d.mission and not d.hunt and not G.isDown(d) end
function G.droneUpCost(d) return math.ceil(3 * RAR[d.r].upk * d.lvl ^ 1.6) end
function G.bayCap() return 15 + (S.pupg.bay and 6 or 0) + 2 * G.tr("fl_bay") end
function G.fabCostAt(total)
  local m = math.max(0.4, 1 - 0.05 * G.perk("FABDISC")) * (1 - 0.05 * G.tr("fl_fab")) * (G.eventActive("FRENZY") and 0.5 or 1)
  return math.max(1, math.floor(20 * 1.07 ^ math.min(total, 120) * m))
end
function G.fabCost() return G.fabCostAt(S.fabsTotal) end

function G.normalizeDrone(d)
  d.lvl = d.lvl or 1
  d.mk = d.mk or 1
  d.mods = type(d.mods) == "table" and d.mods or {}
  if type(d.traits) ~= "table" or #d.traits == 0 then d.traits = {D.TRAITS[love.math.random(#D.TRAITS)].id} end
  d.px, d.py = d.px or G.TX, d.py or G.TY
  d.hunt = nil
  if type(d.name) ~= "string" then d.name = G.nameFor(d.r) end -- older saves had no callsigns
  return d
end

----------------------------------------------------------------------
-- Combine: 3 drones of the same rarity -> 1 drone of the next rarity
----------------------------------------------------------------------
function G.findDrone(id)
  for k, d in ipairs(S.drones) do if d.id == id then return d, k end end
end
-- PRISM is drop-only: fusion tops out at OMEGA
G.FUSE_TOP = 5
function G.canCombine(d) return d and d.r < G.FUSE_TOP and not d.mission and not G.isDown(d) end
function G.combineEligible(r, exclude)
  local list = {}
  for _, d in ipairs(S.drones) do
    if d.r == r and G.canCombine(d) and not (exclude and exclude[d.id]) then list[#list + 1] = d end
  end
  table.sort(list, function(a, b) return G.dronePower(a) < G.dronePower(b) end)
  return list
end
-- the result keeps the best MK and level, the first drone's callsign, and inherits traits from the inputs
function G.combinePreview(ds)
  local r = ds[1].r + 1
  local mk, lvl = 1, 1
  for _, d in ipairs(ds) do mk = math.max(mk, d.mk); lvl = math.max(lvl, d.lvl) end
  return {r = r, mk = mk, lvl = lvl, slots = RAR[r].slots, traits = RAR[r].traits}
end
function G.combineDrones(ids)
  local ds = {}
  for _, id in ipairs(ids) do
    local d = G.findDrone(id)
    if not G.canCombine(d) then return nil, "All three drones must be idle and below the top rarity." end
    ds[#ds + 1] = d
  end
  if #ds ~= 3 then return nil, "Select three drones." end
  if ds[1].r ~= ds[2].r or ds[1].r ~= ds[3].r then return nil, "Drones must share the same rarity." end
  for _, d in ipairs(ds) do
    local _, k = G.findDrone(d.id)
    table.remove(S.drones, k)
  end
  local nd = G.fuseResult(ds)
  G.addDrone(nd)
  S.combines = (S.combines or 0) + 1
  G.hangarSel = nd.id
  G.addXP(40 * nd.r)
  return nd
end
-- builds the fused drone from three inputs without touching the fleet; their modules go to the vault
function G.fuseResult(ds)
  local p = G.combinePreview(ds)
  -- inherit traits: pool of all input traits, plus fresh rolls if the pool is short
  local pool, seen = {}, {}
  for _, d in ipairs(ds) do
    for _, t in ipairs(d.traits) do if not seen[t] then seen[t] = true; pool[#pool + 1] = t end end
  end
  local traits = {}
  while #traits < p.traits and #pool > 0 do traits[#traits + 1] = table.remove(pool, love.math.random(#pool)) end
  while #traits < p.traits do
    local t = D.TRAITS[love.math.random(#D.TRAITS)].id
    local dup = false
    for _, x in ipairs(traits) do if x == t then dup = true end end
    if not dup then traits[#traits + 1] = t end
  end
  for _, d in ipairs(ds) do
    for _, m in ipairs(d.mods) do table.insert(S.modules, m) end
  end
  local nd = {id = ds[1].id, r = p.r, lvl = p.lvl + G.tr("fl_fuse"), mk = p.mk, mods = {}, traits = traits,
    name = ds[1].name, px = G.TX, py = G.TY}
  if p.r >= 4 and not nd.name:find(" ") then nd.name = G.grandName(nd.name) end
  return nd
end

-- auto-fuse: S.autoFuse is the highest rarity it may create (0 = off). Locked drones are never touched.
G.AUTOFUSE = {0, 3, 4, 5}
function G.autoFuseOk(d) return G.canCombine(d) and not d.lock and d.r + 1 <= (S.autoFuse or 0) end
function G.cycleAutoFuse()
  local cur = 1
  for k, v in ipairs(G.AUTOFUSE) do if v == (S.autoFuse or 0) then cur = k end end
  S.autoFuse = G.AUTOFUSE[cur % #G.AUTOFUSE + 1]
  FX.play("tick", 1.2)
end
function G.autoFuseLabel()
  local v = S.autoFuse or 0
  return v == 0 and "OFF" or ("UP TO " .. RAR[v].name)
end
-- fuses groups of 3 inside a list of drones, weakest first. Returns the merge log; `list` is updated in place.
-- onFuse(inputs, result) lets the caller remove inputs from wherever they live.
function G.fuseGroups(list, cap, onFuse)
  local log, chain = {}, 0
  for r = 1, #RAR - 1 do
    if r + 1 > cap then break end
    while true do
      local grp = {}
      for _, d in ipairs(list) do if d.r == r then grp[#grp + 1] = d end end
      if #grp < 3 then break end
      table.sort(grp, function(a, b) return G.dronePower(a) < G.dronePower(b) end)
      local ds = {grp[3], grp[2], grp[1]} -- strongest of the three gives its callsign
      local nd = G.fuseResult(ds)
      for _, d in ipairs(ds) do
        for k, x in ipairs(list) do if x == d then table.remove(list, k) break end end
      end
      list[#list + 1] = nd
      chain = chain + 1
      log[#log + 1] = {r = r, ins = ds, out = nd}
      if onFuse then onFuse(ds, nd) end
    end
  end
  S.combines = (S.combines or 0) + chain
  S.bestChain = math.max(S.bestChain or 0, chain)
  return log
end
function G.autoFuseFleet()
  if (S.autoFuse or 0) < 2 then return end
  local pool = {}
  for _, d in ipairs(S.drones) do if G.autoFuseOk(d) then pool[#pool + 1] = d end end
  local log = G.fuseGroups(pool, S.autoFuse, function(ins, nd)
    for _, d in ipairs(ins) do
      local _, k = G.findDrone(d.id)
      if k then table.remove(S.drones, k) end
    end
    G.addDrone(nd)
  end)
  if #log > 0 then
    local best = log[#log].out
    G.addXP(40 * best.r * #log)
    FX.play("unlock", 1.1)
    FX.toast("AUTO-FUSE // " .. #log .. "x", "Best result: " .. RAR[best.r].name .. " " .. G.droneLabel(best), C[RAR[best.r].col])
  end
end

function G.odds()
  if S.pupg.lucky then return {0.62, 0.87, 0.965, 0.994} end
  return {0.70, 0.91, 0.98, 0.997}
end
function G.rollRarity()
  local o = G.odds()
  local x = love.math.random()
  for k = 1, #o do if x < o[k] then return k end end
  return #o + 1
end
function G.newDroneId()
  for _ = 1, 80 do
    local id = love.math.random(100, 999)
    local used = false
    for _, d in ipairs(S.drones) do if d.id == id then used = true break end end
    if not used then return id end
  end
  return love.math.random(1000, 9999)
end
-- callsigns: higher rarities get a second, grander word
local CALL_A = {"GHOST", "VIPER", "NOMAD", "RAVEN", "WARDEN", "ECHO", "SPECTER", "HALO", "KESTREL", "FALCON",
  "MANTIS", "WRAITH", "COBALT", "EMBER", "ONYX", "SIGNAL", "DRIFTER", "TALON", "BEACON", "CINDER", "VESPER",
  "ORBIT", "STATIC", "TEMPEST", "QUILL", "MERIDIAN", "SENTRY", "LANTERN", "CIPHER", "HUSK", "MOTH", "SABLE",
  "PILGRIM", "ARGUS", "VECTOR", "RELIC", "JUNO", "ATLAS", "TIDE", "SPARROW"}
local CALL_B = {"PRIME", "ZERO", "NINE", "ASCENDANT", "SOVEREIGN", "ETERNAL", "OMEGA", "REX", "MAXIMUS", "INFINITE"}
local function pick(list) return list[love.math.random(#list)] end
function G.droneName()
  local used = {}
  for _, d in ipairs(S.drones) do if d.name then used[d.name] = true end end
  for _ = 1, 30 do
    local n = pick(CALL_A)
    if not used[n] then return n end
  end
  return CALL_A[love.math.random(#CALL_A)] .. "-" .. love.math.random(2, 9)
end
function G.grandName(n) return n .. " " .. pick(CALL_B) end
function G.nameFor(r)
  local n = G.droneName()
  if r >= 4 then n = G.grandName(n) end
  return n
end
function G.droneLabel(d) return d.id .. " " .. (d.name or "") end

function G.makeDrone(r)
  local d = {id = G.newDroneId(), r = r, lvl = 1, mk = S.zone, mods = {}, traits = {}, name = G.nameFor(r)}
  local pool = {}
  for _, t in ipairs(D.TRAITS) do pool[#pool + 1] = t.id end
  for _ = 1, RAR[r].traits do
    d.traits[#d.traits + 1] = table.remove(pool, love.math.random(#pool))
  end
  d.px, d.py = G.TX, G.TY
  return d
end
function G.countPull(d)
  S.rarityEver[d.r] = (S.rarityEver[d.r] or 0) + 1
  if d.r == 4 then S.protoEver = S.protoEver + 1 end
  if d.r == 5 then S.omegaEver = S.omegaEver + 1 end
  if d.r == 6 then S.prismEver = (S.prismEver or 0) + 1 end
end
function G.addDrone(d, noCount)
  for _, o in ipairs(S.drones) do if o.id == d.id then d.id = G.newDroneId() break end end
  table.insert(S.drones, d)
  if not noCount then G.countPull(d) end
  d.hp = G.droneMaxHp(d)
  G.recalc()
  return d
end

-- fabrication: roll 3 candidates, player keeps one
function G.pityCaps() return 10 - G.tr("fl_pity"), 50 - 5 * G.tr("fl_pity") end
function G.rollCandidates()
  local c = {}
  for k = 1, 3 do c[k] = G.rollRarity() end
  S.pity, S.pityP = S.pity + 1, S.pityP + 1
  local best = math.max(c[1], c[2], c[3])
  local pe, pp = G.pityCaps()
  if best < 3 and S.pity >= pe then c[love.math.random(3)] = 3; best = 3 end
  if best < 4 and S.pityP >= pp then c[love.math.random(3)] = 4; best = 4 end
  if best >= 3 then S.pity = 0 end
  if best >= 4 then S.pityP = 0 end
  local ds = {}
  for k = 1, 3 do ds[k] = G.makeDrone(c[k]) end
  -- flip order: random, but the best card always flips last for suspense
  local order = {1, 2, 3}
  for k = 3, 2, -1 do local j = love.math.random(k); order[k], order[j] = order[j], order[k] end
  local bi = 1
  for k = 2, 3 do if c[k] > c[bi] then bi = k end end
  for k = 1, 3 do if order[k] == bi then order[k], order[3] = order[3], order[k] end end
  return {cands = ds, order = order, t = 0, flipped = {}, best = best}
end
function G.fabricate(n, useToken)
  local made = 0
  for _ = 1, n or 1 do
    if #S.drones + #G.choiceQueue >= G.bayCap() then break end
    if useToken then
      if S.tokens < 1 then break end
      S.tokens = S.tokens - 1
    else
      local c = G.fabCost()
      if S.hydro < c then break end
      S.hydro = S.hydro - c
    end
    S.fabsTotal = S.fabsTotal + 1
    made = made + 1
    table.insert(G.choiceQueue, G.rollCandidates())
  end
  if made == 0 then
    FX.play("err")
  else G.addXP(20 * made) end
  return made
end
function G.cardX(k) return 640 + (k - 2) * 250 end
G.fastReveal = false
function G.revealScale() return G.fastReveal and 0.3 or 1 end
function G.flipTime(ch, pos)
  local t = 0.6 + (pos - 1) * 0.55
  if pos == 3 and ch.best >= 4 then t = t + 0.6 end -- extra suspense
  return t * G.revealScale()
end
function G.choiceReady(ch) return ch.t >= G.flipTime(ch, 3) + 0.15 end

-- drone reveals speak the SIGNAL LOCK language too: the lock frames the card (w, h), the tag decodes the class.
-- Drone classes map onto the loot ladder: STD 1, ADV 2, ELITE 4, PROTO 5, OMEGA 6, PRISM 7.
local DRONE_TIER = {1, 2, 4, 5, 6, 7}
function G.revealFX(r, x, y, picked, label, w, h)
  local c = C[RAR[r].col]
  local tier = DRONE_TIER[r] or r
  FX.lock(x, y, tier, c, (label or RAR[r].name) .. (tier >= 4 and " CLASS" or ""), "", {compact = true, w = w or 120, h = h or 120})
  if r <= 2 then FX.play(r == 1 and "tick" or "buy", r == 1 and 0.7 or 1.2)
  elseif r == 3 then FX.play("unlock")
  elseif r == 4 then FX.lootSound(1)
  elseif r == 5 then FX.lootSound(2)
  else FX.prismEvent(label or RAR[r].name, x, y) end
end

function G.pickCandidate(k)
  local ch = G.choiceQueue[1]
  if not ch or not G.choiceReady(ch) then return end
  if #S.drones >= G.bayCap() then FX.play("err") return end
  local d = ch.cands[k]
  G.addDrone(d)
  local scrap = 0
  for j, o in ipairs(ch.cands) do if j ~= k then scrap = scrap + math.ceil(RAR[o.r].scrap * 0.5) end end
  S.parts = S.parts + scrap
  table.remove(G.choiceQueue, 1)
  G.revealFX(d.r, G.cardX(k), 360, true, nil, 220, 300)
  FX.toast(G.droneLabel(d) .. " JOINS THE FLEET", RAR[d.r].name .. " MK" .. d.mk .. " // " .. table.concat(d.traits, " + ") ..
    "  //  +" .. scrap .. " parts from recycled units", C[RAR[d.r].col])
end

function G.upgradeDrone(k)
  local d = S.drones[k]
  if not d then return end
  local c = G.droneUpCost(d)
  if S.parts < c then FX.play("err") return end
  S.parts = S.parts - c
  d.lvl = d.lvl + 1
  d.hp = G.droneMaxHp(d)
  G.addXP(8)
  G.recalc()
  FX.play("buy", 1.1 + math.min(d.lvl, 30) * 0.03)
  local mx, my = require("lib.view").mouse()
  FX.burst(mx, my, 16, C[RAR[d.r].col], 180)
end
function G.scrapDrone(k)
  local d = S.drones[k]
  if not d then return end
  if d.lock then FX.toast("DRONE LOCKED", "Unlock " .. G.droneLabel(d) .. " before scrapping it.", C.red); FX.play("err") return end
  if d.mission and S.map.cells[d.mission.cell] == 3 then S.map.cells[d.mission.cell] = 1 end
  for _, m in ipairs(d.mods) do table.insert(S.modules, m) end
  local p = RAR[d.r].scrap * d.lvl
  S.parts = S.parts + p
  table.remove(S.drones, k)
  G.scrapConfirm = nil
  G.recalc()
  FX.toast(G.droneLabel(d) .. " SCRAPPED", "+" .. p .. " parts recovered. Modules returned to vault.", C.red)
  FX.play("err", 0.6)
end

function G.bestDroneFor(i)
  local th = G.threat(i)
  local best
  for _, d in ipairs(S.drones) do
    if G.droneReady(d) and G.claimPower(d) >= th and (not best or G.claimPower(d) < G.claimPower(best)) then best = d end
  end
  return best
end
function G.idleCount()
  local n = 0
  for _, d in ipairs(S.drones) do if G.droneReady(d) then n = n + 1 end end
  return n
end
function G.missionTime(i, d)
  local t = (15 + G.baseThreat(i) * 8) * (S.pupg.rapid and 0.5 or 1)
  if G.isRadiation and G.isRadiation(i) then t = t * (2 - 0.25 * G.tr("map_rad")) end
  if G.weatherMission then t = t * G.weatherMission() end
  if d then
    t = t / (1 + G.modSum(d, "SPD"))
    if G.hasTrait(d, "SPRINTER") then t = t * 0.6 end
    -- the more claim power exceeds the sector threat, the faster the claim (down to 12% of the time)
    t = t * math.max(0.12, math.min(1, (G.threat(i) / math.max(1e-9, G.claimPower(d))) ^ 0.35))
  end
  return t
end
function G.deploy(i, d)
  if not G.claimable(i) then return false end
  d = d or G.bestDroneFor(i)
  if not d then return false end
  local now = G.now()
  d.mission = {cell = i, start = now, ends = now + G.missionTime(i, d)}
  d.hunt = nil
  S.map.cells[i] = 3
  return true
end
function G.dispatchAll(quiet, reserve)
  local cells = {}
  for i = 1, G.MW * G.MH do if G.claimable(i) then cells[#cells + 1] = i end end
  table.sort(cells, function(a, b)
    local ta, tb = G.baseThreat(a), G.baseThreat(b)
    if ta ~= tb then return ta < tb end
    return a < b
  end)
  local n = 0
  for _, i in ipairs(cells) do
    if reserve and G.idleCount() <= reserve then break end
    if G.deploy(i) then n = n + 1 end
  end
  if not quiet then if n > 0 then FX.play("signal", 1.3, 0.5) else FX.play("err") end end
  return n
end

function G.claimCell(i)
  S.map.cells[i] = 2
  if G.raiseAlert then G.raiseAlert(G.claimAlert()) end
  S.claimsTotal = S.claimsTotal + 1
  local x, y = G.xy(i)
  G.revealAround(x, y, 1.5 + 0.5 * G.tr("map_deep"))
  local th = G.baseThreat(i)
  G.addXP(30 + th * 5)
  -- radiation sectors take twice as long but may cough up a crate (35%)
  if G.isRadiation and G.isRadiation(i) and G.dropCrate and love.math.random() < 0.35 and G.crateBudgetOk() then
    G.dropCrate(x, y, G.rollTier(math.min(5, 2 + math.floor(S.zone / 2))))
    if G.addFeed then G.addFeed("RADIATION SECTOR " .. G.cellName(i) .. " // EXTRA CRATE", C.gold) end
  end
  local loot = G.cellLoot(i)
  local text = "+2% output"
  if loot == "ARTIFACT" then
    S.artifacts = S.artifacts + 1
    text = "ARTIFACT RECOVERED // +5% output, permanent"
    FX.play("unlock")
  elseif loot == "WRECK" then
    if #S.drones < G.bayCap() then
      local d = G.addDrone(G.makeDrone(math.min(5, G.rollRarity() + 1)))
      text = "DRONE WRECK // salvaged " .. RAR[d.r].name .. " drone " .. d.id
    else
      S.parts = S.parts + 30
      text = "DRONE WRECK // bay full, +30 parts"
    end
  elseif loot == "SALVAGE" then
    local p = math.floor((5 + th * 2) * 1.35 ^ (S.zone - 1))
    S.parts = S.parts + p
    text = "SALVAGE // +" .. p .. " parts"
  elseif loot == "CACHE" then
    local e = math.max(100, G.effCps() * (120 + th * 60))
    local hy = math.floor((5 + th * 2) * 1.35 ^ (S.zone - 1))
    G.gain(e)
    S.hydro = S.hydro + hy
    text = "CACHE // +" .. fmt(e) .. " energy, +" .. hy .. " H2O"
  end
  G.recalc()
  if G.addFeed then G.addFeed("SECTOR " .. G.cellName(i) .. " // " .. (loot or "SECURED"), loot and C.orange or C.line) end
  FX.toast("SECTOR " .. G.cellName(i) .. " SECURED", text, loot and C.orange or C.line)
  FX.play("catch", 1.2, 0.6)
end

function G.missionsUpdate()
  local now = G.now()
  for _, d in ipairs(S.drones) do
    if d.mission and now >= d.mission.ends then
      local i = d.mission.cell
      d.mission = nil
      local x, y = G.xy(i)
      d.px, d.py = x, y
      if S.map.cells[i] == 3 then G.claimCell(i) end
    end
  end
end

----------------------------------------------------------------------
-- Derived values
----------------------------------------------------------------------
function G.milestoneMult(i)
  local m, o = 1, S.gens[i]
  for _, t in ipairs(D.MILESTONES) do if o >= t then m = m * 2 else break end end
  return m
end
function G.nextMilestone(i)
  local o, prev = S.gens[i], 0
  for _, t in ipairs(D.MILESTONES) do
    if o < t then return t, prev end
    prev = t
  end
  return nil, prev
end

function G.recalc()
  S = G.S
  G.achCount = 0
  for i = 1, #ACH do if S.ach[i] then G.achCount = G.achCount + 1 end end
  for i = 1, #GENS do G.genUp[i] = 1 end
  local clickMult, clickCpsPct, cometFreq, cometDur, gUp, auto, perlog, hydro = 1, 0, 1, 1, 1, 0, 0, 1
  for _, u in ipairs(UPGRADES) do
    if S.upg[u.id] then
      local e = u.eff
      if e.t == "gen" then G.genUp[e.i] = G.genUp[e.i] * e.m
      elseif e.t == "click" then clickMult = clickMult * e.m
      elseif e.t == "clickcps" then clickCpsPct = clickCpsPct + e.p
      elseif e.t == "global" then gUp = gUp * e.m
      elseif e.t == "cometfreq" then cometFreq = cometFreq * e.m
      elseif e.t == "cometdur" then cometDur = cometDur * e.m
      elseif e.t == "auto" then auto = auto + e.n
      elseif e.t == "perlog" then perlog = perlog + e.p
      elseif e.t == "hydro" then hydro = hydro * e.m end
    end
  end
  local luck = 0
  for _, a in ipairs(D.ARCHIVE) do
    if G.achCount >= a.n then
      if a.prod then gUp = gUp * a.prod end
      if a.click then clickMult = clickMult * a.click end
      if a.auto then auto = auto + a.auto end
      if a.signal then cometFreq = cometFreq * a.signal end
      if a.hydro then hydro = hydro * a.hydro end
      if a.luck then luck = luck + a.luck end
    end
  end
  local dsum, fp, crit = 0, 0, 0.05
  for _, d in ipairs(S.drones) do
    dsum = dsum + G.droneBonus(d)
    fp = fp + G.dronePower(d)
    luck = luck + G.modSum(d, "LCK") + (G.hasTrait(d, "LUCKY") and 0.15 or 0)
    crit = crit + G.modSum(d, "CRT")
  end
  G.droneMult, G.fleetPower, G.luck, G.critChance = 1 + dsum, fp, luck, math.min(0.6, crit)
  local cl = 0
  for i = 1, G.MW * G.MH do if S.map.cells[i] == 2 then cl = cl + 1 end end
  G.claimed = math.max(0, cl - 1)

  local gm = gUp * G.cdBonus() * (1 + 0.01 * G.achCount) * (1 + perlog * G.achCount)
  G.gmParts = {gUp = gUp, cd = G.cdBonus(), logs = (1 + 0.01 * G.achCount) * (1 + perlog * G.achCount), rank = 1 + 0.02 * (S.rank - 1), zone = 1 + 0.25 * S.zoneBest}
  if S.pupg.synergy then gm = gm * (1 + 0.01 * G.achCount) end
  if S.pupg.legacy then gm = gm * 2 end
  if S.pupg.echo then gm = gm * 3 end
  gm = gm * (1 + 0.25 * G.tr("eco_out")) * 1.25 ^ G.tr("eco_out2") * (G.tr("eco_final") > 0 and 5 or 1)
  gm = gm * (1 + 0.5 * G.tr("eco_out3")) * 1.1 ^ G.tr("od_eco") * (1 + 0.01 * G.tr("eco_res") * (G.treeRanks and G.treeRanks() or 0))
  gm = gm * (1 + 0.02 * (S.rank - 1)) * G.droneMult * (1 + 0.02 * G.claimed) * (1 + 0.05 * S.artifacts)
    * (1 + (0.25 + 0.05 * G.tr("map_zone")) * S.zoneBest)
  if S.pupg.fingers then clickMult = clickMult * 3 end
  if S.pupg.magnet then cometFreq = cometFreq * 2 end
  if S.pupg.longcomet then cometDur = cometDur * 1.5 end
  if S.pupg.auto then auto = auto + 10 end
  if S.pupg.hydro then hydro = hydro * 2 end
  clickMult = clickMult * (1 + 0.5 * G.tr("core_tap"))
  clickMult = clickMult * 2 ^ G.tr("core_tap2") * 1.3 ^ G.tr("od_core")
  G.RHYTHM_TIME = 12 - 2 * G.tr("core_rhythm")
  G.SWEET_MULT = 2.5 + 0.5 * G.tr("core_sweet")
  auto = auto + 5 * G.tr("core_auto")
  hydro = hydro * (1 + 0.3 * G.tr("sg_pump")) * 1.3 ^ G.tr("od_sig")
  cometFreq = cometFreq * (1 + 0.15 * G.tr("sg_band"))
  G.SWEET_LO = 0.75 - 0.03 * G.tr("core_heat")
  G.OVERHEAT_TIME = 4 - 0.6 * G.tr("core_vent")
  G.ALTAR_COST = 10 - G.tr("sv_altar")
  -- rank-up perks
  gm = gm * (1 + 0.10 * G.perk("OVERCLOCK"))
  clickMult = clickMult * (1 + 0.25 * G.perk("STEADY"))
  auto = auto + 2 * G.perk("SERVO")
  hydro = hydro * (1 + 0.15 * G.perk("VALVES"))
  cometFreq = cometFreq * (1 + 0.10 * G.perk("TUNER"))
  G.luck = G.luck + 0.05 * G.tr("sv_luck") + 0.05 * G.perk("SENSE") + (G.eventActive("LUCKY") and 0.5 or 0)
  G.critChance = math.min(0.75, G.critChance + 0.03 * G.tr("sv_crit") + 0.02 * G.perk("CRIT") + (G.eventActive("LUCKY") and 0.1 or 0))
  G.globalMult, G.clickMult, G.clickCpsPct = gm, clickMult, clickCpsPct
  G.cometFreq, G.cometDur, G.autoRate, G.hydroMult = cometFreq, cometDur, auto, hydro
  G.baseCps = 0
  for i, g in ipairs(GENS) do
    G.genEach[i] = g.prod * G.genUp[i] * G.milestoneMult(i) * gm
    G.baseCps = G.baseCps + G.genEach[i] * S.gens[i]
  end
end

-- dev: --econdiag. Every factor of the output multiplier, unit by unit, plus the saturation state.
function G.econReport()
  local S = G.S
  local o = {}
  local function p(k, v) o[#o + 1] = string.format("%-26s %s", k, type(v) == "number" and string.format("%.4g", v) or tostring(v)) end
  local P = G.gmParts or {}
  p("lifetime energy", S.totalEarned); p("reboots", S.prestiges); p("core data (bank/total)", S.dm .. " / " .. S.dmTotal)
  p("logs", G.achCount); p("rank", S.rank); p("zone best", S.zoneBest)
  p("--- global multiplier", "")
  p("tech global (gUp)", P.gUp); p("core data bonus", G.cdBonus()); p("logs", P.logs)
  p("synergy", S.pupg.synergy and (1 + 0.01 * G.achCount) or 1); p("legacy", S.pupg.legacy and 2 or 1); p("echo", S.pupg.echo and 3 or 1)
  p("tree eco", (1 + 0.25 * G.tr("eco_out")) * 1.25 ^ G.tr("eco_out2") * (G.tr("eco_final") > 0 and 5 or 1) * (1 + 0.5 * G.tr("eco_out3")))
  p("tree overdrive eco", 1.1 ^ G.tr("od_eco")); p("tree resonance", 1 + 0.01 * G.tr("eco_res") * (G.treeRanks and G.treeRanks() or 0))
  p("rank", 1 + 0.02 * (S.rank - 1)); p("drones", G.droneMult); p("claimed sectors", 1 + 0.02 * G.claimed)
  p("artifacts", 1 + 0.05 * S.artifacts); p("zone", 1 + (0.25 + 0.05 * G.tr("map_zone")) * S.zoneBest)
  p("perk overclock", 1 + 0.10 * G.perk("OVERCLOCK")); p("= GLOBAL", G.globalMult)
  p("--- units", "")
  for i, g in ipairs(D.GENS) do
    if (S.gens[i] or 0) > 0 then
      o[#o + 1] = string.format("%-18s n=%-6d tech=%.3g milestone=%.3g each=%.3g total=%.3g", g.name, S.gens[i], G.genUp[i], G.milestoneMult(i), G.genEach[i], G.genEach[i] * S.gens[i])
    end
  end
  p("--- output", "")
  p("base cps", G.baseCps); p("buff mult", G.buffMult("prod")); p("saturation threshold", G.satThreshold()); p("saturation mult", G.satMult())
  p("final cps", G.getCps()); p("tap value", G.tapValue()); p("auto taps/s", G.autoRate)
  p("dm potential / gain", G.dmPotential() .. " / " .. G.dmGain())
  return table.concat(o, "\n")
end

function G.buffMult(kind)
  local m = 1
  for _, b in ipairs(G.buffs) do if b.kind == kind then m = m * b.mult end end
  return m
end
function G.hasBuff(name)
  for _, b in ipairs(G.buffs) do if b.name == name then return true end end
  return false
end
-- REACTOR SATURATION: once a reboot would at least double your Core Data, output drops the longer the run goes on
-- (x threshold / lifetime energy: a hard wall, not a soft curve). Rebooting raises the threshold, so the wall moves with you.
-- Core Data output bonus: +5% each up to 100 CD, then square-root growth (linear growth made reboots snowball)
function G.cdBonus()
  local cd = S.dmTotal or 0
  if cd <= 100 then return 1 + 0.05 * cd end
  return 6 * (cd / 100) ^ 0.5
end
function G.satThreshold()
  local cd = (S.dmTotal or 0) + 10
  return (G.DM_BASE or 1e6) * (2 * cd / G.dmMult()) ^ (1 / G.DM_EXP)
end
function G.satMult()
  local T = G.satThreshold()
  if S.totalEarned <= T then return 1 end
  return math.max(1e-9, T / S.totalEarned)
end
function G.getCps() return G.baseCps * G.buffMult("prod") * G.satMult() end
-- what the reactor really makes per second (saturation applied, no temporary buffs): every reward that is
-- "N seconds of production" must use this, or it bypasses the wall
function G.effCps() return G.baseCps * G.satMult() end
function G.tapValue() return (G.clickMult + G.getCps() * G.clickCpsPct) * G.buffMult("click") end

function G.gain(x)
  S.stardust = S.stardust + x
  S.runEarned = S.runEarned + x
  S.totalEarned = S.totalEarned + x
  G.histAcc = G.histAcc + x
end

function G.addBuff(name, kind, mult, dur)
  for _, b in ipairs(G.buffs) do
    if b.name == name then b.t = math.max(b.t, dur); b.dur = math.max(b.dur, dur); return end
  end
  G.buffs[#G.buffs + 1] = {name = name, kind = kind, mult = mult, t = dur, dur = dur}
end

----------------------------------------------------------------------
-- Units / upgrades
----------------------------------------------------------------------
local function costMult() return (S.pupg.cheap and 0.9 or 1) * (1 - 0.03 * G.tr("eco_cost")) * math.max(0.5, 1 - 0.02 * G.perk("CUTTER")) end
function G.genCost(i, n)
  local base = GENS[i].cost * R ^ S.gens[i] * costMult()
  return base * (R ^ n - 1) / (R - 1)
end
function G.maxAfford(i)
  local base = GENS[i].cost * R ^ S.gens[i] * costMult()
  local n = math.floor(math.log(S.stardust * (R - 1) / base + 1) / math.log(R))
  n = math.max(0, n)
  while n > 0 and G.genCost(i, n) > S.stardust do n = n - 1 end
  return n
end
function G.buyCount(i)
  local m = G.BUYMODES[G.buyMode]
  if m == "MAX" then return math.max(1, G.maxAfford(i)) end
  return m
end
function G.revealedGen(i)
  return S.gens[i] > 0 or i == 1 or S.runEarned >= GENS[i].cost * 0.4 or S.gens[i - 1] > 0
end

function G.buyGenN(i, n, quiet)
  local cost = G.genCost(i, n)
  if n < 1 or S.stardust < cost then return false end
  local ms = G.nextMilestone(i)
  S.stardust = S.stardust - cost
  S.gens[i] = S.gens[i] + n
  S.ubt[i] = S.ubt[i] + n
  S.unitsBought = S.unitsBought + n
  G.addXP(n)
  if ms and S.gens[i] >= ms and not quiet then
    FX.toast("UNIT MILESTONE // " .. GENS[i].code, GENS[i].name .. " x" .. ms .. " reached. Output x2.", C.orange)
    FX.play("log", 1.2)
  end
  return true
end
function G.buyGen(i, x, y)
  local n = G.buyCount(i)
  if not G.buyGenN(i, n) then FX.play("err") return end
  G.recalc()
  FX.play("buy", 1 + (S.gens[i] % 25) * 0.02, 0.8)
  if x then
    FX.burst(x, y, 10, C.line, 140)
    FX.floater(x, y - 6, "+" .. n .. " " .. GENS[i].code, C.line)
  end
end

function G.availableUpgrades()
  local list = {}
  for _, u in ipairs(UPGRADES) do
    if not S.upg[u.id] and u.cond(S, G) then list[#list + 1] = u end
  end
  table.sort(list, function(a, b) return a.cost < b.cost end)
  return list
end
function G.lockedLogUpgrades()
  local list = {}
  for _, u in ipairs(UPGRADES) do
    if u.logs and not S.upg[u.id] and G.achCount < u.logs then list[#list + 1] = u end
  end
  table.sort(list, function(a, b) return a.logs < b.logs end)
  return list
end

function G.buyUpgrade(u, x, y, quiet)
  if S.upg[u.id] or S.stardust < u.cost then if not quiet then FX.play("err") end return false end
  S.stardust = S.stardust - u.cost
  S.upg[u.id] = true
  S.upBought = S.upBought + 1
  G.addXP(10)
  if not quiet then
    G.recalc()
    FX.play("buy", 1.3, 0.8)
    if x then FX.burst(x, y, 14, C.orange, 160) end
  end
  return true
end

-- auto-buy (unlocked by archive milestones, toggled in UNITS / TECH / RIGS)
function G.autoBuy()
  local changed = false
  if S.autoTech and G.hasArchive("autoTech") then
    local n = 0
    for _, u in ipairs(G.availableUpgrades()) do
      if S.stardust >= u.cost and G.buyUpgrade(u, nil, nil, true) then n = n + 1 end
    end
    if n > 0 then changed = true; FX.play("buy", 1.6, 0.25) end
  end
  if S.autoUnits and G.hasArchive("autoUnits") then
    if changed then G.recalc() end
    local bought = 0
    for _ = 1, 250 do
      local best, bestScore
      for i = 1, #GENS do
        if G.revealedGen(i) then
          local c = G.genCost(i, 1)
          if c <= S.stardust then
            local sc = c / math.max(G.genEach[i], 1e-300)
            if not bestScore or sc < bestScore then best, bestScore = i, sc end
          end
        end
      end
      if not best then break end
      G.buyGenN(best, 1, true)
      bought = bought + 1
    end
    if bought > 0 then changed = true end
  end
  if S.autoRigs and G.hasArchive("autoRigs") then
    for i, r in ipairs(S.rigs) do
      if r.on and r.tank >= G.rigCap(i) then G.collectRig(i, true) end
    end
  end
  -- rig auto-upgrade: restore offline rigs, then level the cheapest one; never more than half the energy bank
  if S.autoRigUp then
    for i, r in ipairs(S.rigs) do
      if not r.on and D.RIG_UNLOCK[i] <= S.stardust * 0.5 then
        S.stardust = S.stardust - D.RIG_UNLOCK[i]; r.on = true
        FX.toast("RIG R" .. i .. " RESTORED", "Auto-upgrade brought a new hydro stream online.", C.line)
      end
    end
    for _ = 1, 5 do
      local bi, bc
      for i, r in ipairs(S.rigs) do
        if r.on and (not bc or G.rigUpCost(i) < bc) then bi, bc = i, G.rigUpCost(i) end
      end
      if not bi or bc > S.stardust * 0.5 then break end
      S.stardust = S.stardust - bc
      S.rigs[bi].lvl = S.rigs[bi].lvl + 1
      G.addXP(15)
      changed = true
    end
  end
  if changed then G.recalc() end
end

----------------------------------------------------------------------
-- Rank / XP
----------------------------------------------------------------------
function G.xpNeed(r) return math.floor(100 * r ^ 1.6) end
function G.addXP(n)
  n = n * (1 + 0.2 * G.tr("sg_xp"))
  S.xp = S.xp + n
  S.sxp = S.sxp + n
  local ranked = false
  while S.xp >= G.xpNeed(S.rank) do
    S.xp = S.xp - G.xpNeed(S.rank)
    S.rank = S.rank + 1
    S.perkPoints = S.perkPoints + 1
    ranked = true
    local hy, pa = 10 + 3 * S.rank, 3 + S.rank
    S.hydro = S.hydro + hy
    S.parts = S.parts + pa
    local tk = (S.rank % 5 == 0) and 1 or 0
    S.tokens = S.tokens + tk
    G.rankBanner = {rank = S.rank, t = 0,
      text = "+1 PERK POINT  //  +" .. hy .. " H2O  +" .. pa .. " PARTS" .. (tk > 0 and "  +1 FAB TOKEN" or "") .. "  //  CLICK YOUR RANK BADGE"}
  end
  if ranked then
    FX.play("rank")
    FX.wave(G.OX, G.OY, G.CORE_R, C.white, 500, 1)
    G.recalc()
  end
end

----------------------------------------------------------------------
-- Tapping
----------------------------------------------------------------------
function G.jackpot(x, y)
  local e = math.max(1000, G.getCps() * 1800)
  G.gain(e)
  S.hydro = S.hydro + 10 + S.rank
  S.tokens = S.tokens + 1
  S.jackpots = S.jackpots + 1
  FX.floater(x, y - 60, "ANOMALY // JACKPOT", C.orange, H.fonts.xl, 2.6)
  FX.floater(x, y - 24, "+" .. fmt(e) .. " ENERGY  +1 TOKEN", C.white, H.fonts.m, 2.6)
  FX.shake = 22
  FX.flashTo(C.orange, 0.45)
  FX.ray(G.OX, G.OY, C.orange, 2, 400)
  FX.burst(G.OX, G.OY, 160, C.orange, 600, 3)
  for k = 1, 4 do FX.wave(G.OX, G.OY, G.CORE_R * k * 0.3, C.orange, 400 + k * 90, 1) end
  FX.toast("ANOMALY DETECTED // JACKPOT", "1 in 1000 tap. +" .. fmt(e) .. " energy, hydro and a fabrication token.", C.orange)
  FX.play("jackpot")
end

-- Core heat: every manual tap heats the core, it cools exponentially. Steady tapping settles at a fixed heat
-- (about 14% per tap/s), so the SWEET SPOT (75-95%) needs a rhythm of ~5.5-7 taps/s. Mashing past 100% overheats.
G.heat, G.overheatT, G.sweetT = 0, 0, 0
G.HEAT_TAP, G.HEAT_COOL = 0.112, 0.8
G.SWEET_LO, G.SWEET_HI, G.SWEET_MULT = 0.75, 0.95, 2.5
G.OVERHEAT_TIME, G.RHYTHM_TIME = 4, 12
function G.inSweetSpot() return G.overheatT <= 0 and G.heat >= G.SWEET_LO and G.heat <= G.SWEET_HI end
function G.heatUpdate(dt)
  if G.overheatT > 0 then
    G.overheatT = G.overheatT - dt
    G.heat = math.max(0, G.heat - dt / G.OVERHEAT_TIME)
    G.sweetT = 0
    return
  end
  G.heat = G.heat * math.exp(-G.HEAT_COOL * dt)
  if G.inSweetSpot() then
    G.sweetT = G.sweetT + dt
    -- holding the rhythm long enough ignites a Core Surge
    if G.sweetT >= G.RHYTHM_TIME then
      G.sweetT = 0
      S.rhythms = (S.rhythms or 0) + 1
      if not G.hasBuff("CORE SURGE") then G.addBuff("CORE SURGE", "prod", 3, 15 + 3 * G.tr("core_surge")) end
      FX.toast("PERFECT RHYTHM", "12 seconds in the sweet spot: Core Surge ignited. Output x3 for 15s.", C.gold)
      FX.play("surge", 1.2)
      for k = 1, 3 do FX.wave(G.OX, G.OY, G.CORE_R * 0.5 * k, C.gold, 380 + k * 60, 0.9) end
    end
  elseif G.heat < G.SWEET_LO - 0.05 then
    G.sweetT = math.max(0, G.sweetT - dt * 2)
  end
end
local errT = 0
function G.tap(x, y, auto, count)
  count = count or 1
  local v = G.tapValue()
  if not auto then
    if G.overheatT > 0 then
      if G.time - errT > 0.25 then errT = G.time; FX.play("err", 0.6, 0.5) end
      return
    end
    G.heat = G.heat + G.HEAT_TAP
    if G.heat >= 1 then
      G.heat, G.overheatT, G.combo = 1, G.OVERHEAT_TIME, 0
      S.overheats = (S.overheats or 0) + 1
      FX.toast("CORE OVERHEAT", "Taps locked for " .. G.OVERHEAT_TIME .. "s while the coolant vents. Keep the heat in the gold zone.", C.red)
      FX.play("raid", 1.4, 0.8)
      FX.shake = math.max(FX.shake, 12)
      if G.tab == "core" then
        FX.flashTo(C.red, 0.3)
        FX.burst(G.OX, G.OY, 60, C.red, 380, 2.5)
      end
      return
    end
    if G.inSweetSpot() then v = v * G.SWEET_MULT end
    if G.time - G.lastClick < 0.5 then G.combo = G.combo + 1 else G.combo = 1 end
    G.lastClick = G.time
    if G.combo > S.maxCombo then S.maxCombo = G.combo end
    v = v * (1 + math.min(G.combo, 200) * 0.005)
    S.clicks = S.clicks + 1
    for _, d in ipairs(S.directives) do
      if d.kind == "chain" and G.combo > (d.prog or 0) then d.prog = G.combo end
    end
    if not G.hasBuff("CORE SURGE") then
      G.surge = G.surge + 0.005 * (1 + math.min(G.combo, 100) / 100) * (G.inSweetSpot() and 2 or 1)
      if G.surge >= 1 then
        G.surge = 0
        G.addBuff("CORE SURGE", "prod", 3, 15 + 3 * G.tr("core_surge"))
        FX.toast("CORE SURGE", "Reactor overload. Output x3 for 15s.", C.orange)
        FX.play("surge")
        FX.shake = math.max(FX.shake, 10)
        for k = 1, 3 do FX.wave(G.OX, G.OY, G.CORE_R * 0.5 * k, C.orange, 380 + k * 60, 0.9) end
      end
    end
    G.addXP(0.25) -- taps feed rank + Signal Track slowly; buying and claiming matter more
    if love.math.random() < 0.001 * (1 + G.tr("core_jack")) then G.jackpot(x, y) end
  end
  local crit = love.math.random() < 0.04 + 0.01 * G.tr("core_crit")
  if crit then v = v * 10 end
  v = v * count
  G.gain(v)
  if G.tab ~= "core" or (auto and G.modal) then return end -- reactor only visible on the CORE scene
  G.coreKick = auto and math.max(G.coreKick, 0.03) or 0.1
  if crit and not auto then
    FX.shake = math.max(FX.shake, 8)
    FX.floater(x, y - 10, "CRITICAL +" .. fmt(v), C.red, H.fonts.l, 1.4)
    FX.burst(x, y, 28, C.red, 320, 2.5)
    FX.wave(G.OX, G.OY, G.CORE_R, C.red, 420)
    FX.play("tap", 0.6, 0.9)
  else
    FX.floater(x + rnd(-14, 14), y - 10, "+" .. fmt(v), auto and C.dim or (G.inSweetSpot() and C.gold or C.white), auto and H.fonts.xs or H.fonts.s)
    FX.burst(x, y, auto and 2 or 7, crit and C.red or C.line, 200)
    if not auto then
      FX.wave(G.OX, G.OY, G.CORE_R * 0.9, C.line, 300)
      FX.play("tap", 1 + math.min(G.combo, 60) * 0.012 + rnd(-0.03, 0.03), 0.7)
    end
  end
end

----------------------------------------------------------------------
-- Signals
----------------------------------------------------------------------
function G.nextSignalDelay() return rnd(60, 150) / G.cometFreq end
function G.spawnSignal()
  local dir = love.math.random() < 0.5 and 1 or -1
  G.signal = {x = dir == 1 and -40 or 1320, y0 = rnd(140, 560), vx = dir * rnd(85, 120), vy = rnd(-8, 8), t = 0, trail = {}}
  G.signal.y = G.signal.y0
  FX.play("signal", 1, 0.8)
end

function G.catchSignal()
  local sx, sy = G.signal.x, G.signal.y
  G.signal = nil
  S.comets = S.comets + 1
  G.addXP(25)
  local r = love.math.random()
  local dur = G.cometDur
  local title, text
  if r < 0.30 then
    local g = math.max(13, math.min(S.stardust * 0.15, G.getCps() * 900))
    G.gain(g)
    title, text = "CACHE RECOVERED", "+" .. fmt(g) .. " energy"
  elseif r < 0.52 then
    G.addBuff("OVERCHARGE", "prod", 7, 77 * dur)
    title, text = "OVERCHARGE", "Output x7 for " .. math.floor(77 * dur) .. "s"
  elseif r < 0.64 then
    G.addBuff("MANUAL OVERRIDE", "click", 777, 13 * dur)
    title, text = "MANUAL OVERRIDE", "Tap power x777 for " .. math.floor(13 * dur) .. "s. TAP!"
  elseif r < 0.76 then
    local hy, pa = 10 + S.rank * 2, 5 + S.rank
    S.hydro, S.parts = S.hydro + hy, S.parts + pa
    title, text = "SUPPLY DROP", "+" .. hy .. " H2O  +" .. pa .. " PARTS"
  elseif r < 0.84 then
    local xp = 100 + S.rank * 20
    G.addXP(xp)
    title, text = "TECH DATA", "+" .. xp .. " XP"
  elseif r < 0.92 and G.dropCrate then
    local tier = math.min(6, 3 + (love.math.random() < 0.3 and 1 or 0))
    G.dropCrate(G.TX + rnd(-1, 1), G.TY + rnd(-1, 1), tier)
    title, text = "LOOT DROP", D.LOOT[tier].name .. " crate landed near the tower (MAP)"
  elseif r < 0.97 then
    G.addBuff("CRITICAL MASS", "prod", 77, 10 * dur)
    title, text = "CRITICAL MASS", "Output x77 for " .. math.floor(10 * dur) .. "s"
  else
    S.tokens = S.tokens + 1
    title, text = "FABRICATION TOKEN", "+1 free drone fabrication"
  end
  FX.floater(sx, sy - 20, title, C.orange, H.fonts.l, 1.8)
  FX.floater(sx, sy + 6, text, C.white, H.fonts.s, 1.8)
  FX.burst(sx, sy, 50, C.orange, 380, 2.5)
  FX.shake = math.max(FX.shake, 6)
  FX.toast("SIGNAL INTERCEPTED // " .. title, text, C.orange)
  FX.play("catch")
end

----------------------------------------------------------------------
-- Hydro rigs
----------------------------------------------------------------------
function G.rigRate(i)
  return 0.05 * S.rigs[i].lvl * G.hydroMult * (1 + 0.15 * (i - 1)) * (G.eventActive("HYDRO") and 5 or 1)
end
function G.rigCap(i) return 30 * S.rigs[i].lvl ^ 1.2 * (1 + 0.5 * G.tr("sg_rig")) end
function G.rigUpCost(i) return D.RIG_BASE[i] * 9 ^ (S.rigs[i].lvl - 1) end
function G.unlockRig(i)
  local cost = D.RIG_UNLOCK[i]
  if S.stardust < cost then FX.play("err") return end
  S.stardust = S.stardust - cost
  S.rigs[i].on = true
  FX.play("unlock")
  FX.toast("RIG R" .. i .. " RESTORED", "A new hydro stream is online.", C.line)
end
function G.upgradeRig(i)
  local cost = G.rigUpCost(i)
  if S.stardust < cost then FX.play("err") return end
  S.stardust = S.stardust - cost
  S.rigs[i].lvl = S.rigs[i].lvl + 1
  G.addXP(15)
  FX.play("buy", 0.9)
end
function G.collectRig(i, quiet)
  local r = S.rigs[i]
  if not r.on or r.tank < 1 then return false end
  local peak = r.tank >= G.rigCap(i) - 1e-6
  local got = r.tank * (peak and 1.25 or 1)
  S.hydro = S.hydro + got
  r.tank = 0
  G.rigFull[i] = false
  S.rigCollects = S.rigCollects + 1
  G.addXP(5 + r.lvl * 2)
  if quiet then return true end
  local mx, my = require("lib.view").mouse()
  FX.floater(mx, my - 20, "+" .. fmt(math.floor(got)) .. " H2O" .. (peak and "  PEAK!" or ""), peak and C.orange or C.line, H.fonts.m, 1.4)
  FX.burst(mx, my, peak and 40 or 18, C.line, 260)
  FX.play("collect", peak and 1.1 or 1)
  return true
end

----------------------------------------------------------------------
-- Directives
----------------------------------------------------------------------
function G.dirCounter(d)
  local k = d.kind
  if k == "tap" then return S.clicks
  elseif k == "units" then return S.unitsBought
  elseif k == "unitType" then return S.ubt[d.i] or 0
  elseif k == "energy" then return S.totalEarned
  elseif k == "signal" then return S.comets
  elseif k == "rig" then return S.rigCollects
  elseif k == "sector" then return S.claimsTotal
  elseif k == "fab" then return S.fabsTotal
  elseif k == "upgrade" then return S.upBought
  elseif k == "kill" then return S.kills
  elseif k == "crate" then return S.crates end
  return 0
end
function G.dirProgress(d)
  if d.kind == "chain" then return d.prog or 0 end
  return G.dirCounter(d) - d.base
end
function G.dirText(d)
  local k, t = d.kind, fmt(d.target)
  local s = d.target > 1 and "S" or ""
  if k == "tap" then return "TAP THE CORE " .. t .. " TIMES"
  elseif k == "units" then return "ACQUIRE " .. t .. " UNITS (ANY TYPE)"
  elseif k == "unitType" then return "ACQUIRE " .. t .. " " .. GENS[d.i].name:upper()
  elseif k == "energy" then return "HARVEST " .. t .. " ENERGY"
  elseif k == "signal" then return "INTERCEPT " .. t .. " SIGNAL" .. s
  elseif k == "rig" then return "COLLECT HYDRO RIGS " .. t .. " TIME" .. s
  elseif k == "sector" then return "SECURE " .. t .. " MAP SECTOR" .. s
  elseif k == "fab" then return "FABRICATE " .. t .. " DRONE" .. s
  elseif k == "chain" then return "REACH A TAP CHAIN OF " .. t
  elseif k == "upgrade" then return "INSTALL " .. t .. " TECH UPGRADES"
  elseif k == "kill" then return "DESTROY " .. t .. " SCAV" .. s
  elseif k == "crate" then return "OPEN " .. t .. " LOOT CRATE" .. s end
  return "?"
end
function G.rewardText(d)
  local r = d.reward
  local parts = {"+" .. r.xp .. " XP"}
  if r.hydro then parts[#parts + 1] = "+" .. r.hydro .. " H2O" end
  if r.parts then parts[#parts + 1] = "+" .. r.parts .. " PARTS" end
  if r.energy then parts[#parts + 1] = "+" .. fmt(r.energy) .. "s OF OUTPUT" end
  if r.crate then parts[#parts + 1] = "+" .. D.LOOT[r.crate].name .. " CRATE" end
  if r.tokens then parts[#parts + 1] = "+" .. r.tokens .. " FAB TOKEN" end
  return table.concat(parts, "   ")
end

function G.newDirective()
  local Rk = S.rank
  local kinds = {"tap", "units", "energy", "chain", "upgrade", "signal"}
  if G.unlocked("rigs") then kinds[#kinds + 1] = "rig" end
  if G.unlocked("hangar") then kinds[#kinds + 1] = "fab" end
  local hi = 0
  for i = #GENS, 1, -1 do if S.gens[i] > 0 then hi = i break end end
  if hi > 0 then kinds[#kinds + 1] = "unitType" end
  if #S.drones > 0 and G.unlocked("map") then
    for _, k in ipairs({"sector", "kill", "kill", "crate"}) do kinds[#kinds + 1] = k end
  end
  local k = kinds[love.math.random(#kinds)]
  local d = {kind = k, prog = 0}
  if k == "tap" then d.target = 100 + 20 * Rk
  elseif k == "units" then d.target = 10 + 4 * Rk
  elseif k == "unitType" then d.i = hi; d.target = 5 + math.floor(Rk / 2)
  elseif k == "energy" then d.target = math.floor(math.max(500, G.effCps() * rnd(120, 400)))
  elseif k == "chain" then d.target = math.min(150, 25 + Rk * 2)
  elseif k == "upgrade" then d.target = love.math.random(2, 4)
  elseif k == "signal" then d.target = love.math.random(1, 2)
  elseif k == "rig" then d.target = love.math.random(1, 3)
  elseif k == "fab" then d.target = 1
  elseif k == "sector" then d.target = love.math.random(1, 3)
  elseif k == "kill" then d.target = love.math.random(5, 15)
  elseif k == "crate" then d.target = love.math.random(4, 10) end
  d.base = G.dirCounter(d)
  d.priority = love.math.random() < 0.12
  local m = d.priority and 3 or 1
  d.reward = {xp = (30 + 8 * Rk) * m}
  local x = love.math.random()
  if x < 0.3 then d.reward.hydro = (8 + 2 * Rk) * m
  elseif x < 0.55 then d.reward.parts = (3 + Rk) * m
  elseif x < 0.8 then d.reward.energy = 120 * m
  else d.reward.crate = d.priority and 4 or 3 end
  if d.priority then d.reward.tokens = 1 end
  return d
end
function G.ensureDirectives()
  for i = 1, 3 do
    if type(S.directives[i]) ~= "table" or not S.directives[i].kind then S.directives[i] = G.newDirective() end
  end
end
function G.claimDirective(i)
  local d = S.directives[i]
  if not d or G.dirProgress(d) < d.target then FX.play("err") return end
  local r = d.reward
  if r.hydro then S.hydro = S.hydro + r.hydro end
  if r.parts then S.parts = S.parts + r.parts end
  if r.tokens then S.tokens = S.tokens + r.tokens end
  if r.energy then G.gain(math.max(100, G.effCps() * r.energy)) end
  if r.crate and G.dropCrate then G.dropCrate(G.TX + rnd(-1, 1), G.TY + rnd(-1, 1), r.crate) end
  S.dirDone = S.dirDone + 1
  S.directives[i] = G.newDirective()
  G.addXP(r.xp)
  local mx, my = require("lib.view").mouse()
  FX.burst(mx, my, 40, d.priority and C.orange or C.line, 300)
  FX.floater(mx, my - 20, "DIRECTIVE COMPLETE", d.priority and C.orange or C.white, H.fonts.l, 1.5)
  FX.play("log", 1.1)
end
function G.rerollDirective(i)
  if G.now() < S.rerollAt then FX.play("err") return end
  S.directives[i] = G.newDirective()
  S.rerollAt = G.now() + 300
  FX.play("tick", 0.8)
end

----------------------------------------------------------------------
-- Daily shift
----------------------------------------------------------------------
function G.today() return os.date("%Y-%m-%d") end
function G.checkDaily() G.dailyPending = S.daily.last ~= G.today() end
function G.dailyNextStreak()
  local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
  if S.daily.last == yesterday then return S.daily.streak + 1 end
  return 1
end
function G.claimDaily()
  local st = G.dailyNextStreak()
  S.daily.streak = st
  S.daily.last = G.today()
  if st > S.bestStreak then S.bestStreak = st end
  local day = D.DAILY[(st - 1) % 7 + 1]
  local scale = 1 + S.rank * 0.1
  if day.hydro then S.hydro = S.hydro + math.floor(day.hydro * scale) end
  if day.parts then S.parts = S.parts + math.floor(day.parts * scale) end
  if day.tokens then S.tokens = S.tokens + day.tokens end
  if day.core then
    local cd = math.max(1, math.floor(S.dmTotal * 0.05))
    S.dm, S.dmTotal = S.dm + cd, S.dmTotal + cd
  end
  G.dailyPending = false
  G.addXP(50 * st)
  G.recalc()
  FX.play("unlock")
  FX.toast("SHIFT " .. st .. " // SUPPLY RECEIVED", day.text .. (scale > 1 and " (rank-scaled)" or ""), C.orange)
end

----------------------------------------------------------------------
-- Reboot
----------------------------------------------------------------------
function G.dmMult() return 1 + 0.1 * G.tr("eco_cd") end
-- fourth root: Core Data feeds back into output, so faster-growing roots made reboots snowball
G.DM_EXP, G.DM_BASE = 1 / 4, 1e6 -- first ~30 Core Data at ~1e12 lifetime energy, same as the old square root
function G.dmPotential() return math.floor((S.totalEarned / G.DM_BASE) ^ G.DM_EXP * G.dmMult()) end
-- one reboot can at most triple your total Core Data (min 25 for new players), and that cap charges up over the
-- first 60 minutes of a run (x2 after 30): quick back-to-back reboots give little, so reboots cannot cascade
G.RUN_CHARGE = 3600
function G.runCharge() return math.min(1, (S.runTime or 0) / G.RUN_CHARGE) end
function G.dmCap() return math.max(25, 2 * S.dmTotal * G.runCharge()) end
function G.dmGain() return math.max(0, math.min(G.dmPotential() - S.dmTotal, G.dmCap())) end
function G.doReboot()
  local g = G.dmGain()
  if g < 1 then return end
  S.dm, S.dmTotal = S.dm + g, S.dmTotal + g
  S.prestiges = S.prestiges + 1
  S.stardust, S.runEarned, S.runTime = 0, 0, 0
  for i = 1, #GENS do S.gens[i] = 0 end
  S.upg = {}
  if S.pupg.starter then S.gens[1], S.gens[2] = 10, 5 end
  G.newMap()
  for i, d in ipairs(S.directives) do
    if d.kind == "energy" or d.kind == "unitType" then S.directives[i] = G.newDirective() end
  end
  G.buffs, G.signal, G.surge = {}, nil, 0
  G.dispDust = 0
  FX.flashTo(C.white, 1.6)
  FX.shake = 22
  for k = 1, 5 do FX.wave(G.OX, G.OY, G.CORE_R * k * 0.3, k % 2 == 0 and C.red or C.white, 500 + k * 80) end
  FX.burst(G.OX, G.OY, 200, C.white, 650, 3)
  FX.play("reboot")
  G.addXP(200)
  G.recalc()
  G.save()
  FX.toast("REBOOT PROTOCOL COMPLETE", "+" .. fmt(g) .. " Core Data. Sector map of zone " .. S.zone .. " regenerated.", C.red)
end

----------------------------------------------------------------------
-- Logs + archive milestones
----------------------------------------------------------------------
function G.checkAch()
  local new = 0
  local before = G.achCount
  for i, a in ipairs(ACH) do
    if not S.ach[i] and a.cond(S) then
      S.ach[i] = true
      new = new + 1
      if new <= 2 then FX.toast("LOG ENTRY " .. a.code .. " // " .. a.name:upper(), a.desc .. "  (+1% output)", C.line) end
    end
  end
  if new > 0 then
    G.recalc()
    G.addXP(15 * new)
    FX.play("log")
  end
  for k, a in ipairs(D.ARCHIVE) do
    if k > S.archive and G.achCount >= a.n then
      S.archive = k
      if a.tokens then S.tokens = S.tokens + a.tokens end
      if before < a.n then
        FX.toast("ARCHIVE MILESTONE // " .. a.n .. " LOGS", a.text, C.orange)
        FX.play("unlock")
        G.rankBanner = {t = 0, title = "ARCHIVE UNLOCK", text = a.text, c = C.orange}
      end
    end
  end
end

----------------------------------------------------------------------
-- Save / load / offline
----------------------------------------------------------------------
local function ser(v)
  local t = type(v)
  if t == "number" then
    if v ~= v then return "0" end
    if v == math.huge then return "1/0" end
    if v == -math.huge then return "-1/0" end
    return string.format("%.17g", v)
  elseif t == "boolean" then return tostring(v)
  elseif t == "string" then return string.format("%q", v)
  elseif t == "table" then
    local parts = {}
    for k, val in pairs(v) do
      local key = type(k) == "number" and ("[" .. k .. "]") or ("[" .. string.format("%q", k) .. "]")
      parts[#parts + 1] = key .. "=" .. ser(val)
    end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "nil"
end

G.serialize = ser
function G.save()
  S.lastSave = os.time()
  love.filesystem.write("save.lua", ser(S))
end

-- clears everything that lives outside the save table
function G.resetTransient()
  G.buffs, G.enemies, G.lootFeed, G.choiceQueue = {}, {}, {}, {}
  G.report, G.perkChoice, G.perkRoll, G.signal, G.rankBanner = nil, nil, nil, nil, nil
  G.event, G.nextEvent, G.tacSel, G.scrapConfirm = nil, nil, nil, nil
  G.combo, G.surge, G.coreKick, G.dispDust = 0, 0, 0, 0
  G.tab = "core"
end

-- wipe the save (a backup of the current one is kept as save_backup.lua)
function G.resetSave()
  G.save()
  love.filesystem.write("save_backup.lua", love.filesystem.read("save.lua"))
  G.resetTransient()
  G.S = G.newState()
  S = G.S
  G.newMap()
  G.recalc()
  G.ensureDirectives()
  G.checkDaily()
  G.save()
end

function G.hasBackup() return love.filesystem.getInfo("save_backup.lua") ~= nil end

local function loadInto(data)
  G.resetTransient()
  love.filesystem.write("save.lua", data)
  G.init(false)
  G.report = nil
  G.S.lastSave = os.time()
  S = G.S
  G.save()
end

function G.restoreBackup()
  local data = G.hasBackup() and love.filesystem.read("save_backup.lua")
  if not data then return false end
  G.save()
  local current = love.filesystem.read("save.lua")
  loadInto(data)
  love.filesystem.write("save_backup.lua", current) -- restoring twice swaps back
  return true
end

-- import a save string (e.g. from the clipboard); returns ok, message
function G.importSave(text)
  if type(text) ~= "string" or #text < 20 then return false, "Clipboard is empty or not a save." end
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  if text:sub(1, 1) ~= "{" then return false, "That does not look like a TOWER 07 save." end
  -- saves only contain data tables; refuse anything that looks like code
  for _, kw in ipairs({"function", "while", "repeat", "goto", "for ", "%.%."}) do
    if text:find(kw) then return false, "Save contains unexpected content." end
  end
  local fn = loadstring("return " .. text)
  if not fn then return false, "Save data is corrupted." end
  setfenv(fn, {})
  local ok, t = pcall(fn)
  if not ok or type(t) ~= "table" or type(t.stardust) ~= "number" or type(t.gens) ~= "table" then
    return false, "Save data is corrupted."
  end
  G.save()
  love.filesystem.write("save_backup.lua", love.filesystem.read("save.lua"))
  loadInto(text)
  return true, "Save imported. Your previous save was kept as a backup."
end

function G.load()
  if not love.filesystem.getInfo("save.lua") then return end
  local data = love.filesystem.read("save.lua")
  local fn = data and loadstring("return " .. data)
  if not fn then return end
  setfenv(fn, {})
  local ok, t = pcall(fn)
  if not ok or type(t) ~= "table" then return end
  local s = G.newState()
  for k, v in pairs(t) do
    if s[k] ~= nil and type(s[k]) == type(v) then s[k] = v end
  end
  for i = 1, #GENS do
    s.gens[i] = tonumber(s.gens[i]) or 0
    s.ubt[i] = tonumber(s.ubt[i]) or 0
  end
  for i = 1, 3 do
    if type(s.rigs[i]) ~= "table" then s.rigs[i] = {on = i == 1, lvl = 1, tank = 0} end
  end
  for i = #s.drones, 1, -1 do
    if type(s.drones[i]) ~= "table" or not s.drones[i].r then table.remove(s.drones, i) end
  end
  if type(s.daily) ~= "table" then s.daily = {last = "", streak = 0} end
  G.S = s
end

function G.computeOffline()
  local elapsed = os.time() - (S.lastSave or os.time())
  if elapsed <= 30 then return end
  local cap = (S.pupg.memory and 86400 or 43200) + 14400 * G.tr("sg_night")
  local rate = (S.pupg.memory and 1 or 0.5) * (1 + 0.25 * G.tr("sg_dream"))
  local gain = G.baseCps * G.satMult() * math.min(elapsed, cap) * rate
  S.runTime = (S.runTime or 0) + math.min(elapsed, cap) -- offline time charges the run too
  local full = 0
  for i, r in ipairs(S.rigs) do
    if r.on then
      local c = G.rigCap(i)
      r.tank = math.min(c, r.tank + G.rigRate(i) * elapsed)
      if r.tank >= c then full = full + 1; G.rigFull[i] = true end
    end
  end
  local nm = 0
  local now = G.now()
  for _, d in ipairs(S.drones) do if d.mission and d.mission.ends <= now then nm = nm + 1 end end
  if gain > 0 or full > 0 or nm > 0 then
    G.report = {secs = elapsed, capped = elapsed > cap, gain = gain, rate = rate, rigs = full, missions = nm,
      crates = #S.crateList}
  end
end

function G.collectReport()
  if not G.report then return end
  G.gain(G.report.gain)
  FX.burst(G.OX, G.OY, 90, C.line, 500, 2.5)
  FX.wave(G.OX, G.OY, G.CORE_R, C.white, 400)
  FX.play("catch", 0.8)
  G.report = nil
end

function G.init(test)
  G.S = G.newState()
  if not test then G.load() end
  S = G.S
  for _, d in ipairs(S.drones) do G.normalizeDrone(d) end
  if not S.map.seed or S.map.seed == 0 or #S.map.cells ~= G.MW * G.MH then
    G.newMap()
  else
    G.buildTerrain()
  end
  G.recalc()
  for _, d in ipairs(S.drones) do d.hp = math.min(d.hp or G.droneMaxHp(d), G.droneMaxHp(d)) end
  G.computeOffline()
  G.ensureDirectives()
  G.checkDaily()
  -- a brand-new save gets the daily supply as an objective card, not a popup at launch
  if S.totalEarned == 0 then G.dailyPending = false end
  G.dispDust = S.stardust
  G.signalTimer = 60 / G.cometFreq
  G.hist = {}
  for i = 1, 60 do G.hist[i] = 0 end
  for k in pairs(G.scroll) do G.scroll[k] = nil end
end

----------------------------------------------------------------------
-- Update
----------------------------------------------------------------------
local autoAcc, ambientAcc, achTimer, saveTimer, breakTimer, titleTimer, buyTimer = 0, 0, 0, 0, 0, 0, 0
G.selftest = false

function G.update(dt)
  S = G.S
  G.time = G.time + dt
  G.sessionTime = G.sessionTime + dt
  S.playTime = S.playTime + dt
  S.runTime = (S.runTime or 0) + dt

  for i = #G.buffs, 1, -1 do
    local b = G.buffs[i]
    b.t = b.t - dt
    if b.t <= 0 then table.remove(G.buffs, i) end
  end

  local cps = G.getCps()
  G.gain(cps * dt)
  if cps > S.bestCps then S.bestCps = cps end

  if G.autoRate > 0 then
    autoAcc = autoAcc + dt * G.autoRate
    local n = math.floor(autoAcc)
    if n > 0 then
      autoAcc = autoAcc - n
      local a = rnd(0, math.pi * 2)
      G.tap(G.OX + math.cos(a) * 40, G.OY + math.sin(a) * 40, true, n)
    end
  end

  buyTimer = buyTimer + dt
  if buyTimer > 0.25 then buyTimer = 0; G.autoBuy() end

  if G.time - G.lastClick > 1.2 then G.combo = 0 end
  if G.time - G.lastClick > 2 then G.surge = math.max(0, G.surge - 0.03 * dt) end
  G.coreKick = math.max(0, G.coreKick - dt * 0.6)
  G.novaConfirm = math.max(0, G.novaConfirm - dt)
  if G.scrapConfirm then
    G.scrapConfirm.t = G.scrapConfirm.t - dt
    if G.scrapConfirm.t <= 0 then G.scrapConfirm = nil end
  end

  local sg = G.signal
  if sg then
    sg.t = sg.t + dt
    sg.x = sg.x + sg.vx * dt
    sg.y = sg.y0 + math.sin(sg.t * 1.2) * 45 + sg.vy * sg.t
    table.insert(sg.trail, {x = sg.x, y = sg.y})
    if #sg.trail > 40 then table.remove(sg.trail, 1) end
    if sg.x > 1360 or sg.x < -80 then G.signal = nil end
  elseif not G.modal then
    G.signalTimer = G.signalTimer - dt
    if G.signalTimer <= 0 then G.spawnSignal(); G.signalTimer = G.nextSignalDelay() end
  end

  if G.tab == "core" then
    ambientAcc = ambientAcc + dt * clamp(math.log10(cps + 1) * 1.5, 0, 22)
    while ambientAcc >= 1 do
      ambientAcc = ambientAcc - 1
      local a = rnd(0, math.pi * 2)
      FX.spark(G.OX + math.cos(a) * G.CORE_R, G.OY + math.sin(a) * G.CORE_R,
        math.cos(a) * rnd(20, 60), math.sin(a) * rnd(20, 60), C.line, rnd(1, 2.2), rnd(1, 2))
    end
  end

  for i, r in ipairs(S.rigs) do
    if r.on then
      local c = G.rigCap(i)
      r.tank = math.min(c, r.tank + G.rigRate(i) * dt)
      if r.tank >= c and not G.rigFull[i] then
        G.rigFull[i] = true
        if not (S.autoRigs and G.hasArchive("autoRigs")) then
          FX.toast("RIG R" .. i .. " // TANK FULL", "Collect now for a +25% peak pressure bonus.", C.orange)
          FX.play("alert")
        end
      end
    end
  end

  G.missionsUpdate()
  if G.tacUpdate then G.tacUpdate(dt) end
  if G.metaUpdate then G.metaUpdate(dt) end
  if G.fiestaUpdate then G.fiestaUpdate(dt) end
  if G.autopilotUpdate then G.autopilotUpdate(dt) end
  G.heatUpdate(dt)

  -- banners queue instead of overwriting each other
  G.bannerQueue = G.bannerQueue or {}
  if G.rankBanner ~= G._banner then
    if G._banner and G._banner.t < 2.2 and G.rankBanner then
      table.insert(G.bannerQueue, G.rankBanner)
      if #G.bannerQueue > 3 then table.remove(G.bannerQueue, 1) end
      G.rankBanner = G._banner
    end
    G._banner = G.rankBanner
  end
  if G.rankBanner then
    G.rankBanner.t = G.rankBanner.t + dt
    if G.rankBanner.t > 3 then
      G.rankBanner = table.remove(G.bannerQueue, 1)
      if G.rankBanner then G.rankBanner.t = 0 end
      G._banner = G.rankBanner
    end
  end

  -- fabrication card flips
  local ch = G.choiceQueue[1]
  if ch then
    local before = ch.t
    ch.t = ch.t + dt
    for pos, k in ipairs(ch.order) do
      local ft = G.flipTime(ch, pos)
      local r = ch.cands[k].r
      -- tension ticks before a rare flip
      if r >= 3 and ch.t < ft and math.floor(ch.t * (6 + r * 2)) ~= math.floor(before * (6 + r * 2)) then
        FX.play("tick", 0.6 + ch.t * 0.4, 0.5)
      end
      if before < ft and ch.t >= ft then
        ch.flipped[k] = true
        G.revealFX(r, G.cardX(k), 360, nil, nil, 220, 300)
      end
    end
  end

  if S.stardust < G.dispDust then G.dispDust = S.stardust
  else G.dispDust = G.dispDust + (S.stardust - G.dispDust) * math.min(1, dt * 12) end

  G.histT = G.histT + dt
  if G.histT >= 1 then
    G.histT = G.histT - 1
    table.insert(G.hist, G.histAcc)
    G.histAcc = 0
    if #G.hist > 60 then table.remove(G.hist, 1) end
  end

  achTimer = achTimer + dt
  if achTimer > 0.5 then achTimer = 0; G.checkAch() end

  saveTimer = saveTimer + dt
  if saveTimer > (G.saveInterval or 15) and not G.selftest then saveTimer = 0; G.save() end

  -- touch-grass reminder (configurable in settings, 0 = off)
  breakTimer = breakTimer + dt
  if (G.breakInterval or 2700) > 0 and breakTimer > (G.breakInterval or 2700) then
    breakTimer = 0
    local tips = {
      {"TOUCH GRASS PROTOCOL", "Step outside for 5 minutes. The tower harvests without you. Probably."},
      {"HYDRATION CHECK", "Drink a glass of water. Technicians are 60% coolant."},
      {"20-20-20 RULE", "Look at something 20 m away for 20 seconds. The scavs can wait."},
      {"STRETCH BREAK", "Roll your shoulders, stretch your wrists. Tap power needs healthy hands."},
      {"SNACK RECON", "Eat something real. Energy bars do not count as harvested energy."},
    }
    local tip = tips[love.math.random(#tips)]
    G.rankBanner = {t = 0, title = tip[1], text = tip[2] .. "  //  Offline earnings keep running.", c = C.line}
    FX.toast(tip[1], tip[2], C.orange)
    FX.play("log", 0.8)
  end

  titleTimer = titleTimer + dt
  if titleTimer > 1 and not G.bossMode then
    titleTimer = 0
    love.window.setTitle("TOWER 07 // " .. fmt(S.stardust) .. " ENERGY // +" .. fmt(cps) .. "/S")
  end
end

return G
