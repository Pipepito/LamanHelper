-- Panel: the reminder list, and the compact icon strip used in combat.
local _, NN = ...
local L = NN.L

local Panel = { rows = {}, stripIcons = {}, combat = false, currentRows = {}, stripSeen = {} }
NN.Panel = Panel

local WIDTH, PAD, ROW_H, ROW_H2, ICON, TITLE_H = 260, 6, 24, 36, 20, 18
local STRIP_GAP = 4

-- Strip icon size: bigger while a controller is in use and the boost is on.
function Panel.STRIP_ICON()
  if NN.Controller and NN.Controller:Boost() then return 32 end
  return 24
end
local TEXT_WIDTH = WIDTH - PAD * 2 - ICON - 6

-------------------------------------------------------------------------------
-- Frames
-------------------------------------------------------------------------------

local frame = CreateFrame("Frame", "NewbieNudgePanel", UIParent)
Panel.frame = frame
frame:SetWidth(WIDTH)
frame:SetHeight(ROW_H + PAD * 2)
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()

frame.bg = frame:CreateTexture(nil, "BACKGROUND")
frame.bg:SetAllPoints()
frame.bg:SetColorTexture(0, 0, 0, 0.55)

local title = CreateFrame("Frame", nil, frame)
Panel.title = title
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
title:SetHeight(TITLE_H)
title.bg = title:CreateTexture(nil, "BACKGROUND")
title.bg:SetAllPoints()
title.bg:SetColorTexture(0.2, 0.4, 0.6, 0.8)
title.text = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title.text:SetPoint("LEFT", title, "LEFT", PAD, 0)
title.text:SetText(L.PANEL_TITLE)
title:Hide()

local list = CreateFrame("Frame", nil, frame)
Panel.list = list
list:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD)

local strip = CreateFrame("Frame", nil, frame)
Panel.strip = strip
strip:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
strip:Hide()

-------------------------------------------------------------------------------
-- Tooltip and clicks
-------------------------------------------------------------------------------

local function showTooltip(owner, data)
  if not data then return end
  GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
  GameTooltip:SetText(data.rule.title)
  GameTooltip:AddLine(data.result.text, 1, 0.82, 0, true)
  GameTooltip:AddLine(data.rule.help, 1, 1, 1, true)
  local left, right, shift
  if NN.Controller and NN.Controller.HintButtons then left, right, shift = NN.Controller:HintButtons() end
  if data.result.onClick then
    GameTooltip:AddLine(left and L.ROW_HINT_CLICK_PAD:format(left) or L.ROW_HINT_CLICK, 0.8, 0.8, 0.8)
  end
  if left then
    GameTooltip:AddLine(L.ROW_HINT_SNOOZE_PAD:format(right, shift, right), 0.8, 0.8, 0.8, true)
  else
    GameTooltip:AddLine(L.ROW_HINT_SNOOZE:format(NN.db and NN.db.snoozeMinutes or 60), 0.8, 0.8, 0.8, true)
  end
  if data.stale then GameTooltip:AddLine(L.ROW_STALE, 0.6, 0.6, 0.6) end
  GameTooltip:Show()
end

local function onClick(button, mouseButton)
  local data = button.data
  if not data then return end
  if mouseButton == "LeftButton" then
    if data.result.onClick then pcall(data.result.onClick) end
  elseif mouseButton == "RightButton" then
    NN:Snooze(data.rule.name, IsShiftKeyDown() and 0 or NN.db.snoozeMinutes)
  end
end

local function bindClickable(button)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetScript("OnClick", onClick)
  button:SetScript("OnEnter", function(self) showTooltip(self, self.data) end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-------------------------------------------------------------------------------
-- Rows (list mode)
-------------------------------------------------------------------------------

local function newRow(index)
  local row = CreateFrame("Button", nil, list)
  row:SetHeight(ROW_H)
  row:SetPoint("LEFT", list, "LEFT", 0, 0)
  row:SetPoint("RIGHT", list, "RIGHT", 0, 0)
  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints()
  row.bg:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.04 or 0.08)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(ICON, ICON)
  row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
  row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.text:SetWidth(TEXT_WIDTH)
  row.text:SetJustifyH("LEFT")
  row.text:SetWordWrap(true)
  row.text:SetMaxLines(2)
  bindClickable(row)
  return row
end

local function fillRow(row, text, icon, alpha, data)
  row.text:SetText(text)
  row.icon:SetTexture(icon or 134400)
  row:SetAlpha(alpha)
  row.data = data
  local measure = row.text.GetUnboundedStringWidth or row.text.GetStringWidth
  local height = (measure(row.text) > TEXT_WIDTH) and ROW_H2 or ROW_H
  row:SetHeight(height)
  row:Show()
  return height
end

function Panel:RefreshList(rows)
  local count = #rows
  local shown = math.min(count, NN.MAX_ROWS)
  local y, total = 0, 0
  local needed = shown + ((count > NN.MAX_ROWS) and 1 or 0)
  for i = 1, needed do
    local row = self.rows[i]
    if not row then row = newRow(i); self.rows[i] = row end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
    row:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -y)
    local height
    if i <= shown then
      local data = rows[i]
      height = fillRow(row, data.result.text, data.result.icon, data.stale and 0.5 or 1, data)
    else
      height = fillRow(row, L.MORE_ROWS:format(count - NN.MAX_ROWS), 134400, 1, nil)
    end
    y = y + height
    total = total + height
  end
  for i = needed + 1, #self.rows do self.rows[i]:Hide(); self.rows[i].data = nil end
  local titleHeight = title:IsShown() and TITLE_H or 0
  list:ClearAllPoints()
  list:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(PAD + titleHeight))
  list:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(PAD + titleHeight))
  list:SetHeight(total)
  frame:SetWidth(WIDTH)
  frame:SetHeight(total + PAD * 2 + titleHeight)
  if count == 0 then frame:Hide() else frame:Show() end
