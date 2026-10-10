-- Small vector icon set (drawn with lines so they match the HUD style).
local V = require "lib.view"
local H = require "lib.hud"
local lg = V.lg
local col = H.col
local TAU = math.pi * 2
local I = {}

local draw = {}

draw.core = function(x, y, s)
  lg.circle("line", x, y, s, 24)
  lg.polygon("line", x - s * 0.55, y - s * 0.3, x + s * 0.55, y - s * 0.3, x, y + s * 0.55)
end
draw.build = function(x, y, s)
  lg.rectangle("line", x - s, y + s * 0.2, s * 2, s * 0.75)
  lg.rectangle("line", x - s * 0.65, y - s * 0.45, s * 1.3, s * 0.6)
  lg.rectangle("line", x - s * 0.3, y - s, s * 0.6, s * 0.5)
end
draw.rigs = function(x, y, s)
  lg.polygon("line", x - s, y - s * 0.8, x + s, y - s * 0.8, x + s * 0.5, y + s * 0.1, x - s * 0.5, y + s * 0.1)
  lg.circle("line", x, y + s * 0.65, s * 0.3, 12)
  lg.line(x, y + s * 0.1, x, y + s * 0.35)
end
draw.hangar = function(x, y, s)
  local k = s / 22
  lg.circle("line", x, y, 11 * k * 1.3, 16)
  lg.circle("line", x, y, 4 * k * 1.3, 10)
  lg.rectangle("line", x - s, y - s * 0.28, s * 0.42, s * 0.56)
  lg.rectangle("line", x + s * 0.58, y - s * 0.28, s * 0.42, s * 0.56)
end
draw.map = function(x, y, s)
  lg.rectangle("line", x - s, y - s, s * 2, s * 2)
  lg.line(x - s / 3, y - s, x - s / 3, y + s)
  lg.line(x + s / 3, y - s, x + s / 3, y + s)
  lg.line(x - s, y - s / 3, x + s, y - s / 3)
  lg.line(x - s, y + s / 3, x + s, y + s / 3)
  lg.polygon("fill", x + s / 3, y - s / 3 - 4, x + s / 3 + 4, y - s / 3, x + s / 3, y - s / 3 + 4, x + s / 3 - 4, y - s / 3)
end
draw.ops = function(x, y, s)
  lg.rectangle("line", x - s * 0.8, y - s, s * 1.6, s * 2)
  lg.rectangle("line", x - s * 0.35, y - s * 1.15, s * 0.7, s * 0.35)
  lg.line(x - s * 0.45, y - s * 0.1, x - s * 0.15, y + s * 0.25, x + s * 0.45, y - s * 0.45)
  lg.line(x - s * 0.45, y + s * 0.6, x + s * 0.45, y + s * 0.6)
end
draw.nova = function(x, y, s)
  lg.arc("line", "open", x, y, s, -math.pi * 0.35, math.pi * 1.45, 24)
  local a = -math.pi * 0.35
  local ex, ey = x + math.cos(a) * s, y + math.sin(a) * s
  lg.polygon("fill", ex - 5, ey - 3, ex + 4, ey - 6, ex + 2, ey + 4)
  lg.circle("fill", x, y, s * 0.2, 8)
end
draw.archive = function(x, y, s)
  for k = 0, 2 do
    local yy = y - s * 0.7 + k * s * 0.7
    lg.ellipse("line", x, yy, s, s * 0.32, 20)
  end
  lg.line(x - s, y - s * 0.7, x - s, y + s * 0.7)
  lg.line(x + s, y - s * 0.7, x + s, y + s * 0.7)
end
draw.energy = function(x, y, s)
  lg.polygon("line", x + s * 0.2, y - s, x - s * 0.6, y + s * 0.15, x - s * 0.05, y + s * 0.15,
    x - s * 0.25, y + s, x + s * 0.6, y - s * 0.2, x + s * 0.05, y - s * 0.2)
end
draw.hydro = function(x, y, s)
  lg.arc("line", "open", x, y + s * 0.3, s * 0.65, -0.35, math.pi + 0.35, 16)
  lg.line(x - s * 0.61, y + s * 0.08, x, y - s, x + s * 0.61, y + s * 0.08)
