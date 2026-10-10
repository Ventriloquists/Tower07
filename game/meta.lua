-- Meta loops: rank-up perks, Signal Track (season pass), timed world events,
-- claimable log rewards and the objectives tracker. Extends G from game/core.lua.
local H = require "lib.hud"
local FX = require "game.fx"
local D = require "game.data"
local G = require "game.core"
local V = require "lib.view"

local C, fmt, rnd = H.C, H.fmt, H.rnd

function G.rankTitle(r)
  local t = "TRAINEE"
  for _, x in ipairs(D.RANK_TITLES) do if r >= x[1] then t = x[2] end end
  return t
end

----------------------------------------------------------------------
-- Perks: every rank-up grants a point; spend it on 1 of 3 rolled cards
----------------------------------------------------------------------
G.perkChoice = nil -- the open modal
G.perkRoll = nil   -- the pending roll (kept when the modal is closed, so no free rerolls)

local function rollPerks()
  local pool = {}
  for _, p in ipairs(D.PERKS) do pool[#pool + 1] = p end
  local cands = {}
  for k = 1, 3 do
    local p = table.remove(pool, love.math.random(#pool))
    local x = love.math.random() * 100
    local g = x < 5 and 3 or (x < 30 and 2 or 1)
    cands[k] = {def = p, grade = g}
  end
  return {cands = cands, t = 0, flipped = {}}
end

function G.perkText(def, stacks) return string.format(def.desc, def.per * stacks) end

function G.openPerkChoice()
  if G.S.perkPoints <= 0 then FX.play("err") return end
  G.perkRoll = G.perkRoll or rollPerks()
  G.perkRoll.t, G.perkRoll.flipped = 0, {}
  G.perkChoice = G.perkRoll
  FX.play("unlock", 1.2)
end
function G.closePerks() G.perkChoice = nil end
function G.perkCardX(k) return 640 + (k - 2) * 260 end

function G.pickPerk(k)
  local S = G.S
  local ch = G.perkChoice
  if not ch or ch.t < 0.75 * G.revealScale() then return end
  local c = ch.cands[k]
  local gr = D.PERK_GRADE[c.grade]
  S.perks[c.def.id] = (S.perks[c.def.id] or 0) + gr.stacks
  S.perkPoints = S.perkPoints - 1
  G.perkRoll, G.perkChoice = nil, nil
  G.recalc()
  local cc = C[gr.col]
  local x, y = G.perkCardX(k), 360
  FX.burst(x, y, 60 + c.grade * 50, cc, 300 + c.grade * 120, 2.5)
  FX.ray(x, y, cc, 1 + c.grade * 0.6, 200 + c.grade * 150)
  if c.grade >= 2 then FX.flashTo(cc, 0.2 * c.grade); FX.shake = math.max(FX.shake, c.grade * 6) end
  FX.play(c.grade == 3 and "jackpot" or "unlock", 1 + c.grade * 0.1)
  FX.toast("PERK INSTALLED // " .. c.def.name:upper(), G.perkText(c.def, gr.stacks) .. "  (" .. gr.name .. ")", cc)
  if S.perkPoints > 0 then G.perkRoll = rollPerks(); G.perkChoice = G.perkRoll end
end

----------------------------------------------------------------------
-- Signal Track: endless season-pass tiers fed by all XP
----------------------------------------------------------------------
function G.passNeed(t) return 300 + 60 * math.min(t, 50) end
function G.passReady() return G.S.passTier - G.S.passClaimed end

local function applyPass(t, px, py, quiet)
  local S = G.S
  local r = D.passReward(t)
  if r.hydro then S.hydro = S.hydro + r.hydro end
  if r.parts then S.parts = S.parts + r.parts end
  if r.tokens then S.tokens = S.tokens + r.tokens end
  if r.crate then
    if quiet then
      table.insert(S.crateList, {x = G.TX, y = G.TY, r = r.crate, t = 0})
      G.openCrate(#S.crateList, true)
    else
      G.grantCrate(r.crate, px, py)
    end
  end
  return r
end

function G.claimPass()
  local S = G.S
  if S.passClaimed >= S.passTier then FX.play("err") return end
  local t = S.passClaimed + 1
  S.passClaimed = t
  local mx, my = V.mouse()
  local r = applyPass(t, mx, my)
  FX.burst(mx, my, r.big and 80 or 30, C[r.col] or C.line, r.big and 420 or 240)
  FX.floater(mx, my - 24, "TIER " .. t .. " // " .. r.text, C[r.col] or C.white, H.fonts.m, 1.6)
  if not r.crate then FX.play("crate", 1.1) end
end

function G.claimAllPass()
  local S = G.S
  local n = S.passTier - S.passClaimed
  if n <= 0 then FX.play("err") return end
  local mx, my = V.mouse()
  local best
  for t = S.passClaimed + 1, S.passTier do
    local r = D.passReward(t)
    if r.crate and (not best or r.crate > D.passReward(best).crate) then best = t end
  end
  for t = S.passClaimed + 1, S.passTier do applyPass(t, mx, my, t ~= best) end
  S.passClaimed = S.passTier
  FX.burst(mx, my, 60, C.orange, 400)
  FX.toast("SIGNAL TRACK // " .. n .. " TIERS CLAIMED", "Rewards delivered. Crate loot is in the salvage log.", C.orange)
  if not best then FX.play("jackpot", 1.2) end
end

----------------------------------------------------------------------
-- Timed world events
----------------------------------------------------------------------
G.event, G.nextEvent = nil, nil
local stormT = 0

function G.scheduleEvent(delay)
  local def = D.EVENTS[love.math.random(#D.EVENTS)]
  if G.lastEventId and def.id == G.lastEventId then def = D.EVENTS[love.math.random(#D.EVENTS)] end
  G.nextEvent = {def = def, t = delay}
end

function G.startEvent(def)
  G.event = {def = def, t = D.EVENT_DURATION, dur = D.EVENT_DURATION}
  G.lastEventId = def.id
  if def.id == "GOLDEN" then G.addBuff("GOLDEN HOUR", "prod", 3, D.EVENT_DURATION) end
  G.recalc()
  local c = C[def.col]
  G.rankBanner = {t = 0, title = "EVENT // " .. def.name, text = def.desc .. "  //  " .. D.EVENT_DURATION .. " SECONDS", c = c}
  FX.toast("EVENT STARTED // " .. def.name, def.desc, c)
  FX.flashTo(c, 0.35)
  FX.play("raid", 1.3, 0.6)
  FX.play("unlock", 0.9)
end

function G.endEvent()
  local def = G.event.def
  G.event = nil
  G.recalc()
  G.scheduleEvent(rnd(600, 1080))
  FX.toast("EVENT ENDED // " .. def.name, "Next event: " .. G.nextEvent.def.name .. " in " .. H.fmtTime(G.nextEvent.t), C.dim)
end

----------------------------------------------------------------------
-- Claimable log rewards
----------------------------------------------------------------------
function G.unclaimedLogs()
  local S, n = G.S, 0
  for i = 1, #D.ACH do if S.ach[i] and not S.achClaim[i] then n = n + 1 end end
  return n
end
function G.logReward(i) return 3 + math.floor(i / 6), 3 + math.floor(i / 8) end

function G.claimLog(i, quiet)
  local S = G.S
  if not S.ach[i] or S.achClaim[i] then return 0, 0, 0 end
  S.achClaim[i] = true
  S.logClaims = S.logClaims + 1
  local pa, hy = G.logReward(i)
  S.parts, S.hydro = S.parts + pa, S.hydro + hy
  local tk = (S.logClaims % 10 == 0) and 1 or 0
  S.tokens = S.tokens + tk
  G.addXP(10)
  if not quiet then
    local mx, my = V.mouse()
    FX.burst(mx, my, 24 + tk * 30, tk > 0 and C.orange or C.line, 220)
    FX.floater(mx, my - 14, "+" .. pa .. " PARTS +" .. hy .. " H2O" .. (tk > 0 and " +1 TOKEN" or ""), tk > 0 and C.orange or C.white, H.fonts.s, 1.3)
    FX.play("crate", 1.2 + math.min(0.6, (S.logClaims % 10) * 0.06))
  end
  return pa, hy, tk
end

function G.claimAllLogs()
  local S = G.S
  local n, pa, hy, tk = 0, 0, 0, 0
  for i = 1, #D.ACH do
    if S.ach[i] and not S.achClaim[i] then
      local a, b, c = G.claimLog(i, true)
      n, pa, hy, tk = n + 1, pa + a, hy + b, tk + c
    end
  end
  if n == 0 then FX.play("err") return end
  local mx, my = V.mouse()
  FX.burst(mx, my, 40 + math.min(n, 60) * 3, tk > 0 and C.orange or C.line, 420)
  FX.floater(mx, my - 30, n .. " LOG REWARDS", C.white, H.fonts.l, 1.6)
  FX.floater(mx, my - 4, "+" .. fmt(pa) .. " PARTS  +" .. fmt(hy) .. " H2O" .. (tk > 0 and ("  +" .. tk .. " TOKENS") or ""), C.orange, H.fonts.s, 1.8)
  FX.play(tk > 0 and "jackpot" or "crate", 1.1)
  FX.toast("LOG REWARDS CLAIMED // " .. n, "+" .. fmt(pa) .. " parts, +" .. fmt(hy) .. " hydro" .. (tk > 0 and (", +" .. tk .. " tokens") or ""), C.orange)
end

----------------------------------------------------------------------
-- Objectives tracker (claimables first, then the nearest goals)
----------------------------------------------------------------------
function G.goals()
  local S = G.S
  local list = {}
  local function add(g) list[#list + 1] = g end
  if not G.dailyPending and S.daily.last ~= G.today() then
    add{icon = "event", title = "DAILY SUPPLY READY", text = "Day " .. G.dailyNextStreak() .. " of your shift streak", c = C.orange,
      ready = true, label = "CLAIM", fn = G.claimDaily}
  end
  if S.perkPoints > 0 then
    add{icon = "perk", title = "PERK READY x" .. S.perkPoints, text = "Choose an overclock upgrade", c = C.gold, ready = true,
      label = "CHOOSE", fn = G.openPerkChoice}
  end
  local nl = G.unclaimedLogs()
  if nl > 0 then
    add{icon = "archive", title = nl .. " LOG REWARD" .. (nl > 1 and "S" or ""), text = "Parts, hydro and tokens", c = C.orange,
      ready = true, label = "CLAIM", fn = G.claimAllLogs}
  end
  if S.passTier > S.passClaimed then
    local t = S.passClaimed + 1
    add{icon = "xp", title = "SIGNAL TRACK TIER " .. t, text = D.passReward(t).text, c = C.orange, ready = true,
      label = "CLAIM", fn = G.claimPass}
  end
  for i, d in ipairs(S.directives) do
    if G.dirProgress(d) >= d.target then
      add{icon = "ops", title = "DIRECTIVE COMPLETE", text = G.dirText(d), c = C.orange, ready = true,
        label = "CLAIM", fn = function() G.claimDirective(i) end}
    end
  end
  for i, r in ipairs(S.rigs) do
    if r.on and r.tank >= G.rigCap(i) then
      add{icon = "rigs", title = "RIG R" .. i .. " AT PEAK", text = "Collect now: +25% bonus", c = C.orange, ready = true,
        label = "COLLECT", fn = function() G.collectRig(i) end}
    end
  end
  if S.bossDown then
    add{icon = "map", title = "ZONE " .. S.zone .. " CLEARED", text = "Advance for stronger loot", c = C.gold, ready = true,
      label = "GO", fn = function() G.tab = "map" end}
  end
  if #S.crateList > 0 and G.unlocked("map") then
    add{icon = "crate", title = #S.crateList .. " CRATE" .. (#S.crateList > 1 and "S" or "") .. " ON MAP", text = "Loot is waiting", c = C.orange,
      ready = true, label = "GO", fn = function() G.tab = "map" end}
  end
  local g = G.dmGain()
  if g >= math.max(1, S.dmTotal * 0.5) then
    add{icon = "nova", title = "REBOOT READY", text = "+" .. fmt(g) .. " Core Data", c = C.red, ready = true,
      label = "GO", fn = function() G.tab = "nova" end}
  end
  -- progress goals
  for _, a in ipairs(D.ARCHIVE) do
    if G.achCount < a.n then
      add{icon = "archive", title = "NEXT UNLOCK // " .. a.n .. " LOGS", text = a.text, prog = G.achCount / a.n, c = C.line,
        fn = function() G.tab = "archive" end}
      break
    end
  end
  local bestD, bestF
  for _, d in ipairs(S.directives) do
    local f = G.dirProgress(d) / d.target
    if f < 1 and (not bestF or f > bestF) then bestD, bestF = d, f end
  end
  if bestD and G.unlocked("ops") then
    add{icon = "ops", title = bestD.priority and "PRIORITY DIRECTIVE" or "DIRECTIVE", text = G.dirText(bestD), prog = math.max(0, bestF),
      c = bestD.priority and C.orange or C.line, fn = function() G.tab = "ops" end}
  end
  local bi, bf, bms
  for i = 1, #D.GENS do
    if S.gens[i] > 0 then
      local ms, prev = G.nextMilestone(i)
      if ms then
        local f = (S.gens[i] - prev) / (ms - prev)
        if not bf or f > bf then bi, bf, bms = i, f, ms end
      end
    end
  end
  if bi then
    add{icon = "build", title = D.GENS[bi].name:upper() .. " " .. S.gens[bi] .. "/" .. bms, text = "Unit output x2 at " .. bms,
      prog = bf, c = C.line, fn = function() G.tab = "build" end}
  end
  add{icon = "xp", title = "RANK " .. (S.rank + 1), text = "+1 perk point, rank rewards", prog = S.xp / G.xpNeed(S.rank), c = C.line}
  add{icon = "xp", title = "SIGNAL TRACK TIER " .. (S.passTier + 1), text = D.passReward(S.passTier + 1).text,
    prog = S.sxp / G.passNeed(S.passTier + 1), c = C.line, fn = function() G.tab = "ops" end}
  return list
end

----------------------------------------------------------------------
-- Update
----------------------------------------------------------------------
function G.metaUpdate(dt)
  local S = G.S
  -- pass tiers
  while S.sxp >= G.passNeed(S.passTier + 1) do
    S.sxp = S.sxp - G.passNeed(S.passTier + 1)
    S.passTier = S.passTier + 1
    local r = D.passReward(S.passTier)
    FX.toast("SIGNAL TRACK // TIER " .. S.passTier .. " REACHED", r.text .. " ready to claim", r.big and C.gold or C.orange)
    if r.big then FX.play("unlock", 1.3) end
  end
  -- events
  if not G.event and not G.nextEvent then G.scheduleEvent(480) end
  if G.event then
    G.event.t = G.event.t - dt
    if G.event.def.id == "STORM" then
      stormT = stormT - dt
      if stormT <= 0 and not G.signal and not G.modal then G.spawnSignal(); stormT = rnd(4, 8) end
    end
    if G.event.t <= 0 then G.endEvent() end
  elseif not G.modal then
    G.nextEvent.t = G.nextEvent.t - dt
    if G.nextEvent.t <= 0 then
      local def = G.nextEvent.def
      G.nextEvent = nil
      G.startEvent(def)
    end
  end
  -- perk card flips
  local pc = G.perkChoice
  if pc then
    local before = pc.t
    pc.t = pc.t + dt
    for k = 1, 3 do
      local ft = (0.15 + (k - 1) * 0.2) * G.revealScale()
      if before < ft and pc.t >= ft then
        pc.flipped[k] = true
        local gr = pc.cands[k].grade
        local cc = C[D.PERK_GRADE[gr].col]
        FX.burst(G.perkCardX(k), 360, 20 + gr * 30, cc, 240)
        FX.play(gr >= 2 and "unlock" or "tick", 1 + gr * 0.15, gr >= 2 and 0.8 or 0.6)
        if gr == 3 then FX.ray(G.perkCardX(k), 360, cc, 1.6, 300); FX.shake = math.max(FX.shake, 8) end
      end
    end
  end
end

return G
