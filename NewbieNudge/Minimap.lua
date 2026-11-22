-- Minimap button: a small round button on the minimap edge with a quick
-- menu (lock, panel style, info bar, snooze everything, hide, settings).
-- Hand-written; no LibDBIcon. Also listed in the game's AddOns drop-down
-- (AddonCompartmentFrame) when the client has one.
local _, NN = ...
local L = NN.L

local MinimapButton = {}
NN.MinimapButton = MinimapButton

local ICON = "Interface\\AddOns\\NewbieNudge\\Media\\icon"
local EDGE_OFFSET = 10

-------------------------------------------------------------------------------
-- Position
-------------------------------------------------------------------------------

local function isSquare()
  if type(GetMinimapShape) ~= "function" then return false end
  local shape = GetMinimapShape()
  return shape == "SQUARE"
end

-- Offset from the minimap centre for an angle in degrees (0 = right,
-- 90 = up). On a square minimap the point slides out to the square's edge.
function MinimapButton:PositionForAngle(angle)
  local radius = (Minimap:GetWidth() or 140) / 2 + EDGE_OFFSET
  local rad = math.rad(angle)
  local x, y = math.cos(rad) * radius, math.sin(rad) * radius
  if isSquare() then
    local scale = radius / math.max(math.abs(x), math.abs(y))
    x, y = x * scale, y * scale
  end
  return x, y
end

function MinimapButton:UpdatePosition()
  local button = self.button
  if not button then return end
  local x, y = self:PositionForAngle(NN.db.minimap.angle or 225)
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MinimapButton:SetAngle(angle)
  NN.db.minimap.angle = angle % 360
  self:UpdatePosition()
end

local function cursorAngle()
  local mx, my = Minimap:GetCenter()
  local cx, cy = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale() or 1
  cx, cy = cx / scale, cy / scale
  return math.deg(math.atan2(cy - my, cx - mx))
end

-------------------------------------------------------------------------------
-- Menu
-------------------------------------------------------------------------------

local function snoozeLabel()
  local minutes = NN.db.snoozeMinutes or 60
  local duration
  if minutes % 60 == 0 then
    duration = L.MENU_DURATION_HOURS:format(minutes / 60)
  else
    duration = L.MENU_DURATION_MINUTES:format(minutes)
  end
  return L.MENU_SNOOZE_ALL:format(duration)
end

