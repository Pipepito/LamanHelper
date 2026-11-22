-- Services: the closest suitable NPC for a service (repair, inn, supplies,
-- trainers) and the player's map marks. NPC data: Data/Services.lua
-- (QuestieDB, GPL-3.0) as NN.ServiceData. Pins are drawn by MapPins.lua.
local _, NN = ...
local L = NN.L

local Services = { listeners = {} }
NN.Services = Services

local LEVEL_MARGIN = 3          -- zones up to 3 levels above the player are fine
local OTHER_CONTINENT = 1e12    -- added to the distance: same continent first
-- service kinds that have a minimap tracking type (trainers have none on purpose)
local TRACKING = {
  repair = function() return MINIMAP_TRACKING_REPAIR or "Repair" end,
  inn = function() return MINIMAP_TRACKING_INNKEEPER or "Innkeeper" end,
  supplies = function() return MINIMAP_TRACKING_VENDOR_FOOD or "Food & Drink" end,
}

local function data() return NN.ServiceData or { npcs = {}, kinds = {} } end

function Services:Npc(npcID)
  local n = data().npcs[npcID]
  if not n then return nil end
  return { id = npcID, name = n[1], title = n[2], map = n[3], x = n[4], y = n[5], faction = n[6] }
end

function Services:KindLabel(kind)
  if kind:find("^trainer_") then return L.SERVICE_KIND_TRAINER end
  if kind:find("^prof_") then return L.SERVICE_KIND_PROF end
  return L["SERVICE_KIND_" .. kind:upper()] or kind
end

local function factionLetter()
  local f = NN.Plain(UnitFactionGroup("player"), "string")
  return (f == "Alliance" and "A") or (f == "Horde" and "H") or nil
end

local function levelAllows(map, level)
  local zone = NN.Zones and NN.Zones[map]
  if not zone or not zone.min then return true end
  return zone.min <= level + LEVEL_MARGIN
end

