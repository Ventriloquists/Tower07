-- OPS: directives, daily supply, world events, Signal Track (season pass).
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local I = require "ui.icons"
local lg = V.lg
local C, col, fmt, clamp = H.C, H.col, H.fmt, H.clamp
local Sc = {}

local function directives()
  local S = G.S
  local Fo = H.fonts
  local x, w = 24, 600
  H.label("DIRECTIVES // " .. S.dirDone .. " COMPLETED", x, 84, C.white)
  local y = 100
  for i, d in ipairs(S.directives) do
    local prog = G.dirProgress(d)
    local done = prog >= d.target
    local h = 104
    local dc = d.priority and C.orange or C.line
    col(C.panel, 0.92); lg.rectangle("fill", x, y, w, h)
    if done then col(C.orange, 0.08 + 0.05 * math.sin(G.time * 5 + i)); lg.rectangle("fill", x, y, w, h) end
    H.brackets(x, y, w, h, 8, done and C.orange or dc)
    if d.priority then
      H.hatch(x, y, w, 20, C.orange, 0.3, 6)
      H.label("PRIORITY // TRIPLE REWARD", x + 12, y + 4, C.orange)
    else
      H.label(string.format("DIRECTIVE %02d", i), x + 12, y + 4, C.dim)
    end
    H.rich(H.fit(Fo.l, G.dirText(d), w - 220), x + 12, y + 24, done and C.white or C.line, 1, Fo.l)
    H.segbar(x + 12, y + 58, w - 220, 8, clamp(prog / d.target, 0, 1), 24, done and C.orange or C.line)
    H.label(fmt(math.max(0, math.min(prog, d.target))) .. " / " .. fmt(d.target), x + 12, y + 72, done and C.white or C.dim)
    H.label("REWARD  " .. G.rewardText(d), x + 12, y + 90, d.priority and C.orange or C.line)
    H.button(x + w - 190, y + 26, 176, 42, done and "CLAIM" or "IN PROGRESS", done, function() G.claimDirective(i) end,
      C.orange, Fo.m, nil, done)
    local cd = S.rerollAt - G.now()
    H.button(x + w - 190, y + 74, 176, 26, cd > 0 and ("REROLL IN " .. H.clock(cd):sub(4)) or "REROLL (FREE, 5 MIN CD)",
      cd <= 0 and not done, function() G.rerollDirective(i) end, C.dim, Fo.xs)
    y = y + h + 6
  end
end

local function daily()
  local S = G.S
  local Fo = H.fonts
  local x, y, w, h = 640, 84, 616, 120
  H.card(x, y, w, h, "DAILY SUPPLY // STREAK " .. S.daily.streak .. " DAYS", C.line,
    G.dailyPending and "READY" or ("NEXT IN " .. H.clock(86400 - (os.date("*t").hour * 3600 + os.date("*t").min * 60 + os.date("*t").sec))))
  local cur = G.dailyPending and ((G.dailyNextStreak() - 1) % 7 + 1) or ((math.max(1, S.daily.streak) - 1) % 7 + 1)
  local bw = (w - 24 - 6 * 6) / 7
  for k, day in ipairs(D.DAILY) do
    local bx, by = x + 12 + (k - 1) * (bw + 6), y + 32
    local isCur = k == cur
    local got = (not G.dailyPending and k <= cur) or (G.dailyPending and k < cur)
    if isCur and G.dailyPending then H.hatch(bx, by, bw, 76, C.orange, 0.3, 5) end
    if got then col(C.line, 0.12); lg.rectangle("fill", bx, by, bw, 76) end
    H.brackets(bx, by, bw, 76, 5, isCur and C.orange or (got and C.line or C.faint))
    lg.setFont(Fo.m); col(isCur and C.orange or (got and C.white or C.dim)); lg.printf(day.code, bx, by + 8, bw, "center")
    if got then I.draw("check", bx + bw / 2, by + 40, 7, C.line) end
    lg.setFont(Fo.xs); col(C.dim); lg.printf(day.text, bx + 2, by + 56, bw - 4, "center")
  end
end

local function events()
  local Fo = H.fonts
  local x, y, w, h = 640, 212, 616, 228
  local ev = G.event
  if ev then
    local ec = C[ev.def.col]
    H.card(x, y, w, h, "EVENT ACTIVE", ec, H.fmtTime(ev.t) .. " LEFT")
    H.hatch(x, y + 26, w, 90, ec, 0.1, 7)
    lg.setFont(Fo.dxl); col(ec); lg.printf(ev.def.name, x, y + 40, w, "center")
    H.richf(ev.def.desc, x, y + 82, w, "center", C.white, 1, Fo.s)
    H.bar(x + 40, y + 108, w - 80, 4, ev.t / ev.dur, ec)
  elseif G.nextEvent then
    local ne = G.nextEvent
    H.card(x, y, w, h, "NEXT EVENT", C.dim, "IN " .. H.fmtTime(ne.t))
    lg.setFont(Fo.dxl); col(C[ne.def.col], 0.85); lg.printf(ne.def.name, x, y + 40, w, "center")
    H.richf(ne.def.desc, x, y + 82, w, "center", C.dim, 1, Fo.s)
    lg.setFont(Fo.l); col(C.white); lg.printf(H.clock(ne.t), x, y + 102, w, "center")
  end
  -- all event types
  local cw = (w - 24 - 2 * 8) / 3
  for k, e in ipairs(D.EVENTS) do
    local cx = x + 12 + ((k - 1) % 3) * (cw + 8)
    local cy = y + 136 + math.floor((k - 1) / 3) * 44
    local active = ev and ev.def.id == e.id
    col(C[e.col], active and 0.2 or 0.05); lg.rectangle("fill", cx, cy, cw, 38)
    H.brackets(cx, cy, cw, 38, 4, C[e.col], active and 1 or 0.5)
    H.label(e.name, cx + 8, cy + 5, C[e.col])
    H.label(H.fit(Fo.xs, e.desc, cw - 14), cx + 8, cy + 20, C.dim)
  end
