-- BUILD: units list (left) + tech upgrade cards (right).
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local I = require "ui.icons"
local lg = V.lg
local C, col, fmt = H.C, H.col, H.fmt
local Sc = {}

local TOP, BOT = 108, 630

local function autoToggle(x, y, w, key, archKey)
  local S = G.S
  local ok, need = G.hasArchive(archKey)
  H.button(x, y, w, 28, ok and ("AUTO: " .. (S[key] and "ON" or "OFF")) or ("AUTO // " .. need .. " LOGS"), ok,
    function() S[key] = not S[key]; FX.play("tick", S[key] and 1.4 or 0.8) end, S[key] and ok and C.orange or C.dim, H.fonts.xs)
end

local function scrollbar(x, y, h, key)
  local ms = G.maxScroll[key]
  if ms <= 0 then return end
  local f = G.scroll[key] / ms
  col(C.faint, 0.6); lg.rectangle("fill", x, y, 2, h)
  col(C.line); lg.rectangle("fill", x - 1, y + f * (h - 40), 4, 40)
end

local function units()
  local S = G.S
  local Fo = H.fonts
  local x, w = 24, 640
  lg.setFont(Fo.l); col(C.white); lg.print("UNITS", x, 62)
  H.label(H.fit(Fo.xs, "OUTPUT x" .. fmt(G.globalMult) .. "  //  +" .. fmt(G.getCps()) .. "/S", 216), x + 84, 70, C.dim)
  for k, m in ipairs(G.BUYMODES) do
    -- right-aligned so the last button ends 12px before the AUTO toggle
    local sx = x + w - 96 - 12 - #G.BUYMODES * 56 + 4 + (k - 1) * 56
    local on = G.buyMode == k
    local hov = H.mouseIn(sx, 64, 52, 28)
    col(C.line, on and 0.3 or (hov and 0.12 or 0.04)); lg.rectangle("fill", sx, 64, 52, 28)
    H.brackets(sx, 64, 52, 28, 4, on and C.white or C.dim)
    lg.setFont(Fo.xs); col(on and C.white or C.dim)
    lg.printf(m == "MAX" and "MAX" or ("x" .. m), sx, 72, 52, "center")
    H.addHit(sx, 64, 52, 28, function() G.buyMode = k; FX.play("tick", 1.4) end)
  end
  autoToggle(x + w - 96, 64, 96, "autoUnits", "autoUnits")

  local clip = {TOP, BOT}
  H.scrollRegion(x, TOP, w, BOT - TOP, "units")
  lg.setScissor(x - 4, TOP, w + 8, BOT - TOP)
  local y = TOP - G.scroll.units
  local rowH = 70
  for i, g in ipairs(D.GENS) do
    local owned = S.gens[i]
    if not G.revealedGen(i) then
      col(C.panel, 0.7); lg.rectangle("fill", x, y, w, rowH - 6)
      H.hatch(x, y, w, rowH - 6, C.red, 0.14, 7)
      H.brackets(x, y, w, rowH - 6, 8, C.red, 0.6)
      I.draw("lock", x + 30, y + 30, 9, C.red)
      lg.setFont(Fo.m); col(C.red); lg.print("SIGNAL LOCKED // ???", x + 64, y + 12)
      H.label("Harvest " .. fmt(g.cost * 0.4) .. " energy this cycle to decrypt", x + 64, y + 36, C.red, 0.8)
      y = y + rowH
      break
    end
    local nb = G.buyCount(i)
    local cost = G.genCost(i, nb)
    local can = S.stardust >= cost
    local hov = H.mouseIn(x, y, w, rowH - 6, clip)
    col(C.panel, 0.92); lg.rectangle("fill", x, y, w, rowH - 6)
    if can then col(C.line, 0.06 + 0.03 * math.sin(G.time * 4 + i)); lg.rectangle("fill", x, y, w, rowH - 6) end
    if hov then col(C.white, 0.05); lg.rectangle("fill", x, y, w, rowH - 6) end
    H.brackets(x, y, w, rowH - 6, 8, can and (hov and C.white or C.line) or C.faint)
    col(can and C.line or C.faint); lg.rectangle("line", x + 10, y + 10, 44, 44)
    H.label(string.format("%02d", i), x + 13, y + 12, C.dim)
    lg.setFont(Fo.s); col(can and C.white or C.dim); lg.printf(g.code, x + 10, y + 27, 44, "center")
    lg.setFont(Fo.m); col(can and C.white or C.dim); lg.print(g.name:upper(), x + 66, y + 8)
    H.label(g.desc, x + 66, y + 28, C.dim)
    local total = G.genEach[i] * owned
    local pct = G.baseCps > 0 and total / G.baseCps * 100 or 0
    H.label("EACH +" .. fmt(G.genEach[i]) .. "/S   TOTAL +" .. fmt(total) .. "/S   " .. string.format("%.0f%%", pct), x + 66, y + 42, C.line, 0.85)
    -- right block: owned + cost
    lg.setFont(Fo.xl); col(C.white); lg.printf(tostring(owned), x + w - 250, y + 6, 100, "right")
    H.label("OWNED", x + w - 196, y + 42, C.dim)
    local bx = x + w - 136
    col(can and C.orange or C.faint, can and 0.85 or 0.4)
    lg.rectangle(can and "fill" or "line", bx, y + 10, 124, 44)
    lg.setFont(Fo.xs); col(can and C.bg or C.dim); lg.printf(nb > 1 and ("BUY x" .. nb) or "BUY", bx, y + 15, 124, "center")
    lg.setFont(Fo.s); col(can and C.bg or C.red); lg.printf(fmt(cost), bx, y + 31, 124, "center")
    local ms, prev = G.nextMilestone(i)
    if ms then
      -- progress bar ends well before the "x2 @N" label and the owned/buy block
      H.bar(x + 66, y + rowH - 13, w - 330, 3, (owned - prev) / (ms - prev), C.orange)
      H.label("x2 @" .. ms, x + w - 256, y + rowH - 18, C.orange, 0.8)
    end
    H.addHit(x, y, w, rowH - 6, function(mx, my) G.buyGen(i, mx, my) end, clip, true)
    y = y + rowH
  end
  lg.setScissor()
  G.maxScroll.units = math.max(0, y + G.scroll.units - BOT)
  scrollbar(x + w + 6, TOP, BOT - TOP, "units")
