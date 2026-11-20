-- BagFull: when the bags are full and the player is trying to pick something
-- up, a small frame lists the cheapest stacks to destroy, with a button per
-- row, so they can free a slot without closing the loot or quest window.
-- Not a rule: it owns one frame and listens to raw events.
local _, NN = ...
local L = NN.L

local BagFull = { rows = {}, reason = nil }
NN.BagFull = BagFull
BagFull.MAX_ROWS = 6

local HEARTHSTONE = 6948
local SURE_SECONDS, AUTO_HIDE_SECONDS = 3, 90
local WIDTH, PAD, ROW_H, TITLE_H, FOOT_H, ICON = 300, 8, 22, 22, 16, 18

local IC = Enum and Enum.ItemClass or {}
local EXCLUDED_CLASSES = {}
for _, key in ipairs({ "Container", "Projectile", "Quiver", "Key", "Reagent", "Questitem" }) do
  if IC[key] ~= nil then EXCLUDED_CLASSES[IC[key]] = true end
end

-------------------------------------------------------------------------------
-- Candidates
-------------------------------------------------------------------------------

-- Names of items that unfinished quest objectives still need.
local function objectiveNames()
  local names = {}
  if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives) then
    return names
  end
  local numEntries = NN.Plain((C_QuestLog.GetNumQuestLogEntries())) or 0
  for i = 1, numEntries do
    local info = C_QuestLog.GetInfo(i)
    local questID = info and not info.isHeader and NN.Plain(info.questID)
    if questID then
      for _, o in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        if NN.Plain(o.type, "string") == "item" and o.finished ~= true then
          local name = NN.ObjectiveItemName and NN.ObjectiveItemName(o.text)
          if name then names[name] = true end
        end
      end
    end
  end
  return names
end

local function isQuestish(bag, slot)
  if not (C_Container.GetContainerItemQuestInfo) then return false end
  local q = C_Container.GetContainerItemQuestInfo(bag, slot)
  return q ~= nil and (q.isQuestItem == true or NN.Plain(q.questID) ~= nil)
end

-- Sorted list of { bag, slot, itemID, name, quality, count, value, icon, link }.
function BagFull:Candidates()
  local maxQuality = (NN.db and NN.db.bagfull and NN.db.bagfull.maxQuality) or 2
  local needed = objectiveNames()
  local list = {}
  for bag = 0, 4 do
    local _, family = C_Container.GetContainerNumFreeSlots(bag)
    if (NN.Plain(family) or 0) == 0 then
      for slot = 1, NN.Plain(C_Container.GetContainerNumSlots(bag)) or 0 do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        local itemID = info and NN.Plain(info.itemID)
        local link = info and NN.Plain(info.hyperlink, "string")
        if itemID and link and info.isLocked ~= true and itemID ~= HEARTHSTONE and not isQuestish(bag, slot) then
          local name, _, quality, _, _, _, _, _, equipLoc, icon, sellPrice, classID = C_Item.GetItemInfo(link)
          name, quality, sellPrice, classID = NN.Plain(name, "string"), NN.Plain(quality), NN.Plain(sellPrice), NN.Plain(classID)
          equipLoc = NN.Plain(equipLoc, "string") or ""
          if name and quality and sellPrice and classID
            and not EXCLUDED_CLASSES[classID] and quality <= maxQuality
            and (quality == 0 or (equipLoc == "" and sellPrice > 0))
            and not needed[name] then
            local count = NN.Plain(info.stackCount) or 1
            list[#list + 1] = {
              bag = bag, slot = slot, itemID = itemID, name = name, quality = quality, count = count,
              value = sellPrice * count, icon = NN.Plain(icon) or NN.Plain(info.iconFileID) or 134400, link = link,
            }
          end
        end
      end
    end
  end
  table.sort(list, function(a, b)
    local ga, gb = a.quality == 0 and 0 or 1, b.quality == 0 and 0 or 1
    if ga ~= gb then return ga < gb end
    if a.value ~= b.value then return a.value < b.value end
    if a.quality ~= b.quality then return a.quality < b.quality end
    if a.count ~= b.count then return a.count < b.count end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
  end)
  return list
end

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------

local frame = CreateFrame("Frame", "NewbieNudgeBagFull", UIParent)
BagFull.frame = frame
frame:SetWidth(WIDTH)
frame:SetFrameStrata("HIGH")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()
frame.bg = frame:CreateTexture(nil, "BACKGROUND")
frame.bg:SetAllPoints()
frame.bg:SetColorTexture(0, 0, 0, 0.8)

