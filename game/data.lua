-- Static game data. Conditions receive the save state S (and G where noted).
local H = require "lib.hud"
local fmt = H.fmt
local D = {}

D.GENS = {
  {code = "PRB", name = "Scout Probe",      desc = "Skims trace energy from the ruins.",     cost = 15,     prod = 0.1},
  {code = "DRN", name = "Drone",            desc = "Armed harvester. Do not approach.",      cost = 100,    prod = 1},
  {code = "TDL", name = "Tidal Turbine",    desc = "Turns the tides into the fusion feed.",   cost = 1100,   prod = 8},
  {code = "FSN", name = "Fusion Pump",      desc = "Compresses ocean into pure output.",     cost = 12000,  prod = 47},
  {code = "SKY", name = "Sky Tower",        desc = "Another tower. Another technician.",     cost = 1.3e5,  prod = 260},
  {code = "ORB", name = "Orbital Relay",    desc = "Beams harvest straight to the station.", cost = 1.4e6,  prod = 1400},
  {code = "HVP", name = "Harvest Platform", desc = "Continental-scale extraction rig.",      cost = 2e7,    prod = 7800},
  {code = "ION", name = "Ion Lattice",      desc = "Charged mesh across the stratosphere.",  cost = 3.3e8,  prod = 44000},
  {code = "GRV", name = "Gravity Well",     desc = "Bends spacetime into a power line.",     cost = 5.1e9,  prod = 2.6e5},
  {code = "SSP", name = "Star Siphon",      desc = "Drinks directly from the sun.",          cost = 7.5e10, prod = 1.6e6},
  {code = "DYS", name = "Dyson Shell",      desc = "Wraps a star. Keeps everything.",        cost = 1e12,   prod = 1e7},
  {code = "SNG", name = "Singularity Core", desc = "Infinite density, infinite harvest.",      cost = 1.7e13, prod = 6.5e7},
  {code = "OMG", name = "Omega Array",      desc = "Harvests the end of time itself.",       cost = 3e14,   prod = 4.3e8},
  {code = "GEN", name = "Genesis Engine",   desc = "Builds new universes to harvest.",       cost = 6e15,   prod = 2.9e9},
  {code = "QSR", name = "Quasar Tap",       desc = "Drains a quasar's relativistic jet.",    cost = 1.5e17, prod = 2e10},
  {code = "VOD", name = "Void Engine",      desc = "Runs on the absence of everything.",     cost = 4e18,   prod = 1.4e11},
  {code = "CHR", name = "Chrono Reactor",   desc = "Harvests tomorrow's energy today.",      cost = 1e20,   prod = 1e12},
  {code = "ENT", name = "Entropy Mill",     desc = "Grinds heat death into fuel.",           cost = 3e21,   prod = 7.5e12},
  {code = "RLM", name = "Reality Loom",     desc = "Weaves new physics with better returns.",  cost = 1e23,   prod = 6e13},
  {code = "TPR", name = "Tower Prime",      desc = "The first tower. The last tower.",       cost = 5e24,   prod = 5e14},
}
D.MILESTONES = {25, 50, 100, 150, 200, 250, 300, 350, 400, 500, 600, 700, 800, 900, 1000}

