-- FlightPoints: the flight points the player has discovered, remembered per
-- character. On WoW Forever the world map's flight-point list has no
-- "discovered" state (snapshot 2026-11-22: state nil on every node), but a
-- flight master's own map does, so it is read whenever that map is open.
local _, NN = ...

local FlightPoints = {}
NN.FlightPoints = FlightPoints

local UNREACHABLE = (Enum and Enum.FlightPathState and Enum.FlightPathState.Unreachable) or 2
local CONTINENT = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2
local KNOWN_TYPES = { CURRENT = true, REACHABLE = true, DISTANT = true }

local function db()
  NN.db.flights = NN.db.flights or { known = {}, seen = {} }
  return NN.db.flights
end

-- The continent map that holds mapID (walking up parent maps), or nil.
function FlightPoints.Continent(mapID)
  for _ = 1, 10 do
    if not mapID then return nil end
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    if not info then return nil end
    if NN.Plain(info.mapType) == CONTINENT then return mapID end
    mapID = NN.Plain(info.parentMapID)
  end
  return nil
end

function FlightPoints:IsKnown(name)
  return name ~= nil and db().known[name] == true
end

-- True once a flight master's map has been read on that continent, so a
-- point missing from the list really is undiscovered.
function FlightPoints:Seen(continentMapID)
  return continentMapID ~= nil and db().seen[continentMapID] == true
end

-- Reads the open flight master's map. Points are only ever added: a point
-- once known stays known.
-- The modern call is tried first; when it gives no state (as the map list
-- doesn't on Forever) the classic calls are read instead. The continent only
-- counts as checked once something was recorded (the current point always is).
function FlightPoints:Record()
  local known = db().known
  local recorded = 0
  if C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and GetTaxiMapID then
    local mapID = NN.Plain(GetTaxiMapID())
    for _, node in ipairs((mapID and C_TaxiMap.GetAllTaxiNodes(mapID)) or {}) do
      local name, state = NN.Plain(node.name, "string"), NN.Plain(node.state)
      if name and state ~= nil then
        recorded = recorded + 1
        if state ~= UNREACHABLE then known[name] = true end
      end
    end
  end
  if recorded == 0 and NumTaxiNodes and TaxiNodeName and TaxiNodeGetType then
    for i = 1, NN.Plain(NumTaxiNodes()) or 0 do
      local name, kind = NN.Plain(TaxiNodeName(i), "string"), NN.Plain(TaxiNodeGetType(i), "string")
      if name and kind then
        recorded = recorded + 1
        if KNOWN_TYPES[kind] then known[name] = true end
      end
    end
  end
  if recorded == 0 then return end
  local here = C_Map and C_Map.GetBestMapForUnit and NN.Plain(C_Map.GetBestMapForUnit("player"))
  local continent = FlightPoints.Continent(here) or (GetTaxiMapID and NN.Plain(GetTaxiMapID()))
  if continent then db().seen[continent] = true end
end

-- Whether flight points can be told discovered or not: the client reports a
-- state, or a flight master's map has been read at least once.
function FlightPoints:CanJudge()
  if next(db().seen) then return true end
  if C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap then
    for _, map in ipairs({ 1414, 1415 }) do
      for _, node in ipairs(C_TaxiMap.GetTaxiNodesForMap(map) or {}) do
        if NN.Plain(node.state) ~= nil then return true end
      end
    end
  end
  return false
end

-- Whether a node from the world map's flight-point list is known: its own
-- state when the client gives one, else the remembered list.
function FlightPoints:NodeKnown(node)
  local state = NN.Plain(node.state)
  if state ~= nil then return state ~= UNREACHABLE end
  return self:IsKnown(NN.Plain(node.name, "string"))
end

NN:RegisterEvent("TAXIMAP_OPENED")
NN:OnAnyEvent(function(event)
  if event == "TAXIMAP_OPENED" and NN.db then FlightPoints:Record() end
end)
