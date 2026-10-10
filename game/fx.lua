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

function FX.play(name, pitch, vol)
  if FX.muted or not FX.snd[name] then return end
  local v = (vol or 1) * FX.vol[CATEGORY[name] or "reward"]
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

function FX.ray(x, y, c, life, size)
  if FX.reduced then return end
  FX.rays[#FX.rays + 1] = {x = x, y = y, c = c, t = 0, max = life or 1.5, size = size or 300, rot = rnd(0, TAU)}
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
    p.vx, p.vy = p.vx * (1 - 2.2 * dt), p.vy * (1 - 2.2 * dt)
    if p.life >= p.max then table.remove(P, i) end
  end
  for i = #FX.floaters, 1, -1 do
    local f = FX.floaters[i]
    f.life = f.life + dt
    f.y = f.y - 55 * dt
    if f.life >= f.max then table.remove(FX.floaters, i) end
  end
  for _, t in ipairs(FX.toasts) do t.life = t.life + dt end
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

-- rotating light rays behind a big reveal
function FX.drawRays()
  if #FX.rays == 0 then return end
  lg.setBlendMode("add")
  for _, r in ipairs(FX.rays) do
    local p = r.t / r.max
    local a = math.min(1, r.t * 6) * (1 - p) ^ 1.5
    local len = r.size * (0.6 + 0.4 * math.min(1, r.t * 3))
    local rot = r.rot + r.t * 0.8
    local n = 14
    for k = 0, n - 1 do
      local ang = rot + k / n * TAU
      local w = 0.09
      col(r.c, 0.22 * a)
      lg.polygon("fill", r.x, r.y,
        r.x + math.cos(ang - w) * len, r.y + math.sin(ang - w) * len,
        r.x + math.cos(ang + w) * len, r.y + math.sin(ang + w) * len)
    end
  end
  lg.setBlendMode("alpha")
end

function FX.drawParticles()
  FX.drawRays()
  lg.setBlendMode("add")
  for _, p in ipairs(FX.particles) do
    col(p.c, (1 - p.life / p.max) * 0.9)
    lg.rectangle("fill", p.x - p.s / 2, p.y - p.s / 2, p.s, p.s)
  end
  lg.setBlendMode("alpha")
  for _, f in ipairs(FX.floaters) do
    local a = 1 - (f.life / f.max) ^ 2
    lg.setFont(f.font)
    col(f.c, a)
    lg.print(f.text, f.x - f.font:getWidth(f.text) / 2, f.y)
  end
end

return FX
