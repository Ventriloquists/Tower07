-- Persistent frame: top bar, bottom dock, notifications, center banner.
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local I = require "ui.icons"
local Set = require "game.settings"
local lg = V.lg
local C, col, fmt = H.C, H.col, H.fmt
local TAU = math.pi * 2
local F = {}

F.TOP, F.DOCK = 52, 656 -- content area is y 52..656

F.SCENES = {
  {"core",    "CORE",    "core",    "Reactor, objectives, quick build"},
  {"build",   "BUILD",   "build",   "Units and tech upgrades"},
  {"rigs",    "RIGS",    "rigs",    "Hydro extraction"},
  {"hangar",  "HANGAR",  "hangar",  "Drone fabrication, roster and modules"},
  {"map",     "MAP",     "map",     "Tactical map: scavs, sectors, loot"},
  {"ops",     "OPS",     "ops",     "Directives, daily supply, Signal Track, events"},
  {"nova",    "REBOOT",  "nova",    "Prestige and the protocol tree"},
  {"archive", "ARCHIVE", "archive", "Log entries, milestones, service record"},
}
function F.scene(key)
  for k, s in ipairs(F.SCENES) do if s[1] == key then return s, k end end
end

----------------------------------------------------------------------
-- background grid + flying signal
----------------------------------------------------------------------
-- macOS Tahoe style wallpaper: soft vertical gradient with slow, blurred colour blobs behind the glass
local wallMesh, wallKey
local WALL = {
  light = {top = {0.55, 0.76, 0.98}, bottom = {0.86, 0.90, 0.99},
    blobs = {{0.30, 0.62, 1.00}, {0.62, 0.50, 1.00}, {0.25, 0.85, 0.88}, {1.00, 0.62, 0.78}, {0.45, 0.80, 1.00}}},
  dark = {top = {0.04, 0.06, 0.16}, bottom = {0.09, 0.05, 0.17},
    blobs = {{0.16, 0.28, 0.85}, {0.48, 0.18, 0.72}, {0.08, 0.48, 0.62}, {0.70, 0.18, 0.42}, {0.20, 0.40, 0.95}}},
}
local function wallpaper(kind)
  local w = WALL[kind] or WALL.light
  local x0, y0, x1, y1 = V.extents()
  local key = kind .. x0 .. y0 .. x1 .. y1
  if wallKey ~= key then
    wallMesh = love.graphics.newMesh({
      {x0, y0, 0, 0, w.top[1], w.top[2], w.top[3], 1}, {x1, y0, 1, 0, w.top[1], w.top[2], w.top[3], 1},
      {x1, y1, 1, 1, w.bottom[1], w.bottom[2], w.bottom[3], 1}, {x0, y1, 0, 1, w.bottom[1], w.bottom[2], w.bottom[3], 1},
    }, "fan", "static")
    wallKey = key
  end
  love.graphics.setColor(1, 1, 1, 1); love.graphics.draw(wallMesh)
  local t = love.timer.getTime() * 0.05
  lg.setBlendMode(kind == "dark" and "add" or "alpha")
  for k, c in ipairs(w.blobs) do
    local bx = 640 + math.cos(t * (0.6 + k * 0.17) + k * 1.9) * 520
    local by = 380 + math.sin(t * (0.5 + k * 0.13) + k * 2.7) * 260
    local r = 260 + 60 * math.sin(t + k)
    for i = 1, 10 do -- stacked soft discs fake a heavy blur
      lg.setColor(c[1], c[2], c[3], kind == "dark" and 0.035 or 0.05)
      lg.circle("fill", bx, by, r * (1 - i * 0.08), 48)
    end
  end
  lg.setBlendMode("alpha")
end

-- macOS notifications: the newest messages slide in as glass cards top right (replaces the comms ticker)
function F.macNotifications()
  local Fo = H.fonts
  local _, _, x1 = V.extents()
  local shown = 0
  for _, t in ipairs(FX.toasts) do
    if t.life < 4 and not (Set.v.ticker == "important" and t.low) then
      shown = shown + 1
      if shown > 2 then break end
      local w, h = 340, 64
      local slide = math.min(1, t.life / 0.3)
      local fade = t.life > 3.4 and math.max(0, (4 - t.life) / 0.6) or 1
      local x = x1 - w - 14 + (1 - slide) ^ 3 * (w + 30)
      local y = 58 + (shown - 1) * (h + 8)
      lg.push("all")
      V.glassRect(x, y, w, h, 18, C.panel[1], C.panel[2], C.panel[3])
      -- app icon
      lg.setColor(t.c[1], t.c[2], t.c[3], fade); lg.rectangle("fill", x + 12, y + 14, 36, 36, 9, 9)
      lg.setColor(1, 1, 1, 0.25 * fade); lg.rectangle("fill", x + 12, y + 14, 36, 16, 9, 9)
      I.draw("event", x + 30, y + 32, 7, {1, 1, 1})
      lg.setFont(Fo.s); col(C.white, fade); lg.print(H.fit(Fo.s, t.title, w - 110), x + 58, y + 12)
      lg.setFont(Fo.xs); col(C.dim, fade); lg.print(H.fit(Fo.xs, t.text, w - 72), x + 58, y + 36)
      col(C.dim, 0.8 * fade); lg.printf("now", x, y + 13, w - 14, "right")
      lg.pop()
    end
  end
end