end

local function track()
  local S = G.S
  local Fo = H.fonts
  local x, y, w, h = 24, 444, 1232, 186
  local need = G.passNeed(S.passTier + 1)
  local ready = G.passReady()
  H.card(x, y, w, h, nil, ready > 0 and C.orange or C.line)
  lg.setFont(Fo.l); col(C.white); lg.print("SIGNAL TRACK", x + 14, y + 8)
  H.label("TIER " .. S.passTier .. "  //  " .. fmt(S.sxp) .. " / " .. fmt(need) .. " SXP  //  EARN SXP FROM EVERYTHING YOU DO",
    x + 200, y + 16, C.dim)
  H.bar(x + 14, y + 40, w - 340, 6, S.sxp / need, C.orange)
  if ready > 0 then
    H.button(x + w - 236, y + 10, 222, 36, "CLAIM ALL (" .. ready .. ")", true, G.claimAllPass, C.orange, Fo.m, nil, true)
  end
  -- tier nodes
  local nw, gap = 112, 8
  local visible = math.floor((w - 28 + gap) / (nw + gap))
  local first = G.passView or math.max(1, S.passClaimed + 1 - 2)
  first = math.max(1, first)
  G.passView = first
  local ny = y + 56
  for k = 0, visible - 1 do
    local t = first + k
    local nx = x + 14 + k * (nw + gap)
    local r = D.passReward(t)
    local rc = C[r.col] or C.line
    local claimed = t <= S.passClaimed
    local reached = t <= S.passTier
    local nextClaim = t == S.passClaimed + 1 and reached
    local hov = H.mouseIn(nx, ny, nw, 120)
    col(C.panel, 0.95); lg.rectangle("fill", nx, ny, nw, 120)
    if r.big then H.hatch(nx, ny, nw, 120, rc, reached and 0.15 or 0.06, 6) end
    if nextClaim then col(C.orange, 0.15 + 0.08 * math.sin(G.time * 6)); lg.rectangle("fill", nx, ny, nw, 120) end
    H.brackets(nx, ny, nw, 120, 6, nextClaim and C.orange or (reached and rc or C.faint), (reached or r.big) and 1 or 0.6)
    lg.setFont(Fo.s); col(reached and C.white or C.dim); lg.printf("TIER " .. t, nx, ny + 8, nw, "center")
    local icon = r.icon or "crate"
    I.draw(icon, nx + nw / 2, ny + 50, r.big and 14 or 11, reached and rc or C.faint)
    lg.setFont(Fo.xs); col(reached and rc or C.dim)
    lg.printf(H.fit(Fo.xs, r.big and r.text:gsub(" CRATE", "") or r.text, nw - 8), nx + 4, ny + 76, nw - 8, "center")
    if claimed then
      I.draw("check", nx + nw / 2, ny + 104, 7, C.line)
    elseif nextClaim then
      lg.setFont(Fo.xs); col(C.orange); lg.printf("CLAIM", nx, ny + 98, nw, "center")
      H.addHit(nx, ny, nw, 120, G.claimPass)
    elseif reached then
      H.label("READY", nx + nw / 2 - 16, ny + 98, rc)
    else
      H.label(t == S.passTier + 1 and (math.floor(S.sxp / need * 100) .. "%") or "LOCKED", nx + nw / 2 - 18, ny + 98, C.faint)
    end
    if hov then H.setTip("TIER " .. t, r.text .. (claimed and " // CLAIMED" or (reached and " // READY" or ""))) end
  end
  H.scrollRegion(x, ny, w, 120, "passView", true)
  -- paging (mouse wheel works too)
  H.button(x + w - 316, y + 12, 34, 30, "<", first > 1, function() G.passView = math.max(1, first - visible) end, C.dim, Fo.s)
  H.button(x + w - 276, y + 12, 34, 30, ">", true, function() G.passView = first + visible end, C.dim, Fo.s)
end

function Sc.draw()
  local Fo = H.fonts
  lg.setFont(Fo.d2); col(C.white); lg.print("OPERATIONS", 24, 54)
  directives()
  daily()
  events()
  track()
end

return Sc
