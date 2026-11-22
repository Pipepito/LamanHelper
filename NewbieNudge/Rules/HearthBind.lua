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

-- Where the player stood when they last bound: inside an inn the sub-zone is
-- the inn's name while the bind location is the area's, so names alone
-- cannot tell "this is my inn".
local function recordBindSpot()
  if not NN.db then return end
  NN.db.hearthSpot = {
    zone = GetZoneText and NN.Plain(GetZoneText(), "string") or "",
    sub = GetSubZoneText and NN.Plain(GetSubZoneText(), "string") or "",
  }
end

local function atOwnInn(bind, zone, sub)
  if bind == sub or bind == zone then return true end
  local spot = NN.db and NN.db.hearthSpot
  return spot ~= nil and spot.zone == zone and spot.sub == sub
end

local function onGossipShow()
  current = nil
  local rule = NN.ruleByName.hearth_bind
  if not rule or not NN:IsRuleActive(rule) then return end
  if not hasBindOption() or not GetBindLocation then return end
  local bind = NN.Plain(GetBindLocation(), "string")
  local sub = GetSubZoneText and NN.Plain(GetSubZoneText(), "string") or ""
  local zone = GetZoneText and NN.Plain(GetZoneText(), "string") or ""
  if not bind or bind == "" or atOwnInn(bind, zone, sub) then return end
  current = { bind = bind }
  local key = zone .. "/" .. sub
  if not saidHere[key] then
    saidHere[key] = true
    NN:Say(L.HEARTH_BIND_ROW:format(bind))
  end
end

NN:RegisterEvent("GOSSIP_SHOW")
NN:RegisterEvent("GOSSIP_CLOSED")
NN:RegisterEvent("HEARTHSTONE_BOUND")
NN:OnAnyEvent(function(event)
  if event == "GOSSIP_SHOW" then onGossipShow()
  elseif event == "GOSSIP_CLOSED" then current = nil
  elseif event == "HEARTHSTONE_BOUND" then recordBindSpot(); current = nil end
end)

NN:RegisterRule({
  name = "hearth_bind",
  group = "travel",
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
