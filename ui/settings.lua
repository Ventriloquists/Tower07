-- Settings screen: display, audio, gameplay, comfort, wellbeing, themes, data.
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local Set = require "game.settings"
local Th = require "ui.themes"
local I = require "ui.icons"
local lg = V.lg
local C, col, clamp = H.C, H.col, H.clamp
local Su = {}

Su.section = "display"
Su.onChange = function() end
Su.msg = nil
local armed = {}          -- two-click confirmations: key -> seconds left
local resetT, resetArmed = 0, false

local PX, PY, PW, PH = 110, 58, 1060, 594
local NX, NW = PX + 12, 180
local CX, CW = PX + 212, PW - 224
local TOP, BOT = PY + 52, PY + PH - 12

local SECTIONS = {
  {"display", "DISPLAY", "full"},
  {"audio", "AUDIO", "audio"},
  {"gameplay", "GAMEPLAY", "core"},
  {"comfort", "COMFORT", "perk"},
  {"wellbeing", "WELLBEING", "event"},
  {"theme", "THEMES", "cd"},
  {"glossary", "GLOSSARY", "ops"},
  {"data", "DATA", "archive"},
}
Su.glossCat = "ALL"

local function say(text, c) Su.msg = {text = text, c = c or C.line, t = 4} end

local function set(key, value)
  Set.v[key] = value
  Set.save()
  Su.onChange(key)
  FX.play("tick", 1.3, 0.6)
end

----------------------------------------------------------------------
-- controls (all right-aligned to xr)
----------------------------------------------------------------------
local function toggle(xr, y, on, fn, clip)
  local w, h = 66, 26
  local x = xr - w
  local hov = H.mouseIn(x, y, w, h, clip)
  col(on and C.line or C.faint, on and 0.3 or 0.45); lg.rectangle("fill", x, y, w, h)
  H.brackets(x, y, w, h, 5, on and C.white or C.dim, hov and 1 or 0.8)
  local kx = on and (x + w - 26) or (x + 4)
  col(on and C.white or C.dim); lg.rectangle("fill", kx, y + 4, 22, h - 8)
  lg.setFont(H.fonts.xs); col(on and C.white or C.dim)
  lg.printf(on and "ON" or "OFF", on and x + 4 or x + 28, y + 7, 34, "center")
  H.addHit(x, y, w, h, fn, clip)
end