local title = CreateFrame("Frame", nil, frame)
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
title:SetHeight(TITLE_H)
title.bg = title:CreateTexture(nil, "BACKGROUND")
title.bg:SetAllPoints()
title.bg:SetColorTexture(0.5, 0.1, 0.1, 0.9)
title.text = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title.text:SetPoint("LEFT", title, "LEFT", PAD, 0)
title.text:SetText(L.BAGFULL_TITLE)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("RIGHT", title, "RIGHT", 2, 0)
close:SetSize(TITLE_H, TITLE_H)
close:SetScript("OnClick", function() BagFull:Hide() end)

local foot = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 4)
foot:SetText(L.BAGFULL_FOOT)

frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
frame:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local point, _, _, x, y = self:GetPoint(1)
  if point and NN.db then
    NN.db.bagfull.point, NN.db.bagfull.x, NN.db.bagfull.y = point, math.floor(x + 0.5), math.floor(y + 0.5)
  end
end)

local function qualityColor(quality)
  if C_Item and C_Item.GetItemQualityColor then
    local r, g, b = C_Item.GetItemQualityColor(quality)
    if r then return r, g, b end
  end
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

local function moneyText(value)
  if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then return C_CurrencyInfo.GetCoinTextureString(value) end
  if GetMoneyString then return GetMoneyString(value) end
  return tostring(value)
end

local function newRow(index)
  local row = CreateFrame("Frame", nil, frame)
  row:SetHeight(ROW_H)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(ICON, ICON)
  row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.button:SetSize(64, ROW_H - 2)
  row.button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  row.button:SetText(L.BAGFULL_DESTROY)
  row.button:SetScript("OnClick", function() BagFull:Destroy(row) end)
  row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.value:SetPoint("RIGHT", row.button, "LEFT", -6, 0)
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
  row.name:SetPoint("RIGHT", row.value, "LEFT", -4, 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)
  return row
end

local function resetSure(row)
  if row.sureTimer then row.sureTimer:Cancel(); row.sureTimer = nil end
  row.sure = nil
  row.button:SetText(L.BAGFULL_DESTROY)
end

