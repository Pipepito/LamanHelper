-- MapList: the NewbieNudge list on the world map, opened from the map's
-- NewbieNudge icon. Switches for the unexplored areas and for each kind of
-- service shown on the map, and the player's marks (jump to, remove).
local _, NN = ...
local L = NN.L

local MapList = { rows = {}, used = 0 }
NN.MapList = MapList

local WIDTH, PAD, ROW_H, ICON = 230, 8, 18, 14
local CHECK_ON = "Interface\\Buttons\\UI-CheckBox-Check"
local CHECK_BOX = "Interface\\Buttons\\UI-CheckBox-Up"
local REVEAL_ICON = "Interface\\Icons\\INV_Misc_Map_01"

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------

local frame = CreateFrame("Frame", "NewbieNudgeMapList", WorldMapFrame or UIParent)
MapList.frame = frame
frame:SetWidth(WIDTH)
frame:EnableMouse(true)
frame:Hide()
frame.bg = frame:CreateTexture(nil, "BACKGROUND")
frame.bg:SetAllPoints()
frame.bg:SetColorTexture(0, 0, 0, 0.8)
frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
frame.title:SetText(L.MAPLIST_TITLE)

-- The lines live in a scrolling area that never grows past the map.
local scroll = CreateFrame("ScrollFrame", nil, frame)
local content = CreateFrame("Frame", nil, scroll)
scroll:SetScrollChild(content)
scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(self, delta)
  local max = math.max(0, content:GetHeight() - self:GetHeight())
  local value = math.min(max, math.max(0, (self:GetVerticalScroll() or 0) - delta * ROW_H * 2))
  self:SetVerticalScroll(value)
end)
MapList.scroll, MapList.content = scroll, content

local function newButton(label, onClick)
  local b = CreateFrame("Button", nil, frame)
  b:SetHeight(ROW_H)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.text:SetText(label)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.bg:SetColorTexture(0.2, 0.4, 0.6, 0.8)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
  b:SetScript("OnClick", onClick)
  return b
end

MapList.removeAll = newButton(L.MAPLIST_REMOVE_ALL, function() NN.Services:ClearMarks() end)
MapList.settings = newButton(L.MAPLIST_SETTINGS, function()
  if NN.MapReveal and NN.MapReveal.OpenSettings then NN.MapReveal:OpenSettings() end
end)
MapList.noneLabel = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
MapList.noneLabel:SetText(L.MAPLIST_NONE)

local function header(text)
  local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetText(text)
  return fs
end
MapList.showHeader = header(L.MAPLIST_SHOW)
MapList.marksHeader = header(L.MAPLIST_MARKS)

-------------------------------------------------------------------------------
-- Rows (a pool of buttons: check box, icon, label, optional remove button)
-------------------------------------------------------------------------------

local function acquireRow()
  MapList.used = MapList.used + 1
  local row = MapList.rows[MapList.used]
  if not row then
    row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp")
    row.check = row:CreateTexture(nil, "ARTWORK")
    row.check:SetSize(ICON + 2, ICON + 2)
    row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.label:SetMaxLines(1)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.removeButton = CreateFrame("Button", nil, row)
    row.removeButton:SetSize(ICON, ICON)
    row.removeButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.removeButton:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    row.removeButton:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(row.isHeading and L.MAPLIST_REMOVE_TT or L.MAPLIST_REMOVE_OPTION_TT)
      GameTooltip:Show()
    end)
    row.removeButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    MapList.rows[MapList.used] = row
  end
  row.isReveal, row.kindKey, row.npcID, row.markKind, row.checked, row.isHeading = nil, nil, nil, nil, nil, nil
  row.icon:SetTexCoord(0, 1, 0, 1)
  row:Show()
  return row
end

-- withCheck: the row shows a check box before its icon.
local function layoutRow(row, withCheck, checked, texture, coords, text)
  row.checked = checked
  row.icon:ClearAllPoints()
  if withCheck then
    row.check:SetTexture(checked and CHECK_ON or CHECK_BOX)
    row.check:Show()
    row.icon:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
  else
    row.check:Hide()
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
  end
  row.icon:SetTexture(texture)
  if coords then row.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end
  row.label:ClearAllPoints()
  row.label:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
  row.label:SetPoint("RIGHT", row, "RIGHT", -(ICON + 4), 0)
  row.label:SetText(text)
