-- Window "glass" for the macOS GLASS theme (Windows only).
-- LÖVE 11 cannot make a window per-pixel transparent, but Windows can: the game window becomes a layered
-- window with a colour key, so every pixel that is exactly the key colour (the theme background) turns into a
-- hole you can see the desktop through, and the whole window gets a slight see-through alpha.
-- Fails silently everywhere else (macOS, Linux, or if the FFI calls are unavailable).
local Gl = {on = false}

local ffi, user32
local GWL_EXSTYLE, WS_EX_LAYERED = -20, 0x00080000
local LWA_COLORKEY, LWA_ALPHA = 0x1, 0x2

local function init()
  if user32 ~= nil then return user32 end
  user32 = false
  if love.system.getOS() ~= "Windows" then return false end
  local ok = pcall(function()
    ffi = require "ffi"
    ffi.cdef [[
      typedef void* GL_HWND;
      GL_HWND FindWindowA(const char* cls, const char* title);
      GL_HWND GetActiveWindow(void);
      long GetWindowLongA(GL_HWND h, int idx);
      long SetWindowLongA(GL_HWND h, int idx, long v);
      int SetLayeredWindowAttributes(GL_HWND h, unsigned long key, unsigned char alpha, unsigned long flags);
    ]]
    user32 = ffi.load("user32")
  end)
  if not ok then user32 = false end
  return user32
end

local function window()
  local u = init()
  if not u then return nil end
  local h = u.FindWindowA(nil, love.window.getTitle())
  if h == nil then h = u.GetActiveWindow() end
  if h == nil then return nil end
  return h
end

-- turn glass on with the given key colour ({r, g, b} 0..1, must match the clear colour exactly) and window alpha
function Gl.set(on, key, alpha)
  local h = window()
  if not h then Gl.on = false return false end
  local u = user32
  local ok = pcall(function()
    local ex = u.GetWindowLongA(h, GWL_EXSTYLE)
    if on then
      u.SetWindowLongA(h, GWL_EXSTYLE, bit.bor(ex, WS_EX_LAYERED))
      local r = math.floor(key[1] * 255 + 0.5)
      local g = math.floor(key[2] * 255 + 0.5)
      local b = math.floor(key[3] * 255 + 0.5)
      u.SetLayeredWindowAttributes(h, r + g * 256 + b * 65536, math.floor((alpha or 0.93) * 255), bit.bor(LWA_COLORKEY, LWA_ALPHA))
    elseif bit.band(ex, WS_EX_LAYERED) ~= 0 then
      u.SetWindowLongA(h, GWL_EXSTYLE, bit.band(ex, bit.bnot(WS_EX_LAYERED)))
    end
  end)
  Gl.on = ok and on or false
  return Gl.on
end

function Gl.available() return init() and true or false end

return Gl
