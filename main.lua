--[[
  TOWER 07 // HARVEST CONTROL
  An idle game for LOVE 11.x in an Oblivion-style HUD aesthetic.

  Click / SPACE = tap core   1-8 = scenes   ESC = back to CORE / settings   P = perks   B = buy mode
  M = mute   F11 = fullscreen   F12 = boss key
]]

local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
require "game.tac"
require "game.meta"
require "game.fiesta"
require "game.tree"
local D = require "game.data"
local Set = require "game.settings"
local Th = require "ui.themes"
local F = require "ui.frame"
local Ov = require "ui.overlays"
local Shatter = require "ui.shatter"
local Memes = require "game.memes"
G.meme = Memes.event
local SettingsUI = require "ui.settings"
local Disguise = require "ui.disguise"
local Reactor = require "ui.reactor"

local SCENES = {
  core = require "ui.scene_core",
  build = require "ui.scene_build",
  rigs = require "ui.scene_rigs",
  hangar = require "ui.scene_hangar",
  map = require "ui.scene_map",
  ops = require "ui.scene_ops",
  nova = require "ui.scene_reboot",
  archive = require "ui.scene_archive",
}

local scanCanvas, vignette
local selftest, stFrame = false, 0
local holdHit, holdT, holdRep = nil, 0, 0
local dragHit = nil
local focused = true
local frameStart = 0
local screenTab, screenT, prevTab, screenDir, screenDur = nil, 1, nil, 1, 0.4 -- station travel state
local lazyT = 0
local bossT = 0
G.lastInput = 0

local function buildOverlays()
  local w, h = love.graphics.getDimensions()
  scanCanvas = love.graphics.newCanvas(w, h)
  love.graphics.setCanvas(scanCanvas)
  love.graphics.clear(0, 0, 0, 0)
  love.graphics.setColor(0, 0, 0, 0.14)
  local step = math.max(3, math.floor(3 * V.s))
  for y = 0, h, step do love.graphics.rectangle("fill", 0, y, w, math.max(1, math.floor(V.s))) end
  love.graphics.setCanvas()
  if not vignette then
    local vw, vh = 160, 90
    local id = love.image.newImageData(vw, vh)
    for y = 0, vh - 1 do
      for x = 0, vw - 1 do
        local dx, dy = (x / (vw - 1) - 0.5) * 2, (y / (vh - 1) - 0.5) * 2
        local d = math.sqrt(dx * dx * 0.8 + dy * dy)
        id:setPixel(x, y, 0, 0, 0, H.clamp((d - 0.65) * 0.9, 0, 0.5))
      end
    end
    vignette = love.graphics.newImage(id)
    vignette:setFilter("linear", "linear")
  end
end

local function toggleFullscreen()
  local fs = love.window.getFullscreen()
  love.window.setFullscreen(not fs, "desktop")
  V.resize(love.graphics.getDimensions())
  buildOverlays()
end
G.toggleFullscreen = toggleFullscreen

----------------------------------------------------------------------
-- settings
----------------------------------------------------------------------
local lastVolume
local function applyVolume()
  local v = Set.v.master
  if FX.muted or G.bossMode or (Set.v.muteUnfocused and not focused) then v = 0 end
  if v ~= lastVolume then love.audio.setVolume(v); lastVolume = v end
end

local function applySettings(key)
  local v = Set.v
  if key == nil or key == "vsync" or key == "all" then love.window.setVSync(v.vsync and 1 or 0) end
  H.numFormat = v.numFormat
  FX.vol.ui, FX.vol.reward, FX.vol.alert = v.vUi, v.vReward, v.vAlert
  FX.setAmbient(v.ambient)
  FX.density = v.confetti
  FX.reduced = v.reducedMotion
  H.reduced = v.reducedMotion
  H.showTips = v.tooltips
  H.keywords = v.keywords
  G.fastReveal = v.fastReveal
  G.saveInterval = v.autosave
  G.breakInterval = v.grass * 60
  Th.apply(v.theme)
  -- memes live only inside the meme themes: sounds, captions, chatter, titles, callsigns
  local th = Th.get(v.theme)
  local memeTheme = th.sounds == "meme"
  G.memeOn = memeTheme
  FX.meme = memeTheme and not Memes.available() -- synth meme loot sounds only as a fallback without the sounds folder
  if FX.soundPack ~= "stupid" and memeTheme and Memes.available() then FX.soundPack = "meme" end
  Memes.enabled = memeTheme
  Memes.captionsOn = memeTheme and v.memeCaptions ~= false
  love.mouse.setVisible((not v.reticle) or G.bossMode == true)
  lastVolume = nil
  applyVolume()
end
SettingsUI.onChange = applySettings

function G.setBossMode(on)
  if on and not Set.v.bossKey and not G.settingsOpen then return end
  G.bossMode = on
  bossT = 0
  if on then
    love.window.setTitle(Disguise.TITLES[Set.v.disguise] or " ")
    G.save()
  end
  love.mouse.setVisible((on == true) or not Set.v.reticle)
  applyVolume()
end

local function napping()
  return Set.v.nap > 0 and not G.bossMode and not selftest and love.timer.getTime() - G.lastInput > Set.v.nap * 60
end

local function frameCap()
  if selftest then return nil end
  if napping() then return 10 end
  if not focused and Set.v.eco then return 15 end
  if G.bossMode then return 20 end
  if not Set.v.vsync and Set.v.fpsCap > 0 then return Set.v.fpsCap end
end

function love.load(args)
  for _, a in ipairs(args or {}) do if a == "--selftest" then selftest = true end end
  if selftest then love.filesystem.setIdentity("tower_harvest_selftest") end
  -- --sandbox: normal game, separate save folder (for testing without touching the real save)
  for _, a in ipairs(args or {}) do if a == "--sandbox" then love.filesystem.setIdentity("tower_harvest_sandbox") end end
  G.selftest = selftest
  H.snap = selftest -- deterministic screenshots: tweens land instantly
  if not selftest then
    Set.load()
    -- one-time move from the old default look to the redesigned house style
    if Set.v.designV < 1 then
      if Set.v.theme == "oblivion" then Set.v.theme = "command" end
      Set.v.designV = 1
      Set.save()
    end
  end
  love.math.setRandomSeed(os.time())
  love.graphics.setLineStyle("smooth")
  V.loadFontData()
  V.resize(love.graphics.getDimensions())
  H.initFonts()
  H.onError = function() FX.play("err") end
  H.setGlossary(require "game.glossary")
  FX.init()
  FX.initAmbient()
  buildOverlays()
  G.init(selftest)
  applySettings()
  G.lastInput = love.timer.getTime()
  for _, a in ipairs(args or {}) do if a == "--pace" then G.paceProbe() end end
  for _, a in ipairs(args or {}) do if a == "--zonesim" then G.zoneSim() end end
  for _, a in ipairs(args or {}) do if a == "--longrun" then G.longRun() elseif a == "--longrun-reboot" then G.longRun(true) elseif a == "--longrun-save" then G.longRun(true, true) end end
  for _, a in ipairs(args or {}) do if a == "--rescale" then G.rescaleSave() end end
  for _, a in ipairs(args or {}) do
    if a == "--econdiag" then
      -- read-only economy breakdown of the real save -> econdiag.txt (quits without saving)
      local ok, r = pcall(function() G.recalc(); return G.econReport() end)
      love.filesystem.write("econdiag.txt", tostring(r))
      selftest = true -- skip the save on quit
      love.event.quit()
    end
    if a == "--mapdiag" then
      local ok, r = pcall(function() G.recalc(); return G.mapReport() end)
      love.filesystem.write("mapdiag.txt", tostring(r))
      love.event.quit()
    end
  end
end

