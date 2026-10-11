-- LOOT FIESTA screen: setup -> card-flip pulls -> fusion cascade -> summary.
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local lg = V.lg
local C, col, fmt = H.C, H.col, H.fmt
local TAU = math.pi * 2
local Fi = {}

local X0, Y0, W, HH = 50, 70, 1180, 572
local GX, GY, GW, GH = X0 + 20, Y0 + 60, 800, 440   -- pull grid / cascade area
local PX, PW = X0 + 840, 320                         -- right info panel
local RAR = D.RARITY
local function rc(r) return C[RAR[r].col] end

local function close() G.fiesta = nil; FX.play("tick", 0.8) end

local function rays(x, y, c, a, n)
  lg.setBlendMode("add")
  for k = 0, n - 1 do
    local an = G.time * 0.2 + k / n * TAU
    col(c, a)
    lg.polygon("fill", x, y, x + math.cos(an - 0.08) * 900, y + math.sin(an - 0.08) * 900,
      x + math.cos(an + 0.08) * 900, y + math.sin(an + 0.08) * 900)
  end
  lg.setBlendMode("alpha")
end

local function frame(title, sub, c)
  local x0, y0, x1, y1 = V.extents()
  col(C.bg, 0.92); lg.rectangle("fill", x0, y0, x1 - x0, y1 - y0)
  col(C.panel, 0.98); lg.rectangle("fill", X0, Y0, W, HH)
  lg.push("all"); lg.intersectScissor(X0, Y0, W, HH); rays(640, Y0 + HH / 2, c, 0.025, 14); lg.pop()
  H.hatch(X0, Y0, W, 40, c, 0.14, 7)
  H.brackets(X0, Y0, W, HH, 16, c)
  lg.setFont(H.fonts.l); col(c); lg.print(title, X0 + 18, Y0 + 7)
  H.label(sub, X0 + 30 + H.fonts.l:getWidth(title), Y0 + 15, C.dim)
end

local function miniCard(d, x, y, w, h, tag)
  local c = rc(d.r)
  col(C.panel, 0.98); lg.rectangle("fill", x, y, w, h)
  if d.r >= 3 then H.hatch(x + 6, y + 2, w - 12, 4, c, 0.8, 4) else col(c, 0.8); lg.rectangle("fill", x + 6, y + 2, w - 12, 3) end
  H.brackets(x, y, w, h, 5, c)
  H.droneIcon(x + 18, y + h / 2 + 2, 0.5, c)
  lg.setFont(H.fonts.xs); col(C.white); lg.print(H.fit(H.fonts.xs, d.name or "", w - 44), x + 36, y + 9)
  col(c); lg.print(RAR[d.r].name .. " LV" .. d.lvl, x + 36, y + 23)
  if tag then lg.setFont(H.fonts.xs); col(C.gold); lg.printf(tag, x, y + 23, w - 6, "right") end
end

