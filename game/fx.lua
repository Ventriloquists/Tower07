-- Particles, floating text, toasts, shockwaves and synthesized audio.
local V = require "lib.view"
local H = require "lib.hud"
local lg = V.lg
local C, col, rnd, clamp = H.C, H.col, H.rnd, H.clamp
local TAU = math.pi * 2

local FX = {particles = {}, floaters = {}, toasts = {}, waves = {}, rays = {}, snd = {}, muted = false,
  shake = 0, flash = 0, flashC = {1, 1, 1}}

----------------------------------------------------------------------
-- Audio
----------------------------------------------------------------------
local function synth(dur, fn)
  local rate = 44100
  local n = math.floor(rate * dur)
  local sd = love.sound.newSoundData(n, rate, 16, 1)
  for i = 0, n - 1 do
    local t = i / rate
    sd:setSample(i, clamp(fn(t, t / dur), -1, 1))
  end
  return love.audio.newSource(sd, "static")
end

local function arp(notes, dur, vol, harm)
  return synth(dur, function(t, p)
    local k = math.min(#notes, math.floor(p * #notes) + 1)
    local lp = p * #notes - (k - 1)
    local f = notes[k]
    return (math.sin(TAU * f * t) + (harm or 0) * math.sin(TAU * f * 2 * t)) * (1 - lp) * vol
  end)
end

function FX.init()
  local s = FX.snd
  s.tap = synth(0.06, function(t, p)
    return (math.sin(TAU * (1400 * t - 3500 * t * t)) * 0.7 + math.sin(TAU * 2800 * t) * 0.15) * (1 - p) ^ 3 * 0.35
  end)
  s.buy = synth(0.14, function(t, p)
    local f = p < 0.45 and 880 or 1320
    local e = p < 0.45 and (1 - p / 0.45) or (1 - (p - 0.45) / 0.55)
    return math.sin(TAU * f * t) * e * 0.25
  end)
  s.signal = synth(0.9, function(t, p)
    local f = (math.floor(t * 6) % 2 == 0) and 740 or 988
    return math.sin(TAU * f * t) * (1 - p) * 0.18 * (0.6 + 0.4 * math.sin(TAU * 12 * t))
  end)
  s.catch = synth(0.55, function(t, p)
    local v = math.sin(TAU * (600 * t + 1600 * t * t)) + 0.5 * math.sin(TAU * (1200 * t + 3200 * t * t))
    return v * (1 - p) ^ 1.5 * 0.22
  end)
  s.log = arp({659, 880, 1109, 1319}, 0.6, 0.2)
  s.rank = arp({523, 659, 784, 1047, 1319, 1568}, 1.1, 0.18, 0.3)
  s.jackpot = arp({784, 988, 1175, 1568, 1976, 2349, 3136}, 1.6, 0.17, 0.4)
  s.unlock = arp({440, 660, 880, 1320}, 0.9, 0.2, 0.5)
  s.reboot = synth(2.2, function(t, p)
    local v = math.sin(TAU * (40 + 300 * (1 - p)) * t) * 0.5 + (love.math.random() * 2 - 1) * 0.35 * (1 - p)
    return v * (1 - p) ^ 2 * 0.6
  end)
  s.err = synth(0.12, function(t, p) return (math.sin(TAU * 180 * t) > 0 and 1 or -1) * (1 - p) * 0.08 end)
  s.alert = synth(0.35, function(t, p)
    local on = (p < 0.4) or (p > 0.55 and p < 0.95)
    return on and math.sin(TAU * 1046 * t) * 0.16 or 0
  end)
  do
    local y = 0
    s.collect = synth(0.7, function(t, p)
      local k = 0.02 + 0.25 * p
      y = y + ((love.math.random() * 2 - 1) - y) * k
      return y * math.sin(math.pi * p) * 0.9 + math.sin(TAU * (300 + 500 * p) * t) * (1 - p) * 0.08
    end)
  end
  s.tick = synth(0.025, function(t, p) return math.sin(TAU * 2200 * t) * (1 - p) * 0.15 end)
  s.mythic = synth(2.6, function(t, p)
    local notes = {523, 659, 784, 1047, 1319, 1568, 2093}
    local k = math.min(#notes, math.floor(p * 9) + 1)
    local f = notes[k]
    local v = math.sin(TAU * f * t) * 0.5 + math.sin(TAU * f * 1.5 * t) * 0.25 + math.sin(TAU * f * 2 * t) * 0.15
    local shimmer = math.sin(TAU * (3000 + 800 * math.sin(TAU * 3 * t)) * t) * 0.06
    return (v * 0.22 + shimmer) * math.min(1, p * 20) * (1 - p) ^ 0.7
  end)
  s.hit = synth(0.05, function(t, p)
    return ((love.math.random() * 2 - 1) * 0.5 + math.sin(TAU * 520 * t) * 0.5) * (1 - p) ^ 2 * 0.25
  end)
  s.laser = synth(0.08, function(t, p) return math.sin(TAU * (2400 - 1800 * p) * t) * (1 - p) * 0.08 end)
  s.boom = synth(0.6, function(t, p)
    return ((love.math.random() * 2 - 1) * 0.7 + math.sin(TAU * (90 - 50 * p) * t) * 0.6) * (1 - p) ^ 2.5 * 0.45
  end)
  s.crate = arp({880, 1175, 1568}, 0.3, 0.18, 0.3)
  s.crack = synth(0.3, function(t, p)
    return ((love.math.random() * 2 - 1) * (1 - p) ^ 8 * 0.8 + math.sin(TAU * 4200 * t) * (1 - p) ^ 5 * 0.25) * 0.6
  end)
  do
    local pings = {}
    for k = 1, 40 do pings[k] = {t0 = love.math.random() ^ 2 * 1.1, f = 2200 + love.math.random() * 5200} end
    s.shatter = synth(1.6, function(t, p)
      local v = (love.math.random() * 2 - 1) * (1 - p) ^ 6 * 0.7
      for _, g in ipairs(pings) do
        if t > g.t0 then v = v + math.sin(TAU * g.f * (t - g.t0)) * math.exp(-(t - g.t0) * 22) * 0.16 end
      end
      return v * 0.55
    end)
  end
  s.slam = synth(0.5, function(t, p)
    return (math.sin(TAU * (120 - 60 * p) * t) * 0.8 + (love.math.random() * 2 - 1) * (1 - p) ^ 6 * 0.4) * (1 - p) ^ 2 * 0.6
  end)
  -- PRISM: shimmering rising arpeggio over a sub-bass swell
  s.prism = synth(3.2, function(t, p)
    local notes = {523, 659, 784, 988, 1175, 1568, 1976, 2349, 3136}
    local k = math.min(#notes, math.floor(t * 6) % #notes + 1)
    local f = notes[k] * (1 + math.floor(t * 6 / #notes) * 0.5)
    local arp = math.sin(TAU * f * t) * 0.25 + math.sin(TAU * f * 1.5 * t) * 0.1
    local chord = (math.sin(TAU * 261.6 * t) + math.sin(TAU * 329.6 * t) + math.sin(TAU * 392 * t) + math.sin(TAU * 523.2 * t)) * 0.08
    local sub = math.sin(TAU * (40 + 25 * p) * t) * 0.4 * math.sin(math.pi * math.min(1, p * 2))
    return (arp * (0.6 + 0.4 * math.sin(TAU * 7 * t)) + chord + sub) * math.min(1, p * 30) * (1 - p) ^ 0.6 * 0.7
  end)
  ------------------------------------------------------------------ stupid pack (cursed themes)
  local function saw(x) return 2 * (x - math.floor(x)) - 1 end
  local function sq(x) return (x - math.floor(x)) < 0.5 and 1 or -1 end
  do -- duck quack: nasal square with a pitch drop
    local ph = 0
    s.quack = synth(0.2, function(t, p)
      ph = ph + (520 - 260 * p) / 44100
      local v = sq(ph) * 0.45 + math.sin(TAU * ph * 2) * 0.3 + math.sin(TAU * ph * 3.1) * 0.15
      return v * math.min(1, p * 40) * (1 - p) ^ 1.4 * 0.35
    end)
  end
  do -- cartoon spring boing
    local ph = 0
    s.boing = synth(0.55, function(t, p)
      ph = ph + (230 + 140 * math.sin(TAU * 11 * t) * math.exp(-4 * t)) / 44100
      return math.sin(TAU * ph) * (1 - p) ^ 1.2 * 0.45
    end)
  end
  do -- rubber duck squeak
    local ph = 0
    s.squeak = synth(0.13, function(t, p)
      ph = ph + (1700 + 1200 * p) / 44100
      return (math.sin(TAU * ph) + (love.math.random() * 2 - 1) * 0.08) * math.sin(math.pi * p) * 0.25
    end)
  end
  do -- fart: fluttering low buzz, smoothed noise
    local ph, lp = 0, 0
    s.fart = synth(0.7, function(t, p)
      ph = ph + (75 + 25 * math.sin(TAU * 23 * t) - 30 * p) / 44100
      local raw = saw(ph) * (1 + 0.7 * math.sin(TAU * 31 * t)) + (love.math.random() * 2 - 1) * 0.6
      lp = lp + (raw - lp) * 0.18
      return clamp(lp * 1.6, -1, 1) * math.min(1, p * 15) * (1 - p) ^ 0.8 * 0.55
    end)
  end
  s.honk = synth(0.5, function(t, p) -- clown horn: honk-honk
    local on = (t < 0.18) or (t > 0.25 and t < 0.45)
    if not on then return 0 end
    local f = t < 0.2 and 440 or 370
    return (sq(f * t) * 0.5 + sq(f * 1.26 * t) * 0.3) * 0.25
  end)
  do -- kazoo fanfare
    local notes = {392, 392, 523, 659, 784, 784}
    local ph = 0
    s.kazoo = synth(1.3, function(t, p)
      local k = math.min(#notes, math.floor(t / 0.2) + 1)
      ph = ph + notes[k] * (1 + 0.02 * math.sin(TAU * 6 * t)) / 44100
      local v = saw(ph)
      v = v * math.abs(v) + 0.3 * saw(ph * 2)            -- buzzy
      local lp = (t % 0.2) / 0.2
      return v * (k == #notes and 1 or (1 - lp * 0.5)) * (1 - p) ^ 0.4 * 0.22
    end)
  end
  do -- slide whistle up
    local ph = 0
    s.slidewhistle = synth(0.6, function(t, p)
      ph = ph + (500 + 1100 * p + 30 * math.sin(TAU * 7 * t)) / 44100
      return math.sin(TAU * ph) * math.sin(math.pi * p) * 0.3
    end)
  end
  s.bonk = synth(0.3, function(t, p) -- wood block bonk
    return (math.sin(TAU * 820 * t) * math.exp(-28 * t) + math.sin(TAU * 170 * t) * math.exp(-10 * t) * 0.8
      + (love.math.random() * 2 - 1) * math.exp(-120 * t) * 0.5) * 0.5
  end)
  do -- sad trombone: wah wah wah waaaah
    local notes = {{0, 0.42, 233}, {0.48, 0.9, 220}, {0.96, 1.38, 208}, {1.44, 2.3, 196}}
    local ph = 0
    s.sadtrombone = synth(2.3, function(t, p)
      local f
      for _, n in ipairs(notes) do if t >= n[1] and t < n[2] then f = n end end
      if not f then return 0 end
      local local_p = (t - f[1]) / (f[2] - f[1])
      local vib = f[3] == 196 and 1 + 0.03 * math.sin(TAU * 5 * t) or 1
      ph = ph + f[3] * vib / 44100
      local v = saw(ph) * 0.5 + math.sin(TAU * ph) * 0.5
      return v * math.sin(math.pi * math.min(1, local_p * 1.2)) * 0.32
    end)
  end
  do -- "bruh": low voice-ish vowel with a 'b' pop
    local ph = 0
    s.bruh = synth(0.42, function(t, p)
      ph = ph + (110 - 25 * p) / 44100
      local v = 0
      for k = 1, 9 do
        local f = 110 * k
        local amp = math.exp(-((f - 650) / 380) ^ 2) + 0.4 * math.exp(-((f - 1100) / 300) ^ 2)
        v = v + math.sin(TAU * ph * k) * amp
      end
      local pop = (love.math.random() * 2 - 1) * math.exp(-80 * t) * 0.6
      return (v * 0.35 + pop) * math.min(1, p * 25) * (1 - p) ^ 0.9 * 0.6
    end)
  end
  s.dialup = synth(1.3, function(t, p) -- 56k modem handshake
    local seg = math.floor(t * 9)
    local f = ({1200, 2100, 980, 1650, 2400, 1300, 1800, 2250, 1000, 2600, 1500, 2000})[seg % 12 + 1]
    local v = math.sin(TAU * f * t) * 0.5 + math.sin(TAU * f * 1.5 * t) * 0.2
    if seg >= 6 then v = v * 0.5 + (love.math.random() * 2 - 1) * 0.45 end
    return v * 0.18 * (1 - p * 0.3)
  end)
  s.raid = synth(0.8, function(t, p)
    local f = 440 + 220 * math.sin(TAU * 2.5 * t)
    return (math.sin(TAU * f * t) > 0 and 1 or -1) * 0.07 * (1 - p)
  end)
  s.surge = synth(0.9, function(t, p)
    return (math.sin(TAU * (200 * t + 900 * t * t)) * 0.6 + (love.math.random() * 2 - 1) * 0.15) * math.sin(math.pi * p) * 0.4
  end)
end

-- volume groups (set from settings)
FX.vol = {ui = 1, reward = 1, alert = 1}
FX.density, FX.reduced = 1, false
local CATEGORY = {
  tap = "ui", tick = "ui", hit = "ui", laser = "ui", buy = "ui", err = "ui",
  signal = "alert", alert = "alert", raid = "alert", reboot = "alert",
}

-- cursed themes swap every sound for something stupid (and slightly random in pitch)
FX.soundPack = nil
local STUPID = {
  tap = "quack", tick = "squeak", buy = "boing", err = "fart", hit = "bonk", laser = "squeak", boom = "bonk",
  alert = "honk", raid = "honk", signal = "dialup", catch = "slidewhistle", collect = "slidewhistle", surge = "slidewhistle",
  log = "kazoo", rank = "kazoo", unlock = "kazoo", jackpot = "kazoo", mythic = "kazoo", prism = "kazoo", crate = "boing",
  reboot = "sadtrombone", crack = "bonk", shatter = "sadtrombone", slam = "bruh",
}
function FX.play(name, pitch, vol)
  local orig = name
  if FX.soundPack == "stupid" and STUPID[name] then
    name = STUPID[name]
    pitch = (pitch or 1) * (0.85 + love.math.random() * 0.35)
  end
  if FX.muted or not FX.snd[name] then return end
  local v = (vol or 1) * FX.vol[CATEGORY[orig] or "reward"]
  if v <= 0.001 then return end
  local s = FX.snd[name]:clone()
  s:setPitch(pitch or 1)
  s:setVolume(v)
  s:play()
end

-- seamless 8 s reactor hum: every partial completes a whole number of cycles per loop
function FX.initAmbient()
  local rate, dur = 22050, 8
  local n = rate * dur
  local sd = love.sound.newSoundData(n, rate, 16, 1)
  for i = 0, n - 1 do
    local t = i / rate
    local swell = 0.5 + 0.5 * math.sin(TAU * 0.25 * t)
    local v = math.sin(TAU * 55 * t) * 0.20 + math.sin(TAU * 55.25 * t) * 0.14
      + math.sin(TAU * 82.5 * t) * 0.08 * swell + math.sin(TAU * 165 * t) * 0.04 * (1 - swell)
      + math.sin(TAU * 220.125 * t) * 0.015
    sd:setSample(i, v * 0.8)
  end
  FX.ambient = love.audio.newSource(sd, "static")
  FX.ambient:setLooping(true)
end
function FX.setAmbient(v)
  if not FX.ambient then return end
  FX.ambient:setVolume(v * 0.7)
  if v > 0.001 and not FX.ambient:isPlaying() then FX.ambient:play()
  elseif v <= 0.001 and FX.ambient:isPlaying() then FX.ambient:stop() end
end

----------------------------------------------------------------------
-- Spawners
----------------------------------------------------------------------
function FX.burst(x, y, n, c, speed, size)
  local P = FX.particles
  n = math.floor(n * FX.density + 0.5)
  local cap = 900 * math.max(1, FX.density)
  for _ = 1, n do
    if #P > cap then return end
    local a = rnd(0, TAU)
    local sp = rnd(0.25, 1) * (speed or 220)
    P[#P + 1] = {x = x, y = y, vx = math.cos(a) * sp, vy = math.sin(a) * sp, life = 0,
      max = rnd(0.4, 1.1), c = c or C.line, s = (size or 2) * rnd(0.6, 1.4)}
  end
end
function FX.spark(x, y, vx, vy, c, life, size)
  local P = FX.particles
  if #P > 900 then return end
  P[#P + 1] = {x = x, y = y, vx = vx, vy = vy, life = 0, max = life or 1.5, c = c or C.line, s = size or 1.5}
end
function FX.floater(x, y, text, c, font, life)
  local F = FX.floaters
  F[#F + 1] = {x = x, y = y, text = text, c = c or C.white, font = font or H.fonts.s, life = 0, max = life or 1.1}
  if #F > 60 then table.remove(F, 1) end
end
-- messages go to a compact "comms feed" (newest first) instead of popups
function FX.toast(title, text, c)
  -- routine messages can be filtered out of the ticker ("IMPORTANT ONLY" setting)
  local low = title:find("^LOG ENTRY") or title:find("SECURED") or title:find("^SIGNAL TRACK // TIER")
    or title:find("^UNIT MILESTONE") or title:find("^DRONE .* JOINS")
  table.insert(FX.toasts, 1, {title = title, text = text or "", c = c or C.line, life = 0, low = low and true or false})
  while #FX.toasts > 8 do table.remove(FX.toasts) end
end
function FX.wave(x, y, r, c, speed, max)
  FX.waves[#FX.waves + 1] = {x = x, y = y, r = r, life = 0, max = max or 0.7, c = c or C.line, speed = speed or 260}
end

function FX.ray(x, y, c, life, size, prism)
  if FX.reduced then return end
  size = size or 300
  FX.rays[#FX.rays + 1] = {x = x, y = y, c = c, t = 0, max = life or 1.5, size = size, rot = rnd(0, TAU), prism = prism}
  local n = math.floor(size / 12 * FX.density)
  for _ = 1, n do
    FX.spark(x + rnd(-size * 0.06, size * 0.06), y + rnd(-6, 6), rnd(-25, 25), -rnd(80, 260 + size * 0.3), c, rnd(0.7, 1.6), rnd(1.5, 3))
  end
end
-- special loot sounds: tier 1 = LEGENDARY / PROTO, 2 = MYTHIC / OMEGA, 3 = PRISM
function FX.lootSound(tier)
  if tier == 1 then FX.play("jackpot")
  elseif tier == 2 then FX.play("mythic")
  else FX.play("prism"); FX.play("mythic", 0.8, 0.6) end
end

-- jackpot moment: slam title + chip fountain + a beat of slow motion
FX.slams, FX.slow = {}, 0
function FX.slam(text, x, y, c, prism)
  FX.slams[#FX.slams + 1] = {text = text, x = x, y = y, c = c, t = 0, max = 1.8, prism = prism}
  FX.play("slam", prism and 0.8 or 1)
  FX.shake = math.max(FX.shake, prism and 22 or 10)
  if not FX.reduced then FX.slow = math.max(FX.slow, prism and 0.35 or 0.1) end
  local P = FX.particles
  for _ = 1, math.floor((prism and 90 or 55) * FX.density) do
    local a = rnd(-math.pi * 0.85, -math.pi * 0.15)
    local sp = rnd(220, 560)
    P[#P + 1] = {x = x + rnd(-10, 10), y = y, vx = math.cos(a) * sp, vy = math.sin(a) * sp, life = 0, max = rnd(1.1, 2),
      c = prism and FX.hue(rnd(0, 1)) or (love.math.random() < 0.3 and C.white or c), s = rnd(3, 6), g = 900, chip = true, spin = rnd(-12, 12)}
  end
end
function FX.hue(h)
  local r = 0.5 + 0.5 * math.cos(TAU * h)
  local g = 0.5 + 0.5 * math.cos(TAU * (h - 1 / 3))
  local b = 0.5 + 0.5 * math.cos(TAU * (h - 2 / 3))
  return {r, g, b}
end
function FX.flashTo(c, a)
  FX.flash = math.max(FX.flash, a)
  FX.flashC = c
end

function FX.update(dt)
  for i = #FX.rays, 1, -1 do
    local r = FX.rays[i]
    r.t = r.t + dt
    if r.t >= r.max then table.remove(FX.rays, i) end
  end
  local P = FX.particles
  for i = #P, 1, -1 do
    local p = P[i]
    p.life = p.life + dt
    p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
    if p.g then p.vy = p.vy + p.g * dt; p.vx = p.vx * (1 - 0.6 * dt)
    else p.vx, p.vy = p.vx * (1 - 2.2 * dt), p.vy * (1 - 2.2 * dt) end
    if p.life >= p.max then table.remove(P, i) end
  end
  for i = #FX.floaters, 1, -1 do
    local f = FX.floaters[i]
    f.life = f.life + dt
    f.y = f.y - 55 * dt
    if f.life >= f.max then table.remove(FX.floaters, i) end
  end
  for _, t in ipairs(FX.toasts) do t.life = t.life + dt end
  if FX.prism then
    FX.prism.t = FX.prism.t + dt
    if FX.prism.t >= FX.prism.max then FX.prism = nil end
  end
  FX.updateLocks(dt)
  for i = #FX.slams, 1, -1 do
    local s = FX.slams[i]
    s.t = s.t + dt
    if s.t >= s.max then table.remove(FX.slams, i) end
  end
  for i = #FX.waves, 1, -1 do
    local w = FX.waves[i]
    w.life = w.life + dt
    w.r = w.r + w.speed * dt
    if w.life >= w.max then table.remove(FX.waves, i) end
  end
  FX.shake = math.max(0, FX.shake - dt * 30)
  FX.flash = math.max(0, FX.flash - dt)
end

----------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------
function FX.drawWaves()
  for _, w in ipairs(FX.waves) do
    col(w.c, (1 - w.life / w.max) * 0.8)
    lg.circle("line", w.x, w.y, w.r, 96)
  end
end

-- loot beam: vertical light pillar, four-point star flare, crisp shock rings (rainbow when prism)
local function spike(x, y, a, len, w, c, alpha)
  local ca, sa = math.cos(a), math.sin(a)
  col(c, alpha)
  lg.polygon("fill", x + ca * len, y + sa * len, x - sa * w, y + ca * w, x - ca * len, y - sa * len, x + sa * w, y - ca * w)
end
local function backOut(p) local s = 1.70158 p = p - 1 return p * p * ((s + 1) * p + s) + 1 end
function FX.drawRays()
  if #FX.rays == 0 then return end
  lg.setBlendMode("add")
  for _, r in ipairs(FX.rays) do
    local p = r.t / r.max
    local a = math.min(1, r.t * 8) * (1 - p) ^ 1.2
    local S = r.size
    local c = r.prism and FX.hue(r.t * 0.6) or r.c
    -- pillar of light up to the top of the screen
    local bw = S * 0.11 * (1 - 0.4 * p)
    for k, f in ipairs({1, 0.45, 0.14}) do
      col(k == 3 and C.white or c, a * ({0.07, 0.14, 0.45})[k])
      lg.rectangle("fill", r.x - bw * f, r.y - 2000, bw * f * 2, 2000)
    end
    col(c, a * 0.25); lg.ellipse("fill", r.x, r.y, bw * 2.2, bw * 0.5, 32)
    -- core glow
    col(c, a * 0.35); lg.circle("fill", r.x, r.y, S * 0.13, 32)
    col(C.white, a * 0.7); lg.circle("fill", r.x, r.y, S * 0.045, 24)
    -- star flare: 4 long spikes + 4 short diagonals, popping in with overshoot
    local pop = backOut(math.min(1, r.t * 3.5))
    local rot = r.rot * 0.15 + r.t * 0.35
    for k = 0, 3 do
      local ang = rot + k * math.pi / 2
      local sc = r.prism and FX.hue(r.t * 0.6 + k * 0.25) or c
      spike(r.x, r.y, ang, S * 0.55 * pop, 3 + S * 0.006, sc, a * 0.75)
      spike(r.x, r.y, ang, S * 0.38 * pop, 1.2, C.white, a * 0.8)
      spike(r.x, r.y, ang + math.pi / 4, S * 0.24 * pop, 2, sc, a * 0.5)
    end
    -- two crisp shock rings
    lg.setLineWidth(2)
    for k = 0, 1 do
      local q = math.max(0, p * 1.6 - k * 0.25)
      if q > 0 and q < 1 then
        col(c, (1 - q) * 0.8 * math.min(1, r.t * 8))
        lg.circle("line", r.x, r.y, S * (0.15 + q * 0.75), 64)
      end
    end
    lg.setLineWidth(1)
  end
  lg.setBlendMode("alpha")
end

function FX.drawSlams()
  for _, s in ipairs(FX.slams) do
    local p = s.t / s.max
    local inn = math.min(1, s.t / 0.16)
    local sc = 2.6 - 1.6 * inn + (inn >= 1 and 0.06 * math.max(0, 1 - (s.t - 0.16) * 6) or 0)
    local a = math.min(1, s.t * 10) * (p > 0.75 and (1 - p) / 0.25 or 1)
    local f = H.fonts.huge
    local w = f:getWidth(s.text)
    local c = s.prism and FX.hue(s.t * 0.8) or s.c
    lg.push(); lg.translate(s.x, math.max(150, s.y - 110) - p * 30); lg.scale(sc)
    lg.setFont(f)
    -- chromatic split on impact
    local off = (1 - inn) * 8 + 2
    lg.setBlendMode("add")
    col({1, 0.2, 0.2}, a * 0.5); lg.print(s.text, -w / 2 - off, -f:getHeight() / 2)
    col({0.2, 0.6, 1}, a * 0.5); lg.print(s.text, -w / 2 + off, -f:getHeight() / 2)
    lg.setBlendMode("alpha")
    col(C.bg, a * 0.6); lg.print(s.text, -w / 2 + 2, -f:getHeight() / 2 + 3)
    col(c, a); lg.print(s.text, -w / 2, -f:getHeight() / 2)
    lg.pop()
  end
end

function FX.drawParticles()
  FX.drawRays()
  lg.setBlendMode("add")
  for _, p in ipairs(FX.particles) do
    if not p.chip then
      col(p.c, (1 - p.life / p.max) * 0.9)
      lg.rectangle("fill", p.x - p.s / 2, p.y - p.s / 2, p.s, p.s)
    end
  end
  lg.setBlendMode("alpha")
  for _, p in ipairs(FX.particles) do
    if p.chip then
      col(p.c, math.min(1, (1 - p.life / p.max) * 2))
      lg.push(); lg.translate(p.x, p.y); lg.rotate(p.life * p.spin)
      lg.rectangle("fill", -p.s / 2, -p.s * 0.3 * math.abs(math.cos(p.life * p.spin)) - 0.5, p.s, p.s * 0.6 * math.abs(math.cos(p.life * p.spin)) + 1)
      lg.pop()
    end
  end
  FX.drawSlams()
  for _, f in ipairs(FX.floaters) do
    local a = 1 - (f.life / f.max) ^ 2
    lg.setFont(f.font)
    col(f.c, a)
    lg.print(f.text, f.x - f.font:getWidth(f.text) / 2, f.y)
  end
end

-- the PRISM takeover, drawn above everything else
----------------------------------------------------------------------
-- SIGNAL LOCK: the loot language. A reticle snaps onto the drop, the name decodes, a readout pins beside it.
-- tier 1..7 (common .. prism) scales lock time, decode length and how much frame the moment gets:
--   1-2 reticle + quick tag   3-4 decode   5 + a scan line across the screen   6 + gold viewport brackets
--   7 (prism) + one holographic sweep over the HUD, rainbow decode, holo brackets.
-- No shake, no flash, a handful of particles. Drawn above everything by FX.drawPrism.
----------------------------------------------------------------------
FX.locks, FX.scans, FX.frame = {}, {}, nil
local GLYPHS = "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789#/%+"
local function scramble(s, p, seed)
  if p >= 1 then return s end
  local n = #s
  local shown = math.floor(n * p)
  local out = {s:sub(1, shown)}
  for i = shown + 1, n do
    local ch = s:sub(i, i)
    if ch == " " then out[#out + 1] = " " else
      local k = (seed * 31 + i * 17) % #GLYPHS + 1
      out[#out + 1] = GLYPHS:sub(k, k)
    end
  end
  return table.concat(out)
end

-- opts: compact = tag above the target (for cards that already show the item), lines = extra detail lines
function FX.lock(x, y, tier, c, kind, name, opts)
  opts = opts or {}
  tier = math.max(1, math.min(7, tier))
  -- crowded (open-all, fiestas): drop the oldest quiet locks first
  while #FX.locks >= 5 do
    local drop = 1
    for i, l in ipairs(FX.locks) do if l.tier < FX.locks[drop].tier then drop = i end end
    table.remove(FX.locks, drop)
  end
  local l = {x = x, y = y, tier = tier, c = c, kind = kind or "", name = name or "", lines = opts.lines or {},
    compact = opts.compact, prism = tier >= 7, t = 0, bw = opts.w, bh = opts.h, map = opts.map}
  l.lockT = 0.1 + 0.03 * tier
  l.decT = tier <= 2 and 0 or 0.12 * tier
  l.hold = opts.compact and (0.7 + 0.15 * tier) or ((tier <= 2 and 0.9 or 1.5 + 0.25 * tier) + #l.lines * 0.3)
  -- readouts reserve their real rectangle when they open; a new card that would overlap one already up is
  -- pushed below it (or above, near the bottom edge), so cards never sit on top of each other
  if not opts.compact then
    local _, _, x1 = V.extents()
    l.side = (x > (x1 - 300)) and -1 or 1
    l.cardH = 38 + #l.lines * 14
    local s = 13 + tier * 2
    local base = y - s - 34
    local moved = true
    while moved do
      moved = false
      for _, o in ipairs(FX.locks) do
        if not o.compact and o.cardY and math.abs(o.x - x) < 360 and o.side == l.side
          and base < o.cardY + o.cardH + 8 and base + l.cardH + 8 > o.cardY then
          base = o.cardY + o.cardH + 8
          moved = true
        end
      end
    end
    if base + l.cardH > 620 then base = 620 - l.cardH end
    l.cardY = math.max(58, base)
  end
  l.max = l.lockT + l.decT + l.hold + 0.3
  FX.locks[#FX.locks + 1] = l
  FX.play("tick", 1.5 + tier * 0.06, 0.5)
  if tier >= 5 and not FX.reduced then FX.scans[#FX.scans + 1] = {x = x, y = y, t = 0, c = c} end
  if tier >= 6 then FX.frame = {t = 0, max = 2.2, c = c, holo = tier >= 7} end
end

function FX.updateLocks(dt)
  for i = #FX.locks, 1, -1 do
    local l = FX.locks[i]
    l.t = l.t + dt
    if not l.landed and l.t >= l.lockT then
      l.landed = true
      if l.tier >= 3 then FX.burst(l.x, l.y, 4 + l.tier * 2, l.c, 110, 1.5) end
    end
    if l.t >= l.max then table.remove(FX.locks, i) end
  end
  for i = #FX.scans, 1, -1 do
    local s = FX.scans[i]
    s.t = s.t + dt
    if s.t > 0.7 then table.remove(FX.scans, i) end
  end
  if FX.frame then
    FX.frame.t = FX.frame.t + dt
    if FX.frame.t >= FX.frame.max then FX.frame = nil end
  end
end

local function brackets(x, y, s, l, c, a, sy)
  sy = sy or s
  col(c, a)
  lg.line(x - s, y - sy + l, x - s, y - sy, x - s + l, y - sy)
  lg.line(x + s - l, y - sy, x + s, y - sy, x + s, y - sy + l)
  lg.line(x - s, y + sy - l, x - s, y + sy, x - s + l, y + sy)
  lg.line(x + s - l, y + sy, x + s, y + sy, x + s, y + sy - l)
end

local function drawLock(l)
  local Fo = H.fonts
  local now = love.timer.getTime()
  local c = l.prism and C.holo or l.c
  local fadeOut = math.max(0, math.min(1, (l.max - l.t) / 0.3))
  -- reticle closes in, then holds
  local q = math.min(1, l.t / l.lockT)
  local e = 1 - (1 - q) ^ 3
  local s = 44 - (44 - (13 + l.tier * 2)) * e
  local sy = s
  if l.bw then -- framing a card: lock onto its outline
    local pad = 30 - 24 * e
    s, sy = l.bw / 2 + pad, l.bh / 2 + pad
  end
  lg.setLineWidth(2)
  brackets(l.x, l.y, s, l.bw and 14 or 7, c, (0.4 + 0.6 * e) * fadeOut, sy)
  if l.landed and l.t - l.lockT < 0.15 then brackets(l.x, l.y, s + 4, l.bw and 10 or 5, C.white, (1 - (l.t - l.lockT) / 0.15) * 0.8, sy + 4) end
  lg.setLineWidth(1)
  if not l.landed then return end
  -- decode progress
  local p = l.decT > 0 and math.min(1, (l.t - l.lockT) / l.decT) or 1
  local seed = math.floor(now * 25)
  local name = scramble(l.name, p, seed)
  local open = math.min(1, (l.t - l.lockT) / 0.12)
  local a = fadeOut
  if l.compact then
    -- tag centred above the target
    local txt = scramble(l.kind, p, seed)
    local tw = math.max(Fo.xs:getWidth(l.kind), 40) + 20
    local tx, ty = l.x - tw * open / 2, l.y - sy - 26
    col(C.bg, 0.9 * a); lg.rectangle("fill", tx, ty, tw * open, 18)
    col(c, a); lg.rectangle("fill", tx, ty + 16, tw * open, 2)
    if open >= 1 then lg.setFont(Fo.xs); col(c, a); lg.printf(txt, tx, ty + 3, tw, "center") end
    return
  end
  -- leader line and readout card beside the target
  local side = l.side or 1
  local ax, ay = l.x + side * s, l.y - s
  local lx, ly = ax + side * 22, ay - 20
  col(c, 0.8 * a); lg.line(ax, ay, lx, ly)
  lg.setFont(Fo.s)
  local w = math.max(Fo.s:getWidth(l.name), Fo.xs:getWidth(l.kind))
  for _, d in ipairs(l.lines) do w = math.max(w, Fo.xs:getWidth(d)) end
  w = math.min(w + 22, 340)
  local h = 38 + #l.lines * 14
  local cx = side > 0 and lx or lx - w * open
  local cy = l.cardY or (ly - 14)
  -- the leader always reaches its card, even when the card was pushed away from the drop
  if math.abs(cy + 10 - ly) > 2 then col(c, 0.8 * a); lg.line(lx, ly, lx, cy + 10) end
  col(C.bg, 0.93 * a); lg.rectangle("fill", cx, cy, w * open, h)
  col(c, a); lg.rectangle("fill", side > 0 and cx or cx + w * open - 2, cy, 2, h)
  col(C.faint, a); lg.rectangle("line", cx + 0.5, cy + 0.5, w * open - 1, h - 1)
  if open < 1 then return end
  lg.setFont(Fo.xs); col(c, a); lg.print(scramble(l.kind, math.min(1, p * 2), seed), cx + 11, cy + 5)
  lg.setFont(Fo.s); col(p < 1 and C.dim or C.white, a); lg.print(H.fit(Fo.s, name, w - 20), cx + 11, cy + 18)
  if p >= 1 then
    lg.setFont(Fo.xs)
    for k, d in ipairs(l.lines) do
      local la = math.min(1, (l.t - l.lockT - l.decT - (k - 1) * 0.08) / 0.15)
      if la > 0 then col(C.dim, a * la); lg.print(H.fit(Fo.xs, d, w - 20), cx + 11, cy + 22 + k * 14) end
    end
  end
end

-- the PRISM moment, now inside the same language: rainbow decode, holo brackets, one sweep over the HUD
FX.prism = nil
function FX.prismEvent(label, x, y)
  if FX.onPrism then FX.onPrism() end
  FX.prism = {t = 0, max = 2.4, label = label or "PRISM"}
  FX.frame = {t = 0, max = 2.4, c = C.holo, holo = true}
  FX.lootSound(3)
end

-- above everything: locks, scan lines, the viewport frame and the prism sweep
function FX.drawPrism()
  local x0, y0, x1, y1 = V.extents()
  -- prism: one diagonal holographic band crosses the whole screen
  local pz = FX.prism
  if pz and not FX.reduced and pz.t < 1.4 then
    local p = pz.t / 1.4
    local bx = x0 - 400 + p * (x1 - x0 + 800)
    lg.setBlendMode("add")
    for k = 0, 7 do
      col(FX.hue(k / 8 + pz.t * 0.4), 0.10 * math.sin(p * math.pi))
      local ox = bx + k * 26
      lg.polygon("fill", ox, y1, ox + 26, y1, ox + 26 + (y1 - y0) * 0.5, y0, ox + (y1 - y0) * 0.5, y0)
    end
    lg.setBlendMode("alpha")
  end
  -- legendary+: a scan line sweeps out from the drop to both edges
  for _, s in ipairs(FX.scans) do
    local p = s.t / 0.7
    local d = (1 - (1 - p) ^ 2) * (x1 - x0)
    local a = 0.55 * (1 - p)
    col(s.c, a)
    lg.rectangle("fill", s.x - d, y0, 1.5, y1 - y0)
    lg.rectangle("fill", s.x + d, y0, 1.5, y1 - y0)
  end
  -- mythic+: brackets close in on the corners of the screen
  local fr = FX.frame
  if fr then
    local inn = FX.reduced and 1 or math.min(1, fr.t / 0.3)
    local a = math.min(1, (fr.max - fr.t) / 0.5)
    local m = 10 + (1 - inn) * 30
    local L = 70
    lg.setLineWidth(3)
    local cc = fr.holo and C.holo or fr.c
    col(cc, a)
    lg.line(x0 + m, y0 + m + L, x0 + m, y0 + m, x0 + m + L, y0 + m)
    lg.line(x1 - m - L, y0 + m, x1 - m, y0 + m, x1 - m, y0 + m + L)
    lg.line(x0 + m, y1 - m - L, x0 + m, y1 - m, x0 + m + L, y1 - m)
    lg.line(x1 - m - L, y1 - m, x1 - m, y1 - m, x1 - m, y1 - m - L)
    lg.setLineWidth(1)
  end
  for _, l in ipairs(FX.locks) do drawLock(l) end
end

return FX
