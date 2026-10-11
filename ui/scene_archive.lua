-- ARCHIVE: a codex, not a wall of codes. 378 log entries belong to ~45 series (Tap Count, Mothership Down...).
-- Top: the milestone line (what the next log unlocks). Left: the series index, each with its own progress
-- strip. Middle: the selected series as a ladder you can read: name, condition, reward, state.
-- Right: drone collection and service record.
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local I = require "ui.icons"
local lg = V.lg
local C, col, fmt, clamp = H.C, H.col, H.fmt, H.clamp
local Sc = {}

local function diamond(mode, x, y, r) lg.polygon(mode, x, y - r, x + r, y, x, y + r, x - r, y) end

-- series, in the order they first appear
local groups
local TITLES = {E = "RESERVE LEVEL", R = "FLOW RATE", U = "UNIT MASTERY"}
local function buildGroups()
  if groups then return groups end
  groups = {}
  local byCat = {}
  for i, a in ipairs(D.ACH) do
    local cat = a.code:match("^(%u+)")
    local g = byCat[cat]
    if not g then
      g = {cat = cat, title = TITLES[cat] or a.name:gsub("%s+%S+$", ""):upper(), ids = {}}
      byCat[cat] = g
      groups[#groups + 1] = g
    end
    g.ids[#g.ids + 1] = i
  end
  return groups
end

local function groupState(g)
  local S = G.S
  local got, claim = 0, 0
  for _, i in ipairs(g.ids) do
    if S.ach[i] then got = got + 1; if not S.achClaim[i] then claim = claim + 1 end end
  end
  return got, claim
end

local function pickDefault()
  local list = buildGroups()
  for k, g in ipairs(list) do local _, c = groupState(g); if c > 0 then return k end end
  for k, g in ipairs(list) do local got = groupState(g); if got < #g.ids then return k end end
  return 1
end

----------------------------------------------------------------------
local function milestones()
  local Fo = H.fonts
  local x, y, w = 24, H.HEAD.BODY_Y, 1232
  local n = #D.ARCHIVE
  local nextA
  for _, a in ipairs(D.ARCHIVE) do if G.achCount < a.n then nextA = a break end end
  H.card(x, y, w, 84, "MILESTONES  //  EVERY LOG IS +1% OUTPUT", C.line)
  if nextA then
    H.richf("NEXT AT " .. nextA.n .. " LOGS: " .. nextA.text:upper(), x, y + 8, w - 12, "right", C.orange, 1, Fo.xs)
  end
  local lx0, lx1, ly = x + 30, x + w - 30, y + 56
  col(C.faint); lg.rectangle("fill", lx0, ly - 1, lx1 - lx0, 2)
  local maxN = D.ARCHIVE[n].n
  local function px(v) return lx0 + (lx1 - lx0) * (v / maxN) ^ 0.6 end
  col(C.orange); lg.rectangle("fill", lx0, ly - 1, px(math.min(G.achCount, maxN)) - lx0, 2)
  for k, a in ipairs(D.ARCHIVE) do
    local mx = px(a.n)
    local got = G.achCount >= a.n
    local isNext = a == nextA
    local s = isNext and 8 or 5
    col(C.bg); diamond("fill", mx, ly, s + 2)
    col(got and C.orange or (isNext and C.white or C.faint))
    diamond(got and "fill" or "line", mx, ly, s)
    if isNext or k % 3 == 1 then H.label(tostring(a.n), mx - 8, ly + 11, got and C.orange or C.dim) end
    if H.mouseIn(mx - 9, ly - 12, 18, 24) then H.setTip((got and "UNLOCKED" or "LOCKED") .. " // " .. a.n .. " LOGS", a.text) end
  end
  local cx = px(math.min(G.achCount, maxN))
  col(C.white); lg.polygon("fill", cx - 5, ly - 15, cx + 5, ly - 15, cx, ly - 8)
  H.label(G.achCount .. " LOGS", cx - 20, ly - 28, C.white)
end

----------------------------------------------------------------------
local function index(list)
  local Fo = H.fonts
  local x, w, top, bot = 24, 296, 218, 630
  H.heading("SERIES", x, 192, w, C.line, nil, #list .. " SERIES")
  H.scrollRegion(x, top, w, bot - top, "archSeries")
  local clip = {top, bot}
  lg.setScissor(x - 4, top, w + 8, bot - top)
  local y = top - G.scroll.archSeries
  local rh = 34
  for k, g in ipairs(list) do
    if y + rh >= top and y <= bot then
      local got, claim = groupState(g)
      local sel = G.archSel == k
      local hov = H.mouseIn(x, y, w, rh - 4, clip)
      local t = H.hoverT(x, y, w, rh, hov or sel)
      col(C.panel, 0.6 + 0.3 * t); lg.rectangle("fill", x, y, w, rh - 4)
      if sel then col(C.line, 0.08); lg.rectangle("fill", x, y, w, rh - 4); col(C.white); lg.rectangle("fill", x, y + 4, 2, rh - 12) end
      local done = got == #g.ids
      lg.setFont(Fo.xs); col(sel and C.white or (got > 0 and C.line or C.dim))
      lg.print(H.fit(Fo.xs, g.title, w - 90), x + 10, y + 4)
      col(done and C.orange or C.dim); lg.printf(got .. "/" .. #g.ids, x, y + 4, w - 10, "right")
      if claim > 0 then
        col(C.orange); diamond("fill", x + w - 56, y + 10, 4)
      end
      -- one tick per entry in the series
      local n = #g.ids
      local sw = (w - 20 - (n - 1)) / n
      for j = 1, n do
        local i = g.ids[j]
        local on = G.S.ach[i]
        col(on and (G.S.achClaim[i] and C.line or C.orange) or C.faint, on and 0.9 or 0.6)
        lg.rectangle("fill", x + 10 + (j - 1) * (sw + 1), y + 20, math.max(1, sw), 4)
      end
      H.addHit(x, y, w, rh - 4, function() G.archSel = k; G.scroll.archDetail = 0; FX.play("tick", 1.4) end, clip)
    end
    y = y + rh
  end
  lg.setScissor()
  G.maxScroll.archSeries = math.max(0, #list * rh - (bot - top))
end

----------------------------------------------------------------------
local function detail(g)
  local S = G.S
  local Fo = H.fonts
  local x, w, top, bot = 336, 540, 246, 630
  local got, claim = groupState(g)
  lg.setFont(Fo.d3); col(C.white); lg.print(g.title, x, 190)
  H.label(got .. " OF " .. #g.ids .. " LOGGED" .. (claim > 0 and ("  //  " .. claim .. " REWARD" .. (claim > 1 and "S" or "") .. " WAITING") or ""),
    x, 212, claim > 0 and C.orange or C.dim)
  col(C.faint); lg.line(x, 234, x + w, 234)
  local unclaimed = G.unclaimedLogs()
  H.button(x + w - 200, 190, 200, 30, unclaimed > 0 and ("CLAIM ALL LOGS  //  " .. unclaimed) or "ALL CLAIMED",
    unclaimed > 0, G.claimAllLogs, C.orange, Fo.xs, nil, unclaimed > 0)
  H.scrollRegion(x, top, w, bot - top, "archDetail")
  local clip = {top, bot}
  lg.setScissor(x - 4, top, w + 8, bot - top)
  local rh = 48
  local y = top + 6 - G.scroll.archDetail
  -- the ladder: one line down the left, a node per entry
  local lx = x + 14
  local lastGot = 0
  for j, i in ipairs(g.ids) do if S.ach[i] then lastGot = j end end
  col(C.faint); lg.rectangle("fill", lx, y + rh / 2 - 6, 1, (#g.ids - 1) * rh)
  if lastGot > 1 then col(C.line, 0.7); lg.rectangle("fill", lx, y + rh / 2 - 6, 1, (lastGot - 1) * rh) end
  for j, i in ipairs(g.ids) do
    if y + rh >= top and y <= bot then
      local a = D.ACH[i]
      local on = S.ach[i]
      local open = on and not S.achClaim[i]
      local cy = y + rh / 2 - 6
      col(C.bg); diamond("fill", lx, cy, 8)
      if open then col(C.orange); diamond("fill", lx, cy, 6)
      elseif on then col(C.line); diamond("fill", lx, cy, 5)
      else col(C.faint); diamond("line", lx, cy, 5) end
      local tx = x + 34
      lg.setFont(Fo.s); col(on and C.white or C.dim); lg.print(H.fit(Fo.s, a.name:upper(), w - 200), tx, y)
      H.rich(H.fit(Fo.xs, a.desc, w - 200), tx, y + 18, on and C.dim or C.faint, 1, Fo.xs)
      local pa, hy = G.logReward(i)
      lg.setFont(Fo.xs); col(on and C.dim or C.faint)
      lg.printf("+" .. fmt(pa) .. " PARTS  +" .. fmt(hy) .. " H2O", x, y + 18, w - 96, "right")
      if open then
        H.button(x + w - 86, y + 2, 86, 26, "CLAIM", true, function() G.claimLog(i) end, C.orange, Fo.xs, clip, true)
      else
        lg.setFont(Fo.xs); col(on and C.line or C.faint); lg.printf(on and "LOGGED" or "LOCKED", x, y + 2, w - 8, "right")
      end
      if j < #g.ids then col(C.faint, 0.5); lg.line(tx, y + rh - 8, x + w, y + rh - 8) end
    end
    y = y + rh
  end
  lg.setScissor()
  G.maxScroll.archDetail = math.max(0, #g.ids * rh + 12 - (bot - top))
end

----------------------------------------------------------------------
local function record()
  local S = G.S
  local Fo = H.fonts
  local x, y, w = 892, 192, 364
  H.card(x, y, w, 196, "DRONE COLLECTION", C.line, "ALL-TIME")
  local maxC = 1
  for k = 1, #D.RARITY do maxC = math.max(maxC, S.rarityEver[k] or 0) end
  for k, r in ipairs(D.RARITY) do
    local ry = y + 34 + (k - 1) * 26
    local n = S.rarityEver[k] or 0
    local rc = C[r.col]
    H.droneIcon(x + 28, ry + 10, 0.55, n > 0 and rc or C.faint)
    lg.setFont(Fo.s); col(n > 0 and rc or C.faint); lg.print(r.name, x + 56, ry + 2)
    H.bar(x + 130, ry + 8, 170, 5, n / maxC, rc)
    lg.setFont(Fo.s); col(C.white); lg.printf(tostring(n), x, ry + 2, w - 14, "right")
  end
  y = y + 196 + H.HEAD.GUTTER
  H.card(x, y, w, 630 - y, "SERVICE RECORD", C.line)
  local day = math.floor((os.time() - (S.startTime or os.time())) / 86400) + 1
  local stats = {
    {"ENERGY HARVESTED", fmt(S.totalEarned)}, {"CORE TAPS", fmt(S.clicks)},
    {"SCAVS DESTROYED", fmt(S.kills)}, {"MOTHERSHIPS", fmt(S.bosses)},
    {"CRATES OPENED", fmt(S.crates)}, {"LEGENDARY / MYTHIC", S.legendary .. " / " .. S.mythic},
    {"SECTORS SECURED", fmt(S.claimsTotal)}, {"HIGHEST ZONE CLEARED", tostring(S.zoneBest)},
    {"REBOOTS", tostring(S.prestiges)}, {"SIGNALS INTERCEPTED", fmt(S.comets)},
    {"PLAY TIME", H.fmtTime(S.playTime)}, {"MISSION DAY // BEST STREAK", day .. " // " .. S.bestStreak},
  }
  for k, s in ipairs(stats) do
    local sy = y + 34 + (k - 1) * 16
    H.label(s[1], x + 14, sy, C.dim)
    lg.setFont(Fo.xs); col(C.white); lg.printf(s[2], x, sy, w - 14, "right")
  end
end

function Sc.draw()
  local Fo = H.fonts
  local list = buildGroups()
  if not G.archSel or not list[G.archSel] then G.archSel = pickDefault() end
  H.screenTitle("ARCHIVE", G.achCount .. " / " .. #D.ACH .. " LOGS")
  milestones()
  index(list)
  detail(list[G.archSel])
  record()
end

return Sc