----------------------------------------------------------------------
-- Tech upgrades
----------------------------------------------------------------------
D.UPGRADES = {}
do
  local U = D.UPGRADES
  local TIERN = {"Calibrated", "Reinforced", "Resonant", "Overclocked", "Quantum", "Hyperphase",
    "Transcendent", "Absolute", "Eternal", "Mythic", "Omega", "Infinite"}
  local TREQ  = {1, 5, 25, 50, 100, 150, 200, 300, 400, 500, 600, 750}
  local TCOST = {10, 50, 500, 5e4, 5e6, 5e8, 5e10, 5e13, 5e16, 5e19, 5e22, 5e25}
  for i, g in ipairs(D.GENS) do
    for k = 1, #TREQ do
      local req = TREQ[k]
      U[#U + 1] = {id = "g" .. i .. "_" .. k, code = g.code, name = TIERN[k] .. " " .. g.name,
        desc = g.name .. " output x2", cost = g.cost * TCOST[k],
        cond = function(S) return S.gens[i] >= req end, eff = {t = "gen", i = i, m = 2}}
    end
  end
  local CLICK = {
    {"Haptic Glove",      "Tap power x2",              100,  10,   {t = "click", m = 2}},
    {"Tactile Relay",     "Tap power x2",              1000, 50,   {t = "click", m = 2}},
    {"Pulse Driver",      "Tap power x2",              1e4,  150,  {t = "click", m = 2}},
    {"Neural Tap",        "Tap power +1% of output", 5e4,  300,  {t = "clickcps", p = 0.01}},
    {"Cortex Bridge",     "Tap power +1% of output", 5e6,  600,  {t = "clickcps", p = 0.01}},
    {"Command Authority", "Tap power +1% of output", 5e8,  1000, {t = "clickcps", p = 0.01}},
    {"Override Key",      "Tap power +2% of output", 5e10, 2000, {t = "clickcps", p = 0.02}},
    {"Prime Directive",   "Tap power +2% of output", 5e13, 4000, {t = "clickcps", p = 0.02}},
    {"Hand of the Tower", "Tap power +3% of output", 5e16, 8000, {t = "clickcps", p = 0.03}},
  }
  for k, c in ipairs(CLICK) do
    local req = c[4]
    U[#U + 1] = {id = "c" .. k, code = "TAP", name = c[1], desc = c[2], cost = c[3],
      cond = function(S) return S.clicks >= req end, eff = c[5]}
  end
  local SERVO = {
    {"Servo Arm Mk I",    1,  300,   1},
    {"Servo Arm Mk II",   2,  2e4,   6},
    {"Servo Arm Mk III",  3,  2e6,   14},
    {"Servo Cluster",     5,  2e8,   25},
    {"Servo Swarm",       8,  2e11,  40},
    {"Phantom Servos",    12, 2e14,  60},
    {"Servo Singularity", 20, 2e17,  90},
    {"Infinite Servos",   30, 2e20,  130},
  }
  for k, s in ipairs(SERVO) do
    local logs = s[4]
    U[#U + 1] = {id = "a" .. k, code = "AUT", name = s[1], desc = "Auto-tap +" .. s[2] .. "/s",
      cost = s[3], logs = logs, cond = function(S, G) return G.achCount >= logs end, eff = {t = "auto", n = s[2]}}
  end
  local GLOB = {"Grid Sync", "Coolant Loop", "Phase Alignment", "Dark Feed", "Entropy Reversal",
    "Hawking Siphon", "String Tuning", "Vacuum Harness", "Omega Point", "Absolute Zero",
    "Event Horizon", "False Vacuum", "Planck Lattice", "Zero Point", "Final Cycle"}
  for k, n in ipairs(GLOB) do
    local cost = 1e3 * 1000 ^ k
    U[#U + 1] = {id = "w" .. k, code = "SYS", name = n, desc = "ALL output x2", cost = cost,
      cond = function(S) return S.runEarned >= cost * 0.2 end, eff = {t = "global", m = 2}}
  end
  local ARCH = {
    {"l1", "Log Indexer",      "+1% output per log entry",       1e6,  20,  {t = "perlog", p = 0.01}},
    {"l2", "Signal Decoder",   "Signal duration +50%", 5e7,  30,  {t = "cometdur", m = 1.5}},
    {"l3", "Archive Engine",   "+2% output per log entry",       1e12, 60,  {t = "perlog", p = 0.02}},
    {"l4", "Hydro Compressor", "Rig flow x2",                    1e14, 80,  {t = "hydro", m = 2}},
    {"l5", "Total Recall",     "+3% output per log entry",       1e20, 120, {t = "perlog", p = 0.03}},
    {"l6", "Omniscient Index", "+5% output per log entry",       1e28, 170, {t = "perlog", p = 0.05}},
    {"l7", "Akashic Core",     "+8% output per log entry",       1e40, 240, {t = "perlog", p = 0.08}},
  }
  for _, a in ipairs(ARCH) do
    local logs = a[5]
    U[#U + 1] = {id = a[1], code = "LOG", name = a[2], desc = a[3], cost = a[4], logs = logs,
      cond = function(S, G) return G.achCount >= logs end, eff = a[6]}
  end
  U[#U + 1] = {id = "s1", code = "SIG", name = "Signal Scanner", desc = "Signal rate +30%", cost = 1e5,
    cond = function(S) return S.comets >= 1 end, eff = {t = "cometfreq", m = 1.3}}
  U[#U + 1] = {id = "s2", code = "SIG", name = "Signal Lock", desc = "Signal duration x2", cost = 1e7,
    cond = function(S) return S.comets >= 5 end, eff = {t = "cometdur", m = 2}}
  U[#U + 1] = {id = "s3", code = "SIG", name = "Deep Scanner", desc = "Signal rate +30%", cost = 1e9,
    cond = function(S) return S.comets >= 10 end, eff = {t = "cometfreq", m = 1.3}}