end

local function tech()
  local S = G.S
  local Fo = H.fonts
  local list = G.availableUpgrades()
  local x, w = 688, 568
  local affordable = 0
  for _, u in ipairs(list) do if S.stardust >= u.cost then affordable = affordable + 1 end end
  lg.setFont(Fo.l); col(C.white); lg.print("TECH", x, 62)
  H.label(#list .. " AVAILABLE  //  " .. S.upBought .. " INSTALLED", x + 70, 70, C.dim)
  H.button(x + w - 300, 64, 196, 28, "INSTALL ALL (" .. affordable .. ")", affordable > 0, function()
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
  autoToggle(x + w - 96, 64, 96, "autoTech", "autoTech")

  local clip = {TOP, BOT}
  H.scrollRegion(x, TOP, w, BOT - TOP, "tech")
  lg.setScissor(x - 4, TOP, w + 8, BOT - TOP)
  local cols, gap = 3, 8
  local cw, ch = (w - (cols - 1) * gap) / cols, 96
  local y0 = TOP - G.scroll.tech
  local n = 0
  local function slot()
    local c, r = n % cols, math.floor(n / cols)
    n = n + 1
    return x + c * (cw + gap), y0 + r * (ch + gap)
  end
  -- affordable first, then by cost
  table.sort(list, function(a, b)
    local ca, cb = S.stardust >= a.cost, S.stardust >= b.cost
    if ca ~= cb then return ca end
    return a.cost < b.cost
  end)
  for _, u in ipairs(list) do
    local cx, cy = slot()
    if cy + ch >= TOP and cy <= BOT then
      local can = S.stardust >= u.cost
      local hov = H.mouseIn(cx, cy, cw, ch, clip)
      local cc = (u.code == "SIG" or u.code == "LOG") and C.orange or ((u.code == "TAP" or u.code == "AUT") and C.red or C.line)
      col(C.panel, 0.92); lg.rectangle("fill", cx, cy, cw, ch)
      if can then col(cc, 0.08 + 0.04 * math.sin(G.time * 4 + n)); lg.rectangle("fill", cx, cy, cw, ch) end
      if hov then col(C.white, 0.05); lg.rectangle("fill", cx, cy, cw, ch) end
      H.brackets(cx, cy, cw, ch, 7, can and (hov and C.white or cc) or C.faint)
      col(cc, can and 0.9 or 0.35); lg.rectangle("fill", cx, cy, 4, ch)
      H.label(u.code, cx + 12, cy + 8, cc)
      lg.setFont(Fo.s); col(can and C.white or C.dim)
      lg.printf(u.name:upper(), cx + 12, cy + 22, cw - 20, "left")
      H.label(H.fit(Fo.xs, u.desc, cw - 20), cx + 12, cy + 58, can and C.line or C.dim)
      lg.setFont(Fo.s); col(can and C.orange or C.red); lg.printf(fmt(u.cost), cx, cy + ch - 20, cw - 10, "right")
      if hov then H.setTip(u.name:upper(), u.desc .. "  //  COST " .. fmt(u.cost)) end
      H.addHit(cx, cy, cw, ch, function(mx, my) G.buyUpgrade(u, mx, my) end, clip)
    end
  end
  if #list == 0 then
    -- empty state gets its own full-width row; locked teasers start below it
    local ey = y0
    col(C.panel, 0.6); lg.rectangle("fill", x, ey, w, ch)
    H.brackets(x, ey, w, ch, 7, C.faint)
    lg.setFont(Fo.s); col(C.dim); lg.printf("NO UPGRADES AVAILABLE", x, ey + ch / 2 - 18, w, "center")
    H.label("Buy more units or tap the core to reveal new tech.", x + w / 2 - 140, ey + ch / 2 + 4, C.faint)
    n = cols
  end
  local shownLocked = 0
  for _, u in ipairs(G.lockedLogUpgrades()) do
    if shownLocked >= 3 then break end
    shownLocked = shownLocked + 1
    local cx, cy = slot()
    if cy + ch >= TOP and cy <= BOT then
      col(C.panel, 0.7); lg.rectangle("fill", cx, cy, cw, ch)
      H.hatch(cx, cy, cw, ch, C.red, 0.12, 7)
      H.brackets(cx, cy, cw, ch, 7, C.red, 0.6)
      I.draw("lock", cx + 18, cy + 18, 7, C.red)
      lg.setFont(Fo.s); col(C.red); lg.printf(u.name:upper(), cx + 12, cy + 34, cw - 20, "left")
      H.label("DECRYPTS AT " .. u.logs .. " LOGS (" .. G.achCount .. ")", cx + 12, cy + ch - 20, C.red, 0.8)
    end
  end
  lg.setScissor()
  local rows = math.ceil(n / cols)
  G.maxScroll.tech = math.max(0, rows * (ch + gap) - (BOT - TOP))
  scrollbar(x + w + 6, TOP, BOT - TOP, "tech")
end

function Sc.draw()
  units()
  tech()
end

return Sc
