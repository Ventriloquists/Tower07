-- MEMES: real meme sounds (sounds/ folder), Impact-font image-macro captions, "press F to pay respects",
-- and the visual gags of the meme theme pack (MLG hitmarkers, doge speak, illuminati eye, crewmates, fire).
local V = require "lib.view"
local H = require "lib.hud"
local FX = require "game.fx"
local lg = V.lg
local C, col = H.C, H.col
local TAU = math.pi * 2
local M = {fx = nil, enabled = false, captionsOn = false} -- only switched on by the meme themes

----------------------------------------------------------------------
-- sounds (lazy loaded from sounds/, missing files are simply skipped)
----------------------------------------------------------------------
local MLG = " - MLG Sound Effect (HD) ( 160kbps ).mp3"
local MLGS = " - MLG Sound Effects (HD) ( 160kbps ).mp3"
M.FILES = {
  click = "u_1thl5d0szy-memeclick-506437.mp3",
  igotthis = "johnnybacon156-i-got-this-467997.mp3",
  fah = "johnnybacon156-fah-469417.mp3",
  what = "50986408-what-meme-388653.mp3",
  aa = "50986408-aa-with-reverb-meme-381632.mp3",
  fart = "apebble-fart-4-228244.mp3",
  thud = "dragon-studio-thud-sound-effect-405470.mp3",
  thud2 = "u_60prvfn0xb-thud-sound-effect-319090.mp3",
  carhorn = "ennismore-goofy-ahh-car-horn-200870.mp3",
  discord = "jeremayjimenez-discord-sfx-calling-250633.mp3",
  sus = "shelvis_makes_games-sus-meme-sound-181271.mp3",
  fox = "20th Century Recorder Edition" .. MLG,
  damnson = "Damn Son Where_d You Find This" .. MLG,
  woweffect = "Damn Son You Just Hit With the Wow Effect" .. MLG,
  wam = "Dedotated Wam" .. MLG,
  trickshot = "FUNNIEST TRICKSHOT REACTION" .. MLGS,
  gottagofast = "Gotta Go Fast (Sonic Theme)" .. MLG,
  illuminatihyper = "Hyper Distorted Illuminati Confirmed" .. MLG,
  violinhyper = "Hyper Distorted Sad Violin" .. MLGS,
  illuminati = "ILLUMINATI CONFIRMED" .. MLGS,
  horns = "MLG Horns" .. MLGS,
  camera = "MOM GET THE CAMERA" .. MLGS,
  noone = "NO ONE HAS EVER DONE THAT" .. MLG,
  triple = "OH BABY A TRIPLE" .. MLGS,
  ohmygod = "OH OH MY GOD (Trickshot Reaction)" .. MLGS,
  sike = "SIKE THAT_S THE WRONG NUMBER" .. MLG,
  violin = "Sad Violin" .. MLGS,
  violinhorn = "Sad Violin Airhorn" .. MLGS,
  weed = "Smoke Weed Everyday" .. MLG,
  noscope = "THATS RIGHT GET NOSCOPED" .. MLGS,
  wombo = "WOMBO COMBO HAPPY FEET" .. MLGS,
  wow = "WOW" .. MLG,
}
local src, lastPlay = {}, {}
local function load(key)
  if src[key] ~= nil then return src[key] end
  src[key] = false
  local f = M.FILES[key]
  if f and love.filesystem.getInfo("sounds/" .. f) then
    local ok, s = pcall(love.audio.newSource, "sounds/" .. f, "static")
    if ok then src[key] = s end
  end
  return src[key]
end
-- plays a meme clip; short clips can stack, long ones never overlap themselves
function M.play(key, vol, gap)
  local s = load(key)
  if not s or FX.muted then return false end
  local now = love.timer.getTime()
  if now - (lastPlay[key] or -99) < (gap or 0.12) then return false end
  lastPlay[key] = now
  local dur = s:getDuration()
  local v = (vol or 1) * FX.vol.reward
  if v <= 0.001 then return true end
  if dur > 2.5 then
    s:stop(); s:setVolume(v); s:play()
  else
    local c = s:clone(); c:setVolume(v); c:play()
  end
  return true
end
function M.available() return love.filesystem.getInfo("sounds") ~= nil end

-- the meme sound pack: every game sound gets a meme stand-in (nil = keep the normal sound)
M.MAP = {
  tap = "click", err = "fah", hit = "thud2", boom = "thud", alert = "carhorn", raid = "sus", signal = "discord",
  catch = "damnson", collect = "horns", log = "wow", unlock = "wow", rank = "woweffect", jackpot = "triple",
  mythic = "illuminati", prism = "ohmygod", reboot = "violinhorn", surge = "gottagofast", shatter = "fox",
  crack = "thud", slam = "thud", vineboom = "thud", airhorn = "horns", illuminati = "illuminati",
}
FX.memeHook = function(name) -- called by FX.play when the meme pack is active
  local key = M.MAP[name]
  if not key then return false end
  return M.play(key, nil, name == "tap" and 0.05 or 0.15) or true
