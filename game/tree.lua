-- PROTOCOL TREE: Core Data skill tree. A hub with 6 spokes; nodes can have several ranks.
-- The 19 original protocol ids are kept, so saves keep what they bought (S.pupg[id] = true or a rank number).
-- Positions: d = distance along the spoke, s = sideways offset (in tree units).
local G = require "game.core"
local FX = require "game.fx"
local H = require "lib.hud"
local C = H.C
local fmt = H.fmt

local T = {}
T.BRANCHES = {
  {id = "ECONOMY", a = -90, col = "line",   icon = "energy"},
  {id = "CORE",    a = -30, col = "orange", icon = "core"},
  {id = "FLEET",   a = 30,  col = "white",  icon = "hangar"},
  {id = "MAP",     a = 90,  col = "red",    icon = "map"},
  {id = "SALVAGE", a = 150, col = "gold",   icon = "crate"},
  {id = "SIGNALS", a = 210, col = "teal",   icon = "event"},
}
local function pct(p) return function(r) return "+" .. math.floor(p * r + 0.5) .. "%" end end
local function neg(p) return function(r) return "-" .. math.floor(p * r + 0.5) .. "%" end end
local function plus(p, u) return function(r) return "+" .. (p * r) .. (u or "") end end

T.NODES = {
  -- ECONOMY
  {id = "starter",  b = "ECONOMY", d = 1, s = 0, req = "root", name = "Preloaded Fleet", desc = "Each reboot starts with 10 Probes + 5 Drones", cost = 5},
  {id = "eco_out",  b = "ECONOMY", d = 2, s = 0, req = "starter", name = "Output Matrix", desc = "+25% ALL output per rank", max = 10, cost = 8, grow = 1.6, now = pct(25)},
  {id = "cheap",    b = "ECONOMY", d = 3, s = 0, req = "eco_out", name = "Fabricator Override", desc = "Unit cost -10%", cost = 250},
  {id = "eco_cost", b = "ECONOMY", d = 2.6, s = -1, req = "eco_out", name = "Bulk Procurement", desc = "-3% unit cost per rank", max = 5, cost = 40, grow = 1.8, now = neg(3)},
  {id = "eco_cd",   b = "ECONOMY", d = 2.6, s = 1, req = "eco_out", name = "Data Compression", desc = "+10% Core Data from reboots per rank", max = 10, cost = 60, grow = 1.7, now = pct(10)},
  {id = "legacy",   b = "ECONOMY", d = 4, s = 0, req = "cheap", name = "Legacy Protocol", desc = "ALL output x3", cost = 1500, big = true},
  {id = "eco_out2", b = "ECONOMY", d = 4.6, s = -1, req = "legacy", name = "Hyper Matrix", desc = "ALL output x1.5 per rank", max = 5, cost = 5000, grow = 2.5,
    now = function(r) return string.format("x%.2f", 1.5 ^ r) end},
  {id = "echo",     b = "ECONOMY", d = 5, s = 0, req = "legacy", name = "Omega Directive", desc = "ALL output x10", cost = 50000, big = true},
  {id = "eco_final", b = "ECONOMY", d = 6, s = 0, req = "echo", name = "Singularity", desc = "ALL output x100", cost = 1000000, big = true},
  -- CORE
  {id = "fingers",   b = "CORE", d = 1, s = 0, req = "root", name = "Neural Uplink", desc = "Tap power x3", cost = 15},
  {id = "core_tap",  b = "CORE", d = 2, s = 0, req = "fingers", name = "Tap Amplifier", desc = "+50% tap power per rank", max = 10, cost = 10, grow = 1.5, now = pct(50)},
  {id = "core_heat", b = "CORE", d = 1.6, s = 1, req = "fingers", name = "Heat Sink", desc = "Sweet spot starts 3% lower per rank (wider gold zone)", max = 5, cost = 25, grow = 1.6, now = plus(3, "% wider")},
  {id = "auto",      b = "CORE", d = 3, s = 0, req = "core_tap", name = "Ghost Technician", desc = "Auto-tap +10/s", cost = 600},
  {id = "core_crit", b = "CORE", d = 2.6, s = -1, req = "core_tap", name = "Crit Lattice", desc = "+1% tap crit chance per rank", max = 6, cost = 60, grow = 1.6, now = pct(1)},
  {id = "core_auto", b = "CORE", d = 2.6, s = 1, req = "core_tap", name = "Phantom Hands", desc = "Auto-tap +5/s per rank", max = 10, cost = 150, grow = 1.5, now = plus(5, "/s")},
  {id = "synergy",   b = "CORE", d = 4, s = 0, req = "auto", name = "Archive Synergy", desc = "+1% output per log entry (extra)", cost = 10000, big = true},
  {id = "core_surge", b = "CORE", d = 3.6, s = 1, req = "auto", name = "Surge Capacitor", desc = "Core Surge lasts +3s per rank", max = 5, cost = 300, grow = 1.8, now = plus(3, "s")},
  {id = "core_vent", b = "CORE", d = 3.6, s = -1, req = "auto", name = "Cryo Vent", desc = "Overheat lockout -0.6s per rank", max = 5, cost = 1000, grow = 1.7,
    now = function(r) return "-" .. (0.6 * r) .. "s" end},
  -- FLEET
  {id = "repair",   b = "FLEET", d = 1, s = 0, req = "root", name = "Field Repair", desc = "Missing drones return 3x faster", cost = 50},
  {id = "fl_power", b = "FLEET", d = 1.6, s = 1, req = "repair", name = "Drone Overclock", desc = "+20% drone power per rank", max = 10, cost = 20, grow = 1.5, now = pct(20)},
  {id = "bay",      b = "FLEET", d = 2, s = 0, req = "repair", name = "Bay Expansion", desc = "+6 drone bay slots", cost = 80},
  {id = "fl_speed", b = "FLEET", d = 2.6, s = -1, req = "bay", name = "Ion Thrusters", desc = "+10% drone speed per rank", max = 5, cost = 40, grow = 1.6, now = pct(10)},
  {id = "rapid",    b = "FLEET", d = 3, s = 0, req = "bay", name = "Rapid Deployment", desc = "Claim missions 50% faster", cost = 150},
  {id = "fl_bay",   b = "FLEET", d = 3.6, s = 1, req = "rapid", name = "Hangar Annex", desc = "+2 drone bay slots per rank", max = 5, cost = 200, grow = 1.8, now = plus(2, " slots")},
  {id = "lucky",    b = "FLEET", d = 4, s = 0, req = "rapid", name = "Lucky Fabricator", desc = "Better rarity odds when fabricating", cost = 300},
  {id = "fl_yield", b = "FLEET", d = 4.6, s = -1, req = "lucky", name = "Yield Tuning", desc = "+15% drone yield per rank", max = 10, cost = 250, grow = 1.6, now = pct(15)},
  {id = "fl_fab",   b = "FLEET", d = 5, s = 0, req = "lucky", name = "Fab Discount", desc = "-5% fab cost per rank", max = 6, cost = 500, grow = 1.7, now = neg(5)},
  {id = "fl_fiesta", b = "FLEET", d = 6, s = 0, req = "fl_fab", name = "Party Protocol", desc = "+50% loot fiesta bonus pulls per rank", max = 4, cost = 2000, grow = 2, now = pct(50), big = true},
  -- MAP
  {id = "carto",      b = "MAP", d = 1, s = 0, req = "root", name = "Cartographer", desc = "New sector maps start with scan radius 4", cost = 60},
  {id = "map_scan",   b = "MAP", d = 1.6, s = -1, req = "carto", name = "Wide Sensors", desc = "New maps reveal +1 scan radius per rank", max = 4, cost = 30, grow = 1.7, now = plus(1, " radius")},
  {id = "turret",     b = "MAP", d = 2, s = 0, req = "carto", name = "Tower Turret Mk II", desc = "Tower turret damage x5, range +1", cost = 120},
  {id = "map_deep",   b = "MAP", d = 2.6, s = 1, req = "turret", name = "Deep Scan", desc = "Claimed sectors reveal +0.5 radius per rank", max = 4, cost = 50, grow = 1.6, now = plus(0.5, " radius")},
  {id = "map_range",  b = "MAP", d = 3, s = 0, req = "turret", name = "Long-Range Ops", desc = "Claim sectors 1 further from your territory per rank", max = 2, cost = 400, grow = 3, now = plus(1, " sector"), big = true},
  {id = "map_turret", b = "MAP", d = 3.6, s = -1, req = "map_range", name = "Turret Arrays", desc = "Turret range +0.5 and damage +50% per rank", max = 5, cost = 150, grow = 1.6, now = pct(50)},
  {id = "map_tet",    b = "MAP", d = 4, s = 0, req = "map_range", name = "Uplink Capacitor", desc = "TET strike charges 25% faster per rank", max = 4, cost = 300, grow = 1.7, now = pct(25)},
  {id = "map_bounty", b = "MAP", d = 4.6, s = 1, req = "map_tet", name = "Bounty Contracts", desc = "+60s mothership bounty time per rank", max = 3, cost = 500, grow = 2, now = plus(60, "s")},
  {id = "map_zone",   b = "MAP", d = 5, s = 0, req = "map_tet", name = "Zone Cartel", desc = "Each cleared zone: +5% more output per rank", max = 5, cost = 2000, grow = 1.8, now = pct(5)},
  -- SALVAGE
  {id = "tractor",  b = "SALVAGE", d = 1, s = 0, req = "root", name = "Tractor Beam", desc = "Crates auto-open after 8 seconds", cost = 20},
  {id = "sv_luck",  b = "SALVAGE", d = 1.6, s = 1, req = "tractor", name = "Lucky Scanner", desc = "+5% loot luck per rank", max = 8, cost = 25, grow = 1.5, now = pct(5)},
  {id = "sv_salv",  b = "SALVAGE", d = 1.6, s = -1, req = "tractor", name = "Salvage Rights", desc = "+30% parts from salvaging modules per rank", max = 5, cost = 40, grow = 1.6, now = pct(30)},
  {id = "vault",    b = "SALVAGE", d = 2, s = 0, req = "tractor", name = "Vault Expansion", desc = "+40 module vault slots", cost = 400},
  {id = "sv_vault", b = "SALVAGE", d = 3, s = 0, req = "vault", name = "Vault Annex", desc = "+20 module vault slots per rank", max = 5, cost = 300, grow = 1.7, now = plus(20, " slots")},
  {id = "sv_crit",  b = "SALVAGE", d = 3.6, s = 1, req = "sv_vault", name = "Targeting Suite", desc = "+3% strike crit per rank", max = 5, cost = 200, grow = 1.6, now = pct(3)},
  {id = "sv_forge", b = "SALVAGE", d = 4, s = 0, req = "sv_vault", name = "Master Forge", desc = "Item level fusions +5% value per rank", max = 5, cost = 600, grow = 1.7, now = pct(5)},
  {id = "sv_altar", b = "SALVAGE", d = 5, s = 0, req = "sv_forge", name = "Altar Discount", desc = "Mythic Altar needs 1 module less per rank", max = 3, cost = 3000, grow = 2.5,
    now = function(r) return (10 - r) .. " per perk" end, big = true},
  -- SIGNALS
  {id = "hydro",     b = "SIGNALS", d = 1, s = 0, req = "root", name = "Hydro Pressure", desc = "Rig flow x2", cost = 30},
  {id = "sg_pump",   b = "SIGNALS", d = 1.6, s = -1, req = "hydro", name = "Deep Pumps", desc = "+30% rig flow per rank", max = 10, cost = 15, grow = 1.5, now = pct(30)},
  {id = "magnet",    b = "SIGNALS", d = 2, s = 0, req = "hydro", name = "Signal Beacon", desc = "Signal rate x2", cost = 40},
  {id = "sg_band",   b = "SIGNALS", d = 2.6, s = 1, req = "magnet", name = "Wide Band", desc = "+15% signal rate per rank", max = 5, cost = 60, grow = 1.6, now = pct(15)},
  {id = "memory",    b = "SIGNALS", d = 3, s = 0, req = "magnet", name = "Persistent Memory", desc = "Offline harvest 50% -> 100%, cap 12H -> 24H", cost = 100},
  {id = "sg_night",  b = "SIGNALS", d = 3.6, s = -1, req = "memory", name = "Night Shift", desc = "+4h offline harvest cap per rank", max = 3, cost = 200, grow = 1.8, now = plus(4, "h")},
  {id = "sg_event",  b = "SIGNALS", d = 3.6, s = 1, req = "memory", name = "Event Horizon", desc = "World events last +30s per rank", max = 4, cost = 400, grow = 1.7, now = plus(30, "s")},
  {id = "longcomet", b = "SIGNALS", d = 4, s = 0, req = "memory", name = "Signal Amplifier", desc = "Signal duration +50%", cost = 4000},
  {id = "sg_xp",     b = "SIGNALS", d = 5, s = 0, req = "longcomet", name = "Fast Learner", desc = "+20% XP per rank", max = 5, cost = 800, grow = 1.7, now = pct(20), big = true},
  -- second wave of protocols (deeper in every branch)
  {id = "eco_res",    b = "ECONOMY", d = 3.6, s = 1, req = "eco_cd", name = "Protocol Resonance", desc = "+1% ALL output per installed protocol rank, per rank", max = 3, cost = 500, grow = 2.2,
    now = function(r) return "+" .. r .. "% per rank" end},
  {id = "eco_out3",   b = "ECONOMY", d = 5.6, s = 1, req = "echo", name = "Quantum Ledger", desc = "+50% ALL output per rank", max = 10, cost = 200000, grow = 1.5, now = pct(50)},
  {id = "core_tap2",  b = "CORE", d = 4.6, s = -1, req = "synergy", name = "Neural Overdrive", desc = "Tap power x2 per rank", max = 5, cost = 30000, grow = 2,
    now = function(r) return "x" .. 2 ^ r end},
  {id = "core_rhythm", b = "CORE", d = 4.6, s = 1, req = "synergy", name = "Metronome", desc = "Perfect Rhythm needs 2s less in the sweet spot per rank", max = 4, cost = 2000, grow = 1.8,
    now = function(r) return (12 - 2 * r) .. "s" end},
  {id = "core_sweet", b = "CORE", d = 5, s = 0, req = "synergy", name = "Golden Zone", desc = "Sweet spot tap bonus +0.5x per rank", max = 5, cost = 5000, grow = 1.8,
    now = function(r) return "x" .. (2.5 + 0.5 * r) end},
  {id = "core_jack",  b = "CORE", d = 6, s = 0, req = "core_sweet", name = "Anomaly Engine", desc = "Jackpot tap chance +100% per rank", max = 4, cost = 20000, grow = 2, now = pct(100), big = true},
  {id = "fl_hull",    b = "FLEET", d = 1.6, s = -1, req = "repair", name = "Reinforced Frames", desc = "+25% drone hull per rank", max = 8, cost = 25, grow = 1.5, now = pct(25)},
  {id = "fl_dps",     b = "FLEET", d = 5.6, s = 1, req = "fl_fab", name = "Hunter Protocol", desc = "+20% drone damage per rank", max = 8, cost = 600, grow = 1.6, now = pct(20)},
  {id = "fl_pity",    b = "FLEET", d = 5.6, s = -1, req = "fl_fab", name = "Lucky Streak", desc = "ELITE+ guaranteed 1 batch sooner, PROTO+ 5 sooner, per rank", max = 4, cost = 800, grow = 1.7,
    now = function(r) return (10 - r) .. " / " .. (50 - 5 * r) end},
  {id = "fl_fuse",    b = "FLEET", d = 7, s = 0, req = "fl_fiesta", name = "Fusion Catalyst", desc = "Fused drones gain +1 level per rank", max = 5, cost = 3000, grow = 1.8, now = plus(1, " LV"), big = true},
  {id = "map_strike", b = "MAP", d = 1.6, s = 1, req = "carto", name = "Orbital Calibration", desc = "+50% orbital strike damage per rank", max = 8, cost = 20, grow = 1.5, now = pct(50)},
  {id = "map_rad",    b = "MAP", d = 3.6, s = 1, req = "map_range", name = "Rad Shielding", desc = "Radiation sectors claim 25% faster per rank", max = 4, cost = 250, grow = 1.6, now = pct(25)},
  {id = "map_alert",  b = "MAP", d = 5.6, s = -1, req = "map_zone", name = "Bait Beacons", desc = "+20% scav alert gain per rank", max = 5, cost = 800, grow = 1.7, now = pct(20)},
  {id = "map_spawn",  b = "MAP", d = 5.6, s = 1, req = "map_zone", name = "Hive Provocation", desc = "Scavs spawn 15% faster per rank", max = 5, cost = 600, grow = 1.6, now = pct(15)},
  {id = "map_boss",   b = "MAP", d = 6, s = 0, req = "map_zone", name = "Carrier Breaker", desc = "+50% damage to motherships per rank", max = 4, cost = 5000, grow = 2, now = pct(50), big = true},
  {id = "sv_crate",   b = "SALVAGE", d = 2.6, s = 1, req = "vault", name = "Crate Scanner", desc = "+10% chance per rank that a kill drops an extra crate", max = 5, cost = 150, grow = 1.6, now = pct(10)},
  {id = "sv_parts",   b = "SALVAGE", d = 2.6, s = -1, req = "vault", name = "Scrap Economy", desc = "+20% parts from crates per rank", max = 8, cost = 100, grow = 1.5, now = pct(20)},
  {id = "sv_tier",    b = "SALVAGE", d = 4.6, s = -1, req = "sv_forge", name = "Treasure Sense", desc = "Crates climb rarity 10% more often per rank", max = 5, cost = 1000, grow = 1.7, now = pct(10)},
  {id = "sv_mythic",  b = "SALVAGE", d = 6, s = 0, req = "sv_altar", name = "Mythic Resonance", desc = "Each altar transmutation forges +1 extra boosted perk point", max = 1, cost = 50000, big = true},
  {id = "sg_rig",     b = "SIGNALS", d = 2.6, s = -1, req = "magnet", name = "Rig Capacity", desc = "+50% rig tank size per rank", max = 5, cost = 50, grow = 1.6, now = pct(50)},
  {id = "sg_dream",   b = "SIGNALS", d = 6, s = 0, req = "sg_xp", name = "Dream Harvest", desc = "+25% offline harvest rate per rank", max = 4, cost = 5000, grow = 2, now = pct(25), big = true},
  -- OVERDRIVE: endless capstones, one per spoke. No rank cap, exponential cost: the late-game Core Data sink.
  {id = "od_eco",  b = "ECONOMY", d = 7.2, s = 0, req = "eco_final", name = "Overdrive: Infinite Ledger", desc = "ALL output x1.25 per rank. Endless.", max = math.huge,
    cost = 2e6, grow = 1.45, endless = true, now = function(r) return "x" .. fmt(1.25 ^ r) end},
  {id = "od_core", b = "CORE", d = 7.2, s = 0, req = "core_jack", name = "Overdrive: Endless Uplink", desc = "Tap power x1.3 per rank. Endless.", max = math.huge,
    cost = 2e5, grow = 1.45, endless = true, now = function(r) return "x" .. fmt(1.3 ^ r) end},
  {id = "od_fleet", b = "FLEET", d = 8.2, s = 0, req = "fl_fuse", name = "Overdrive: Endless Fleet", desc = "Drone power x1.2 per rank. Endless.", max = math.huge,
    cost = 2e5, grow = 1.45, endless = true, now = function(r) return "x" .. fmt(1.2 ^ r) end},
  {id = "od_map",  b = "MAP", d = 7.2, s = 0, req = "map_boss", name = "Overdrive: Siege Engines", desc = "Drone, strike and turret damage x1.2 per rank. Endless.", max = math.huge,
    cost = 2e5, grow = 1.45, endless = true, now = function(r) return "x" .. fmt(1.2 ^ r) end},
  {id = "od_salv", b = "SALVAGE", d = 7.2, s = 0, req = "sv_mythic", name = "Overdrive: Endless Salvage", desc = "Parts from crates x1.3 per rank. Endless.", max = math.huge,
    cost = 2e5, grow = 1.45, endless = true, now = function(r) return "x" .. fmt(1.3 ^ r) end},
  {id = "od_sig",  b = "SIGNALS", d = 7.2, s = 0, req = "sg_dream", name = "Overdrive: Endless Current", desc = "Rig flow x1.3 per rank. Endless.", max = math.huge,
    cost = 2e5, grow = 1.45, endless = true, now = function(r) return "x" .. fmt(1.3 ^ r) end},
}
T.SPREAD = 1.7
T.BYID = {}
local BR = {}
for _, b in ipairs(T.BRANCHES) do BR[b.id] = b end
for _, n in ipairs(T.NODES) do
  n.max = n.max or 1
  n.grow = n.grow or 1
  local a = math.rad(BR[n.b].a)
  -- spread along the spoke so side branches of neighbouring spokes never touch
  local d, s = n.d * T.SPREAD, n.s * 0.75
  n.x = d * math.cos(a) - s * math.sin(a)
  n.y = d * math.sin(a) + s * math.cos(a)
  n.col = BR[n.b].col
  T.BYID[n.id] = n
