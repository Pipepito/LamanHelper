-- NewbieNudge's settings window: every options page (Options.Model) in one
-- window that works with the pad alone as well as the mouse. The only place
-- NewbieNudge's settings live; nothing goes in the game's Settings window.
-- Opened from the game's Esc menu, /nudge, the minimap menu and a binding.
local _, NN = ...
local L = NN.L

local Win = { pages = {}, page = 1, sel = 1, offset = 0 }
NN.SettingsWindow = Win

local MARGIN = 22 -- clear of the DiamondMetal border
local LIST_W = 160
local ROWS_W = 470
local GAP = 14
local ROW_H = 26
local VISIBLE = 15
local HEAD_H = 56
local DESC_H = 44
local FOOT_H = 40
local CONTROL_X = 270 -- where a row's control starts
local CONTROL_W = ROWS_W - CONTROL_X
local BAR_GAP = 6 -- between the rows and the scroll bar
local BAR_W = 16
local ARROW_H = 16
local TRACK_H = VISIBLE * ROW_H - 2 * ARROW_H
local MIN_THUMB = 24
local WHEEL_ROWS = 3 -- rows per mouse wheel notch

-- PLAYER_REGEN_DISABLED fires before InCombatLockdown() turns true
local fighting = false
local function inCombat() return fighting or (InCombatLockdown and InCombatLockdown()) end

-------------------------------------------------------------------------------
-- Entries: reading and changing values
-------------------------------------------------------------------------------

local function selectable(e) return e and e.kind ~= "header" end

local function call(fn, ...)
  local ok, value = pcall(fn, ...)
  if ok then return value end
  return nil
end

local function formatNumber(value, step)
  if type(value) ~= "number" then return "?" end
  if step and step < 1 then
    local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
    return text
  end
  return tostring(math.floor(value + 0.5))
end

local function optionIndex(e)
  local current = call(e.get)
  for i, option in ipairs(e.options or {}) do
    if option.value == current then return i end
  end
  return 1
end

-- The text shown in a row's control column.
function Win.ValueText(e)
  if e.kind == "slider" then return formatNumber(call(e.get), e.step)
  elseif e.kind == "dropdown" then
    local option = e.options and e.options[optionIndex(e)]
    return option and option.label or ""
  elseif e.kind == "button" then return e.buttonText or ""
  end
  return ""
end

-- Left/right on a slider (one step) or a dropdown (next option, wrapping).
function Win.Step(e, dir)
  if e.kind == "slider" then
    local value = call(e.get) or e.min
    local step = e.step or 1
    local new = math.min(math.max(value + dir * step, e.min), e.max)
    -- snap to the step grid so float steps do not drift
    new = e.min + math.floor((new - e.min) / step + 0.5) * step
    if new ~= value then call(e.set, new) end
  elseif e.kind == "dropdown" and e.options and #e.options > 0 then
    local i = (optionIndex(e) - 1 + dir) % #e.options + 1
    call(e.set, e.options[i].value)
  elseif e.kind == "checkbox" then
    call(e.set, not call(e.get))
  end
end

-- A / left click.
function Win.Activate(e)
  if not selectable(e) then return end
  if e.kind == "checkbox" then call(e.set, not call(e.get))
  elseif e.kind == "button" then call(e.onClick)
  else Win.Step(e, 1) end
end

-------------------------------------------------------------------------------
-- Selection and scrolling
-------------------------------------------------------------------------------

function Win:Entries()
  local page = self.pages[self.page]
  return page and page.entries or {}
end

local function nextSelectable(entries, from, step)
  local i = from
  while entries[i] do
    if selectable(entries[i]) then return i end
    i = i + step
  end
  return nil
end