end

----------------------------------------------------------------------
-- Impact captions (image macro style: top + bottom text, white with a black outline)
----------------------------------------------------------------------
local impact = {}
local function impactFont(size)
  local px = math.floor(size * V.s + 0.5)
  local key = px
  if impact[key] == nil then
    impact[key] = false
    pcall(function()
      local fh = io.open((os.getenv("WINDIR") or "C:/Windows") .. "/Fonts/impact.ttf", "rb")
      if fh then
        local d = fh:read("*a"); fh:close()
        impact[key] = love.graphics.newFont(love.filesystem.newFileData(d, "impact.ttf"), px)
      end
    end)
  end
  return impact[key] or love.graphics.getFont()
end
local function macroText(text, cx, y, size, w, a)
  local f = impactFont(size)
  local s = 1 / V.s
  local ox = cx - w / 2
  love.graphics.setFont(f)
  local o = math.max(1.5, size * 0.06)
  love.graphics.setColor(0, 0, 0, a)
  for dx = -1, 1 do for dy = -1, 1 do
    if dx ~= 0 or dy ~= 0 then love.graphics.printf(text, ox + dx * o, y + dy * o, w * V.s, "center", 0, s, s) end
  end end
  love.graphics.setColor(1, 1, 1, a)
  love.graphics.printf(text, ox, y, w * V.s, "center", 0, s, s)
end
M.caps = {}
local capT = -99
function M.resetCaption() capT = -99 end
function M.caption(top, bottom, dur, force)
  if not M.captionsOn then return end
  local now = love.timer.getTime()
  if not force and now - capT < 2.5 then return end -- one macro at a time
  capT = now
  M.caps = {{top = top, bottom = bottom, t = 0, max = dur or 2.4}}
end

----------------------------------------------------------------------
-- events: the moments that deserve a meme
----------------------------------------------------------------------
local EVENTS = {
  overheat   = {"sike", "THIS IS FINE", "THE CORE IS ON FIRE"},
  rhythm     = {"wombo", "WOMBO COMBO", "PERFECT RHYTHM"},
  tet        = {"noscope", "360 NO SCOPE", "GET REKT"},
  bossSpawn  = {"illuminatihyper", "BOSS MUSIC", "INTENSIFIES"},
  bossKill   = {"trickshot", "GG", "EZ"},
  bounty     = {"damnson", "DAMN SON", "WHERE'D YOU FIND THIS"},
  prism      = {"camera", "MOM GET THE CAMERA", "NO ONE HAS EVER DONE THAT"},
  mia        = {"violinhyper", nil, "PRESS F TO PAY RESPECTS"},
  bayFull    = {"wam", "YOUR BAY IS FULL", "DOWNLOAD MORE DEDOTATED WAM"},
  reboot     = {"violinhorn", "IT'S FREE", "REAL ESTATE"},
  zoneClear  = {"fox", "ACHIEVEMENT GET", "ZONE CLEARED"},
  legendary  = {"triple", nil, "POGGERS"},
  mythic     = {"illuminati", "ILLUMINATI", "CONFIRMED"},
  jackpot    = {"weed", "1 IN 1000", "EVERYDAY"},
  over9000   = {"aa", "IT'S OVER", "9000!!!"},
  combo      = {"triple", "C-C-C-COMBO", "BREAKER"},
  fiesta     = {"gottagofast", nil, "GOTTA GO FAST"},
  error      = {"what", nil, nil},
}
function M.event(name)
  if not M.enabled then return end
  local e = EVENTS[name]
  if not e then return end
  if FX.soundPack == "meme" and e[1] then M.play(e[1], 1, 0.5) end
  if name == "prism" and FX.soundPack == "meme" then M.after = {t = 2.2, key = "noone"} end
  if name == "mia" then M.fPrompt = 6 end
  if e[2] or e[3] then M.caption(e[2], e[3], name == "prism" and 3.2 or 2.4, name == "prism") end
end
FX.onPrism = function() M.event("prism") end

-- press F to pay respects
M.fPrompt = 0
function M.pressF(S)
  if M.fPrompt <= 0 then return false end
  M.fPrompt = 0
  S.respects = (S.respects or 0) + 1
  FX.toast("RESPECTS PAID", "Respects paid: " .. S.respects .. ". The fleet remembers.", C.dim)
  FX.play("tick", 0.6)
  M.caption(nil, "F", 1.4, true)
  return true
end

----------------------------------------------------------------------
-- meme theme gags
----------------------------------------------------------------------
local DOGE = {"such harvest", "very tower", "much energy", "wow", "so drone", "many loot", "very scav", "much click",
  "so prism", "amaze", "excite", "such reboot", "very hydro", "plz tap", "much wow"}
