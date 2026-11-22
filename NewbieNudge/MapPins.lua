-- MapPins: marked service NPCs (gold ring) and, when "show nearby services"
-- is on, every useful NPC of the player's faction on the world map. Pins are
-- plain buttons on the map canvas, placed in map coordinates; only the map
-- being viewed gets pins. No minimap pins (the game's own tracking does that).
local _, NN = ...
local L = NN.L

local MapPins = { pins = {}, used = 0 }
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
        local skillLine = NN.Plain(select(7, GetProfessionInfo(index)))
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

local function place(npcID, kind, marked, rank, options)
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
  pin:SetFrameLevel(MapPins.TopLevel())
  -- The pin keeps its size whatever the zoom: scale 1/canvasScale. SetPoint
  -- offsets are in the pin's own scale, so they grow by canvasScale.
  local scale = WorldMapFrame.ScrollContainer.GetCanvasScale and NN.Plain(WorldMapFrame.ScrollContainer:GetCanvasScale()) or 1
  if not scale or scale <= 0 then scale = 1 end
  pin:SetScale(1 / scale)
  pin:ClearAllPoints()
  pin:SetPoint("CENTER", child, "TOPLEFT", npc.x / 100 * child:GetWidth() * scale, -(npc.y / 100) * child:GetHeight() * scale)
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
        if npc.map == map and not drawn[id] then
          place(id, mark.kind, true, rank, #mark.npcs)
          drawn[id] = true
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
