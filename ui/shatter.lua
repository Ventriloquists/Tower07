-- Zone transition: the tactical map freezes, cracks from an impact point and shatters like glass
-- (Final Fantasy battle-intro style). The old map is a screenshot cut into radial shards; the new
-- map is already live underneath while the shards burst toward the viewer and fall away.
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local G = require "game.core"
local lg = V.lg
local C, col, rnd = H.C, H.col, H.rnd
local TAU = math.pi * 2
local Sh = {}

G.shatter = nil

-- clip a convex polygon {x1,y1,x2,y2,...} to an axis-aligned rectangle (Sutherland-Hodgman)
local function clip(poly, rx, ry, rw, rh)
  local function edge(pts, inside, cross)
    local out = {}
    local n = #pts / 2
    for i = 1, n do
      local ax, ay = pts[i * 2 - 1], pts[i * 2]
      local j = i % n + 1
      local bx, by = pts[j * 2 - 1], pts[j * 2]
      local ia, ib = inside(ax, ay), inside(bx, by)
      if ia then out[#out + 1] = ax; out[#out + 1] = ay end
      if ia ~= ib then local x, y = cross(ax, ay, bx, by); out[#out + 1] = x; out[#out + 1] = y end
    end
    return out
  end
  local function atX(X) return function(ax, ay, bx, by) local t = (X - ax) / (bx - ax) return X, ay + (by - ay) * t end end
  local function atY(Y) return function(ax, ay, bx, by) local t = (Y - ay) / (by - ay) return ax + (bx - ax) * t, Y end end
  local p = poly
  p = edge(p, function(x) return x >= rx end, atX(rx)); if #p < 6 then return p end
  p = edge(p, function(x) return x <= rx + rw end, atX(rx + rw)); if #p < 6 then return p end
  p = edge(p, function(_, y) return y >= ry end, atY(ry)); if #p < 6 then return p end
  p = edge(p, function(_, y) return y <= ry + rh end, atY(ry + rh))
  return p
end

function Sh.start(img)
  local T = G.TAC
  local rx, ry, rw, rh = T.MX0, T.MY0, G.MW * T.CS, G.MH * T.CS
  local ix, iy = rx + rw / 2 + rnd(-60, 60), ry + rh / 2 + rnd(-40, 40)
  -- radial crack web: jittered rays x jittered rings
  local rays = 15
  local rings = {16, 42, 80, 130, 195, 275, 370, 480, 620}
  local ang = {}
  for j = 1, rays do ang[j] = (j - 1) / rays * TAU + rnd(-0.12, 0.12) end
  local P = {}
  for k, r in ipairs(rings) do
    P[k] = {}
    for j = 1, rays do
      local rr = r * rnd(0.86, 1.14)
      P[k][j] = {ix + math.cos(ang[j]) * rr, iy + math.sin(ang[j]) * rr}
    end
  end
  local polys = {}
  for j = 1, rays do
    local j2 = j % rays + 1
    polys[#polys + 1] = {ix, iy, P[1][j][1], P[1][j][2], P[1][j2][1], P[1][j2][2]}
    for k = 1, #rings - 1 do
      local a, b, c, d = P[k][j], P[k + 1][j], P[k + 1][j2], P[k][j2]
      if love.math.random() < 0.45 then -- some cells split diagonally for irregular glass
        polys[#polys + 1] = {a[1], a[2], b[1], b[2], c[1], c[2]}
        polys[#polys + 1] = {a[1], a[2], c[1], c[2], d[1], d[2]}
      else
        polys[#polys + 1] = {a[1], a[2], b[1], b[2], c[1], c[2], d[1], d[2]}
      end
    end
  end
  local shards = {}
  local iw, ih = img:getDimensions()
  for _, poly in ipairs(polys) do
    local p = clip(poly, rx, ry, rw, rh)
    local n = #p / 2
    if n >= 3 then
      local cx, cy = 0, 0
      for i = 1, n do cx, cy = cx + p[i * 2 - 1], cy + p[i * 2] end
      cx, cy = cx / n, cy / n
      local verts, outline = {}, {}
      for i = 1, n do
        local x, y = p[i * 2 - 1], p[i * 2]
        -- texture coords: virtual -> window pixels -> image (handles letterboxing and HiDPI)
        local u = (V.ox + x * V.s) / V.winW
        local v = (V.oy + y * V.s) / V.winH
        verts[i] = {x - cx, y - cy, u, v}
        outline[#outline + 1] = x - cx; outline[#outline + 1] = y - cy
      end
      local mesh = love.graphics.newMesh(verts, "fan", "static")
      mesh:setTexture(img)
      local dx, dy = cx - ix, cy - iy
      local dist = math.sqrt(dx * dx + dy * dy)
      local nx, ny = dx / math.max(1, dist), dy / math.max(1, dist)
      local sp = rnd(90, 260) + math.max(0, 420 - dist) * 0.7
      shards[#shards + 1] = {mesh = mesh, outline = outline, x = cx, y = cy, ox = cx, oy = cy, dist = dist,
        vx = nx * sp + rnd(-40, 40), vy = ny * sp - rnd(60, 220), rot = 0, vr = rnd(-4, 4),
        s = 1, vs = rnd(0.4, 1.4), launch = 0.55 + dist * 0.00045 + rnd(0, 0.05)}
    end
  end
  table.sort(shards, function(a, b) return a.vs < b.vs end) -- shards flying "closer" draw on top
  G.shatter = {t = 0, img = img, shards = shards, ix = ix, iy = iy, rect = {rx, ry, rw, rh}, cracked = false, burst = false}
  FX.play("crack", 1.0)
end

-- ask for the transition: capture the frame first, then advance the zone underneath
function G.requestAdvance()
  if G.shatterPending or G.shatter then return end
  if FX.reduced or G.tab ~= "map" then G.advanceZone() return end
  G.shatterPending = true
  love.graphics.captureScreenshot(function(data)
    G.shatterPending = false
    local ok, img = pcall(love.graphics.newImage, data)
    G.advanceZone()
    if ok and img then Sh.start(img) end
  end)
end

function Sh.update(dt)
  local s = G.shatter
  if not s then return end
  s.t = s.t + dt
  if not s.cracked and s.t > 0.22 then s.cracked = true; FX.play("crack", 0.8) end
  if not s.burst and s.t > 0.55 then
    s.burst = true
    FX.play("shatter", 1)
    FX.flashTo(C.white, 0.55)
    FX.shake = math.max(FX.shake, 18)
    FX.burst(s.ix, s.iy, 120, C.white, 700, 2)
    FX.burst(s.ix, s.iy, 60, C.line, 500, 3)
  end
  for _, p in ipairs(s.shards) do
    if s.t > p.launch then
      p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
      p.vy = p.vy + 1100 * dt
      p.rot = p.rot + p.vr * dt
      p.s = p.s + p.vs * dt
    end
  end
  if s.t > 2.6 then
    for _, p in ipairs(s.shards) do p.mesh:release() end
    s.img:release()
    G.shatter = nil
  end
end

function Sh.draw()
  local s = G.shatter
  if not s then return end
  local t = s.t
  local freeze = math.min(1, t / 0.18)
  local crackR = math.max(0, (t - 0.08) / 0.45) * 760
  for _, p in ipairs(s.shards) do
    local flying = t > p.launch
    local ft = flying and (t - p.launch) or 0
    local a = flying and math.max(0, 1 - ft / 1.6) or 1
    if a > 0 then
      lg.push()
      lg.translate(p.x, p.y)
      lg.rotate(p.rot)
      lg.scale(p.s)
      -- the frozen glass: the old map with an icy tint
      col(C.white, a); lg.draw(p.mesh)
      col(C.line, a * 0.22 * freeze); lg.polygon("fill", p.outline)
      -- glint as the shard turns toward the light
      if flying then
        lg.setBlendMode("add")
        col(C.white, a * 0.35 * math.max(0, math.cos(p.rot * 2 + p.vr)))
        lg.polygon("fill", p.outline)
        lg.setBlendMode("alpha")
      end
      -- cracks spread outward from the impact point
      if flying or p.dist < crackR then
        lg.setLineWidth(flying and 1.5 or 1.2)
        col(C.white, a * (flying and 0.8 or 0.9))
        lg.polygon("line", p.outline)
        lg.setLineWidth(1)
      end
      lg.pop()
    end
  end
  -- impact star while the glass cracks
  if t < 0.7 then
    local k = math.min(1, t / 0.1) * (1 - math.max(0, (t - 0.45) / 0.25))
    lg.setBlendMode("add")
    col(C.white, k * 0.8); lg.circle("fill", s.ix, s.iy, 6 + t * 30, 24)
    for j = 0, 3 do
      local an = j * math.pi / 2 + 0.3
      col(C.white, k * 0.6)
      lg.polygon("fill", s.ix + math.cos(an) * 90, s.iy + math.sin(an) * 90, s.ix - math.sin(an) * 3, s.iy + math.cos(an) * 3,
        s.ix - math.cos(an) * 90, s.iy - math.sin(an) * 90, s.ix + math.sin(an) * 3, s.iy - math.cos(an) * 3)
    end
    lg.setBlendMode("alpha")
  end
end

return Sh
