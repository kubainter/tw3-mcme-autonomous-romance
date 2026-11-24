-- MCME Autonomous Romance: no Num-pad exit hints in our own Tier 4 scenes.
--
-- The core's handler (uc\controls.lua) draws the exit list above the player and switches the HUD
-- hints on for every scene of the player that is not external; it never looks at the hook. Our
-- scenes start with hook MCME_AR, so this wraps that handler and steps aside for our hook only.
-- Manual Unicorn scenes and quest scenes keep their hints.
local HOOK = "MCME_AR"
local KEY = "unicorn:controls"

local ok, unicorn = pcall(w3.use, "modUnicornCore")
if not ok or not unicorn then return end

local wrapper = nil

local function wrap()
  local L = rawget(_G, "UNICORN_LUA")
  local handlers = L and L.handlers and L.handlers.StageStart
  if not handlers then return false end
  local current = handlers[KEY]
  if type(current) ~= "function" then return false end
  if wrapper ~= nil and current == wrapper then return true end
  local inner = current
  wrapper = function(e)
    local t = e and e.thread
    if t and t.hook == HOOK then return end
    return inner(e)
  end
  handlers[KEY] = wrapper
  return true
end

local reported = false
local announced = false
local next_check = 0

-- The core registers its handler when it loads and again after a reload of its .lua, so this
-- re-checks on a slow tick instead of wrapping once at startup.
w3.on_tick(function()
  local now = w3.time()
  if now < next_check then return end
  next_check = now + 5
  local ok_pcall, installed = pcall(wrap)
  if not ok_pcall and not reported then
    reported = true
    print("[MCME_AR_Unicorn] hint suppression unavailable: " .. tostring(installed))
  elseif ok_pcall and installed and not announced then
    announced = true
    print("[MCME_AR_Unicorn] hint suppression active for hook " .. HOOK)
  end
end)