function Win:KeepVisible()
  local entries = self:Entries()
  -- show the header above the first line too
  local top = self.sel
  if entries[top - 1] and entries[top - 1].kind == "header" then top = top - 1 end
  if top <= self.offset then self.offset = top - 1 end
  if self.sel > self.offset + VISIBLE then self.offset = self.sel - VISIBLE end
  self.offset = math.max(0, math.min(self.offset, math.max(0, #entries - VISIBLE)))
end

function Win:Move(step)
  local i = nextSelectable(self:Entries(), self.sel + step, step)
  if i then self.sel = i; self:KeepVisible(); self:Render() end
end

-- Scrolls the rows without moving the selection (mouse wheel, scroll bar).
function Win:MaxOffset() return math.max(0, #self:Entries() - VISIBLE) end

function Win:ScrollTo(offset)
  offset = math.max(0, math.min(math.floor(offset + 0.5), self:MaxOffset()))
  if offset ~= self.offset then self.offset = offset; self:Render() end
end

function Win:Scroll(rows) self:ScrollTo(self.offset + rows) end

-- The thumb's size and distance from the top of the track, in pixels.
function Win:ThumbLayout()
  local total, max = #self:Entries(), self:MaxOffset()
  if max == 0 then return TRACK_H, 0 end
  local h = math.max(MIN_THUMB, math.floor(TRACK_H * VISIBLE / total))
  return h, (TRACK_H - h) * self.offset / max
end

-- Dragging the thumb dy pixels down from where the drag started.
function Win:DragTo(startOffset, dy)
  local h = self:ThumbLayout()
  local room = TRACK_H - h
  if room <= 0 then return end
  self:ScrollTo(startOffset + dy / room * self:MaxOffset())
end

function Win:SetPage(n)
  if #self.pages == 0 then return end
  self.page = (n - 1) % #self.pages + 1
  self.sel = nextSelectable(self:Entries(), 1, 1) or 1
  self.offset = 0
  self:KeepVisible()
  self:Render()
end

function Win:Selected() return self:Entries()[self.sel] end

function Win:Change(dir)
  local e = self:Selected()
  if selectable(e) and e.kind ~= "button" then Win.Step(e, dir); self:Render() end
end

function Win:Press()
  Win.Activate(self:Selected())
  self:Render()
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------

local function textButton(parent, w, h, text)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w, h)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  b.text:SetPoint("CENTER")
  b.text:SetText(text)
  return b
end

local function buildRow(frame, i)
  local r = CreateFrame("Button", nil, frame)
  r:SetSize(ROWS_W, ROW_H - 2)
  r:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN + LIST_W + GAP, -HEAD_H - (i - 1) * ROW_H)
  r.hl = r:CreateTexture(nil, "BACKGROUND")
  r.hl:SetAllPoints()
  r.hl:SetColorTexture(1, 0.82, 0, 0.22)
  r.hl:Hide()
  r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  r.label:SetPoint("LEFT", r, "LEFT", 6, 0)
  r.label:SetWidth(CONTROL_X - 12)
  if r.label.SetJustifyH then r.label:SetJustifyH("LEFT") end
  if r.label.SetWordWrap then r.label:SetWordWrap(false) end
  -- checkbox
  r.box = r:CreateTexture(nil, "ARTWORK")
  r.box:SetSize(24, 24)
  r.box:SetPoint("LEFT", r, "LEFT", CONTROL_X, 0)
  r.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
  r.check = r:CreateTexture(nil, "OVERLAY")
  r.check:SetAllPoints(r.box)
  r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  -- slider / dropdown: < value >
  r.left = textButton(r, 22, ROW_H - 2, "<")
  r.left:SetPoint("LEFT", r, "LEFT", CONTROL_X, 0)
  r.right = textButton(r, 22, ROW_H - 2, ">")
  r.right:SetPoint("RIGHT", r, "RIGHT", -4, 0)
  r.value = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  r.value:SetPoint("LEFT", r.left, "RIGHT", 2, 0)
  r.value:SetPoint("RIGHT", r.right, "LEFT", -2, 0)
  if r.value.SetJustifyH then r.value:SetJustifyH("CENTER") end
  -- button
  r.button = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
  r.button:SetSize(CONTROL_W - 8, ROW_H - 4)
  r.button:SetPoint("LEFT", r, "LEFT", CONTROL_X, 0)

  local function pick() if r.index then Win.sel = r.index end end
  r:SetScript("OnClick", function() pick(); Win:Press() end)
  -- hovering a row shows its help, like selecting it does
  r:SetScript("OnEnter", function()
    if r.entry and Win.frame then Win.frame.desc:SetText(r.entry.tooltip or "") end
  end)
  r:SetScript("OnLeave", function()
    local e = Win:Selected()
    if Win.frame then Win.frame.desc:SetText(e and e.tooltip or "") end
  end)
  r.button:SetScript("OnClick", function() pick(); Win:Press() end)
  r.left:SetScript("OnClick", function() pick(); Win:Change(-1) end)
  r.right:SetScript("OnClick", function() pick(); Win:Change(1) end)
  return r
end

local function buildTab(frame, i)
  local t = CreateFrame("Button", nil, frame)
  t:SetSize(LIST_W, ROW_H - 2)
  t:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -HEAD_H - (i - 1) * ROW_H)
  t.hl = t:CreateTexture(nil, "BACKGROUND")
  t.hl:SetAllPoints()
  t.hl:SetColorTexture(1, 0.82, 0, 0.3)
  t.text = t:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  t.text:SetPoint("LEFT", t, "LEFT", 8, 0)
  t.text:SetPoint("RIGHT", t, "RIGHT", -4, 0)
  if t.text.SetJustifyH then t.text:SetJustifyH("LEFT") end
  t:SetScript("OnClick", function() Win:SetPage(i) end)
  return t
end

local function cursorY(frame)
  local _, y = GetCursorPosition()
  return y / ((frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1)
end

-- A plain scroll bar to the right of the rows: arrows, a track to click for
-- a page, and a thumb to drag. Hidden when the page fits.
local function buildScrollBar(frame)
  local x = MARGIN + LIST_W + GAP + ROWS_W + BAR_GAP
  local bar = CreateFrame("Frame", nil, frame)
  bar:SetSize(BAR_W, VISIBLE * ROW_H)
  bar:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -HEAD_H)

  local function arrow(dir)
    local b = CreateFrame("Button", nil, bar)
    b:SetSize(BAR_W, ARROW_H)
    local name = dir < 0 and "Up" or "Down"
    local base = "Interface\\Buttons\\UI-ScrollBar-Scroll" .. name .. "Button-"
    b:SetNormalTexture(base .. "Up")
    b:SetPushedTexture(base .. "Down")
    b:SetHighlightTexture(base .. "Highlight")
    b:SetScript("OnClick", function() Win:Scroll(dir) end)
    return b
  end
  bar.up = arrow(-1)
  bar.up:SetPoint("TOP", bar, "TOP", 0, 0)
  bar.down = arrow(1)
  bar.down:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)

  bar.track = CreateFrame("Button", nil, bar)
  bar.track:SetSize(BAR_W, TRACK_H)
  bar.track:SetPoint("TOP", bar, "TOP", 0, -ARROW_H)
  bar.track.bg = bar.track:CreateTexture(nil, "BACKGROUND")
  bar.track.bg:SetAllPoints()
  bar.track.bg:SetColorTexture(0, 0, 0, 0.45)
  -- a click above or below the thumb moves one page
  bar.track:SetScript("OnClick", function(self)
    local top = self.GetTop and self:GetTop()
    if not top then return end
    local h, y = Win:ThumbLayout()
    local below = top - cursorY(self)
    if below < y then Win:Scroll(-(VISIBLE - 1)) elseif below > y + h then Win:Scroll(VISIBLE - 1) end
  end)

  bar.thumb = CreateFrame("Button", nil, bar)
  bar.thumb:SetWidth(BAR_W - 2)
  bar.thumb.tex = bar.thumb:CreateTexture(nil, "ARTWORK")
  bar.thumb.tex:SetAllPoints()
  bar.thumb.tex:SetColorTexture(1, 0.82, 0, 0.55)
  bar.thumb:SetScript("OnMouseDown", function(self)
    self.dragFrom, self.dragOffset = cursorY(self), Win.offset
    self:SetScript("OnUpdate", function(t)
      Win:DragTo(t.dragOffset, t.dragFrom - cursorY(t))
    end)
  end)
  bar.thumb:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
  bar.thumb:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
  return bar
