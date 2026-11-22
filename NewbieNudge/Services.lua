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
  food = function() return MINIMAP_TRACKING_VENDOR_FOOD or "Food & Drink" end,
  flight = function() return MINIMAP_TRACKING_FLIGHTMASTER or "Flight Master" end,
}

local function data() return NN.ServiceData or { npcs = {}, kinds = {} } end

function Services:Npc(npcID)
  local n = data().npcs[npcID]
  if not n then return nil end
  return { id = npcID, name = n[1], title = n[2], map = n[3], x = n[4], y = n[5], faction = n[6] }
end

function Services:KindLabel(kind)
  if kind:find("^trainer_") then return L.SERVICE_KIND_TRAINER end
  if kind:find("^prof_") then return L.SERVICE_KIND_PROF end -- prof_all too
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

-- NPC ids of a kind; "prof_all" is every profession's trainers together.
function Services:KindNpcs(kind)
  if kind ~= "prof_all" then return data().kinds[kind] or {} end
  if not self.allProfs then
    local ids, seen = {}, {}
    for name, list in pairs(data().kinds) do
      if name:find("^prof_%d+$") then
        for _, id in ipairs(list) do if not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
      end
    end
    table.sort(ids)
    self.allProfs = ids
  end
  return self.allProfs
end

-- NPCs of a kind the player can use: friendly, and not in a zone far above
-- their level. npcIDs (optional) restricts the choice (weapon-master rows).
function Services:Candidates(kind, npcIDs)
  local letter = factionLetter()
  local level = NN.Plain(UnitLevel("player")) or 1
  local out = {}
  if not letter then return out end
  for _, id in ipairs(npcIDs or Services:KindNpcs(kind)) do
    local n = data().npcs[id]
    local levelOk = NN.db.services.levelFilter == false or levelAllows(n and n[3], level)
    if n and n[6]:find(letter, 1, true) and levelOk then out[#out + 1] = id end
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

-------------------------------------------------------------------------------
-- Travel time: running, or running to a discovered flight master, flying and
-- running on. Rough numbers on purpose: they only need to rank the options.
-------------------------------------------------------------------------------

local RUN_SPEED = 7          -- yards per second on foot
local FLIGHT_SPEED = 30      -- yards per second on a flight
local ROUTE_FACTOR = 1.3     -- flight routes bend
local TAKE_OFF = 20          -- seconds to get going
local CONTINENT_MAPS = { 1414, 1415 } -- Kalimdor, Eastern Kingdoms
local UNREACHABLE = (Enum and Enum.FlightPathState and Enum.FlightPathState.Unreachable) or 2

local function distance(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

-- Discovered flight masters with their world position.
function Services:FlightMasters()
  local out = {}
  if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then return out end
  for _, map in ipairs(CONTINENT_MAPS) do
    for _, node in ipairs(C_TaxiMap.GetTaxiNodesForMap(map) or {}) do
      local pos = node.position
      if NN.FlightPoints:NodeKnown(node) and type(pos) == "table" then
        local x, y
        if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
        x, y = NN.Plain(x), NN.Plain(y)
        local c, wx, wy
        if x and y then c, wx, wy = worldPos(map, x, y) end
        if c and wx and wy then
          out[#out + 1] = { name = NN.Plain(node.name, "string") or "?", continent = c, x = wx, y = wy }
        end
      end
    end
  end
  return out
end

-- Seconds to reach the NPC and how: { kind = "foot" } or
-- { kind = "fly", from = name, to = name }. Nil when a position is unknown.
-- flights: FlightMasters() (passed in when ranking many NPCs).
function Services:TravelTime(npcID, flights)
  local continent, px, py = self:PlayerWorldPos()
  if not continent then return nil end
  local n = data().npcs[npcID]
  local c, tx, ty = worldPos(n[3], n[4] / 100, n[5] / 100)
  if not (c and tx and ty) then return nil end
  if c ~= continent then return OTHER_CONTINENT + distance(px, py, tx, ty), { kind = "continent" } end
  local best, route = distance(px, py, tx, ty) / RUN_SPEED, { kind = "foot" }
  -- take off from the nearest discovered flight master, land at the best one
  local from, fromDist
  for _, fm in ipairs(flights or self:FlightMasters()) do
    if fm.continent == continent then
      local d = distance(px, py, fm.x, fm.y)
      if not fromDist or d < fromDist then from, fromDist = fm, d end
    end
  end
  if from then
    for _, to in ipairs(flights or self:FlightMasters()) do
      if to ~= from and to.continent == continent then
        local t = fromDist / RUN_SPEED + TAKE_OFF
          + distance(from.x, from.y, to.x, to.y) * ROUTE_FACTOR / FLIGHT_SPEED
          + distance(to.x, to.y, tx, ty) / RUN_SPEED
        if t < best then best, route = t, { kind = "fly", from = from.name, to = to.name } end
      end
    end
  end
  return best, route
end

-- Whether a flight master stands at a flight point the player has
-- discovered (a known flight point within 80 yards of it).
function Services:FlightKnown(npcID, flights)
  local n = data().npcs[npcID]
  if not n then return false end
  local c, x, y = worldPos(n[3], n[4] / 100, n[5] / 100)
  if not c then return false end
  for _, fm in ipairs(flights or self:FlightMasters()) do
    if fm.continent == c and distance(fm.x, fm.y, x, y) < 80 then return true end
  end
  return false
end

-- The quickest candidates, at most one per map: { { id, time, route }, ... }.
-- Empty plus "position" when the player's position is unknown.
function Services:Ranked(kind, npcIDs, count)
  if not self:PlayerWorldPos() then return {}, "position" end
  local flights = self:FlightMasters()
  local all = {}
  for _, id in ipairs(self:Candidates(kind, npcIDs)) do
    local time, route = self:TravelTime(id, flights)
    if time then all[#all + 1] = { id = id, time = time, route = route } end
  end
  table.sort(all, function(a, b) if a.time ~= b.time then return a.time < b.time end return a.id < b.id end)
  local out, maps = {}, {}
  for _, option in ipairs(all) do
    local map = data().npcs[option.id][3]
    if not maps[map] then
      maps[map] = true
      out[#out + 1] = option
      if count and #out >= count then break end
    end
  end
  return out
end

-- npcID of the quickest candidate, or nil plus "position" / "none".
function Services:Closest(kind, npcIDs)
  local ranked, reason = self:Ranked(kind, npcIDs, 1)
  if reason then return nil, reason end
  if not ranked[1] then return nil, "none" end
  return ranked[1].id, ranked[1]
end

function Services:RouteText(route)
  if route and route.kind == "fly" then return L.SERVICES_ROUTE_FLY:format(route.from, route.to) end
  if route and route.kind == "continent" then return L.SERVICES_ROUTE_CONTINENT end
  return L.SERVICES_ROUTE_FOOT
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

-- A mark holds one or more options, best first: { kind, npcs = { id, ... },
-- fromRow, rule }. Saved marks from before options ({ npcID }) load as one
-- option; options whose NPC left the data are dropped. m.npcID is kept as a
-- shortcut to the best option.
function Services:Marks()
  local out = {}
  for _, m in ipairs(NN.db.marks) do
    if not m.npcs then m.npcs = { m.npcID } end
    if m.kind == "supplies" then m.kind = "food" end -- split into food / goods / trade
    local npcs = {}
    for _, id in ipairs(m.npcs) do if data().npcs[id] then npcs[#npcs + 1] = id end end
    m.npcs = npcs
    m.npcID = npcs[1]
    if npcs[1] then out[#out + 1] = m end
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
  for _, id in ipairs(npcIDs) do
    for _, option in ipairs(mark.npcs) do if id == option then return true end end
  end
  return false
end

-- rule: the reminder the mark came from; its mark goes when that reminder does.
-- npcs: one npcID or a list of options, best first.
function Services:Mark(kind, npcs, fromRow, rule)
  if type(npcs) ~= "table" then npcs = { npcs } end
  local marks = {}
  for _, m in ipairs(NN.db.marks) do if m.kind ~= kind then marks[#marks + 1] = m end end
  marks[#marks + 1] = { kind = kind, npcs = npcs, fromRow = fromRow and true or false, rule = rule }
  NN.db.marks = marks
  changed()
end

-- Drops one option; the mark goes with its last option.
function Services:UnmarkOption(kind, npcID)
  local mark = self:MarkOf(kind)
  if not mark then return end
  local npcs = {}
  for _, id in ipairs(mark.npcs) do if id ~= npcID then npcs[#npcs + 1] = id end end
  if #npcs == 0 then return self:Unmark(kind) end
  mark.npcs, mark.npcID = npcs, npcs[1]
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

-- Marks one NPC and tells the player: a chat line, the minimap tracking,
-- and (openMap) the world map on its zone.
function Services:MarkNpc(kind, id, fromRow, rule, openMap, route)
  self:Mark(kind, id, fromRow, rule)
  local npc = self:Npc(id)
  local text = L.SERVICES_MARKED:format(npc.name, npc.title, zoneName(npc.map))
  if route and route.kind == "fly" then text = text .. " " .. self:RouteText(route) end
  NN:Say(text)
  turnOnTracking(kind)
  if openMap and OpenWorldMap then OpenWorldMap(npc.map) end
end

-- Marks the quickest options of a kind (db.services.options, default 4),
-- says the best one and its route, opens the map there and turns on the
-- matching minimap tracking. Returns the best npcID or nil.
function Services:MarkClosest(kind, npcIDs, fromRow, rule)
  local ranked, reason = self:Ranked(kind, npcIDs, NN.db.services.options or 4)
  if not ranked[1] then
    if reason == "position" then NN:Say(L.SERVICES_NO_POSITION)
    else NN:Say(L.SERVICES_NONE:format(self:KindLabel(kind))) end
    return nil
  end
  local ids = {}
  for _, option in ipairs(ranked) do ids[#ids + 1] = option.id end
  self:Mark(kind, ids, fromRow, rule)
  local best = self:Npc(ids[1])
  local text = L.SERVICES_MARKED:format(best.name, best.title, zoneName(best.map))
  if ranked[1].route.kind == "fly" then text = text .. " " .. self:RouteText(ranked[1].route) end
  if #ids > 1 then text = text .. " " .. L.SERVICES_MORE:format(#ids - 1) end
  NN:Say(text)
  turnOnTracking(kind)
  if OpenWorldMap then OpenWorldMap(best.map) end
  return ids[1]
end

-- Drop marks whose NPC left the data (a data refresh between sessions).
NN:AfterLogin(function()
  NN.db.marks = Services:Marks()
  -- "supplies" (food & general goods) became food, goods and trade
  local kinds, open = NN.db.services.kinds, NN.db.map and NN.db.map.openMarks
  if kinds.supplies ~= nil then
    for _, k in ipairs({ "food", "goods", "trade" }) do if kinds[k] == nil then kinds[k] = kinds.supplies end end
    kinds.supplies = nil
  end
  if open and open.supplies ~= nil then
    if open.food == nil then open.food = open.supplies end
    open.supplies = nil
  end
end)
