-- OPS: everything here runs on time and progress, so the station is built around lines.
-- Top: the SIGNAL TRACK as a road (tier nodes on one line, rewards above, your position on it).
-- Bottom left: three DIRECTIVES as mission dossiers with progress rings. Bottom right: the SCHEDULE
-- (daily supply streak on its own short line, the live or next event, the event roster on demand).
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local I = require "ui.icons"
local lg = V.lg
local C, col, fmt, clamp = H.C, H.col, H.fmt, H.clamp
local TAU = math.pi * 2
local Sc = {}

local function diamond(mode, x, y, r) lg.polygon(mode, x, y - r, x + r, y, x, y + r, x - r, y) end

----------------------------------------------------------------------
-- SIGNAL TRACK road
----------------------------------------------------------------------
local STEP = 132
local function track()
  local S = G.S
  local Fo = H.fonts
  local x, y, w, h = 24, H.HEAD.BODY_Y, 1232, 178
  local need = G.passNeed(S.passTier + 1)
  local ready = G.passReady()
  -- standard card header (title in the lit band, progress on the right); controls get their own row below it
  H.card(x, y, w, h, "SIGNAL TRACK  //  TIER " .. S.passTier, ready > 0 and C.orange or C.line,
    fmt(S.sxp) .. " / " .. fmt(need) .. " SXP TO TIER " .. (S.passTier + 1))
  local ry, rh = y + 32, H.HEAD.CTRL_H
  H.label("EVERYTHING YOU DO EARNS SXP  //  WHEEL OR ARROWS TO BROWSE", x + 12, ry + 7, C.dim)
  H.button(x + w - 12 - 222, ry, 222, rh, ready > 0 and ("CLAIM ALL  //  " .. ready .. (ready == 1 and " TIER" or " TIERS")) or "NOTHING TO CLAIM",
    ready > 0, G.claimAllPass, C.orange, Fo.xs, nil, ready > 0)
  H.button(x + w - 12 - 222 - 8 - 34, ry, 34, rh, ">", true, function() G.passView = (G.passView or 1) + 4 end, C.dim, Fo.s)
  H.button(x + w - 12 - 222 - 8 - 34 - 6 - 34, ry, 34, rh, "<", true, function() G.passView = math.max(1, (G.passView or 1) - 4) end, C.dim, Fo.s)
  -- the road: scrolls smoothly; wheel and arrows move the view; every visit starts at your next claim
  local now = love.timer.getTime()
  if not G.passView or now - (Sc.seen or 0) > 0.5 then G.passView = math.max(1, S.passClaimed - 1) end
  Sc.seen = now
  local view = H.tween("passRoad", G.passView, H.MO.base)
  local lx0, lx1, ly = x + 20, x + w - 20, y + 124
  lg.push("all")
  lg.intersectScissor(lx0 - 10, y + 62, lx1 - lx0 + 20, h - 64)
  local function nx(t) return lx0 + 40 + (t - view) * STEP end
  -- base line, lit up to your exact position (claimed + progress into the next tier)
  col(C.faint); lg.rectangle("fill", lx0, ly, lx1 - lx0, 2)
  local pos = S.passTier + clamp(S.sxp / need, 0, 1)
  local px = nx(pos)
  col(C.orange, 0.9); lg.rectangle("fill", lx0, ly, clamp(px - lx0, 0, lx1 - lx0), 2)
  local first = math.max(1, math.floor(view) - 1)
  for t = first, first + math.ceil((lx1 - lx0) / STEP) + 2 do
    local cx = nx(t)
    if cx > lx0 - 60 and cx < lx1 + 60 then
      local r = D.passReward(t)
      local rc = C[r.col] or C.line
      local claimed = t <= S.passClaimed
      local reached = t <= S.passTier
      local nextClaim = t == S.passClaimed + 1 and reached
      local size = r.big and 9 or 6
      local hov = H.mouseIn(cx - STEP / 2, y + 62, STEP, h - 64)
      -- reward above the line
      I.draw(r.icon or "crate", cx, ly - 44, r.big and 12 or 9, reached and rc or C.faint, (reached or hov) and 1 or 0.7)
      lg.setFont(Fo.xs); col(reached and rc or C.dim, reached and 1 or 0.8)
      lg.printf(H.fit(Fo.xs, r.text, STEP - 12), cx - STEP / 2 + 6, ly - 26, STEP - 12, "center")
      -- node on the line
      col(C.bg); diamond("fill", cx, ly + 1, size + 3)
      if claimed then
        col(C.orange, 0.55); diamond("fill", cx, ly + 1, size)
      elseif nextClaim then
        if not H.reduced then
          local p = (love.timer.getTime() * 1.1) % 1
          col(C.orange, 0.7 * (1 - p)); diamond("line", cx, ly + 1, size + 4 + p * 12)
        end
        col(C.orange); diamond("fill", cx, ly + 1, size + 1)
      elseif reached then
        col(rc); diamond("fill", cx, ly + 1, size)
      else
        col(r.big and rc or C.faint, r.big and 0.6 or 1); diamond("line", cx, ly + 1, size)
      end
      if r.big then col(rc, reached and 0.8 or 0.35); diamond("line", cx, ly + 1, size + 6) end
      -- tier and state below
      lg.setFont(Fo.s); col(reached and C.white or C.dim); lg.printf("TIER " .. t, cx - 50, ly + 14, 100, "center")
      lg.setFont(Fo.xs)
      if claimed then col(C.dim); lg.printf("CLAIMED", cx - 50, ly + 32, 100, "center")
      elseif nextClaim then col(C.orange); lg.printf("CLAIM", cx - 50, ly + 32, 100, "center")
      elseif reached then col(rc); lg.printf("READY", cx - 50, ly + 32, 100, "center")
      elseif t == S.passTier + 1 then col(C.line); lg.printf(math.floor(S.sxp / need * 100) .. "%", cx - 50, ly + 32, 100, "center")
      else col(C.faint); lg.printf("LOCKED", cx - 50, ly + 32, 100, "center") end
      if hov then
        H.setTip("TIER " .. t, r.text .. (claimed and " // CLAIMED" or (reached and " // READY" or "")))
        if nextClaim then col(C.orange, 0.06); lg.rectangle("fill", cx - STEP / 2, y + 62, STEP, h - 64) end
      end
      if nextClaim then H.addHit(cx - STEP / 2, y + 62, STEP, h - 64, G.claimPass) end
    end
  end
  -- you are here
  if px > lx0 and px < lx1 then
    col(C.white); lg.polygon("fill", px - 5, ly - 12, px + 5, ly - 12, px, ly - 4)
  end
  lg.pop()
  H.scrollRegion(x, y + 62, w, h - 64, "passView", true)