-- NPCs of a kind the player can use: friendly, and not in a zone far above
-- their level. npcIDs (optional) restricts the choice (weapon-master rows).
function Services:Candidates(kind, npcIDs)
  local letter = factionLetter()
  local level = NN.Plain(UnitLevel("player")) or 1
  local out = {}
  if not letter then return out end
  for _, id in ipairs(npcIDs or data().kinds[kind] or {}) do
    local n = data().npcs[id]
    if n and n[6]:find(letter, 1, true) and levelAllows(n[3], level) then out[#out + 1] = id end
  end
  return out
end

local function worldPos(map, x, y)
  if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
  local continent, pos = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
  if not (continent and pos) then return nil end
  local wx, wy = pos:GetXY()
  return continent, NN.Plain(wx), NN.Plain(wy)
end

-- The player's continent and world position, or nil (instances, secrets).
function Services:PlayerWorldPos()
  local map = C_Map and C_Map.GetBestMapForUnit and NN.Plain(C_Map.GetBestMapForUnit("player"))
  if not map then return nil end
  local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
  if not pos then return nil end
  local x, y = pos:GetXY()
  x, y = NN.Plain(x), NN.Plain(y)
  if not (x and y) then return nil end
  local continent, wx, wy = worldPos(map, x, y)
  if not (continent and wx and wy) then return nil end
  return continent, wx, wy
end

-- npcID of the closest candidate, or nil plus "position" / "none".
function Services:Closest(kind, npcIDs)
  local continent, px, py = self:PlayerWorldPos()
  if not continent then return nil, "position" end
  local best, bestDist
  for _, id in ipairs(self:Candidates(kind, npcIDs)) do
    local n = data().npcs[id]
    local c, x, y = worldPos(n[3], n[4] / 100, n[5] / 100)
    if c and x and y then
      local d = (x - px) ^ 2 + (y - py) ^ 2
      if c ~= continent then d = d + OTHER_CONTINENT end
      if not bestDist or d < bestDist then best, bestDist = id, d end
    end
  end
  if not best then return nil, "none" end
  return best
end

-------------------------------------------------------------------------------
-- Marks (saved per character in db.marks)
-------------------------------------------------------------------------------

local function changed()
  for _, fn in ipairs(Services.listeners) do pcall(fn) end
end

-- Called with no arguments whenever the marks change (MapPins, Panel).
function Services:OnChange(fn)
  self.listeners[#self.listeners + 1] = fn
end

function Services:Marks()
  local out = {}
  for _, m in ipairs(NN.db.marks) do
    if data().npcs[m.npcID] then out[#out + 1] = m end
  end
  return out
end

function Services:MarkOf(kind)
  for _, m in ipairs(self:Marks()) do if m.kind == kind then return m end end
  return nil
end

-- npcIDs (optional): only a mark on one of these NPCs counts (each
-- weapon-master row names its own trainers).
function Services:IsMarked(kind, npcIDs)
  local mark = self:MarkOf(kind)
  if not mark then return false end
  if not npcIDs then return true end
  for _, id in ipairs(npcIDs) do if id == mark.npcID then return true end end
  return false
end

-- rule: the reminder the mark came from; its mark goes when that reminder does.
function Services:Mark(kind, npcID, fromRow, rule)
  local marks = {}
  for _, m in ipairs(NN.db.marks) do if m.kind ~= kind then marks[#marks + 1] = m end end
  marks[#marks + 1] = { kind = kind, npcID = npcID, fromRow = fromRow and true or false, rule = rule }
  NN.db.marks = marks
  changed()
end

function Services:Unmark(kind)
  local marks = {}
  for _, m in ipairs(NN.db.marks) do if m.kind ~= kind then marks[#marks + 1] = m end end
  NN.db.marks = marks
  changed()
end

function Services:ClearMarks()
  NN.db.marks = {}
  changed()
end

-- Marks made from a reminder row go away with the reminder (repair done,
-- trainer visited). activeKinds: set of kinds still on the panel.
-- A mark tied to a rule is only judged once that rule has really been
-- checked this session (not right after login, not while it can't tell),
-- and not while the rule is snoozed or off; nothing is judged in combat or
-- instances, where rules are frozen.
local function shouldPrune(mark, activeKinds)
  if not mark.fromRow or activeKinds[mark.kind] then return false end
  if not mark.rule then return true end
  local rule = NN.ruleByName[mark.rule]
  if not rule then return true end
  return (NN.checked and NN.checked[mark.rule]) and NN:IsRuleActive(rule) or false
end

function Services:PruneRowMarks(activeKinds)
  if NN:IsRestricted() then return end
  local marks, removed = {}, false
  for _, m in ipairs(NN.db.marks) do
    if shouldPrune(m, activeKinds) then removed = true else marks[#marks + 1] = m end
  end
  if removed then NN.db.marks = marks; changed() end
end

local function turnOnTracking(kind)
  local wanted = TRACKING[kind] and TRACKING[kind]()
  if not (wanted and C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.SetTracking) then return end
  for i = 1, NN.Plain(C_Minimap.GetNumTrackingTypes()) or 0 do
    local info = C_Minimap.GetTrackingInfo(i)
    if info and NN.Plain(info.name, "string") == wanted then
      if not info.active then C_Minimap.SetTracking(i, true) end
      return
    end
  end
end

local function zoneName(map)
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
  return (info and NN.Plain(info.name, "string")) or tostring(map)
end
Services.ZoneName = zoneName

-- Marks the closest NPC of the kind, says where, opens the world map there
-- and turns on the matching minimap tracking. Returns the npcID or nil.
-- Marks one NPC and tells the player: a chat line, the minimap tracking,
-- and (openMap) the world map on its zone.
function Services:MarkNpc(kind, id, fromRow, rule, openMap)
  self:Mark(kind, id, fromRow, rule)
  local npc = self:Npc(id)
  NN:Say(L.SERVICES_MARKED:format(npc.name, npc.title, zoneName(npc.map)))
  turnOnTracking(kind)
  if openMap and OpenWorldMap then OpenWorldMap(npc.map) end
end

function Services:MarkClosest(kind, npcIDs, fromRow, rule)
  local id, reason = self:Closest(kind, npcIDs)
  if not id then
    if reason == "position" then NN:Say(L.SERVICES_NO_POSITION)
    else NN:Say(L.SERVICES_NONE:format(self:KindLabel(kind))) end
    return nil
  end
  self:MarkNpc(kind, id, fromRow, rule, true)
  return id
end

-- Drop marks whose NPC left the data (a data refresh between sessions).
NN:AfterLogin(function()
  NN.db.marks = Services:Marks()
end)
