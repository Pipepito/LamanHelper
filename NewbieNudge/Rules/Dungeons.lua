-- Rules: dungeon_ready (a dungeon fits your level) and zone_level (this zone
-- is below or above your level). Data: Data/Dungeons.lua and Data/Zones.lua
-- (WoW Handbook, GPL-3.0); names come from the client.
local _, NN = ...
local L = NN.L

local DUNGEON_ICON = 136106
local ZONE_ICON = 134269
local MAX_DUNGEON_ROWS = 2
local ZONE_MARGIN = 2

-------------------------------------------------------------------------------
-- Dungeons
-------------------------------------------------------------------------------

function NN.MarkDungeonSeen(instanceID)
  if NN.db and instanceID and instanceID ~= 0 then
    NN.db.seen.dungeons[instanceID] = true
    NN:MarkDirty("dungeon_ready")
  end
end

local function currentInstanceID()
  if not GetInstanceInfo then return nil end
  local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
  return NN.Plain(instanceID)
end

-- Entering an instance counts as "done" for its reminder. Rules are frozen
-- inside instances, so this runs on the raw event rather than in check().
NN:OnAnyEvent(function(event)
  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    local id = currentInstanceID()
    if id and id ~= 0 then NN.MarkDungeonSeen(id) end
  end
end)

local function questsHalfDone(d)
  if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or #d.quests == 0 then return false end
  local done = 0
  for _, questID in ipairs(d.quests) do
    if C_QuestLog.IsQuestFlaggedCompleted(questID) == true then done = done + 1 end
  end
  return done * 2 >= #d.quests
end

local function dungeonName(d)
  local name = GetRealZoneText and NN.Plain(GetRealZoneText(d.instanceID), "string")
  if name and name ~= "" then return name end
  return d.nameEN
end

local function openMapAt(mapID)
  return function()
    if OpenWorldMap then
      OpenWorldMap(mapID)
    elseif ToggleWorldMap then
      ToggleWorldMap()
      if WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(mapID) end
    end
  end
end

NN:RegisterRule({
  name = "dungeon_ready",
  group = "travel",
  title = L.DUNGEON_TITLE,
  help = L.DUNGEON_HELP,
  events = { "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "QUEST_TURNED_IN" },
  applies = function() return NN.Dungeons ~= nil end,
  check = function()
    local level = NN.Plain(UnitLevel("player"))
    if level == nil then return NN.UNKNOWN end
    local faction = UnitFactionGroup and NN.Plain(UnitFactionGroup("player"), "string")
    faction = faction and faction:lower()
    local seen = NN.db.seen.dungeons
    local results = {}
    for _, d in ipairs(NN.Dungeons) do
      if #results >= MAX_DUNGEON_ROWS then break end
      if (d.faction == nil or d.faction == faction) and level >= d.min and level <= d.max and not seen[d.instanceID] then
        if questsHalfDone(d) then
          seen[d.instanceID] = true
        else
          results[#results + 1] = {
            text = L.DUNGEON_ROW:format(dungeonName(d), d.min, d.max), icon = DUNGEON_ICON,
            onClick = openMapAt(d.mapID),
          }
        end
      end
    end
    if #results == 0 then return nil end
    return results
  end,
  sample = function() return { { text = L.DUNGEON_ROW:format("The Deadmines", 16, 26), icon = DUNGEON_ICON } } end,
})

-------------------------------------------------------------------------------
-- Zone level
-------------------------------------------------------------------------------

local CONTINENT = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2

-- Walks up from mapID until a map in NN.Zones is found; stops at continents.
function NN.ZoneForMap(mapID)
  if not (NN.Zones and C_Map and C_Map.GetMapInfo) then return nil end
  local id = mapID
  for _ = 1, 10 do
    if id == nil then return nil end
    local zone = NN.Zones[id]
    if zone then return id, zone end
    local info = C_Map.GetMapInfo(id)
    if not info or (NN.Plain(info.mapType) or 0) <= CONTINENT then return nil end
    id = NN.Plain(info.parentMapID)
  end
  return nil
end

NN:RegisterRule({
  name = "zone_level",
  group = "travel",
  title = L.ZONE_TITLE,
  help = L.ZONE_HELP,
  events = { "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" },
  applies = function() return NN.Zones ~= nil end,
  check = function()
    if IsInInstance and IsInInstance() then return nil end
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local mapID = NN.Plain(C_Map.GetBestMapForUnit("player"))
    if not mapID then return nil end
    local zoneID, zone = NN.ZoneForMap(mapID)
    if not zone then return nil end
    local level = NN.Plain(UnitLevel("player"))
    if level == nil then return NN.UNKNOWN end
    local info = C_Map.GetMapInfo(zoneID)
    local name = (info and NN.Plain(info.name, "string")) or tostring(zoneID)
    if level > zone.max + ZONE_MARGIN then
      return { text = L.ZONE_BELOW_ROW:format(name, zone.min, zone.max), icon = ZONE_ICON, onClick = ToggleWorldMap }
    elseif level < zone.min - ZONE_MARGIN then
      return { text = L.ZONE_ABOVE_ROW:format(name, zone.min, zone.max), icon = ZONE_ICON, onClick = ToggleWorldMap }
    end
    return nil
  end,
  sample = function() return { { text = L.ZONE_BELOW_ROW:format("Elwynn Forest", 1, 10), icon = ZONE_ICON } } end,
})