end

----------------------------------------------------------------------
-- DIRECTIVES: three mission dossiers
----------------------------------------------------------------------
local function ring(cx, cy, r, f, c)
  lg.setLineWidth(4)
  col(C.faint, 0.8); lg.circle("line", cx, cy, r, 64)
  if f > 0 then col(c); lg.arc("line", "open", cx, cy, r, -math.pi / 2, -math.pi / 2 + clamp(f, 0, 1) * TAU, 64) end
  lg.setLineWidth(1)
  col(c, 0.5)
  for k = 0, 23 do
    local a = k / 24 * TAU
    lg.line(cx + math.cos(a) * (r + 6), cy + math.sin(a) * (r + 6), cx + math.cos(a) * (r + (k % 6 == 0 and 11 or 8)), cy + math.sin(a) * (r + (k % 6 == 0 and 11 or 8)))
  end
end

local function directives()
  local S = G.S
  local Fo = H.fonts
  local x0, y, h = 24, 288, 342 -- heading at 286, dossiers end at 630
  H.heading("DIRECTIVES", x0, y - 2, 800, C.line, nil, S.dirDone .. " COMPLETED  //  REROLL ONE EVERY 5 MIN")
  y = y + 26
  h = h - 26
  local w = (800 - 2 * H.HEAD.GUTTER) / 3
  for i, d in ipairs(S.directives) do
    local x = x0 + (i - 1) * (w + H.HEAD.GUTTER)
    local prog = G.dirProgress(d)
    local f = clamp(prog / d.target, 0, 1)
    local done = prog >= d.target
    local dc = done and C.orange or (d.priority and C.orange or C.line)
    H.card(x, y, w, h, nil, dc)
    if d.priority then
      col(C.orange, 0.12); lg.rectangle("fill", x + H.CUT, y + 1, w - H.CUT, 22)
      H.label("PRIORITY  //  TRIPLE REWARD", x + 14, y + 6, C.orange)
    else
      H.label(string.format("DIRECTIVE %02d", i), x + 14, y + 6, C.dim)
    end
    -- progress ring with the count inside
    local cx, cy = x + w / 2, y + 90
    ring(cx, cy, 52, f, dc)
    lg.setFont(Fo.d2); col(done and C.orange or C.white); lg.printf(math.floor(f * 100) .. "%", cx - 60, cy - 18, 120, "center")
    lg.setFont(Fo.xs); col(C.dim)
    lg.printf(fmt(math.max(0, math.min(prog, d.target))) .. " / " .. fmt(d.target), cx - 60, cy + 10, 120, "center")
    -- the order
    H.richf(G.dirText(d), x + 14, y + 160, w - 28, "center", C.white, 1, Fo.s)
    H.label("REWARD", x + 14, y + 204, C.dim)
    H.richf(G.rewardText(d), x + 14, y + 218, w - 28, "left", d.priority and C.orange or C.line, 1, Fo.xs)
    H.button(x + 14, y + h - 76, w - 28, 36, done and "CLAIM" or "IN PROGRESS", done, function() G.claimDirective(i) end,
      C.orange, Fo.m, nil, done)
    local cd = S.rerollAt - G.now()
    H.button(x + 14, y + h - 34, w - 28, 24, cd > 0 and ("REROLL IN " .. H.clock(cd):sub(4)) or "REROLL",
      cd <= 0 and not done, function() G.rerollDirective(i) end, C.dim, Fo.xs)
  end
