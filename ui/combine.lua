-- Drone fusion: 3 drones of one rarity -> 1 drone of the next rarity.
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local I = require "ui.icons"
local lg = V.lg
local C, col, fmt = H.C, H.col, H.fmt
local Cb = {}

local X0, Y0, W, HH = 150, 92, 980, 540

function G.openCombine(ids)
  local first = ids[1] and G.findDrone(ids[1])
  if not first then FX.play("err") return end
  if first.r >= #D.RARITY then
    FX.toast("FUSION UNAVAILABLE", D.RARITY[#D.RARITY].name .. " is the highest rarity.", C.red); FX.play("err") return
  end
  G.combine = {r = first.r, slots = {}, phase = "select", t = 0}
  for k, id in ipairs(ids) do
    local d = G.findDrone(id)
    if k <= 3 and G.canCombine(d) and d.r == first.r then G.combine.slots[#G.combine.slots + 1] = id end
  end
  FX.play("unlock", 1.3)
end

local function slotDrones()
  local ds = {}
  for _, id in ipairs(G.combine.slots) do ds[#ds + 1] = G.findDrone(id) end
  return ds
end

local function autofill()
  local cb = G.combine
  local ex = {}
  for _, id in ipairs(cb.slots) do ex[id] = true end
  for _, d in ipairs(G.combineEligible(cb.r, ex)) do
    if #cb.slots >= 3 then break end
    cb.slots[#cb.slots + 1] = d.id
  end
  FX.play("tick", 1.2)
end

local function fuse()
  local cb = G.combine
  cb.phase, cb.t = "fusing", 0
  FX.play("surge", 1.2)
end

-- mini drone card used in slots and the picker
local function droneCard(d, x, y, w, h, big)
  local rr = D.RARITY[d.r]
  local rc = C[rr.col]
  col(C.panel, 0.98); lg.rectangle("fill", x, y, w, h)
  if d.r == #D.RARITY then H.holoFX(x, y, w, h) end
  if d.r >= 3 then H.hatch(x + 8, y + 2, w - 16, 5, rc, 0.8, 4) else col(rc, 0.8); lg.rectangle("fill", x + 8, y + 2, w - 16, 3) end
  H.brackets(x, y, w, h, 6, rc)
  if big then
    H.droneIcon(x + w / 2, y + 52, 1.4, rc)
    lg.setFont(H.fonts.l); col(C.white); lg.printf(tostring(d.id), x, y + 92, w, "center")
    lg.setFont(H.fonts.s); col(rc); lg.printf(d.name or "", x, y + 120, w, "center")
    H.label(rr.name .. "  MK" .. d.mk .. "  LV " .. d.lvl, x + w / 2 - 50, y + 142, C.dim)
    H.label("POWER " .. fmt(G.dronePower(d)), x + 12, y + h - 40, C.white)
    H.label(table.concat(d.traits, " + "), x + 12, y + h - 24, C.orange)
  else
    lg.setFont(H.fonts.s); col(C.white); lg.print(tostring(d.id), x + 8, y + 8)
    H.label(H.fit(H.fonts.xs, d.name or "", w - 50), x + 44, y + 11, rc)
    H.label("MK" .. d.mk .. " LV" .. d.lvl .. "  PWR " .. fmt(G.dronePower(d)), x + 8, y + 28, C.dim)
  end
end

function Cb.draw()
  local cb = G.combine
  local S = G.S
  local Fo = H.fonts
  local dt = love.timer.getDelta()
  cb.t = cb.t + dt
  H.clearHits()
  local x0, y0, x1, y1 = V.extents()
  col(C.bg, 0.9); lg.rectangle("fill", x0, y0, x1 - x0, y1 - y0)
  col(C.panel, 0.98); lg.rectangle("fill", X0, Y0, W, HH)
  H.hatch(X0, Y0, W, 36, C.orange, 0.12, 7)
  H.brackets(X0, Y0, W, HH, 16, C.orange)
  lg.setFont(Fo.l); col(C.orange); lg.print("DRONE FUSION", X0 + 18, Y0 + 6)
  H.label("3 DRONES OF ONE RARITY  >>  1 DRONE OF THE NEXT RARITY  //  MODULES RETURN TO THE VAULT", X0 + 200, Y0 + 14, C.dim)

  local cur = D.RARITY[cb.r]
  local nxt = D.RARITY[cb.r + 1]
  local cc, nc = C[cur.col], C[nxt.col]
  local sw, sh = 168, 220
  local sy = Y0 + 56
  local ds = slotDrones()

  ------------------------------------------------------------------ result phase
  if cb.phase == "done" then
    local d = cb.result
    local cx = 640
    lg.setFont(Fo.dxl); col(nc); lg.printf("FUSION COMPLETE", X0, sy, W, "center")
    droneCard(d, cx - 120, sy + 50, 240, 260, true)
    H.label("+" .. math.floor(G.droneBonus(d) * 100 + 0.5) .. "% DRONE YIELD   //   " .. D.RARITY[d.r].slots .. " MODULE SLOTS", cx - 140, sy + 320, C.line)
    H.button(cx - 110, Y0 + HH - 64, 220, 44, "CONTINUE", true, function() G.combine = nil end, nc, Fo.m, nil, true)
    return
  end

  ------------------------------------------------------------------ fusing animation
  if cb.phase == "fusing" then
    local p = math.min(1, cb.t / 1.3)
    local e = p * p
    local cx, cy = 640, sy + sh / 2
    for k, d in ipairs(ds) do
      local bx = X0 + 40 + (k - 1) * (sw + 24) + sw / 2
      local x = bx + (cx - bx) * e + H.rnd(-6, 6) * p
      local y = cy + H.rnd(-6, 6) * p
      lg.push(); lg.translate(x, y); lg.scale(1 - e * 0.6); lg.translate(-sw / 2, -sh / 2)
      droneCard(d, 0, 0, sw, sh, true)
      lg.pop()
    end
    lg.setBlendMode("add")
    col(nc, e * 0.5); lg.circle("fill", cx, cy, 30 + e * 120, 48)
    lg.setBlendMode("alpha")
    if math.floor(cb.t * 12) ~= math.floor((cb.t - dt) * 12) then FX.play("tick", 0.8 + p, 0.6) end
    if cb.t >= 1.3 then
      local ids = {}
      for _, d in ipairs(ds) do ids[#ids + 1] = d.id end
      local nd, err = G.combineDrones(ids)
      if not nd then
        FX.toast("FUSION FAILED", err, C.red); G.combine = nil; return
      end
      cb.result, cb.phase = nd, "done"
      G.revealFX(nd.r, cx, cy)
      FX.toast("FUSION // " .. D.RARITY[nd.r].name .. " " .. G.droneLabel(nd), "Three " .. cur.name ..
        " drones became one " .. D.RARITY[nd.r].name .. ".", nc)
    end
    return
  end

  ------------------------------------------------------------------ selection
  for k = 1, 3 do
    local x = X0 + 40 + (k - 1) * (sw + 24)
    local d = ds[k]
    if d then
      local hov = H.mouseIn(x, sy, sw, sh)
      droneCard(d, x, sy, sw, sh, true)
      if hov then
        col(C.red, 0.15); lg.rectangle("fill", x, sy, sw, sh)
        lg.setFont(Fo.xs); col(C.red); lg.printf("CLICK TO REMOVE", x, sy + sh - 56, sw, "center")
      end
      H.addHit(x, sy, sw, sh, function() table.remove(cb.slots, k); FX.play("tick", 0.8) end)
    else
      col(cc, 0.05); lg.rectangle("fill", x, sy, sw, sh)
      H.hatch(x, sy, sw, sh, cc, 0.08, 9)
      H.brackets(x, sy, sw, sh, 8, cc, 0.5)
      lg.setFont(Fo.huge); col(cc, 0.35); lg.printf("+", x, sy + 70, sw, "center")
      H.label("SLOT " .. k .. " // " .. cur.name, x + sw / 2 - 40, sy + sh - 30, cc)
    end
    if k < 3 then lg.setFont(Fo.l); col(C.dim); lg.printf("+", x + sw, sy + sh / 2 - 14, 24, "center") end
  end
  -- arrow + preview
  local ax = X0 + 40 + 3 * (sw + 24) - 10
  col(nc, 0.7)
  for k = 0, 2 do
    local px = ax + k * 14 + (G.time * 30) % 14
    lg.polygon("fill", px, sy + sh / 2 - 8, px + 9, sy + sh / 2, px, sy + sh / 2 + 8)
  end
  local rx = ax + 56
  local rw = X0 + W - 30 - rx
  col(nc, 0.08 + 0.05 * math.sin(G.time * 4)); lg.rectangle("fill", rx, sy, rw, sh)
  H.hatch(rx, sy, rw, 30, nc, 0.3, 6)
  H.brackets(rx, sy, rw, sh, 10, nc)
  lg.setFont(Fo.m); col(nc); lg.printf("RESULT // " .. nxt.name, rx, sy + 6, rw, "center")
  H.droneIcon(rx + rw / 2, sy + 76, 1.5, nc)
  if #ds > 0 then
    local p = G.combinePreview(ds)
    H.label("MK" .. p.mk .. "  //  LV " .. p.lvl .. "  (best of the inputs)", rx + 14, sy + 120, C.white)
    H.label(p.slots .. " module slots  //  " .. p.traits .. " traits (inherited)", rx + 14, sy + 136, C.line)
    H.label("POWER x" .. string.format("%.1f", nxt.power / cur.power) .. "   DRONE YIELD x" ..
      string.format("%.1f", nxt.bonus / cur.bonus), rx + 14, sy + 152, C.orange)
    H.label("Keeps the callsign of slot 1: " .. (ds[1].name or ""), rx + 14, sy + 176, C.dim)
  end

  -- picker
  local py = sy + sh + 18
  local ex = {}
  for _, id in ipairs(cb.slots) do ex[id] = true end
  local el = G.combineEligible(cb.r, ex)
  H.label("ELIGIBLE " .. cur.name .. " DRONES (IDLE OR HUNTING) // " .. #el .. "  //  CLICK TO ADD", X0 + 40, py, C.white)
  local cw, ch, cols = 148, 46, 6
  local maxN = cols * 2
  for n = 1, math.min(#el, maxN) do
    local d = el[n]
    local c, r = (n - 1) % cols, math.floor((n - 1) / cols)
    local x, y = X0 + 40 + c * (cw + 8), py + 18 + r * (ch + 8)
    droneCard(d, x, y, cw, ch)
    if H.mouseIn(x, y, cw, ch) then col(C.white, 0.08); lg.rectangle("fill", x, y, cw, ch) end
    H.addHit(x, y, cw, ch, function()
      if #cb.slots < 3 then cb.slots[#cb.slots + 1] = d.id; FX.play("tick", 1.3) else FX.play("err") end
    end)
  end
  if #el > maxN then H.label("+" .. (#el - maxN) .. " MORE", X0 + 40, py + 128, C.dim) end
  if #el == 0 and #ds < 3 then
    H.label("No other " .. cur.name .. " drones available. Fabricate more or wait for missions to finish.", X0 + 40, py + 30, C.red)
  end

  -- actions
  local by = Y0 + HH - 56
  H.button(X0 + W - 520, by, 150, 40, "AUTO-FILL", #ds < 3 and #el > 0, autofill, C.line, Fo.s)
  H.button(X0 + W - 362, by, 200, 40, #ds == 3 and "FUSE" or ("FUSE (" .. #ds .. "/3)"), #ds == 3, fuse, C.orange, Fo.m, nil, #ds == 3)
  H.button(X0 + W - 154, by, 124, 40, "CANCEL", true, function() G.combine = nil end, C.dim, Fo.s)
end

return Cb