end

-------------------------------------------------------------------------------
-- Content
-------------------------------------------------------------------------------

local function professionName(skillLine)
  if not (GetProfessions and GetProfessionInfo) then return nil end
  for _, index in pairs({ GetProfessions() }) do
    index = NN.Plain(index)
    if index then
      local name, _, _, _, _, _, line = GetProfessionInfo(index)
      if NN.Plain(line) == skillLine then return NN.Plain(name, "string") end
    end
  end
  return nil
end

local FIXED_LABELS = { repair = "MAPLIST_KIND_REPAIR", inn = "MAPLIST_KIND_INN",
  prof_all = "MAPLIST_KIND_PROF_ALL", food = "MAPLIST_KIND_FOOD", goods = "MAPLIST_KIND_GOODS", trade = "MAPLIST_KIND_TRADE",
  weapon = "MAPLIST_KIND_WEAPON" }

function MapList.KindLabel(kind)
  if FIXED_LABELS[kind] then return L[FIXED_LABELS[kind]] end
  if kind:find("^trainer_") then
    local className = NN.Plain((UnitClass("player")), "string") or kind:sub(9)
    return L.MAPLIST_KIND_TRAINER:format(className)
  end
  local skillLine = tonumber(kind:match("^prof_(%d+)$"))
  return L.MAPLIST_KIND_PROF:format(professionName(skillLine) or NN.Services:KindLabel(kind))
end

local function kindOn(kind)
  local db = NN.db.services
  return db.showAll and db.kinds[kind] ~= false
end

local function place(widget, y, height)
  widget:ClearAllPoints()
  widget:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
  widget:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
  return y + (height or ROW_H)
end