end

----------------------------------------------------------------------
-- Reboot (prestige) upgrades, paid with Core Data
----------------------------------------------------------------------
D.PUPG = {
  {id = "starter",   name = "Preloaded Fleet",     desc = "Each reboot starts with 10 Probes + 5 Drones", cost = 5},
  {id = "fingers",   name = "Neural Uplink",       desc = "Tap power x3",                                 cost = 15},
  {id = "tractor",   name = "Tractor Beam",        desc = "Crates auto-open after 8 seconds",        cost = 20},
  {id = "hydro",     name = "Hydro Pressure",      desc = "Rig flow x2",                    cost = 30},
  {id = "magnet",    name = "Signal Beacon",       desc = "Signal rate x2",                   cost = 40},
  {id = "repair",    name = "Field Repair",        desc = "Missing drones return 3x faster",               cost = 50},
  {id = "carto",     name = "Cartographer",        desc = "New sector maps start with scan radius 4",     cost = 60},
  {id = "bay",       name = "Bay Expansion",       desc = "+6 drone bay slots",                           cost = 80},
  {id = "memory",    name = "Persistent Memory",   desc = "Offline harvest 50% -> 100%, cap 12H -> 24H",  cost = 100},
  {id = "turret",    name = "Tower Turret Mk II",  desc = "Tower turret damage x5, range +1",             cost = 120},
  {id = "rapid",     name = "Rapid Deployment",    desc = "Claim missions 50% faster",              cost = 150},
  {id = "cheap",     name = "Fabricator Override", desc = "Unit cost -10%",                        cost = 250},
  {id = "lucky",     name = "Lucky Fabricator",    desc = "Better rarity odds when fabricating",                     cost = 300},
  {id = "vault",     name = "Vault Expansion",     desc = "+40 module vault slots",                       cost = 400},
  {id = "auto",      name = "Ghost Technician",    desc = "Auto-tap +10/s",                     cost = 600},
  {id = "legacy",    name = "Legacy Protocol",     desc = "ALL output x3",                                cost = 1500},
  {id = "longcomet", name = "Signal Amplifier",    desc = "Signal duration +50%",                         cost = 4000},
  {id = "synergy",   name = "Archive Synergy",     desc = "+1% output per log entry (extra)",            cost = 10000},
  {id = "echo",      name = "Omega Directive",     desc = "ALL output x10",                               cost = 50000},
}