-- --rescale: one-time cleanup of a save inflated by the old XP / Signal Track / loot luck runaway.
-- Writes save_before_rescale.lua first, then rescale_report.txt.
function G.rescaleSave()
  local old = love.filesystem.read("save.lua")
  if not old then love.event.quit() return end
  love.filesystem.write("save_before_rescale.lua", old)
  G.init(false)
  local S = G.S
  local rep = {}
  local function note(k, a, b) rep[#rep + 1] = string.format("%-22s %s -> %s", k, tostring(a), tostring(b)) end
  note("signal track tier", S.passTier, math.min(S.passTier, 150)); S.passTier = math.min(S.passTier, 150); S.passClaimed = S.passTier; S.sxp = 0
  note("rank", S.rank, math.min(S.rank, 150)); S.rank = math.min(S.rank, 150); S.xp = 0
  note("perk points", S.perkPoints, math.min(S.perkPoints, 30)); S.perkPoints = math.min(S.perkPoints, 30)
  note("fab tokens", S.tokens, math.min(S.tokens, 150)); S.tokens = math.min(S.tokens, 150)
  -- PRISM drones: keep the 6 strongest
  local prisms = {}
  for _, d in ipairs(S.drones) do if d.r == 6 then prisms[#prisms + 1] = d end end
  table.sort(prisms, function(a, b) return G.dronePower(a) > G.dronePower(b) end)
  local drop = {}
  for k = 7, #prisms do drop[prisms[k]] = true end
  for k = #S.drones, 1, -1 do
    local d = S.drones[k]
    if drop[d] then
      for _, m in ipairs(d.mods) do table.insert(S.modules, m) end
      table.remove(S.drones, k)
    end
  end
  note("PRISM drones", #prisms, math.min(#prisms, 6))
  -- PRISMATIC modules: keep the 24 strongest, the rest become MYTHIC
  local pm = {}
  for _, m in ipairs(S.modules) do if m.r == 7 then pm[#pm + 1] = m end end
  for _, d in ipairs(S.drones) do for _, m in ipairs(d.mods) do if m.r == 7 then pm[#pm + 1] = m end end end
  table.sort(pm, function(a, b) return G.modScore(a) > G.modScore(b) end)
  for k = 25, #pm do pm[k].r = 6; pm[k].v = pm[k].v * D.RMUL[6] / D.RMUL[7] end
  note("PRISMATIC modules", #pm, math.min(#pm, 24))
  -- crates waiting on the map: nothing above LEGENDARY
  local cr = 0
  for _, c in ipairs(S.crateList) do if c.r > 5 then c.r = 5; cr = cr + 1 end end
  note("map crates downgraded", cr, 0)
  G.recalc()
  G.save()
  love.filesystem.write("rescale_report.txt", table.concat(rep, "\n"))
  love.event.quit()
end

-- Zone pacing: how long a zone takes with a weak vs. a maxed fleet (no rendering) -> zonesim.txt
function G.zoneSim()
  love.filesystem.setIdentity("tower_harvest_zonesim")
  G.selftest = true
  G.unlocked = function() return true, 0 end -- every system on
  local out = {}
  local fleets = {
    {name = "WEAK   6x ADV LV5, no modules", n = 6, r = 2, lvl = 5, mod = nil},
    {name = "MID   10x ELITE LV15, epic modules", n = 10, r = 3, lvl = 15, mod = 4},
    {name = "MAXED 21x OMEGA LV40, mythic modules", n = 21, r = 5, lvl = 40, mod = 6},
  }
  for _, zone in ipairs({1, 3, 6}) do
    for _, fl in ipairs(fleets) do
      G.init(true)
      G.dailyPending = false
      local S = G.S
      S.zone = zone
      S.pupg.bay = true; S.pupg.fl_bay = 0
      S.autoClaim, S.autoHunt = true, true
      G.newMap()
      for _ = 1, fl.n do
        local d = G.makeDrone(fl.r)
        d.lvl, d.mk = fl.lvl, zone
        if fl.mod then
          for s = 1, D.RARITY[fl.r].slots do
            local m = G.newModule(fl.mod)
            for k, x in ipairs(S.modules) do if x == m then table.remove(S.modules, k) end end
            d.mods[s] = m
          end
        end
        G.addDrone(d)
      end
      G.enemies = {}
      G.recalc()
      local t, spawnAt, killAt, peak = 0, nil, nil, 0
      while t < 3600 do
        t = t + 0.1
        G.warp = G.warp + 0.1 -- missions run on the game clock
        G.update(0.1)
        peak = math.max(peak, #G.enemies)
        if not spawnAt and G.boss() then spawnAt = t end
        if S.bossDown then killAt = t break end
      end
      out[#out + 1] = string.format("zone %d  %-38s mothership %6s   cleared %6s   land %3d%%  kills %4d  crates %3d  peak scavs %d",
        zone, fl.name, spawnAt and string.format("%.1fm", spawnAt / 60) or "never", killAt and string.format("%.1fm", killAt / 60) or "never",
        math.floor(G.landFrac() * 100), S.kills, S.crates + #S.crateList, peak)
    end
  end
  love.filesystem.write("zonesim.txt", table.concat(out, "\n"))
  love.event.quit()
end

-- Pacing probe: simulates a new player for 30 minutes (no rendering) and writes a timeline.
-- --longrun: 12 h without ever rebooting, spamming SMART BUY + tech + claims. Shows whether growth ever stalls.
function G.longRun(reboots, fromSave)
  if fromSave then
    -- start from a copy of the real save (all permanent multipliers), then write only to the probe folder
    G.selftest = true
    G.init(false)
    love.filesystem.setIdentity("tower_harvest_longrun")
  else
    love.filesystem.setIdentity("tower_harvest_longrun")
    G.selftest = true
    G.init(true)
  end
  G.dailyPending = false
  local S = G.S
  if not fromSave then S.stardust = 1e6 end
  local out, t, dt = {}, 0, 1
  local boughtWin, lastLog = 0, 0
  local function sample()
    local units, top = 0, 0
    for i = 1, #D.GENS do units = units + S.gens[i]; if S.gens[i] > 0 then top = i end end
    local mult = {}
    out[#out + 1] = string.format("%5.1fh  cps 1e%-6.1f units %6d  top gen %2d  bought/15m %6d  rank %5d  logs %3d  globalMult 1e%.1f",
      t / 3600, math.log10(math.max(1, G.getCps())), units, top, boughtWin, S.rank, G.achCount, math.log10(math.max(1, G.globalMult)))
    boughtWin = 0
  end
  local hours = fromSave and 3 or (reboots and 24 or 12)
  while t < hours * 3600 do
    t = t + dt
    local u0 = S.unitsBought
    G.smartBuy()
    for _, u in ipairs(G.availableUpgrades()) do if S.stardust >= u.cost then G.buyUpgrade(u, nil, nil, true) end end
    if G.unclaimedLogs() > 0 then G.claimAllLogs() end
    if S.perkPoints > 0 then G.openPerkChoice(); if G.perkChoice then G.perkChoice.t = 5; G.pickPerk(1) end end
    G.perkChoice = nil
    if G.passReady() > 0 then G.claimAllPass() end
    boughtWin = boughtWin + (S.unitsBought - u0)
    G.modal = false
    G.update(dt)
    if reboots and G.satMult() < 0.5 and G.dmGain() >= math.max(1, S.dmTotal * 0.9) then
      G.doReboot(); G.treeSpendAll()
      out[#out + 1] = string.format("%5.1fh  -- REBOOT -> Core Data %s", t / 3600, H.fmt(S.dmTotal))
      local p = G.gmParts or {}
      out[#out + 1] = string.format("        gUp 1e%.1f  cd 1e%.1f  logs 1e%.1f  rank 1e%.1f  zone %.1f  total 1e%.1f  units %d  rank %d  logs %d",
        math.log10(p.gUp or 1), math.log10(p.cd or 1), math.log10(p.logs or 1), math.log10(p.rank or 1), p.zone or 1, math.log10(G.globalMult), (function() local u = 0 for i = 1, #D.GENS do u = u + S.gens[i] end return u end)(), S.rank, G.achCount)
    end
    if t - lastLog >= 900 then lastLog = t; sample() end
  end
  out[#out + 1] = string.format("FINAL lifetime energy 1e%.1f  //  cps 1e%.1f", math.log10(math.max(1, S.totalEarned)), math.log10(math.max(1, G.getCps())))
  love.filesystem.write(fromSave and "longrun_save.txt" or (reboots and "longrun_reboot.txt" or "longrun.txt"), table.concat(out, "\n"))
  love.event.quit()
end

function G.paceProbe()
  love.filesystem.setIdentity("tower_harvest_pace")
  G.selftest = true
  G.init(true)
  G.dailyPending = false
  local S = G.S
  local out, t, dt = {}, 0, 0.1
  local lastRank, lastLogs, nextUnlock = S.rank, 0, 1
  local function log(s) out[#out + 1] = string.format("%5.1f min  %s", t / 60, s) end
  local tapAcc, buyAcc = 0, 0
  while t < 30 * 60 do
    t = t + dt
    G.time = G.time + 0 -- G.update advances time itself
    tapAcc = tapAcc + dt * 5
    while tapAcc >= 1 do tapAcc = tapAcc - 1; G.lastClick = G.time - 0.3; G.tap(G.OX, G.OY) end
    buyAcc = buyAcc + dt
    if buyAcc >= 2 then
      buyAcc = 0
      G.smartBuy()
      for _, u in ipairs(G.availableUpgrades()) do if S.stardust >= u.cost then G.buyUpgrade(u, nil, nil, true) end end
      G.recalc()
      if G.unclaimedLogs() > 0 then G.claimAllLogs() end
      if S.perkPoints > 0 then G.openPerkChoice(); G.perkChoice.t = 5; G.pickPerk(1) end
      G.perkChoice = nil
      for i, d in ipairs(S.directives) do if G.dirProgress(d) >= d.target then G.claimDirective(i) end end
      if G.passReady() > 0 then G.claimAllPass() end
    end
    G.modal = false
    G.update(dt)
    if S.rank ~= lastRank then lastRank = S.rank; log("rank " .. S.rank) end
    if G.achCount ~= lastLogs then lastLogs = G.achCount end
    local a = D.ARCHIVE[nextUnlock]
    if a and G.achCount >= a.n then log("ARCHIVE " .. a.n .. " logs: " .. a.text); nextUnlock = nextUnlock + 1 end
    if math.floor(t) % 60 == 0 and math.floor(t - dt) % 60 ~= 0 then
      log(string.format("energy %s  /s %s  logs %d  rank %d", H.fmt(S.stardust), H.fmt(G.getCps()), G.achCount, S.rank))
    end
  end
  love.filesystem.write("pace.txt", table.concat(out, "\n"))
  love.event.quit()
end

function love.resize(w, h)
  V.resize(w, h)
  buildOverlays()
end

----------------------------------------------------------------------
-- Self-test: drives every system and captures screenshots
----------------------------------------------------------------------
local function shot(name) love.graphics.captureScreenshot("shot_" .. name .. ".png") end
local function runSelftest()
  stFrame = stFrame + 1
  local f, S = stFrame, G.S
  if f == 1 then G.tab = "build" end
  if f == 2 then shot("fix_build_fresh") end
  if f == 3 then G.tab = "core"; G.dailyPending = false; for _ = 1, 30 do G.tap(G.OX, G.OY) end end
  if f == 6 then S.stardust = 1e40; G.gain(1e40); S.hydro, S.parts, S.tokens = 1e6, 1e6, 5 end
  if f >= 7 and f <= 30 then
    for i = 1, #D.GENS do G.buyMode = (f % 4) + 1; G.buyGen(i, 900, 300) end
  end
  if f == 31 then G.checkAch(); G.tab = "core" end
  if f == 36 then shot("core") end
  if f == 41 then
    -- keyword segmentation unit checks
    local function terms(s)
      local out = {}
      for _, sg in ipairs(H.segment(s)) do if sg.term then out[#out + 1] = sg.term.name end end
      return table.concat(out, ",")
    end
    local checks = {
      {"Signal rate +30%", "Signal rate"}, {"+15% rig flow", "Rig flow"}, {"Tap power x2", "Tap power"},
      {"Auto-tap +2/s", "Auto-tap"}, {"Loot luck +10%", "Loot luck"}, {"STRIKE CRIT 5%", "Strike crit"},
      {"+12% DRONE YIELD", "Drone yield"}, {"IL2", ""}, {"STD MK1", ""}, {"Scout Probe output x2", "Output"},
      {"Fab cost -5% (max -60%)", "Fabrication"}, {"+1% output per log entry", "Output,Log entry"},
      {"Smooth and power-friendly", ""}, {"auto-taps", "Auto-tap"},
    }
    local bad = {}
    for _, c in ipairs(checks) do if terms(c[1]) ~= c[2] then bad[#bad + 1] = c[1] .. "=>" .. terms(c[1]) end end
    G.selftestKw = #bad == 0 and "kw-ok" or ("kw-FAIL " .. table.concat(bad, " | "))
  end
  if f == 32 then V.fakeMouse = {985, 170} end
  if f == 34 then shot("kw_hover_core") end
  if f == 35 then V.fakeMouse = {G.OX, G.OY}; H.focusStep(1); H.focusStep(1) end
  if f == 36 then
    shot("reactor_hover_focus")
    -- deterministic: step and resolve against the same (last drawn) frame of click areas
    if not H.focusedHit() then H.focusStep(1) end
    G.selftestFocus = H.focusedHit() and "focus-ok" or ("focus-FAIL hits=" .. #H.hits .. " tab=" .. tostring(G.tab) .. " modal=" .. tostring(G.modal) .. " nap=" .. tostring(G.forceNap))
  end
  if f == 37 then
    V.fakeMouse = nil; H.kbFocus = nil
    G.tab = "build"
    for _ = 1, 4 do G.addDrone(G.makeDrone(3)) end
    G.addDrone(G.makeDrone(1))
  end
  if f == 38 then shot("fix_build"); G.tab = "core" end
  if f == 155 then G.tab = "hangar"; G.travelProbe = 0.45 end
  if f == 156 then shot("travel_core_to_hangar") end
  if f == 157 then G.travelProbe = nil end
  if f == 158 then shot("fix_hangar") end
  if f == 174 then G.tab = "map"; G.spawnEnemy("ELITE"); G.tacSel = {kind = "enemy", uid = G.enemies[#G.enemies].uid} end
  if f == 177 then shot("fix_map") end
  if f == 179 then G.tab = "core" end
  -- rebuilt stations
  if f == 181 then G.tab = "ops" end
  if f == 183 then shot("station_ops") end
  if f == 184 then G.tab = "archive" end
  if f == 186 then shot("station_archive") end
  if f == 187 then G.tab = "rigs"; G.S.rigs[1].tank = G.rigCap(1) end
  if f == 189 then shot("station_rigs") end
  if f == 190 then G.tab = "hangar"; G.openVault() end
  if f == 192 then shot("station_hangar_vault") end
  if f == 193 then G.vaultOpen = false; G.tab = "core" end
  if f == 195 or f == 196 then
    -- staged reactor: sweet-spot heat, surge filling, live chain, nothing drawn over it
    FX.waves, FX.rays, FX.slams = {}, {}, {}
    G.rankBanner, G.bannerQueue = nil, {}
    G.heat, G.overheatT, G.surge, G.combo, G.sweetT = 0.86, 0, 0.62, 40, 6
  end
  if f == 197 then shot("reactor_staged") end
  -- every station once, clean (tab change and screenshot never in the same frame)
  if f == 198 then G.tab = "build"; G.stagedDust, G.stagedMode = G.S.stardust, G.buyMode; G.S.stardust, G.buyMode = 1e45, 1 end
  if f == 200 then shot("station_build") end
  if f == 201 then G.tab = "nova"; G.S.stardust, G.buyMode = G.stagedDust, G.stagedMode end
  if f == 203 then shot("station_reboot") end
  if f == 204 then G.tab = "hangar" end
  if f == 206 then shot("station_hangar") end
  if f == 207 then G.tab = "map" end
  if f == 209 then shot("station_map") end
  if f == 210 then G.tab = "core"; FX.locks = {} end
  if f == 194 then
    -- COLLECT ALL: queue every instant reward, drain the cascade, nothing claimable may remain
    local before = #G.collectables()
    local started = G.collectAll()
    while #G.cascade > 0 do G.cascadeStep() end
    local after = #G.collectables()
    G.selftestCollect = (before == 0 or (started and after == 0)) and ("collect-ok(" .. before .. ")") or ("collect-FAIL " .. before .. "->" .. after)
  end
  -- settings screens
  if f == 40 then G.settingsOpen = true; SettingsUI.section = "display" end
  if f == 44 then shot("settings_display") end
  if f == 46 then SettingsUI.section = "audio" end
  if f == 50 then shot("settings_audio") end
  if f == 52 then SettingsUI.section = "wellbeing" end
  if f == 56 then shot("settings_wellbeing") end
  if f == 58 then S.mythic, S.bosses = 1, 1; SettingsUI.section = "theme" end
  if f == 62 then shot("settings_theme") end
  if f == 64 then SettingsUI.section = "data" end
  if f == 68 then shot("settings_data") end
  if f == 70 then SettingsUI.section = "gameplay" end
  if f == 72 then shot("settings_gameplay"); SettingsUI.section = "glossary" end
  if f == 74 then shot("settings_glossary") end
  -- themes applied to real scenes
  if f == 76 then G.settingsOpen = false; Set.v.theme = "synthwave"; Set.v.numFormat = "sci"; applySettings("theme") end
  if f == 80 then shot("theme_synthwave_core") end
  if f == 82 then Set.v.theme = "amber"; Set.v.numFormat = "short"; applySettings("theme"); G.tab = "build" end
  if f == 86 then shot("theme_amber_build") end
  if f == 88 then Set.v.theme = "bloodmoon"; applySettings("theme"); G.tab = "map"; for _ = 1, 6 do G.spawnEnemy() end end
  if f == 96 then shot("theme_bloodmoon_map") end
  if f == 98 then Set.v.theme = "cbsafe"; applySettings("theme"); G.tab = "ops" end
  if f == 102 then shot("theme_cbsafe_ops") end
  if f == 104 then Set.v.theme = "command"; applySettings("theme"); G.tab = "core" end
  -- boss key
  if f == 106 then Set.v.disguise = "sheet"; G.setBossMode(true) end
  if f == 110 then shot("boss_sheet") end
  if f == 112 then Set.v.disguise = "log"; G.setBossMode(true) end
  if f == 140 then shot("boss_log") end
  if f == 142 then G.setBossMode(false) end
  -- reticle + fps counter + nap overlay
  if f == 144 then Set.v.reticle, Set.v.showFps = true, true; applySettings("reticle") end
  if f == 150 then G.forceNap = true end
  if f == 154 then shot("nap") end
  if f == 156 then G.forceNap = false; Set.v.reticle, Set.v.showFps = false, false; applySettings("reticle") end
  -- data: export/import round trip, reset + restore
  if f == 160 then
    local before = S.totalEarned
    local ok, msg = G.importSave(G.serialize(G.S))
    G.selftestImport = ok and math.abs(G.S.totalEarned - before) < 1e30 and "import-ok" or ("import-FAIL " .. tostring(msg))
    local bad = G.importSave("{function() end}")
    G.selftestImport = G.selftestImport .. (bad and " guard-FAIL" or " guard-ok")
  end
  if f == 164 then G.resetSave() end
  if f == 168 then shot("after_reset") end
  if f == 170 then
    local wiped = G.S.totalEarned < 1e6
    G.restoreBackup()
    G.selftestReset = (wiped and "reset-ok" or "reset-FAIL") .. (G.S.totalEarned > 1e30 and " restore-ok" or " restore-FAIL")
  end
  -- lazy mode claims everything
  if f == 172 then
    Set.v.lazy = true; S.clicks = S.clicks + 5000; G.addXP(5000); G.checkAch()
    G.lazyBefore = {logs = G.unclaimedLogs(), pass = G.S.passClaimed}
  end
  if f == 230 then
    local b = G.lazyBefore
    G.selftestLazy = (b.logs > 0 and G.unclaimedLogs() <= 5 and G.S.passClaimed > b.pass) and "lazy-ok" or
      ("lazy-FAIL logs " .. b.logs .. "->" .. G.unclaimedLogs() .. " pass " .. b.pass .. "->" .. G.S.passClaimed)
    Set.v.lazy = false
  end
  if f == 232 then G.save(); G.load(); G.init(false); G.recalc() end
  -- reticle must not crash (regression: setVisible(nil))
  if f == 501 then Set.v.reticle = true; applySettings("reticle"); G.selftestReticle = "reticle-ok" end
  if f == 502 then Set.v.reticle = false; applySettings("reticle") end
  -- fusion: drag one ADV onto another, autofill, fuse
  if f == 503 then
    G.choiceQueue = {}
    for _ = 1, 4 do G.addDrone(G.makeDrone(2)) end
    G.tab = "hangar"
  end
  if f == 505 then
    local ids = {}
    for _, d in ipairs(S.drones) do if d.r == 2 and G.canCombine(d) then ids[#ids + 1] = d.id end end
    G.fuseBefore = #S.drones
    G.openCombine({ids[1], ids[2]})
  end
  if f == 507 then shot("combine_select") end
  if f == 508 then
    local ex = {}
    for _, id in ipairs(G.combine.slots) do ex[id] = true end
    G.combine.slots[3] = G.combineEligible(G.combine.r, ex)[1].id
    G.combine.phase, G.combine.t = "fusing", 0.5
  end
  if f == 512 then shot("combine_fusing") end
  if f == 554 and G.combine then G.combine.t = 1.29 end
  if f == 558 then shot("combine_done") end
  if f == 560 then
    local r = G.combine and G.combine.result
    G.selftestFuse = (r and r.r == 3 and #S.drones == G.fuseBefore - 2) and ("fuse-ok " .. r.name) or "fuse-FAIL"
    G.combine = nil
    -- every higher tier: ELITE -> PROTO -> OMEGA (PROTO+ adds a second callsign word)
    for tier = 3, 4 do
      local ids = {}
      for _ = 1, 3 do local d = G.makeDrone(tier); G.addDrone(d); ids[#ids + 1] = d.id end
      local ok, nd = pcall(G.combineDrones, ids)
      if not (ok and nd and nd.r == tier + 1 and nd.name:find(" ")) then
        G.selftestFuse = "fuse-FAIL tier" .. tier .. " " .. tostring(nd)
      else
        G.selftestFuse = G.selftestFuse .. " / " .. nd.name
      end
    end
  end
  -- map depth
  if f == 562 then
    G.tab = "map"; G.mapLayer = "threat"; G.mapPanel = "weather"
    G.weather = {def = G.WEATHER[4], t = 100, dur = 150, wind = 1, windSpeed = 55}
    for _ = 1, 5 do G.spawnEnemy() end
    for _, d in ipairs(S.drones) do if G.droneReady(d) then G.tacSel = {kind = "drone", id = d.id} break end end
  end
  if f == 566 then shot("map_threat_storm") end
  if f == 568 then G.mapLayer = "radiation"; G.mapPanel = "tet"; S.tetCharge = 1; V.fakeMouse = {500, 300}
    G.weather = {def = G.WEATHER[3], t = 100, dur = 150, wind = 2, windSpeed = 9} end
  if f == 572 then shot("map_radiation_tet") end
  if f == 574 then local before = S.tetStrikes; G.tetStrike(); G.selftestTet = (S.tetStrikes == before + 1) and "tet-ok" or "tet-FAIL" end
  if f == 578 then shot("map_tet_beam"); V.fakeMouse = nil; G.mapLayer = "loot"; G.mapPanel = "log" end
  if f == 582 then shot("map_loot"); G.mapLayer = "terrain"; G.tab = "core" end
  if f == 233 then
    G.tab = "build"
    for _ = 1, 5 do for _, u in ipairs(G.availableUpgrades()) do G.buyUpgrade(u, nil, nil, true) end G.recalc() end
  end
  if f == 237 then shot("fix_build_empty") end
  -- loot fiesta: x50 with auto-fuse up to OMEGA, one drone locked
  if f == 600 then
    G.tab = "hangar"; S.hydro = 1e12; S.autoFuse = 5; S.fabsTotal = math.max(S.fabsTotal, 10)
    G.lockedId = S.drones[1] and S.drones[1].id
    if S.drones[1] then S.drones[1].lock = true end
  end
  if f == 601 then shot("hangar_fiesta_button") end
  if f == 603 then G.openFiesta(); G.fiestaOpt.n = 50 end
  if f == 608 then shot("fiesta_setup") end
  if f == 610 then G.fiestaBefore = S.fiestas; G.startFiesta() end
  if f == 630 and G.fiesta then G.fiesta.wait = -2.5 end
  if f == 640 then shot("fiesta_pulls") end
  if f == 642 then require("ui.fiesta").escape() end
  if f == 650 then shot("fiesta_cascade") end
  if f == 652 then require("ui.fiesta").escape() end
  if f == 658 then shot("fiesta_done") end
  if f == 660 then
    local fi = G.fiesta
    local ok = fi and S.fiestas == G.fiestaBefore + 1 and #fi.pulls == 57 and #S.drones <= G.bayCap() and #fi.kept > 0
    ok = ok and (not G.lockedId or G.findDrone(G.lockedId) ~= nil)
    G.autoFuseFleet()
    ok = ok and (not G.lockedId or G.findDrone(G.lockedId) ~= nil)
    G.selftestFiesta = ok and ("fiesta-ok fusions=" .. #fi.merges .. " kept=" .. #fi.kept .. " chain=" .. S.bestChain) or "fiesta-FAIL"
    require("ui.fiesta").escape()
  end
  -- heat: 20 instant taps must overheat and lock taps; the sweet spot pays x2.5
  if f == 664 then
    G.tab = "core"; G.heat, G.overheatT = 0, 0
    local e0 = S.stardust
    for _ = 1, 20 do G.tap(G.OX, G.OY) end
    local locked = G.overheatT > 0
    local e1 = S.stardust
    G.tap(G.OX, G.OY)
    local blocked = S.stardust == e1
    G.overheatT, G.heat = 0, 0.85
    local ok = locked and blocked and e1 > e0 and G.inSweetSpot()
    G.selftestHeat = ok and "heat-ok" or ("heat-FAIL " .. tostring(locked) .. tostring(blocked))
  end
  if f == 668 then shot("core_heat_sweet") end
  if f == 670 then G.heat, G.overheatT = 1, 2.5 end
  if f == 674 then shot("core_heat_overheat"); G.overheatT, G.heat = 0, 0 end
  -- mothership + bounty, map indicator
  if f == 676 then
    G.tab = "map"
    local b = G.spawnEnemy("MOTHERSHIP")
    G.bossBefore = S.bounties
    G.selftestBoss = b and b.bounty and "boss-spawned" or "boss-FAIL"
  end
  if f == 680 then shot("map_mothership") end
  if f == 682 then
    local b = G.boss()
    if b then G.damageEnemy(b, b.hp + 1) end
    G.selftestBoss = (S.bounties == G.bossBefore + 1) and "bounty-ok" or "bounty-FAIL"
  end
  -- altar: 10 mythics -> 1 boosted perk point
  if f == 684 then
    G.tab = "hangar"
    for _ = 1, 12 do G.newModule(6) end
    for _ = 1, 20 do G.newModule(love.math.random(1, 5)) end
    S.autoLoadout = false
    G.altarPP = S.perkPoints
  end
  if f == 685 then shot("hangar_vault_button") end
  if f == 686 then G.openVault() end
  if f == 690 then shot("vault") end
  if f == 692 then G.openAltar() end
  if f == 694 then shot("altar") end
  if f == 696 then
    G.altarTransmute(1)
    G.altar = nil; G.openPerkChoice()
    local pc = G.perkChoice
    local ok = S.perkPoints == G.altarPP + 1 and pc and pc.boost and pc.cands[1].grade >= 2
    G.selftestAltar = ok and "altar-ok" or "altar-FAIL"
  end
  if f == 698 then shot("perk_mythic") end
  if f == 700 then
    G.perkChoice.t = 5
    G.pickPerk(1)
    -- picking the boosted perk must lead back to the altar, closing the altar back to the vault
    local back = G.altar ~= nil and G.perkChoice == nil
    G.altar = nil
    local vault = G.vaultOpen
    G.vaultOpen = false
    if not (back and vault) then G.selftestAltar = "altar-return-FAIL" end
  end
  -- autopilot: auto-upgrade spends parts
  if f == 704 then
    S.parts = 1e6; S.autoUpgrade = true; G.apLvl = 0
    for _, d in ipairs(S.drones) do G.apLvl = G.apLvl + d.lvl end
    G.autopilotUpdate(1.1)
    local l = 0
    for _, d in ipairs(S.drones) do l = l + d.lvl end
    G.selftestPilot = l > G.apLvl and "pilot-ok" or "pilot-FAIL"
  end
  -- forge: 3 identical -> IL+1 with the best roll; 10 of a rarity -> next rarity
  if f == 706 then
    S.autoLoadout, S.autoSalvage = false, 0
    S.modules = {}
    for k = 1, 3 do S.modUid = S.modUid + 1; table.insert(S.modules, {uid = S.modUid, t = "PWR", r = 3, ilvl = 2, v = 0.2 + k * 0.01}) end
    for k = 1, 4 do S.modUid = S.modUid + 1; table.insert(S.modules, {uid = S.modUid, t = "YLD", r = 4, ilvl = 1, v = 0.6}) end
    for _ = 1, 12 do G.newModule(1) end
    local key = "PWR|3|2"
    local m = G.forgeIL(key)
    local okIL = m and m.ilvl == 3 and math.abs(m.v - 0.23 / 1.2 * 1.4) < 1e-9
    local before = #G.promoteInputs(1)
    local p = G.promote(1)
    local okP = p and p.r == 2 and #G.promoteInputs(1) == before - 10
    G.selftestForge = (okIL and okP) and "forge-ok" or ("forge-FAIL " .. tostring(okIL) .. tostring(okP))
    for _ = 1, 9 do G.newModule(1) end
    G.vaultOpen = true; G.vaultMode = "forge"; G.tab = "hangar"
  end
  if f == 710 then shot("vault_forge") end
  if f == 712 then G.vaultOpen = false; G.vaultMode = "inventory" end
  -- protocol tree: ranks, prerequisites, claim range
  if f == 713 then
    local T = G.TREE
    S.dm = 1e7
    local out0 = G.globalMult
    local refused = not G.treeCan(T.BYID.eco_out) -- needs Preloaded Fleet first
    G.treeBuy(T.BYID.starter)
    local ok = refused and G.treeBuy(T.BYID.eco_out) and G.tr("eco_out") == 1 and G.globalMult > out0 * 1.2
    for _ = 1, 12 do G.treeBuy(T.BYID.eco_out) end
    ok = ok and G.tr("eco_out") == 10                         -- capped at max rank
    local locked = not G.treeCan(T.BYID.map_range) or G.tr("turret") > 0
    for _, id in ipairs({"carto", "turret", "map_range", "map_scan", "core_tap", "fl_power", "sv_luck", "sg_pump"}) do G.treeBuy(T.BYID[id]) end
    ok = ok and locked and G.tr("map_range") == 1
    -- a sector 2 away from the tower is now claimable-adjacent
    local i2 = G.idx(G.TX + 2, G.TY)
    ok = ok and G.adjClaimed(i2)
    -- a huge bank must be absorbed: SPEND ALL keeps buying, endless OVERDRIVE ranks soak up the rest
    S.dm = 1e40
    G.treeSpendAll()
    local od = G.tr("od_eco") + G.tr("od_core") + G.tr("od_fleet") + G.tr("od_map") + G.tr("od_salv") + G.tr("od_sig")
    ok = ok and S.dm < 5e39 and od > 100 -- a single next rank can cost up to ~1/2 the bank with x3 steps
    G.spendInfo = string.format("spent-left=%s od=%d", H.fmt(S.dm), od)
    G.selftestTree = ok and ("tree-ok " .. G.spendInfo) or string.format("tree-FAIL eco=%d range=%d turret=%d adj=%s locked=%s gm=%.3g/%.3g", G.tr("eco_out"), G.tr("map_range"), G.tr("turret"), tostring(G.adjClaimed(i2)), tostring(locked), G.globalMult, out0)
    G.tab = "nova"; G.treeSel = "od_map"; G.treeView = {x = 0, y = -330, z = 0.9}
  end
  if f == 715 then FX.rays, FX.particles, FX.slams, G.rankBanner, G._banner, G.bannerQueue = {}, {}, {}, nil, nil, {} end
  if f == 716 then shot("reboot_tree") end
  if f == 717 then G.treeView = {x = 0, y = 0, z = 0.17}; G.treeSel = nil end
  if f == 719 then shot("reboot_tree_fit") end
  -- zone shatter transition + jackpot slam
  if f == 721 then G.tab = "map"; S.bossDown = true; G.zoneBefore = S.zone; G.shatterPending = nil; G.shatter = nil end
  if f == 723 then G.requestAdvance() end
  if f == 726 then
    G.selftestShatter = (G.shatter and S.zone == G.zoneBefore + 1) and ("shatter-ok shards=" .. #G.shatter.shards) or
      ("shatter-FAIL zone " .. G.zoneBefore .. "->" .. S.zone .. " " .. tostring(G.shatter))
    if G.shatter then for _ = 1, 8 do Shatter.update(0.05) end end
  end
  if f == 727 then shot("shatter_crack") end
  if f == 728 and G.shatter then for _ = 1, 9 do Shatter.update(0.05) end end
  if f == 729 then shot("shatter_fly") end
  if f == 730 and G.shatter then for _ = 1, 30 do Shatter.update(0.1) end end
  if f == 732 then FX.slams = {}; FX.rays = {}; G.grantCrate(6, 640, 420) end
  if f == 733 then FX.update(0.3) end
  if f == 735 then shot("mythic_slam") end
  if f == 737 then G.tab = "map"; G.tacSel = S.drones[1] and {kind = "drone", id = S.drones[1].id} end
  if f == 739 then shot("map_drone_selected") end
  if f == 740 then
    S.rigs[2].on, S.rigs[2].lvl = false, 1
    local l0 = S.rigs[1].lvl
    S.stardust, S.autoRigUp = 1e40, true
    G.autoBuy()
    G.selftestRigs = (S.rigs[2].on and S.rigs[1].lvl > l0) and "rigs-ok" or "rigs-FAIL"
    S.autoRigUp = false
  end
  -- PRISM: drop-only rarity + full-screen escalation
  if f == 742 then
    local fab6 = false
    for _ = 1, 20000 do if G.rollRarity() >= 6 then fab6 = true end end
    local om = G.makeDrone(5)
    local fuse6 = G.canCombine(om)
    for _ = 1, 12 do G.newModule(D.MYTHIC) end
    local forge7 = G.promote(D.MYTHIC, true) ~= nil
    FX.prism, FX.rays, FX.particles, FX.slams = nil, {}, {}, {}
    G.tab = "map"
    G.grantCrate(7, 640, 360)
    G.selftestPrism = (not fab6 and not fuse6 and not forge7 and FX.prism ~= nil) and "prism-ok" or
      string.format("prism-FAIL fab=%s fuse=%s forge=%s event=%s", tostring(fab6), tostring(fuse6), tostring(forge7), tostring(FX.prism ~= nil))
  end
  if f == 743 then FX.update(0.4) end
  if f == 744 then FX.update(0.5) end
  if f == 746 then shot("prism_event") end
  if f == 748 then
    FX.prism, FX.rays, FX.particles, FX.slams = nil, {}, {}, {}
    G.tab = "hangar"
    local d = G.makeDrone(6); G.addDrone(d); G.hangarSel = d.id
  end
  if f == 751 then shot("prism_drone_card") end
  -- desktop-app themes
  if f == 752 then FX.prism, FX.rays, FX.particles = nil, {}, {}; Set.v.theme = "macos"; applySettings("theme"); G.tab = "core" end
  if f == 754 then shot("theme_macos_core") end
  if f == 755 then Set.v.theme = "win11"; applySettings("theme"); G.tab = "hangar" end
  if f == 757 then shot("theme_win11_hangar") end
  if f == 758 then Set.v.theme = "macdark"; applySettings("theme"); G.tab = "map" end
  if f == 759 then shot("theme_macdark_map") end
  -- social + silly themes
  if f == 760 then G.rankBanner, G._banner, G.bannerQueue = nil, nil, {}; Set.v.theme = "youtube"; applySettings("theme"); G.tab = "core" end
  if f == 762 then shot("theme_youtube_core") end
  if f == 763 then Set.v.theme = "reddit"; applySettings("theme"); G.tab = "hangar" end
  if f == 765 then shot("theme_reddit_hangar") end
  if f == 766 then Set.v.theme = "twitter"; applySettings("theme"); G.tab = "map" end
  if f == 768 then shot("theme_twitter_map") end
  if f == 769 then Set.v.theme = "macos"; applySettings("theme"); G.tab = "hangar"; V.fakeMouse = {520, 690} end
  if f == 772 then shot("theme_macos_dock") end
  if f == 773 then V.fakeMouse = nil; Set.v.theme = "australia"; applySettings("theme"); G.tab = "core" end
  if f == 775 then shot("theme_australia") end
  if f == 776 then Set.v.theme = "dvd"; applySettings("theme") end
  if f == 777 then
    local ok = FX.soundPack == "stupid"
    for _, n in ipairs({"quack", "boing", "squeak", "fart", "honk", "kazoo", "slidewhistle", "bonk", "sadtrombone", "bruh", "dialup"}) do
      if not FX.snd[n] then ok = false end
    end
    FX.play("tap"); FX.play("err"); FX.play("reboot")
    G.selftestSounds = ok and "sounds-ok" or "sounds-FAIL"
  end
  if f == 779 then shot("theme_dvd") end
  if f == 781 then Set.v.theme = "command"; applySettings("theme") end
  -- meme pack
  if f == 782 then
    Set.v.theme = "mlg"; applySettings("theme"); G.tab = "core"
    local played = Memes.play("triple", 0.01, 0)
    Memes.caps = {}; Memes.resetCaption()
    G.meme("overheat")
    G.selftestMemes = (Memes.available() and played and FX.soundPack == "meme" and #Memes.caps == 1) and "memes-ok" or
      string.format("memes-FAIL avail=%s played=%s pack=%s caps=%d", tostring(Memes.available()), tostring(played), tostring(FX.soundPack), #Memes.caps)
    Memes.hitmarker(640, 344)
  end
  if f == 784 then shot("theme_mlg_caption") end
  if f == 785 then Set.v.theme = "doge"; applySettings("theme"); for _ = 1, 4 do Memes.update(1.2) end end
  if f == 787 then shot("theme_doge") end
  if f == 788 then
    Memes.caps = {}; Set.v.theme = "command"; applySettings("theme")
    Memes.resetCaption(); G.meme("overheat")
    if #Memes.caps > 0 or FX.soundPack == "meme" or G.memeOn or G.rankTitle(9999):find("9000") then G.selftestMemes = "memes-LEAK" end
  end
  if f == 790 then
    love.filesystem.write("selftest_result.txt", "OK " .. H.fmt(G.S.totalEarned) .. " logs=" .. G.achCount .. "/" .. #D.ACH ..
      " " .. tostring(G.selftestImport) .. " " .. tostring(G.selftestReset) .. " " .. tostring(G.selftestLazy) ..
      " " .. tostring(G.selftestKw) .. " " .. tostring(G.selftestFocus) .. " " .. tostring(G.selftestCollect) .. " " .. tostring(G.selftestReticle) .. " " .. tostring(G.selftestFuse) ..
      " " .. tostring(G.selftestTet) .. " " .. tostring(G.selftestFiesta) .. " " .. tostring(G.selftestHeat) ..
      " " .. tostring(G.selftestBoss) .. " " .. tostring(G.selftestAltar) .. " " .. tostring(G.selftestPilot) .. " " .. tostring(G.selftestForge) .. " " .. tostring(G.selftestTree) .. " " .. tostring(G.selftestShatter) .. " " .. tostring(G.selftestRigs) .. " " .. tostring(G.selftestPrism) .. " " .. tostring(G.selftestSounds) .. " " .. tostring(G.selftestMemes) ..
      " " .. (G.mapReport():gsub("\n", " | ")) ..
      " rank=" .. G.S.rank .. " pass=" .. G.S.passTier .. "/" .. G.S.passClaimed)
    love.event.quit()
  end
end

----------------------------------------------------------------------
-- Loop
----------------------------------------------------------------------
function love.update(dt)
  frameStart = love.timer.getTime()
  dt = math.min(dt, 0.1)
  -- jackpot slow motion (FX.slam)
  if FX.slow > 0 then FX.slow = FX.slow - dt; dt = dt * 0.25 end
  if selftest then runSelftest() end
  if not G.unlocked(G.tab) then G.tab = "core" end
  G.modal = Ov.isModal()
  G.update(dt)
  FX.update(dt)
  H.updateHolo(love.timer.getTime())
  Th.animate(love.timer.getTime())
  Shatter.update(dt)
  Memes.update(dt)
  applyVolume()
  if G.bossMode then bossT = bossT + dt end

  -- lazy technician: auto-claim the routine stuff
  lazyT = lazyT - dt
  if Set.v.lazy and lazyT <= 0 and not G.settingsOpen then
    lazyT = 1
    if G.dailyPending then G.claimDaily() end
    if G.report then G.collectReport() end
    if #G.choiceQueue == 0 and not G.perkChoice then
      if G.unclaimedLogs() > 0 then G.claimAllLogs() end
      if G.passReady() > 0 then G.claimAllPass() end
      for i, d in ipairs(G.S.directives) do if G.dirProgress(d) >= d.target then G.claimDirective(i) end end
    end
  end

  -- slider drag
  if dragHit then
    if love.mouse.isDown(1) then dragHit.fn(V.mouse()) else dragHit = nil end
  end
  -- hold-to-repeat (hold-to-buy); speed from settings
  if holdHit then
    local mx, my = V.mouse()
    local h = holdHit
    local sp = Set.v.holdSpeed
    if love.mouse.isDown(1) and mx >= h.x and mx <= h.x + h.w and my >= h.y and my <= h.y + h.h and not G.modal then
      holdT = holdT + dt
      if holdT > 0.35 / sp then
        holdRep = holdRep - dt
        if holdRep <= 0 then
          h.fn(mx, my)
          holdRep = math.max(0.015, (0.11 - (holdT - 0.35) * 0.04) / sp)
        end
      end
    else
      holdHit = nil
    end
  end
end

local function drawNap()
  local Fo = H.fonts
  local x0, y0, x1, y1 = V.extents()
  local col = H.col
  col(H.C.bg, 0.9); V.lg.rectangle("fill", x0, y0, x1 - x0, y1 - y0)
  local t = love.timer.getTime()
  for k = 1, 6 do
    local p = (t * 0.15 + k / 6) % 1
    V.lg.setFont(k % 2 == 0 and Fo.xl or Fo.l)
    col(H.C.dim, (1 - p) * 0.6)
    V.lg.print("z", 700 + math.sin(p * 6 + k) * 30 + k * 6, 300 - p * 160)
  end
  V.lg.setFont(Fo.xl); col(H.C.line); V.lg.printf("NAP MODE", 0, 250, 1280, "center")
  V.lg.setFont(Fo.huge); col(H.C.white); V.lg.printf(H.fmt(G.S.stardust), 0, 300, 1280, "center")
  V.lg.setFont(Fo.m); col(H.C.line); V.lg.printf("+" .. H.fmt(G.getCps()) .. " ENERGY / SEC // THE TOWER KEEPS HARVESTING", 0, 366, 1280, "center")
  V.lg.setFont(Fo.s); col(H.C.dim); V.lg.printf("MOVE THE MOUSE TO WAKE UP  //  10 FPS POWER SAVING", 0, 410, 1280, "center")
end

-- system cursor affordance: a hand over anything clickable (including the reactor), "no" over disabled controls
local cursors, cursorNow = {}, nil
local function updateCursor(isNapping)
  if Set.v.reticle or selftest or not love.mouse.isCursorSupported() then return end
  local mx, my = V.mouse()
  local kind = "arrow"
  if not isNapping and not G.bossMode then
    local h = H.hitAt(mx, my)
    if h then kind = h.disabled and "no" or "hand"
    elseif G.tab == "core" and not Ov.isModal() and Reactor.hit(mx, my) then kind = "hand" end
  end
  if kind ~= cursorNow then
    cursorNow = kind
    cursors[kind] = cursors[kind] or love.mouse.getSystemCursor(kind)
    love.mouse.setCursor(cursors[kind])
  end
end

local function drawReticle()
  local mx, my = V.mouse()
  local hot = H.hitAt(mx, my) ~= nil or (G.tab == "core" and Reactor.hit(mx, my))
  local c = hot and H.C.orange or H.C.white
  local lg = V.lg
  H.col(H.C.bg, 0.8)
  lg.setLineWidth(3); lg.circle("line", mx, my, 9, 20); lg.setLineWidth(1)
  H.col(c)
  lg.circle("line", mx, my, 9, 20)
  lg.line(mx - 16, my, mx - 5, my); lg.line(mx + 5, my, mx + 16, my)
  lg.line(mx, my - 16, mx, my - 5); lg.line(mx, my + 5, mx, my + 16)
  lg.rectangle("fill", mx - 1, my - 1, 2, 2)
end

local function finishFrame()
  local cap = frameCap()
  if cap then
    local spent = love.timer.getTime() - frameStart
    if spent < 1 / cap then love.timer.sleep(1 / cap - spent) end
  end
end

function love.draw()
  H.beginFrame()
  local bg = H.C.bg
  if G.bossMode then
    love.graphics.clear(0, 0, 0)
    V.begin()
    Disguise.draw(Set.v.disguise, bossT)
    V.finish()
    finishFrame()
    return
  end
  love.graphics.clear(bg[1], bg[2], bg[3])
  V.begin()
  F.background()
  local shake = 0
  if FX.shake > 0 and not Set.v.reducedMotion then shake = FX.shake * 0.4 * Set.v.shake end
  love.graphics.push()
  if shake > 0 then love.graphics.translate(H.rnd(-shake, shake), H.rnd(-shake, shake)) end
  local scene = SCENES[G.tab] or SCENES.core
  -- station travel: the stations sit side by side along the spine. Switching pans the camera across, the old
  -- station sliding out as the new one slides in; longer trips take a little longer. Only the arriving station
  -- takes input (the departing one is drawn, then its hits are dropped).
  if G.tab ~= screenTab then
    local _, a = F.scene(screenTab or G.tab)
    local _, b = F.scene(G.tab)
    prevTab, screenTab, screenT = screenTab, G.tab, 0
    for i = #FX.locks, 1, -1 do if FX.locks[i].map then table.remove(FX.locks, i) end end -- map readouts stay on the map
    screenDir = (b or 1) >= (a or 1) and 1 or -1
    screenDur = math.min(0.6, 0.36 + 0.04 * math.abs((b or 1) - (a or 1)))
  end
  screenT = math.min(1, screenT + love.timer.getDelta() / screenDur)
  if G.travelProbe then screenT = G.travelProbe end -- self-test: freeze mid-travel for a screenshot
  local travel = prevTab and SCENES[prevTab] and screenT < 1 and not (Set.v.reducedMotion or (selftest and not G.travelProbe) or not H.isHud())
  if travel then
    local e = H.ease.inOutCubic(screenT)
    local W = 1320
    H.offX = math.floor(-screenDir * W * e)
    V.panX = H.offX
    love.graphics.translate(H.offX, 0); SCENES[prevTab].draw(); love.graphics.translate(-H.offX, 0)
    H.clearHits()
    H.offX = math.floor(screenDir * W * (1 - e))
    V.panX = H.offX
    love.graphics.translate(H.offX, 0); scene.draw(); love.graphics.translate(-H.offX, 0)
    H.offX, V.panX = 0, 0
    love.graphics.setScissor()
  else
    scene.draw()
  end
  Shatter.draw()
  love.graphics.pop()
  F.topBar()
  F.dock()
  F.signal()
  local modal = Ov.isModal()
  if not modal then F.toasts() end -- comms bar sits under banners, overlays and tooltips
  F.banner()
  -- particles go over card reveals, but under the settings screen
  if G.settingsOpen then FX.drawParticles(); Ov.draw() else Ov.draw(); FX.drawParticles() end
  FX.drawPrism()
  Memes.draw()
  local isNapping = napping() or G.forceNap
  if isNapping then drawNap() end
  if Set.v.showFps then
    V.lg.setFont(H.fonts.xs); H.col(H.C.white, 0.8)
    V.lg.print(love.timer.getFPS() .. " FPS", 4, 706)
  end
  if not isNapping then H.drawKbFocus() end
  if Set.v.reticle and not isNapping then drawReticle() end
  updateCursor(isNapping)
  V.finish()
  if FX.flash > 0 then
    local c = FX.flashC
    local k = Set.v.reducedMotion and math.min(0.25, Set.v.flash) or Set.v.flash
    love.graphics.setColor(c[1], c[2], c[3], math.min(1, math.min(1, FX.flash) ^ 2 * 0.85 * k))
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
  end
  love.graphics.setColor(1, 1, 1, 1)
  if Set.v.scanlines and not H.style then love.graphics.draw(scanCanvas, 0, 0) end
  if Set.v.vignette and not H.style then love.graphics.draw(vignette, 0, 0, 0, V.winW / vignette:getWidth(), V.winH / vignette:getHeight()) end
  finishFrame()
end

----------------------------------------------------------------------
-- Input
----------------------------------------------------------------------
local function wake()
  local was = napping()
  G.lastInput = love.timer.getTime()
  return was
end

function love.mousemoved() wake(); H.kbFocus = nil end

function love.mousepressed(sx, sy, b)
  if wake() then return end -- the waking click is swallowed
  if G.bossMode or b ~= 1 then return end
  local x, y = V.toVirtual(sx, sy)
  Memes.hitmarker(x, y)
  if Ov.isModal() then
    local h = H.click(x, y)
    if h and h.hold == "drag" then dragHit = h end
    return
  end
  local sg = G.signal
  if sg and (x - sg.x) ^ 2 + (y - sg.y) ^ 2 < 40 * 40 then G.catchSignal() return end
  if G.tab == "hangar" then SCENES.hangar.press(x, y)
  elseif G.tab == "nova" then SCENES.nova.press(x, y) end
  local h = H.click(x, y)
  if h then
    if h.hold == "drag" then dragHit = h
    elseif h.hold then holdHit, holdT, holdRep = h, 0, 0 end
    return
  end
  if G.tab == "core" and Reactor.hit(x, y) then G.tap(x, y) end
end

function love.mousereleased(sx, sy, b)
  holdHit, dragHit = nil, nil
  if b == 1 and G.tab == "hangar" and not Ov.isModal() then SCENES.hangar.release(V.toVirtual(sx, sy)) end
  if b == 1 and G.tab == "nova" and not Ov.isModal() then SCENES.nova.release(V.toVirtual(sx, sy)) end
end

function love.wheelmoved(_, dy)
  wake()
  if G.bossMode then return end
  local x, y = V.mouse()
  local r = H.scrollAt(x, y)
  if not r then return end
  if r.key == "passView" then
    G.passView = math.max(1, (G.passView or 1) - dy)
    return
  end
  if r.key == "treeZoom" then SCENES.nova.zoom(dy, x, y) return end
  G.scroll[r.key] = H.clamp(G.scroll[r.key] - dy * 60, 0, G.maxScroll[r.key])
end

local function cancelChoice()
  local ch = table.remove(G.choiceQueue, 1)
  if not ch then return end
  local p = 0
  for _, d in ipairs(ch.cands) do p = p + math.ceil(D.RARITY[d.r].scrap * 0.5) end
  G.S.parts = G.S.parts + p
  FX.toast("BATCH RECYCLED", "+" .. p .. " parts.", H.C.line)
end

local RESERVED = {escape = true, f11 = true, f12 = true, m = true, b = true, p = true, c = true, ["return"] = true, space = true}

function love.keypressed(k)
  wake()
  if k == "f12" then
    if G.bossMode then G.setBossMode(false) elseif Set.v.bossKey then G.setBossMode(true) end
    return
  end
  if G.bossMode then return end
  if k == "f11" or (k == "return" and love.keyboard.isDown("lalt", "ralt")) then toggleFullscreen() return end
  if k == "f" and Memes.pressF(G.S) then return end
  -- panic button for the cursed themes: F9 always restores the default palette
  if k == "f9" then Set.v.theme = "command"; Set.save(); applySettings("theme"); FX.toast("THEME RESET", "Back to COMMAND. Your eyes thank you.", H.C.line) return end
  -- keyboard focus works on every screen and modal: TAB / SHIFT+TAB to move, ENTER to press
  if k == "tab" then
    H.focusStep(love.keyboard.isDown("lshift", "rshift") and -1 or 1)
    FX.play("tick", 1.5, 0.4)
    return
  end
  if (k == "return" or k == "kpenter") and H.kbFocus and H.activateFocus() then return end
  if k == "escape" and H.kbFocus then H.kbFocus = nil return end
  if G.settingsOpen then
    if k == "escape" then G.settingsOpen = false end
    return
  end
  if Ov.isModal() then
    if k == "return" or k == "space" then
      if G.report then G.collectReport()
      elseif G.dailyPending then G.claimDaily() end
    elseif k == "escape" then
      if G.fiesta then require("ui.fiesta").escape()
      elseif G.altar then require("ui.altar").escape()
      elseif G.combine and G.combine.phase ~= "fusing" then G.combine = nil
      elseif G.perkChoice then G.closePerks()
      elseif #G.choiceQueue > 0 and #G.S.drones >= G.bayCap() then cancelChoice() end
    end
    return
  end
  if k == "space" then G.tap(G.OX + H.rnd(-30, 30), G.OY + H.rnd(-30, 30))
  elseif k == "m" then FX.muted = not FX.muted
  elseif k == "b" then G.buyMode = G.buyMode % #G.BUYMODES + 1
  elseif k == "p" then G.openPerkChoice()
  elseif k == "c" then G.collectAll()
  elseif tonumber(k) and F.SCENES[tonumber(k)] then
    local key = F.SCENES[tonumber(k)][1]
    if G.unlocked(key) then G.tab = key; FX.play("tap", 1.6, 0.4) else FX.play("err") end
  elseif k == "escape" then
    if G.vaultOpen and G.tab == "hangar" then require("ui.vault").escape()
    elseif G.tab ~= "core" then G.tab = "core"
    elseif love.window.getFullscreen() then toggleFullscreen()
    else G.settingsOpen = true end
  elseif Set.v.anyKey and not RESERVED[k] and #k == 1 then
    -- any-key tapping: letters and symbols smash the core
    G.tap(G.OX + H.rnd(-40, 40), G.OY + H.rnd(-40, 40))
  end
end

function love.focus(f)
  focused = f
  if not f and not selftest then G.save() end
end
function love.quit() if not selftest then G.save() end return false end

local defaultErr = love.errorhandler
function love.errorhandler(msg)
  -- always leave a crash log next to the save
  pcall(love.filesystem.write, "crash.txt", os.date() .. "\n" .. tostring(msg) .. "\n" .. debug.traceback())
  if selftest then
    love.filesystem.write("selftest_result.txt", "ERROR " .. tostring(msg) .. "\n" .. debug.traceback())
    return nil
  end
  return defaultErr(msg)
end
