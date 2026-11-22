-- Rule: flight_path — a flight master in the current zone you have not
-- unlocked yet. The world map's flight-point list reports every flight master
-- of a zone with a state; "Unreachable" is one you have not visited.
local _, NN = ...
local L = NN.L

local FLIGHT_ICON = 132161
local MAX_NAMES = 2
local UNREACHABLE = (Enum and Enum.FlightPathState and Enum.FlightPathState.Unreachable) or 2
local CONTINENT = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2
-- node.faction (Enum.FlightPathFaction): Horde 1, Alliance 2; the other
-- faction's flight masters are never "to unlock".
local FPF = Enum and Enum.FlightPathFaction
local OTHER_FACTION = { Horde = (FPF and FPF.Alliance) or 2, Alliance = (FPF and FPF.Horde) or 1 }

local function apiAvailable()
  return C_TaxiMap ~= nil and C_TaxiMap.GetTaxiNodesForMap ~= nil and C_Map ~= nil and C_Map.GetBestMapForUnit ~= nil
end

-- The zone-level map for where the player stands (walks up from sub-areas).
local function currentZone()
  local mapID = NN.Plain(C_Map.GetBestMapForUnit("player"))
  for _ = 1, 10 do
    if not mapID then return nil end
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    if not info then return nil end
    local mapType = NN.Plain(info.mapType) or 0
    if mapType == 3 then return mapID, NN.Plain(info.name, "string") or "" end -- Zone
    if mapType <= CONTINENT then return nil end
    mapID = NN.Plain(info.parentMapID)
  end
  return nil
end

NN:RegisterRule({
  name = "flight_path",
  group = "travel",
  title = L.FLIGHT_PATH_TITLE,
  help = L.FLIGHT_PATH_HELP,
  events = { "ZONE_CHANGED_NEW_AREA", "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "PLAYER_ENTERING_WORLD" },
  applies = function() return apiAvailable() end,
  check = function()
    if IsInInstance and IsInInstance() then return nil end
    local mapID, zoneName = currentZone()
    if not mapID then return nil end
    local names = {}
    -- Forever gives no state on these nodes: then judge from the flight
    -- points remembered at flight masters, once one was seen on this continent.
    local judged = NN.FlightPoints:Seen(NN.FlightPoints.Continent(mapID))
    local enemy = OTHER_FACTION[NN.Plain(UnitFactionGroup("player"), "string") or ""]
    for _, node in ipairs(C_TaxiMap.GetTaxiNodesForMap(mapID) or {}) do
      local state = NN.Plain(node.state)
      local unknown
      if state ~= nil then unknown = state == UNREACHABLE
      else unknown = judged and not NN.FlightPoints:NodeKnown(node) end
      if unknown and enemy and NN.Plain(node.faction) == enemy then unknown = false end
      if unknown then
        local name = NN.Plain(node.name, "string")
        if name then names[#names + 1] = name end
      end
    end
    if #names == 0 then return nil end
    table.sort(names)
    local shown = {}
    for i = 1, math.min(#names, MAX_NAMES) do shown[i] = names[i] end
    local text
    if #names > MAX_NAMES then
      text = L.FLIGHT_PATH_ROW_MANY:format(zoneName, table.concat(shown, ", "), #names - MAX_NAMES)
    else
      text = L.FLIGHT_PATH_ROW:format(zoneName, table.concat(shown, ", "))
    end
    -- the map button marks only this zone's flight masters still to discover
    local service
    if NN.Services then
      local ids = {}
      for _, id in ipairs(NN.Services:Candidates("flight")) do
        local npc = NN.Services:Npc(id)
        if npc and npc.map == mapID and not NN.Services:FlightKnown(id) then ids[#ids + 1] = id end
      end
      if #ids > 0 then service = { kind = "flight", npcIDs = ids } end
    end
    return { text = text, icon = FLIGHT_ICON, onClick = ToggleWorldMap, service = service }
  end,
  sample = function() return { { text = L.FLIGHT_PATH_ROW:format("Westfall", "Sentinel Hill"), icon = FLIGHT_ICON } } end,
})