local function seg(xr, y, opts, cur, fn, clip, dim)
  local f = H.fonts.xs
  local ws, total = {}, 0
  for k, o in ipairs(opts) do ws[k] = f:getWidth(o[2]) + 24; total = total + ws[k] end
  local x = xr - total - (#opts - 1) * 4
  for k, o in ipairs(opts) do
    local on = o[1] == cur
    local hov = H.mouseIn(x, y, ws[k], 26, clip)
    col(C.line, on and 0.3 or (hov and 0.12 or 0.04)); lg.rectangle("fill", x, y, ws[k], 26)
    H.brackets(x, y, ws[k], 26, 4, on and C.white or C.dim, dim and 0.4 or 1)
    lg.setFont(f); col(on and C.white or C.dim, dim and 0.5 or 1)
    lg.printf(o[2], x, y + 7, ws[k], "center")
    local v = o[1]
    H.addHit(x, y, ws[k], 26, function() fn(v) end, clip)
    x = x + ws[k] + 4
  end
end

local function slider(xr, y, w, value, lo, hi, label, fn, clip)
  local x = xr - w
  local f = clamp((value - lo) / (hi - lo), 0, 1)
  local hov = H.mouseIn(x - 6, y, w + 12, 26, clip)
  col(C.faint, 0.7); lg.rectangle("fill", x, y + 11, w, 4)
  col(C.line); lg.rectangle("fill", x, y + 11, w * f, 4)
  for k = 0, 10 do col(C.dim, 0.5); lg.rectangle("fill", x + w * k / 10 - 0.5, y + 18, 1, k % 5 == 0 and 6 or 3) end
  col(hov and C.white or C.line); lg.rectangle("fill", x + w * f - 5, y + 2, 10, 22)
  lg.setFont(H.fonts.xs); col(C.white)
  lg.printf(label, x - 150, y + 7, 140, "right")
  H.addHit(x - 6, y, w + 12, 26, function(mx)
    local nv = lo + clamp((mx - x) / w, 0, 1) * (hi - lo)
    fn(math.floor(nv * 100 + 0.5) / 100)
  end, clip, "drag")
end

local function pct(v) return v <= 0.001 and "MUTED" or (math.floor(v * 100 + 0.5) .. "%") end

----------------------------------------------------------------------
-- section definitions: rows of {label, desc, control(xr, y, clip)}
----------------------------------------------------------------------
local v = Set.v
local function rows(section)
  v = Set.v
  if section == "display" then
    return {
      {"FULLSCREEN", "Borderless fullscreen. F11 or Alt+Enter work anywhere.", function(xr, y, cl)
        toggle(xr, y, love.window.getFullscreen(), function() G.toggleFullscreen(); FX.play("tick") end, cl) end},
      {"VSYNC", "Sync to the monitor refresh rate. Smooth and power-friendly.", function(xr, y, cl)
        toggle(xr, y, v.vsync, function() set("vsync", not v.vsync) end, cl) end},
      {"FRAME CAP", "Maximum frames per second. Only used when VSync is off.", function(xr, y, cl)
        seg(xr, y, {{30, "30"}, {60, "60"}, {120, "120"}, {144, "144"}, {0, "UNLIMITED"}}, v.fpsCap,
          function(x) set("fpsCap", x) end, cl, v.vsync) end},
      {"FPS COUNTER", "Show frames per second in the corner.", function(xr, y, cl)
        toggle(xr, y, v.showFps, function() set("showFps", not v.showFps) end, cl) end},
      {"SCANLINES", "CRT scanline overlay.", function(xr, y, cl)
        toggle(xr, y, v.scanlines, function() set("scanlines", not v.scanlines) end, cl) end},
      {"VIGNETTE", "Darkened screen edges.", function(xr, y, cl)
        toggle(xr, y, v.vignette, function() set("vignette", not v.vignette) end, cl) end},
      {"TARGETING CURSOR", "Replace the mouse pointer with a tower reticle.", function(xr, y, cl)
        toggle(xr, y, v.reticle, function() set("reticle", not v.reticle) end, cl) end},
      {"NUMBER FORMAT", "1.23Qa  //  1.23e15  //  engineering (exponents in steps of 3).", function(xr, y, cl)
        seg(xr, y, {{"short", "SHORT"}, {"sci", "SCIENTIFIC"}, {"eng", "ENGINEERING"}}, v.numFormat,
          function(x) set("numFormat", x) end, cl) end},
    }
  elseif section == "audio" then
    local function vol(key, label, desc)
      return {label, desc, function(xr, y, cl)
        slider(xr, y, 260, v[key], 0, 1, pct(v[key]), function(x) v[key] = x; Set.save(); Su.onChange(key) end, cl) end}
    end
    return {
      vol("master", "MASTER VOLUME", "Everything. [M] toggles mute anywhere."),
      vol("vUi", "TAPS & CLICKS", "Core taps, buttons, purchases, strikes."),
      vol("vReward", "REWARDS & LOOT", "Crates, logs, rank-ups, fanfares."),
      vol("vAlert", "ALERTS & EVENTS", "Signals, raids, full tanks, reboots."),
      vol("ambient", "REACTOR HUM", "Ambient drone of a very large machine."),
      {"MUTE IN BACKGROUND", "Silence the game while the window is not focused.", function(xr, y, cl)
        toggle(xr, y, v.muteUnfocused, function() set("muteUnfocused", not v.muteUnfocused) end, cl) end},
    }
  elseif section == "gameplay" then
    return {
      {"CONFIRM REBOOT", "Ask twice before wiping a cycle.", function(xr, y, cl)
        toggle(xr, y, v.confirmReboot, function() set("confirmReboot", not v.confirmReboot) end, cl) end},
      {"FAST REVEALS", "Skip the suspense on fabrication and perk card flips. (You monster.)", function(xr, y, cl)
        toggle(xr, y, v.fastReveal, function() set("fastReveal", not v.fastReveal) end, cl) end},
      {"HOLD-TO-BUY SPEED", "How fast purchases repeat while you hold the mouse button.", function(xr, y, cl)
        seg(xr, y, {{1, "DECAF"}, {2, "ESPRESSO"}, {4, "TRIPLE SHOT"}}, v.holdSpeed, function(x) set("holdSpeed", x) end, cl) end},
      {"ANY-KEY TAPPING", "Every letter key taps the core. Keyboard smashing is now a strategy.", function(xr, y, cl)
        toggle(xr, y, v.anyKey, function() set("anyKey", not v.anyKey) end, cl) end},
      {"COMMS TICKER", "Hide routine messages (log entries, secured sectors) from the ticker.", function(xr, y, cl)
        seg(xr, y, {{"all", "EVERYTHING"}, {"important", "IMPORTANT ONLY"}}, v.ticker, function(x) set("ticker", x) end, cl) end},
      {"AUTOSAVE", "How often progress is written to disk.", function(xr, y, cl)
        seg(xr, y, {{10, "10S"}, {15, "15S"}, {30, "30S"}, {60, "60S"}}, v.autosave, function(x) set("autosave", x) end, cl) end},
      {"LAZY TECHNICIAN", "Auto-claims daily supply, offline reports, logs, directives and Signal Track tiers.", function(xr, y, cl)
        toggle(xr, y, v.lazy, function() set("lazy", not v.lazy) end, cl) end},
    }
  elseif section == "comfort" then
    local function shakeLbl(x)
      if x <= 0.01 then return "OFF" elseif x < 0.5 then return "POLITE" elseif x < 1.05 then return "NORMAL"
      elseif x < 1.3 then return "SPICY" end
      return "EARTHQUAKE"
    end
    local function flashLbl(x)
      if x <= 0.01 then return "OFF" elseif x < 0.5 then return "GENTLE" elseif x < 1.05 then return "NORMAL" end
      return "RETINA BURN"
    end
    return {
      {"SCREEN SHAKE", "How hard the screen shakes on crits, jackpots and explosions.", function(xr, y, cl)
        slider(xr, y, 260, v.shake, 0, 1.5, shakeLbl(v.shake), function(x) v.shake = x; Set.save(); Su.onChange("shake") end, cl) end},
      {"FLASH INTENSITY", "Full-screen color flashes. Lower or disable for photosensitivity.", function(xr, y, cl)
        slider(xr, y, 260, v.flash, 0, 1.5, flashLbl(v.flash), function(x) v.flash = x; Set.save(); Su.onChange("flash") end, cl) end},
      {"CONFETTI LEVEL", "Particle amount. PARTY may summon your GPU fan.", function(xr, y, cl)
        seg(xr, y, {{0.35, "MINIMAL"}, {1, "NORMAL"}, {2, "PARTY"}}, v.confetti, function(x) set("confetti", x) end, cl) end},
      {"REDUCED MOTION", "No light rays, shake, UI animation or background drift. Softer flashes.", function(xr, y, cl)
        toggle(xr, y, v.reducedMotion, function() set("reducedMotion", not v.reducedMotion) end, cl) end},
      {"TOOLTIPS", "Show info boxes when hovering over things.", function(xr, y, cl)
        toggle(xr, y, v.tooltips, function() set("tooltips", not v.tooltips) end, cl) end},
      {"KEYWORD HIGHLIGHTS", "Underline game terms like rig flow or loot luck. Hover them for an explanation.", function(xr, y, cl)
        toggle(xr, y, v.keywords, function() set("keywords", not v.keywords) end, cl) end},
    }
  elseif section == "wellbeing" then
    return {
      {"TOUCH-GRASS REMINDER", "Every so often: hydrate, stretch, look 20 m away. Offline earnings keep running.", function(xr, y, cl)
        seg(xr, y, {{0, "OFF"}, {20, "20 MIN"}, {45, "45 MIN"}, {90, "90 MIN"}}, v.grass, function(x) set("grass", x) end, cl) end},
      {"NAP MODE", "When you are AFK: dim the screen and drop to 10 FPS. The tower keeps harvesting.", function(xr, y, cl)
        seg(xr, y, {{0, "OFF"}, {2, "2 MIN"}, {5, "5 MIN"}, {15, "15 MIN"}}, v.nap, function(x) set("nap", x) end, cl) end},
      {"ECO MODE", "15 FPS while the window is in the background. Your laptop fan says thanks.", function(xr, y, cl)
        toggle(xr, y, v.eco, function() set("eco", not v.eco) end, cl) end},
      {"BOSS KEY [F12]", "Instantly disguise the game and mute it. Press F12 again to come back.", function(xr, y, cl)
        toggle(xr, y, v.bossKey, function() set("bossKey", not v.bossKey) end, cl) end},
      {"DISGUISE", "What your boss sees.", function(xr, y, cl)
        seg(xr, y, {{"sheet", "SPREADSHEET"}, {"log", "BUILD LOG"}, {"black", "BLACKOUT"}}, v.disguise,
          function(x) set("disguise", x) end, cl) end},
      {"TEST THE DISGUISE", "Rehearse your escape. Press F12 to return.", function(xr, y, cl)
        H.button(xr - 180, y, 180, 26, "ENGAGE DISGUISE", true, function()
          G.setBossMode(true)
          G.settingsOpen = false
        end, C.line, H.fonts.xs, cl) end},
    }
  elseif section == "data" then
    local function confirmBtn(xr, y, key, label, confirmLabel, enabled, fn, c, cl)
      local on = armed[key] and armed[key] > 0
      H.button(xr - 200, y, 200, 26, on and confirmLabel or label, enabled, function()
        if on then armed[key] = nil; fn() else armed[key] = 3; FX.play("signal", 0.7, 0.5) end
      end, c or C.line, H.fonts.xs, cl, on)
    end
    return {
      {"SAVE NOW", "Write progress to disk immediately.", function(xr, y, cl)
        H.button(xr - 200, y, 200, 26, "SAVE", true, function() G.save(); say("Saved.", C.line); FX.play("buy") end, C.line, H.fonts.xs, cl) end},
      {"EXPORT SAVE", "Copy your save to the clipboard as text. Paste it somewhere safe.", function(xr, y, cl)
        H.button(xr - 200, y, 200, 26, "COPY TO CLIPBOARD", true, function()
          G.save()
          local text = G.serialize(G.S)
          love.system.setClipboardText(text)
          say("Save copied to clipboard (" .. math.floor(#text / 1024 + 0.5) .. " KB).", C.line)
          FX.play("crate")
        end, C.line, H.fonts.xs, cl) end},
      {"IMPORT SAVE", "Load a save from the clipboard. Your current save becomes the backup.", function(xr, y, cl)
        confirmBtn(xr, y, "import", "PASTE FROM CLIPBOARD", "CLICK AGAIN TO IMPORT", true, function()
          local ok, msg = G.importSave(love.system.getClipboardText())
          say(msg, ok and C.line or C.red)
          FX.play(ok and "unlock" or "err")
          if ok then Su.onChange("import") end
        end, C.orange, cl) end},
      {"RESTORE BACKUP", "Undo the last reset or import (swaps the current save with the backup).", function(xr, y, cl)
        confirmBtn(xr, y, "restore", "RESTORE BACKUP", "CLICK AGAIN TO SWAP", G.hasBackup(), function()
          if G.restoreBackup() then say("Backup restored. Restore again to swap back.", C.line); FX.play("unlock")
          else say("No backup found.", C.red) end
        end, C.orange, cl) end},
      {"OPEN SAVE FOLDER", "Show where your save files live.", function(xr, y, cl)
        H.button(xr - 200, y, 200, 26, "OPEN FOLDER", true, function()
          love.system.openURL("file:///" .. love.filesystem.getSaveDirectory():gsub("\\", "/"))
        end, C.line, H.fonts.xs, cl) end},
      {"RESET SETTINGS", "Restore every option on this screen to its default.", function(xr, y, cl)
        confirmBtn(xr, y, "rsettings", "RESET SETTINGS", "CLICK AGAIN TO RESET", true, function()
          Set.reset(); Su.onChange("all"); say("Settings restored to defaults.", C.line)
        end, C.orange, cl) end},
    }
  end
  return {}
end

----------------------------------------------------------------------
-- themes grid
----------------------------------------------------------------------
local function themes(clip)
  local S = G.S
  local Fo = H.fonts
  local cols, gap = 3, 12
  local cw, ch = (CW - (cols - 1) * gap) / cols, 132
  local y0 = TOP - G.scroll.settings
  for k, t in ipairs(Th.LIST) do
    local c, r = (k - 1) % cols, math.floor((k - 1) / cols)
    local x, y = CX + c * (cw + gap), y0 + r * (ch + gap)
    local unlocked = Th.isUnlocked(t, S)
    local active = Set.v.theme == t.id
    local hov = H.mouseIn(x, y, cw, ch, clip)
    local tc = t.c
    -- preview drawn in the theme's own colors
    lg.setColor(tc.bg[1], tc.bg[2], tc.bg[3]); lg.rectangle("fill", x, y, cw, ch)
    lg.setColor(tc.panel[1], tc.panel[2], tc.panel[3]); lg.rectangle("fill", x + 10, y + 34, cw - 20, 52)
    lg.setColor(tc.faint[1], tc.faint[2], tc.faint[3])
    for gx = x + 10, x + cw - 10, 16 do lg.line(gx, y + 34, gx, y + 86) end
    lg.setColor(tc.line[1], tc.line[2], tc.line[3]); lg.rectangle("fill", x + 18, y + 64, (cw - 36) * 0.62, 5)
    lg.setColor(tc.orange[1], tc.orange[2], tc.orange[3]); lg.rectangle("fill", x + cw - 70, y + 42, 52, 18)
    local sw = {"line", "white", "orange", "red", "gold", "dim"}
    for i, key in ipairs(sw) do
      local cc = tc[key]
      lg.setColor(cc[1], cc[2], cc[3]); lg.rectangle("fill", x + 18 + (i - 1) * 16, y + 44, 12, 12)
    end
    lg.setFont(Fo.s); lg.setColor(tc.white[1], tc.white[2], tc.white[3]); lg.print(t.name, x + 12, y + 10)
    lg.setFont(Fo.xs); lg.setColor(tc.dim[1], tc.dim[2], tc.dim[3]); lg.print(H.fit(Fo.xs, t.desc, cw - 24), x + 12, y + 96)
    -- tag: what kind of theme this is
    local tag, tcol = nil, C.line
    if t.cursed then tag, tcol = "CURSED", C.red
    elseif t.screen then tag, tcol = "WARP", C.orange
    elseif t.anim then tag, tcol = "ANIMATED", C.holo end
    if tag then
      local tw = Fo.xs:getWidth(tag) + 10
      col(tcol); lg.rectangle("fill", x + 12, y + ch - 22, tw, 14)
      lg.setFont(Fo.xs); col(C.bg); lg.printf(tag, x + 12, y + ch - 21, tw, "center")
    end
    H.brackets(x, y, cw, ch, 8, active and C.white or (hov and C.line or C.dim), active and 1 or 0.7)
    if active then
      col(C.white); lg.rectangle("fill", x + cw - 62, y + 8, 54, 16)
      lg.setFont(Fo.xs); col(C.bg); lg.printf("ACTIVE", x + cw - 62, y + 10, 54, "center")
    end
    if not unlocked then
      col(C.bg, 0.72); lg.rectangle("fill", x, y, cw, ch)
      H.hatch(x, y, cw, ch, C.red, 0.12, 8)
      I.draw("lock", x + cw / 2, y + 52, 10, C.red)
      lg.setFont(Fo.xs); col(C.red); lg.printf("LOCKED // " .. t.lock:upper(), x, y + 76, cw, "center")
    end
    H.addHit(x, y, cw, ch, function()
      if not unlocked then FX.play("err"); say("Locked: " .. t.lock .. ".", C.red) return end
      set("theme", t.id)
      if t.cursed then
        say("Theme: " .. t.name .. "  //  press F9 anytime to escape", C.red)
        FX.toast("CURSED THEME", "Press F9 at any time to get back to OBLIVION.", C.red)
      else
        say("Theme: " .. t.name, C.line)
      end
    end, clip)
  end
  local rowsN = math.ceil(#Th.LIST / cols)
  G.maxScroll.settings = math.max(0, rowsN * (ch + gap) - (BOT - TOP))
end

----------------------------------------------------------------------
-- glossary: every keyword, grouped by category
----------------------------------------------------------------------
local function glossary(clip)
  local Fo = H.fonts
  -- category filter chips (fixed above the scrolling list)
  local cats, seen = {"ALL"}, {}
  for _, t in ipairs(H.glossary) do
    if not seen[t.cat] then seen[t.cat] = true; cats[#cats + 1] = t.cat end
  end
  local cx = CX
  for _, c in ipairs(cats) do
    local w = Fo.xs:getWidth(c) + 20
    local on = Su.glossCat == c
    local hov = H.mouseIn(cx, TOP, w, 24)
    col(C.line, on and 0.3 or (hov and 0.12 or 0.04)); lg.rectangle("fill", cx, TOP, w, 24)
    H.brackets(cx, TOP, w, 24, 4, on and C.white or C.dim)
    lg.setFont(Fo.xs); col(on and C.white or C.dim); lg.printf(c, cx, TOP + 6, w, "center")
    H.addHit(cx, TOP, w, 24, function() Su.glossCat = c; G.scroll.settings = 0; FX.play("tick", 1.2) end)
    cx = cx + w + 4
  end
  local top = TOP + 34
  local gclip = {top, BOT}
  lg.setScissor(CX - 4, top, CW + 8, BOT - top)
  local y = top - G.scroll.settings
  local nameW = 170
  local lastCat
  for _, t in ipairs(H.glossary) do
    if Su.glossCat == "ALL" or Su.glossCat == t.cat then
      if Su.glossCat == "ALL" and t.cat ~= lastCat then
        lastCat = t.cat
        if y + 24 >= top and y <= BOT then
          lg.setFont(Fo.s); col(C.orange); lg.print(t.cat, CX, y + 4)
          col(C.orange, 0.3); lg.line(CX + Fo.s:getWidth(t.cat) + 10, y + 12, CX + CW, y + 12)
        end
        y = y + 26
      end
      local dh = H.richHeight(t.desc, CW - nameW - 10, Fo.xs)
      local h = math.max(36, dh + 22)
      if y + h >= top and y <= BOT then
        lg.setFont(Fo.s); col(C.white); lg.print(t.name:upper(), CX, y + 2)
        local others = {}
        for _, a in ipairs(t.alias) do if a:lower() ~= t.name:lower() then others[#others + 1] = a end end
        if #others > 0 then
          lg.setFont(Fo.xs); col(C.faint); lg.print(H.fit(Fo.xs, table.concat(others, ", "), nameW - 10), CX, y + 20)
        end
        H.richf(t.desc, CX + nameW, y + 3, CW - nameW - 10, "left", C.line, 1, Fo.xs)
        col(C.line, 0.08); lg.line(CX, y + h - 4, CX + CW, y + h - 4)
      end
      y = y + h
    end
  end
  lg.setScissor()
  G.maxScroll.settings = math.max(0, y + G.scroll.settings - BOT)
  H.scrollRegion(CX, top, CW, BOT - top, "settings")
end

----------------------------------------------------------------------
-- the big red button: hold for 3 seconds
----------------------------------------------------------------------
local function resetSaveRow(y, clip)
  local Fo = H.fonts
  local x, w, h = CX, CW, 64
  col(C.red, 0.06); lg.rectangle("fill", x, y, w, h + 30)
  H.hatch(x, y, w, h + 30, C.red, 0.08, 9)
  H.brackets(x, y, w, h + 30, 8, C.red, 0.8)
  lg.setFont(Fo.s); col(C.red); lg.print("RESET SAVE", x + 14, y + 10)
  H.label("Wipe ALL progress and start a fresh shift. Settings are kept. A backup is saved (see RESTORE BACKUP).", x + 14, y + 32, C.dim)
  local bx, by, bw, bh = x + w - 300, y + 50, 286, 34
  local holding = resetArmed and love.mouse.isDown(1) and H.mouseIn(bx, by, bw, bh, clip)
  local dt = love.timer.getDelta()
  if holding then resetT = resetT + dt else resetT = math.max(0, resetT - dt * 3); if not love.mouse.isDown(1) then resetArmed = false end end
  col(C.red, 0.15); lg.rectangle("fill", bx, by, bw, bh)
  col(C.red, 0.85); lg.rectangle("fill", bx, by, bw * clamp(resetT / 3, 0, 1), bh)
  H.brackets(bx, by, bw, bh, 6, C.red)
  lg.setFont(Fo.s); col(resetT > 0 and C.white or C.red)
  lg.printf(resetT > 0 and ("KEEP HOLDING... " .. string.format("%.1f", math.max(0, 3 - resetT))) or "HOLD 3 SECONDS TO WIPE", bx, by + 9, bw, "center")
  H.addHit(bx, by, bw, bh, function() resetArmed = true end, clip)
  if resetT >= 3 then
    resetT, resetArmed = 0, false
    G.resetSave()
    G.settingsOpen = false
    FX.flashTo(C.red, 0.8)
    FX.play("reboot")
    G.rankBanner = {t = 0, title = "SAVE WIPED // A NEW SHIFT BEGINS", text = "Welcome, trainee. Your old save is kept as a backup in SETTINGS > DATA.", c = C.red}
  end
end

----------------------------------------------------------------------
function Su.draw()
  local Fo = H.fonts
  H.clearHits()
  local x0, y0, x1, y1 = V.extents()
  col(C.bg, 0.88); lg.rectangle("fill", x0, y0, x1 - x0, y1 - y0)
  for k, a in pairs(armed) do armed[k] = a - love.timer.getDelta(); if armed[k] <= 0 then armed[k] = nil end end
  -- frame
  col(C.panel, 0.98); lg.rectangle("fill", PX, PY, PW, PH)
  H.hatch(PX, PY, PW, 40, C.line, 0.08, 7)
  H.brackets(PX, PY, PW, PH, 16, C.line)
  I.draw("parts", PX + 24, PY + 20, 10, C.white)
  lg.setFont(Fo.l); col(C.white); lg.print("SETTINGS", PX + 44, PY + 7)
  H.label("CHANGES SAVE AUTOMATICALLY  //  ESC TO CLOSE", PX + 170, PY + 16, C.dim)
  H.button(PX + PW - 48, PY + 6, 38, 28, "X", true, function() G.settingsOpen = false; FX.play("tick") end, C.line, Fo.s)
  -- nav
  for k, s in ipairs(SECTIONS) do
    local y = PY + 52 + (k - 1) * 54
    local on = Su.section == s[1]
    local hov = H.mouseIn(NX, y, NW, 48)
    col(C.line, on and 0.18 or (hov and 0.08 or 0.02)); lg.rectangle("fill", NX, y, NW, 48)
    if on then col(C.white); lg.rectangle("fill", NX, y, 3, 48) end
    H.brackets(NX, y, NW, 48, 5, on and C.white or C.dim, on and 1 or 0.6)
    I.draw(s[3], NX + 26, y + 24, 9, on and C.white or C.line)
    lg.setFont(Fo.s); col(on and C.white or C.line); lg.print(s[2], NX + 50, y + 15)
    H.addHit(NX, y, NW, 48, function()
      if Su.section ~= s[1] then Su.section = s[1]; G.scroll.settings = 0; FX.play("tick", 1.2) end
    end)
  end
  lg.setFont(Fo.xs); col(C.faint); lg.print("TOWER 07 // HARVEST CONTROL", NX, PY + PH - 44)
  lg.print("SAVE: " .. love.filesystem.getIdentity(), NX, PY + PH - 28)
  col(C.line, 0.25); lg.line(CX - 12, TOP, CX - 12, BOT)

  -- content
  local clip = {TOP, BOT}
  H.scrollRegion(CX, TOP, CW, BOT - TOP, "settings")
  lg.setScissor(CX - 4, TOP, CW + 8, BOT - TOP)
  if Su.section == "theme" then
    themes(clip)
  elseif Su.section == "glossary" then
    lg.setScissor()
    glossary(clip)
  else
    local list = rows(Su.section)
    local rh = 58
    local y = TOP - G.scroll.settings
    for _, r in ipairs(list) do
      if y + rh >= TOP and y <= BOT then
        col(C.line, 0.1); lg.line(CX, y + rh - 4, CX + CW, y + rh - 4)
        lg.setFont(Fo.s); col(C.white); lg.print(r[1], CX, y + 8)
        H.label(H.fit(Fo.xs, r[2], CW - 470), CX, y + 28, C.dim)
        r[3](CX + CW, y + 12, clip)
      end
      y = y + rh
    end
    local extra = 0
    if Su.section == "data" then
      resetSaveRow(y + 6, clip)
      extra = 110
    end
    G.maxScroll.settings = math.max(0, #list * rh + extra - (BOT - TOP))
  end
  lg.setScissor()
  -- message line
  if Su.msg then
    Su.msg.t = Su.msg.t - love.timer.getDelta()
    if Su.msg.t <= 0 then Su.msg = nil
    else
      lg.setFont(Fo.s); col(Su.msg.c, math.min(1, Su.msg.t))
      lg.printf(Su.msg.text, PX, PY + PH + 8, PW, "center")
    end
  end
end

return Su
