-- MYTHIC ALTAR: feed 10 MYTHIC modules into the ring, transmute them into a boosted perk choice.
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local lg = V.lg
local C, col = H.C, H.col
local TAU = math.pi * 2
local Al = {}

local X0, Y0, W, HH = 190, 80, 900, 550
local CX, CY, RING = 640, 318, 150

local function close() G.altar = nil; FX.play("tick", 0.8) end

local function socket(k)
  local a = -math.pi / 2 + (k - 1) / G.ALTAR_COST * TAU + G.time * 0.12
  return CX + math.cos(a) * RING, CY + math.sin(a) * RING
end

function Al.draw()
  local A, S, Fo = G.altar, G.S, H.fonts
  local dt = love.timer.getDelta()
  A.t = A.t + dt
  H.clearHits()
  local mc = C[D.LOOT[D.MYTHIC].col]
  local x0, y0, x1, y1 = V.extents()
  col(C.bg, 0.93); lg.rectangle("fill", x0, y0, x1 - x0, y1 - y0)
  col(C.panel, 0.98); lg.rectangle("fill", X0, Y0, W, HH)
  -- slow rays behind the ring
  lg.push("all"); lg.intersectScissor(X0, Y0, W, HH)
  lg.setBlendMode("add")
  local spin = A.phase == "burn" and A.t * A.t * 3 or 0
  for k = 0, 11 do
    local an = G.time * 0.1 + spin + k / 12 * TAU
    col(mc, A.phase == "burn" and 0.03 + A.t * 0.03 or 0.03)
    lg.polygon("fill", CX, CY, CX + math.cos(an - 0.07) * 700, CY + math.sin(an - 0.07) * 700,
      CX + math.cos(an + 0.07) * 700, CY + math.sin(an + 0.07) * 700)
  end
  lg.pop()
  H.hatch(X0, Y0, W, 40, mc, 0.15, 7)
  H.brackets(X0, Y0, W, HH, 16, mc)
  lg.setFont(Fo.l); col(mc); lg.print("MYTHIC ALTAR", X0 + 18, Y0 + 7)
  H.label(G.ALTAR_COST .. " MYTHIC MODULES  >>  1 PERK POINT  //  EVERY CARD ENHANCED OR PRIME", X0 + 230, Y0 + 15, C.dim)

  local list = G.altarMythics()
  local have = #list
  -- the ring
  col(mc, 0.25); lg.circle("line", CX, CY, RING, 96)
  H.tickRing(CX, CY, RING + 22, 60, 4, -G.time * 0.05, mc, 0.4, 10)
  local filled = math.min(have, G.ALTAR_COST)
  for k = 1, G.ALTAR_COST do
    local sx, sy = socket(k)
    if A.phase == "burn" then
      -- modules spiral into the core
      local p = math.min(1, A.t / 1.5)
      local e = p * p
      local a = math.atan2(sy - CY, sx - CX) + e * 4
      local r = RING * (1 - e)
      sx, sy = CX + math.cos(a) * r, CY + math.sin(a) * r
      col(mc, 1 - e * 0.5); lg.rectangle("fill", sx - 9, sy - 9, 18, 18)
    else
      local on = k <= filled
      col(on and mc or C.faint, on and 0.3 or 0.15); lg.rectangle("fill", sx - 16, sy - 16, 32, 32)
      H.brackets(sx - 16, sy - 16, 32, 32, 5, on and mc or C.faint, on and 1 or 0.5)
      if on then lg.setFont(Fo.xs); col(C.white); lg.printf(list[k].t, sx - 16, sy - 6, 32, "center") end
    end
  end
  -- core of the altar
  local pulse = 0.5 + 0.5 * math.sin(G.time * 3)
  local full = have >= G.ALTAR_COST
  lg.setBlendMode("add")
  col(mc, (full and 0.18 or 0.06) + (A.phase == "burn" and A.t * 0.3 or 0) + 0.06 * pulse)
  lg.circle("fill", CX, CY, 60 + (A.phase == "burn" and A.t * 30 or 0), 64)
  lg.setBlendMode("alpha")
  lg.setFont(Fo.huge); col(full and mc or C.dim)
  lg.printf(filled .. "/" .. G.ALTAR_COST, CX - 100, CY - 26, 200, "center")

  if A.phase == "burn" then
    if math.floor(A.t * 10) ~= math.floor((A.t - dt) * 10) then FX.play("tick", 0.6 + A.t, 0.6) end
    if A.t >= 1.6 then
      G.revealFX(5, CX, CY, true, "TRANSMUTED")
      FX.toast("MYTHIC TRANSMUTATION", A.n .. " perk point" .. (A.n > 1 and "s" or "") .. " forged. Every card is ENHANCED or PRIME.", mc)
      G.altar = nil
      G.openPerkChoice()
    end
    return
  end

  -- info + actions
  local equipped = 0
  for _, d in ipairs(S.drones) do for _, m in ipairs(d.mods) do if m.r == D.MYTHIC then equipped = equipped + 1 end end end
  local iy = CY + RING + 40
  lg.setFont(Fo.s); col(C.white)
  lg.printf(have .. " MYTHIC MODULE" .. (have == 1 and "" or "S") .. " IN THE VAULT  //  " .. equipped .. " EQUIPPED ON DRONES (NOT USED)", X0, iy, W, "center")
  H.label("The weakest mythics are fed first. Boosted perk points waiting: " .. (S.mythicRolls or 0) ..
    "   //   Transmutations: " .. (S.transmutes or 0), X0 + 160, iy + 22, C.dim)
  local maxN = math.floor(have / G.ALTAR_COST)
  local by = Y0 + HH - 62
  local ok = maxN >= 1
  if ok then col(mc, 0.08 + 0.1 * pulse); lg.rectangle("fill", X0 + 30 - 4, by - 4, 268, 52) end
  H.button(X0 + 30, by, 260, 44, ok and "TRANSMUTE // 1 PERK" or ("NEED " .. G.ALTAR_COST - have % G.ALTAR_COST .. " MORE"), ok,
    function() G.altarTransmute(1) end, mc, Fo.m, nil, ok)
  H.button(X0 + 306, by, 260, 44, "TRANSMUTE ALL // " .. maxN .. " PERKS", maxN >= 2, function() G.altarTransmute(maxN) end, mc, Fo.s)
  H.button(X0 + W - 170, by, 140, 44, "CLOSE", true, close, C.dim, Fo.s)
end

function Al.escape() if G.altar and G.altar.phase ~= "burn" then close() end end

return Al
