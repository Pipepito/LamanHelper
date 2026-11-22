-- MapPins: marked service NPCs (gold ring) and, when "show nearby services"
-- is on, every useful NPC of the player's faction on the world map. Pins are
-- plain buttons on the map canvas, placed in map coordinates; only the map
-- being viewed gets pins. No minimap pins (the game's own tracking does that).
local _, NN = ...
local L = NN.L

local MapPins = { pins = {}, used = 0, badges = {}, badgesUsed = 0 }
NN.MapPins = MapPins

local MARK_SIZE, PIN_SIZE = 20, 14
local RING_OPENING = 21
-- Named icon paths (a wrong file id draws nothing at all on the map).
local ICONS = {
  repair = "Interface\\Icons\\Trade_BlackSmithing", inn = "Interface\\Icons\\INV_Misc_Rune_01",
  food = "Interface\\Icons\\INV_Misc_Food_15", goods = "Interface\\Icons\\INV_Misc_Bag_10",
  trade = "Interface\\Icons\\INV_Fabric_Linen_01", flight = "Interface\\Icons\\Ability_Hunter_EagleEye", weapon = "Interface\\Icons\\INV_Sword_04",
}
local TRAINER_ICON, PROF_ICON = "Interface\\Icons\\INV_Misc_Book_09", "Interface\\Icons\\INV_Misc_Note_01"
-- profession skill line -> icon, for professions the player doesn't have
local PROF_ICONS = {
  [171] = "Interface\\Icons\\Trade_Alchemy", [164] = "Interface\\Icons\\Trade_BlackSmithing", [333] = "Interface\\Icons\\Trade_Engraving",
  [202] = "Interface\\Icons\\Trade_Engineering", [182] = "Interface\\Icons\\Trade_Herbalism", [165] = "Interface\\Icons\\INV_Misc_ArmorKit_17",
  [186] = "Interface\\Icons\\Trade_Mining", [393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", [197] = "Interface\\Icons\\Trade_Tailoring",
  [185] = "Interface\\Icons\\INV_Misc_Food_15", [129] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice", [356] = "Interface\\Icons\\Trade_Fishing",
}

-- The icon the client shows for one of the player's professions.
local function playerProfessionIcon(skillLine)
  if not (GetProfessions and GetProfessionInfo) then return nil end
  for _, index in pairs({ GetProfessions() }) do
    index = NN.Plain(index)
    if index then
      local _, icon, _, _, _, _, line = GetProfessionInfo(index)
      if NN.Plain(line) == skillLine and icon then return icon end
    end
  end
  return nil
end

local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"
-- Same values as the client's CLASS_ICON_TCOORDS, used when it is missing.
local CLASS_COORDS = {
  WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 },
  ROGUE = { 0.49609375, 0.7421875, 0, 0.25 }, DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
  HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
  PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
  PALADIN = { 0, 0.25, 0.5, 0.75 },
}

-- Texture and texture coordinates for a kind's pin; class trainers get the
-- round class icon.
local function iconFor(kind)
  if ICONS[kind] then return ICONS[kind] end
  local class = kind:match("^trainer_(%u+)$")
  if class then
    local coords = (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]) or CLASS_COORDS[class]
    if coords then return CLASS_ICONS, coords end
    return TRAINER_ICON
  end
  local skillLine = tonumber(kind:match("^prof_(%d+)$"))
  if skillLine then return playerProfessionIcon(skillLine) or PROF_ICONS[skillLine] or PROF_ICON end
  return PROF_ICON
end

local function canvas()
  return WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end

MapPins.IconFor = function(kind) return iconFor(kind) end

-------------------------------------------------------------------------------
-- Kinds shown by "show nearby services"
-------------------------------------------------------------------------------

-- Every profession, in this order on the map list.
MapPins.PROFESSIONS = { 171, 164, 333, 202, 182, 165, 186, 393, 197, 185, 129, 356 }