function MapList:Refresh()
  if not (NN.db and frame:IsShown()) then return end
  self.used = 0
  local y = 0

  local reveal = acquireRow()
  reveal.isReveal = true
  layoutRow(reveal, true, NN.db.map.reveal and true or false, REVEAL_ICON, nil, L.MAPLIST_REVEAL)
  reveal.removeButton:Hide()
  reveal:SetScript("OnClick", function()
    if NN.MapReveal then NN.MapReveal:Toggle() else NN.db.map.reveal = not NN.db.map.reveal end
    MapList:Refresh()
  end)
  y = place(reveal, y)

  y = place(self.showHeader, y + 4, 16)
  for _, kind in ipairs(NN.MapPins.ShowAllKinds()) do
    local row = acquireRow()
    row.kindKey = kind
    local texture, coords = NN.MapPins.IconFor(kind)
    layoutRow(row, true, kindOn(kind), texture, coords, MapList.KindLabel(kind))
    row.removeButton:Hide()
    row:SetScript("OnClick", function()
      local db = NN.db.services
      if not db.showAll then
        -- services were off: show just the kind that was ticked
        db.showAll = true
        for _, k in ipairs(NN.MapPins.ShowAllKinds()) do db.kinds[k] = (k == kind) end
      else
        db.kinds[kind] = not kindOn(kind)
        local any = false
        for _, k in ipairs(NN.MapPins.ShowAllKinds()) do if kindOn(k) then any = true end end
        if not any then db.showAll = false end
      end
      NN.MapPins:Refresh()
      MapList:Refresh()
    end)
    y = place(row, y)
  end

  y = place(self.marksHeader, y + 4, 16)
  local marks = NN.Services:Marks()
  if #marks == 0 then
    self.noneLabel:Show()
    y = place(self.noneLabel, y)
  else
    self.noneLabel:Hide()
    for _, mark in ipairs(marks) do
      -- heading: the kind; its ✕ removes the whole mark
      local heading = acquireRow()
      heading.markKind, heading.isHeading = mark.kind, true
      local texture, coords = NN.MapPins.IconFor(mark.kind)
      layoutRow(heading, false, nil, texture, coords, MapList.KindLabel(mark.kind))
      heading.removeButton:Show()
      heading.removeButton:SetScript("OnClick", function() NN.Services:Unmark(mark.kind) end)
      heading:SetScript("OnClick", nil)
      y = place(heading, y)
      -- one line per option, quickest first: "1. Jandi · Orgrimmar · ~3 min"
      local flights = NN.Services:FlightMasters()
      for rank, id in ipairs(mark.npcs) do
        local npc = NN.Services:Npc(id)
        local row = acquireRow()
        row.npcID, row.markKind = id, mark.kind
        local text = ("%d. %s · %s"):format(rank, npc.name, NN.Services.ZoneName(npc.map))
        local time = NN.Services:TravelTime(id, flights)
        if time and time < 359999 then text = text .. (" · ~%d min"):format(math.max(1, math.ceil(time / 60)))
        elseif time then text = text .. " · " .. L.SERVICES_ROUTE_CONTINENT end
        layoutRow(row, false, nil, nil, nil, text)
        row.icon:SetTexture(nil)
        row.removeButton:Show()
        row.removeButton:SetScript("OnClick", function() NN.Services:UnmarkOption(mark.kind, id) end)
        row:SetScript("OnClick", function()
          if WorldMapFrame and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(npc.map) end
        end)
        y = place(row, y)
      end
    end
  end

  for i = self.used + 1, #self.rows do self.rows[i]:Hide() end

  -- the lines scroll inside the map's height; title above, buttons below
  local top, bottom = PAD + 20, ROW_H + 6 + PAD
  local mapHeight = (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer:GetHeight()) or 600
  if not mapHeight or mapHeight <= 0 then mapHeight = 600 end
  local visible = math.max(ROW_H * 3, math.min(y, mapHeight - top - bottom - 20))
  content:SetSize(WIDTH - PAD * 2, y)
  scroll:ClearAllPoints()
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -top)
  scroll:SetSize(WIDTH - PAD * 2, visible)
  local max = math.max(0, y - visible)
  if (scroll:GetVerticalScroll() or 0) > max then scroll:SetVerticalScroll(max) end

  if #marks > 0 then self.removeAll:Enable() else self.removeAll:Disable() end
  self.removeAll:SetAlpha(#marks > 0 and 1 or 0.5)
  local half = (WIDTH - PAD * 3) / 2
  local buttonsY = top + visible + 6
  self.removeAll:ClearAllPoints()
  self.removeAll:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -buttonsY)
  self.removeAll:SetWidth(half)
  self.settings:ClearAllPoints()
  self.settings:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -buttonsY)
  self.settings:SetWidth(half)
  frame:SetHeight(buttonsY + ROW_H + PAD)
end

-------------------------------------------------------------------------------
-- Open / close
-------------------------------------------------------------------------------

function MapList:Place()
  local anchor = NN.MapReveal and NN.MapReveal.button
  frame:ClearAllPoints()
  if anchor then
    frame:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 4)
  else
    frame:SetPoint("BOTTOMRIGHT", WorldMapFrame or UIParent, "BOTTOMRIGHT", -8, 40)
  end
  -- above the map and its pins (pins are one strata above the map)
  frame:SetFrameStrata("DIALOG")
  if NN.MapPins and NN.MapPins.Strata() == "DIALOG" then frame:SetFrameStrata("FULLSCREEN") end
end

function MapList:SetOpen(open)
  NN.db.map.listOpen = open and true or false
  if open then
    self:Place()
    frame:Show()
    self:Refresh()
  else
    frame:Hide()
  end
end

function MapList:Toggle()
  self:SetOpen(not frame:IsShown())
end

NN.Services:OnChange(function() MapList:Refresh() end)
NN:AfterLogin(function()
  if WorldMapFrame and WorldMapFrame.HookScript then
    WorldMapFrame:HookScript("OnShow", function()
      if NN.db.map.listOpen then MapList:SetOpen(true) end
    end)
    if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", function() MapList:Refresh() end) end
  end
end)
