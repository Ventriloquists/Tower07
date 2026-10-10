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
local D = require "game.data"
local Set = require "game.settings"
local Th = require "ui.themes"
local F = require "ui.frame"
local Ov = require "ui.overlays"
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
  H.showTips = v.tooltips
  H.keywords = v.keywords
  G.fastReveal = v.fastReveal
  G.saveInterval = v.autosave
  G.breakInterval = v.grass * 60
  Th.apply(v.theme)
  love.mouse.setVisible(not v.reticle or G.bossMode)
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
  love.mouse.setVisible(on or not Set.v.reticle)
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
  G.selftest = selftest
  if not selftest then Set.load() end
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
end

-- Pacing probe: simulates a new player for 30 minutes (no rendering) and writes a timeline.
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
  if f == 35 then V.fakeMouse = nil end
  if f == 37 then
    G.tab = "build"
    for _ = 1, 4 do G.addDrone(G.makeDrone(3)) end
    G.addDrone(G.makeDrone(1))
  end
  if f == 38 then shot("fix_build"); G.tab = "core" end
  if f == 155 then G.tab = "hangar" end
  if f == 158 then shot("fix_hangar") end
  if f == 174 then G.tab = "map"; G.spawnEnemy("ELITE"); G.tacSel = {kind = "enemy", uid = G.enemies[#G.enemies].uid} end
  if f == 177 then shot("fix_map") end
  if f == 179 then G.tab = "core" end
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
  if f == 104 then Set.v.theme = "oblivion"; applySettings("theme"); G.tab = "core" end
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
  if f == 233 then
    G.tab = "build"
    for _ = 1, 5 do for _, u in ipairs(G.availableUpgrades()) do G.buyUpgrade(u, nil, nil, true) end G.recalc() end
  end
  if f == 237 then shot("fix_build_empty") end
  if f == 240 then
    love.filesystem.write("selftest_result.txt", "OK " .. H.fmt(G.S.totalEarned) .. " logs=" .. G.achCount .. "/" .. #D.ACH ..
      " " .. tostring(G.selftestImport) .. " " .. tostring(G.selftestReset) .. " " .. tostring(G.selftestLazy) ..
      " " .. tostring(G.selftestKw) ..
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
  if selftest then runSelftest() end
  if not G.unlocked(G.tab) then G.tab = "core" end
  G.modal = Ov.isModal()
  G.update(dt)
  FX.update(dt)
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
  scene.draw()
  love.graphics.pop()
  F.topBar()
  F.dock()
  F.signal()
  local modal = Ov.isModal()
  if not modal then F.toasts() end -- comms bar sits under banners, overlays and tooltips
  F.banner()
  -- particles go over card reveals, but under the settings screen
  if G.settingsOpen then FX.drawParticles(); Ov.draw() else Ov.draw(); FX.drawParticles() end
  local isNapping = napping() or G.forceNap
  if isNapping then drawNap() end
  if Set.v.showFps then
    V.lg.setFont(H.fonts.xs); H.col(H.C.white, 0.8)
    V.lg.print(love.timer.getFPS() .. " FPS", 4, 706)
  end
  if Set.v.reticle and not isNapping then drawReticle() end
  V.finish()
  if FX.flash > 0 then
    local c = FX.flashC
    local k = Set.v.reducedMotion and math.min(0.25, Set.v.flash) or Set.v.flash
    love.graphics.setColor(c[1], c[2], c[3], math.min(1, math.min(1, FX.flash) ^ 2 * 0.85 * k))
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
  end
  love.graphics.setColor(1, 1, 1, 1)
  if Set.v.scanlines then love.graphics.draw(scanCanvas, 0, 0) end
  if Set.v.vignette then love.graphics.draw(vignette, 0, 0, 0, V.winW / vignette:getWidth(), V.winH / vignette:getHeight()) end
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

function love.mousemoved() wake() end

function love.mousepressed(sx, sy, b)
  if wake() then return end -- the waking click is swallowed
  if G.bossMode or b ~= 1 then return end
  local x, y = V.toVirtual(sx, sy)
  if Ov.isModal() then
    local h = H.click(x, y)
    if h and h.hold == "drag" then dragHit = h end
    return
  end
  local sg = G.signal
  if sg and (x - sg.x) ^ 2 + (y - sg.y) ^ 2 < 40 * 40 then G.catchSignal() return end
  local h = H.click(x, y)
  if h then
    if h.hold == "drag" then dragHit = h
    elseif h.hold then holdHit, holdT, holdRep = h, 0, 0 end
    return
  end
  if G.tab == "core" and Reactor.hit(x, y) then G.tap(x, y) end
end

function love.mousereleased() holdHit, dragHit = nil, nil end

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

local RESERVED = {escape = true, f11 = true, f12 = true, m = true, b = true, p = true, ["return"] = true, space = true}

function love.keypressed(k)
  wake()
  if k == "f12" then
    if G.bossMode then G.setBossMode(false) elseif Set.v.bossKey then G.setBossMode(true) end
    return
  end
  if G.bossMode then return end
  if k == "f11" or (k == "return" and love.keyboard.isDown("lalt", "ralt")) then toggleFullscreen() return end
  if G.settingsOpen then
    if k == "escape" then G.settingsOpen = false end
    return
  end
  if Ov.isModal() then
    if k == "return" or k == "space" then
      if G.report then G.collectReport()
      elseif G.dailyPending then G.claimDaily() end
    elseif k == "escape" then
      if G.perkChoice then G.closePerks()
      elseif #G.choiceQueue > 0 and #G.S.drones >= G.bayCap() then cancelChoice() end
    end
    return
  end
  if k == "space" then G.tap(G.OX + H.rnd(-30, 30), G.OY + H.rnd(-30, 30))
  elseif k == "m" then FX.muted = not FX.muted
  elseif k == "b" then G.buyMode = G.buyMode % #G.BUYMODES + 1
  elseif k == "p" then G.openPerkChoice()
  elseif tonumber(k) and F.SCENES[tonumber(k)] then
    local key = F.SCENES[tonumber(k)][1]
    if G.unlocked(key) then G.tab = key; FX.play("tap", 1.6, 0.4) else FX.play("err") end
  elseif k == "escape" then
    if G.tab ~= "core" then G.tab = "core"
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
  if selftest then
    love.filesystem.write("selftest_result.txt", "ERROR " .. tostring(msg) .. "\n" .. debug.traceback())
    return nil
  end
  return defaultErr(msg)
end