----------------------------------------------------------------------
-- SETUP
----------------------------------------------------------------------
local function setup(f)
  local S, Fo, o = G.S, H.fonts, G.fiestaOpt
  frame("LOOT FIESTA", "MASS FABRICATION  //  THE BEST OF EVERY 3 CANDIDATES IS KEPT AUTOMATICALLY", C.orange)
  -- size tiles
  local sizes = {10, 25, 50, 100, 0}
  local tw, th, ty = 196, 170, Y0 + 70
  for k, n in ipairs(sizes) do
    local x = X0 + 30 + (k - 1) * (tw + 22)
    local real = n == 0 and G.fiestaMax(o.tokens) or n
    local h, tok = G.fiestaCost(real, o.tokens)
    local ok = real > 0 and S.hydro >= h
    local on = o.n == n
    local c = n == 0 and C.gold or (n >= 50 and C.red or C.orange)
    local hov = H.mouseIn(x, ty, tw, th)
    col(c, on and 0.16 or (hov and 0.08 or 0.03)); lg.rectangle("fill", x, ty, tw, th)
    if on then H.hatch(x, ty, tw, 8, c, 0.8, 5) end
    H.brackets(x, ty, tw, th, 10, c, on and 1 or 0.5)
    lg.setFont(Fo.huge); col(ok and C.white or C.dim)
    lg.printf(n == 0 and "MAX" or ("x" .. n), x, ty + 18, tw, "center")
    lg.setFont(Fo.s); col(c)
    lg.printf(n == 0 and ("x" .. real .. " AFFORDABLE") or ("+" .. G.fiestaBonus(n) .. " BONUS PULL" .. (G.fiestaBonus(n) > 1 and "S" or "")), x, ty + 86, tw, "center")
    if n == 0 and real > 0 then lg.printf("+" .. G.fiestaBonus(real) .. " BONUS", x, ty + 104, tw, "center") end
    lg.setFont(Fo.xs); col(ok and C.line or C.red)
    lg.printf(fmt(h) .. " H2O" .. (tok > 0 and ("  +" .. tok .. " TOKENS") or ""), x, ty + 128, tw, "center")
    col(C.dim); lg.printf(real >= 10 and (math.floor(real / 10) .. "x ELITE+ GUARANTEED") or "NO GUARANTEE", x, ty + 146, tw, "center")
    H.addHit(x, ty, tw, th, function() o.n = n; FX.play("tick", 1 + k * 0.1) end)
  end
  -- options
  local oy = ty + th + 30
  local function toggle(x, y, label, on, fn, desc)
    H.button(x, y, 260, 34, label .. (on == nil and "" or (on and " // ON" or " // OFF")), true, fn, on == false and C.dim or C.orange, Fo.xs)
    H.label(desc, x + 272, y + 10, C.dim)
  end
  toggle(X0 + 30, oy, "USE FAB TOKENS (" .. S.tokens .. ")", o.tokens, function() o.tokens = not o.tokens; FX.play("tick") end,
    "Tokens pay for the most expensive pulls first.")
  toggle(X0 + 30, oy + 44, "AUTO-FUSE // " .. G.autoFuseLabel(), nil, G.cycleAutoFuse,
    "Fuses every 3 drones of one rarity into the next, up to this rarity. Also runs in the hangar.")
  toggle(X0 + 30, oy + 88, "FUSE IDLE FLEET TOO", o.fleet, function() o.fleet = not o.fleet; FX.play("tick") end,
    "Unlocked idle or hunting fleet drones join the fusion cascade. Lock favourites in the hangar.")
  local space = G.bayCap() - #S.drones - #G.choiceQueue
  H.label("BAY " .. #S.drones .. " / " .. G.bayCap() .. "  //  " .. math.max(0, space) .. " FREE  //  overflow is recycled into parts",
    X0 + 30, oy + 140, space > 0 and C.line or C.red)
  H.label("FIESTAS RUN " .. (S.fiestas or 0) .. "   //   DRONES PULLED " .. fmt(S.fiestaPulls or 0) .. "   //   BEST FUSION CHAIN " .. (S.bestChain or 0),
    X0 + 30, oy + 158, C.dim)
  -- start
  local n = G.fiestaSize()
  local h = G.fiestaCost(n, o.tokens)
  local ok = n > 0 and S.hydro >= h
  local bx, by = X0 + W - 330, Y0 + HH - 120
  local pulse = 0.5 + 0.5 * math.sin(G.time * 5)
  if ok then col(C.orange, 0.1 + 0.12 * pulse); lg.rectangle("fill", bx - 8, by - 8, 316, 76) end
  H.button(bx, by, 300, 60, ok and ("START FIESTA // x" .. n + G.fiestaBonus(n)) or "NOT ENOUGH HYDRO", ok,
    G.startFiesta, C.orange, Fo.l, nil, ok)
  H.button(bx + 180, by - 44, 120, 30, "CLOSE", true, close, C.dim, Fo.xs)
end

----------------------------------------------------------------------
-- PULLS
----------------------------------------------------------------------
local function gridLayout(total)
  -- pick the column count that gives the tallest cards (aspect around 5:4)
  local gap, best = 6
  for cols = 4, 14 do
    local rows = math.ceil(total / cols)
    local cw = (GW - (cols - 1) * gap) / cols
    local ch = math.min(cw * 0.8, (GH - (rows - 1) * gap) / rows)
    if not best or ch > best[3] + 0.5 then best = {cols, math.min(cw, ch * 1.5), ch} end
  end
  return best[1], best[2], best[3], gap
end
local function cardPos(k, total)
  local cols, cw, ch, gap = gridLayout(total)
  local c, r = (k - 1) % cols, math.floor((k - 1) / cols)
  return GX + c * (cw + gap), GY + r * (ch + gap), cw, ch
end

