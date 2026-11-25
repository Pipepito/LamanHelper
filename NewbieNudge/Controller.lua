-- Controller: the addon's own behaviour when a controller is in use (scale
-- boost, button hints, bindable actions). The game's controller settings are
-- read for the hints and left to the game's own options to change.
local _, NN = ...
local L = NN.L

-------------------------------------------------------------------------------
-- Pad buttons
-------------------------------------------------------------------------------

-- The client's GetBindingText returns a font glyph for pad buttons, unusable
-- as a label, so the addon carries its own short Xbox-style names.
local PAD_BUTTONS = {
  "none", "PADLTRIGGER", "PADRTRIGGER", "PADLSHOULDER", "PADRSHOULDER", "PADLSTICK", "PADRSTICK",
  "PADBACK", "PADFORWARD", "PADSYSTEM", "PADSOCIAL", "PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4",
  "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
}
local PAD_NAMES = {
  PADLTRIGGER = "LT", PADRTRIGGER = "RT", PADLSHOULDER = "LB", PADRSHOULDER = "RB",
  PADLSTICK = "LS", PADRSTICK = "RS", PADBACK = "Back", PADFORWARD = "Start", PADSYSTEM = "Guide", PADSOCIAL = "Share",
  PADPADDLE1 = "Paddle 1", PADPADDLE2 = "Paddle 2", PADPADDLE3 = "Paddle 3", PADPADDLE4 = "Paddle 4",
  PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y", PAD5 = "Pad 5", PAD6 = "Pad 6",
  PADDUP = "D-pad up", PADDDOWN = "D-pad down", PADDLEFT = "D-pad left", PADDRIGHT = "D-pad right",
}

local function padLabel(token)
  if token == nil or token == "" or token == "none" then return L.PAD_NONE end
  return PAD_NAMES[token] or token
end

-- Reads the game's controller settings (button hints) but never writes them:
-- on WoW Forever, changing them from the addon's Settings page tainted the
-- gamepad interface and the game blocked its actions (taint log, 2026-11-23).
local Controller = NN.CVarSection.New({ curated = {}, match = function() return false end })
NN.Controller = Controller
Controller.PAD_BUTTONS = PAD_BUTTONS
Controller.PAD_NAMES = PAD_NAMES
Controller.PadLabel = function(_, token) return padLabel(token) end
Controller.session = false

-------------------------------------------------------------------------------
-- The addon when a controller is in use
-------------------------------------------------------------------------------

-- Sticky for the session: on the Deck the trackpad flips the active input to
-- the mouse constantly, and the panel must not resize every few seconds.
function Controller:SetSession(on)
  if not on or self.session then return end
  self.session = true
  if NN.Panel then
    NN.Panel:ApplyScale()
    NN.Panel:Refresh(NN:ActiveRows())
  end
  if NN.BagFull and NN.BagFull.ApplyScale then NN.BagFull:ApplyScale() end
end

-- True when the game's controller mode is on (Options > Controller > Enable
-- Controller). The Back buttons window is only offered then.
function Controller:ModeOn()
  if C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled() == true then return true end
  return self:GetString("GamePadEnable") == "1"
end

function Controller:Boost()
  return self.session == true and NN.db ~= nil and NN.db.controller.boost == true
end

-- Labels for the pad buttons that click, right-click and act as Shift, or nil
-- when no controller is in use or hints are off.
function Controller:HintButtons()
  if not self.session or not (NN.db and NN.db.controller.hints) then return nil end
  local left = self:GetString("GamePadCursorLeftClick")
  local right = self:GetString("GamePadCursorRightClick")
  local shift = self:GetString("GamePadEmulateShift")
  return padLabel(left or "PADRTRIGGER"), padLabel(right or "PADRSHOULDER"), padLabel(shift or "PADLTRIGGER")
end

NN:RegisterEvent("GAME_PAD_ACTIVE_CHANGED")
NN:RegisterEvent("GAME_PAD_CONNECTED")
NN:OnAnyEvent(function(event, arg1)
  if event == "GAME_PAD_ACTIVE_CHANGED" and arg1 == true then Controller:SetSession(true) end
end)

NN:AfterLogin(function()
  if C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled() == true and Controller:GetString("GamePadEnable") == "1" then
    local id = C_GamePad.GetActiveDeviceID and NN.Plain(C_GamePad.GetActiveDeviceID())
    if id and id ~= 0 then Controller:SetSession(true) end
  end
end)

-- Bindable actions (Bindings.xml); the game's own key-binding window lets
-- players put them on pad combinations.
BINDING_HEADER_NEWBIENUDGE = L.BINDING_HEADER
BINDING_NAME_NEWBIENUDGE_TOGGLE = L.BINDING_TOGGLE
BINDING_NAME_NEWBIENUDGE_OPEN_TOP = L.BINDING_OPEN_TOP
BINDING_NAME_NEWBIENUDGE_SNOOZE_TOP = L.BINDING_SNOOZE_TOP
BINDING_NAME_NEWBIENUDGE_OPTIONS = L.BINDING_OPTIONS
BINDING_NAME_NEWBIENUDGE_PADDLES = L.BINDING_PADDLES

function Controller:AddPanelOptions(category, layout)
  local Options = NN.Options
  Options.AddHeader(layout, L.OPT_CONTROLLER_PANEL)
  Options.AddCheckbox(category, "NN_controller_boost", L.OPT_CONTROLLER_BOOST, L.OPT_CONTROLLER_BOOST_TT,
    function() return NN.db.controller.boost end,
    function(value)
      NN.db.controller.boost = value and true or false
      if NN.Panel then NN.Panel:ApplyScale(); NN.Panel:Refresh(NN:ActiveRows()) end
      if NN.BagFull and NN.BagFull.ApplyScale then NN.BagFull:ApplyScale() end
    end)
  Options.AddSlider(category, "NN_controller_scale", L.OPT_CONTROLLER_SCALE, nil, 1.0, 1.6, 0.05,
    function() return NN.db.controller.scale end,
    function(value)
      NN.db.controller.scale = value
      if NN.Panel then NN.Panel:ApplyScale() end
      if NN.BagFull and NN.BagFull.ApplyScale then NN.BagFull:ApplyScale() end
    end)
  Options.AddCheckbox(category, "NN_controller_hints", L.OPT_CONTROLLER_HINTS, nil,
    function() return NN.db.controller.hints end,
    function(value) NN.db.controller.hints = value and true or false end)
end

-------------------------------------------------------------------------------
-- Options page (only when the client has gamepad support)
-------------------------------------------------------------------------------

if C_GamePad then
  NN.Options.RegisterPage("controller", "OPT_CONTROLLER", function(category, layout)
    local Options = NN.Options
    if Controller.AddPanelOptions then Controller:AddPanelOptions(category, layout) end
    -- the paddle editor is NewbieNudge's own window; this button only shows
    -- it and writes no setting (the Options window's commit tainted the
    -- controller interface when settings were written from it). With
    -- controller mode off, Show says so in chat instead of opening.
    Options.AddButton(layout, L.OPT_CONTROLLER_PADDLES, L.MENU_PADDLES, function()
      if NN.PaddlesWindow then NN.PaddlesWindow:Show() end
    end)
  end)
end