end

-------------------------------------------------------------------------------
-- Strip (combat mode)
-------------------------------------------------------------------------------

local function newStripIcon(index)
  local button = CreateFrame("Button", nil, strip)
  button:SetSize(Panel.STRIP_ICON(), Panel.STRIP_ICON())
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints()
  bindClickable(button)
  return button
end

local function pulse(button)
  if button.pulseTicker then button.pulseTicker:Cancel() end
  local ticks = 0
  button.pulseTicker = C_Timer.NewTicker(0.25, function(ticker)
    ticks = ticks + 1
    button:SetAlpha(ticks % 2 == 1 and 0.3 or 1)
    if ticks >= 6 then button:SetAlpha(1); ticker:Cancel(); button.pulseTicker = nil end
  end)
end

function Panel:RefreshStrip(rows)
  local seen = {}
  local STRIP_ICON = Panel.STRIP_ICON()
  for i, data in ipairs(rows) do
    local button = self.stripIcons[i]
    if not button then button = newStripIcon(i); self.stripIcons[i] = button end
    button:SetSize(STRIP_ICON, STRIP_ICON)
    button:ClearAllPoints()
    button:SetPoint("LEFT", strip, "LEFT", (i - 1) * (STRIP_ICON + STRIP_GAP), 0)
    button.icon:SetTexture(data.result.icon or 134400)
    button.data = data
    button:Show()
    local key = data.rule.name .. "|" .. tostring(data.result.text)
    seen[key] = true
    if data.stale then
      if button.pulseTicker then button.pulseTicker:Cancel(); button.pulseTicker = nil end
      button:SetAlpha(0.5)
    else
      button:SetAlpha(1)
      if not self.stripSeen[key] then pulse(button) end
    end
  end
  for i = #rows + 1, #self.stripIcons do self.stripIcons[i]:Hide(); self.stripIcons[i].data = nil end
  self.stripSeen = seen
  local titleHeight = title:IsShown() and TITLE_H or 0
  strip:ClearAllPoints()
  strip:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(PAD + titleHeight))
  strip:SetSize(math.max(1, #rows * (STRIP_ICON + STRIP_GAP) - STRIP_GAP), STRIP_ICON)
  frame:SetWidth(math.max(#rows * (STRIP_ICON + STRIP_GAP) - STRIP_GAP, 1) + PAD * 2)
  frame:SetHeight(STRIP_ICON + PAD * 2 + titleHeight)
  if #rows == 0 then frame:Hide() else frame:Show() end
end

-------------------------------------------------------------------------------
-- Public
-------------------------------------------------------------------------------

function Panel:Refresh(rows)
  self.currentRows = rows
  if NN.db and NN.db.panel.hidden then frame:Hide(); return end
  if self.combat then
    if NN.db and NN.db.combatStrip == false then frame:Hide(); return end
    list:Hide(); strip:Show()
    self:RefreshStrip(rows)
  else
    strip:Hide(); list:Show()
    self:RefreshList(rows)
  end
end

function Panel:SetCombatMode(inCombat)
  inCombat = inCombat and true or false
  if self.combat == inCombat then return end
  self.combat = inCombat
  if not inCombat then self.stripSeen = {} end
  self:Refresh(NN:ActiveRows())
end

function Panel:SetLocked(locked)
  if locked then title:Hide() else title:Show() end
  self:Refresh(self.currentRows)
end

function Panel:ApplyScale()
  local scale = (NN.db and NN.db.panel.scale) or 1
  if NN.Controller and NN.Controller:Boost() then
    scale = scale * ((NN.db.controller and NN.db.controller.scale) or 1.25)
  end
  frame:SetScale(scale)
end

-- Bindable actions (see Controller.lua / Bindings.xml).
function Panel:ToggleHidden()
  NN.db.panel.hidden = not NN.db.panel.hidden
  if NN.db.panel.hidden then frame:Hide() else self:Refresh(NN:ActiveRows()) end
end

function Panel:OpenTop()
  local row = self.currentRows and self.currentRows[1]
  if row and row.result and row.result.onClick then pcall(row.result.onClick) end
end

function Panel:SnoozeTop()
  local row = self.currentRows and self.currentRows[1]
  if row and row.rule then NN:Snooze(row.rule.name, NN.db.snoozeMinutes) end
end

function Panel:ApplyPosition()
  local p = NN.db.panel
  frame:ClearAllPoints()
  frame:SetPoint(p.point or "RIGHT", UIParent, p.point or "RIGHT", p.x or 0, p.y or 0)
end

function Panel:SavePosition()
  local point, _, _, x, y = frame:GetPoint(1)
  if not point then return end
  NN.db.panel.point, NN.db.panel.x, NN.db.panel.y = point, math.floor(x + 0.5), math.floor(y + 0.5)
end

function Panel:ResetPosition()
  local d = NN.defaults.panel
  NN.db.panel.point, NN.db.panel.x, NN.db.panel.y = d.point, d.x, d.y
  self:ApplyPosition()
end

frame:SetScript("OnDragStart", function(self)
  if NN.db and not NN.db.panel.locked then self:StartMoving() end
end)
frame:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  Panel:SavePosition()
end)

NN:AfterLogin(function()
  Panel:ApplyPosition()
  Panel:ApplyScale()
  Panel:SetLocked(NN.db.panel.locked)
end)