end

local onPad
local function takePad(on)
  local frame = Win.frame
  if not frame then return end
  frame:SetScript("OnGamePadButtonDown", on and onPad or nil)
  if frame.EnableGamePadButton then frame:EnableGamePadButton(on and true or false) end
  if on and frame.SetPropagateGamePadInput then frame:SetPropagateGamePadInput(false) end
end

onPad = function(_, button)
  if button == "PADDUP" then Win:Move(-1)
  elseif button == "PADDDOWN" then Win:Move(1)
  elseif button == "PADDLEFT" then Win:Change(-1)
  elseif button == "PADDRIGHT" then Win:Change(1)
  elseif button == "PADLSHOULDER" then Win:SetPage(Win.page - 1)
  elseif button == "PADRSHOULDER" then Win:SetPage(Win.page + 1)
  elseif button == "PAD1" then Win:Press()
  elseif button == "PAD2" then Win:Hide() end
end

local function build()
  local PadUI = NN.PadUI or {}
  local frame = CreateFrame("Frame", "NewbieNudgeSettings", UIParent)
  frame:SetSize(MARGIN * 2 + LIST_W + GAP + ROWS_W + BAR_GAP + BAR_W, HEAD_H + VISIBLE * ROW_H + DESC_H + FOOT_H)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  frame:SetScript("OnShow", function() if not inCombat() then takePad(true) end end)
  frame:SetScript("OnHide", function() takePad(false) end)
  if frame.EnableMouseWheel then frame:EnableMouseWheel(true) end
  -- the wheel scrolls the list, like any other list; the pad moves the selection
  frame:SetScript("OnMouseWheel", function(_, delta) Win:Scroll(delta > 0 and -WHEEL_ROWS or WHEEL_ROWS) end)
  frame.bg = frame:CreateTexture(nil, "BACKGROUND")
  frame.bg:SetAllPoints()
  frame.bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOP", frame, "TOP", 0, -12)
  frame.title:SetText(L.SETWIN_TITLE)
  if PadUI.StyleFrame then PadUI.StyleFrame(frame) end
  if PadUI.TitleLine then PadUI.TitleLine(frame, frame.title) end
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -3, -3)
  close:SetScript("OnClick", function() frame:Hide() end)

  frame.divider = frame:CreateTexture(nil, "ARTWORK")
  frame.divider:SetColorTexture(1, 0.82, 0, 0.35)
  frame.divider:SetSize(1, VISIBLE * ROW_H)
  frame.divider:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN + LIST_W + GAP / 2, -HEAD_H)

  frame.tabs, frame.rows = {}, {}
  for i = 1, VISIBLE do frame.rows[i] = buildRow(frame, i) end
  frame.bar = buildScrollBar(frame)
  frame.scroll = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.scroll:SetPoint("TOPRIGHT", frame, "TOPLEFT", MARGIN + LIST_W + GAP + ROWS_W, -HEAD_H - VISIBLE * ROW_H - 2)

  frame.desc = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.desc:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -HEAD_H - VISIBLE * ROW_H - 16)
  frame.desc:SetWidth(LIST_W + GAP + ROWS_W)
  if frame.desc.SetJustifyH then frame.desc:SetJustifyH("LEFT") end
  if frame.desc.SetJustifyV then frame.desc:SetJustifyV("TOP") end
  if frame.desc.SetHeight then frame.desc:SetHeight(DESC_H - 14) end

  local padName = PadUI.PadName or function(t) return t end
  if NN.PaddlesWindow and NN.PaddlesWindow.Legend then
    frame.legend = NN.PaddlesWindow.Legend(frame, {
      { L.PADDLES_DPAD, L.SETWIN_KEY_MOVE, "PADDUP" }, { padName("PAD1"), L.PADDLES_KEY_SELECT, "PAD1" },
      { "LB/RB", L.SETWIN_KEY_PAGES, "PADLSHOULDER" }, { padName("PAD2"), L.PADDLES_KEY_CLOSE, "PAD2" },
    })
    frame.legend:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", MARGIN, 16)
  end
  frame:Hide()
  -- not in UISpecialFrames: the game's Esc menu reads that list, and the
  -- taint log showed addons there mixing into it (2026-11-23)
  return frame
