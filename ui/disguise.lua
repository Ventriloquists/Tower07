-- Boss key screens (F12): a fake spreadsheet, a scrolling build log, or a black screen.
local V = require "lib.view"
local H = require "lib.hud"
local lg = V.lg
local Dg = {}

Dg.TITLES = {sheet = "Q3_Budget_FINAL_v7(2).xlsx", log = "build - make -j8", black = " "}

-- deterministic fake data
local rng = love.math.newRandomGenerator(4207)
local SHEET = {}
local HEAD = {"Region", "Jan", "Feb", "Mar", "Q1 Total", "Forecast", "Variance", "Owner", "Status"}
local REGIONS = {"North", "South", "East", "West", "Central", "EMEA", "APAC", "LATAM", "Online", "Retail", "Wholesale",
  "Partners", "Services", "Licensing", "Support", "Hardware", "Training", "Consulting", "Other"}
local OWNERS = {"M. Keller", "J. Ortiz", "S. Brandt", "A. Novak", "R. Chen", "L. Haas"}
local STATUS = {"OK", "Review", "Pending", "OK", "OK", "Escalated"}
for r = 1, #REGIONS do
  local a, b, c = rng:random(8000, 60000), rng:random(8000, 60000), rng:random(8000, 60000)
  local fc = math.floor((a + b + c) * (0.9 + rng:random() * 0.25))
  SHEET[r] = {REGIONS[r], a, b, c, a + b + c, fc, a + b + c - fc, OWNERS[rng:random(#OWNERS)], STATUS[rng:random(#STATUS)]}
end
local function money(n)
  local s = string.format("%.2f", math.abs(n))
  local int, dec = s:match("(%d+)%.(%d+)")
  int = int:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
  return (n < 0 and "-" or "") .. int .. "." .. dec
end

local LOG = {}
do
  local dirs = {"core", "net", "render", "audio", "io", "util", "physics", "ui", "db", "auth"}
  local files = {"AllocatorPool", "SocketManager", "ShaderCache", "MixerBus", "FileWatcher", "StringTable", "Broadphase",
    "LayoutEngine", "QueryPlanner", "TokenStore", "ThreadPool", "EventQueue", "Serializer", "ConfigLoader", "Scheduler"}
  local n = 0
  for i = 1, 600 do
    n = n + 1
    local pct = math.floor((i % 300) / 300 * 100)
    local f = files[rng:random(#files)]
    local d = dirs[rng:random(#dirs)]
    if rng:random() < 0.06 then
      LOG[n] = {"src/" .. d .. "/" .. f .. ".cpp:" .. rng:random(20, 900) .. ":" .. rng:random(3, 40) ..
        ": warning: unused variable 'tmp' [-Wunused-variable]", 1}
    elseif rng:random() < 0.04 then
      LOG[n] = {"[" .. string.format("%3d", pct) .. "%] Linking CXX static library lib" .. d .. ".a", 2}
    else
      LOG[n] = {"[" .. string.format("%3d", pct) .. "%] Building CXX object src/" .. d .. "/CMakeFiles/" .. d ..
        ".dir/" .. f .. ".cpp.o", 0}
    end
  end
end

local function sheet()
  local Fo = H.fonts
  local x0, y0, x1, y1 = V.extents()
  lg.setColor(1, 1, 1); lg.rectangle("fill", x0, y0, x1 - x0, y1 - y0)
  -- title + menu
  lg.setColor(0.93, 0.93, 0.93); lg.rectangle("fill", x0, 0, x1 - x0, 64)
  lg.setFont(Fo.s); lg.setColor(0.2, 0.2, 0.2); lg.printf(Dg.TITLES.sheet, 0, 6, 1280, "center")
  lg.setFont(Fo.xs); lg.setColor(0.3, 0.3, 0.3)
  local mx = 16
  for _, m in ipairs({"File", "Edit", "View", "Insert", "Format", "Data", "Tools", "Help"}) do lg.print(m, mx, 30); mx = mx + 56 end
  lg.setColor(0.8, 0.8, 0.8); lg.line(x0, 64, x1, 64)
  -- formula bar
  lg.setColor(1, 1, 1); lg.rectangle("fill", x0, 64, x1 - x0, 28)
  lg.setColor(0.4, 0.4, 0.4); lg.print("F7", 16, 72); lg.print("fx", 70, 72)
  lg.setColor(0.1, 0.1, 0.1); lg.print("=E7-SUM(B7:D7)*1.07", 100, 72)
  lg.setColor(0.8, 0.8, 0.8); lg.line(x0, 92, x1, 92)
  -- grid
  local cw = {44, 120, 96, 96, 96, 110, 110, 104, 110, 96, 96, 96, 96}
  local rh, gy = 22, 92
  lg.setColor(0.95, 0.95, 0.95); lg.rectangle("fill", x0, gy, x1 - x0, rh)
  local x = 0
  for c = 1, #cw do
    lg.setColor(0.85, 0.85, 0.85); lg.line(x, gy, x, 680)
    if c > 1 then lg.setColor(0.35, 0.35, 0.35); lg.printf(string.char(63 + c), x, gy + 5, cw[c], "center") end
    x = x + cw[c]
  end
  for r = 1, 26 do
    local y = gy + r * rh
    lg.setColor(0.88, 0.88, 0.88); lg.line(x0, y, x1, y)
    lg.setColor(0.95, 0.95, 0.95); lg.rectangle("fill", 0, y, cw[1], rh)
    lg.setColor(0.35, 0.35, 0.35); lg.printf(tostring(r), 0, y + 5, cw[1], "center")
    local row = r == 1 and HEAD or SHEET[r - 1]
    if row then
      local cx = cw[1]
      for c = 1, #row do
        local val = row[c]
        local txt = type(val) == "number" and money(val) or val
        lg.setColor(r == 1 and 0.1 or 0.15, r == 1 and 0.1 or 0.15, r == 1 and 0.1 or 0.15)
        if type(val) == "number" and val < 0 then lg.setColor(0.75, 0.1, 0.1) end
        if val == "Escalated" then lg.setColor(0.8, 0.3, 0.0) end
        lg.printf(txt, cx + 4, y + 5, cw[c + 1] - 8, type(val) == "number" and "right" or "left")
        cx = cx + cw[c + 1]
      end
    end
  end
  -- selection
  lg.setColor(0.1, 0.45, 0.85); lg.setLineWidth(2)
  local sx = cw[1] + cw[2] + cw[3] + cw[4] + cw[5] + cw[6]
  lg.rectangle("line", sx, gy + 7 * rh, cw[7], rh)
  lg.setLineWidth(1)
  -- sheet tabs
  lg.setColor(0.93, 0.93, 0.93); lg.rectangle("fill", x0, 690, x1 - x0, 30)
  local tx = 16
  for k, t in ipairs({"Summary", "Q3 Budget", "Forecast", "Sheet3"}) do
    local w = Fo.xs:getWidth(t) + 24
    lg.setColor(k == 2 and 1 or 0.88, k == 2 and 1 or 0.88, k == 2 and 1 or 0.88); lg.rectangle("fill", tx, 692, w, 24)
    lg.setColor(0.25, 0.25, 0.25); lg.print(t, tx + 12, 698)
    tx = tx + w + 2
  end
  lg.setColor(0.4, 0.4, 0.4); lg.printf("Ready        Sum: 1,284,551.07", 0, 698, 1264, "right")
end

local function buildLog(t)
  local Fo = H.fonts
  local x0, y0, x1, y1 = V.extents()
  lg.setColor(0.05, 0.05, 0.06); lg.rectangle("fill", x0, y0, x1 - x0, y1 - y0)
  lg.setFont(Fo.xs)
  local shown = math.floor(t * 7) + 60
  local lines = 44
  for i = 1, lines do
    local idx = shown - lines + i
    local l = LOG[(idx - 1) % #LOG + 1]
    if l and idx > 0 then
      if l[2] == 1 then lg.setColor(0.95, 0.8, 0.3) elseif l[2] == 2 then lg.setColor(0.4, 0.9, 0.5) else lg.setColor(0.75, 0.75, 0.75) end
      lg.print(l[1], 12, 8 + (i - 1) * 16)
    end
  end
  if math.floor(t * 2) % 2 == 0 then lg.setColor(0.8, 0.8, 0.8); lg.rectangle("fill", 12, 8 + lines * 16, 8, 13) end
end

local function black(t)
  local x0, y0, x1, y1 = V.extents()
  lg.setColor(0, 0, 0); lg.rectangle("fill", x0, y0, x1 - x0, y1 - y0)
  if math.floor(t * 2) % 2 == 0 then lg.setColor(0.6, 0.6, 0.6); lg.rectangle("fill", 12, 12, 8, 14) end
end

function Dg.draw(kind, t)
  if kind == "log" then buildLog(t) elseif kind == "black" then black(t) else sheet() end
end

return Dg
