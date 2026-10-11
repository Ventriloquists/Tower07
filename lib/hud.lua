-- Palette, formatting, HUD drawing primitives and the immediate-mode hit system.
local V = require "lib.view"
local lg = V.lg
local H = {}

H.C = {
  bg     = {0.024, 0.036, 0.048},
  panel  = {0.035, 0.058, 0.075},
  line   = {0.55, 0.86, 0.96},
  white  = {0.90, 0.97, 1.00},
  dim    = {0.36, 0.52, 0.60},
  faint  = {0.16, 0.27, 0.32},
  red    = {1.00, 0.27, 0.22},
  orange = {1.00, 0.58, 0.20},
  teal   = {0.13, 0.42, 0.52},
  sea    = {0.03, 0.075, 0.095},
  gold   = {1.00, 0.84, 0.36},
  holo   = {1.00, 0.60, 0.95}, -- PRISM rarity: recoloured every frame (rainbow), never themed
}
local C = H.C

-- layout of the right-hand panel
H.L = {PX = 576, PY = 54, PW = 692, NAV = 118, NAVC = 52}

function H.col(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end
local col = H.col
function H.rnd(a, b) return a + love.math.random() * (b - a) end
function H.clamp(x, a, b) return math.max(a, math.min(b, x)) end
local clamp = H.clamp

-- rainbow hue (0..1) -> rgb, slightly pastel so it reads as holographic foil
function H.hue(h)
  local t = 2 * math.pi
  return 0.62 + 0.38 * math.cos(t * h), 0.62 + 0.38 * math.cos(t * (h - 1 / 3)), 0.62 + 0.38 * math.cos(t * (h - 2 / 3))
end
function H.updateHolo(time)
  local c = H.C.holo
  c[1], c[2], c[3] = H.hue(time * 0.35)
end
-- holographic foil: moving diagonal rainbow bands + glints, clipped to the rect
function H.holoFX(x, y, w, h, a)
  a = a or 1
  local t = love.timer.getTime()
  lg.push("all")
  lg.intersectScissor(x, y, w, h)
  lg.setBlendMode("add")
  local band = 14
  local slant = h * 0.6
  local off = (t * 40) % (band * 6)
  for k = -2, math.ceil((w + slant) / band) + 6 do
    local bx = x + k * band - off
    local r, g, b = H.hue(k * 0.11 + t * 0.25)
    love.graphics.setColor(r, g, b, 0.10 * a)
    love.graphics.polygon("fill", bx, y + h, bx + band, y + h, bx + band + slant, y, bx + slant, y)
  end
  -- a bright sheen sweeping across
  local sx = x - w + ((t * 0.5) % 1.6) * (w * 2)
  love.graphics.setColor(1, 1, 1, 0.12 * a)
  love.graphics.polygon("fill", sx, y + h, sx + 18, y + h, sx + 18 + slant, y, sx + slant, y)
  -- glints
  for k = 1, 4 do
    local gx = x + ((k * 0.37 + t * 0.07 * k) % 1) * w
    local gy = y + ((k * 0.61 + t * 0.05) % 1) * h
    local s = 1.5 + 1.5 * math.max(0, math.sin(t * 3 + k * 2))
    love.graphics.setColor(1, 1, 1, 0.5 * a)
    love.graphics.polygon("fill", gx, gy - s * 2, gx + s * 0.5, gy, gx, gy + s * 2, gx - s * 0.5, gy)
    love.graphics.polygon("fill", gx - s * 2, gy, gx, gy + s * 0.5, gx + s * 2, gy, gx, gy - s * 0.5)
  end
  lg.pop()
end

H.fonts = {}
function H.initFonts()
  local f = H.fonts
  f.xs, f.s, f.m, f.l, f.xl = V.newFont(11), V.newFont(13), V.newFont(16), V.newFont(22), V.newFont(30)
  -- display face: hero numbers and screen titles
  f.huge, f.d1, f.dxl, f.d2, f.d3 = V.newFont(50, true), V.newFont(34, true), V.newFont(28, true), V.newFont(22, true), V.newFont(17, true)
end

----------------------------------------------------------------------
-- Design tokens
----------------------------------------------------------------------
-- spacing scale (8pt grid with a 4pt half step), motion speeds (exponential approach rates, 1/s)
H.SP = {xs = 4, s = 8, m = 12, l = 16, xl = 24, xxl = 32}
H.MO = {fast = 22, base = 14, slow = 7, screen = 0.32}
H.CUT = 7 -- chamfer size of the HUD silhouette

-- easing curves for timed transitions (t in 0..1)
H.ease = {
  outCubic = function(t) t = 1 - t return 1 - t * t * t end,
  outExpo = function(t) return t >= 1 and 1 or 1 - 2 ^ (-10 * t) end,
  inOutCubic = function(t) return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2 end,
}

----------------------------------------------------------------------
-- Motion: eased per-element values. The UI is immediate mode, so state is keyed by layout position.
----------------------------------------------------------------------
H.reduced = false -- settings: reduced motion snaps every tween
local motion, mframe = {}, 0
-- init: starting value for a key that was not drawn last frame (e.g. 0 to fade something in each time it appears)
function H.tween(key, target, speed, init)
  local m = motion[key]
  if m and init and mframe - m.f > 1 then m.v = init end
  if not m then m = {v = init or target}; motion[key] = m end
  m.f = mframe
  if H.reduced or H.snap then m.v = target return target end
  local dt = math.min(0.05, love.timer.getDelta())
  m.v = m.v + (target - m.v) * (1 - math.exp(-(speed or H.MO.base) * dt))
  if math.abs(target - m.v) < 0.002 then m.v = target end
  return m.v
end
-- hover tween for a rect: 0..1
function H.hoverT(x, y, w, h, hov, speed)
  return H.tween(math.floor(x) .. ":" .. math.floor(y) .. ":" .. math.floor(w), hov and 1 or 0, speed or H.MO.fast)
end
local function motionGC()
  mframe = mframe + 1
  if mframe % 300 ~= 0 then return end
  for k, m in pairs(motion) do if mframe - m.f > 120 then motion[k] = nil end end
end

-- the HUD style is the default look; desktop-app themes (H.style) keep their own drawing
local function hud() return not H.style end
H.isHud = hud

function H.lerpC(a, b, t)
  return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end
function H.chamfer(mode, x, y, w, h, c1, c2)
  c1 = math.min(c1 or H.CUT, h * 0.45, w * 0.45)
  c2 = math.min(c2 or c1, h * 0.45, w * 0.45)
  lg.polygon(mode, x + c1, y, x + w, y, x + w, y + h - c2, x + w - c2, y + h, x, y + h, x, y + c1)
end

----------------------------------------------------------------------
-- Formatting
----------------------------------------------------------------------
local SUFFIX = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
  "UDc", "DDc", "TDc", "QaDc", "QiDc", "SxDc", "SpDc", "OcDc", "NoDc", "Vg"}
