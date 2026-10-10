-- ARCHIVE: milestone track, claimable log entries, service record (collection + lifetime stats).
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local I = require "ui.icons"
local lg = V.lg
local C, col, fmt = H.C, H.col, H.fmt
local Sc = {}

local function milestones()
  local Fo = H.fonts
  local x, y, w = 24, 92, 1232
  local n = #D.ARCHIVE
  local nextA
  for _, a in ipairs(D.ARCHIVE) do if G.achCount < a.n then nextA = a break end end
  H.card(x, y, w, 92, nil, C.line)
  lg.setFont(Fo.s); col(C.white); lg.print("ARCHIVE MILESTONES", x + 14, y + 8)
  if nextA then
    lg.setFont(Fo.s); col(C.orange)
    H.richf("NEXT @ " .. nextA.n .. " LOGS: " .. nextA.text:upper(), x, y + 8, w - 14, "right", C.orange, 1, Fo.s)
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
    local s = isNext and 9 or 6
    col(got and C.orange or (isNext and C.white or C.faint))
    lg.polygon(got and "fill" or "line", mx, ly - s, mx + s, ly, mx, ly + s, mx - s, ly)
    if isNext or k % 3 == 1 or got and k == 1 then
      H.label(tostring(a.n), mx - 8, ly + 12, got and C.orange or C.dim)
    end
    if H.mouseIn(mx - 9, ly - 12, 18, 24) then
      H.setTip((got and "UNLOCKED" or "LOCKED") .. " // " .. a.n .. " LOGS", a.text)
    end
  end
  -- current position marker
  local cx = px(math.min(G.achCount, maxN))
  col(C.white); lg.polygon("fill", cx - 5, ly - 16, cx + 5, ly - 16, cx, ly - 9)
  H.label(G.achCount .. " LOGS", cx - 20, ly - 30, C.white)
end

local function logs()
  local S = G.S
  local Fo = H.fonts
  local x, w = 24, 852
  local top, bot = 232, 630
  local unclaimed = G.unclaimedLogs()
  lg.setFont(Fo.s); col(C.white); lg.print("LOG ENTRIES // " .. G.achCount .. " / " .. #D.ACH, x, 196)
  H.label("each unlocked entry: +1% output. claim for parts, hydro, and a token every 10 claims", x, 214, C.dim)
  H.button(x + w - 220, 192, 220, 32, unclaimed > 0 and ("CLAIM ALL REWARDS (" .. unclaimed .. ")") or "ALL REWARDS CLAIMED",
    unclaimed > 0, G.claimAllLogs, C.orange, Fo.xs, nil, unclaimed > 0)
  H.scrollRegion(x, top, w, bot - top, "archive")
  lg.setScissor(x - 2, top, w + 4, bot - top)
  local cell, gap = 60, 6
  local cols = math.floor((w + gap) / (cell + gap))
  local y0 = top - G.scroll.archive
  local clip = {top, bot}
  local rows = 0
  for i, a in ipairs(D.ACH) do
    local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
    rows = r + 1
    local cx, cy = x + c * (cell + gap), y0 + r * (cell * 0.8 + gap)
    local ch = cell * 0.8
    if cy + ch >= top and cy <= bot then
      local got = S.ach[i]
      local claim = got and not S.achClaim[i]
      local hov = H.mouseIn(cx, cy, cell, ch, clip)
      if claim then
        col(C.orange, 0.2 + 0.12 * math.sin(G.time * 5 + i)); lg.rectangle("fill", cx, cy, cell, ch)
        H.brackets(cx, cy, cell, ch, 5, C.orange)
        lg.setFont(Fo.s); col(C.white); lg.printf(a.code, cx, cy + 8, cell, "center")
        H.label("CLAIM", cx + cell / 2 - 14, cy + 28, C.orange)
        H.addHit(cx, cy, cell, ch, function() G.claimLog(i) end, clip)
      elseif got then
        col(C.line, hov and 0.25 or 0.1); lg.rectangle("fill", cx, cy, cell, ch)
        H.brackets(cx, cy, cell, ch, 5, C.line, 0.7)
        lg.setFont(Fo.s); col(C.white); lg.printf(a.code, cx, cy + 15, cell, "center")
      else
        col(C.faint, 0.5); lg.rectangle("line", cx + 0.5, cy + 0.5, cell - 1, ch - 1)
        lg.setFont(Fo.s); col(C.faint); lg.printf(a.code, cx, cy + 15, cell, "center")
      end
      if hov then
        local pa, hy = G.logReward(i)
        H.setTip((got and "" or "[LOCKED] ") .. a.name:upper(), a.desc .. "  //  reward +" .. pa .. " parts +" .. hy .. " hydro")
      end
    end
  end
  lg.setScissor()
  G.maxScroll.archive = math.max(0, rows * (cell * 0.8 + gap) - (bot - top))
end

local function record()
  local S = G.S
  local Fo = H.fonts
  local x, y, w = 892, 196, 364
  H.card(x, y, w, 196, "DRONE COLLECTION", C.line, "ALL-TIME")
  local maxC = 1
  for k = 1, 5 do maxC = math.max(maxC, S.rarityEver[k] or 0) end
  for k, r in ipairs(D.RARITY) do
    local ry = y + 34 + (k - 1) * 30
    local n = S.rarityEver[k] or 0
    local rc = C[r.col]
    H.droneIcon(x + 28, ry + 10, 0.55, n > 0 and rc or C.faint)
    lg.setFont(Fo.s); col(n > 0 and rc or C.faint); lg.print(r.name, x + 56, ry + 2)
    H.bar(x + 130, ry + 8, 170, 5, n / maxC, rc)
    lg.setFont(Fo.s); col(C.white); lg.printf(tostring(n), x, ry + 2, w - 14, "right")
  end
  y = y + 204
  H.card(x, y, w, 230, "SERVICE RECORD", C.line)
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
    local sy = y + 32 + (k - 1) * 17
    H.label(s[1], x + 14, sy, C.dim)
    lg.setFont(Fo.xs); col(C.white); lg.printf(s[2], x, sy, w - 14, "right")
  end
end

function Sc.draw()
  local Fo = H.fonts
  lg.setFont(Fo.l); col(C.white); lg.print("ARCHIVE", 24, 58)
  milestones()
  logs()
  record()
end

return Sc
