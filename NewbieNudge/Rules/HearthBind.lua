-- Rule: hearth_bind — talking to an innkeeper far from where the Hearthstone
-- is set: a row while the talk window is open, and one chat line per
-- innkeeper visit per session. The innkeeper's bind option is the gossip
-- entry with the Hearthstone icon (132052, confirmed in game 2026-11-20).
local _, NN = ...
local L = NN.L

local HEARTH_ICON = 134414
local BIND_OPTION_ICON = 132052

local current -- { bind = "Goldshire" } while an innkeeper's gossip is open
local saidHere = {} -- [zone .. "/" .. subzone] = true, this session

local function hasBindOption()
  if not (C_GossipInfo and C_GossipInfo.GetOptions) then return false end
  for _, option in ipairs(C_GossipInfo.GetOptions() or {}) do
    if NN.Plain(option.icon) == BIND_OPTION_ICON then return true end
  end
  return false
end

local function onGossipShow()
  current = nil
  if not hasBindOption() or not GetBindLocation then return end
  local bind = NN.Plain(GetBindLocation(), "string")
  local sub = GetSubZoneText and NN.Plain(GetSubZoneText(), "string") or ""
  local zone = GetZoneText and NN.Plain(GetZoneText(), "string") or ""
  if not bind or bind == "" or bind == sub or bind == zone then return end
  current = { bind = bind }
  local key = zone .. "/" .. sub
  if not saidHere[key] then
    saidHere[key] = true
    NN:Say(L.HEARTH_BIND_ROW:format(bind))
  end
end

NN:RegisterEvent("GOSSIP_SHOW")
NN:RegisterEvent("GOSSIP_CLOSED")
NN:OnAnyEvent(function(event)
  if event == "GOSSIP_SHOW" then onGossipShow()
  elseif event == "GOSSIP_CLOSED" then current = nil end
end)

NN:RegisterRule({
  name = "hearth_bind",
  title = L.HEARTH_BIND_TITLE,
  help = L.HEARTH_BIND_HELP,
  events = { "GOSSIP_SHOW", "GOSSIP_CLOSED" },
  applies = function() return true end,
  check = function()
    if not current then return nil end
    return { text = L.HEARTH_BIND_ROW:format(current.bind), icon = HEARTH_ICON }
  end,
  sample = function() return { { text = L.HEARTH_BIND_ROW:format("Goldshire"), icon = HEARTH_ICON } } end,
})