H.numFormat = "short" -- "short" (1.23Qa), "sci" (1.23e15), "eng" (1.23e15 in steps of 3)
function H.fmt(n)
  if n ~= n then return "0" end
  if n == math.huge then return "INF" end
  if n < 0 then return "-" .. H.fmt(-n) end
  if n < 1000 then
    if n < 100 and n ~= math.floor(n) then return string.format("%.1f", n) end
    return string.format("%d", math.floor(n))
  end
  if H.numFormat ~= "short" then
    if n < 1e4 then return string.format("%d", math.floor(n)) end
    local ex = math.floor(math.log10(n))
    if H.numFormat == "eng" then ex = math.floor(ex / 3) * 3 end
    local v = n / 10 ^ ex
    if H.numFormat == "sci" and v >= 9.995 then ex = ex + 1; v = v / 10 end
    if H.numFormat == "eng" and v >= 999.995 then ex = ex + 3; v = v / 1000 end
    return string.format("%.2fe%d", v, ex)
  end
  local e = math.floor(math.log10(n) / 3)
  local v = n / 10 ^ (e * 3)
  if v >= 999.995 then e = e + 1; v = v / 1000 end
  if e < #SUFFIX then return string.format("%.2f%s", v, SUFFIX[e + 1]) end
  local ex = math.floor(math.log10(n))
  return string.format("%.2fe%d", n / 10 ^ ex, ex)
end
function H.fmtTime(s)
  s = math.max(0, math.floor(s))
  if s < 60 then return s .. "S" end
  if s < 3600 then return math.floor(s / 60) .. "M " .. (s % 60) .. "S" end
  if s < 86400 then return math.floor(s / 3600) .. "H " .. math.floor(s % 3600 / 60) .. "M" end
  return math.floor(s / 86400) .. "D " .. math.floor(s % 86400 / 3600) .. "H"
end
function H.clock(s)
  s = math.max(0, math.floor(s))
  return string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end

