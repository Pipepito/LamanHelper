-- InfoBar: a row on top of the reminder panel with bag space, gold and gear
-- condition. Laid out by Panel.lua (Panel:LayoutHeader); hidden in combat so
-- the combat strip stays small.
local _, NN = ...
local L = NN.L

local InfoBar = { HEIGHT = 18, segments = {} }
NN.InfoBar = InfoBar

local ICON, ICON_GAP, SEGMENT_GAP = 12, 3, 10
local REGULAR_FAMILY = 0
local LOW_DURABILITY = 0.20 -- same threshold as the durability rule
local RED, ORANGE, YELLOW, WHITE = { 1, 0.2, 0.2 }, { 1, 0.6, 0 }, { 1, 0.82, 0 }, { 1, 1, 1 }
local ORDER = { "bags", "gold", "gear" }

-------------------------------------------------------------------------------
-- Data
-------------------------------------------------------------------------------

-- Regular bags 0-4 only (family 0), the same bags the bag_full rule counts.
-- Returns used, total, free, or nil when the client hides a value.
function InfoBar.BagCounts()
  local total, free = 0, 0
  for bag = 0, 4 do
    local n = NN.Plain(C_Container.GetContainerNumSlots(bag))
    if n == nil then return nil end
    if n > 0 then
      local f, family = C_Container.GetContainerNumFreeSlots(bag)
      f, family = NN.Plain(f), NN.Plain(family)
      if f == nil then return nil end
      if (family or 0) == REGULAR_FAMILY then total, free = total + n, free + f end
    end
  end
  return total - free, total, free
end

function InfoBar.BagName(bag)
  if bag == 0 then return BACKPACK_TOOLTIP or "Backpack" end
  local id = NN.BagInventorySlot and NN.Plain(GetInventoryItemID("player", NN.BagInventorySlot(bag)))
  local name = id and NN.Plain(C_Item.GetItemInfo(id), "string")
  return name or ("Bag " .. bag)
end

-- { percent, anyLow, lowestName, lowestPercent }, or nil when unreadable.
-- percent is nil when nothing equipped has durability.
function InfoBar.GearStatus()
  local cur, max, anyLow = 0, 0, false
  local lowest, lowestSlot
  for slot = INVSLOT_FIRST_EQUIPPED or 1, INVSLOT_LAST_EQUIPPED or 17 do
    local c, m = GetInventoryItemDurability(slot)
    if c ~= nil or m ~= nil then
      c, m = NN.Plain(c), NN.Plain(m)
      if c == nil or m == nil then return nil end
      if m > 0 then
        cur, max = cur + c, max + m
        local ratio = c / m
        if ratio < LOW_DURABILITY then anyLow = true end
        if not lowest or ratio < lowest then lowest, lowestSlot = ratio, slot end
      end
    end
  end
  local status = { anyLow = anyLow }
  if max > 0 then
    status.percent = math.floor(cur / max * 100 + 0.5)
    status.lowestPercent = math.floor(lowest * 100 + 0.5)
    local id = NN.Plain(GetInventoryItemID("player", lowestSlot))
    status.lowestName = id and NN.Plain(C_Item.GetItemInfo(id), "string")
  end
  return status
end

-------------------------------------------------------------------------------
-- Frames
-------------------------------------------------------------------------------

local frame = CreateFrame("Frame", "NewbieNudgeInfoBar", NN.Panel.frame)
InfoBar.frame = frame
frame:SetHeight(InfoBar.HEIGHT)
frame:Hide()

local function newSegment(name, icon, onClick, tooltip)
  local button = CreateFrame("Button", nil, frame)
  button:SetHeight(InfoBar.HEIGHT)
  if icon then
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(ICON, ICON)
    button.icon:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.icon:SetTexture(icon)
  end
  button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  button.text:SetPoint("LEFT", button, "LEFT", icon and (ICON + ICON_GAP) or 0, 0)
  if onClick then
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", onClick)
  end
  if tooltip then
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      tooltip()
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  InfoBar.segments[name] = button
  return button
end