local floaters, hitmarkers, crew = {}, {}, nil
local spawnT = 0
function M.hitmarker(x, y)
  if M.fx ~= "mlg" then return end
  hitmarkers[#hitmarkers + 1] = {x = x, y = y, t = 0}
  if #hitmarkers > 12 then table.remove(hitmarkers, 1) end
end

-- the comms feed occasionally picks up meme chatter
local CHATTER = {
  {"TASK FAILED SUCCESSFULLY", "Harvest error 0x0: everything worked."},
  {"STONKS", "Energy number go up. Investors are pleased."},
  {"IT'S FREE REAL ESTATE", "The scavs left a sector unattended."},
  {"HELLO THERE", "General Kenobi has entered the sector."},
  {"IGHT IMMA HEAD OUT", "A scout scav has left the map."},
  {"THIS IS FINE", "Core temperature nominal. Probably."},
  {"IS THIS LOSS?", "| || || |_"},
  {"NEVER GONNA GIVE YOU UP", "Never gonna let your drones down."},
  {"I AM THE SENATE", "The tower is the law now."},
  {"WE'LL BE RIGHT BACK", "Technical difficulties in sector C4."},
  {"POV: YOU TAPPED THE CORE", "The core felt that."},
  {"NOBODY:", "Absolutely nobody:  The tower: *harvests*"},
  {"ONE DOES NOT SIMPLY", "Walk into zone 7."},
  {"WHY ARE YOU RUNNING", "A scav is fleeing your turret. WHY ARE YOU RUNNING?"},
  {"TO BE CONTINUED", "Roundabout intensifies."},
  {"OK BOOMER", "The tower's oldest drone has opinions."},
  {"CHAD SCAVS VS VIRGIN DRONES", "The drones disagree."},
  {"DOGE APPROVES", "much harvest. very tower. wow."},
}
local chatterT = 90
function M.update(dt)
  if M.enabled then
    chatterT = chatterT - dt
    if chatterT <= 0 then
      chatterT = H.rnd(80, 160)
      local c = CHATTER[love.math.random(#CHATTER)]
      FX.toast("MEME // " .. c[1], c[2], C.gold)
    end
  end
  for i = #M.caps, 1, -1 do
    local c = M.caps[i]
    c.t = c.t + dt
    if c.t >= c.max then table.remove(M.caps, i) end
  end
  if M.after then
    M.after.t = M.after.t - dt
    if M.after.t <= 0 then M.play(M.after.key, 1, 0.5); M.after = nil end
  end
  M.fPrompt = math.max(0, M.fPrompt - dt)
  for i = #hitmarkers, 1, -1 do
    hitmarkers[i].t = hitmarkers[i].t + dt
    if hitmarkers[i].t > 0.35 then table.remove(hitmarkers, i) end
  end
  for i = #floaters, 1, -1 do
    local f = floaters[i]
    f.t = f.t + dt
    f.y = f.y - 12 * dt
    if f.t > f.max then table.remove(floaters, i) end
  end
  spawnT = spawnT - dt
  if M.fx == "doge" and spawnT <= 0 then
    spawnT = 1.1
    floaters[#floaters + 1] = {text = DOGE[love.math.random(#DOGE)], x = H.rnd(80, 1200), y = H.rnd(110, 600), t = 0, max = 2.6,
      c = {H.hue(love.math.random())}, rot = H.rnd(-0.2, 0.2), size = H.rnd(18, 30)}
  elseif M.fx == "mlg" and spawnT <= 0 then
    spawnT = H.rnd(4, 8)
    local words = {"360 NO SCOPE", "MLG", "REKT", "+100", "QUICKSCOPE", "WOW", "OHHHH"}
    floaters[#floaters + 1] = {text = words[love.math.random(#words)], x = H.rnd(150, 1130), y = H.rnd(150, 560), t = 0, max = 1.6,
      c = {H.hue(love.math.random())}, rot = H.rnd(-0.4, 0.4), size = 34, spin = H.rnd(-6, 6)}
  elseif M.fx == "amogus" and not crew and love.math.random() < dt / 9 then
    crew = {x = -60, y = H.rnd(560, 610), vx = H.rnd(70, 110), c = {H.hue(love.math.random())}, t = 0}
  end
  if crew then
    crew.t = crew.t + dt
    crew.x = crew.x + crew.vx * dt
    if crew.x > 1360 then crew = nil end
  end
end

local function drawCrewmate(x, y, c, t)
  local bob = math.abs(math.sin(t * 8)) * 3
  y = y - bob
  love.graphics.setColor(c[1] * 0.6, c[2] * 0.6, c[3] * 0.6)
  love.graphics.rectangle("fill", x - 22, y - 8, 10, 22, 4, 4)           -- backpack
  love.graphics.setColor(c[1], c[2], c[3])
  love.graphics.rectangle("fill", x - 14, y - 22, 30, 40, 13, 13)       -- body
  love.graphics.rectangle("fill", x - 12, y + 12, 10, 12, 3, 3)         -- legs
  love.graphics.rectangle("fill", x + 4, y + 12, 10, 12, 3, 3)
  love.graphics.setColor(0.6, 0.85, 0.95)
  love.graphics.rectangle("fill", x - 2, y - 14, 20, 12, 6, 6)          -- visor
  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.rectangle("fill", x + 6, y - 12, 7, 4, 2, 2)
end

function M.draw()
  local t = love.timer.getTime()
  -- theme gags
  if M.fx == "illuminati" then
    local cx, cy = 1210, 600
    local a = 0.45 + 0.15 * math.sin(t * 2)
    lg.setBlendMode("add")
    for k = 1, 3 do col(C.gold, 0.05 * k); lg.circle("fill", cx, cy, 60 - k * 12, 32) end
    lg.setBlendMode("alpha")
    col(C.gold, a); lg.setLineWidth(2)
    lg.polygon("line", cx, cy - 46, cx + 42, cy + 26, cx - 42, cy + 26)
    lg.ellipse("line", cx, cy + 2, 16, 9, 24)
    lg.circle("fill", cx + 4 * math.sin(t * 0.7), cy + 2, 5, 16)
    for k = 0, 11 do
      local an = k / 12 * TAU + t * 0.15
      lg.line(cx + math.cos(an) * 52, cy + math.sin(an) * 52, cx + math.cos(an) * 64, cy + math.sin(an) * 64)
    end
    lg.setLineWidth(1)
  elseif M.fx == "fine" then
    -- the room is on fire
    lg.setBlendMode("add")
    for k = 0, 40 do
      local x = k * 33 + math.sin(t * 2 + k) * 8
      local h = 40 + 30 * math.sin(t * 5 + k * 1.7) + 20 * math.sin(t * 3.1 + k)
      col(C.orange, 0.10); lg.ellipse("fill", x, 640, 26, h, 16)
      col(C.red, 0.08); lg.ellipse("fill", x + 12, 650, 18, h * 0.7, 16)
    end
    lg.setBlendMode("alpha")
  elseif M.fx == "amogus" and crew then
    drawCrewmate(crew.x, crew.y, crew.c, crew.t)
    if crew.x > 500 and crew.x < 800 then
      lg.setFont(H.fonts.s); col(C.white, 0.8); lg.print("sus", crew.x - 10, crew.y - 48)
    end
  end
  for _, f in ipairs(floaters) do
    local a = math.min(1, f.t * 4) * math.min(1, (f.max - f.t) * 2)
    if M.fx == "doge" then
      lg.push(); lg.translate(f.x, f.y); lg.rotate(f.rot)
      lg.setFont(H.fonts.xl); lg.setColor(f.c[1] * 0.7, f.c[2] * 0.7, f.c[3] * 0.7, a); lg.print(f.text, 0, 0)
      lg.pop()
    else
      lg.push(); lg.translate(f.x, f.y); lg.rotate(f.rot + (f.spin or 0) * f.t)
      macroText(f.text, 0, -20, f.size, 400, a)
      lg.pop()
    end
  end
  -- hitmarkers (MLG)
  for _, h in ipairs(hitmarkers) do
    local a = 1 - h.t / 0.35
    lg.setLineWidth(3); col({1, 1, 1}, a)
    for _, d in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
      lg.line(h.x + d[1] * 6, h.y + d[2] * 6, h.x + d[1] * 16, h.y + d[2] * 16)
    end
    lg.setLineWidth(1)
  end
  -- press F prompt
  if M.fPrompt > 0 then
    local a = math.min(1, M.fPrompt)
    col(C.bg, 0.7 * a); lg.rectangle("fill", 640 - 150, 560, 300, 40)
    col(C.white, a); lg.rectangle("line", 640 - 150, 560, 300, 40)
    lg.setFont(H.fonts.m); lg.printf("PRESS  [F]  TO PAY RESPECTS", 640 - 150, 570, 300, "center")
  end
  -- image macro captions
  for _, c in ipairs(M.caps) do
    local p = c.t / c.max
    local a = math.min(1, c.t * 6) * (p > 0.8 and (1 - p) / 0.2 or 1)
    local pop = 1 + 0.25 * math.max(0, 1 - c.t * 5)
    lg.push(); lg.translate(640, 0); lg.scale(pop, pop)
    if c.top then macroText(c.top, 0, 70 / pop, 60, 1200, a) end
    if c.bottom then macroText(c.bottom, 0, (720 - 140) / pop, 60, 1200, a) end
    lg.pop()
  end
end

return M
