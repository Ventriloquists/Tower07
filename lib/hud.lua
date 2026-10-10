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
  f.xs, f.s, f.m, f.l, f.xl, f.huge = V.newFont(11), V.newFont(13), V.newFont(16), V.newFont(22), V.newFont(30), V.newFont(52)
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
function H.beginFrame() H.hits = {}; H.tip = nil; H.kwTip = nil; H.scrollRegions = {} end
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
function H.mouseIn(x, y, w, h, clip)
  local mx, my = V.mouse()
  if clip and (my < clip[1] or my > clip[2]) then return false end
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end
-- hold = true: keeps firing while the mouse button is held (hold-to-buy)
function H.addHit(x, y, w, h, fn, clip, hold)
  if clip then
    local y0, y1 = math.max(y, clip[1]), math.min(y + h, clip[2])
    if y1 <= y0 then return end
    y, h = y0, y1 - y0
  end
  H.hits[#H.hits + 1] = {x = x, y = y, w = w, h = h, fn = fn, hold = hold}
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
-- Primitives
----------------------------------------------------------------------
function H.brackets(x, y, w, h, l, c, a)
  col(c, a)
  l = l or 8
  lg.line(x, y + l, x, y, x + l, y)
  lg.line(x + w - l, y, x + w, y, x + w, y + l)
  lg.line(x, y + h - l, x, y + h, x + l, y + h)
  lg.line(x + w - l, y + h, x + w, y + h, x + w, y + h - l)
end

function H.hatch(x, y, w, h, c, a, gap)
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
  if primary and enabled then
    -- filled call-to-action with a soft pulse
    local t = love.timer.getTime()
    col(c, hov and 1 or (0.82 + 0.1 * math.sin(t * 4)))
    lg.rectangle("fill", x, y, w, h)
    col(C.white, hov and 0.9 or 0.5)
    lg.rectangle("line", x + 0.5, y + 0.5, w - 1, h - 1)
    lg.setFont(font)
    col(C.bg)
  else
    col(c, hov and 0.25 or (enabled and 0.09 or 0.03))
    lg.rectangle("fill", x, y, w, h)
    H.brackets(x, y, w, h, 6, enabled and c or C.faint, hov and 1 or 0.85)
    lg.setFont(font)
    col(enabled and (hov and C.white or c) or C.faint)
  end
  lg.printf(text, x, y + h / 2 - font:getHeight() / 2, w, "center")
  H.addHit(x, y, w, h, function() if enabled then fn() else H.onError() end end, clip, hold)
end

-- red count badge (notification pattern)
function H.badge(x, y, n, c)
  if not n or n <= 0 then return end
  local txt = n > 99 and "99+" or tostring(n)
  local f = H.fonts.xs
  local w = math.max(16, f:getWidth(txt) + 8)
  c = c or C.red
  col(c)
  lg.rectangle("fill", x - w / 2, y - 8, w, 16, 8, 8)
  -- dark text on bright badges, light text on dark ones
  local lum = 0.3 * c[1] + 0.59 * c[2] + 0.11 * c[3]
  col(lum > 0.62 and C.bg or C.white)
  lg.setFont(f)
  lg.printf(txt, x - w / 2, y - 6, w, "center")
end

-- standard panel card with optional header
function H.card(x, y, w, h, title, c, sub)
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
  col(bg or C.faint, 0.6); lg.rectangle("fill", x, y, w, h)
  col(c or C.line); lg.rectangle("fill", x, y, w * clamp(frac, 0, 1), h)
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
