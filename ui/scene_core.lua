-- CORE: the home screen. Reactor centerpiece, objectives tracker, reactor status, quick-build hotbar.
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local I = require "ui.icons"
local Reactor = require "ui.reactor"
local lg = V.lg
local C, col, fmt, clamp = H.C, H.col, H.fmt, H.clamp
local Sc = {}

-- buy the best-value units until the energy runs out
function G.smartBuy()
  local S = G.S
  local bought = 0
  for _ = 1, 500 do
    local best, bs
    for i = 1, #D.GENS do
      if G.revealedGen(i) then
        local c = G.genCost(i, 1)
        if c <= S.stardust then
          local sc = c / math.max(G.genEach[i], 1e-300)
          if not bs or sc < bs then best, bs = i, sc end
        end
      end
    end
    if not best then break end
    G.buyGenN(best, 1, true)
    bought = bought + 1
    if bought % 25 == 0 then G.recalc() end
  end
  G.recalc()
  if bought == 0 then FX.play("err") return end
  local mx, my = V.mouse()
  FX.burst(mx, my, 20 + math.min(bought, 60), C.line, 260)
  FX.floater(mx, my - 20, "+" .. bought .. " UNITS", C.white, H.fonts.m, 1.2)
  FX.play("buy", 1.2)
end

----------------------------------------------------------------------
local function hero()
  local Fo = H.fonts
  -- hero readout: kicker label, the big number in the display face, the rate underneath
  local hud = H.isHud()
  if hud then
    lg.setFont(Fo.xs); col(C.dim); lg.printf("STORED ENERGY", 340, 58, 600, "center")
  end
  lg.setFont(Fo.huge); col(C.white)
  lg.printf(fmt(G.dispDust), 340, hud and 66 or 58, 600, "center")
  local boosted = G.buffMult("prod") > 1
  lg.setFont(Fo.m); col(boosted and C.orange or C.line)
  lg.printf("+" .. fmt(G.getCps()) .. " ENERGY / SEC", 340, hud and 128 or 114, 600, "center")
  -- reactor saturation warning: output is being throttled until you reboot
  local sat = G.satMult()
  local sy = hud and 150 or 134
  if sat < 0.999 then
    local pct = sat * 100
    local txt = "REACTOR SATURATION  //  OUTPUT AT " .. (pct >= 1 and string.format("%d%%", pct) or (pct >= 0.01 and string.format("%.2g%%", pct) or "<0.01%")) .. "  //  REBOOT TO RESET"
    local pulse = 0.6 + 0.4 * math.sin(G.time * 4)
    local tw = Fo.xs:getWidth(txt) + 24
    local hov = H.mouseIn(640 - tw / 2, sy, tw, 18)
    col(C.red, (hov and 0.35 or 0.18) * pulse + 0.05); lg.rectangle("fill", 640 - tw / 2, sy, tw, 18)
    if hud then col(C.red); lg.rectangle("fill", 640 - tw / 2, sy, 3, 18) end
    lg.setFont(Fo.xs); col(C.red); lg.printf(txt, 640 - tw / 2, sy + 3, tw, "center")
    if hov then H.setTip("REACTOR SATURATION", "This run has outgrown the reactor: a reboot now would at least double your Core Data. Output falls in proportion to how far past that line you are (twice past = half output), so pushing on stops paying. Rebooting resets it and raises the line.") end
    H.addHit(640 - tw / 2, sy, tw, 18, function() if G.unlocked("nova") then G.tab = "nova"; FX.play("tap", 1.6, 0.4) end end)
    sy = sy + 24
  else
    sy = sy + 4
  end
  -- buff chips
  local n = #G.buffs
  local cw = 156
  local x = 640 - (n * cw + (n - 1) * 8) / 2
  for _, b in ipairs(G.buffs) do
    local bc = b.kind == "click" and C.red or C.orange
    if b.name == "GOLDEN HOUR" then bc = C.gold end
    col(C.panel, 0.9); lg.rectangle("fill", x, sy, cw, 26)
    col(bc, 0.15); lg.rectangle("fill", x, sy, cw, 26)
    H.brackets(x, sy, cw, 26, 5, bc)
    lg.setFont(Fo.xs); col(bc); lg.print(H.fit(Fo.xs, b.name, 90), x + 8, sy + 3)
    col(C.white); lg.printf("x" .. b.mult .. " " .. math.ceil(b.t) .. "s", x, sy + 3, cw - 8, "right")
    H.bar(x + 8, sy + 19, cw - 16, 2, b.t / b.dur, bc)
    x = x + cw + 8
  end