----------------------------------------------------------------------
-- Hits (rebuilt every frame while drawing)
----------------------------------------------------------------------
H.hits = {}
H.tip = nil
H.scrollRegions = {}
H.onError = function() end
function H.beginFrame() H.hits = {}; H.tip = nil; H.kwTip = nil; H.scrollRegions = {}; motionGC() end
function H.clearHits() H.hits = {}; H.tip = nil; H.kwTip = nil; H.scrollRegions = {} end
-- register a wheel-scrollable area for this frame
function H.scrollRegion(x, y, w, h, key, horizontal)
  H.scrollRegions[#H.scrollRegions + 1] = {x = x, y = y, w = w, h = h, key = key, horizontal = horizontal}
end
function H.scrollAt(x, y)
  for i = #H.scrollRegions, 1, -1 do
    local r = H.scrollRegions[i]
    if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then return r end
  end
end
-- H.offY: vertical offset of the content being drawn (screen transitions), so hover and hits match what is seen
H.offY, H.offX = 0, 0
function H.mouseIn(x, y, w, h, clip)
  local mx, my = V.mouse()
  mx, my = mx - H.offX, my - H.offY
  if clip and (my < clip[1] or my > clip[2]) then return false end
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end
-- hold = true: keeps firing while the mouse button is held (hold-to-buy)
function H.addHit(x, y, w, h, fn, clip, hold)
  x, y = x + H.offX, y + H.offY
  if clip then
    local y0, y1 = math.max(y, clip[1]), math.min(y + h, clip[2])
    if y1 <= y0 then return end
    y, h = y0, y1 - y0
  end
  local hit = {x = x, y = y, w = w, h = h, fn = fn, hold = hold}
  H.hits[#H.hits + 1] = hit
  return hit
end
function H.hitAt(x, y)
  for i = #H.hits, 1, -1 do
    local h = H.hits[i]
    if x >= h.x and x <= h.x + h.w and y >= h.y and y <= h.y + h.h then return h end
  end
end
function H.click(x, y)
  local h = H.hitAt(x, y)
  if h then h.fn(x, y) return h end
  return nil
end
function H.setTip(title, text) H.tip = {title = title, text = text} end

----------------------------------------------------------------------
-- Keyboard focus: TAB / SHIFT+TAB walk every clickable thing in reading order, ENTER activates it.
-- Hits are rebuilt each frame, so focus is remembered as a rectangle and re-found by position.
----------------------------------------------------------------------
H.kbFocus = nil
local function sameRect(a, b) return math.abs(a.x - b.x) < 2 and math.abs(a.y - b.y) < 2 and math.abs(a.w - b.w) < 2 end
local function readingOrder()
  local list = {}
  for _, h in ipairs(H.hits) do if h.w >= 12 and h.h >= 10 and h.hold ~= "drag" then list[#list + 1] = h end end
  table.sort(list, function(a, b)
    local ra, rb = math.floor(a.y / 14), math.floor(b.y / 14)
    if ra ~= rb then return ra < rb end
    return a.x < b.x
  end)
  return list
end
function H.focusStep(dir)
  local list = readingOrder()
  if #list == 0 then H.kbFocus = nil return end
  local idx = 0
  if H.kbFocus then
    for i, h in ipairs(list) do if sameRect(h, H.kbFocus) then idx = i break end end
  end
  idx = idx + dir
  if idx < 1 then idx = #list elseif idx > #list then idx = 1 end
  local h = list[idx]
  H.kbFocus = {x = h.x, y = h.y, w = h.w, h = h.h}
end
function H.focusedHit()
  if not H.kbFocus then return end
  for i = #H.hits, 1, -1 do if sameRect(H.hits[i], H.kbFocus) then return H.hits[i] end end
end
function H.activateFocus()
  local h = H.focusedHit()
  if not h then return false end
  h.fn(h.x + h.w / 2, h.y + h.h / 2)
  return true
end
-- drawn last each frame: the lock-on ticks around the keyboard-focused element
function H.drawKbFocus()
  local h = H.focusedHit()
  if not h then return end
  H.focusRing(h.x, h.y, h.w, h.h, h.disabled and C.dim or C.white, 1)
end

----------------------------------------------------------------------
-- Primitives
----------------------------------------------------------------------
-- H.style: set by desktop-app themes ("mac" / "win"): rounded outlines instead of corner brackets, no hatching
H.style = nil
function H.brackets(x, y, w, h, l, c, a)
  if H.style then
    col(c, (a or 1) * 0.55)
    lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, 6, 6)
    return
  end
  col(c, a)
  l = l or 8
  local k = V.cutFor(w, h)
  if k > 0 then
    -- chamfered silhouette: only the two cut corners carry a bracket, tracing the diagonal (four brackets on
    -- top of an outline read as clutter; two read as a signature)
    lg.line(x, y + k + l, x, y + k, x + k, y, x + k + l, y)
    lg.line(x + w - k - l, y + h, x + w - k, y + h, x + w, y + h - k, x + w, y + h - k - l)
    return
  end
  lg.line(x, y + l, x, y, x + l, y)
  lg.line(x + w - l, y, x + w, y, x + w, y + l)
  lg.line(x, y + h - l, x, y + h, x + l, y + h)
  lg.line(x + w - l, y + h, x + w, y + h, x + w, y + h - l)
end

-- accent edge on the left of a panel: starts below the cut corner and traces the diagonal,
-- so it follows the silhouette instead of painting over it (colour must be set by the caller)
function H.leftEdge(x, y, w, h, t)
  t = t or 3
  local k = V.cutFor(w, h)
  lg.rectangle("fill", x, y + k, t, h - k)
  if k > 0 then
    local lw = lg.getLineWidth()
    lg.setLineWidth(1)
    lg.line(x + 0.5, y + k, x + k, y + 0.5)
    lg.setLineWidth(lw / V.lw)
  end
end

-- focus lock-on: four corner ticks that close in on the hovered element (t = 0..1)
function H.focusRing(x, y, w, h, c, t)
  if t <= 0.01 then return end
  local o = 5 * (1 - t)
  local l = 6
  col(c, t)
  x, y, w, h = x - 3 - o, y - 3 - o, w + 6 + o * 2, h + 6 + o * 2
  lg.line(x, y + l, x, y, x + l, y)
  lg.line(x + w - l, y, x + w, y, x + w, y + l)
  lg.line(x, y + h - l, x, y + h, x + l, y + h)
  lg.line(x + w - l, y + h, x + w, y + h, x + w, y + h - l)
end

-- station layout grid: every station shares one header band and one content top
H.HEAD = {TITLE_Y = 56, CTRL_Y = 58, CTRL_H = 26, BODY_Y = 92, GUTTER = 16, LEFT = 24, RIGHT = 1256}
-- station (or column) title with an optional subtitle 16px after it; returns the x where the subtitle ends
function H.screenTitle(title, sub, x, subColor)
  x = x or H.HEAD.LEFT
  local f = H.fonts
  lg.setFont(f.d2); col(C.white); lg.print(title, x, H.HEAD.TITLE_Y)
  local ex = x + f.d2:getWidth(title)
  if sub then
    ex = ex + 16
    H.label(sub, ex, H.HEAD.TITLE_Y + 10, subColor or C.dim)
    ex = ex + f.xs:getWidth(sub)
  end
  return ex
end

-- section heading: index number, display title, hairline rule (used for screen and column titles)
function H.heading(title, x, y, w, c, index, sub)
  local f = H.fonts
  local tx = x
  if index then
    lg.setFont(f.xs); col(c or C.line, 0.9); lg.print(index, x, y + 3)
    tx = x + f.xs:getWidth(index) + 8
  end
  lg.setFont(f.s); col(C.white); lg.print(title, tx, y)
  local tw = f.s:getWidth(title)
  if sub then lg.setFont(f.xs); col(C.dim); lg.printf(sub, x, y + 2, w, "right") end
  col(C.faint, 0.9); lg.line(x, y + 18, x + w, y + 18)
  col(c or C.line, 0.9); lg.rectangle("fill", x, y + 17, math.min(w, tx - x + tw), 2)
end

function H.hatch(x, y, w, h, c, a, gap)
  if H.style then return end
  lg.push("all")
  lg.intersectScissor(x, y, w, h)
  col(c, a)
  gap = gap or 6
  for i = -h, w, gap do lg.line(x + i, y + h, x + i + h, y) end
  lg.pop()
end

function H.segbar(x, y, w, h, frac, segs, c, a)
  local gap = 2
  local sw = (w - (segs - 1) * gap) / segs
  for i = 0, segs - 1 do
    local f = clamp(frac * segs - i, 0, 1)
    col(C.faint, 0.6)
    lg.rectangle("fill", x + i * (sw + gap), y, sw, h)
    if f > 0 then
      col(c, a or 0.95)
      lg.rectangle("fill", x + i * (sw + gap), y, sw * f, h)
    end
  end
end

function H.tickRing(cx, cy, r, n, len, rot, c, a, major)
  col(c, a)
  for i = 0, n - 1 do
    local ang = rot + i / n * math.pi * 2
    local l = (major and i % major == 0) and len * 2.2 or len
    local ca, sa = math.cos(ang), math.sin(ang)
    lg.line(cx + ca * r, cy + sa * r, cx + ca * (r + l), cy + sa * (r + l))
  end
end

----------------------------------------------------------------------
-- Keywords: glossary terms inside UI text are highlighted and explain themselves on hover
----------------------------------------------------------------------
H.keywords = true
H.glossary = {}
local byFirst = {}  -- first letter -> aliases, longest first
local segCache, segCount = {}, 0

function H.setGlossary(list)
  H.glossary = list
  byFirst = {}
  for _, term in ipairs(list) do
    for _, a in ipairs(term.alias) do
      local s = a:lower()
      local f = s:sub(1, 1)
      byFirst[f] = byFirst[f] or {}
      table.insert(byFirst[f], {s = s, term = term})
    end
  end
  for _, l in pairs(byFirst) do table.sort(l, function(a, b) return #a.s > #b.s end) end
  segCache, segCount = {}, 0
end

-- hyphens join words ("power-friendly" is not the keyword "power")
local function isWord(ch) return ch ~= "" and ch:match("[%w%-]") ~= nil end

-- split text into {t = string, term = glossary entry or nil}
local function segment(text)
  local c = segCache[text]
  if c then return c end
  local low = text:lower()
  local segs, n, i, start = {}, #text, 1, 1
  while i <= n do
    local hit
    local list = byFirst[low:sub(i, i)]
    if list and not isWord(i > 1 and low:sub(i - 1, i - 1) or "") then
      for _, a in ipairs(list) do
        local L = #a.s
        if low:sub(i, i + L - 1) == a.s and not isWord(low:sub(i + L, i + L)) then hit = a break end
      end
    end
    if hit then
      if start < i then segs[#segs + 1] = {t = text:sub(start, i - 1)} end
      segs[#segs + 1] = {t = text:sub(i, i + #hit.s - 1), term = hit.term}
      i = i + #hit.s
      start = i
    else
      i = i + 1
    end
  end
  if start <= n then segs[#segs + 1] = {t = text:sub(start)} end
  segCount = segCount + 1
  if segCount > 4000 then segCache, segCount = {}, 0 end -- dynamic numbers make new strings every frame
  segCache[text] = segs
  return segs
end
H.segment = segment

local function bright(c)
  return c[1] + (1 - c[1]) * 0.5, c[2] + (1 - c[2]) * 0.5, c[3] + (1 - c[3]) * 0.5
end

-- draw one keyword word/phrase; registers hover (respecting the current scissor)
local function drawKeyword(s, term, x, y, font, c, a, noHover)
  local w, h = font:getWidth(s), font:getHeight()
  local mx, my = V.mouse()
  local hov = false
  if not noHover and mx >= x and mx <= x + w and my >= y and my <= y + h then
    local sc = V.sc
    hov = not sc or (mx >= sc[1] and mx <= sc[1] + sc[3] and my >= sc[2] and my <= sc[2] + sc[4])
    if hov then H.kwTip = {title = term.name:upper(), text = term.desc} end
  end
  local r, g, b = bright(c)
  if hov then r, g, b = 1, 1, 1 end
  love.graphics.setColor(r, g, b, a or 1)
  lg.print(s, x, y)
  love.graphics.setColor(r, g, b, (a or 1) * (hov and 0.9 or 0.55))
  local uy = y + h - 1
  if hov then
    lg.rectangle("fill", x, uy, w, 1)
  else
    for dx = 0, w - 1, 3 do lg.rectangle("fill", x + dx, uy, 1.5, 1) end
  end
  return w
end

-- single-line text with keyword highlights
function H.rich(text, x, y, c, a, font, noHover)
  text = tostring(text)
  font = font or H.fonts.xs
  lg.setFont(font)
  c = c or C.dim
  if not H.keywords then col(c, a); lg.print(text, x, y) return end
  local segs = segment(text)
  if #segs == 1 and not segs[1].term then col(c, a); lg.print(text, x, y) return end
  local cx = x
  for _, s in ipairs(segs) do
    if s.term then
      cx = cx + drawKeyword(s.t, s.term, cx, y, font, c, a, noHover)
    else
      col(c, a); lg.print(s.t, cx, y)
      cx = cx + font:getWidth(s.t)
    end
  end
end

local function layoutRich(text, w, font)
  local segs = H.keywords and segment(text) or {{t = text}}
  -- words keep their keyword tag; spaces are separate tokens
  local toks = {}
  for _, s in ipairs(segs) do
    for word, space in s.t:gmatch("([^ ]*)( *)") do
      if word ~= "" then toks[#toks + 1] = {t = word, term = s.term} end
      if space ~= "" then toks[#toks + 1] = {t = space, space = true} end
    end
  end
  local lines, line, lw = {}, {}, 0
  for _, t in ipairs(toks) do
    local tw = font:getWidth(t.t)
    if not t.space and lw + tw > w and #line > 0 then
      while #line > 0 and line[#line].space do lw = lw - line[#line].w; table.remove(line) end
      lines[#lines + 1] = {toks = line, w = lw}
      line, lw = {}, 0
    end
    if not (t.space and #line == 0) then
      t.w = tw
      line[#line + 1] = t
      lw = lw + tw
    end
  end
  if #line > 0 then lines[#lines + 1] = {toks = line, w = lw} end
  return lines
end

function H.richHeight(text, w, font)
  font = font or H.fonts.xs
  return #layoutRich(tostring(text), w, font) * font:getHeight()
end

-- wrapped text with keyword highlights; returns the height used
function H.richf(text, x, y, w, align, c, a, font, noHover)
  text = tostring(text)
  font = font or H.fonts.xs
  c = c or C.dim
  local lines = layoutRich(text, w, font)
  local lh = font:getHeight()
  lg.setFont(font)
  for i, l in ipairs(lines) do
    local cx = x
    if align == "center" then cx = x + (w - l.w) / 2 elseif align == "right" then cx = x + w - l.w end
    local ly = y + (i - 1) * lh
    for _, t in ipairs(l.toks) do
      if t.term then
        drawKeyword(t.t, t.term, cx, ly, font, c, a, noHover)
      else
        col(c, a); lg.print(t.t, cx, ly)
      end
      cx = cx + t.w
    end
  end
  return #lines * lh
end

function H.label(text, x, y, c, a, font)
  H.rich(text, x, y, c or C.dim, a, font or H.fonts.xs)
end

function H.rowFrame(x, y, w, h, active, hov, c)
  if hud() then
    local t = H.hoverT(x, y, w, h, hov)
    c = c or C.line
    col(C.panel, 0.9); lg.rectangle("fill", x, y, w, h)
    col(c, 0.025 + 0.07 * t); lg.rectangle("fill", x, y, w, h)
    col(active and c or C.faint, active and (0.35 + 0.45 * t) or 0.7); lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    -- selection spine on the left edge grows with hover
    if active then col(t > 0.5 and C.white or c, 0.5 + 0.5 * t); lg.rectangle("fill", x, y + H.CUT + 2, 2, (h - H.CUT - 4) * (0.35 + 0.65 * t)) end
    return
  end
  col(C.panel, 0.88)
  lg.rectangle("fill", x, y, w, h)
  if hov then col(C.line, 0.07); lg.rectangle("fill", x, y, w, h) end
  col(C.faint, 0.7)
  lg.rectangle("line", x, y, w, h)
  H.brackets(x, y, w, h, 7, active and (hov and C.white or (c or C.line)) or C.faint, active and 1 or 0.8)
end

function H.button(x, y, w, h, text, enabled, fn, c, font, clip, primary, hold)
  local hov = enabled and H.mouseIn(x, y, w, h, clip)
  c = c or C.line
  font = font or H.fonts.s
  if H.style == "mac" then
    -- macOS 26 capsules: tinted solid for the main action, glass for everything else
    local r = math.min(h / 2, 20)
    if primary and enabled then
      col(c, hov and 1 or 0.92); lg.rectangle("fill", x, y, w, h, r, r)
      lg.setColor(1, 1, 1, hov and 0.32 or 0.22); lg.rectangle("fill", x + 1, y + 1, w - 2, h * 0.48, r, r)
      lg.setFont(font); lg.setColor(1, 1, 1)
    else
      local dark = H.macDark
      lg.setColor(1, 1, 1, dark and (hov and 0.16 or 0.08) or (hov and 0.75 or 0.5)); lg.rectangle("fill", x, y, w, h, r, r)
      lg.setColor(1, 1, 1, dark and 0.18 or 0.8); lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1, r, r)
      lg.setFont(font)
      col(enabled and (hov and C.white or c) or C.faint)
    end
    lg.printf(text, x, y + h / 2 - font:getHeight() / 2, w, "center")
    local hit = H.addHit(x, y, w, h, function() if enabled then fn() else H.onError() end end, clip, hold)
    if hit then hit.disabled = not enabled end
    return
  end
  if hud() then return H.hudButton(x, y, w, h, text, enabled, fn, c, font, clip, primary, hold, hov) end
  if primary and enabled then
    -- filled call-to-action with a soft pulse
    local t = love.timer.getTime()
    local R = H.style and 6 or 0
    col(c, hov and 1 or (0.82 + 0.1 * math.sin(t * 4)))
    lg.rectangle("fill", x, y, w, h, R, R)
    col(C.white, hov and 0.9 or 0.5)
    if not H.style then lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1) end
    lg.setFont(font)
    col(C.bg)
  else
    col(c, hov and 0.25 or (enabled and 0.09 or 0.03))
    lg.rectangle("fill", x, y, w, h, H.style and 6 or 0, H.style and 6 or 0)
    H.brackets(x, y, w, h, 6, enabled and c or C.faint, hov and 1 or 0.85)
    lg.setFont(font)
    col(enabled and (hov and C.white or c) or C.faint)
  end
  lg.printf(text, x, y + h / 2 - font:getHeight() / 2, w, "center")
  local hit = H.addHit(x, y, w, h, function() if enabled then fn() else H.onError() end end, clip, hold)
  if hit then hit.disabled = not enabled end
end

-- HUD button: chamfered plate. Idle is calm (no ambient animation); hover fills, brightens the edge and runs one light
-- sweep across the face; press sinks 1px and darkens; a refused click shakes the button red. Disabled = flat and dim.
-- The lock-on corner ticks are reserved for keyboard focus (drawn by H.drawKbFocus), so hover never doubles up.
function H.hudButton(x, y, w, h, text, enabled, fn, c, font, clip, primary, hold, hov)
  local key = math.floor(x) .. ":" .. math.floor(y) .. ":" .. math.floor(w)
  local t = H.hoverT(x, y, w, h, hov)
  local down = hov and love.mouse.isDown(1)
  local cut = math.min(H.CUT, h * 0.3)
  local now = love.timer.getTime()
  local d = H.denied
  local deny = d and d.k == key and now - d.t < 0.4 and (1 - (now - d.t) / 0.4) or 0
  if deny > 0 and not H.reduced then x = x + math.sin((now - d.t) * 55) * 4 * deny end
  local yy = y + (down and 1 or 0)
  if primary and enabled then
    col(c, 0.12 * t); H.chamfer("fill", x - 3, yy - 3, w + 6, h + 6, cut + 2)
    col(c, down and 0.74 or (0.88 + 0.12 * t)); H.chamfer("fill", x, yy, w, h, cut)
    lg.setColor(1, 1, 1, down and 0.05 or (0.14 + 0.1 * t)); lg.rectangle("fill", x + cut, yy, w - cut, 1)
    lg.setColor(0, 0, 0, 0.18); lg.rectangle("fill", x, yy + h - 2, w - cut, 2)
    lg.setFont(font); col(C.bg)
  elseif enabled then
    col(C.panel, 0.94); H.chamfer("fill", x, yy, w, h, cut)
    col(c, (down and 0.2 or 0.06) + 0.08 * t); H.chamfer("fill", x, yy, w, h, cut)
    col(c, 0.32 + 0.6 * t); H.chamfer("line", x + 0.5, yy + 0.5, w - 1, h - 1, cut)
    local sh = (h - cut * 2 - 2) * (0.45 + 0.55 * t)
    col(c, 0.9); lg.rectangle("fill", x + 1, yy + h / 2 - sh / 2, 2, sh)
    lg.setFont(font)
    local r, g, b = H.lerpC(c, C.white, t)
    lg.setColor(r, g, b, 1)
  else
    col(C.panel, 0.55); H.chamfer("fill", x, yy, w, h, cut)
    col(C.faint, 0.9); H.chamfer("line", x + 0.5, yy + 0.5, w - 1, h - 1, cut)
    lg.setFont(font); col(C.dim, 0.6)
  end
  -- one sweep of light per hover, driven by the hover tween so it is caused by the cursor, never ambient
  if enabled and t > 0.02 and t < 0.98 and hov then
    lg.push("all")
    lg.intersectScissor(x, yy, w, h)
    local sx = x - h + t * (w + h * 2)
    lg.setColor(1, 1, 1, primary and 0.2 or 0.08)
    lg.polygon("fill", sx, yy + h, sx + 10, yy + h, sx + 10 + h * 0.6, yy, sx + h * 0.6, yy)
    lg.pop()
  end
  lg.printf(text, x, yy + h / 2 - font:getHeight() / 2, w, "center")
  if deny > 0 then col(C.red, deny); H.chamfer("line", x - 1.5, yy - 1.5, w + 3, h + 3, cut + 1) end
  local hit = H.addHit(x, y, w, h, function()
    if enabled then fn() else H.denied = {k = key, t = love.timer.getTime()}; H.onError() end
  end, clip, hold)
  if hit then hit.disabled = not enabled end
end

-- segmented control: one plate, a selection slab that glides to the chosen option
function H.segmented(x, y, w, h, labels, sel, onSelect, key, c)
  c = c or C.line
  local n = #labels
  local sw = w / n
  local f = H.fonts.xs
  if not hud() then
    for k, l in ipairs(labels) do
      local sx = x + (k - 1) * sw
      local on = sel == k
      local hov = H.mouseIn(sx, y, sw - 4, h)
      col(c, on and 0.3 or (hov and 0.12 or 0.04)); lg.rectangle("fill", sx, y, sw - 4, h)
      H.brackets(sx, y, sw - 4, h, 4, on and C.white or C.dim)
      lg.setFont(f); col(on and C.white or C.dim)
      lg.printf(l, sx, y + h / 2 - f:getHeight() / 2, sw - 4, "center")
      H.addHit(sx, y, sw - 4, h, function() onSelect(k) end)
    end
    return
  end
  col(C.panel, 0.9); H.chamfer("fill", x, y, w, h, 5)
  col(C.faint); H.chamfer("line", x + 0.5, y + 0.5, w - 1, h - 1, 5)
  local px = H.tween("seg:" .. (key or x .. ":" .. y), x + ((sel or 1) - 1) * sw, H.MO.base)
  col(c, 0.22); lg.rectangle("fill", px + 2, y + 2, sw - 4, h - 4)
  col(c); lg.rectangle("fill", px + 2, y + h - 3, sw - 4, 2)
  for k, l in ipairs(labels) do
    local sx = x + (k - 1) * sw
    local on = sel == k
    local hov = H.mouseIn(sx, y, sw, h)
    if k > 1 then col(C.faint); lg.line(sx, y + 6, sx, y + h - 6) end
    if hov and not on then col(c, 0.07); lg.rectangle("fill", sx + 2, y + 2, sw - 4, h - 4) end
    lg.setFont(f); col(on and C.white or (hov and C.line or C.dim))
    lg.printf(l, sx, y + h / 2 - f:getHeight() / 2, sw, "center")
    H.addHit(sx, y, sw, h, function() onSelect(k) end)
  end
end

-- red count badge (notification pattern)
function H.badge(x, y, n, c)
  if not n or n <= 0 then return end
  local txt = n > 99 and "99+" or tostring(n)
  local f = H.fonts.xs
  local w = math.max(16, f:getWidth(txt) + 8)
  c = c or C.red
  if hud() then
    -- a counter tag: square-cut, with a dark keyline so it separates from whatever it sits on
    col(C.bg); lg.rectangle("fill", x - w / 2 - 1, y - 9, w + 2, 18)
    col(c); H.chamfer("fill", x - w / 2, y - 8, w, 16, 4)
  else
    col(c)
    lg.rectangle("fill", x - w / 2, y - 8, w, 16, 8, 8)
  end
  -- dark text on bright badges, light text on dark ones
  local lum = 0.3 * c[1] + 0.59 * c[2] + 0.11 * c[3]
  col(lum > 0.62 and C.bg or C.white)
  lg.setFont(f)
  lg.printf(txt, x - w / 2, y - 6, w, "center")
end

-- standard panel card with optional header
function H.card(x, y, w, h, title, c, sub)
  if hud() then
    c = c or C.line
    col(C.panel, 0.92); lg.rectangle("fill", x, y, w, h)
    -- top light: the panel is lit from above, fading down
    col(c, 0.045); lg.rectangle("fill", x + V.cutFor(w, h), y + 1, w - V.cutFor(w, h), math.min(h - 2, 22))
    col(C.faint, 0.85); lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    -- accent: a short lit segment of the top edge after the cut, and a tick on the bottom-right cut
    local k = V.cutFor(w, h)
    col(c, 0.95); lg.rectangle("fill", x + k, y, math.min(44, w * 0.3), 2)
    col(c, 0.55); lg.line(x + w - k, y + h - 0.5, x + w - 0.5, y + h - k)
    if title then
      H.label(title, x + 12, y + 8, c)
      if sub then
        lg.setFont(H.fonts.xs); col(C.dim)
        lg.printf(sub, x, y + 8, w - 12, "right")
      end
      col(C.faint, 0.9); lg.line(x + 12, y + 24, x + w - 12, y + 24)
    end
    return
  end
  col(C.panel, 0.9); lg.rectangle("fill", x, y, w, h)
  col(C.faint, 0.6); lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
  H.brackets(x, y, w, h, 8, c or C.line, 0.9)
  if title then
    H.label(title, x + 12, y + 8, c or C.line)
    if sub then
      lg.setFont(H.fonts.xs); col(C.dim)
      lg.printf(sub, x, y + 8, w - 12, "right")
    end
    col(c or C.line, 0.25); lg.line(x + 10, y + 24, x + w - 10, y + 24)
  end
end

-- smooth progress bar
function H.bar(x, y, w, h, frac, c, bg)
  c = c or C.line
  col(bg or C.faint, 0.6); lg.rectangle("fill", x, y, w, h)
  local f = clamp(frac or 0, 0, 1)
  if hud() and w >= 30 then
    -- fills glide to their value; the leading edge carries a bright cap
    f = clamp(H.tween("bar" .. math.floor(x) .. ":" .. math.floor(y) .. ":" .. math.floor(w), f, H.MO.base), 0, 1)
    col(c, 0.95); lg.rectangle("fill", x, y, w * f, h)
    if f > 0.005 and f < 0.999 then
      col(C.white, 0.85); lg.rectangle("fill", x + w * f - 1, y - (h >= 4 and 1 or 0), 2, h + (h >= 4 and 2 or 0))
    end
    return
  end
  col(c); lg.rectangle("fill", x, y, w * f, h)
end

-- truncate a string to fit a width
function H.fit(font, s, w)
  if font:getWidth(s) <= w then return s end
  while #s > 1 and font:getWidth(s .. "..") > w do s = s:sub(1, -2) end
  return s .. ".."
end

-- the drone glyph from the reference screens
function H.droneIcon(x, y, s, c, a)
  col(c, a or 1)
  lg.circle("line", x, y, 11 * s, 24)
  lg.circle("line", x, y, 4 * s, 12)
  lg.rectangle("line", x - 24 * s, y - 5 * s, 10 * s, 10 * s)
  lg.rectangle("line", x + 14 * s, y - 5 * s, 10 * s, 10 * s)
  lg.line(x - 14 * s, y, x - 11 * s, y)
  lg.line(x + 11 * s, y, x + 14 * s, y)
  lg.line(x, y + 11 * s, x, y + 17 * s)
  lg.line(x - 4 * s, y + 17 * s, x + 4 * s, y + 17 * s)
end

return H