end
draw.parts = function(x, y, s)
  lg.circle("line", x, y, s * 0.62, 16)
  lg.circle("line", x, y, s * 0.25, 10)
  for k = 0, 7 do
    local a = k / 8 * TAU
    lg.line(x + math.cos(a) * s * 0.62, y + math.sin(a) * s * 0.62, x + math.cos(a) * s, y + math.sin(a) * s)
  end
end
draw.token = function(x, y, s)
  local p, q = {}, {}
  for k = 0, 5 do
    local a = k / 6 * TAU + math.pi / 6
    p[#p + 1] = x + math.cos(a) * s; p[#p + 1] = y + math.sin(a) * s
    q[#q + 1] = x + math.cos(a) * s * 0.5; q[#q + 1] = y + math.sin(a) * s * 0.5
  end
  lg.polygon("line", p)
  lg.polygon("line", q)
end
draw.cd = function(x, y, s)
  lg.polygon("line", x, y - s, x + s * 0.8, y, x, y + s, x - s * 0.8, y)
  lg.line(x - s * 0.8, y, x + s * 0.8, y)
  lg.line(x, y - s, x, y + s)
end
draw.lock = function(x, y, s)
  lg.rectangle("line", x - s * 0.7, y - s * 0.1, s * 1.4, s * 1.1)
  lg.arc("line", "open", x, y - s * 0.1, s * 0.45, math.pi, TAU, 12)
end
draw.crate = function(x, y, s)
  lg.rectangle("line", x - s, y - s * 0.75, s * 2, s * 1.5)
  lg.line(x - s, y - s * 0.75, x + s, y + s * 0.75)
  lg.line(x + s, y - s * 0.75, x - s, y + s * 0.75)
end
draw.perk = function(x, y, s)
  lg.line(x - s, y + s * 0.1, x, y - s * 0.7, x + s, y + s * 0.1)
  lg.line(x - s, y + s * 0.8, x, y, x + s, y + s * 0.8)
end
draw.event = function(x, y, s)
  lg.circle("line", x, y, s, 20)
  lg.line(x, y, x, y - s * 0.65)
  lg.line(x, y, x + s * 0.5, y + s * 0.2)
end
draw.xp = function(x, y, s)
  local p = {}
  for k = 0, 9 do
    local a = -math.pi / 2 + k / 10 * TAU
    local r = k % 2 == 0 and s or s * 0.45
    p[#p + 1] = x + math.cos(a) * r; p[#p + 1] = y + math.sin(a) * r
  end
  lg.polygon("line", p)
end
draw.scav = function(x, y, s)
  lg.polygon("line", x - s, y - s * 0.8, x + s, y - s * 0.8, x + s, y + s * 0.1, x, y + s, x - s, y + s * 0.1)
  lg.line(x - s * 0.5, y - s * 0.3, x, y + s * 0.25, x + s * 0.5, y - s * 0.3)
end
draw.audio = function(x, y, s)
  lg.polygon("line", x - s, y - s * 0.35, x - s * 0.45, y - s * 0.35, x + s * 0.1, y - s, x + s * 0.1, y + s,
    x - s * 0.45, y + s * 0.35, x - s, y + s * 0.35)
  lg.arc("line", "open", x + s * 0.2, y, s * 0.55, -0.8, 0.8, 8)
  lg.arc("line", "open", x + s * 0.2, y, s * 0.95, -0.8, 0.8, 8)
end
draw.full = function(x, y, s)
  H.brackets(x - s, y - s * 0.75, s * 2, s * 1.5, s * 0.6, {1, 1, 1}, nil)
end
draw.check = function(x, y, s)
  lg.line(x - s, y, x - s * 0.3, y + s * 0.7, x + s, y - s * 0.7)
end

function I.draw(name, x, y, s, c, a)
  local f = draw[name]
  if not f then return end
  col(c or H.C.line, a or 1)
  if name == "full" then
    -- brackets() sets its own color
    H.brackets(x - s, y - s * 0.75, s * 2, s * 1.5, s * 0.6, c or H.C.line, a)
    return
  end
  f(x, y, s)
end

return I
