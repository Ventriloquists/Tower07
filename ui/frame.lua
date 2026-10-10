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
function F.background()
  local x0, y0, x1, y1 = V.extents()
  col(C.faint, 0.16)
  for x = math.floor(x0 / 40) * 40, x1, 40 do lg.line(x, y0, x, y1) end
  for y = math.floor(y0 / 40) * 40, y1, 40 do lg.line(x0, y, x1, y) end
  col(C.dim, 0.22)
  for x = math.floor(x0 / 160) * 160, x1, 160 do
    for y = math.floor(y0 / 160) * 160, y1, 160 do
      lg.line(x - 4, y, x + 4, y)
      lg.line(x, y - 4, x, y + 4)
    end
  end
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
  col(C.bg, 0.97); lg.rectangle("fill", x0, 0, x1 - x0, F.TOP)
  col(C.line, 0.45); lg.line(x0, F.TOP, x1, F.TOP)

  -- profile: rank badge with XP ring
  local bx, by = 32, 26
  local need = G.xpNeed(S.rank)
  local hovP = H.mouseIn(8, 2, 250, 48)
  col(C.panel); lg.circle("fill", bx, by, 20, 32)
  col(C.faint); lg.setLineWidth(3); lg.circle("line", bx, by, 21, 32)
  col(C.orange); lg.arc("line", "open", bx, by, 21, -math.pi / 2, -math.pi / 2 + TAU * math.min(1, S.xp / need), 32)
  lg.setLineWidth(1)
  lg.setFont(Fo.m); col(C.white); lg.printf(tostring(S.rank), bx - 20, by - 9, 40, "center")
  lg.setFont(Fo.m); col(C.white); lg.print("TECH " .. (49 + S.prestiges), 62, 7)
  H.label(S.perkPoints > 0 and G.rankTitle(S.rank) or (G.rankTitle(S.rank) .. "  //  " .. fmt(S.xp) .. "/" .. fmt(need) .. " XP"),
    62, 28, C.dim)
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
    "CORE DATA", "Prestige currency. Each point: +5% output forever. Spend in the protocol tree.")

  -- event pill
  local ex, ew = 996, 182
  local ev = G.event
  local hovE = H.mouseIn(ex, 8, ew, 36)
  if ev then
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
function F.dock()
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
  local Fo = H.fonts
  local x0, _, x1 = V.extents()
  local y, h = F.TICKER, F.DOCK - F.TICKER
  col(C.bg, 0.97); lg.rectangle("fill", x0, y, x1 - x0, h)
  col(C.line, 0.25); lg.line(x0, y, x1, y)
  col(C.line, 0.15); lg.rectangle("fill", 0, y, 64, h)
  lg.setFont(Fo.xs); col(C.line); lg.print("COMMS", 12, y + 4)
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