----------------------------------------------------------------------
-- Drones
----------------------------------------------------------------------
D.RARITY = {
  {name = "STD",   col = "line",   power = 1,  bonus = 0.02, scrap = 2,   upk = 1,   slots = 2, traits = 1},
  {name = "ADV",   col = "white",  power = 3,  bonus = 0.05, scrap = 6,   upk = 1.5, slots = 2, traits = 1},
  {name = "ELITE", col = "orange", power = 8,  bonus = 0.12, scrap = 15,  upk = 2.5, slots = 2, traits = 1},
  {name = "PROTO", col = "red",    power = 20, bonus = 0.30, scrap = 40,  upk = 4,   slots = 3, traits = 2},
  {name = "OMEGA", col = "gold",   power = 60, bonus = 1.00, scrap = 150, upk = 6,   slots = 3, traits = 2},
}
D.TRAITS = {
  {id = "HUNTER",     desc = "Power +60% vs scavs"},
  {id = "SPRINTER",   desc = "Speed +60%, claim missions 40% faster"},
  {id = "HARVESTER",  desc = "Drone yield x2"},
  {id = "LUCKY",      desc = "Loot luck +15%"},
  {id = "JUGGERNAUT", desc = "Hull +100%"},
  {id = "ENGINEER",   desc = "Claim power +50%"},
  {id = "SALVAGER",   desc = "Crate parts + hydro +50%"},
}

----------------------------------------------------------------------
-- Loot: crate / module rarity tiers
----------------------------------------------------------------------
D.LOOT = {
  {name = "COMMON",    col = "dim",    secs = 30,   parts = 4,   hydro = 3,   mods = 0.10, nmods = 1, tokens = 0},
  {name = "UNCOMMON",  col = "line",   secs = 60,   parts = 10,  hydro = 8,   mods = 0.25, nmods = 1, tokens = 0},
  {name = "RARE",      col = "white",  secs = 180,  parts = 25,  hydro = 20,  mods = 0.50, nmods = 1, tokens = 0.05},
  {name = "EPIC",      col = "orange", secs = 420,  parts = 70,  hydro = 50,  mods = 0.90, nmods = 1, tokens = 0.25},
  {name = "LEGENDARY", col = "red",    secs = 900,  parts = 200, hydro = 150, mods = 1.00, nmods = 2, tokens = 1},
  {name = "MYTHIC",    col = "gold",   secs = 1800, parts = 600, hydro = 400, mods = 1.00, nmods = 3, tokens = 3},
}
D.LOOT_UP = {0, 0.35, 0.30, 0.25, 0.20, 0.15} -- chance to climb from tier k-1 to k
D.RMUL = {1, 1.6, 2.5, 4, 6.5, 11}
D.MODS = {
  {t = "PWR", name = "Power Cell",     base = 0.10, weight = 1.3, fmt = "+%d%% POWER"},
  {t = "ARM", name = "Hull Plating",   base = 0.20, weight = 0.6, fmt = "+%d%% HULL"},
  {t = "SPD", name = "Thruster",       base = 0.12, weight = 0.7, fmt = "+%d%% SPEED"},
  {t = "YLD", name = "Yield Lens",     base = 0.15, weight = 1.1, fmt = "+%d%% DRONE YIELD"},
  {t = "LCK", name = "Luck Matrix",    base = 0.04, weight = 0.9, fmt = "+%d%% LOOT LUCK"},
  {t = "CRT", name = "Targeting Chip", base = 0.03, weight = 0.8, fmt = "+%d%% STRIKE CRIT"},
}

----------------------------------------------------------------------
-- Scavs (enemies) and zones
----------------------------------------------------------------------
D.ENEMIES = {
  {id = "SCOUT",      hp = 10,   dps = 0.6, spd = 0.9,  tier = 1, crates = 1, xp = 5,   w = 50},
  {id = "RAIDER",     hp = 35,   dps = 1.5, spd = 0.6,  tier = 1, crates = 1, xp = 10,  w = 30},
  {id = "BRUTE",      hp = 140,  dps = 4,   spd = 0.35, tier = 2, crates = 2, xp = 25,  w = 14},
  {id = "ELITE",      hp = 500,  dps = 10,  spd = 0.5,  tier = 3, crates = 2, xp = 60,  w = 6},
  {id = "MOTHERSHIP", hp = 6000, dps = 35,  spd = 0.12, tier = 4, crates = 4, xp = 400, w = 0, boss = true},
}
D.ZONES = {"COASTAL RUINS", "CRATER BASIN", "OLD LIBRARY", "DEAD HIGHWAY", "RADIATION ZONE", "SCAV DELTA",
  "SKYLINE GRAVE", "DROWNED CITY", "NULL STRATA", "THE GLASS PLAIN", "BLACK MERIDIAN", "EDGE OF SIGNAL"}
