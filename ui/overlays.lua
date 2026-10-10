-- Banners, tooltip and modal overlays (offline report, daily supply, pick-1-of-3 fabrication).
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local lg = V.lg
local C, col, fmt = H.C, H.col, H.fmt
local TAU = math.pi * 2
local Ov = {}

local I = require "ui.icons"
local SettingsUI = require "ui.settings"
local Combine = require "ui.combine"
local Fiesta = require "ui.fiesta"
local Altar = require "ui.altar"
local Vault = require "ui.vault"

H.showTips = true

function Ov.isModal()
  return G.settingsOpen or G.fiesta ~= nil or G.altar ~= nil or G.vaultOpen or G.combine ~= nil or G.report ~= nil or G.dailyPending or #G.choiceQueue > 0 or G.perkChoice ~= nil
end

local function dim(a)
  local x0, y0, x1, y1 = V.extents()
  col(C.bg, a or 0.86)
  lg.rectangle("fill", x0, y0, x1 - x0, y1 - y0)
end

local function box(x, y, w, h, c)
  col(C.panel); lg.rectangle("fill", x, y, w, h)
  H.hatch(x, y, w, 30, c, 0.18, 6)
  H.brackets(x, y, w, h, 14, c)
end

local function tooltip()
  -- element tooltips follow the TOOLTIPS setting; keyword explanations always show
  local tip = H.kwTip or (H.showTips and H.tip) -- the keyword under the cursor is more specific than its card
  if not tip then return end
  local kw = tip == H.kwTip
  local mx, my = V.mouse()
  local w = 320
  -- measure, then draw
  local h = 34 + H.richHeight(tip.text, w - 20, H.fonts.xs)
  local x = math.min(mx + 14, 1280 - w - 6)
  local y = my + 16
  if y + h > 712 then y = my - h - 12 end -- no room below (e.g. the dock): open above the cursor
  col(C.bg, 0.97); lg.rectangle("fill", x, y, w, h)
  H.brackets(x, y, w, h, 6, kw and C.orange or C.white)
  if kw then
    col(C.orange); lg.rectangle("fill", x, y, 3, h)
    H.label("GLOSSARY", x + w - 70, y + 8, C.orange)
  end
  lg.setFont(H.fonts.s); col(kw and C.orange or C.white); lg.print(tip.title, x + 10, y + 6)
  H.richf(tip.text, x + 10, y + 26, w - 20, "left", C.line, 1, H.fonts.xs, true)
end

