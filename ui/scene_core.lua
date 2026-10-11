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
  lg.setFont(Fo.huge); col(C.white)
  lg.printf(fmt(G.dispDust), 340, 58, 600, "center")
  local boosted = G.buffMult("prod") > 1
  lg.setFont(Fo.m); col(boosted and C.orange or C.line)
  lg.printf("+" .. fmt(G.getCps()) .. " ENERGY / SEC", 340, 114, 600, "center")
  -- reactor saturation warning: output is being throttled until you reboot
  local sat = G.satMult()
  if sat < 0.999 then
    local txt = string.format("REACTOR SATURATION  x%s OUTPUT  //  REBOOT TO RESET", sat >= 0.01 and string.format("%.2f", sat) or H.fmt(sat))
    local pulse = 0.6 + 0.4 * math.sin(G.time * 4)
    local tw = Fo.xs:getWidth(txt) + 24
    local hov = H.mouseIn(640 - tw / 2, 134, tw, 18)
    col(C.red, (hov and 0.35 or 0.18) * pulse + 0.05); lg.rectangle("fill", 640 - tw / 2, 134, tw, 18)
    lg.setFont(Fo.xs); col(C.red); lg.printf(txt, 640 - tw / 2, 137, tw, "center")
    if hov then H.setTip("REACTOR SATURATION", "This run has outgrown the reactor: a reboot now would more than triple your Core Data, so every further unit pays off less and less. Rebooting resets the saturation and raises the limit.") end
    H.addHit(640 - tw / 2, 134, tw, 18, function() if G.unlocked("nova") then G.tab = "nova"; FX.play("tap", 1.6, 0.4) end end)
  end
  -- buff chips
  local n = #G.buffs
  local cw = 156
  local x = 640 - (n * cw + (n - 1) * 8) / 2
  for _, b in ipairs(G.buffs) do
    local bc = b.kind == "click" and C.red or C.orange
    if b.name == "GOLDEN HOUR" then bc = C.gold end
    col(bc, 0.15); lg.rectangle("fill", x, 138, cw, 26)
    H.brackets(x, 138, cw, 26, 5, bc)
    lg.setFont(Fo.xs); col(bc); lg.print(H.fit(Fo.xs, b.name, 90), x + 8, 141)
    col(C.white); lg.printf("x" .. b.mult .. " " .. math.ceil(b.t) .. "s", x, 141, cw - 8, "right")
    H.bar(x + 8, 157, cw - 16, 2, b.t / b.dur, bc)
    x = x + cw + 8
  end
end