function F.background()
  if H.wallpaper then return wallpaper(H.wallpaper) end
  if H.style then return end -- desktop-app themes: clean background
  local x0, y0, x1, y1 = V.extents()
  -- key light from above the tower, a warm rim from the lower right: the HUD floats in a lit room
  local glow = F.glowMesh()
  local t = love.timer.getTime()
  col(C.line, 0.075); love.graphics.draw(glow, 640, -120, 0, 980, 620)
  col(C.orange, 0.035); love.graphics.draw(glow, 1180, 760, 0, 720, 460)
  -- survey grid with slight parallax toward the cursor
  local mx, my = V.mouse()
  local px = H.reduced and 0 or (mx - 640) / 640 * -6
  -- parallax camera: the grid drifts as you travel along the spine, so stations read as places side by side
  local _, st = F.scene(G.tab)
  local cam = H.tween("cam", -((st or 1) - 1) * 220, 5) * 0.4
  local camMinor, camMajor = cam % 40 - 40, cam % 160 - 160
  local py = H.reduced and 0 or (my - 360) / 360 * -4
  -- the grid is texture, not content: barely there, with registration crosses only on the major lines
  col(C.faint, 0.07)
  for x = math.floor(x0 / 40) * 40, x1 + 80, 40 do lg.line(x + px + camMinor, y0, x + px + camMinor, y1) end
  for y = math.floor(y0 / 40) * 40, y1 + 40, 40 do lg.line(x0, y + py, x1, y + py) end
  col(C.dim, 0.16)
  for x = math.floor(x0 / 160) * 160, x1 + 320, 160 do
    for y = math.floor(y0 / 160) * 160, y1 + 160, 160 do
      local gx = x + px + camMajor
      lg.line(gx - 3, y + py, gx + 3, y + py)
      lg.line(gx, y + py - 3, gx, y + py + 3)
    end
  end
  -- film grain keeps the large dark areas from looking flat
  local img, q = F.grain(x1 - x0, y1 - y0)
  local gx, gy = 0, 0
  if not H.reduced then gx, gy = math.floor(love.math.random() * 128), math.floor(love.math.random() * 128) end
  love.graphics.setColor(1, 1, 1, 0.028)
  q:setViewport(gx, gy, x1 - x0, y1 - y0, 128, 128)
  love.graphics.draw(img, q, x0, y0)
end