function BagFull:Refresh()
  local list = self:Candidates()
  local shown = math.min(#list, self.MAX_ROWS)
  for i = 1, shown do
    local row = self.rows[i]
    if not row then row = newRow(i); self.rows[i] = row end
    local d = list[i]
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(TITLE_H + PAD + (i - 1) * ROW_H))
    row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(TITLE_H + PAD + (i - 1) * ROW_H))
    row.icon:SetTexture(d.icon)
    row.name:SetText(d.count > 1 and (d.name .. " x" .. d.count) or d.name)
    row.name:SetTextColor(qualityColor(d.quality))
    row.value:SetText(moneyText(d.value))
    if not row.data or row.data.itemID ~= d.itemID or row.data.bag ~= d.bag or row.data.slot ~= d.slot then resetSure(row) end
    row.data = d
    row:Show()
  end
  for i = shown + 1, #self.rows do self.rows[i]:Hide(); self.rows[i].data = nil; resetSure(self.rows[i]) end
  foot:SetText(#list == 0 and L.BAGFULL_EMPTY or L.BAGFULL_FOOT)
  frame:SetHeight(TITLE_H + PAD + math.max(shown, 1) * ROW_H + PAD + FOOT_H)
end

-- Same boost as the panel while a controller is in use.
function BagFull:ApplyScale()
  local scale = 1
  if NN.Controller and NN.Controller:Boost() then scale = (NN.db.controller and NN.db.controller.scale) or 1.25 end
  frame:SetScale(scale)
end

function BagFull:Anchor()
  frame:ClearAllPoints()
  if LootFrame and LootFrame:IsShown() then
    frame:SetPoint("TOPLEFT", LootFrame, "TOPRIGHT", 8, 0)
  else
    local p = NN.db.bagfull
    frame:SetPoint(p.point or "LEFT", UIParent, p.point or "LEFT", p.x or 40, p.y or 0)
  end
end

-------------------------------------------------------------------------------
-- Show / hide
-------------------------------------------------------------------------------

local function cancelTimer()
  if BagFull.timer then BagFull.timer:Cancel(); BagFull.timer = nil end
end

-- reason: "error" (inventory full message), "loot" (loot window with no
-- space), "manual" (/nudge trash; never hides on its own).
function BagFull:Show(reason)
  if not (NN.db and NN.db.bagfull and NN.db.bagfull.enabled) then return end
  self.reason = reason or "manual"
  self:Refresh()
  self:ApplyScale()
  self:Anchor()
  frame:Show()
  self.events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  cancelTimer()
  if self.reason ~= "manual" then
    self.timer = C_Timer.NewTimer(AUTO_HIDE_SECONDS, function()
      BagFull.timer = nil
      if BagFull.reason ~= "manual" then BagFull:Hide() end
    end)
  end
end

function BagFull:Hide()
  frame:Hide()
  self.reason = nil
  self.events:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
  cancelTimer()
end

function BagFull:IsShown() return frame:IsShown() end

-- Hides once a slot is free and the loot window is gone (not for manual opens).
function BagFull:MaybeAutoHide()
  if not frame:IsShown() or self.reason == "manual" then return end
  local free = NN.RegularFreeSlots()
  if free ~= NN.UNKNOWN and free >= 1 and not (LootFrame and LootFrame:IsShown()) then self:Hide() end
end

-------------------------------------------------------------------------------
-- Destroy
-------------------------------------------------------------------------------

function BagFull:Destroy(row)
  local d = row.data
  if not d then return end
  local info = C_Container.GetContainerItemInfo(d.bag, d.slot)
  if not info or NN.Plain(info.itemID) ~= d.itemID or (NN.Plain(info.stackCount) or 1) ~= d.count then
    self:Refresh()
    return
  end
  if d.quality >= 1 and not row.sure then
    row.sure = true
    row.button:SetText(L.BAGFULL_SURE)
    row.sureTimer = C_Timer.NewTimer(SURE_SECONDS, function() row.sureTimer = nil; resetSure(row) end)
    return
  end
  resetSure(row)
  ClearCursor()
  C_Container.PickupContainerItem(d.bag, d.slot)
  if CursorHasItem and CursorHasItem() then
    DeleteCursorItem()
  else
    ClearCursor()
  end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

NN:RegisterEvent("UI_ERROR_MESSAGE")
NN:RegisterEvent("LOOT_OPENED")
NN:RegisterEvent("LOOT_CLOSED")

-- Item info arrives in bursts; only listen while the frame is shown, on a
-- private frame so the core scheduler is not woken by it.
BagFull.events = CreateFrame("Frame")
BagFull.events:SetScript("OnEvent", function(_, event)
  if event == "GET_ITEM_INFO_RECEIVED" and frame:IsShown() then BagFull:Refresh() end
end)

NN:OnAnyEvent(function(event, arg1, arg2)
  if event == "UI_ERROR_MESSAGE" then
    if arg2 == ERR_INV_FULL then BagFull:Show("error") end
  elseif event == "LOOT_OPENED" then
    if NN.db and NN.db.bagfull.onLoot and NN.RegularFreeSlots() == 0 then BagFull:Show("loot") end
  elseif event == "LOOT_CLOSED" then
    BagFull:MaybeAutoHide()
  elseif event == "BAG_UPDATE_DELAYED" then
    if frame:IsShown() then BagFull:Refresh(); BagFull:MaybeAutoHide() end
  end
end)

-------------------------------------------------------------------------------
-- Options page
-------------------------------------------------------------------------------

NN.Options.RegisterPage("bags", "OPT_BAGS", function(category, layout)
  local Options = NN.Options
  Options.AddCheckbox(category, "NN_bagfull_enabled", L.OPT_BAGFULL_ENABLED, L.OPT_BAGFULL_ENABLED_TT,
    function() return NN.db.bagfull.enabled end,
    function(value) NN.db.bagfull.enabled = value and true or false; if not value then BagFull:Hide() end end)
  Options.AddDropdown(category, "NN_bagfull_quality", L.OPT_BAGFULL_QUALITY, L.OPT_BAGFULL_QUALITY_TT, {
      { value = "0", label = ITEM_QUALITY0_DESC or "Poor" },
      { value = "1", label = ITEM_QUALITY1_DESC or "Common" },
      { value = "2", label = ITEM_QUALITY2_DESC or "Uncommon" },
    },
    function() return tostring(NN.db.bagfull.maxQuality or 2) end,
    function(value) NN.db.bagfull.maxQuality = tonumber(value) or 2; if frame:IsShown() then BagFull:Refresh() end end)
  Options.AddCheckbox(category, "NN_bagfull_onLoot", L.OPT_BAGFULL_ONLOOT, nil,
    function() return NN.db.bagfull.onLoot end,
    function(value) NN.db.bagfull.onLoot = value and true or false end)
end)
