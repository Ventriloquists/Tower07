-- Virtual-resolution layer: the game is laid out on a 1280x720 canvas that is
-- scaled uniformly (letterboxed) to any window size. Text is rasterized at the
-- real pixel size so it stays crisp in fullscreen / 4K.
local V = {VW = 1280, VH = 720, s = 1, ox = 0, oy = 0, lw = 1, winW = 1280, winH = 720}
local G = love.graphics

local fontData, displayData
local registry = {}
local Font = {}
Font.__index = Font
-- V.caseFn: optional text transform (desktop themes); widths use it too so layouts stay aligned
V.caseFn = nil
local function tx(t) if V.caseFn and type(t) == "string" then return V.caseFn(t) end return t end
V.tx = tx
function Font:getWidth(t) return self.f:getWidth(tx(t)) / V.s end
function Font:getHeight() return self.f:getHeight() / V.s end

local function build(fw)
  local px = math.max(6, math.floor(fw.size * V.s + 0.5))
  -- display fonts use the heading face, but only with the default face (app themes keep their system font)
  local data = (fw.display and V.face == "default" and displayData) or fontData
  if data then
    local ok, f = pcall(G.newFont, data, px)
    if ok then fw.f = f return end
  end
  fw.f = G.newFont(px)
end

local faceCache = {}
local function loadFace(list)
  local dir = (os.getenv("WINDIR") or "C:/Windows") .. "/Fonts/"
  for _, name in ipairs(list) do
    if faceCache[name] then return faceCache[name] end
    local ok, data = pcall(function()
      local f = io.open(dir .. name, "rb")
      if not f then return nil end
      local d = f:read("*a")
      f:close()
      return love.filesystem.newFileData(d, name)
    end)
    if ok and data then faceCache[name] = data return data end
  end
end
-- type system: Bahnschrift (DIN) for the interface, Franklin Gothic for display headings and hero numbers
function V.loadFontData()
  fontData = loadFace({"bahnschrift.ttf", "segoeui.ttf"})
  displayData = loadFace({"framd.ttf", "bahnschrift.ttf", "segoeui.ttf"})
  V.face = "default"
end
-- switch the UI typeface (themes that mimic a desktop app use the system UI font); rebuilds every font
function V.setFace(name)
  name = name or "default"
  if V.face == name then return end
  V.face = name
  fontData = loadFace(name == "default" and {"bahnschrift.ttf", "segoeui.ttf"} or {name, "bahnschrift.ttf"})
  for _, fw in ipairs(registry) do build(fw) end
end

function V.newFont(size, display)
  local fw = setmetatable({size = size, display = display}, Font)
  build(fw)
  registry[#registry + 1] = fw
  return fw
end

function V.resize(w, h)
  V.winW, V.winH = w, h
  V.s = math.min(w / V.VW, h / V.VH)
  V.ox = math.floor((w - V.VW * V.s) / 2)
  V.oy = math.floor((h - V.VH * V.s) / 2)
  -- thin lines stay thin when scaled up
  V.lw = (1 + (V.s - 1) * 0.5) / V.s
  for _, fw in ipairs(registry) do build(fw) end
end

-- visible area in virtual coordinates (wider/taller than 1280x720 when letterboxed)
function V.extents()
  return -V.ox / V.s, -V.oy / V.s, (V.winW - V.ox) / V.s, (V.winH - V.oy) / V.s
end

-- V.fx: whole-screen warp from the silly themes {rot, sx, sy, dx, dy} around the screen centre.
-- Drawing applies it in V.begin; input uses the exact inverse so clicks still land where you see things.
V.fx = nil
function V.warp(x, y) -- virtual -> warped virtual
  local f = V.fx
  if not f then return x, y end
  local px, py = (x - 640) * (f.sx or 1), (y - 360) * (f.sy or 1)
  local c, s = math.cos(f.rot or 0), math.sin(f.rot or 0)
  return 640 + (f.dx or 0) + px * c - py * s, 360 + (f.dy or 0) + px * s + py * c
end
function V.toVirtual(x, y)
  local vx, vy = (x - V.ox) / V.s, (y - V.oy) / V.s
  local f = V.fx
  if f then
    local px, py = vx - 640 - (f.dx or 0), vy - 360 - (f.dy or 0)
    local c, s = math.cos(-(f.rot or 0)), math.sin(-(f.rot or 0))
    px, py = px * c - py * s, px * s + py * c
    vx, vy = 640 + px / (f.sx or 1), 360 + py / (f.sy or 1)
  end
  return vx, vy
end
function V.mouse()
  if V.fakeMouse then return V.fakeMouse[1], V.fakeMouse[2] end -- self-test hook
  return V.toVirtual(love.mouse.getPosition())
end

function V.begin()
  G.push()
  G.translate(V.ox, V.oy)
  G.scale(V.s)
  local f = V.fx
  if f then
    G.translate(640 + (f.dx or 0), 360 + (f.dy or 0))
    G.rotate(f.rot or 0)
    G.scale(f.sx or 1, f.sy or 1)
    G.translate(-640, -360)
  end
  G.setLineWidth(V.lw)
end
function V.finish() G.pop() end

-- love.graphics proxy with virtual-resolution aware text, lines and scissors
local lg = setmetatable({}, {__index = G})
V.lg = lg

local function snap(x, y)
  local sx = math.floor(V.ox + x * V.s + 0.5)
  local sy = math.floor(V.oy + y * V.s + 0.5)
  return (sx - V.ox) / V.s, (sy - V.oy) / V.s
end
function lg.setFont(fw) G.setFont(fw.f) end
function lg.print(t, x, y)
  x, y = snap(x, y)
  G.print(tx(t), x, y, 0, 1 / V.s, 1 / V.s)
end
function lg.printf(t, x, y, w, align)
  x, y = snap(x, y)
  G.printf(tx(t), x, y, w * V.s, align or "left", 0, 1 / V.s, 1 / V.s)
end
-- V.round: corner radius for panels; V.shadow: soft drop shadow under opaque panels
V.round, V.shadow = 0, false
-- V.liquid: macOS 26 "Liquid Glass" panels {alpha, sheen, edge, dark}: translucent body, top sheen, specular edge, deep soft shadow
V.liquid = nil
function V.glassRect(x, y, w, h, r, cr, cg, cb)
  local L = V.liquid or {alpha = 0.6, sheen = 0.1, edge = 0.5}
  G.setColor(0, 0, 0, L.dark and 0.18 or 0.06); G.rectangle("fill", x - 3, y + 4, w + 6, h + 8, r + 4, r + 4)
  G.setColor(0, 0, 0, L.dark and 0.14 or 0.05); G.rectangle("fill", x - 1, y + 1, w + 2, h + 3, r + 1, r + 1)
  G.setColor(cr, cg, cb, L.alpha); G.rectangle("fill", x, y, w, h, r, r)
  G.setColor(1, 1, 1, L.sheen); G.rectangle("fill", x + 1, y + 1, w - 2, math.min(h * 0.42, 46), r, r)
  local lw = G.getLineWidth()
  G.setLineWidth(1 / V.s)
  G.setColor(1, 1, 1, L.edge); G.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, r, r)
  G.setColor(0, 0, 0, L.dark and 0.35 or 0.06); G.rectangle("line", x - 0.5, y - 0.5, w + 1, h + 1, r + 0.5, r + 0.5)
  G.setLineWidth(lw)