end

----------------------------------------------------------------------
-- ACTION STACK: everything that wants you, in one place. Instant rewards collapse into one command
-- (COLLECT ALL, key C); things that need a decision or a trip are rows with GO; then what is coming next.
----------------------------------------------------------------------
local function stackRow(g, x, y, w, h)
  local Fo = H.fonts
  local gc = g.c or C.line
  local hov = H.mouseIn(x, y, w, h)
  local t = H.hoverT(x, y, w, h, hov)
  col(C.panel, 0.9); lg.rectangle("fill", x, y, w, h)
  col(gc, 0.05 + 0.06 * t); lg.rectangle("fill", x, y, w, h)
  col(gc, 0.9); lg.rectangle("fill", x, y + 6, 2, h - 12)
  I.draw(g.icon, x + 18, y + h / 2, 7, gc)
  local tw = w - 112
  H.rich(H.fit(Fo.s, g.title, tw), x + 34, y + 5, C.white, 1, Fo.s)
  H.rich(H.fit(Fo.xs, g.text, tw), x + 34, y + 23, C.dim, 1, Fo.xs)
  H.button(x + w - 70, y + (h - 24) / 2, 62, 24, g.claim and g.label or "GO  >", true, g.fn, gc, Fo.xs, nil, false)
end

local function actionStack()
  local Fo = H.fonts
  local x, w = 24, 300
  local goals = G.goals()
  local ready, next = {}, {}
  for _, g in ipairs(goals) do if g.ready then ready[#ready + 1] = g else next[#next + 1] = g end end
  local claims = #G.collectables()
  H.heading("ACTION STACK", x, 60, w, C.line, nil, #ready > 0 and (#ready .. " WAITING") or "ALL CLEAR")
  -- the master command
  local busy = #G.cascade > 0
  local label = busy and ("COLLECTING  //  " .. #G.cascade .. " LEFT") or
    (claims > 0 and ("COLLECT ALL  //  " .. claims .. "   [C]") or "NOTHING TO COLLECT")
  H.button(x, 86, w, 40, label, claims > 0 and not busy, G.collectAll, C.orange, Fo.m, nil, claims > 0 and not busy)
  if H.mouseIn(x, 86, w, 40) then
    H.setTip("COLLECT ALL  [C]", "Claims every instant reward at once: daily supply, log rewards, Signal Track tiers, finished directives and rigs at peak. Works from any screen.")
  end
  local y = 134
  local bottom = 506
  -- rows that need you (claims are folded into COLLECT ALL; still listed so you know what you get)
  local shown = 0
  for _, g in ipairs(ready) do
    if y + 42 > bottom - 70 then break end
    stackRow(g, x, y, w, 40)
    y = y + 44
    shown = shown + 1
  end
  if shown < #ready then
    H.label("+" .. (#ready - shown) .. " MORE", x + 2, y - 2, C.dim)
    y = y + 12
  end
  if #ready == 0 then
    -- empty state: say so plainly, with the next thing to aim for
    col(C.panel, 0.6); lg.rectangle("fill", x, y, w, 40)
    H.label("NOTHING WAITING. THE TOWER IS HARVESTING.", x + 12, y + 8, C.dim)
    H.label("Tap the core or build units to speed it up.", x + 12, y + 22, C.faint)
    y = y + 48
  end
  -- what is next: compact progress lines
  y = y + 6
  lg.setFont(Fo.xs); col(C.dim); lg.print("NEXT UP", x, y)
  col(C.faint); lg.line(x + 52, y + 7, x + w, y + 7)
  y = y + 18
  for _, g in ipairs(next) do
    if y + 28 > bottom then break end
    local hov = g.fn and H.mouseIn(x, y, w, 26)
    H.rich(H.fit(Fo.xs, g.title, w - 50), x, y, hov and C.white or C.line, 1, Fo.xs)
    lg.setFont(Fo.xs); col(C.dim); lg.printf(math.floor(clamp(g.prog or 0, 0, 1) * 100) .. "%", x, y, w, "right")
    H.bar(x, y + 16, w, 3, g.prog or 0, g.c or C.line)
    if g.fn then H.addHit(x, y, w, 26, g.fn) end
    if hov then H.setTip(g.title, g.text) end
    y = y + 30
  end
end

----------------------------------------------------------------------
-- right column: tap telemetry, PRODUCTION FLOW (where the energy actually comes from), rigs, signal track
----------------------------------------------------------------------
local hist, histT = {}, -1
local function sample()
  local now = love.timer.getTime()
  if now - histT < 1 then return end
  histT = now
  hist[#hist + 1] = G.getCps()
  if #hist > 60 then table.remove(hist, 1) end
end

local function telemetry(x, y, w)
  local Fo = H.fonts
  local h = 58
  H.card(x, y, w, h, nil, C.line)
  local surging = G.hasBuff("CORE SURGE")
  local cw = w / 3
  local cols = {
    {"CORE SURGE", surging and "x3 LIVE" or (math.floor(G.surge * 100) .. "%"), surging and C.orange or C.white,
      "Tap fast to fill the orange ring. Full = output x3 for 15s."},
    {"TAP CHAIN", string.format("x%.2f", 1 + math.min(G.combo, 200) * 0.005), G.combo > 1 and C.red or C.white,
      "Tapping fast builds the red ring: up to x2 tap power. Breaks after 1.2s without a tap. Crits: 4% for x10."},
    {"PER TAP", "+" .. fmt(G.tapValue()), C.white,
      "Energy per tap. Auto-tap: " .. (G.autoRate > 0 and (fmt(G.autoRate) .. " taps/s") or "none (tech: SERVOS)") .. "."},
  }
  for k, c in ipairs(cols) do
    local cx = x + (k - 1) * cw
    if k > 1 then col(C.faint); lg.line(cx, y + 10, cx, y + h - 10) end
    H.label(c[1], cx + 12, y + 9, C.dim)
    lg.setFont(Fo.m); col(c[3]); lg.print(H.fit(Fo.m, c[2], cw - 16), cx + 12, y + 24)
    if H.mouseIn(cx, y, cw, h) then H.setTip(c[1], c[4]) end
  end
  H.bar(x + 12, y + h - 8, cw - 24, 2, surging and 1 or G.surge, C.orange)
  H.bar(x + cw + 12, y + h - 8, cw - 24, 2, math.min(G.combo, 200) / 200, C.red)
  return y + h
end

local function production(x, y, w)
  local S = G.S
  local Fo = H.fonts
  local h = 190
  H.card(x, y, w, h, "PRODUCTION FLOW", C.line, "OUTPUT x" .. fmt(G.globalMult))
  -- 60 second history, log scale: shows growth, saturation and buffs at a glance
  local gx, gy, gw, gh = x + 12, y + 32, w - 24, 50
  col(C.faint, 0.5)
  for k = 1, 3 do lg.line(gx, gy + gh * k / 4, gx + gw, gy + gh * k / 4) end
  if #hist >= 2 then
    local lo, hi = math.huge, -math.huge
    for _, v in ipairs(hist) do local l = math.log10(math.max(v, 1)); lo = math.min(lo, l); hi = math.max(hi, l) end
    if hi - lo < 0.05 then lo, hi = lo - 0.05, hi + 0.05 end
    local pts = {}
    for i, v in ipairs(hist) do
      pts[#pts + 1] = gx + (i - 1) / 59 * gw
      pts[#pts + 1] = gy + gh - (math.log10(math.max(v, 1)) - lo) / (hi - lo) * gh
    end
    col(C.line, 0.08)
    for i = 1, #pts - 3, 2 do
      lg.polygon("fill", pts[i], pts[i + 1], pts[i + 2], pts[i + 3], pts[i + 2], gy + gh, pts[i], gy + gh)
    end
    col(C.line, 0.9); lg.setLineWidth(1.5); lg.line(pts); lg.setLineWidth(1)
    col(C.white); lg.rectangle("fill", pts[#pts - 1] - 2, pts[#pts] - 2, 4, 4)
  else
    H.label("SAMPLING...", gx, gy + gh / 2 - 6, C.faint)
  end
  H.label("60S", gx, gy + gh + 3, C.faint)
  lg.setFont(Fo.xs); col(C.dim); lg.printf("NOW " .. fmt(G.getCps()) .. "/S", gx, gy + gh + 3, gw, "right")
  -- share of output per unit type
  local parts, total = {}, 0
  for i = 1, #D.GENS do
    local v = (S.gens[i] or 0) > 0 and (G.genEach[i] or 0) * S.gens[i] or 0
    if v > 0 then parts[#parts + 1] = {i = i, v = v}; total = total + v end
  end
  table.sort(parts, function(a, b) return a.v > b.v end)
  local by = gy + gh + 22
  col(C.faint, 0.6); lg.rectangle("fill", gx, by, gw, 8)
  if total > 0 then
    local cx = gx
    for k, p in ipairs(parts) do
      local pw = p.v / total * gw
      col(C.line, math.max(0.18, 1 - (k - 1) * 0.22)); lg.rectangle("fill", cx, by, math.max(0, pw - 1), 8)
      cx = cx + pw
    end
    local ry = by + 16
    for k = 1, math.min(3, #parts) do
      local p = parts[k]
      local g = D.GENS[p.i]
      col(C.line, math.max(0.18, 1 - (k - 1) * 0.22)); lg.rectangle("fill", gx, ry + 4, 6, 6)
      lg.setFont(Fo.xs); col(C.white); lg.print(H.fit(Fo.xs, g.name:upper(), 140), gx + 12, ry)
      col(C.dim); lg.printf(fmt(p.v) .. "/S", gx, ry, gw - 40, "right")
      col(C.line); lg.printf(math.floor(p.v / total * 100 + 0.5) .. "%", gx, ry, gw, "right")
      ry = ry + 16
    end
  else
    H.label("No units yet. Build one below.", gx, by + 16, C.dim)
  end
  if H.mouseIn(x, y, w, h) then
    H.setTip("PRODUCTION FLOW", "Top: energy per second over the last minute (log scale). Bar: each unit type's share of your output. Click to open BUILD.")
  end
  H.addHit(x, y, w, h, function() if G.unlocked("build") then G.tab = "build"; FX.play("tap", 1.6, 0.4) end end)
  return y + h
end

local function status()
  local S = G.S
  local Fo = H.fonts
  local x, w = 956, 300
  H.heading("TELEMETRY", x, 60, w, C.line)
  local y = telemetry(x, 86, w) + 6
  y = production(x, y, w) + 6
  -- rigs: one line each
  local rh = 30 + #S.rigs * 18
  H.card(x, y, w, rh, "HYDRO RIGS", C.line, fmt(math.floor(S.hydro)) .. " H2O")
  for i, r in ipairs(S.rigs) do
    local ry = y + 30 + (i - 1) * 18
    H.label("R" .. i, x + 12, ry, C.white)
    if r.on then
      local f = clamp(r.tank / G.rigCap(i), 0, 1)
      local full = f >= 1
      H.bar(x + 34, ry + 5, 150, 4, f, full and C.orange or C.line)
      lg.setFont(Fo.xs); col(full and C.orange or C.dim); lg.print(math.floor(f * 100) .. "%", x + 190, ry)
      if G.unlocked("rigs") and r.tank >= 1 then
        local hov = H.mouseIn(x + w - 74, ry - 2, 62, 16)
        lg.setFont(Fo.xs); col(full and C.orange or (hov and C.white or C.line))
        lg.printf(full and "PEAK  >" or "COLLECT", x + w - 74, ry, 62, "right")
        H.addHit(x + w - 74, ry - 2, 62, 16, function() G.collectRig(i) end)
      end
    else
      H.label("OFFLINE // RESTORE IN RIGS", x + 34, ry, C.faint)
    end
  end
  y = y + rh + 6
  local need = G.passNeed(S.passTier + 1)
  local ready = G.passReady()
  if y + 56 <= 512 then
    H.card(x, y, w, 56, "SIGNAL TRACK // TIER " .. S.passTier, ready > 0 and C.orange or C.line, ready > 0 and (ready .. " READY") or nil)
    H.bar(x + 12, y + 32, w - 24, 4, S.sxp / need, C.orange)
    H.label("NEXT: " .. D.passReward(S.passTier + 1).text, x + 12, y + 40, C.dim)
    if ready > 0 then H.addHit(x, y, w, 56, G.claimPass) end
  end
end

----------------------------------------------------------------------
local function quickBuild()
  local S = G.S
  local Fo = H.fonts
  local y, h = 534, 96
  -- choose 5 units: affordable ones first (most advanced), then the cheapest out-of-reach ones
  local can, cannot = {}, {}
  for i = #D.GENS, 1, -1 do
    if G.revealedGen(i) then
      if S.stardust >= G.genCost(i, 1) then can[#can + 1] = i else cannot[#cannot + 1] = i end
    end
  end
  table.sort(cannot, function(a, b) return G.genCost(a, 1) < G.genCost(b, 1) end)
  local ids = {}
  for _, i in ipairs(can) do if #ids < 5 then ids[#ids + 1] = i end end
  for _, i in ipairs(cannot) do if #ids < 5 then ids[#ids + 1] = i end end
  table.sort(ids)
  local nextLocked
  for i = 1, #D.GENS do if not G.revealedGen(i) then nextLocked = i break end end
  H.label("QUICK BUILD // HOLD TO KEEP BUYING", 24, y - 16, C.dim)
  for k = 1, 5 do
    local x, w = 24 + (k - 1) * 196, 188
    local i = ids[k]
    if i then
      local g = D.GENS[i]
      local nb = G.buyCount(i)
      local cost = G.genCost(i, nb)
      local can = S.stardust >= cost
      local hov = H.mouseIn(x, y, w, h)
      local t = H.hoverT(x, y, w, h, hov)
      col(C.panel, 0.92); lg.rectangle("fill", x, y, w, h)
      if can then col(C.line, 0.05); lg.rectangle("fill", x, y, w, h) end
      col(C.white, 0.05 * t); lg.rectangle("fill", x, y, w, h)
      if H.isHud() then
        col(can and C.line or C.faint, can and (0.3 + 0.5 * t) or 0.8); lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
      else
        H.brackets(x, y, w, h, 8, can and (hov and C.white or C.line) or C.faint)
      end
      col(can and C.line or C.faint); lg.rectangle("line", x + 10, y + 10, 38, 38)
      lg.setFont(Fo.xs); col(can and C.white or C.dim); lg.printf(g.code, x + 10, y + 23, 38, "center")
      lg.setFont(Fo.s); col(can and C.white or C.dim); lg.print(H.fit(Fo.s, g.name:upper(), w - 66), x + 56, y + 9)
      H.label("+" .. fmt(G.genEach[i]) .. "/S EACH", x + 56, y + 29, C.dim)
      lg.setFont(Fo.l); col(C.white); lg.printf("x" .. S.gens[i], x, y + 50, w - 10, "right")
      H.label(nb > 1 and ("BUY " .. nb) or "BUY", x + 10, y + 56, C.dim)
      lg.setFont(Fo.s); col(can and C.orange or C.dim); lg.print(fmt(cost), x + 10, y + 70)
      local ms, prev = G.nextMilestone(i)
      if ms then H.bar(x + 10, y + h - 8, w - 20, 3, (S.gens[i] - prev) / (ms - prev), C.orange) end
      H.addHit(x, y, w, h, function(mx, my) G.buyGen(i, mx, my) end, nil, true)
    elseif nextLocked and k == #ids + 1 then
      col(C.panel, 0.7); lg.rectangle("fill", x, y, w, h)
      H.hatch(x, y, w, h, C.red, 0.12, 7)
      H.brackets(x, y, w, h, 8, C.red, 0.6)
      lg.setFont(Fo.s); col(C.red); lg.print("SIGNAL LOCKED", x + 12, y + 12)
      H.label("Harvest " .. fmt(D.GENS[nextLocked].cost * 0.4), x + 12, y + 36, C.red)
      H.label("energy this cycle to decrypt", x + 12, y + 50, C.dim)
    end
  end
  -- buy mode + smart buy
  local bx = 1016
  local labels = {}
  for k, m in ipairs(G.BUYMODES) do labels[k] = m == "MAX" and "MAX" or ("x" .. m) end
  H.segmented(bx, y, 240, 24, labels, G.buyMode, function(k) G.buyMode = k; FX.play("tick", 1.4) end, "buymode")
  local anyCan = false
  for i = 1, #D.GENS do if G.revealedGen(i) and S.stardust >= G.genCost(i, 1) then anyCan = true break end end
  local autoOk, need = G.hasArchive("autoUnits")
  H.button(bx, y + 30, 176, h - 30, "SMART BUY", anyCan, G.smartBuy, C.line, Fo.l, nil, true)
  H.label("best value units", bx + 42, y + h - 18, anyCan and C.bg or C.faint)
  local on = S.autoUnits and autoOk
  H.button(bx + 182, y + 30, 58, h - 30, autoOk and (on and "AUTO ON" or "AUTO") or (need .. " LOGS"), autoOk,
    function() S.autoUnits = not S.autoUnits; FX.play("tick", 1.2) end, on and C.orange or C.dim, Fo.xs, nil, on)
  if H.mouseIn(bx + 182, y + 30, 58, h - 30) then
    H.setTip("AUTO-ACQUIRE", autoOk and "Keeps buying the best-value units for you, so you never have to spam SMART BUY." or ("Unlocks at " .. need .. " log entries."))
  end
end

function Sc.draw()
  Reactor.draw()
  hero() -- over the reactor: the readout must never sink behind the instrument
  sample()
  actionStack()
  status()
  quickBuild()
end

return Sc
