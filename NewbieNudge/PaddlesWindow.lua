-- The Paddles window: NewbieNudge's own editor for the back paddles. Opened
-- from the minimap menu and /nudge paddles, never from Blizzard's Settings
-- panel (its commit tainted Forever's controller interface, 2026-11-23).
local _, NN = ...
local L = NN.L

local Window = { rows = {} }
NN.PaddlesWindow = Window

local ROW_H, SLOT = 34, 28
local EMPTY_ICON = 134400
local COMMAND_ICON = 136243

local function P() return NN.Paddles end
-- PLAYER_REGEN_DISABLED fires before InCombatLockdown() turns true
local fighting = false
local function inCombat() return fighting or (InCombatLockdown and InCombatLockdown()) end

local function slotLabel(slot)
  return (NN.Controller and NN.Controller.PAD_NAMES and NN.Controller.PAD_NAMES[slot]) or slot
end

-------------------------------------------------------------------------------
-- What goes on a slot
-------------------------------------------------------------------------------

-- The action the cursor holds, or nil.
local function cursorAction()
  if not GetCursorInfo then return nil end
  local kind, a, _, c = GetCursorInfo()
  if kind == "spell" then
    local id = NN.Plain(c) or NN.Plain(a)
    return id and { kind = "spell", value = id }
  elseif kind == "item" then
    return NN.Plain(a) and { kind = "item", value = NN.Plain(a) }
  elseif kind == "macro" then
    local name = GetMacroInfo and NN.Plain((GetMacroInfo(a)), "string")
    return name and { kind = "macro", value = name }
  end
  return nil
end

-- slot nil = the paddle itself, else a layer slot of paddle n
local function setAction(n, slot, action)
  if slot then P():SetLayerAction(n, slot, action) else P():SetAction(n, action) end
  Window:Refresh()
end

local function currentAction(n, slot)
  local entry = P():Get(n)
  if slot then return entry.layer and entry.layer[slot] end
  return entry.action
end

-- Every game command with a name, grouped by the game's binding headers.
local function commandGroups()
  local groups, order = {}, {}
  if not (GetNumBindings and GetBinding) then return order, groups end
  for i = 1, GetNumBindings() or 0 do
    local command, category = GetBinding(i)
    command = NN.Plain(command, "string")
    if command and not command:find("^HEADER_") then
      local name = GetBindingName and NN.Plain(GetBindingName(command), "string")
      if name and name ~= command then
        local header = NN.Plain(category, "string") or ""
        local title = (header ~= "" and NN.Plain(_G[header], "string")) or header
        if not groups[title] then groups[title] = {}; order[#order + 1] = title end
        local list = groups[title]
        list[#list + 1] = { command = command, name = name }
      end
    end
  end
  return order, groups
end

-- The picker's lists: { label, icon, action } rows; header rows have no action.
local function spellChoices()
  local out = {}
  for _, sp in ipairs(NN.Spellbook and NN.Spellbook:KnownSpells() or {}) do
    local icon = C_Spell and C_Spell.GetSpellTexture and P().Icon(C_Spell.GetSpellTexture(sp.id))
    out[#out + 1] = { label = sp.name, icon = icon or EMPTY_ICON, action = { kind = "spell", value = sp.id } }
  end
  return out
end

local function itemChoices()
  local out, seen = {}, {}
  if not (C_Container and C_Container.GetContainerNumSlots) then return out end
  for bag = 0, (NUM_BAG_SLOTS or 4) + 1 do
    for slot = 1, NN.Plain(C_Container.GetContainerNumSlots(bag)) or 0 do
      local id = NN.Plain(C_Container.GetContainerItemID(bag, slot))
      if id and not seen[id] and C_Item and C_Item.GetItemSpell and C_Item.GetItemSpell(id) then
        seen[id] = true
        local name = NN.Plain(C_Item.GetItemNameByID and C_Item.GetItemNameByID(id), "string")
        local icon = C_Item.GetItemIconByID and P().Icon(C_Item.GetItemIconByID(id))
        out[#out + 1] = { label = name or ("item:" .. id), icon = icon or EMPTY_ICON, action = { kind = "item", value = id } }
      end
    end
  end
  table.sort(out, function(a, b) return a.label < b.label end)
  return out
end

local function macroChoices()
  local out = {}
  if not (GetNumMacros and GetMacroInfo) then return out end
  local account, character = GetNumMacros()
  local function add(i)
    local name, icon = GetMacroInfo(i)
    name = NN.Plain(name, "string")
    if name then out[#out + 1] = { label = name, icon = P().Icon(icon) or EMPTY_ICON, action = { kind = "macro", value = name } } end
  end
  for i = 1, NN.Plain(account) or 0 do add(i) end
  for i = 121, 120 + (NN.Plain(character) or 0) do add(i) end
  return out
end

local function commandChoices(forPaddle)
  local out = {}
  if forPaddle then out[#out + 1] = { label = L.PADDLES_LAYER, icon = EMPTY_ICON, action = { kind = "layer" } } end
  local order, groups = commandGroups()
  for _, title in ipairs(order) do
    out[#out + 1] = { label = title, header = true }
    for _, c in ipairs(groups[title]) do
      out[#out + 1] = { label = c.name, icon = COMMAND_ICON, action = { kind = "command", value = c.command } }
    end
  end
  return out
end

Window.TABS = { "spells", "items", "macros", "commands" }

function Window:Choices(tab, forPaddle)
  if tab == "spells" then return spellChoices() end
  if tab == "items" then return itemChoices() end
  if tab == "macros" then return macroChoices() end
  if tab == "commands" then return commandChoices(forPaddle) end
  return {}
end

-------------------------------------------------------------------------------
-- Picker: choose a slot's action from a list (works with the d-pad)
-------------------------------------------------------------------------------

local PER_PAGE = 10
local PICKER_HEIGHT = 56 + PER_PAGE * 24 + 56
local TAB_LABEL = { spells = "PADDLES_TAB_SPELLS", items = "PADDLES_TAB_ITEMS", macros = "PADDLES_TAB_MACROS",
  commands = "PADDLES_TAB_COMMANDS" }

local function pickerTarget(p)
  local name = L.PADDLES_ROW:format(p.n)
  if p.slot then name = name .. ": " .. slotLabel(p.slot) end
  return name
end

function Window:RenderPicker()
  local p, ui = self.picker, self.frame and self.frame.picker
  if not ui then return end
  if not p then ui:Hide(); return end
  p.list = self:Choices(p.tab, p.slot == nil)
  local pages = math.max(1, math.ceil(#p.list / PER_PAGE))
  p.page = math.min(math.max(p.page or 1, 1), pages)
  local first = (p.page - 1) * PER_PAGE
  if not p.index or p.index <= first or p.index > first + PER_PAGE then p.index = first + 1 end
  -- never rest on a group header
  while p.list[p.index] and p.list[p.index].header and p.index < #p.list do p.index = p.index + 1 end
  ui.title:SetText(L.PADDLES_PICK_FOR:format(pickerTarget(p)))
  for i, tab in ipairs(self.TABS) do
    ui.tabs[i]:SetText(L[TAB_LABEL[tab]])
    if tab == p.tab then ui.tabs[i]:LockHighlight() else ui.tabs[i]:UnlockHighlight() end
  end
  for i, e in ipairs(ui.entries) do
    local c = p.list[first + i]
    if c then
      e.text:SetText(c.label)
      e.icon:SetTexture(c.icon)
      if c.header then
        e.icon:Hide(); e.text:SetTextColor(1, 0.82, 0)
      else
        e.icon:Show(); e.text:SetTextColor(1, 1, 1)
      end
      if first + i == p.index then e.mark:Show() else e.mark:Hide() end
      e:Show()
    else
      e:Hide()
    end
  end
  ui.empty:SetText(#p.list == 0 and L.PADDLES_NOTHING or "")
  ui.page:SetText(L.PADDLES_PAGE:format(p.page, pages))
  if self.frame:GetHeight() < PICKER_HEIGHT then self.frame:SetHeight(PICKER_HEIGHT) end
  ui:Show()
end

function Window:OpenPicker(n, slot)
  if inCombat() then return end
  if not self.frame then self:Show() end
  self.picker = { n = n, slot = slot, tab = "spells", page = 1 }
  self:RenderPicker()
end

function Window:ClosePicker()
  self.picker = nil
  self:RenderPicker()
end

function Window:PickerSetTab(tab)
  if not self.picker then return end
  self.picker.tab, self.picker.page, self.picker.index = tab, 1, nil
  self:RenderPicker()
end

function Window:PickerTab(delta)
  if not self.picker then return end
  local i = 1
  for k, tab in ipairs(self.TABS) do if tab == self.picker.tab then i = k end end
  i = ((i - 1 + delta) % #self.TABS) + 1
  self:PickerSetTab(self.TABS[i])
end

function Window:PickerPage(delta)
  local p = self.picker
  if not p then return end
  p.page, p.index = (p.page or 1) + delta, nil
  self:RenderPicker()
end

-- moves the mark through the list, turning pages at the edges
function Window:PickerMove(delta)
  local p = self.picker
  if not (p and p.list and #p.list > 0) then return end
  local i = math.min(math.max((p.index or 1) + delta, 1), #p.list)
  while p.list[i] and p.list[i].header do
    local nxt = i + (delta < 0 and -1 or 1)
    if nxt < 1 or nxt > #p.list then i = p.index or i; break end
    i = nxt
  end
  p.index = i
  p.page = math.floor((p.index - 1) / PER_PAGE) + 1
  self:RenderPicker()
end

function Window:PickerChoose()
  local p = self.picker
  local c = p and p.list and p.list[p.index or 0]
  if not c or c.header or not c.action then return end
  self.picker = nil
  setAction(p.n, p.slot, c.action)
  self:RenderPicker()
end

function Window:PickerClear()
  local p = self.picker
  if not p then return end
  self.picker = nil
  setAction(p.n, p.slot, nil)
  self:RenderPicker()
end

local function buildPicker(frame)
  local ui = CreateFrame("Frame", nil, frame)
  ui:SetAllPoints()
  if ui.SetFrameLevel and frame.GetFrameLevel then ui:SetFrameLevel((frame:GetFrameLevel() or 1) + 20) end
  ui:EnableMouse(true)
  ui.bg = ui:CreateTexture(nil, "BACKGROUND")
  ui.bg:SetAllPoints()
  ui.bg:SetColorTexture(0.05, 0.05, 0.08, 1)
  ui.title = ui:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  ui.title:SetPoint("TOP", ui, "TOP", 0, -8)
  ui.tabs = {}
  for i, tab in ipairs(Window.TABS) do
    local t = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
    t:SetSize(110, 22)
    t:SetPoint("TOPLEFT", ui, "TOPLEFT", 12 + (i - 1) * 116, -28)
    t:SetScript("OnClick", function() Window:PickerSetTab(tab) end)
    ui.tabs[i] = t
  end
  ui.entries = {}
  for i = 1, PER_PAGE do
    local e = CreateFrame("Button", nil, ui)
    e:SetSize(520, 22)
    e:SetPoint("TOPLEFT", ui, "TOPLEFT", 16, -56 - (i - 1) * 24)
    e.mark = e:CreateTexture(nil, "BACKGROUND")
    e.mark:SetAllPoints()
    e.mark:SetColorTexture(1, 0.82, 0, 0.25)
    e.icon = e:CreateTexture(nil, "ARTWORK")
    e.icon:SetSize(20, 20)
    e.icon:SetPoint("LEFT", e, "LEFT", 0, 0)
    e.text = e:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    e.text:SetPoint("LEFT", e, "LEFT", 26, 0)
    e:SetScript("OnClick", function()
      local p = Window.picker
      if not p then return end
      p.index = (p.page - 1) * PER_PAGE + i
      Window:PickerChoose()
    end)
    ui.entries[i] = e
  end
  ui.empty = ui:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  ui.empty:SetPoint("TOPLEFT", ui, "TOPLEFT", 16, -60)
  ui.page = ui:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ui.page:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 16, 26)
  ui.hint = ui:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  ui.hint:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 16, 10)
  ui.hint:SetText(L.PADDLES_PICKER_HINT)
  ui.clear = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
  ui.clear:SetSize(90, 22)
  ui.clear:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -110, 8)
  ui.clear:SetText(L.PADDLES_CLEAR)
  ui.clear:SetScript("OnClick", function() Window:PickerClear() end)
  ui.back = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
  ui.back:SetSize(90, 22)
  ui.back:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -12, 8)
  ui.back:SetText(BACK or "Back")
  ui.back:SetScript("OnClick", function() Window:ClosePicker() end)
  ui:Hide()
  return ui
end

-------------------------------------------------------------------------------
-- Widgets
-------------------------------------------------------------------------------

local function slotButton(parent, n, slot)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(SLOT, SLOT)
  b.nnSlotOf, b.nnLayerSlot = n, slot
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local function receive()
    if inCombat() then return end
    local action = cursorAction()
    if action then
      if ClearCursor then ClearCursor() end
      setAction(n, slot, action)
      return true
    end
  end
  b:SetScript("OnReceiveDrag", receive)
  b:SetScript("OnClick", function() if not receive() then Window:OpenPicker(n, slot) end end)
  b:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local name = P():Describe(currentAction(n, slot))
    GameTooltip:SetText(name or L.PADDLES_EMPTY)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  return b
end

local function showAction(b, text, action)
  local name, icon, missing = P():Describe(action)
  if not action or not action.kind then
    b.icon:SetTexture(EMPTY_ICON); b.icon:SetDesaturated(true)
    if text then text:SetText(L.PADDLES_EMPTY) end
    return
  end
  if action.kind == "layer" then name = L.PADDLES_LAYER end
  if action.kind == "command" then icon = COMMAND_ICON end
  b.icon:SetTexture(icon or EMPTY_ICON)
  local absent = missing or (action.kind == "item" and (NN.Plain(GetItemCount and GetItemCount(action.value)) or 0) == 0)
  b.icon:SetDesaturated(absent and true or false)
  if text then text:SetText(missing and L.PADDLES_MISSING:format(name) or name) end
end

local function buildRow(frame, n)
  local r = { layer = {}, layerLabels = {} }
  r.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  r.title:SetText(L.PADDLES_ROW:format(n))
  r.key = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  r.learn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  r.learn:SetSize(80, 22)
  r.learn:SetText(L.PADDLES_LEARN)
  r.learn:SetScript("OnClick", function()
    frame.status:SetText(L.PADDLES_PRESS)
    Window:TakePad(false)
    P():StartLearning(n, function(key, reason)
      if frame:IsVisible() and not inCombat() and not P():IsLearning() then Window:TakePad(true) end
      if reason == "refused" then frame.status:SetText(L.PADDLES_REFUSED)
      elseif reason == "combat" then frame.status:SetText(L.PADDLES_COMBAT)
      elseif reason == "cancel" then frame.status:SetText(L.PADDLES_CANCELLED)
      else frame.status:SetText("") end
      Window:Refresh()
    end)
    -- a learn cancelled by this click may have taken the pad back
    Window:TakePad(false)
  end)
  r.slot = slotButton(frame, n, nil)
  r.action = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.replaces = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  for _, slot in ipairs(P().LAYER_SLOTS) do
    r.layer[slot] = slotButton(frame, n, slot)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetText(slotLabel(slot))
    r.layerLabels[slot] = label
  end
  return r
end

local function build()
  local frame = CreateFrame("Frame", "NewbieNudgePaddles", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  frame:SetSize(560, 300)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  frame:SetScript("OnShow", function()
    if not inCombat() and not P():IsLearning() then Window:TakePad(true) end
  end)
  frame:SetScript("OnHide", function()
    if P():IsLearning() then P():StopLearning() end
    Window:TakePad(false)
  end)
  frame.bg = frame:CreateTexture(nil, "BACKGROUND")
  frame.bg:SetAllPoints()
  frame.bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.title:SetPoint("TOP", frame, "TOP", 0, -8)
  frame.title:SetText(L.PADDLES_TITLE)
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  close:SetScript("OnClick", function() frame:Hide() end)

  frame.enable = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  frame.enable:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -26)
  frame.enable:SetScript("OnClick", function(self) P():SetEnabled(self:GetChecked()); Window:Refresh() end)
  frame.enableText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.enableText:SetPoint("LEFT", frame.enable, "RIGHT", 2, 0)
  frame.enableText:SetText(L.PADDLES_USE)

  frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.combat = frame:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
  frame.combat:SetText(L.PADDLES_COMBAT)
  frame.tip = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.tip:SetText(L.PADDLES_TIP)
  for _, fs in ipairs({ frame.status, frame.tip }) do
    if fs.SetWidth then fs:SetWidth(530) end
    if fs.SetJustifyH then fs:SetJustifyH("LEFT") end
  end
  for n = 1, P().MAX do Window.rows[n] = buildRow(frame, n) end
  frame.picker = buildPicker(frame)
  frame.focusMark = CreateFrame("Frame", nil, frame)
  if frame.focusMark.SetFrameLevel and frame.GetFrameLevel then frame.focusMark:SetFrameLevel((frame:GetFrameLevel() or 1) + 10) end
  frame.focusMark.tex = frame.focusMark:CreateTexture(nil, "OVERLAY")
  frame.focusMark.tex:SetAllPoints()
  frame.focusMark.tex:SetColorTexture(1, 0.82, 0, 0.35)
  frame.focusMark:Hide()
  frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.hint:SetText(L.PADDLES_WINDOW_HINT)
  frame:Hide()
  -- not in UISpecialFrames: the game's Esc menu reads that list, and the
  -- taint log showed addons there mixing into it (2026-11-23)
  return frame
end

-------------------------------------------------------------------------------
-- Controller: the window takes the pad buttons while it is open (out of
-- combat, not while learning) and gives them back when it closes
-------------------------------------------------------------------------------

-- Widgets in d-pad order: one list per line, built by Refresh.
function Window:Focused()
  local f = self.focus
  local line = f and self.grid and self.grid[f.r]
  return line and line[math.min(f.c, #line)]
end

local function showFocus()
  local frame, w = Window.frame, Window:Focused()
  if not (frame and frame.focusMark) then return end
  if not w or Window.picker then frame.focusMark:Hide(); return end
  frame.focusMark:ClearAllPoints()
  frame.focusMark:SetPoint("TOPLEFT", w, "TOPLEFT", -3, 3)
  frame.focusMark:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", 3, -3)
  frame.focusMark:Show()
end

local function moveFocus(dr, dc)
  local grid, f = Window.grid, Window.focus
  if not (grid and f) then return end
  f.r = math.min(math.max(f.r + dr, 1), #grid)
  f.c = math.min(math.max(math.min(f.c, #grid[f.r]) + dc, 1), #grid[f.r])
  showFocus()
end

local function activate(w)
  if not w then return end
  if w.nnSlotOf then Window:OpenPicker(w.nnSlotOf, w.nnLayerSlot)
  elseif w.GetScript and w:GetScript("OnClick") then
    if w.GetChecked and w.SetChecked then w:SetChecked(not w:GetChecked()) end
    w:GetScript("OnClick")(w)
  end
end

local function clearFocused(w)
  if w and w.nnSlotOf then setAction(w.nnSlotOf, w.nnLayerSlot, nil) end
end

local onPad
local function takePad(on)
  local frame = Window.frame
  if not frame then return end
  frame:SetScript("OnGamePadButtonDown", on and onPad or nil)
  if frame.EnableGamePadButton then frame:EnableGamePadButton(on and true or false) end
  if on and frame.SetPropagateGamePadInput then frame:SetPropagateGamePadInput(false) end
end
Window.TakePad = function(_, on) takePad(on) end

onPad = function(_, button)
  if P():IsLearning() then return end
  if Window.picker then
    if button == "PADDUP" then Window:PickerMove(-1)
    elseif button == "PADDDOWN" then Window:PickerMove(1)
    elseif button == "PADDLEFT" then Window:PickerPage(-1)
    elseif button == "PADDRIGHT" then Window:PickerPage(1)
    elseif button == "PADLSHOULDER" then Window:PickerTab(-1)
    elseif button == "PADRSHOULDER" then Window:PickerTab(1)
    elseif button == "PAD1" then Window:PickerChoose()
    elseif button == "PAD3" then Window:PickerClear()
    elseif button == "PAD2" then Window:ClosePicker() end
    showFocus()
    return
  end
  if button == "PADDUP" then moveFocus(-1, 0)
  elseif button == "PADDDOWN" then moveFocus(1, 0)
  elseif button == "PADDLEFT" then moveFocus(0, -1)
  elseif button == "PADDRIGHT" then moveFocus(0, 1)
  elseif button == "PAD1" then activate(Window:Focused())
  elseif button == "PAD3" then clearFocused(Window:Focused())
  elseif button == "PAD2" then Window:Hide() end
end

-------------------------------------------------------------------------------
-- Layout and state
-------------------------------------------------------------------------------

local function place(region, x, y)
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", Window.frame, "TOPLEFT", x, y)
end

function Window:Refresh()
  local frame = self.frame
  if not frame then return end
  local locked = inCombat() and true or false
  frame.enable:SetChecked(P():IsEnabled())
  if locked then frame.enable:Disable() else frame.enable:Enable() end
  local y = -58
  local grid = { { frame.enable } }
  for n, r in ipairs(self.rows) do
    grid[#grid + 1] = { r.learn, r.slot }
    local entry = P():Get(n)
    place(r.title, 12, y - 6)
    r.key:SetText(entry.key or L.PADDLES_NOT_SET)
    place(r.key, 90, y - 6)
    place(r.learn, 170, y - 2)
    place(r.slot, 260, y)
    place(r.action, 296, y - 4)
    showAction(r.slot, r.action, entry.action)
    local bound = entry.key and GetBindingAction and NN.Plain(GetBindingAction(entry.key), "string")
    if bound and bound ~= "" then
      r.replaces:SetText(L.PADDLES_REPLACES:format(GetBindingName and NN.Plain(GetBindingName(bound), "string") or bound))
      r.replaces:Show()
    else
      r.replaces:SetText(""); r.replaces:Hide()
    end
    place(r.replaces, 296, y - 18)
    for _, b in ipairs({ r.learn, r.slot }) do if locked then b:Disable() else b:Enable() end end
    y = y - ROW_H
    local isLayer = entry.action and entry.action.kind == "layer"
    for i, slot in ipairs(P().LAYER_SLOTS) do
      local b, label = r.layer[slot], r.layerLabels[slot]
      if isLayer then
        local col, line = (i - 1) % 4, math.floor((i - 1) / 4)
        place(label, 30 + col * 130, y - line * ROW_H - 8)
        place(b, 100 + col * 130, y - line * ROW_H)
        showAction(b, nil, entry.layer and entry.layer[slot])
        if locked then b:Disable() else b:Enable() end
        b:Show(); label:Show()
      else
        b:Hide(); label:Hide()
      end
    end
    if isLayer then
      y = y - math.ceil(#P().LAYER_SLOTS / 4) * ROW_H
      for i, slot in ipairs(P().LAYER_SLOTS) do
        if (i - 1) % 4 == 0 then grid[#grid + 1] = {} end
        local cur = grid[#grid]
        cur[#cur + 1] = r.layer[slot]
      end
    end
  end
  place(frame.status, 12, y - 4)
  place(frame.combat, 12, y - 20)
  if locked then frame.combat:Show() else frame.combat:Hide() end
  place(frame.tip, 12, y - 36)
  place(frame.hint, 12, y - 66)
  frame:SetHeight(-y + 90)
  self.grid = grid
  self.focus = self.focus or { r = 2, c = 1 }
  self.focus.r = math.min(self.focus.r, #grid)
  showFocus()
end

function Window:Show()
  if not self.frame then self.frame = build() end
  self.frame:Show()
  self:Refresh()
  if not inCombat() and not P():IsLearning() then takePad(true) end
end

function Window:Hide() if self.frame then self.frame:Hide() end end

function Window:Toggle()
  if self.frame and self.frame:IsShown() then self:Hide() else self:Show() end
end

NN:OnAnyEvent(function(event)
  if event == "PLAYER_REGEN_DISABLED" then fighting = true; takePad(false) end
  if event == "PLAYER_REGEN_ENABLED" then
    fighting = false
    if Window.frame and Window.frame:IsVisible() and not P():IsLearning() then takePad(true) end
  end
  if (event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED") and Window.frame and Window.frame:IsShown() then
    Window:Refresh()
  end
end)
