-- Virtual-resolution layer: the game is laid out on a 1280x720 canvas that is
-- scaled uniformly (letterboxed) to any window size. Text is rasterized at the
-- real pixel size so it stays crisp in fullscreen / 4K.
local V = {VW = 1280, VH = 720, s = 1, ox = 0, oy = 0, lw = 1, winW = 1280, winH = 720}
local G = love.graphics

local fontData
local registry = {}
local Font = {}
Font.__index = Font
function Font:getWidth(t) return self.f:getWidth(t) / V.s end
function Font:getHeight() return self.f:getHeight() / V.s end

local function build(fw)
  local px = math.max(6, math.floor(fw.size * V.s + 0.5))
  if fontData then
    local ok, f = pcall(G.newFont, fontData, px)
    if ok then fw.f = f return end
  end
  fw.f = G.newFont(px)
end

function V.loadFontData()
  pcall(function()
    local dir = (os.getenv("WINDIR") or "C:/Windows") .. "/Fonts/"
    for _, name in ipairs({"bahnschrift.ttf", "segoeui.ttf"}) do
      local f = io.open(dir .. name, "rb")
      if f then
        local d = f:read("*a")
        f:close()
        fontData = love.filesystem.newFileData(d, name)
        return
      end
    end
  end)
end

function V.newFont(size)
  local fw = setmetatable({size = size}, Font)
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

function V.toVirtual(x, y) return (x - V.ox) / V.s, (y - V.oy) / V.s end
function V.mouse()
  if V.fakeMouse then return V.fakeMouse[1], V.fakeMouse[2] end -- self-test hook
  return V.toVirtual(love.mouse.getPosition())
end

function V.begin()
  G.push()
  G.translate(V.ox, V.oy)
  G.scale(V.s)
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
  G.print(t, x, y, 0, 1 / V.s, 1 / V.s)
end
function lg.printf(t, x, y, w, align)
  x, y = snap(x, y)
  G.printf(t, x, y, w * V.s, align or "left", 0, 1 / V.s, 1 / V.s)
end
function lg.setLineWidth(w) G.setLineWidth(w * V.lw) end
function lg.setScissor(x, y, w, h)
  V.sc = x and {x, y, w, h} or nil -- virtual-space clip, used for hover tests
  if x then
    G.setScissor(V.ox + x * V.s, V.oy + y * V.s, math.max(0, w * V.s), math.max(0, h * V.s))
  else
    G.setScissor()
  end
end
function lg.intersectScissor(x, y, w, h)
  G.intersectScissor(V.ox + x * V.s, V.oy + y * V.s, math.max(0, w * V.s), math.max(0, h * V.s))
end

return V