local function report()
  local r = G.report
  H.clearHits()
  dim()
  local w, h = 540, 310
  local x, y = 640 - w / 2, 360 - h / 2
  box(x, y, w, h, C.line)
  lg.setFont(H.fonts.m); col(C.white); lg.print("WELCOME BACK, TECHNICIAN", x + 16, y + 6)
  H.label("OFFLINE HARVEST REPORT // " .. H.fmtTime(r.secs) .. (r.capped and " (CAPPED)" or ""), x + 16, y + 46, C.line)
  H.label("THE TOWER KEPT WORKING WHILE YOU RESTED (" .. math.floor(r.rate * 100) .. "% EFFICIENCY)", x + 16, y + 62)
  lg.setFont(H.fonts.huge); col(C.white); lg.printf("+" .. fmt(r.gain), x, y + 88, w, "center")
  H.label("ENERGY", x + w / 2 - 20, y + 150, C.dim)
  local lines = {}
  if r.rigs > 0 then lines[#lines + 1] = r.rigs .. " HYDRO RIG" .. (r.rigs > 1 and "S" or "") .. " AT FULL PRESSURE // COLLECT NOW" end
  if r.missions > 0 then lines[#lines + 1] = r.missions .. " DRONE MISSION" .. (r.missions > 1 and "S" or "") .. " COMPLETED" end
  if (r.crates or 0) > 0 then lines[#lines + 1] = r.crates .. " LOOT CRATE" .. (r.crates > 1 and "S" or "") .. " WAITING ON THE MAP" end
  for k, l in ipairs(lines) do
    lg.setFont(H.fonts.s); col(C.orange); lg.printf(l, x, y + 168 + (k - 1) * 18, w, "center")
  end
  local S = G.S
  H.button(x + 20, y + h - 56, 240, 40, "COLLECT", true, G.collectReport, C.line, H.fonts.m)
  H.button(x + w - 260, y + h - 56, 240, 40, "DOUBLE IT // 1 TOKEN", S.tokens > 0 and r.gain > 0, function()
    S.tokens = S.tokens - 1
    S.doubled = S.doubled + 1
    r.gain = r.gain * 2
    FX.flashTo(C.orange, 0.4)
    FX.ray(640, 300, C.orange, 1.4, 400)
    FX.burst(640, 300, 120, C.orange, 500, 3)
    FX.play("jackpot")
    G.collectReport()
  end, C.orange, H.fonts.m, nil, S.tokens > 0)
end

local function daily()
  H.clearHits()
  dim()
  local w, h = 600, 280
  local x, y = 640 - w / 2, 360 - h / 2
  box(x, y, w, h, C.orange)
  local st = G.dailyNextStreak()
  lg.setFont(H.fonts.m); col(C.orange); lg.print("NEW SHIFT // DAILY SUPPLY DROP", x + 16, y + 6)
  H.label(st > 1 and ("SHIFT STREAK CONTINUES: DAY " .. st) or "SHIFT STREAK: DAY 1 (log in every day to climb the ladder)",
    x + 16, y + 44, C.line)
  local cur = (st - 1) % 7 + 1
  local bw = (w - 32 - 6 * 6) / 7
  for k, day in ipairs(D.DAILY) do
    local bx = x + 16 + (k - 1) * (bw + 6)
    local by = y + 70
    local isCur = k == cur
    if isCur then H.hatch(bx, by, bw, 90, C.orange, 0.35 + 0.15 * math.sin(G.time * 5), 5) end
    if k < cur then col(C.line, 0.15); lg.rectangle("fill", bx, by, bw, 90) end
    H.brackets(bx, by, bw, 90, 6, isCur and C.orange or (k < cur and C.line or C.faint))
    lg.setFont(H.fonts.l); col(isCur and C.white or C.dim); lg.printf(day.code, bx, by + 14, bw, "center")
    lg.setFont(H.fonts.xs); col(isCur and C.orange or C.dim); lg.printf(day.text, bx + 2, by + 52, bw - 4, "center")
  end
  H.label("Miss a day and the streak resets. Day 7 includes Core Data.", x + 16, y + 172, C.dim)
  H.button(x + w / 2 - 130, y + h - 60, 260, 42, "[ CLAIM SUPPLY ]", true, G.claimDaily, C.orange, H.fonts.m)
end

----------------------------------------------------------------------
-- pick 1 of 3
----------------------------------------------------------------------
local function card(ch, k)
  local S = G.S
  local F = H.fonts
  local d = ch.cands[k]
  local rr = D.RARITY[d.r]
  local rc = C[rr.col]
  local cx, cy = G.cardX(k), 360
  local w, h = 220, 300
  local x, y = cx - w / 2, cy - h / 2
  local flipped = ch.flipped[k]
  local ready = G.choiceReady(ch)
  local hov = ready and H.mouseIn(x, y, w, h)
  local pos = 1
  for p, kk in ipairs(ch.order) do if kk == k then pos = p end end
  local ft = G.flipTime(ch, pos)

  if not flipped then
    -- face down; rare cards tremble and glow before the flip
    local tell = d.r >= 3 and ch.t > ft - 0.9
    local amp = tell and (d.r - 2) * 2.5 * math.min(1, (ch.t - (ft - 0.9)) / 0.9) or 0
    local ox, oy = H.rnd(-amp, amp), H.rnd(-amp, amp)
    lg.push(); lg.translate(ox, oy)
    col(C.panel); lg.rectangle("fill", x, y, w, h)
    H.hatch(x, y, w, h, tell and rc or C.line, tell and (0.15 + 0.15 * math.sin(G.time * 20)) or 0.08, 8)
    H.brackets(x, y, w, h, 14, tell and rc or C.line)
    lg.setFont(F.huge); col(tell and rc or C.dim); lg.printf("?", x, cy - 36, w, "center")
    H.label(tell and "!! SIGNAL SPIKE !!" or "ASSEMBLING", x + w / 2 - (tell and 46 or 28), y + h - 30, tell and rc or C.dim)
    lg.pop()
    return
  end

  -- face up
  local age = ch.t - ft
  local s = math.min(1, age * 6)
  lg.push()
  lg.translate(cx, cy)
  lg.scale(0.6 + 0.4 * s + (hov and 0.03 or 0), 1)
  lg.translate(-cx, -cy)
  if d.r >= 3 then
    lg.setBlendMode("add")
    col(rc, 0.1 + 0.06 * math.sin(G.time * 4))
    lg.rectangle("fill", x - 10, y - 10, w + 20, h + 20)
    lg.setBlendMode("alpha")
  end
  col(C.panel); lg.rectangle("fill", x, y, w, h)
  if d.r >= 3 then H.hatch(x, y, w, h, rc, 0.08, 7) end
  H.hatch(x, y, w, 28, rc, 0.35, 5)
  H.brackets(x, y, w, h, 14, hov and C.white or rc)
  lg.setFont(F.m); col(rc); lg.printf(rr.name .. (d.r == 5 and " // MYTHIC" or ""), x, y + 5, w, "center")
  H.droneIcon(cx, y + 74, 1.8, rc)
  lg.setFont(F.huge); col(C.white); lg.printf(tostring(d.id), x, y + 94, w, "center")
  lg.setFont(F.s); col(rc); lg.printf(d.name or "", x, y + 148, w, "center")
  H.label("MK" .. d.mk .. "   //   " .. rr.slots .. " MODULE SLOTS", x + 16, y + 168, C.dim)
  H.label(string.format("POWER %s", fmt(G.dronePower(d))), x + 16, y + 184, C.white)
  H.label(string.format("OUTPUT +%d%%", math.floor(G.droneBonus(d) * 100 + 0.5)), x + 120, y + 184, C.white)
  for t, tid in ipairs(d.traits) do
    local desc = ""
    for _, tr in ipairs(D.TRAITS) do if tr.id == tid then desc = tr.desc end end
    lg.setFont(F.s); col(C.orange); lg.print(tid, x + 16, y + 202 + (t - 1) * 30)
    H.label(desc, x + 16, y + 218 + (t - 1) * 30, C.line)
  end
  if ready then
    local blink = math.floor(G.time * 3) % 2 == 0
    lg.setFont(F.s); col(hov and C.white or rc, (hov or blink) and 1 or 0.6)
    lg.printf(hov and "[ SELECT ]" or "SELECT", x, y + h - 26, w, "center")
  end
  lg.pop()
  if ready then H.addHit(x, y, w, h, function() G.pickCandidate(k) end) end
end

local function choice()
  local S = G.S
  local ch = G.choiceQueue[1]
  H.clearHits()
  dim(0.9)
  -- light rays behind the best revealed card
  lg.setFont(H.fonts.l); col(C.white)
  lg.printf("DRONE FABRICATION // SELECT 1 OF 3", 0, 140, 1280, "center")
  H.label(#G.choiceQueue > 1 and ("+" .. (#G.choiceQueue - 1) .. " MORE BATCHES QUEUED") or
    "UNCHOSEN UNITS ARE RECYCLED INTO PARTS", 640 - 120, 172, C.dim)
  if #S.drones >= G.bayCap() then
    lg.setFont(H.fonts.s); col(C.red); lg.printf("BAY FULL // SCRAP A DRONE FIRST (PRESS ESC TO CANCEL BATCH)", 0, 540, 1280, "center")
  end
  for k = 1, 3 do card(ch, k) end
  if not G.choiceReady(ch) then
    H.addHit(-2000, -2000, 6000, 6000, function()
      -- skip ahead: flip everything now
      local last = G.flipTime(ch, 3)
      for pos, k in ipairs(ch.order) do
        if not ch.flipped[k] then
          ch.flipped[k] = true
          G.revealFX(ch.cands[k].r, G.cardX(k), 360)
        end
      end
      ch.t = last + 0.2
    end)
  end
  local pe, pp = G.pityCaps()
  H.label("ELITE+ IN " .. math.max(1, pe - S.pity) .. "  //  PROTO+ IN " .. math.max(1, pp - S.pityP), 640 - 80, 560, C.orange)
end

----------------------------------------------------------------------
-- rank-up perk: pick 1 of 3
----------------------------------------------------------------------
local function perkCard(ch, k)
  local S = G.S
  local Fo = H.fonts
  local c = ch.cands[k]
  local gr = D.PERK_GRADE[c.grade]
  local gc = C[gr.col]
  local cx, cy = G.perkCardX(k), 360
  local w, h = 236, 300
  local x, y = cx - w / 2, cy - h / 2
  local ready = ch.t >= 0.75 * G.revealScale()
  local hov = ready and H.mouseIn(x, y, w, h)
  if not ch.flipped[k] then
    col(C.panel); lg.rectangle("fill", x, y, w, h)
    H.hatch(x, y, w, h, C.line, 0.08, 8)
    H.brackets(x, y, w, h, 14, C.line)
    lg.setFont(Fo.huge); col(C.dim); lg.printf("?", x, cy - 36, w, "center")
    return
  end
  if c.grade >= 2 then
    lg.setBlendMode("add")
    col(gc, 0.1 + 0.06 * math.sin(G.time * 4))
    lg.rectangle("fill", x - 10, y - 10, w + 20, h + 20)
    lg.setBlendMode("alpha")
  end
  col(C.panel); lg.rectangle("fill", x, y, w, h)
  if hov then col(gc, 0.1); lg.rectangle("fill", x, y, w, h) end
  H.hatch(x, y, w, 28, gc, 0.35, 5)
  H.brackets(x, y, w, h, 14, hov and C.white or gc)
  lg.setFont(Fo.m); col(gc); lg.printf(gr.name .. (gr.stacks > 1 and ("  x" .. gr.stacks) or ""), x, y + 5, w, "center")
  I.draw(c.def.icon, cx, y + 86, 26, gc)
  lg.setFont(Fo.l); col(C.white); lg.printf(c.def.name:upper(), x, y + 134, w, "center")
  H.richf(G.perkText(c.def, gr.stacks), x + 12, y + 172, w - 24, "center", gc, 1, Fo.m)
  local cur = S.perks[c.def.id] or 0
  H.label("STACKS " .. cur .. "  ->  " .. (cur + gr.stacks), x + w / 2 - 44, y + 228, C.dim)
  if ready then
    lg.setFont(Fo.s); col(hov and C.white or gc)
    lg.printf(hov and "[ INSTALL ]" or "INSTALL", x, y + h - 30, w, "center")
    H.addHit(x, y, w, h, function() G.pickPerk(k) end)
  end
end

local function perks()
  local S = G.S
  local ch = G.perkChoice
  H.clearHits()
  dim(0.9)
  lg.setFont(H.fonts.l); col(C.gold)
  if ch.boost then col(C[D.LOOT[D.MYTHIC].col]) end
  lg.printf(ch.boost and "MYTHIC TRANSMUTATION // EVERY CARD ENHANCED+" or ("RANK " .. S.rank .. " // CHOOSE AN OVERCLOCK"), 0, 132, 1280, "center")
  H.label(S.perkPoints .. " PERK POINT" .. (S.perkPoints > 1 and "S" or "") .. " AVAILABLE  //  PERKS ARE PERMANENT AND STACK", 640 - 170, 164, C.dim)
  for k = 1, 3 do perkCard(ch, k) end
  H.button(640 - 90, 528, 180, 30, "DECIDE LATER", true, G.closePerks, C.dim, H.fonts.xs)
end

function Ov.draw()
  if G.settingsOpen then
    SettingsUI.draw()
  elseif G.fiesta then
    Fiesta.draw()
  elseif G.altar then
    Altar.draw()
  elseif G.combine then
    Combine.draw()
  elseif G.report then report()
  elseif G.dailyPending then daily()
  elseif #G.choiceQueue > 0 then choice()
  elseif G.perkChoice then perks()
  elseif G.vaultOpen then Vault.draw() end
  tooltip()
end

return Ov
