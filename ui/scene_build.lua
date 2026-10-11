-- BUILD: the units production line (left) and the tech catalogue (right).
-- Units read in columns: what it is (+ BEST BUY, the row Smart Buy would pick), what it makes, the next x2
-- milestone, how many you own, and the buy button with the price or how long until you can afford it.
-- Tech is filtered by category and every card says what it costs or when you can buy it.
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local I = require "ui.icons"
local lg = V.lg
local C, col, fmt, clamp = H.C, H.col, H.fmt, H.clamp
local Sc = {}

local TOP, BOT = H.HEAD.BODY_Y, 630

-- "IN 2M 13S" until a cost is affordable at the current output (nil when nothing is produced)
local function eta(cost)
  local cps = G.getCps()
  local need = cost - G.S.stardust
  if need <= 0 then return "NOW" end
  if cps <= 0 then return nil end
  local t = need / cps
  if t > 360000 then return "> 100H" end
  return "IN " .. H.fmtTime(t)
end

local function autoToggle(x, y, w, key, archKey)
  local S = G.S
  local ok, need = G.hasArchive(archKey)
  H.button(x, y, w, H.HEAD.CTRL_H, ok and ("AUTO: " .. (S[key] and "ON" or "OFF")) or ("AUTO // " .. need .. " LOGS"), ok,
    function() S[key] = not S[key]; FX.play("tick", S[key] and 1.4 or 0.8) end, S[key] and ok and C.orange or C.dim, H.fonts.xs)
end

local function scrollbar(x, y, h, key)
  local ms = G.maxScroll[key]
  if ms <= 0 then return end
  local f = G.scroll[key] / ms
  col(C.faint, 0.6); lg.rectangle("fill", x, y, 2, h)
  col(C.line); lg.rectangle("fill", x - 1, y + f * (h - 40), 4, 40)
end

----------------------------------------------------------------------
-- UNITS
----------------------------------------------------------------------
-- the unit Smart Buy would take next: cheapest energy per unit of output among what you can afford
local function bestBuy()
  local S = G.S
  local best, bs
  for i = 1, #D.GENS do
    if G.revealedGen(i) then
      local c = G.genCost(i, 1)
      if c <= S.stardust and (G.genEach[i] or 0) > 0 then
        local sc = c / G.genEach[i]
        if not bs or sc < bs then best, bs = i, sc end
      end
    end
  end
  return best
end

local ROW_H, ROW_GAP = 64, 6
local function unitRow(i, x, y, w, clip, best)
  local S = G.S
  local Fo = H.fonts
  local g = D.GENS[i]
  local owned = S.gens[i]
  local nb = G.buyCount(i)
  local cost = G.genCost(i, nb)
  local can = S.stardust >= cost
  local hov = H.mouseIn(x, y, w, ROW_H, clip)
  H.rowFrame(x, y, w, ROW_H, can, hov, i == best and C.orange or C.line)
  -- identity chip
  col(can and C.line or C.faint, can and 0.9 or 1); lg.rectangle("line", x + 12, y + 12, 40, 40)
  lg.setFont(Fo.xs); col(C.dim); lg.printf(string.format("%02d", i), x + 12, y + 14, 40, "center")
  lg.setFont(Fo.s); col(can and C.white or C.dim); lg.printf(g.code, x + 12, y + 30, 40, "center")
  -- name, output, milestone
  local tx = x + 64
  lg.setFont(Fo.s); col(can and C.white or C.line); lg.print(g.name:upper(), tx, y + 9)
  if i == best then
    local nx = tx + Fo.s:getWidth(g.name:upper()) + 10
    local tw = Fo.xs:getWidth("BEST BUY") + 12
    col(C.orange); H.chamfer("fill", nx, y + 10, tw, 15, 4)
    lg.setFont(Fo.xs); col(C.bg); lg.printf("BEST BUY", nx, y + 12, tw, "center")
  end
  local total = G.genEach[i] * owned
  H.label("+" .. fmt(G.genEach[i]) .. "/S EACH  //  +" .. fmt(total) .. "/S TOTAL", tx, y + 28, C.dim)
  local ms, prev = G.nextMilestone(i)
  local barW = 210
  if ms then
    H.bar(tx, y + 49, barW, 3, (owned - prev) / (ms - prev), C.orange)
    H.label("x2 AT " .. ms, tx + barW + 10, y + 44, C.orange)
  end
  -- owned: number and label share one right edge
  local ox = x + w - 136 - 16
  lg.setFont(Fo.dxl); col(C.white); lg.printf(tostring(owned), ox - 120, y + 6, 120, "right")
  lg.setFont(Fo.xs); col(C.dim); lg.printf("OWNED", ox - 120, y + 42, 120, "right")
  -- buy: price when affordable, otherwise the price and when you will have it
  local bx, bw = x + w - 136, 124
  if can then
    col(C.orange, hov and 1 or 0.9); H.chamfer("fill", bx, y + 10, bw, 44, 6)
    lg.setFont(Fo.xs); col(C.bg); lg.printf(nb > 1 and ("BUY x" .. nb) or "BUY", bx, y + 15, bw, "center")
    lg.setFont(Fo.s); lg.printf(fmt(cost), bx, y + 31, bw, "center")
  else
    col(C.faint); H.chamfer("line", bx + 0.5, y + 10.5, bw - 1, 43, 6)
    lg.setFont(Fo.s); col(C.dim); lg.printf(fmt(cost), bx, y + 15, bw, "center")
    local e = eta(cost)
    lg.setFont(Fo.xs); col(C.faint); lg.printf(e or "NO OUTPUT YET", bx, y + 34, bw, "center")
  end
  if hov then H.setTip(g.name:upper(), g.desc .. "  //  hold to keep buying. Every 25 owned (then more) doubles its output.") end
  H.addHit(x, y, w, ROW_H, function(mx, my) G.buyGen(i, mx, my) end, clip, true)