-- The menu as plain data; OpenMenu turns it into the client's menu.
function MinimapButton:MenuEntries()
  local db = NN.db
  local entries = {}
  local function add(e) entries[#entries + 1] = e end
  local function refresh() if NN.Panel then NN.Panel:Refresh(NN:ActiveRows()) end end

  add({ kind = "title", label = L.ADDON_TITLE })
  add({ kind = "button", label = db.panel.locked and L.MENU_UNLOCK or L.MENU_LOCK, onClick = function()
    db.panel.locked = not db.panel.locked
    if NN.Panel then NN.Panel:SetLocked(db.panel.locked) end
  end })
  add({ kind = "divider" })
  add({ kind = "title", label = L.MENU_STYLE })
  for _, style in ipairs({ "list", "icons" }) do
    add({ kind = "radio", label = style == "list" and L.MENU_STYLE_LIST or L.MENU_STYLE_ICONS,
      checked = (db.panel.style or "list") == style,
      onClick = function() if NN.Panel then NN.Panel:SetStyle(style) else db.panel.style = style end end })
  end
  add({ kind = "checkbox", label = L.MENU_INFOBAR, checked = db.infobar.enabled and true or false, onClick = function()
    db.infobar.enabled = not db.infobar.enabled
    refresh()
  end })
  add({ kind = "divider" })
  if #NN:ActiveRows() > 0 then
    add({ kind = "button", label = snoozeLabel(), onClick = function()
      local minutes = db.snoozeMinutes or 60
      NN:Say(L.SNOOZE_ALL_DONE:format(NN:SnoozeShowing(minutes), minutes))
    end })
  end
  if next(db.snoozed) then
    add({ kind = "button", label = L.MENU_WAKE_ALL, onClick = function() NN:ClearSnoozes() end })
  end
  add({ kind = "button", label = db.panel.hidden and L.MENU_SHOW or L.MENU_HIDE, onClick = function()
    if NN.Panel then NN.Panel:ToggleHidden() else db.panel.hidden = not db.panel.hidden end
  end })
  add({ kind = "button", label = L.MENU_SETTINGS, onClick = function() NN:OpenOptions() end })
  return entries
end

local function openWithMenuUtil(owner, entries)
  MenuUtil.CreateContextMenu(owner, function(_, root)
    for _, e in ipairs(entries) do
      if e.kind == "title" then root:CreateTitle(e.label)
      elseif e.kind == "divider" then root:CreateDivider()
      elseif e.kind == "button" then root:CreateButton(e.label, e.onClick)
      elseif e.kind == "checkbox" then root:CreateCheckbox(e.label, function() return e.checked end, e.onClick)
      elseif e.kind == "radio" then root:CreateRadio(e.label, function() return e.checked end, e.onClick)
      end
    end
  end)
end

local function openWithEasyMenu(entries)
  local list = {}
  for _, e in ipairs(entries) do
    if e.kind == "divider" then
      list[#list + 1] = { text = "", disabled = true, notCheckable = true }
    else
      list[#list + 1] = {
        text = e.label, isTitle = e.kind == "title", notCheckable = e.kind == "title" or e.kind == "button",
        checked = e.checked, func = e.onClick, keepShownOnClick = false,
      }
    end
  end
  MinimapButton.dropdown = MinimapButton.dropdown
    or CreateFrame("Frame", "NewbieNudgeMinimapMenu", UIParent, "UIDropDownMenuTemplate")
  EasyMenu(list, MinimapButton.dropdown, "cursor", 0, 0, "MENU")
end

function MinimapButton:OpenMenu(owner)
  local entries = self:MenuEntries()
  if MenuUtil and MenuUtil.CreateContextMenu then
    openWithMenuUtil(owner or self.button or UIParent, entries)
  elseif EasyMenu then
    openWithEasyMenu(entries)
  end
end

-------------------------------------------------------------------------------
-- Tooltip
-------------------------------------------------------------------------------

local function fillTooltip(tooltip)
  tooltip:SetText(L.ADDON_TITLE)
  local count = #NN:ActiveRows()
  if count > 0 then
    tooltip:AddLine(L.MINIMAP_TT_COUNT:format(count), 1, 0.82, 0)
  else
    tooltip:AddLine(L.MINIMAP_TT_NONE, 1, 0.82, 0)
  end
  tooltip:AddLine(L.MINIMAP_TT_CLICK, 0.8, 0.8, 0.8)
  tooltip:AddLine(L.MINIMAP_TT_DRAG, 0.8, 0.8, 0.8)
end

-------------------------------------------------------------------------------
-- Button
-------------------------------------------------------------------------------

function MinimapButton:Create()
  if self.button or not Minimap then return self.button end
  local button = CreateFrame("Button", "NewbieNudgeMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button.background = button:CreateTexture(nil, "BACKGROUND")
  button.background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  button.background:SetSize(20, 20)
  button.background:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetTexture(ICON)
  button.icon:SetSize(20, 20)
  button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
  button.border = button:CreateTexture(nil, "OVERLAY")
  button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  button.border:SetSize(53, 53)
  button.border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetScript("OnClick", function(self) GameTooltip:Hide(); MinimapButton:OpenMenu(self) end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    fillTooltip(GameTooltip)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  button:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:SetScript("OnUpdate", function() MinimapButton:SetAngle(cursorAngle()) end)
  end)
  button:SetScript("OnDragStop", function(self)
    local onUpdate = self:GetScript("OnUpdate")
    if onUpdate then onUpdate(self) end
    self:SetScript("OnUpdate", nil)
  end)
  self.button = button
  self:UpdatePosition()
  return button
end

function MinimapButton:SetShown(shown)
  NN.db.minimap.hide = not shown
  local button = self:Create()
  if not button then return end
  if shown then button:Show() else button:Hide() end
end

function MinimapButton:Toggle()
  self:SetShown(NN.db.minimap.hide)
  NN:Say(NN.db.minimap.hide and L.SLASH_MINIMAP_OFF or L.SLASH_MINIMAP_ON)
end

NN:AfterLogin(function()
  MinimapButton:Create()
  MinimapButton:SetShown(not NN.db.minimap.hide)
  if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
    AddonCompartmentFrame:RegisterAddon({
      text = L.ADDON_TITLE,
      icon = ICON,
      notCheckable = true,
      func = function() MinimapButton:OpenMenu() end,
      funcOnEnter = function(owner)
        GameTooltip:SetOwner(owner or UIParent, "ANCHOR_LEFT")
        fillTooltip(GameTooltip)
        GameTooltip:Show()
      end,
      funcOnLeave = function() GameTooltip:Hide() end,
    })
  end
end)
