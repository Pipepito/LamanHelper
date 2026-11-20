-- Rule: flight_path — a flight master in the current zone you have not
-- unlocked yet. The world map's flight-point list reports every flight master
-- of a zone with a state; "Unreachable" is one you have not visited.
local _, NN = ...
local L = NN.L

local FLIGHT_ICON = 132161
local MAX_NAMES = 2
local UNREACHABLE = (Enum and Enum.FlightPathState and Enum.FlightPathState.Unreachable) or 2
local CONTINENT = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2

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
  title = L.FLIGHT_PATH_TITLE,
  help = L.FLIGHT_PATH_HELP,
  events = { "ZONE_CHANGED_NEW_AREA", "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "PLAYER_ENTERING_WORLD" },
  applies = function() return apiAvailable() end,
  check = function()
    if IsInInstance and IsInInstance() then return nil end
    local mapID, zoneName = currentZone()
    if not mapID then return nil end
    local names = {}
    for _, node in ipairs(C_TaxiMap.GetTaxiNodesForMap(mapID) or {}) do
      if NN.Plain(node.state) == UNREACHABLE then
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
    return { text = text, icon = FLIGHT_ICON, onClick = ToggleWorldMap }
  end,
  sample = function() return { { text = L.FLIGHT_PATH_ROW:format("Westfall", "Sentinel Hill"), icon = FLIGHT_ICON } } end,
})