end

----------------------------------------------------------------------
-- SCHEDULE: daily streak line, live/next event, roster
----------------------------------------------------------------------
local function schedule()
  local S = G.S
  local Fo = H.fonts
  local x, y, w = 840, 286, 416
  local now = os.date("*t")
  local left = 86400 - (now.hour * 3600 + now.min * 60 + now.sec)
  local canClaim = not G.dailyPending and S.daily.last ~= G.today()
  H.heading("SCHEDULE", x, y, w, C.line, nil, canClaim and "SUPPLY READY" or ("RESET IN " .. H.clock(left)))
  -- daily supply: seven stops on a short line
  y = y + 26
  H.card(x, y, w, 112, "DAILY SUPPLY  //  STREAK " .. S.daily.streak, canClaim and C.orange or C.line)
  local cur = canClaim and ((G.dailyNextStreak() - 1) % 7 + 1) or ((math.max(1, S.daily.streak) - 1) % 7 + 1)
  local lx0, lx1, ly = x + 30, x + w - 30, y + 54
  col(C.faint); lg.rectangle("fill", lx0, ly, lx1 - lx0, 2)
  local stepW = (lx1 - lx0) / 6
  local gotN = canClaim and (cur - 1) or cur
  if gotN > 1 then col(C.line, 0.8); lg.rectangle("fill", lx0, ly, stepW * (gotN - 1), 2) end
  for k, day in ipairs(D.DAILY) do
    local cx = lx0 + (k - 1) * stepW
    local got = (canClaim and k < cur) or (not canClaim and k <= cur)
    local isNext = canClaim and k == cur
    col(C.bg); diamond("fill", cx, ly + 1, 9)
    if isNext then col(C.orange); diamond("fill", cx, ly + 1, 7)
    elseif got then col(C.line); diamond("fill", cx, ly + 1, 6)
    else col(C.faint); diamond("line", cx, ly + 1, 6) end
    lg.setFont(Fo.xs); col(isNext and C.orange or (got and C.white or C.dim)); lg.printf(day.code, cx - 24, ly - 22, 48, "center")
    if H.mouseIn(cx - 24, ly - 24, 48, 48) then H.setTip("DAY " .. k .. " // " .. day.code, day.text) end
  end
  if canClaim then
    H.button(x + 14, y + 74, w - 28, 28, "CLAIM DAY " .. cur .. "  //  " .. D.DAILY[cur].text, true, G.claimDaily, C.orange, Fo.xs, nil, true)
  else
    H.label("Next supply: " .. D.DAILY[cur % 7 + 1].text .. "  //  in " .. H.clock(left), x + 14, y + 82, C.dim)
  end
  -- event: live or next
  y = y + 120
  local ev, ne = G.event, G.nextEvent
  local def = ev and ev.def or (ne and ne.def)
  local ec = def and C[def.col] or C.dim
  H.card(x, y, w, 104, ev and "EVENT LIVE" or "NEXT EVENT", ec, ev and (H.fmtTime(ev.t) .. " LEFT") or (ne and ("IN " .. H.fmtTime(ne.t)) or nil))
  if def then
    lg.setFont(Fo.d2); col(ec, ev and 1 or 0.8); lg.print(def.name, x + 14, y + 32)
    H.richf(def.desc, x + 14, y + 62, w - 28, "left", ev and C.white or C.dim, 1, Fo.xs)
    if ev then H.bar(x + 14, y + 92, w - 28, 3, ev.t / ev.dur, ec)
    elseif ne then H.label(H.clock(ne.t), x + w - 80, y + 36, C.white) end
  end
  -- roster: names only, details on hover
  y = y + 112
  local cw = (w - 8) / 2
  for k, e in ipairs(D.EVENTS) do
    local cx = x + ((k - 1) % 2) * (cw + 8)
    local cy = y + math.floor((k - 1) / 2) * 22
    local active = ev and ev.def.id == e.id
    local hov = H.mouseIn(cx, cy, cw, 20)
    col(C[e.col], active and 1 or (hov and 0.8 or 0.45)); lg.rectangle("fill", cx, cy + 6, 6, 6)
    lg.setFont(Fo.xs); col(active and C.white or (hov and C.line or C.dim)); lg.print(e.name, cx + 12, cy + 3)
    if hov then H.setTip(e.name, e.desc) end
  end
end

function Sc.draw()
  local Fo = H.fonts
  H.screenTitle("OPERATIONS")
  track()
  directives()
  schedule()
end

return Sc