newSegment("bags", 133634, function() ToggleAllBags() end, function()
  GameTooltip:SetText(L.INFOBAR_BAGS_TITLE)
  for bag = 0, 4 do
    local n = NN.Plain(C_Container.GetContainerNumSlots(bag)) or 0
    local f, family = C_Container.GetContainerNumFreeSlots(bag)
    f, family = NN.Plain(f), NN.Plain(family)
    if n > 0 and f and (family or 0) == REGULAR_FAMILY then
      GameTooltip:AddLine(L.INFOBAR_BAG_LINE:format(InfoBar.BagName(bag), f, n), 1, 1, 1)
    end
  end
  GameTooltip:AddLine(L.INFOBAR_CLICK_BAGS, 0.8, 0.8, 0.8)
end)
-- The coin string already carries the coin icons.
newSegment("gold", nil, nil, nil)
newSegment("gear", 136241, function() ToggleCharacter("PaperDollFrame") end, function()
  GameTooltip:SetText(L.INFOBAR_GEAR_TITLE)
  local status = InfoBar.GearStatus()
  if status and status.lowestName then
    GameTooltip:AddLine(L.INFOBAR_GEAR_LOWEST:format(status.lowestName, status.lowestPercent), 1, 1, 1)
  end
  GameTooltip:AddLine(L.INFOBAR_CLICK_GEAR, 0.8, 0.8, 0.8)
end)

-------------------------------------------------------------------------------
-- Texts
-------------------------------------------------------------------------------

local function setText(button, text, colour)
  button.text:SetText(text)
  button.text:SetTextColor(colour[1], colour[2], colour[3])
end

local function bagsText(button)
  local used, total, free = InfoBar.BagCounts()
  if not used then return setText(button, L.INFOBAR_UNKNOWN, WHITE) end
  local colour = (free < 3 and RED) or (free < 6 and ORANGE) or WHITE
  setText(button, L.INFOBAR_BAGS:format(used, total, free), colour)
end

local function goldText(button, dropCopper)
  local money = NN.Plain(GetMoney())
  if not money then return setText(button, L.INFOBAR_UNKNOWN, WHITE) end
  if dropCopper and money >= 10000 then money = money - money % 100 end
  setText(button, NN.MoneyText(money), WHITE)
end

local function gearText(button)
  local status = InfoBar.GearStatus()
  if not status then return setText(button, L.INFOBAR_UNKNOWN, WHITE) end
  if not status.percent then return setText(button, "—", WHITE) end
  local colour = (status.anyLow and RED) or (status.percent < 50 and YELLOW) or WHITE
  setText(button, L.INFOBAR_GEAR:format(status.percent), colour)
end

local FILL = { bags = bagsText, gold = goldText, gear = gearText }

local function textWidth(fs)
  local measure = fs.GetUnboundedStringWidth or fs.GetStringWidth
  return measure(fs)
end

local function layout()
  local x = 0
  for _, name in ipairs(ORDER) do
    local button = InfoBar.segments[name]
    if button:IsShown() then
      local width = (button.icon and (ICON + ICON_GAP) or 0) + textWidth(button.text)
      button:SetWidth(width)
      button:ClearAllPoints()
      button:SetPoint("LEFT", frame, "LEFT", x, 0)
      x = x + width + SEGMENT_GAP
    end
  end
  local width = math.max(1, x - SEGMENT_GAP)
  frame:SetWidth(width)
  return width
end

-------------------------------------------------------------------------------
-- Public
-------------------------------------------------------------------------------

function InfoBar:IsActive()
  local db = NN.db
  if not (db and db.infobar and db.infobar.enabled) then return false end
  if db.panel.hidden then return false end
  if NN.Panel and NN.Panel.combat then return false end
  return (db.infobar.bags or db.infobar.gold or db.infobar.gear) and true or false
end

-- Updates every enabled segment and returns the bar's width. maxWidth (list
-- style) drops the copper from the gold text when the bar would not fit.
function InfoBar:Refresh(maxWidth)
  local opts = NN.db.infobar
  for _, name in ipairs(ORDER) do
    local button = self.segments[name]
    if opts[name] then FILL[name](button); button:Show() else button:Hide() end
  end
  local width = layout()
  if maxWidth and width > maxWidth and opts.gold then
    goldText(self.segments.gold, true)
    width = layout()
  end
  return width
end

-- The panel re-checks (and so redraws the bar) after any registered event.
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" }) do
  NN:RegisterEvent(event)
end