function D.zoneName(z) return D.ZONES[z] or ("DEEP ZONE " .. z) end

----------------------------------------------------------------------
-- Rigs, daily
----------------------------------------------------------------------
D.RIG_BASE   = {5e3, 2e7, 5e10}
D.RIG_UNLOCK = {0, 2e6, 5e9}
D.DAILY = {
  {code = "D1", hydro = 25,  text = "25 H2O"},
  {code = "D2", parts = 12,  text = "12 PARTS"},
  {code = "D3", tokens = 1,  text = "1 TOKEN"},
  {code = "D4", hydro = 80,  text = "80 H2O"},
  {code = "D5", parts = 40,  text = "40 PARTS"},
  {code = "D6", tokens = 2,  text = "2 TOKENS"},
  {code = "D7", tokens = 3, core = true, text = "3 TOKENS + CD"},
}

----------------------------------------------------------------------
-- Rank-up perks (choose 1 of 3). Each card rolls a grade that sets stacks.
----------------------------------------------------------------------
D.PERKS = {
  {id = "OVERCLOCK", name = "Overclock",       desc = "+%d%% ALL output",               per = 10, icon = "energy"},
  {id = "STEADY",    name = "Steady Hand",     desc = "+%d%% tap power",                per = 25, icon = "core"},
  {id = "SERVO",     name = "Servo Link",      desc = "Auto-tap +%d/s",       per = 2,  icon = "core"},
  {id = "VALVES",    name = "Pressure Valves", desc = "+%d%% rig flow",                 per = 15, icon = "hydro"},
  {id = "HUNTER",    name = "Combat Firmware", desc = "+%d%% power (all drones)",              per = 10, icon = "hangar"},
  {id = "SENSE",     name = "Treasure Sense",  desc = "+%d%% loot luck",                per = 5,  icon = "crate"},
  {id = "TUNER",     name = "Signal Tuner",    desc = "+%d%% signal rate",         per = 10, icon = "event"},
  {id = "CRIT",      name = "Crit Matrix",     desc = "+%d%% strike crit",       per = 2,  icon = "xp"},
  {id = "CUTTER",    name = "Cost Cutter",     desc = "Unit cost -%d%% (max -50%%)",  per = 2,  icon = "build"},
  {id = "FABDISC",   name = "Fab Discount",    desc = "Fab cost -%d%% (max -60%%)", per = 5, icon = "parts"},
}
D.PERK_GRADE = {
  {name = "STANDARD", col = "line",   stacks = 1, w = 70},
  {name = "ENHANCED", col = "orange", stacks = 2, w = 25},
  {name = "PRIME",    col = "gold",   stacks = 3, w = 5},
}

D.RANK_TITLES = {{1, "TRAINEE"}, {5, "TECHNICIAN"}, {10, "SR TECHNICIAN"}, {20, "SUPERVISOR"}, {35, "COMMANDER"},
  {50, "DIRECTOR"}, {75, "ARCHITECT"}, {100, "OVERSEER"}, {150, "ASCENDANT"}}

----------------------------------------------------------------------
-- Timed world events
----------------------------------------------------------------------
D.EVENTS = {
  {id = "GOLDEN",   name = "GOLDEN HOUR",   desc = "All output x3",                      col = "gold"},
  {id = "STORM",    name = "SIGNAL STORM",  desc = "Signals arrive every few seconds",   col = "orange"},
  {id = "INVASION", name = "SCAV INVASION", desc = "Double scavs, crates drop one rarity higher",    col = "red"},
  {id = "HYDRO",    name = "HYDRO SURGE",   desc = "Rig flow x5",                 col = "line"},
  {id = "FRENZY",   name = "FAB FRENZY",    desc = "Fab cost -50%",       col = "white"},
  {id = "LUCKY",    name = "LUCKY STARS",   desc = "+50% loot luck, +10% strike crit",   col = "gold"},
}
D.EVENT_DURATION = 150