-- Skill lines of the player's professions, as a set.
function MapPins.PlayerProfessions()
  local set = {}
  if GetProfessions and GetProfessionInfo then
    for _, index in pairs({ GetProfessions() }) do
      index = NN.Plain(index)
      if index then
        -- only the 7th value: the real client returns more after it, and a
        -- second value would land in NN.Plain's "kind" argument
        local skillLine = NN.Plain((select(7, GetProfessionInfo(index))))
        if skillLine and skillLine > 0 then set[skillLine] = true end
      end
    end
  end
  return set
end

-- Kinds that "show nearby services" can draw: the fixed ones, the class
-- trainer, then every profession (the player's first).
function MapPins.ShowAllKinds()
  local kinds = { "repair", "inn", "food", "goods", "trade", "weapon", "flight" }
  local class = select(2, UnitClass("player"))
  if class then kinds[#kinds + 1] = "trainer_" .. class end
  local mine = MapPins.PlayerProfessions()
  for _, id in ipairs(MapPins.PROFESSIONS) do if mine[id] then kinds[#kinds + 1] = "prof_" .. id end end
  for _, id in ipairs(MapPins.PROFESSIONS) do if not mine[id] then kinds[#kinds + 1] = "prof_" .. id end end
  return kinds
end

-- Whether a kind is switched on in the map list. Not chosen yet: on, except
-- professions the player doesn't have.
function MapPins.KindShown(kind)
  local chosen = NN.db and NN.db.services.kinds[kind]
  if chosen ~= nil then return chosen end
  local skillLine = tonumber(kind:match("^prof_(%d+)$"))
  if skillLine then return MapPins.PlayerProfessions()[skillLine] == true end
  return true
end

-------------------------------------------------------------------------------
-- Pins
-------------------------------------------------------------------------------

local function onEnter(self)
  local npc = NN.Services:Npc(self.npcID)
  if not npc then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if self.marked then
    -- "2 · about 3 min · Fly from A to B." first, then who and where
    local time, route = NN.Services:TravelTime(self.npcID)
    if route and route.kind == "continent" then
      GameTooltip:SetText(L.MAPPIN_OPTION_FAR:format(self.rank or 1, NN.Services:RouteText(route)))
      GameTooltip:AddLine(npc.name, 1, 1, 1)
    elseif time then
      local minutes = math.max(1, math.ceil(math.min(time, 359999) / 60))
      GameTooltip:SetText(L.MAPPIN_OPTION:format(self.rank or 1, minutes, NN.Services:RouteText(route)))
      GameTooltip:AddLine(npc.name, 1, 1, 1)
    else
      GameTooltip:SetText(npc.name)
    end
  else
    GameTooltip:SetText(npc.name)
  end
  if npc.title ~= "" then GameTooltip:AddLine(npc.title, 1, 0.82, 0) end
  GameTooltip:AddLine(NN.Services.ZoneName(npc.map), 1, 1, 1)
  if self.kind == "flight" then
    if NN.Services:FlightKnown(self.npcID) then
      GameTooltip:AddLine(L.MAPPIN_FLIGHT_KNOWN, 0.3, 1, 0.3)
    elseif not NN.FlightPoints:CanJudge() then
      GameTooltip:AddLine(L.MAPPIN_FLIGHT_UNCHECKED, 0.8, 0.8, 0.8, true)
    else
      GameTooltip:AddLine(L.MAPPIN_FLIGHT_UNKNOWN, 1, 0.5, 0.2)
    end
  end
  GameTooltip:AddLine(self.marked and L.MAPPIN_REMOVE_OPTION or L.MAPPIN_CLICK_MARK, 0.8, 0.8, 0.8)
  GameTooltip:Show()
end

local function onClick(self, button)
  GameTooltip:Hide()
  if self.marked then
    if button == "RightButton" then NN.Services:UnmarkOption(self.kind, self.npcID) end
  elseif button == "LeftButton" then
    NN.Services:MarkNpc(self.kind, self.npcID, false, nil, false) -- the map is already open
  end
end

local function acquire()
  MapPins.used = MapPins.used + 1
  local pin = MapPins.pins[MapPins.used]
  if not pin then
    pin = CreateFrame("Button", nil, canvas())
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetAllPoints()
    -- round icon, so its corners don't stick out of the ring
    local mask = pin:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(pin.icon)
    pin.icon:AddMaskTexture(mask)
    pin.ring = pin:CreateTexture(nil, "OVERLAY")
    pin.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    pin.rankText = pin:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    pin.rankText:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", 3, -3)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin:SetScript("OnEnter", onEnter)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pin:SetScript("OnClick", onClick)
    MapPins.pins[MapPins.used] = pin
  end
  return pin
end

-- rank: the option's place in its mark (1 = quickest); numbered when the
-- mark has more than one option; gold ring for the quickest, grey otherwise.
-- One drawing strata above the map's own (MEDIUM -> HIGH): at the map's
-- strata the zone art hid the pins on Forever (cities showed them).
local STRATA_ORDER = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
function MapPins.Strata()
  local mapStrata = WorldMapFrame and WorldMapFrame.GetFrameStrata and WorldMapFrame:GetFrameStrata() or "MEDIUM"
  for i, name in ipairs(STRATA_ORDER) do
    if name == mapStrata then return STRATA_ORDER[math.min(i + 1, #STRATA_ORDER)] end
  end
  return "HIGH"
end

-- One level above the highest of the map's own pins (and at least the
-- canvas + 500). Worked out once per Refresh.
function MapPins.TopLevel()
  if MapPins.topLevel then return MapPins.topLevel end
  local child = canvas()
  local top = ((child and child:GetFrameLevel()) or 1) + 500
  if WorldMapFrame and WorldMapFrame.EnumerateAllPins then
    for pin in WorldMapFrame:EnumerateAllPins() do
      local level = pin.GetFrameLevel and pin:GetFrameLevel()
      if level and level + 10 > top then top = level + 10 end
    end
  end
  MapPins.topLevel = top
  return top
end

local function place(npcID, kind, marked, rank, options, px, py)
  local npc = NN.Services:Npc(npcID)
  local child = canvas()
  local pin = acquire()
  local size = marked and MARK_SIZE or PIN_SIZE
  pin.npcID, pin.kind, pin.marked, pin.rank = npcID, kind, marked, rank
  if marked and (options or 1) > 1 then
    pin.rankText:SetText(tostring(rank)); pin.rankText:Show()
  else
    pin.rankText:Hide()
  end
  if rank == 1 then pin.ring:SetVertexColor(1, 0.82, 0) else pin.ring:SetVertexColor(0.75, 0.75, 0.75) end
  pin:SetSize(size, size)
  local texture, coords = iconFor(kind)
  pin.icon:SetTexture(texture)
  if coords then pin.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) else pin.icon:SetTexCoord(0, 1, 0, 1) end
  -- The border's ring sits in the top-left of its 53 px texture: its opening
  -- is centred at (15.5, -14.5) and about RING_OPENING px wide. Scale it so
  -- the opening matches the icon and put that centre on the icon's centre.
  local k = size / RING_OPENING
  pin.ring:SetSize(53 * k, 53 * k)
  pin.ring:ClearAllPoints()
  pin.ring:SetPoint("TOPLEFT", pin, "TOPLEFT", size / 2 - 15.5 * k, -size / 2 + 14.5 * k)
  if marked then pin.ring:Show() else pin.ring:Hide() end
  -- Same map strata, above every pin the map draws itself (the explored-area
  -- layer covered ours in game while still letting the mouse through).
  pin:SetFrameStrata(MapPins.Strata())
  -- marks above city badges (+1), badges above the other pins
  pin:SetFrameLevel(MapPins.TopLevel() + (marked and 2 or 0))
  -- The pin keeps its size whatever the zoom: scale 1/canvasScale. SetPoint
  -- offsets are in the pin's own scale, so they grow by canvasScale.
  local scale = WorldMapFrame.ScrollContainer.GetCanvasScale and NN.Plain(WorldMapFrame.ScrollContainer:GetCanvasScale()) or 1
  if not scale or scale <= 0 then scale = 1 end
  pin:SetScale(1 / scale)
  pin:ClearAllPoints()
  local x, y = px or npc.x / 100, py or npc.y / 100
  pin:SetPoint("CENTER", child, "TOPLEFT", x * child:GetWidth() * scale, -y * child:GetHeight() * scale)
  pin:Show()
end

function MapPins:Refresh()
  self.used = 0
  self.topLevel = nil
  local map = WorldMapFrame and WorldMapFrame.GetMapID and NN.Plain(WorldMapFrame:GetMapID())
  if map and canvas() and NN.db and NN.Services then
    local drawn = {}
    for _, mark in ipairs(NN.Services:Marks()) do
      for rank, id in ipairs(mark.npcs) do
        local npc = NN.Services:Npc(id)
        if not drawn[id] then
          if npc.map == map then
            place(id, mark.kind, true, rank, #mark.npcs)
            drawn[id] = true
          else
            local px, py = MapPins.Project(npc, map)
            if px then place(id, mark.kind, true, rank, #mark.npcs, px, py); drawn[id] = true end
          end
        end
      end
    end
    if NN.db.services.showAll then
      for _, kind in ipairs(self.ShowAllKinds()) do
        -- kinds switched off in the map list are skipped
        local ids = MapPins.KindShown(kind) and NN.Services:Candidates(kind) or {}
        for _, id in ipairs(ids) do
          local npc = NN.Services:Npc(id)
          if npc.map == map and not drawn[id] then
            place(id, kind, false)
            drawn[id] = true
          end
        end
      end
    end
  end
  for i = self.used + 1, #self.pins do self.pins[i]:Hide() end
  self:RefreshBadges(map)
end

-------------------------------------------------------------------------------
-- City badges: on a zone map, the cities inside it show which of the
-- player's trainers, weapon masters and flight points they hold.
-------------------------------------------------------------------------------

-- The rectangle of a city map on the viewed map, or nil. The city's own
-- parent link is used when it points at the viewed map (continent maps);
-- otherwise the city's corners go through world positions, because on
-- Forever a city map hangs off the continent, not its zone (Orgrimmar is not
-- a child of Durotar). Only a city lying inside the viewed map counts.
local CONTINENT_TYPE = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2

local function cornersOnMap(cityMap, viewedMap)
  if not (C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
  local c1, p1 = C_Map.GetWorldPosFromMapPos(cityMap, CreateVector2D(0, 0))
  local c2, p2 = C_Map.GetWorldPosFromMapPos(cityMap, CreateVector2D(1, 1))
  if not (c1 and p1 and c2 and p2) then return nil end
  local _, a = C_Map.GetMapPosFromWorldPos(c1, p1, viewedMap)
  local _, b = C_Map.GetMapPosFromWorldPos(c2, p2, viewedMap)
  if not (a and b) then return nil end
  local ax, ay = a:GetXY()
  local bx, by = b:GetXY()
  ax, ay, bx, by = NN.Plain(ax), NN.Plain(ay), NN.Plain(bx), NN.Plain(by)
  if not (ax and ay and bx and by) then return nil end
  return math.min(ax, bx), math.max(ax, bx), math.min(ay, by), math.max(ay, by)
end

function MapPins.CityRect(cityMap, viewedMap)
  if cityMap == viewedMap or not (C_Map and C_Map.GetMapInfo) then return nil end
  local info = C_Map.GetMapInfo(cityMap)
  if not info then return nil end
  local left, right, top, bottom
  if NN.Plain(info.parentMapID) == viewedMap and C_Map.GetMapRectOnMap then
    left, right, top, bottom = C_Map.GetMapRectOnMap(cityMap, viewedMap)
    left, right, top, bottom = NN.Plain(left), NN.Plain(right), NN.Plain(top), NN.Plain(bottom)
  else
    local viewed = C_Map.GetMapInfo(viewedMap)
    if viewed and NN.Plain(viewed.mapType) == CONTINENT_TYPE then return nil end
    left, right, top, bottom = cornersOnMap(cityMap, viewedMap)
    if not left then return nil end
    -- a city: its centre inside the viewed map and much smaller than it
    -- (Orgrimmar pokes out past the top of Durotar's map); a neighbouring
    -- zone has its centre outside
    local cx, cy = (left + right) / 2, (top + bottom) / 2
    if cx < 0 or cx > 1 or cy < 0 or cy > 1 then return nil end
    if right - left > 0.6 or bottom - top > 0.6 then return nil end
  end
  if not (left and right and top and bottom) then return nil end
  return left, right, top, bottom
end

-- An NPC's spot on the viewed zone map when it stands in a city inside it.
function MapPins.Project(npc, viewedMap)
  local left, right, top, bottom = MapPins.CityRect(npc.map, viewedMap)
  if not left then return nil end
  return left + npc.x / 100 * (right - left), top + npc.y / 100 * (bottom - top)
end

local BADGE_ICON, BADGE_GAP = 14, 2

local function badgeEnter(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(NN.Services.ZoneName(self.mapID))
  for _, line in ipairs(self.lines) do GameTooltip:AddLine(line, 1, 1, 1, true) end
  GameTooltip:AddLine(L.MAPBADGE_CLICK, 0.8, 0.8, 0.8)
  GameTooltip:Show()
end

local function acquireBadge()
  MapPins.badgesUsed = MapPins.badgesUsed + 1
  local badge = MapPins.badges[MapPins.badgesUsed]
  if not badge then
    badge = CreateFrame("Button", nil, canvas())
    badge.bg = badge:CreateTexture(nil, "BACKGROUND")
    badge.bg:SetAllPoints()
    badge.bg:SetColorTexture(0, 0, 0, 0.6)
    badge.icons = {}
    badge:RegisterForClicks("LeftButtonUp")
    badge:SetScript("OnEnter", badgeEnter)
    badge:SetScript("OnLeave", function() GameTooltip:Hide() end)
    badge:SetScript("OnClick", function(self)
      GameTooltip:Hide()
      if WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(self.mapID) end
    end)
    MapPins.badges[MapPins.badgesUsed] = badge
  end
  return badge
end

function MapPins:RefreshBadges(map)
  self.badgesUsed = 0
  local child = canvas()
  if map and child and NN.db and NN.db.services.showAll and NN.Services then
    -- kinds a badge can show, in this order; professions share one icon
    local class = select(2, UnitClass("player"))
    local order = { class and ("trainer_" .. class) or nil, "weapon", "flight" }
    local profs = {}
    for _, kind in ipairs(self.ShowAllKinds()) do if kind:find("^prof_") then profs[#profs + 1] = kind end end
    local cities, cityOrder = {}, {}
    local function add(cityMap, iconKind, kind, name)
      local city = cities[cityMap]
      if not city then
        city = { kinds = {}, has = {}, names = {}, nameOrder = {} }
        cities[cityMap] = city
        cityOrder[#cityOrder + 1] = cityMap
      end
      if not city.has[iconKind] then city.has[iconKind] = true; city.kinds[#city.kinds + 1] = iconKind end
      if not city.names[kind] then city.names[kind] = {}; city.nameOrder[#city.nameOrder + 1] = kind end
      table.insert(city.names[kind], name)
    end
    local function collect(kind, iconKind)
      if not self.KindShown(kind) then return end
      for _, id in ipairs(NN.Services:Candidates(kind)) do
        local npc = NN.Services:Npc(id)
        if npc.map ~= map and self.CityRect(npc.map, map) then add(npc.map, iconKind, kind, npc.name) end
      end
    end
    for _, kind in ipairs(order) do collect(kind, kind) end
    for _, kind in ipairs(profs) do collect(kind, "prof") end
    local scale = WorldMapFrame.ScrollContainer.GetCanvasScale and NN.Plain(WorldMapFrame.ScrollContainer:GetCanvasScale()) or 1
    if not scale or scale <= 0 then scale = 1 end
    for _, cityMap in ipairs(cityOrder) do
      local city = cities[cityMap]
      local badge = acquireBadge()
      badge.mapID, badge.kinds = cityMap, city.kinds
      badge.lines = {}
      for _, kind in ipairs(city.nameOrder) do
        local label = (NN.MapList and NN.MapList.KindLabel(kind)) or kind
        badge.lines[#badge.lines + 1] = label .. ": " .. table.concat(city.names[kind], ", ")
      end
      for i, kind in ipairs(city.kinds) do
        local icon = badge.icons[i]
        if not icon then icon = badge:CreateTexture(nil, "ARTWORK"); badge.icons[i] = icon end
        local texture, coords = iconFor(kind == "prof" and "prof_0" or kind)
        icon:SetTexture(texture)
        if coords then icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) else icon:SetTexCoord(0, 1, 0, 1) end
        icon:SetSize(BADGE_ICON, BADGE_ICON)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", badge, "LEFT", BADGE_GAP + (i - 1) * (BADGE_ICON + BADGE_GAP), 0)
        icon:Show()
      end
      for i = #city.kinds + 1, #badge.icons do badge.icons[i]:Hide() end
      badge:SetSize(#city.kinds * (BADGE_ICON + BADGE_GAP) + BADGE_GAP, BADGE_ICON + BADGE_GAP * 2)
      badge:SetFrameStrata(self.Strata())
      badge:SetFrameLevel(self.TopLevel() + 1)
      badge:SetScale(1 / scale)
      local left, right, top, bottom = self.CityRect(cityMap, map)
      local w, h = child:GetWidth() * scale, child:GetHeight() * scale
      badge:ClearAllPoints()
      if left >= 0 and top >= 0 and right <= 1 and bottom <= 1 then
        -- city fully on the map: badge on the city
        badge:SetPoint("CENTER", child, "TOPLEFT", (left + right) / 2 * w, -(top + bottom) / 2 * h)
      else
        -- city cut by the map edge (Orgrimmar on Durotar): just below the
        -- part on the map, centred across it, kept on the map
        local l, r = math.max(0, left), math.min(1, right)
        local below = math.min(math.max(0, bottom) + 0.01, 0.95)
        badge:SetPoint("TOP", child, "TOPLEFT", (l + r) / 2 * w, -below * h)
      end
      badge:Show()
    end
  end
  for i = self.badgesUsed + 1, #self.badges do self.badges[i]:Hide() end
end

function MapPins:SetShowAll(on)
  NN.db.services.showAll = on and true or false
  self:Refresh()
  if NN.MapList then NN.MapList:Refresh() end
end

-------------------------------------------------------------------------------
-- Hooks: map changes, map shown, marks changed
-------------------------------------------------------------------------------

function MapPins:Hook()
  if self.hooked or not WorldMapFrame then return end
  self.hooked = true
  if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", function() MapPins:Refresh() end) end
  if WorldMapFrame.OnCanvasScaleChanged then hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", function() MapPins:Refresh() end) end
  WorldMapFrame:HookScript("OnShow", function() MapPins:Refresh() end)
end

NN.Services:OnChange(function()
  MapPins:Refresh()
  if NN.Panel and NN.Panel.currentRows then NN.Panel:Refresh(NN.Panel.currentRows) end
end)
NN:AfterLogin(function() MapPins:Hook() end)

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
  if name == "Blizzard_WorldMap" then MapPins:Hook() end
end)