end
-- V.chamfer: the HUD silhouette. Panels lose their top-left and bottom-right corners (cut at 45 degrees).
-- Only panel-sized rectangles are cut: bars, tiles, chips and full-screen dims stay square.
V.chamfer = 0
function V.cutFor(w, h)
  local c = V.chamfer
  if c <= 0 or w < 40 or h < 24 or w > 1000 then return 0 end
  return math.min(c, h * 0.3, w * 0.3)
end
function V.chamferPoly(mode, x, y, w, h, c1, c2)
  c2 = c2 or c1
  G.polygon(mode, x + c1, y, x + w, y, x + w, y + h - c2, x + w - c2, y + h, x, y + h, x, y + c1)
end
function lg.rectangle(mode, x, y, w, h, rx, ry, seg)
  if not rx and V.chamfer > 0 then
    local c = V.cutFor(w, h)
    if c > 0 then return V.chamferPoly(mode, x, y, w, h, c) end
  end
  if V.round > 0 and not rx and w >= 40 and h >= 24 then
    local r = math.min(V.round, h / 2, w / 2)
    if V.liquid and mode == "fill" and w >= 60 and h >= 30 then
      local cr, cg, cb, ca = G.getColor()
      if ca >= 0.85 then
        V.glassRect(x, y, w, h, r, cr, cg, cb)
        G.setColor(cr, cg, cb, ca)
        return
      end
    end
    if V.shadow and mode == "fill" and w >= 60 and h >= 30 then
      local cr, cg, cb, ca = G.getColor()
      if ca >= 0.85 then
        G.setColor(0, 0, 0, 0.05); G.rectangle("fill", x - 1, y + 1, w + 2, h + 3, r + 1, r + 1)
        G.setColor(0, 0, 0, 0.06); G.rectangle("fill", x, y + 1, w, h + 1, r, r)
        G.setColor(cr, cg, cb, ca)
      end
    end
    return G.rectangle(mode, x, y, w, h, r, r, seg)
  end
  return G.rectangle(mode, x, y, w, h, rx, ry, seg)
end
function lg.setLineWidth(w) G.setLineWidth(w * V.lw) end
local function warpRect(x, y, w, h)
  if not V.fx then return x, y, w, h end
  local ax, ay, bx, by = math.huge, math.huge, -math.huge, -math.huge
  for _, p in ipairs({{x, y}, {x + w, y}, {x, y + h}, {x + w, y + h}}) do
    local px, py = V.warp(p[1], p[2])
    ax, ay, bx, by = math.min(ax, px), math.min(ay, py), math.max(bx, px), math.max(by, py)
  end
  return ax, ay, bx - ax, by - ay
end
function lg.setScissor(x, y, w, h)
  V.sc = x and {x, y, w, h} or nil -- virtual-space clip, used for hover tests
  if x then
    x, y, w, h = warpRect(x, y, w, h)
    G.setScissor(V.ox + x * V.s, V.oy + y * V.s, math.max(0, w * V.s), math.max(0, h * V.s))
  else
    G.setScissor()
  end
end
function lg.intersectScissor(x, y, w, h)
  x, y, w, h = warpRect(x, y, w, h)
  G.intersectScissor(V.ox + x * V.s, V.oy + y * V.s, math.max(0, w * V.s), math.max(0, h * V.s))
end

return V