end

local function lockedRow(i, x, y, w)
  local S = G.S
  local g = D.GENS[i]
  local need = g.cost * 0.4
  H.rowFrame(x, y, w, ROW_H, false, false, C.red)
  I.draw("lock", x + 32, y + 32, 8, C.red, 0.8)
  lg.setFont(H.fonts.s); col(C.red); lg.print("SIGNAL LOCKED", x + 64, y + 10)
  H.label("Harvest " .. fmt(need) .. " energy this run to decrypt the next unit", x + 64, y + 28, C.dim)
  H.bar(x + 64, y + 49, 210, 3, S.runEarned / need, C.red)
  H.label(math.floor(clamp(S.runEarned / need, 0, 1) * 100) .. "%", x + 284, y + 44, C.red)
end

local function units()
  local Fo = H.fonts
  local x, w = 24, 640
  H.screenTitle("UNITS", H.fit(Fo.xs, "OUTPUT x" .. fmt(G.globalMult) .. "  //  +" .. fmt(G.getCps()) .. "/S", 200), x)
  local labels = {}
  for k, m in ipairs(G.BUYMODES) do labels[k] = m == "MAX" and "MAX" or ("x" .. m) end
  H.segmented(x + w - 96 - 16 - 220, H.HEAD.CTRL_Y, 220, H.HEAD.CTRL_H, labels, G.buyMode, function(k) G.buyMode = k; FX.play("tick", 1.4) end, "buymode")
  autoToggle(x + w - 96, H.HEAD.CTRL_Y, 96, "autoUnits", "autoUnits")

  local clip = {TOP, BOT}
  H.scrollRegion(x, TOP, w, BOT - TOP, "units")
  lg.setScissor(x - 4, TOP, w + 8, BOT - TOP)
  local y = TOP - G.scroll.units
  local best = bestBuy()
  local bestY
  for i = 1, #D.GENS do
    if i == best then bestY = y + G.scroll.units - TOP end
    if not G.revealedGen(i) then
      if y + ROW_H >= TOP and y <= BOT then lockedRow(i, x, y, w) end
      y = y + ROW_H + ROW_GAP
      break
    end
    if y + ROW_H >= TOP and y <= BOT then unitRow(i, x, y, w, clip, best) end
    y = y + ROW_H + ROW_GAP
  end
  lg.setScissor()
  local contentH = y + G.scroll.units - TOP
  G.maxScroll.units = math.max(0, y + G.scroll.units - BOT)
  scrollbar(x + w + 6, TOP, BOT - TOP, "units")
  -- the BEST BUY row is often far down the list: an orange tick on the scroll track shows where it is,
  -- and clicking the track there scrolls it into view
  if bestY and G.maxScroll.units > 0 then
    local ty = TOP + bestY / contentH * (BOT - TOP)
    col(C.orange); lg.rectangle("fill", x + w + 3, ty, 8, 4)
    H.addHit(x + w + 1, ty - 6, 12, 16, function()
      G.scroll.units = clamp(bestY - 40, 0, G.maxScroll.units); FX.play("tick", 1.4)
    end)
    if H.mouseIn(x + w + 1, ty - 6, 12, 16) then H.setTip("BEST BUY", D.GENS[best].name:upper() .. " gives the most output per energy right now. Click to jump to it.") end
  end