end

local function showControl(r, e)
  r.box:Hide(); r.check:Hide(); r.left:Hide(); r.right:Hide(); r.value:Hide(); r.button:Hide()
  if e.kind == "checkbox" then
    r.box:Show()
    if call(e.get) then r.check:Show() end
  elseif e.kind == "slider" or e.kind == "dropdown" then
    r.left:Show(); r.right:Show(); r.value:Show()
    r.value:SetText(Win.ValueText(e))
  elseif e.kind == "button" then
    r.button:Show()
    r.button:SetText(Win.ValueText(e))
  end
end

function Win:Render()
  local frame = self.frame
  if not frame then return end
  for i, page in ipairs(self.pages) do
    local t = frame.tabs[i]
    if not t then t = buildTab(frame, i); frame.tabs[i] = t end
    t.text:SetText(page.title)
    t:Show()
    if i == self.page then t.hl:Show() else t.hl:Hide() end
  end
  for i = #self.pages + 1, #frame.tabs do frame.tabs[i]:Hide() end

  local entries = self:Entries()
  for i, r in ipairs(frame.rows) do
    local index = self.offset + i
    local e = entries[index]
    r.index, r.entry = e and index or nil, e
    if not e then
      r:Hide()
    else
      r:Show()
      r.label:SetText(e.label or "")
      if r.label.SetFontObject then r.label:SetFontObject(e.kind == "header" and "GameFontNormal" or "GameFontHighlight") end
      if e.kind == "header" then
        r.box:Hide(); r.check:Hide(); r.left:Hide(); r.right:Hide(); r.value:Hide(); r.button:Hide()
      else
        showControl(r, e)
      end
      if index == self.sel and selectable(e) then r.hl:Show() else r.hl:Hide() end
    end
  end
  local more = #entries > VISIBLE
  frame.scroll:SetText(more and L.SETWIN_SCROLL:format(self.offset + 1, math.min(self.offset + VISIBLE, #entries), #entries) or "")
  local bar = frame.bar
  if bar then
    bar:SetShown(more)
    if more then
      local h, y = self:ThumbLayout()
      bar.thumb:SetHeight(h)
      bar.thumb:ClearAllPoints()
      bar.thumb:SetPoint("TOP", bar.track, "TOP", 0, -y)
    end
  end
  local e = self:Selected()
  frame.desc:SetText(e and e.tooltip or "")
end

function Win:Show(pageTitle)
  if not self.frame then self.frame = build() end
  self.pages = NN.Options and NN.Options.Model and NN.Options.Model() or {}
  local start = 1
  for i, page in ipairs(self.pages) do if page.title == pageTitle then start = i end end
  self.frame:Show()
  self:SetPage(start)
end

function Win:Hide() if self.frame then self.frame:Hide() end end

function Win:Toggle()
  if self.frame and self.frame:IsShown() then self:Hide() else self:Show() end
end

NN:OnAnyEvent(function(event)
  if event == "PLAYER_REGEN_DISABLED" then fighting = true; takePad(false) end
  if event == "PLAYER_REGEN_ENABLED" then
    fighting = false
    if Win.frame and Win.frame:IsVisible() then takePad(true) end
  end
end)

-------------------------------------------------------------------------------
-- The game's Esc menu: a "NewbieNudge" button above AddOns
-------------------------------------------------------------------------------

-- Same approach as other addons on Forever: the menu builds its buttons from
-- a list (InitButtons/AddButton) on every OnShow/OnEvent, so the button is
-- added again after each through HookScript. No protected calls, and none of
-- the game's methods are replaced.
-- Closes the game menu. HideUIPanel can leave it open (the menu's own click
-- handling runs around our callback), so it is hidden directly when needed,
-- now and again on the next frame.
local function closeGameMenu()
  local menu = GameMenuFrame
  if not menu or not menu:IsShown() then return end
  if HideUIPanel then pcall(HideUIPanel, menu) end
  if menu:IsShown() then menu:Hide() end
end
Win.CloseGameMenu = closeGameMenu

local function addToGameMenu(menu)
  local b = menu:AddButton(L.ADDON_TITLE, function()
    closeGameMenu()
    Win:Show()
    if C_Timer and C_Timer.After then C_Timer.After(0, closeGameMenu) end
  end)
  if type(b) ~= "table" or type(menu.buttonPool) ~= "table" then return end
  for other in menu.buttonPool:EnumerateActive() do
    if other ~= b and other.GetText and other:GetText() == ADDONS and type(other.layoutIndex) == "number" then
      -- right above AddOns; another addon's button that took the section's
      -- gap (layoutIndex - 0.5) stays first
      b.layoutIndex = other.layoutIndex - 0.4
      if other.topPadding then b.topPadding, other.topPadding = other.topPadding, nil end
    end
  end
  if menu.MarkDirty then menu:MarkDirty() end
end
Win.AddToGameMenu = addToGameMenu

NN:AfterLogin(function()
  if type(GameMenuFrame) ~= "table" or type(rawget(GameMenuFrame, "AddButton")) ~= "function" then return end
  local function after(menu)
    local ok, err = pcall(addToGameMenu, menu)
    if not ok and NN.db then NN.db.errors["gamemenu"] = tostring(err) end
  end
  GameMenuFrame:HookScript("OnShow", after)
  GameMenuFrame:HookScript("OnEvent", after)
end)