local HOLD = {0, 0, 0.3, 1.0, 2.0, 3.2}
local function revealNext(f)
  f.shown = f.shown + 1
  local p = f.pulls[f.shown]
  p.at = f.t
  f.seen[p.r] = f.seen[p.r] + 1
  local x, y, w, h = cardPos(f.shown, #f.pulls)
  local cx, cy = x + w / 2, y + h / 2
  local c = rc(p.r)
  if p.r <= 2 then
    FX.play("tick", 0.9 + p.r * 0.15 + f.shown * 0.004, 0.5)
    FX.burst(cx, cy, 6 * p.r, c, 120)
  else
    G.revealFX(p.r, cx, cy, p.r == 3)
    if p.r == 4 then G.rankBanner = {t = 0, title = "PROTO PULLED", text = G.droneLabel(p.d) .. " joins the fiesta.", c = C.red}
    elseif p.r == 5 then G.rankBanner = {t = 0, title = "!! OMEGA IN THE FIESTA !!", text = G.droneLabel(p.d) .. ". Absolute cinema.", c = C.gold} end
  end
  -- pulls speed up as the fiesta goes on; rare cards hold the moment
  f.wait = f.wait + math.max(0.035, 0.16 * 0.94 ^ f.shown) + HOLD[p.r]
end

local function tallyPanel(f, counts, label)
  local Fo = H.fonts
  local y = Y0 + 60
  H.label(label, PX, y, C.white)
  local maxc = 1
  for r = 1, #RAR do maxc = math.max(maxc, counts[r]) end
  for r = 1, #RAR do
    local yy = y + 22 + (r - 1) * 26
    local c = rc(r)
    col(c); lg.rectangle("fill", PX, yy + 4, 8, 8)
    H.label(RAR[r].name, PX + 16, yy + 2, c)
    col(c, 0.15); lg.rectangle("fill", PX + 80, yy, PW - 140, 16)
    col(c, 0.85); lg.rectangle("fill", PX + 80, yy, (PW - 140) * counts[r] / maxc, 16)
    lg.setFont(Fo.m); col(counts[r] > 0 and C.white or C.faint); lg.printf(tostring(counts[r]), PX, yy - 2, PW, "right")
  end
  return y + 22 + #RAR * 26
end

local function bestBox(d, y, title)
  local Fo = H.fonts
  local c = rc(d.r)
  local h = 120
  col(c, 0.08 + 0.04 * math.sin(G.time * 4)); lg.rectangle("fill", PX, y, PW, h)
  if d.r >= 3 then H.hatch(PX, y, PW, 6, c, 0.8, 5) end
  H.brackets(PX, y, PW, h, 10, c)
  H.label(title, PX + 12, y + 12, C.dim)
  H.droneIcon(PX + 50, y + 70, 1.2, c)
  lg.setFont(Fo.l); col(C.white); lg.print(H.fit(Fo.l, d.name or "", PW - 110), PX + 100, y + 34)
  lg.setFont(Fo.s); col(c); lg.print(RAR[d.r].name .. "  MK" .. d.mk .. "  LV " .. d.lvl, PX + 100, y + 66)
  H.label(table.concat(d.traits, " + "), PX + 100, y + 88, C.orange)
end

local function pulls(f, dt)
  local Fo = H.fonts
  frame("LOOT FIESTA", "x" .. f.n .. (f.bonus > 0 and ("  +" .. f.bonus .. " BONUS") or "") .. "  //  BEST OF 3 AUTO-PICKED", C.orange)
  f.wait = f.wait - dt
  while f.wait <= 0 and f.shown < #f.pulls do revealNext(f) end
  local total = #f.pulls
  local bestR = 0
  for k, p in ipairs(f.pulls) do
    local x, y, w, h = cardPos(k, total)
    if k > f.shown then
      col(C.faint, 0.18); lg.rectangle("fill", x, y, w, h)
      H.hatch(x, y, w, h, p.bonus and C.gold or C.line, 0.07, 6)
      col(p.bonus and C.gold or C.faint, 0.5); lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
      if k == f.shown + 1 then col(C.orange, 0.4 + 0.4 * math.sin(G.time * 20)); lg.rectangle("line", x - 1.5, y - 1.5, w + 3, h + 3) end
    else
      bestR = math.max(bestR, p.r)
      local c = rc(p.r)
      local age = f.t - p.at
      local s = math.min(1, age / 0.12)                -- flip
      lg.push(); lg.translate(x + w / 2, y + h / 2); lg.scale(s, 1); lg.translate(-w / 2, -h / 2)
      col(C.panel, 1); lg.rectangle("fill", 0, 0, w, h)
      col(c, 0.18 + (p.r >= 3 and 0.12 * math.sin(G.time * 6 + k) or 0)); lg.rectangle("fill", 0, 0, w, h)
      if p.r >= 3 then H.hatch(0, 0, w, h, c, 0.1, 5) end
      if p.r == #RAR then H.holoFX(0, 0, w, h) end
      col(c, 0.9); lg.rectangle("line", 0.5, 0.5, w - 1, h - 1)
      if h >= 30 then H.droneIcon(w / 2, h / 2 - (h >= 48 and 6 or 0), math.min(0.7, h / 70), c) end
      lg.setFont(Fo.xs); col(c)
      if h >= 48 then lg.printf(RAR[p.r].name, 0, h - 15, w, "center")
      elseif h < 30 then lg.printf(RAR[p.r].name, 0, h / 2 - 6, w, "center") end
      if p.bonus then col(C.gold); lg.rectangle("fill", w - 7, 2, 5, 5) end
      if p.guaranteed then col(C.white); lg.rectangle("fill", 2, 2, 5, 5) end
      lg.pop()
      if age < 0.4 then
        lg.setBlendMode("add"); col(c, (1 - age / 0.4) * (p.r >= 3 and 0.9 or 0.4))
        lg.rectangle("fill", x - 3, y - 3, w + 6, h + 6); lg.setBlendMode("alpha")
      end
    end
  end
  -- right panel
  local y = tallyPanel(f, f.seen, "PULL " .. f.shown .. " / " .. total)
  local last
  for k = f.shown, 1, -1 do if f.pulls[k].r == bestR then last = f.pulls[k].d break end end
  if last then bestBox(last, y + 12, "BEST PULL SO FAR") end
  H.label("gold dot = bonus pull  //  white dot = 10-pull guarantee", GX, GY + GH + 10, C.dim)
  local done = f.shown >= total and f.wait <= -0.6
  if done then
    f.phase = #f.merges > 0 and "merge" or "done"
    f.t0 = f.t
    if f.phase == "merge" then FX.play("surge", 1.3) end
  end
  H.button(PX + PW - 140, Y0 + HH - 56, 140, 40, "SKIP >>", true, function()
    for _ = f.shown + 1, total do f.shown = f.shown + 1; f.pulls[f.shown].at = f.t - 1; f.seen[f.pulls[f.shown].r] = f.seen[f.pulls[f.shown].r] + 1 end
    G.revealFX(f.bestPull.r, 640, 360, f.bestPull.r < 4)
    f.wait = -1
  end, C.dim, Fo.s)
end

----------------------------------------------------------------------
-- FUSION CASCADE
----------------------------------------------------------------------
local COLW = GW / #RAR
local function chipPos(r, i)
  -- chips stack upward from the bottom of each rarity column, 3 per row
  local per = 3
  local cx = GX + (r - 1) * COLW + 20
  local row, c = math.floor((i - 1) / per), (i - 1) % per
  return cx + c * ((COLW - 40) / per), GY + GH - 26 - row * 13, (COLW - 40) / per - 4, 9
end
local MAXCHIP = 3 * 26

local function cascade(f, dt)
  local Fo = H.fonts
  frame("FUSION CASCADE", "AUTO-FUSE " .. G.autoFuseLabel() .. "  //  3 INTO 1, ALL THE WAY UP", C.gold)
  local m = f.merges[f.mi + 1]
  local dur = math.max(0.07, 0.5 * 0.9 ^ f.mi)
  if m then
    f.mt = f.mt + dt
    if f.mt >= dur then
      f.mt = 0
      f.mi = f.mi + 1
      f.counts[m.r] = f.counts[m.r] - 3
      f.counts[m.r + 1] = f.counts[m.r + 1] + 1
      local x, y = chipPos(m.r + 1, math.min(f.counts[m.r + 1], MAXCHIP))
      FX.play("buy", 0.9 + math.min(f.mi, 40) * 0.03, 0.7)
      FX.burst(x + 10, y, 14 + m.r * 8, rc(m.r + 1), 200)
      if m.out.r >= 4 then G.revealFX(m.out.r, x + 10, y, true) end
      m = f.merges[f.mi + 1]
    end
  end
  -- columns
  for r = 1, #RAR do
    local x = GX + (r - 1) * COLW
    local c = rc(r)
    col(c, 0.04); lg.rectangle("fill", x + 6, GY, COLW - 12, GH)
    H.brackets(x + 6, GY, COLW - 12, GH, 6, c, 0.5)
    lg.setFont(Fo.m); col(c); lg.printf(RAR[r].name, x, GY + 8, COLW, "center")
    lg.setFont(Fo.huge); col(f.counts[r] > 0 and C.white or C.faint); lg.printf(tostring(f.counts[r]), x, GY + 30, COLW, "center")
    local hidden = (m and m.r == r) and 3 or 0
    for i = 1, math.min(f.counts[r] - hidden, MAXCHIP) do
      local cx, cy, w, h = chipPos(r, i)
      col(c, 0.85); lg.rectangle("fill", cx, cy, w, h)
    end
    if f.counts[r] > MAXCHIP then H.label("+" .. (f.counts[r] - MAXCHIP), x + COLW / 2 - 12, GY + 92, c) end
    if r < #RAR then
      col(rc(r + 1), 0.5)
      local ax, ay = x + COLW - 6, GY + GH / 2
      lg.polygon("fill", ax - 4, ay - 7, ax + 5, ay, ax - 4, ay + 7)
    end
  end
  -- the merge in flight: three chips converge on the next column
  if m then
    local p = f.mt / dur
    local e = p * p
    local tx, ty = chipPos(m.r + 1, math.min(f.counts[m.r + 1] + 1, MAXCHIP))
    for j = 1, 3 do
      local sx, sy, w, h = chipPos(m.r, math.max(1, math.min(f.counts[m.r], MAXCHIP) - 3 + j))
      local x, y = sx + (tx - sx) * e, sy + (ty - sy) * e - math.sin(p * math.pi) * 60
      col(rc(m.r)); lg.rectangle("fill", x, y, w, h)
    end
    lg.setBlendMode("add"); col(rc(m.r + 1), e * 0.6); lg.circle("fill", tx + 10, ty + 4, 8 + e * 18); lg.setBlendMode("alpha")
  end
  -- chain counter
  if f.mi > 0 then
    local s = 1 + 0.25 * math.max(0, 1 - f.mt / dur)
    local cc = f.mi >= 20 and C.gold or (f.mi >= 8 and C.red or C.orange)
    lg.push(); lg.translate(GX + GW / 2, GY + GH / 2 - 40); lg.scale(s)
    lg.setFont(Fo.huge); col(cc); lg.printf("CHAIN x" .. f.mi, -300, -20, 600, "center")
    lg.pop()
  end
  local y = tallyPanel(f, f.counts, "FUSION " .. f.mi .. " / " .. #f.merges)
  if f.mi > 0 then bestBox(f.merges[f.mi].out, y + 12, "LATEST FUSION") end
  if not m then
    f.mt = f.mt + dt
    if f.mt > 0.8 then f.phase = "done"; FX.play("unlock", 1.2) end
  end
  H.button(PX + PW - 140, Y0 + HH - 56, 140, 40, "SKIP >>", true, function()
    f.mi = #f.merges; f.mt = 1; f.counts = {0, 0, 0, 0, 0, 0}
    for _, d in ipairs(f.kept) do f.counts[d.r] = f.counts[d.r] + 1 end
  end, C.dim, Fo.s)
end

----------------------------------------------------------------------
-- SUMMARY
----------------------------------------------------------------------
local function summary(f)
  local S, Fo = G.S, H.fonts
  local b = f.best
  local bc = rc(b.r)
  frame("FIESTA COMPLETE", "x" .. f.n .. " +" .. f.bonus .. " BONUS  //  " .. #f.kept .. " JOINED THE FLEET", bc)
  -- hero card
  local hx, hy, hw, hh = X0 + 30, Y0 + 64, 300, 330
  col(bc, 0.08 + 0.05 * math.sin(G.time * 3)); lg.rectangle("fill", hx, hy, hw, hh)
  lg.push("all"); lg.intersectScissor(hx, hy, hw, hh); rays(hx + hw / 2, hy + 120, bc, 0.06, 10); lg.pop()
  if b.r >= 3 then H.hatch(hx, hy, hw, 10, bc, 0.8, 6) end
  if b.r == #RAR then H.holoFX(hx, hy, hw, hh) end
  H.brackets(hx, hy, hw, hh, 14, bc)
  H.label("BEST DRONE", hx + 14, hy + 16, C.dim)
  H.droneIcon(hx + hw / 2, hy + 110, 2.2, bc)
  lg.setFont(Fo.dxl); col(C.white); lg.printf(H.fit(Fo.dxl, b.name or "", hw - 20), hx, hy + 180, hw, "center")
  lg.setFont(Fo.m); col(bc); lg.printf(RAR[b.r].name .. "  MK" .. b.mk .. "  LV " .. b.lvl, hx, hy + 222, hw, "center")
  H.label("POWER " .. fmt(G.dronePower(b)), hx + 20, hy + 262, C.white)
  H.label("+" .. math.floor(G.droneBonus(b) * 100 + 0.5) .. "% DRONE YIELD", hx + 160, hy + 262, C.white)
  H.label(table.concat(b.traits, " + "), hx + 20, hy + 286, C.orange)
  -- stats
  local sx, sy = hx + hw + 30, Y0 + 64
  local rows = {
    {"PULLED", tostring(#f.pulls) .. (f.bonus > 0 and ("  (incl. " .. f.bonus .. " bonus)") or ""), C.white},
    {"COST", fmt(f.hydro) .. " H2O" .. (f.tokens > 0 and ("  +  " .. f.tokens .. " tokens") or ""), C.line},
    {"FUSIONS", tostring(#f.merges) .. "  //  BEST CHAIN EVER " .. (S.bestChain or 0), C.gold},
    {"JOINED FLEET", tostring(#f.kept), C.white},
    {"RECYCLED", f.scrapped .. " overflow drones  //  +" .. fmt(f.candParts + f.scrapParts) .. " parts", C.line},
  }
  for k, r in ipairs(rows) do
    H.label(r[1], sx, sy + (k - 1) * 20, C.dim)
    H.label(r[2], sx + 120, sy + (k - 1) * 20, r[3])
  end
  -- pulled by rarity
  local ty = sy + 112
  for r = 1, #RAR do
    local x = sx + (r - 1) * 92
    local c = rc(r)
    col(c, 0.1); lg.rectangle("fill", x, ty, 84, 46)
    H.brackets(x, ty, 84, 46, 5, c, 0.7)
    lg.setFont(Fo.l); col(f.tally[r] > 0 and C.white or C.faint); lg.printf(tostring(f.tally[r]), x, ty + 4, 84, "center")
    H.label(RAR[r].name, x + 42 - Fo.xs:getWidth(RAR[r].name) / 2, ty + 30, c)
  end
  -- new drones
  H.label("NEW IN THE FLEET", sx, ty + 62, C.white)
  local cw, ch = 172, 40
  for k = 1, math.min(#f.kept, 15) do
    local c, r = (k - 1) % 3, math.floor((k - 1) / 3)
    miniCard(f.kept[k], sx + c * (cw + 8), ty + 80 + r * (ch + 6), cw, ch, k == 1 and "BEST" or nil)
  end
  if #f.kept > 15 then H.label("+" .. (#f.kept - 15) .. " MORE IN THE HANGAR", sx, ty + 80 + 5 * (ch + 6), C.dim) end
  if #f.kept == 0 then H.label("Bay full: everything was recycled into parts. Scrap or fuse drones to make room.", sx, ty + 84, C.red) end
  -- actions
  local n = G.fiestaSize()
  local h = G.fiestaCost(n, G.fiestaOpt.tokens)
  local ok = n > 0 and S.hydro >= h
  H.button(hx, Y0 + HH - 80, 300, 56, ok and ("AGAIN // x" .. n .. " FOR " .. fmt(h) .. " H2O") or "AGAIN // NOT ENOUGH HYDRO", ok,
    G.startFiesta, C.orange, Fo.m, nil, ok)
  H.button(hx + 312, Y0 + HH - 80, 160, 56, "SETUP", true, function() G.fiesta = {phase = "setup", t = 0} end, C.line, Fo.s)
  H.button(X0 + W - 200, Y0 + HH - 80, 170, 56, "TO HANGAR", true, close, C.dim, Fo.s)
end

function Fi.draw()
  local f = G.fiesta
  local dt = love.timer.getDelta()
  f.t = f.t + dt
  H.clearHits()
  if f.phase == "setup" then setup(f)
  elseif f.phase == "pull" then pulls(f, dt)
  elseif f.phase == "merge" then cascade(f, dt)
  else summary(f) end
end

-- Esc: skip the animation, or close
function Fi.escape()
  local f = G.fiesta
  if f.phase == "pull" then
    f.shown = #f.pulls
    for _, p in ipairs(f.pulls) do p.at = p.at or f.t - 1 end
    f.seen = {unpack(f.tally)}
    f.phase = #f.merges > 0 and "merge" or "done"
  elseif f.phase == "merge" then
    f.phase = "done"
  else close() end
end

return Fi