end

-- rank of a node (old saves stored `true`)
function G.tr(id)
  local v = G.S and G.S.pupg[id]
  if v == true then return 1 end
  return tonumber(v) or 0
end
function G.treeCost(n) return math.floor(n.cost * n.grow ^ G.tr(n.id)) end
function G.treeAvail(n) return n.req == "root" or G.tr(n.req) > 0 end
function G.treeCan(n)
  return G.treeAvail(n) and G.tr(n.id) < n.max and G.S.dm >= G.treeCost(n)
end
function G.treeBuy(n, quiet)
  local S = G.S
  if not G.treeCan(n) then if not quiet then FX.play("err") end return false end
  local c = G.treeCost(n)
  S.dm = S.dm - c
  local r = G.tr(n.id) + 1
  S.pupg[n.id] = n.max == 1 and true or r
  if quiet then return true end
  G.recalc()
  FX.play(n.big and "jackpot" or "unlock", 1 + r * 0.03)
  FX.toast("PROTOCOL " .. (n.max > 1 and ("RANK " .. r .. " // ") or "INSTALLED // ") .. n.name:upper(), n.desc, C[n.col])
  return true
end
-- buy as many ranks of one node as the bank allows
function G.treeBuyMax(n)
  local k = 0
  while k < 100000 and G.treeBuy(n, true) do k = k + 1 end
  if k == 0 then FX.play("err") return 0 end
  G.recalc()
  FX.play(n.big and "jackpot" or "unlock", 1.1)
  FX.toast("PROTOCOL " .. n.name:upper() .. " +" .. k .. " RANKS", n.desc, C[n.col])
  return k
end
-- spend the bank: always the cheapest affordable rank, so it spreads across the tree
function G.treeSpendAll()
  local k = 0
  while k < 200000 do
    local best, bc
    for _, n in ipairs(T.NODES) do
      if G.treeCan(n) then
        local c = G.treeCost(n)
        if not bc or c < bc then best, bc = n, c end
      end
    end
    if not best then break end
    G.treeBuy(best, true)
    k = k + 1
  end
  if k == 0 then FX.play("err") return 0 end
  G.recalc()
  FX.play("jackpot", 1.2)
  FX.toast("CORE DATA INVESTED", k .. " protocol ranks installed. Remaining bank: " .. fmt(G.S.dm) .. " CD.", C.orange)
  return k
end
function G.treeRanks()
  local k = 0
  for _, n in ipairs(T.NODES) do k = k + G.tr(n.id) end
  return k
end
function G.treeReady()
  local k = 0
  for _, n in ipairs(T.NODES) do if G.treeCan(n) then k = k + 1 end end
  return k
end

G.TREE = T
return T
