-- REBOOT: prestige preview + protocol tree (5 branches, unlock left to right).
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local D = require "game.data"
local I = require "ui.icons"
local Set = require "game.settings"
local lg = V.lg
local C, col, fmt = H.C, H.col, H.fmt
local Sc = {}

local function pupg(id)
  for _, p in ipairs(D.PUPG) do if p.id == id then return p end end
end

local function prestige()
  local S = G.S
  local Fo = H.fonts
  local x, y, w, h = 24, 92, 420, 538
  local g = G.dmGain()
  local can = g >= 1
  col(C.panel, 0.95); lg.rectangle("fill", x, y, w, h)
  H.hatch(x, y, w, 30, C.red, 0.25, 6)
  H.brackets(x, y, w, h, 12, C.red)
  lg.setFont(Fo.m); col(C.red); lg.print("REBOOT PROTOCOL", x + 14, y + 6)
  H.label("CORE DATA IN BANK", x + 14, y + 44, C.dim)
  lg.setFont(Fo.xl); col(C.white); lg.print(fmt(S.dm), x + 14, y + 56)
  H.label("LIFETIME CORE DATA", x + 220, y + 44, C.dim)
  lg.setFont(Fo.xl); col(C.white); lg.print(fmt(S.dmTotal), x + 220, y + 56)
  -- the big preview
  col(C.red, can and 0.12 or 0.04); lg.rectangle("fill", x + 14, y + 104, w - 28, 120)
  H.brackets(x + 14, y + 104, w - 28, 120, 8, can and C.red or C.faint)
  H.label("REBOOT NOW FOR", x + 28, y + 114, C.dim)
  lg.setFont(Fo.huge); col(can and C.orange or C.faint); lg.printf("+" .. fmt(g), x, y + 126, w, "center")
  H.label("CORE DATA", x + w / 2 - 28, y + 186, can and C.orange or C.faint)
  H.label("CORE DATA OUTPUT BONUS  +" .. fmt(S.dmTotal * 5) .. "%  ->  +" .. fmt((S.dmTotal + g) * 5) .. "%", x + 28, y + 204, can and C.white or C.dim)
  local nextAt = ((G.dmPotential() + 1) ^ 2) * 1e9
  H.label("NEXT CORE DATA AT " .. fmt(nextAt) .. " LIFETIME ENERGY", x + 14, y + 236, C.dim)
  H.bar(x + 14, y + 252, w - 28, 4, S.totalEarned / nextAt, C.red)
  -- resets / keeps
  local ly = y + 270
  H.label("RESETS", x + 14, ly, C.red)
  H.label("KEEPS", x + 220, ly, C.line)
  local resets = {"Energy", "Units", "Tech upgrades", "Sector map"}
  local keeps = {"Rank + perks", "Drones + modules", "Rigs, logs, pass", "Zone, Core Data"}
  for k = 1, 4 do
    H.label("- " .. resets[k], x + 14, ly + 4 + k * 16, C.dim)
    H.label("+ " .. keeps[k], x + 220, ly + 4 + k * 16, C.dim)
  end
  local label = can and (G.novaConfirm > 0 and "CONFIRM REBOOT?" or "INITIATE REBOOT") or "NOT ENOUGH ENERGY YET"
  H.button(x + 14, y + h - 84, w - 28, 66, label, can, function()
    if G.novaConfirm > 0 or not Set.v.confirmReboot then G.novaConfirm = 0; G.doReboot()
    else G.novaConfirm = 3; FX.play("signal", 0.6, 0.6) end
  end, C.red, Fo.l, nil, can)
end

local function tree()
  local S = G.S
  local Fo = H.fonts
  local x0, y0 = 460, 92
  H.label("PROTOCOL TREE // SPEND CORE DATA // EACH BRANCH UNLOCKS LEFT TO RIGHT", x0, y0, C.white)
  local rowH, nw, nh = 108, 150, 84
  for b, br in ipairs(D.TREE) do
    local ry = y0 + 20 + (b - 1) * rowH
    -- branch label
    col(C.panel, 0.8); lg.rectangle("fill", x0, ry, 96, nh)
    H.brackets(x0, ry, 96, nh, 6, C.line, 0.6)
    I.draw(br.icon, x0 + 48, ry + 30, 12, C.line)
    lg.setFont(Fo.xs); col(C.white); lg.printf(br.name, x0, ry + 58, 96, "center")
    for k, id in ipairs(br.ids) do
      local p = pupg(id)
      local nx = x0 + 112 + (k - 1) * (nw + 12)
      local owned = S.pupg[id]
      local parentOk = k == 1 or S.pupg[br.ids[k - 1]]
      local can = parentOk and not owned and S.dm >= p.cost
      -- connector
      if k > 1 then
        col(owned and C.line or (parentOk and C.dim or C.faint), owned and 0.9 or 0.5)
        lg.setLineWidth(owned and 2 or 1)
        lg.line(nx - 12, ry + nh / 2, nx, ry + nh / 2)
        lg.setLineWidth(1)
      else
        col(C.dim, 0.5); lg.line(nx - 12, ry + nh / 2, nx, ry + nh / 2)
      end
      local hov = H.mouseIn(nx, ry, nw, nh)
      col(C.panel, 0.95); lg.rectangle("fill", nx, ry, nw, nh)
      if owned then col(C.line, 0.16); lg.rectangle("fill", nx, ry, nw, nh)
      elseif can then col(C.orange, 0.1 + 0.06 * math.sin(G.time * 5 + b + k)); lg.rectangle("fill", nx, ry, nw, nh) end
      if not parentOk then H.hatch(nx, ry, nw, nh, C.faint, 0.3, 7) end
      local bc = owned and C.line or (can and C.orange or (parentOk and C.white or C.faint))
      H.brackets(nx, ry, nw, nh, 6, hov and C.white or bc)
      lg.setFont(Fo.s); col(owned and C.line or (parentOk and C.white or C.dim))
      lg.printf(p.name:upper(), nx + 8, ry + 8, nw - 16, "left")
      if owned then
        I.draw("check", nx + nw - 18, ry + nh - 16, 6, C.line)
        H.label("INSTALLED", nx + 8, ry + nh - 20, C.line)
      elseif not parentOk then
        I.draw("lock", nx + nw - 16, ry + nh - 18, 6, C.faint)
        H.label(fmt(p.cost) .. " CD", nx + 8, ry + nh - 20, C.faint)
      else
        lg.setFont(Fo.s); col(can and C.orange or C.red); lg.print(fmt(p.cost) .. " CD", nx + 8, ry + nh - 22)
      end
      if hov then H.setTip(p.name:upper() .. (owned and " // INSTALLED" or ""), p.desc .. "  //  " .. fmt(p.cost) .. " CORE DATA" ..
        (parentOk and "" or "  //  requires the previous node")) end
      H.addHit(nx, ry, nw, nh, function()
        if not can then FX.play("err") return end
        S.dm = S.dm - p.cost
        S.pupg[id] = true
        G.recalc()
        local mx, my = V.mouse()
        FX.burst(mx, my, 50, C.orange, 320)
        FX.ray(mx, my, C.orange, 1, 200)
        FX.play("unlock")
        FX.toast("PROTOCOL INSTALLED // " .. p.name:upper(), p.desc, C.orange)
      end)
    end
  end
end

function Sc.draw()
  local Fo = H.fonts
  lg.setFont(Fo.l); col(C.white); lg.print("REBOOT", 24, 58)
  prestige()
  tree()
end

return Sc