-- radial falloff (white centre -> transparent edge), tinted with setColor and scaled to any ellipse
local glowMesh
function F.glowMesh()
  if glowMesh then return glowMesh end
  local v = {{0, 0, 0.5, 0.5, 1, 1, 1, 1}}
  for i = 0, 48 do
    local a = i / 48 * TAU
    v[#v + 1] = {math.cos(a), math.sin(a), 0, 0, 1, 1, 1, 0}
  end
  glowMesh = love.graphics.newMesh(v, "fan", "static")
  return glowMesh
end

local grainImg, grainQuad
function F.grain(w, h)
  if not grainImg then
    local d = love.image.newImageData(128, 128)
    for y = 0, 127 do
      for x = 0, 127 do
        local v = love.math.random()
        d:setPixel(x, y, v, v, v, 1)
      end
    end
    grainImg = love.graphics.newImage(d)
    grainImg:setWrap("repeat", "repeat")
    grainQuad = love.graphics.newQuad(0, 0, w, h, 128, 128)
  end
  return grainImg, grainQuad
end

function F.signal()
  local s = G.signal
  if not s then return end
  for i, p in ipairs(s.trail) do
    if i % 3 == 0 then col(C.orange, i / #s.trail * 0.6); lg.rectangle("fill", p.x - 1, p.y - 1, 2, 2) end
  end
  local r = 26 + math.sin(G.time * 6) * 3
  H.hatch(s.x - 18, s.y - 18, 36, 36, C.red, 0.5, 5)
  col(C.red); lg.circle("line", s.x, s.y, 18)
  lg.push()
  lg.translate(s.x, s.y)
  lg.rotate(G.time * 1.5)
  H.brackets(-r, -r, r * 2, r * 2, 8, C.orange)
  lg.pop()
  col(C.white); lg.circle("fill", s.x, s.y, 3)
  local blink = math.floor(G.time * 4) % 2 == 0
  H.label("UNKNOWN SIGNAL", s.x + 34, s.y - 18, blink and C.orange or C.red)
  H.label("CLICK TO INTERCEPT", s.x + 34, s.y - 5, C.white, 0.8)
end

----------------------------------------------------------------------
-- badges shown on dock buttons
----------------------------------------------------------------------
function F.badges()
  local S = G.S
  local b = {}
  local list = G.availableUpgrades()
  local n = 0
  for _, u in ipairs(list) do if S.stardust >= u.cost then n = n + 1 end end
  b.build = {n, C.orange}
  local full = 0
  for i, r in ipairs(S.rigs) do if r.on and r.tank >= G.rigCap(i) then full = full + 1 end end
  b.rigs = {full, C.red}
  if #S.drones + #G.choiceQueue < G.bayCap() then
    b.hangar = {S.tokens + (S.hydro >= G.fabCost() and 1 or 0), C.orange}
  end
  local raiding = 0
  for _, e in ipairs(G.enemies) do if e.raid > 0 then raiding = raiding + 1 end end
  b.map = raiding > 0 and {raiding, C.red} or {#S.crateList, C.orange}
  local ops = (G.dailyPending and 1 or 0) + G.passReady()
  for _, d in ipairs(S.directives) do if G.dirProgress(d) >= d.target then ops = ops + 1 end end
  b.ops = {ops, C.orange}
  b.nova = {G.dmGain() >= math.max(1, S.dmTotal * 0.5) and 1 or 0, C.red}
  b.archive = {G.unclaimedLogs(), C.orange}
  b.core = {S.perkPoints, C.gold}
  return b
end

----------------------------------------------------------------------
-- top bar
----------------------------------------------------------------------
local function pill(x, y, w, h, icon, label, value, c, sub, tipTitle, tipText)
  local hov = H.mouseIn(x, y, w, h)
  if H.isHud() then
    -- resource readout: icon tile, small caps label, big value; a lit underline grows on hover
    -- the primary currency sits on a plate; the others are bare readouts divided by hairlines (plate on hover)
    local t = H.hoverT(x, y, w, h, hov)
    local hero = label == "ENERGY"
    if hero then
      col(C.panel, 0.85); lg.rectangle("fill", x, y, w, h)
      col(c, 0.05); lg.rectangle("fill", x, y, w, h)
      col(C.faint, 0.9); lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    else
      col(C.panel, 0.7 * t); lg.rectangle("fill", x, y, w, h)
      col(C.faint, 0.9); lg.line(x + w + 4, y + 6, x + w + 4, y + h - 6)
    end
    col(c, 0.12 + 0.1 * t); H.chamfer("fill", x + 4, y + 4, 24, h - 8, 5)
    I.draw(icon, x + 16, y + h / 2, 7, c)
    col(c, (hero and 0.7 or 0) + 0.3 * t); lg.rectangle("fill", x + 4, y + h - 2, 24 + (w - 28) * (hero and math.max(0.25, t) or t), 2)
    H.label(label, x + 36, y + 4, C.dim)
    lg.setFont(H.fonts.m); col(C.white); lg.print(value, x + 36, y + 15)
    if sub then
      lg.setFont(H.fonts.xs); col(c)
      lg.printf(sub, x, y + 19, w - 8, "right")
    end
    if hov and tipTitle then H.setTip(tipTitle, tipText) end
    return
  end
  col(C.panel, 0.95); lg.rectangle("fill", x, y, w, h)
  col(c, hov and 0.5 or 0.25); lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
  col(c, 0.12); lg.rectangle("fill", x, y, 30, h)
  I.draw(icon, x + 15, y + h / 2, 8, c)
  H.label(label, x + 38, y + 4, C.dim)
  lg.setFont(H.fonts.m); col(C.white); lg.print(value, x + 38, y + 15)
  if sub then
    lg.setFont(H.fonts.xs); col(c)
    lg.printf(sub, x, y + 19, w - 8, "right")
  end
  if hov and tipTitle then H.setTip(tipTitle, tipText) end
end

function F.topBar()
  local S = G.S
  local Fo = H.fonts
  local x0, _, x1 = V.extents()
  if H.wallpaper then
    -- floating glass toolbar
    V.glassRect(x0 + 4, 3, x1 - x0 - 8, F.TOP - 6, (F.TOP - 6) / 2, C.panel[1], C.panel[2], C.panel[3])
  elseif H.isHud() then
    col(C.bg, 0.94); lg.rectangle("fill", x0, 0, x1 - x0, F.TOP)
    col(C.faint, 1); lg.line(x0, F.TOP, x1, F.TOP)
    col(C.line, 0.6); lg.line(x0, F.TOP, 260, F.TOP) -- the profile corner carries the accent
  else
    col(C.bg, 0.97); lg.rectangle("fill", x0, 0, x1 - x0, F.TOP)
    col(C.line, 0.45); lg.line(x0, F.TOP, x1, F.TOP)
  end

  -- profile: rank badge with XP ring (mac themes make room for the traffic lights)
  local mac = H.style == "mac"
  local bx, by = mac and 84 or 32, 26
  local tx = mac and 112 or 62
  local need = G.xpNeed(S.rank)
  local hovP = H.mouseIn(8, 2, 250, 48)
  col(C.panel); lg.circle("fill", bx, by, 20, 32)
  col(C.faint); lg.setLineWidth(3); lg.circle("line", bx, by, 21, 32)
  col(C.orange); lg.arc("line", "open", bx, by, 21, -math.pi / 2, -math.pi / 2 + TAU * math.min(1, S.xp / need), 32)
  lg.setLineWidth(1)
  lg.setFont(Fo.m); col(C.white); lg.printf(tostring(S.rank), bx - 20, by - 9, 40, "center")
  lg.setFont(Fo.m); col(C.white); lg.print("TECH " .. (49 + S.prestiges), tx, 7)
  H.label(S.perkPoints > 0 and G.rankTitle(S.rank) or (G.rankTitle(S.rank) .. "  //  " .. fmt(S.xp) .. "/" .. fmt(need) .. " XP"),
    tx, 28, C.dim)
  if hovP then H.setTip("RANK " .. S.rank .. " // " .. G.rankTitle(S.rank), "Every rank: +2% output and a PERK POINT. Click to spend perk points.") end
  if S.perkPoints > 0 then
    local blink = 0.75 + 0.25 * math.sin(G.time * 6)
    local px, py, pw, ph = 180, 9, 74, 34
    col(C.gold, blink); lg.rectangle("fill", px, py, pw, ph)
    I.draw("perk", px + 15, py + ph / 2, 7, C.bg)
    lg.setFont(Fo.s); col(C.bg); lg.print("PERK", px + 28, py + 3)
    lg.setFont(Fo.xs); lg.print("x" .. S.perkPoints .. " [P]", px + 28, py + 19)
  end
  H.addHit(8, 2, 250, 48, function() if S.perkPoints > 0 then G.openPerkChoice() else FX.play("tick") end end)
  if mac then
    -- traffic lights: close (saves and quits), minimize, zoom (fullscreen)
    local lights = {
      {{1.00, 0.37, 0.34}, "x", "CLOSE", "Saves and quits the game.", function() love.event.quit() end},
      {{1.00, 0.74, 0.18}, "-", "MINIMIZE", "Minimizes the window.", function() love.window.minimize() end},
      {{0.16, 0.79, 0.25}, "+", "ZOOM", "Toggles fullscreen.", function() G.toggleFullscreen() end},
    }
    local any = H.mouseIn(8, 14, 54, 24)
    for k, l in ipairs(lights) do
      local lx = 18 + (k - 1) * 20
      lg.setColor(l[1][1], l[1][2], l[1][3]); lg.circle("fill", lx, by, 6.5, 24)
      lg.setColor(0, 0, 0, 0.18); lg.circle("line", lx, by, 6.5, 24)
      if any then lg.setFont(Fo.xs); lg.setColor(0, 0, 0, 0.6); lg.printf(l[2], lx - 6, by - 7, 12, "center") end
      if H.mouseIn(lx - 8, by - 8, 16, 16) then H.setTip(l[3], l[4]) end
      H.addHit(lx - 8, by - 8, 16, 16, l[5])
    end
  end

  -- currencies
  local cps = G.getCps()
  local x = 268
  pill(x, 8, 236, 36, "energy", "ENERGY", fmt(G.dispDust), C.line, "+" .. fmt(cps) .. "/S",
    "ENERGY", "Spend on units, tech, rigs. Earned per second and by tapping the core."); x = x + 244
  pill(x, 8, 118, 36, "hydro", "HYDRO", fmt(math.floor(S.hydro)), C.line, nil,
    "HYDRO", "Fabricates drones. Produced by RIGS."); x = x + 126
  pill(x, 8, 118, 36, "parts", "PARTS", fmt(S.parts), C.white, nil,
    "PARTS", "Upgrades drones. From crates, salvage, logs."); x = x + 126
  pill(x, 8, 96, 36, "token", "TOKENS", tostring(S.tokens), S.tokens > 0 and C.orange or C.dim, nil,
    "FAB TOKENS", "Free drone fabrications."); x = x + 104
  pill(x, 8, 118, 36, "cd", "CORE DATA", fmt(S.dm), C.red, nil,
    "CORE DATA", "Prestige currency. Boosts all output (+5% each up to 100, then slower). Spend in the protocol tree.")

  -- event pill
  local ex, ew = 996, 182
  local ev = G.event
  local hovE = H.mouseIn(ex, 8, ew, 36)
  local boss = G.boss and G.boss()
  if boss then
    -- an active mothership beats the event pill: red, pulsing, click to jump to the map
    local b = 0.5 + 0.5 * math.sin(G.time * 6)
    col(C.red, 0.2 + 0.15 * b); lg.rectangle("fill", ex, 8, ew, 36)
    H.hatch(ex, 8, ew, 36, C.red, 0.2, 6)
    H.brackets(ex, 8, ew, 36, 6, C.red)
    I.draw("event", ex + 16, 26, 8, C.red)
    lg.setFont(Fo.s); col(C.red); lg.print("MOTHERSHIP", ex + 30, 10)
    local bt = (boss.bounty or 0) > 0 and H.fmtTime(boss.bounty) or "--"
    lg.setFont(Fo.xs); col(C.white); lg.printf(bt, ex, 12, ew - 8, "right")
    H.bar(ex + 30, 34, ew - 40, 3, boss.hp / boss.max, C.red)
    if hovE then H.setTip("MOTHERSHIP ACTIVE", "Hull " .. math.floor(boss.hp / boss.max * 100) .. "%. Destroy it to clear the zone" ..
      ((boss.bounty or 0) > 0 and " - before the bounty runs out for 2 LEGENDARY crates + 3 fab tokens." or ".") .. " Click to open the MAP.") end
    H.addHit(ex, 8, ew, 36, function() if G.unlocked("map") then G.tab = "map"; FX.play("tap", 1.6, 0.4) end end)
  elseif ev then
    local ec = C[ev.def.col]
    col(ec, 0.22 + 0.08 * math.sin(G.time * 5)); lg.rectangle("fill", ex, 8, ew, 36)
    H.hatch(ex, 8, ew, 36, ec, 0.15, 6)
    H.brackets(ex, 8, ew, 36, 6, ec)
    I.draw("event", ex + 16, 26, 8, ec)
    lg.setFont(Fo.s); col(ec); lg.print(ev.def.name, ex + 30, 10)
    lg.setFont(Fo.xs); col(C.white); lg.printf(H.fmtTime(ev.t), ex, 12, ew - 8, "right")
    H.bar(ex + 30, 34, ew - 40, 3, ev.t / ev.dur, ec)
    if hovE then H.setTip("EVENT ACTIVE // " .. ev.def.name, ev.def.desc) end
  elseif G.nextEvent then
    local ne = G.nextEvent
    col(C.panel, 0.95); lg.rectangle("fill", ex, 8, ew, 36)
    H.brackets(ex, 8, ew, 36, 6, C.dim, 0.8)
    I.draw("event", ex + 16, 26, 8, C.dim)
    H.label("NEXT EVENT IN " .. H.fmtTime(ne.t), ex + 30, 12, C.dim)
    lg.setFont(Fo.s); col(C[ne.def.col], 0.85); lg.print(ne.def.name, ex + 30, 24)
    if hovE then H.setTip("UPCOMING // " .. ne.def.name, ne.def.desc) end
  end

  -- settings
  local function iconBtn(bx2, icon, on, title, text, fn)
    local hov = H.mouseIn(bx2, 8, 40, 36)
    if H.isHud() then
      local t = H.hoverT(bx2, 8, 40, 36, hov)
      col(C.panel, 0.7); lg.rectangle("fill", bx2, 8, 40, 36)
      col(C.line, 0.04 + 0.12 * t); lg.rectangle("fill", bx2, 8, 40, 36)
      col(C.faint, 0.8); lg.rectangle("line", bx2 + 0.5, 8.5, 39, 35)
      I.draw(icon, bx2 + 20, 26, 8, hov and C.white or (on and C.line or C.red))
      if hov then H.setTip(title, text) end
      H.addHit(bx2, 8, 40, 36, fn)
      return
    end
    col(C.line, hov and 0.2 or 0.05); lg.rectangle("fill", bx2, 8, 40, 36)
    H.brackets(bx2, 8, 40, 36, 5, hov and C.white or (on and C.line or C.dim))
    I.draw(icon, bx2 + 20, 26, 8, hov and C.white or (on and C.line or C.red))
    if hov then H.setTip(title, text) end
    H.addHit(bx2, 8, 40, 36, fn)
  end
  iconBtn(1186, "audio", not FX.muted, FX.muted and "AUDIO OFF" or "AUDIO ON", "Toggle sound [M]", function() FX.muted = not FX.muted end)
  iconBtn(1232, "parts", true, "SETTINGS", "Display, audio, themes, boss key, save data  [ESC on CORE]", function()
    G.settingsOpen = true
    FX.play("tick", 1.2)
  end)
end

----------------------------------------------------------------------
-- bottom dock
----------------------------------------------------------------------
-- macOS style: a floating, frosted Dock with app tiles that magnify toward the cursor
local DOCK_TILE = {
  {0.04, 0.52, 1.00}, {1.00, 0.58, 0.00}, {0.20, 0.78, 0.35}, {0.35, 0.34, 0.84},
  {1.00, 0.23, 0.19}, {0.69, 0.32, 0.87}, {0.56, 0.56, 0.58}, {0.35, 0.78, 0.98},
}
function F.macDock()
  local Fo = H.fonts
  local y = F.DOCK
  local badges = F.badges()
  local n = #F.SCENES
  local slotW, base = 64, 44
  local dw = n * slotW + 20
  local dx, dy = 640 - dw / 2, y + 8
  local mx, my = V.mouse()
  local inDock = my >= dy - 30 and my <= y + 64 and mx >= dx - 30 and mx <= dx + dw + 30 and not G.modal
  V.glassRect(dx, dy, dw, 54, 22, C.panel[1], C.panel[2], C.panel[3])
  local hovered
  for k, s in ipairs(F.SCENES) do
    local key = s[1]
    local cx = dx + 10 + (k - 0.5) * slotW
    local mag = inDock and math.max(0, 1 - math.abs(mx - cx) / 130) or 0
    local sz = base * (1 + 0.5 * mag * mag)
    local cy = dy + 27 - (sz - base) * 0.9
    local open, need = G.unlocked(key)
    local tc = open and DOCK_TILE[(k - 1) % #DOCK_TILE + 1] or {0.6, 0.6, 0.62}
    -- tile with a soft top sheen
    lg.setColor(0, 0, 0, 0.15); lg.rectangle("fill", cx - sz / 2, cy - sz / 2 + 2, sz, sz, sz * 0.24, sz * 0.24)
    lg.setColor(tc[1], tc[2], tc[3], open and 1 or 0.6); lg.rectangle("fill", cx - sz / 2, cy - sz / 2, sz, sz, sz * 0.24, sz * 0.24)
    lg.setColor(1, 1, 1, 0.18); lg.rectangle("fill", cx - sz / 2, cy - sz / 2, sz, sz * 0.45, sz * 0.24, sz * 0.24)
    I.draw(open and s[3] or "lock", cx, cy, sz * 0.22, {1, 1, 1})
    if G.tab == key then col(C.white, 0.75); lg.circle("fill", cx, dy + 51, 2.2, 10) end
    if open and badges[key] and badges[key][1] > 0 then H.badge(cx + sz / 2 - 4, cy - sz / 2 + 4, badges[key][1], C.red) end
    if inDock and math.abs(mx - cx) < slotW / 2 then hovered = {cx = cx, top = cy - sz / 2, name = open and s[2] or (need .. " LOGS")} end
    H.addHit(cx - slotW / 2, dy, slotW, 56, function()
      if not open then
        FX.toast(s[2] .. " // LOCKED", "Collect " .. need .. " log entries to unlock (" .. G.achCount .. "/" .. need .. ").", C.red)
        FX.play("err")
        return
      end
      G.tab = key
      FX.play("tap", 1.6, 0.4)
    end)
  end
  -- name bubble above the hovered app, like the real Dock
  if hovered then
    lg.setFont(Fo.s)
    local w = Fo.s:getWidth(hovered.name) + 20
    local bx, by = hovered.cx - w / 2, hovered.top - 32
    col(C.panel, 0.95); lg.rectangle("fill", bx, by, w, 24, 6, 6)
    col(C.dim, 0.4); lg.rectangle("line", bx + 0.5, by + 0.5, w - 1, 23, 6, 6)
    col(C.white); lg.printf(hovered.name, bx, by + 4, w, "center")
  end
end

-- THE SPINE: the tower's stations on one transit line. Each station reports what is happening there right now,
-- so you know where to go before you go. The active marker travels along the line when you switch.
-- level: "alert" (red, act now), "attn" (amber, something to collect), nil (calm readout)
function F.context(key)
  local S = G.S
  if key == "core" then
    if S.perkPoints > 0 then return S.perkPoints .. " PERK" .. (S.perkPoints > 1 and "S" or ""), "attn" end
    return "+" .. fmt(G.getCps()) .. "/S"
  elseif key == "build" then
    local n = 0
    for _, u in ipairs(G.availableUpgrades()) do if S.stardust >= u.cost then n = n + 1 end end
    if n > 0 then return n .. " TECH READY", "attn" end
    local units = 0
    for i = 1, #D.GENS do units = units + (S.gens[i] or 0) end
    return fmt(units) .. " UNITS"
  elseif key == "rigs" then
    local full, on, sum = 0, 0, 0
    for i, r in ipairs(S.rigs) do
      if r.on then on = on + 1; sum = sum + math.min(1, r.tank / G.rigCap(i)); if r.tank >= G.rigCap(i) then full = full + 1 end end
    end
    if full > 0 then return full .. " AT PEAK", "attn" end
    if on == 0 then return "OFFLINE" end
    return math.floor(sum / on * 100) .. "% TANKS"
  elseif key == "hangar" then
    if #G.choiceQueue > 0 then return "PICK DRONE", "attn" end
    if S.tokens > 0 and #S.drones < G.bayCap() then return S.tokens .. " TOKENS", "attn" end
    return #S.drones .. "/" .. G.bayCap() .. " DRONES"
  elseif key == "map" then
    if G.boss and G.boss() then return "MOTHERSHIP", "alert" end
    for _, e in ipairs(G.enemies) do if e.raid > 0 then return "RAID", "alert" end end
    if S.bossDown then return "ZONE CLEAR", "attn" end
    if #S.crateList > 0 then return #S.crateList .. " CRATE" .. (#S.crateList > 1 and "S" or ""), "attn" end
    return "ZONE " .. S.zone
  elseif key == "ops" then
    local n = (G.dailyPending and 1 or 0) + G.passReady()
    for _, d in ipairs(S.directives) do if G.dirProgress(d) >= d.target then n = n + 1 end end
    if n > 0 then return n .. " READY", "attn" end
    return "TIER " .. S.passTier
  elseif key == "nova" then
    local g = G.dmGain()
    if g >= math.max(1, S.dmTotal * 0.5) then return "+" .. fmt(g) .. " CD", "alert" end
    return fmt(S.dm) .. " CD"
  elseif key == "archive" then
    local n = G.unclaimedLogs()
    if n > 0 then return n .. " REWARD" .. (n > 1 and "S" or ""), "attn" end
    return G.achCount .. "/" .. #D.ACH
  end
  return ""
end

local function hudDock()
  local Fo = H.fonts
  local x0, _, x1, y1 = V.extents()
  local y = F.DOCK
  local n = #F.SCENES
  local w = 1280 / n
  local ly = y + 20 -- the line
  col(C.bg, 0.97); lg.rectangle("fill", x0, y, x1 - x0, y1 - y)
  col(C.faint, 1); lg.line(x0, y, x1, y)
  local _, active = F.scene(G.tab)
  active = active or 1
  -- the line itself: lit up to the last unlocked station, dashed beyond it
  local lastOpen = 1
  for k, s in ipairs(F.SCENES) do if G.unlocked(s[1]) then lastOpen = k end end
  col(C.dim, 0.7); lg.rectangle("fill", x0, ly, (lastOpen - 0.5) * w - x0, 1)
  col(C.faint, 1)
  for dx = (lastOpen - 0.5) * w, x1, 8 do lg.rectangle("fill", dx, ly, 4, 1) end
  -- the travelling marker (eased along the line, it leaves a short light trail while moving)
  local mx = H.tween("spineX", (active - 0.5) * w, H.MO.base)
  local target = (active - 0.5) * w
  local glow = F.glowMesh()
  col(C.line, 0.14); love.graphics.draw(glow, mx, ly, 0, w * 0.5, 40)
  if math.abs(target - mx) > 2 then
    local a, b = math.min(mx, target), math.max(mx, target)
    col(C.line, 0.5); lg.rectangle("fill", a, ly - 0.5, b - a, 2)
  end
  for k, s in ipairs(F.SCENES) do
    local key = s[1]
    local x = (k - 1) * w
    local cx = x + w / 2
    local on = G.tab == key
    local open, need = G.unlocked(key)
    local hov = H.mouseIn(x, y, w, 64)
    local t = H.hoverT(x, y, w, 64, hov)
    local txt, level = "", nil
    if open then txt, level = F.context(key) end
    local lc = level == "alert" and C.red or (level == "attn" and C.orange or nil)
    if hov and not on then col(C.line, 0.035); lg.rectangle("fill", x + 1, y + 1, w - 2, 63) end
    -- station node: diamond. Active = solid and ringed; attention = amber core; locked = hollow, dim
    local r = (on and 6 or 4.5) + t * 1.5
    if level == "alert" and not H.reduced then
      local p = (love.timer.getTime() * 1.2) % 1
      col(C.red, 0.6 * (1 - p)); lg.polygon("line", cx, ly - r - p * 12, cx + r + p * 12, ly, cx, ly + r + p * 12, cx - r - p * 12, ly)
    end
    col(C.bg); lg.polygon("fill", cx, ly - r - 2, cx + r + 2, ly, cx, ly + r + 2, cx - r - 2, ly)
    if on then
      col(C.white); lg.polygon("fill", cx, ly - r, cx + r, ly, cx, ly + r, cx - r, ly)
      col(C.line, 0.8); lg.polygon("line", cx, ly - r - 4, cx + r + 4, ly, cx, ly + r + 4, cx - r - 4, ly)
    elseif open then
      col(lc or C.dim, lc and 1 or (0.6 + 0.4 * t)); lg.polygon(lc and "fill" or "line", cx, ly - r, cx + r, ly, cx, ly + r, cx - r, ly)
    else
      col(C.faint); lg.polygon("line", cx, ly - r, cx + r, ly, cx, ly + r, cx - r, ly)
    end
    -- name with its icon, live readout below
    I.draw(open and s[3] or "lock", cx - Fo.s:getWidth(s[2]) / 2 - 12, ly + 20, 6, on and C.white or (open and C.dim or C.faint), open and (0.7 + 0.3 * t) or 0.6)
    lg.setFont(Fo.s)
    local r2, g2, b2 = H.lerpC(C.dim, C.white, on and 1 or t)
    if open then lg.setColor(r2, g2, b2, 1) else col(C.faint) end
    lg.printf(s[2], x, ly + 12, w, "center")
    lg.setFont(Fo.xs)
    if open then
      col(lc or C.dim, lc and 1 or 0.8); lg.printf(H.fit(Fo.xs, txt, w - 12), x, ly + 28, w, "center")
    else
      col(C.faint); lg.printf(need .. " LOGS", x, ly + 28, w, "center")
    end
    if t > 0.02 then lg.setFont(Fo.xs); col(C.dim, t); lg.print(tostring(k), x + 8, y + 5) end
    if hov then H.setTip(s[2], open and (s[4] .. "  [" .. k .. "]") or ("Unlocks at " .. need .. " log entries")) end
    H.addHit(x, y, w, 64, function()
      if not open then
        FX.toast(s[2] .. " // LOCKED", "Collect " .. need .. " log entries to unlock (" .. G.achCount .. "/" .. need .. ").", C.red)
        FX.play("err")
        return
      end
      G.tab = key
      FX.play("tap", 1.6, 0.4)
    end)
  end
end

function F.dock()
  if H.style == "mac" then return F.macDock() end
  if H.isHud() then return hudDock() end
  local Fo = H.fonts
  local x0, _, x1, y1 = V.extents()
  local y = F.DOCK
  col(C.bg, 0.97); lg.rectangle("fill", x0, y, x1 - x0, y1 - y)
  col(C.line, 0.45); lg.line(x0, y, x1, y)
  local badges = F.badges()
  local w = 1280 / #F.SCENES
  for k, s in ipairs(F.SCENES) do
    local key = s[1]
    local x = (k - 1) * w
    local on = G.tab == key
    local open, need = G.unlocked(key)
    local hov = H.mouseIn(x, y, w, 64)
    if on then
      col(C.line, 0.14); lg.rectangle("fill", x + 2, y + 1, w - 4, 63)
      col(C.white); lg.rectangle("fill", x + 14, y, w - 28, 3)
    elseif hov then
      col(C.line, 0.06); lg.rectangle("fill", x + 2, y + 1, w - 4, 63)
    end
    local cx = x + w / 2
    local ic = not open and C.red or (on and C.white or (hov and C.line or C.dim))
    I.draw(open and s[3] or "lock", cx, y + 22, 10, ic, open and 1 or 0.6)
    lg.setFont(Fo.s); col(ic, open and 1 or 0.7)
    lg.printf(open and s[2] or (need .. " LOGS"), x, y + 38, w, "center")
    H.label(tostring(k), x + 10, y + 6, C.faint)
    if open and key == "map" and G.boss and G.boss() then
      local b = 0.5 + 0.5 * math.sin(G.time * 6)
      col(C.red, 0.08 + 0.12 * b); lg.rectangle("fill", x + 2, y + 1, w - 4, 63)
      H.brackets(x + 4, y + 3, w - 8, 59, 6, C.red, 0.5 + 0.5 * b)
      lg.setFont(Fo.xs); col(C.red); lg.printf("MOTHERSHIP", x, y + 52, w, "center")
    end
    if open and badges[key] then
      local n, bc = badges[key][1], badges[key][2]
      if n > 0 then H.badge(cx + 18, y + 12, n, bc) end
    end
    if hov then H.setTip(s[2], open and s[4] or ("Unlocks at " .. need .. " log entries")) end
    H.addHit(x, y, w, 64, function()
      if not open then
        FX.toast(s[2] .. " // LOCKED", "Collect " .. need .. " log entries to unlock (" .. G.achCount .. "/" .. need .. ").", C.red)
        FX.play("err")
        return
      end
      G.tab = key
      FX.play("tap", 1.6, 0.4)
    end)
  end
end

----------------------------------------------------------------------
-- notifications (top right) and center banner
----------------------------------------------------------------------
-- comms ticker: a single strip above the dock (never covers content)
F.TICKER = 636
function F.toasts()
  if H.style == "mac" then return F.macNotifications() end
  local Fo = H.fonts
  local x0, _, x1 = V.extents()
  local y, h = F.TICKER, F.DOCK - F.TICKER
  col(C.bg, 0.97); lg.rectangle("fill", x0, y, x1 - x0, h)
  col(C.line, 0.25); lg.line(x0, y, x1, y)
  col(C.line, 0.15); lg.rectangle("fill", 0, y, 64, h)
  lg.setFont(Fo.xs); col(C.line); lg.print("COMMS", 18, y + 4)
  -- live channel dot
  col(C.line, H.reduced and 1 or (0.4 + 0.6 * math.abs(math.sin(love.timer.getTime() * 2)))); lg.rectangle("fill", 8, y + 8, 4, 4)
  local x = 76
  lg.setFont(Fo.xs)
  local list = {}
  for _, t in ipairs(FX.toasts) do
    if not (Set.v.ticker == "important" and t.low) then list[#list + 1] = t end
  end
  for i, t in ipairs(list) do
    local fresh = math.max(0, 1 - t.life / 1.5)
    local a = i == 1 and 1 or math.max(0.35, 0.8 - i * 0.12)
    local txt = t.title .. (t.text ~= "" and ("  //  " .. t.text) or "")
    local maxW = i == 1 and 620 or 420
    txt = H.fit(Fo.xs, txt, maxW)
    local w = Fo.xs:getWidth(txt) + 20
    if x + w > 1270 then break end
    if fresh > 0 then col(t.c, 0.3 * fresh); lg.rectangle("fill", x - 4, y + 1, w, h - 2) end
    col(t.c, a); lg.rectangle("fill", x, y + 7, 5, 5)
    col(i == 1 and t.c or C.white, a); lg.print(txt, x + 10, y + 4)
    x = x + w + 14
  end
end

function F.banner()
  local b = G.rankBanner
  if not b then return end
  local a = math.min(1, b.t * 5, (3 - b.t) * 2)
  local c = b.c or C.white
  local x0, _, x1 = V.extents()
  if H.isHud() then
    -- cinematic letterbox: the band opens from the centre line, the title settles in, then it all closes
    local open = H.ease.outCubic(math.min(1, b.t * 4)) * math.min(1, (3 - b.t) * 3)
    local cy, full = 256, 96
    local h = full * open
    local y = cy - h / 2
    col(C.bg, 0.9 * a); lg.rectangle("fill", x0, y, x1 - x0, h)
    local glow = F.glowMesh()
    col(c, 0.12 * a); love.graphics.draw(glow, 640, cy, 0, 700, h * 0.6)
    local lw = (x1 - x0) * H.ease.outExpo(math.min(1, b.t * 2.5))
    col(c, a); lg.rectangle("fill", 640 - lw / 2, y, lw, 1); lg.rectangle("fill", 640 - lw / 2, y + h - 1, lw, 1)
    if open > 0.6 then
      lg.push("all")
      lg.intersectScissor(x0, y, x1 - x0, h)
      local settle = (1 - H.ease.outCubic(math.min(1, b.t * 3))) * 60
      local title = b.rank and ("RANK " .. b.rank .. "  //  " .. G.rankTitle(b.rank)) or b.title
      lg.setFont(H.fonts.xs); col(c, a)
      lg.printf(b.rank and "PROMOTION" or "PRIORITY SIGNAL", 0, cy - 40, 1280, "center")
      lg.setFont(H.fonts.d1); col(C.white, a)
      lg.printf(title, settle, cy - 26, 1280, "center")
      H.richf(b.text or "", -settle, cy + 16, 1280, "center", C.dim, a, H.fonts.s)
      lg.pop()
    end
    return
  end
  local y, h = 214, 84
  local slide = (1 - math.min(1, b.t * 4)) * 200
  col(C.bg, 0.88 * a); lg.rectangle("fill", x0, y, x1 - x0, h)
  H.hatch(x0, y, x1 - x0, h, c, 0.08 * a, 8)
  col(c, a); lg.rectangle("fill", x0, y, x1 - x0, 2); lg.rectangle("fill", x0, y + h - 2, x1 - x0, 2)
  lg.setFont(H.fonts.xl); col(c, a)
  lg.printf(b.rank and ("RANK UP // " .. b.rank .. " // " .. G.rankTitle(b.rank)) or b.title, slide, y + 12, 1280, "center")
  lg.setFont(H.fonts.s); col(C.white, a)
  H.richf(b.text or "", -slide, y + 52, 1280, "center", C.white, a, H.fonts.s)
end

return F
