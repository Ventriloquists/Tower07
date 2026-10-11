-- LOOT FIESTA: mass fabrication with auto-pick, fusion cascade and overflow recycling.
-- Everything is resolved the moment it starts (so skipping or quitting never loses anything);
-- the fiesta screen only replays the result. Extends the G table from game/core.lua.
local H = require "lib.hud"
local FX = require "game.fx"
local D = require "game.data"
local G = require "game.core"
local RAR = D.RARITY

G.FIESTA_SIZES = {10, 25, 50, 100}
G.fiesta = nil
G.fiestaOpt = {n = 10, tokens = false, fleet = true}

function G.fiestaUnlocked() return G.S.fabsTotal >= 10, 10 end
-- bigger fiestas pay out free bonus pulls
function G.fiestaBonus(n)
  local b = n >= 100 and 15 or n >= 50 and 7 or n >= 25 and 3 or n >= 10 and 1 or 0
  return math.floor(b * (1 + 0.5 * G.tr("fl_fiesta")))
end
-- hydro and tokens needed; tokens pay for the last (most expensive) pulls
function G.fiestaCost(n, useTokens)
  local S = G.S
  local tok = useTokens and math.min(S.tokens, n) or 0
  local h = 0
  for k = 0, n - tok - 1 do h = h + G.fabCostAt(S.fabsTotal + k) end
  return h, tok
end
function G.fiestaMax(useTokens)
  local S = G.S
  local tok = useTokens and S.tokens or 0
  local h, n = 0, 0
  while n < 100 do
    if n >= tok then
      local c = G.fabCostAt(S.fabsTotal + n - tok)
      if h + c > S.hydro then break end
      h = h + c
    end
    n = n + 1
  end
  return n
end
function G.fiestaSize()
  local o = G.fiestaOpt
  return o.n == 0 and G.fiestaMax(o.tokens) or o.n
end

function G.openFiesta()
  if not G.fiestaUnlocked() then FX.play("err") return end
  G.fiesta = {phase = "setup", t = 0}
  FX.play("unlock", 0.9)
end

local function better(a, b)
  if a.r ~= b.r then return a.r > b.r end
  return G.dronePower(a) > G.dronePower(b)
end