end

----------------------------------------------------------------------
-- TECH
----------------------------------------------------------------------
local CATS = {
  {id = "all", label = "ALL"},
  {id = "units", label = "UNITS", c = "line", t = {gen = true}},
  {id = "tap", label = "TAP", c = "red", t = {click = true, clickcps = true}},
  {id = "auto", label = "AUTO", c = "orange", t = {auto = true}},
  {id = "output", label = "OUTPUT", c = "gold", t = {global = true, perlog = true}},
  {id = "other", label = "OTHER", c = "teal", t = {cometfreq = true, cometdur = true, hydro = true}},
}
local function catOf(u)
  for k = 2, #CATS do if CATS[k].t[u.eff.t] then return CATS[k] end end
  return CATS[#CATS]
end
G.techFilter = G.techFilter or 1

local function techCard(u, cx, cy, cw, ch, clip)
  local S = G.S
  local Fo = H.fonts
  local can = S.stardust >= u.cost
  local cat = catOf(u)
  local cc = C[cat.c] or C.line
  local hov = H.mouseIn(cx, cy, cw, ch, clip)
  local t = H.hoverT(cx, cy, cw, ch, hov)
  col(C.panel, 0.92); lg.rectangle("fill", cx, cy, cw, ch)
  col(cc, 0.04 * t); lg.rectangle("fill", cx, cy, cw, ch)
  col(can and cc or C.faint, can and (0.35 + 0.45 * t) or 0.8); lg.rectangle("line", cx + 0.5, cy + 0.5, cw - 1, ch - 1)
  col(cc, can and 0.9 or 0.35); H.leftEdge(cx, cy, cw, ch, 3)
  -- category + price on top, the name, the effect at the bottom
  -- unit upgrades name the unit they boost; for the other categories the code would only repeat the category
  H.label(cat.label .. ((cat.id == "units" and u.code) and ("  //  " .. u.code) or ""), cx + 12, cy + 8, cc, can and 1 or 0.6)
  lg.setFont(Fo.xs); col(can and C.orange or C.dim); lg.printf(fmt(u.cost), cx, cy + 8, cw - 10, "right")
  lg.setFont(Fo.s); col(can and C.white or C.dim)
  lg.printf(u.name:upper(), cx + 12, cy + 24, cw - 22, "left")
  local foot = can and u.desc or ((eta(u.cost) or "NO OUTPUT YET") .. "  //  " .. u.desc)
  H.label(H.fit(Fo.xs, foot, cw - 22), cx + 12, cy + ch - 18, can and C.line or C.faint)
  if hov then H.setTip(u.name:upper(), u.desc .. "  //  COST " .. fmt(u.cost) .. (can and "" or ("  //  " .. (eta(u.cost) or "")))) end
  H.addHit(cx, cy, cw, ch, function(mx, my) G.buyUpgrade(u, mx, my) end, clip)
end

local function tech()
  local S = G.S
  local Fo = H.fonts
  local all = G.availableUpgrades()
  local x, w = 688, 568
  local affordable = 0
  for _, u in ipairs(all) do if S.stardust >= u.cost then affordable = affordable + 1 end end
  H.screenTitle("TECH", #all .. " AVAILABLE  //  " .. S.upBought .. " INSTALLED", x)
  H.button(x + w - 96 - 16 - 196, H.HEAD.CTRL_Y, 196, H.HEAD.CTRL_H, "INSTALL ALL (" .. affordable .. ")", affordable > 0, function()
    local mx, my = V.mouse()
    local n = 0
    for _, u in ipairs(G.availableUpgrades()) do
      if S.stardust >= u.cost and G.buyUpgrade(u, nil, nil, true) then n = n + 1 end
    end
    G.recalc()
    FX.burst(mx, my, 20 + n * 4, C.orange, 300)
    FX.floater(mx, my - 20, "+" .. n .. " UPGRADES", C.orange, H.fonts.m, 1.2)
    FX.play("unlock", 1.2)
  end, C.orange, Fo.xs, nil, true)
  autoToggle(x + w - 96, H.HEAD.CTRL_Y, 96, "autoTech", "autoTech")

  -- category filter with live counts
  local counts = {}
  for _, u in ipairs(all) do local id = catOf(u).id; counts[id] = (counts[id] or 0) + 1 end
  local labels = {}
  for k, c in ipairs(CATS) do labels[k] = c.label .. " " .. (k == 1 and #all or (counts[c.id] or 0)) end
  H.segmented(x, TOP, w, H.HEAD.CTRL_H, labels, G.techFilter, function(k)
    G.techFilter = k; G.scroll.tech = 0; FX.play("tick", 1.3)
  end, "techfilter")
  local list = {}
  local filter = CATS[G.techFilter]
  for _, u in ipairs(all) do if G.techFilter == 1 or catOf(u) == filter then list[#list + 1] = u end end
  -- affordable first, then by cost
  table.sort(list, function(a, b)
    local ca, cb = S.stardust >= a.cost, S.stardust >= b.cost
    if ca ~= cb then return ca end
    return a.cost < b.cost
  end)

  local top = TOP + H.HEAD.CTRL_H + 12
  local clip = {top, BOT}
  H.scrollRegion(x, top, w, BOT - top, "tech")
  lg.setScissor(x - 4, top, w + 8, BOT - top)
  local cols, gap = 3, 8
  local cw, ch = (w - (cols - 1) * gap) / cols, 84
  local y0 = top - G.scroll.tech
  local n = 0
  local function slot()
    local c, r = n % cols, math.floor(n / cols)
    n = n + 1
    return x + c * (cw + gap), y0 + r * (ch + gap)
  end
  for _, u in ipairs(list) do
    local cx, cy = slot()
    if cy + ch >= top and cy <= BOT then techCard(u, cx, cy, cw, ch, clip) end
  end
  if #list == 0 then
    -- empty state: one full-width row, locked teasers below it
    col(C.panel, 0.6); lg.rectangle("fill", x, y0, w, ch)
    lg.setFont(Fo.s); col(C.dim)
    lg.printf(G.techFilter == 1 and "NO UPGRADES AVAILABLE" or ("NO " .. filter.label .. " UPGRADES RIGHT NOW"), x, y0 + ch / 2 - 18, w, "center")
    H.label("Buy more units or tap the core to reveal new tech.", x + w / 2 - 140, y0 + ch / 2 + 4, C.faint)
    n = cols
  end
  if G.techFilter == 1 then
    local shownLocked = 0
    for _, u in ipairs(G.lockedLogUpgrades()) do
      if shownLocked >= 3 then break end
      shownLocked = shownLocked + 1
      local cx, cy = slot()
      if cy + ch >= top and cy <= BOT then
        col(C.panel, 0.6); lg.rectangle("fill", cx, cy, cw, ch)
        col(C.faint); lg.rectangle("line", cx + 0.5, cy + 0.5, cw - 1, ch - 1)
        col(C.red, 0.6); H.leftEdge(cx, cy, cw, ch, 3)
        I.draw("lock", cx + 20, cy + 16, 6, C.red, 0.8)
        lg.setFont(Fo.s); col(C.dim); lg.printf(u.name:upper(), cx + 12, cy + 28, cw - 22, "left")
        H.label("DECRYPTS AT " .. u.logs .. " LOGS (" .. G.achCount .. ")", cx + 12, cy + ch - 18, C.red, 0.8)
      end
    end
  end
  lg.setScissor()
  local rows = math.ceil(n / cols)
  G.maxScroll.tech = math.max(0, rows * (ch + gap) - (BOT - top))
  scrollbar(x + w + 6, top, BOT - top, "tech")
end

function Sc.draw()
  units()
  tech()
end

return Sc
