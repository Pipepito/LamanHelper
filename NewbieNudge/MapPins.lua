-- MapPins: marked service NPCs (gold ring) and, when "show nearby services"
-- is on, every useful NPC of the player's faction on the world map. Pins are
-- plain buttons on the map canvas, placed in map coordinates; only the map
-- being viewed gets pins. No minimap pins (the game's own tracking does that).
local _, NN = ...
local L = NN.L

local MapPins = { pins = {}, used = 0 }
NN.MapPins = MapPins

local MARK_SIZE, PIN_SIZE = 20, 14
local ICONS = { repair = 136241, inn = 134414, supplies = 133950, weapon = 135324 }
local TRAINER_ICON, PROF_ICON = 136243, 136240

local function iconFor(kind)
  if ICONS[kind] then return ICONS[kind] end
  if kind:find("^trainer_") then return TRAINER_ICON end
  return PROF_ICON
end

local function canvas()
  return WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end

-------------------------------------------------------------------------------
-- Kinds shown by "show nearby services"
-------------------------------------------------------------------------------

function MapPins.ShowAllKinds()
  local kinds = { "repair", "inn", "supplies", "weapon" }
  local class = select(2, UnitClass("player"))
  if class then kinds[#kinds + 1] = "trainer_" .. class end
  if GetProfessions and GetProfessionInfo then
    for _, index in pairs({ GetProfessions() }) do
      index = NN.Plain(index)
      if index then
        local skillLine = NN.Plain(select(7, GetProfessionInfo(index)))
        if skillLine and skillLine > 0 then kinds[#kinds + 1] = "prof_" .. skillLine end
      end
    end
  end
  return kinds
end

-------------------------------------------------------------------------------
-- Pins
-------------------------------------------------------------------------------

local function onEnter(self)
  local npc = NN.Services:Npc(self.npcID)
  if not npc then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(npc.name)
  if npc.title ~= "" then GameTooltip:AddLine(npc.title, 1, 0.82, 0) end
  GameTooltip:AddLine(NN.Services.ZoneName(npc.map), 1, 1, 1)
  GameTooltip:AddLine(self.marked and L.MAPPIN_REMOVE or L.MAPPIN_CLICK_MARK, 0.8, 0.8, 0.8)
  GameTooltip:Show()
end

local function onClick(self, button)
  GameTooltip:Hide()
  if self.marked then
    if button == "RightButton" then NN.Services:Unmark(self.kind) end
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
    pin.ring = pin:CreateTexture(nil, "OVERLAY")
    pin.ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    pin.ring:SetPoint("TOPLEFT", pin, "TOPLEFT", -4, 4)
    pin.ring:SetVertexColor(1, 0.82, 0)
    pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    pin:SetScript("OnEnter", onEnter)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pin:SetScript("OnClick", onClick)
    MapPins.pins[MapPins.used] = pin
  end
  return pin
end

local function place(npcID, kind, marked)
  local npc = NN.Services:Npc(npcID)
  local child = canvas()
  local pin = acquire()
  local size = marked and MARK_SIZE or PIN_SIZE
  pin.npcID, pin.kind, pin.marked = npcID, kind, marked
  pin:SetSize(size, size)
  pin.icon:SetTexture(iconFor(kind))
  pin.ring:SetSize(size * 1.7, size * 1.7)
  if marked then pin.ring:Show() else pin.ring:Hide() end
  -- Same map strata, above the canvas and Blizzard's own pins.
  pin:SetFrameLevel((child:GetFrameLevel() or 1) + 500)
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
  local map = WorldMapFrame and WorldMapFrame.GetMapID and NN.Plain(WorldMapFrame:GetMapID())
  if map and canvas() and NN.db and NN.Services then
    local drawn = {}
    for _, mark in ipairs(NN.Services:Marks()) do
      local npc = NN.Services:Npc(mark.npcID)
      if npc.map == map and not drawn[mark.npcID] then
        place(mark.npcID, mark.kind, true)
        drawn[mark.npcID] = true
      end
    end
    if NN.db.services.showAll then
      for _, kind in ipairs(self.ShowAllKinds()) do
        for _, id in ipairs(NN.Services:Candidates(kind)) do
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