----------------------------------------------------------------------
-- Signal Track (season pass): endless tiers
----------------------------------------------------------------------
function D.passReward(t)
  if t % 25 == 0 then return {crate = 6, tokens = 3, text = "MYTHIC CRATE + 3 TOKENS", big = true, col = "gold"} end
  if t % 10 == 0 then return {crate = 5, tokens = 2, text = "LEGENDARY CRATE + 2 TOKENS", big = true, col = "red"} end
  local k = t % 5
  if k == 1 then local v = 20 + t * 6 return {hydro = v, text = "+" .. v .. " H2O", col = "line", icon = "hydro"} end
  if k == 2 then local v = 10 + t * 4 return {parts = v, text = "+" .. v .. " PARTS", col = "white", icon = "parts"} end
  if k == 3 then return {crate = 3, text = "RARE CRATE", col = "white"} end
  if k == 4 then return {tokens = 1, text = "+1 FAB TOKEN", col = "orange", icon = "token"} end
  return {crate = 4, text = "EPIC CRATE", col = "orange"}
end

----------------------------------------------------------------------
-- Reboot protocol tree: branches unlock left to right
----------------------------------------------------------------------
D.TREE = {
  {name = "ECONOMY", icon = "energy", ids = {"starter", "cheap", "legacy", "echo"}},
  {name = "CORE",    icon = "core",   ids = {"fingers", "auto", "synergy"}},
  {name = "FLEET",   icon = "hangar", ids = {"repair", "bay", "rapid", "lucky"}},
  {name = "SALVAGE", icon = "crate",  ids = {"tractor", "carto", "turret", "vault"}},
  {name = "SIGNALS", icon = "event",  ids = {"hydro", "magnet", "memory", "longcomet"}},
}

----------------------------------------------------------------------
-- Archive milestones: log entries unlock systems and grant boosts
----------------------------------------------------------------------
D.ARCHIVE = {
  {n = 16,  unlock = "ops",     text = "OPS // directives unlocked"},
  {n = 28,  unlock = "rigs",    text = "RIGS // hydro rigs online"},
  {n = 34,  click = 2,          text = "Tap power x2"},
  {n = 40,  unlock = "hangar",  text = "HANGAR // drone fabrication + 1 fab token", tokens = 1},
  {n = 48,  auto = 1,           text = "Auto-tap +1/s"},
  {n = 56,  unlock = "map",     text = "MAP // tactical sector map online"},
  {n = 62,  autoTech = true,    text = "AUTO-INSTALL TECH unlocked"},
  {n = 68,  unlock = "vault",   text = "VAULT // drone module loadouts online"},
  {n = 74,  prod = 1.5,         text = "ALL output x1.5"},
  {n = 80,  autoUnits = true,   text = "AUTO-ACQUIRE UNITS unlocked"},
  {n = 86,  signal = 1.25,      text = "Signal rate +25%"},
  {n = 92,  auto = 2,           text = "Auto-tap +2/s", tokens = 2},
  {n = 98,  autoRigs = true,    text = "AUTO-COLLECT RIGS unlocked"},
  {n = 106, prod = 2,           text = "ALL output x2"},
  {n = 114, hydro = 1.5,        text = "Rig flow x1.5"},
  {n = 122, prod = 2,           text = "ALL output x2", tokens = 3},
  {n = 132, auto = 5,           text = "Auto-tap +5/s"},
  {n = 140, click = 5,          text = "Tap power x5"},
  {n = 170, prod = 3,           text = "ALL output x3"},
  {n = 200, prod = 5,           text = "ALL output x5", tokens = 5},
  {n = 230, luck = 0.10,        text = "Loot luck +10%"},
  {n = 260, prod = 10,          text = "ALL output x10"},
  {n = 290, luck = 0.15,        text = "Loot luck +15%", tokens = 8},
  {n = 320, prod = 25,          text = "ALL output x25", tokens = 10},
}