----------------------------------------------------------------------
local function objectives()
  local Fo = H.fonts
  local x, w = 24, 300
  H.label("OBJECTIVES", x, 62, C.white)
  col(C.line, 0.3); lg.line(x, 78, x + w, 78)
  local goals = G.goals()
  local y = 86
  for k = 1, math.min(6, #goals) do
    local g = goals[k]
    local h = 66
    local gc = g.c or C.line
    local hov = H.mouseIn(x, y, w, h)
    col(C.panel, 0.92); lg.rectangle("fill", x, y, w, h)
    if g.ready then
      col(gc, 0.1 + 0.06 * math.sin(G.time * 4 + k)); lg.rectangle("fill", x, y, w, h)
    end
    if hov then col(C.line, 0.06); lg.rectangle("fill", x, y, w, h) end
    col(gc, g.ready and 0.9 or 0.35); lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    col(gc, 0.15); lg.rectangle("fill", x, y, 40, h)
    I.draw(g.icon, x + 20, y + h / 2, 9, gc)
    local tw = g.ready and (w - 140) or (w - 54)
    H.rich(H.fit(Fo.s, g.title, tw), x + 50, y + 9, g.ready and gc or C.white, 1, Fo.s)
    H.rich(H.fit(Fo.xs, g.text, tw), x + 50, y + 29, C.dim, 1, Fo.xs)
    if g.prog then
      H.bar(x + 50, y + 49, w - 64, 4, g.prog, gc)
      lg.setFont(Fo.xs); col(C.dim); lg.printf(math.floor(clamp(g.prog, 0, 1) * 100) .. "%", x, y + 34, w - 12, "right")
    end
    if g.ready and g.label then
      H.button(x + w - 84, y + 18, 74, 30, g.label, true, g.fn, gc, Fo.xs, nil, true)
    elseif g.fn then
      H.addHit(x, y, w, h, g.fn)
    end
    y = y + h + 6
  end
end

----------------------------------------------------------------------
local function status()
  local S = G.S
  local Fo = H.fonts
  local x, w = 956, 300
  H.label("REACTOR STATUS", x, 62, C.white)
  col(C.line, 0.3); lg.line(x, 78, x + w, 78)
  -- surge
  local surging = G.hasBuff("CORE SURGE")
  local y = 86
  H.card(x, y, w, 64, nil, surging and C.orange or C.line)
  H.label("CORE SURGE", x + 12, y + 8, surging and C.orange or C.dim)
  lg.setFont(Fo.l); col(surging and C.orange or C.white)
  lg.printf(surging and "ACTIVE x3" or (math.floor(G.surge * 100) .. "%"), x, y + 4, w - 12, "right")
  H.segbar(x + 12, y + 34, w - 24, 8, surging and 1 or G.surge, 20, C.orange)
  H.label("Tap fast to fill: output x3 for 15s", x + 12, y + 46, C.dim)
  -- chain + crit
  y = y + 70
  H.card(x, y, w, 52, nil, G.combo > 1 and C.red or C.line)
  H.label("TAP CHAIN", x + 12, y + 8, G.combo > 1 and C.red or C.dim)
  lg.setFont(Fo.m); col(G.combo > 1 and C.red or C.white)
  lg.printf(string.format("x%.2f", 1 + math.min(G.combo, 200) * 0.005), x, y + 5, w - 12, "right")
  H.bar(x + 12, y + 34, w - 24, 4, math.min(G.combo, 200) / 200, C.red)
  -- output
  y = y + 58
  H.card(x, y, w, 88, nil, C.line)
  local rows = {
    {"PER TAP", "+" .. fmt(G.tapValue())},
    {"AUTO-TAP", G.autoRate > 0 and (fmt(G.autoRate) .. " / SEC") or "NONE (TECH: SERVOS)"},
    {"OUTPUT MULTIPLIER", "x" .. fmt(G.globalMult)},
    {"TAP CRIT", "4%  //  x10"},
  }
  for k, r in ipairs(rows) do
    H.label(r[1], x + 12, y + 8 + (k - 1) * 18, C.dim)
    lg.setFont(Fo.xs); col(C.white); lg.printf(r[2], x, y + 8 + (k - 1) * 18, w - 12, "right")
  end
  -- rigs quick collect
  y = y + 94
  H.card(x, y, w, 102, "HYDRO RIGS", C.line, fmt(math.floor(S.hydro)) .. " H2O")
  for i, r in ipairs(S.rigs) do
    local ry = y + 30 + (i - 1) * 23
    H.label("R" .. i, x + 12, ry + 2, C.white)
    if r.on then
      local f = clamp(r.tank / G.rigCap(i), 0, 1)
      local full = f >= 1
      H.bar(x + 34, ry + 6, 150, 6, f, full and C.orange or C.line)
      lg.setFont(Fo.xs); col(full and C.orange or C.dim); lg.print(math.floor(f * 100) .. "%", x + 190, ry + 2)
      if G.unlocked("rigs") then
        H.button(x + w - 80, ry, 68, 19, full and "PEAK!" or "COLLECT", r.tank >= 1, function() G.collectRig(i) end,
          full and C.orange or C.line, Fo.xs, nil, full)
      end
    else
      H.label("OFFLINE // RESTORE IN RIGS", x + 34, ry + 2, C.faint)
    end
  end
  -- signal track mini
  y = y + 108
  local need = G.passNeed(S.passTier + 1)
  local ready = G.passReady()
  H.card(x, y, w, 66, "SIGNAL TRACK // TIER " .. S.passTier, ready > 0 and C.orange or C.line, ready > 0 and (ready .. " READY") or nil)
  H.bar(x + 12, y + 32, w - 24, 5, S.sxp / need, C.orange)
  H.label("NEXT: " .. D.passReward(S.passTier + 1).text, x + 12, y + 44, C.dim)
  if ready > 0 then H.addHit(x, y, w, 66, G.claimPass) end
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
      col(C.panel, 0.92); lg.rectangle("fill", x, y, w, h)
      if can then col(C.line, 0.07 + 0.04 * math.sin(G.time * 4 + k)); lg.rectangle("fill", x, y, w, h) end
      if hov then col(C.white, 0.05); lg.rectangle("fill", x, y, w, h) end
      H.brackets(x, y, w, h, 8, can and (hov and C.white or C.line) or C.faint)
      col(can and C.line or C.faint); lg.rectangle("line", x + 10, y + 10, 38, 38)
      lg.setFont(Fo.xs); col(can and C.white or C.dim); lg.printf(g.code, x + 10, y + 23, 38, "center")
      lg.setFont(Fo.s); col(can and C.white or C.dim); lg.print(H.fit(Fo.s, g.name:upper(), w - 66), x + 56, y + 9)
      H.label("+" .. fmt(G.genEach[i]) .. "/S EACH", x + 56, y + 29, C.dim)
      lg.setFont(Fo.l); col(C.white); lg.printf("x" .. S.gens[i], x, y + 50, w - 10, "right")
      H.label(nb > 1 and ("BUY " .. nb) or "BUY", x + 10, y + 56, C.dim)
      lg.setFont(Fo.s); col(can and C.orange or C.red); lg.print(fmt(cost), x + 10, y + 70)
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
  for k, m in ipairs(G.BUYMODES) do
    local sx = bx + (k - 1) * 61
    local on = G.buyMode == k
    local hov = H.mouseIn(sx, y, 57, 24)
    col(C.line, on and 0.3 or (hov and 0.12 or 0.04)); lg.rectangle("fill", sx, y, 57, 24)
    H.brackets(sx, y, 57, 24, 4, on and C.white or C.dim)
    lg.setFont(Fo.xs); col(on and C.white or C.dim)
    lg.printf(m == "MAX" and "MAX" or ("x" .. m), sx, y + 6, 57, "center")
    H.addHit(sx, y, 57, 24, function() G.buyMode = k; FX.play("tick", 1.4) end)
  end
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
  hero()
  Reactor.draw()
  objectives()
  status()
  quickBuild()
end

return Sc