function G.startFiesta()
  local S = G.S
  local o = G.fiestaOpt
  local n = G.fiestaSize()
  if n < 1 then FX.play("err") return false end
  local h, tok = G.fiestaCost(n, o.tokens)
  if S.hydro < h then FX.play("err") return false end
  S.hydro = S.hydro - h
  S.tokens = S.tokens - tok
  S.fabsTotal = S.fabsTotal + n
  local bonus = G.fiestaBonus(n)

  -- 1. pulls: best of every 3 candidates, the other two are recycled; 1 ELITE+ guaranteed per 10 pulls
  local pulls, candParts, block = {}, 0, false
  for k = 1, n + bonus do
    local ch = G.rollCandidates()
    local g = false
    if k % 10 == 0 and not block and ch.best < 3 then
      ch.cands[1] = G.makeDrone(3); g = true; S.pity = 0
    end
    local bi = 1
    for j = 2, 3 do if ch.cands[j].r > ch.cands[bi].r then bi = j end end
    local d = ch.cands[bi]
    if d.r >= 3 then block = true end
    if k % 10 == 0 then block = false end
    for j, c in ipairs(ch.cands) do if j ~= bi then candParts = candParts + math.ceil(RAR[c.r].scrap * 0.5) end end
    G.countPull(d)
    pulls[k] = {d = d, r = d.r, bonus = k > n, guaranteed = g}
  end

  -- 2. fusion cascade over the new drones (plus idle unlocked fleet drones if allowed)
  local pool, fleetIn = {}, {}
  for _, p in ipairs(pulls) do pool[#pool + 1] = p.d end
  local start = {0, 0, 0, 0, 0, 0}
  local merges = {}
  if (S.autoFuse or 0) >= 2 then
    if o.fleet then
      for _, d in ipairs(S.drones) do
        if G.autoFuseOk(d) then pool[#pool + 1] = d; fleetIn[d] = true end
      end
    end
    for _, d in ipairs(pool) do start[d.r] = start[d.r] + 1 end
    merges = G.fuseGroups(pool, S.autoFuse, function(ins, nd)
      for _, d in ipairs(ins) do
        if fleetIn[d] or d.fromFleet then nd.fromFleet = true end
        if fleetIn[d] then
          local _, k = G.findDrone(d.id)
          if k then table.remove(S.drones, k) end
        end
      end
      G.countPull(nd)
    end)
  else
    for _, d in ipairs(pool) do start[d.r] = start[d.r] + 1 end
  end

  -- 3. fill the bay with the best new drones; overflow is recycled into parts
  local fresh = {}
  for _, d in ipairs(pool) do if not fleetIn[d] then fresh[#fresh + 1] = d end end
  table.sort(fresh, function(a, b)
    if (a.fromFleet and 1 or 0) ~= (b.fromFleet and 1 or 0) then return a.fromFleet == true end
    return better(a, b)
  end)
  local space = G.bayCap() - #S.drones - #G.choiceQueue
  local kept, scrapped, scrapParts = {}, 0, 0
  for k, d in ipairs(fresh) do
    d.fromFleet = nil
    if k <= space then
      G.addDrone(d, true)
      kept[#kept + 1] = d
    else
      scrapped = scrapped + 1
      scrapParts = scrapParts + RAR[d.r].scrap * d.lvl
    end
  end
  table.sort(kept, better)
  S.parts = S.parts + candParts + scrapParts
  S.fiestas = (S.fiestas or 0) + 1
  S.fiestaPulls = (S.fiestaPulls or 0) + n + bonus
  G.addXP(20 * n + 40 * #merges)
  G.recalc()
  if kept[1] then G.hangarSel = kept[1].id end

  local bestPull = pulls[1].d
  for _, p in ipairs(pulls) do if better(p.d, bestPull) then bestPull = p.d end end
  local tally = {0, 0, 0, 0, 0, 0}
  for _, p in ipairs(pulls) do tally[p.r] = tally[p.r] + 1 end
  if G.meme then G.meme(#merges >= 10 and "combo" or "fiesta") end
  G.fiesta = {phase = "pull", t = 0, n = n, bonus = bonus, tokens = tok, hydro = h,
    pulls = pulls, merges = merges, start = start, kept = kept, best = kept[1] or bestPull, bestPull = bestPull,
    scrapped = scrapped, scrapParts = scrapParts, candParts = candParts, tally = tally,
    shown = 0, wait = 0.5, seen = {0, 0, 0, 0, 0, 0}, mi = 0, mt = 0, counts = {unpack(start)}}
  FX.play("surge", 1.1)
  return true
end

-- periodic auto-fuse of the fleet (outside fiestas)
local afT = 0
function G.fiestaUpdate(dt)
  afT = afT + dt
  if afT < 2 then return end
  afT = 0
  if G.modal or G.drag or G.fiesta or G.combine then return end
  G.autoFuseFleet()
end

----------------------------------------------------------------------
-- MYTHIC ALTAR: 10 MYTHIC modules from the vault -> 1 perk point with guaranteed ENHANCED+ cards
----------------------------------------------------------------------
G.ALTAR_COST = 10
G.altar = nil
function G.altarMythics()
  local list = {}
  for _, m in ipairs(G.S.modules) do if m.r == D.MYTHIC then list[#list + 1] = m end end
  table.sort(list, function(a, b) return G.modScore(a) < G.modScore(b) end) -- weakest are fed first
  return list
end
function G.openAltar()
  G.altar = {phase = "idle", t = 0}
  FX.play("unlock", 0.7)
end
function G.altarTransmute(n)
  local S = G.S
  local list = G.altarMythics()
  n = math.min(n, math.floor(#list / G.ALTAR_COST))
  if n < 1 then FX.play("err") return end
  local used = {}
  for k = 1, n * G.ALTAR_COST do used[list[k]] = true end
  for k = #S.modules, 1, -1 do if used[S.modules[k]] then table.remove(S.modules, k) end end
  n = n * (1 + G.tr("sv_mythic"))
  S.perkPoints = S.perkPoints + n
  S.mythicRolls = (S.mythicRolls or 0) + n
  S.transmutes = (S.transmutes or 0) + n
  G.perkRoll = nil -- the next roll is a boosted one
  G.altarReturn = true
  G.altar = {phase = "burn", t = 0, n = n}
  FX.play("surge", 0.8)
end