----------------------------------------------------------------------
-- Log entries (achievements)
----------------------------------------------------------------------
D.ACH = {}
do
  local cnt = {}
  local function ach(cat, name, desc, cond)
    cnt[cat] = (cnt[cat] or 0) + 1
    D.ACH[#D.ACH + 1] = {code = cat .. cnt[cat], name = name, desc = desc, cond = cond}
  end
  local ks = {}
  for k = 1, 30 do ks[#ks + 1] = k end
  for k = 33, 90, 3 do ks[#ks + 1] = k end
  for n, k in ipairs(ks) do
    local th = 10 ^ k
    ach("E", "Reserve Level " .. n, "Harvest " .. fmt(th) .. " energy (lifetime)", function(S) return S.totalEarned >= th end)
  end
  local rates = {1, 10, 100, 1e3, 1e4, 1e5, 1e6}
  for k = 9, 60, 3 do rates[#rates + 1] = 10 ^ k end
  for _, th in ipairs(rates) do
    ach("R", "Flow " .. fmt(th), "Reach " .. fmt(th) .. " energy/sec", function(S) return S.bestCps >= th end)
  end
  for i, g in ipairs(D.GENS) do
    for _, c in ipairs({1, 10, 25, 50, 100, 200, 300, 500}) do
      ach("U", g.name .. " x" .. c, "Operate " .. c .. " " .. g.name .. " units", function(S) return S.gens[i] >= c end)
    end
  end
  local function series(cat, name, desc, key, list)
    for _, c in ipairs(list) do
      ach(cat, name .. " " .. fmt(c), desc:format(fmt(c)), function(S) return (S[key] or 0) >= c end)
    end
  end
  series("T", "Tap Count", "Tap the core %s times", "clicks", {1, 10, 100, 500, 1000, 5000, 10000, 50000, 100000})
  series("S", "Interceptor", "Intercept %s signals", "comets", {1, 5, 25, 100, 500})
  series("P", "Reboot", "Complete %s reboot protocols", "prestiges", {1, 3, 10, 25, 50})
  series("X", "Chain", "Reach a tap chain of %s", "maxCombo", {25, 50, 100, 200})
  series("G", "Engineer", "Install %s upgrades (lifetime)", "upBought", {10, 25, 50, 100, 250, 500})
  series("F", "Fabricator", "Fabricate %s drones", "fabsTotal", {1, 10, 50, 200, 500})
  series("V", "Prototype", "Recruit %s PROTO drones", "protoEver", {1, 5, 20})
  series("O", "Omega", "Recruit %s OMEGA drones", "omegaEver", {1, 3})
  series("M", "Cartographer", "Secure %s sectors (lifetime)", "claimsTotal", {1, 10, 50, 200, 1000, 5000})
  series("K", "Rank", "Reach technician rank %s", "rank", {5, 10, 25, 50, 100, 200})
  series("D", "Operative", "Complete %s directives", "dirDone", {1, 10, 50, 200, 500})
  series("H", "Hydro Tech", "Collect hydro rigs %s times", "rigCollects", {1, 10, 100, 500, 2000})
  series("A", "Relic Hunter", "Recover %s artifacts", "artifacts", {1, 5, 25, 100})
  series("J", "Anomaly", "Trigger %s jackpot taps", "jackpots", {1, 5, 20})
  series("Y", "Loyal Shift", "Reach a %s day shift streak", "bestStreak", {3, 7, 30})
  series("Q", "Scav Hunter", "Destroy %s scavs", "kills", {1, 10, 100, 1000, 10000, 50000})
  series("B", "Mothership Down", "Destroy %s motherships", "bosses", {1, 5, 25, 100})
  series("Z", "Zone Breaker", "Clear zone %s", "zoneBest", {1, 3, 5, 10, 15, 25, 50})
  series("C", "Looter", "Open %s loot crates", "crates", {10, 100, 1000, 5000, 20000})
  series("L", "Legend", "Open %s LEGENDARY+ crates", "legendary", {1, 10, 50})
  series("W", "Myth", "Open %s MYTHIC crates", "mythic", {1, 5, 20})
  series("I", "Defender", "Repel %s raids", "raidsRepelled", {1, 25, 250})
end

return D
