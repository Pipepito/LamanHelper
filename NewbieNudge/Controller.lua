-- Controller: the gamepad console variables Blizzard's settings hide, with
-- one-click presets for the Steam Deck and for a plain controller, and the
-- addon's own behaviour when a controller is in use (scale boost, button
-- hints, bindable actions). Built on CVarSection.
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

local function padOptions()
  local options = {}
  for _, token in ipairs(PAD_BUTTONS) do options[#options + 1] = { token, padLabel(token), rawLabel = true } end
  return options
end

-------------------------------------------------------------------------------
-- Curated list
-------------------------------------------------------------------------------

local TURN = { { "0", "CTRL_OPT_NEVER" }, { "1", "CTRL_OPT_IN_COMBAT" }, { "2", "CTRL_OPT_ALWAYS" } }
local STICKS = { { "0", "CTRL_OPT_STICKS_NONE" }, { "1", "CTRL_OPT_STICKS_MOVEMENT" }, { "2", "CTRL_OPT_STICKS_BOTH" } }
local SOFT = { { "0", "CTRL_OPT_SOFT_OFF" }, { "1", "CTRL_OPT_SOFT_GAMEPAD" }, { "2", "CTRL_OPT_SOFT_KBM" }, { "3", "CTRL_OPT_SOFT_ALWAYS" } }
local ARC = { { "0", "CTRL_OPT_ARC_FRONT" }, { "1", "CTRL_OPT_ARC_FRONTARC" }, { "2", "CTRL_OPT_ARC_ANY" } }

local function cb(cvar) return { cvar = cvar, kind = "checkbox", label = "CTRL_" .. cvar, help = "CTRL_" .. cvar .. "_TT" } end
local function sl(cvar, min, max, step) return { cvar = cvar, kind = "slider", min = min, max = max, step = step, label = "CTRL_" .. cvar, help = "CTRL_" .. cvar .. "_TT" } end
local function dd(cvar, options) return { cvar = cvar, kind = "dropdown", options = options, label = "CTRL_" .. cvar, help = "CTRL_" .. cvar .. "_TT" } end
local function pb(cvar) return { cvar = cvar, kind = "padbutton", label = "CTRL_" .. cvar, help = "CTRL_" .. cvar .. "_TT" } end

local CURATED = {
  cb("GamePadEnable"),
  { header = "CTRL_GROUP_CAMERA" },
  sl("GamePadCameraYawSpeed", 0.25, 4, 0.25),
  sl("GamePadCameraPitchSpeed", 0.25, 4, 0.25),
  dd("GamePadTurnWithCamera", TURN),
  { header = "CTRL_GROUP_MOVEMENT" },
  sl("GamePadFaceMovementMaxAngle", 0, 180, 5),
  sl("GamePadFaceMovementMaxAngleCombat", 0, 180, 5),
  cb("GamePadAnalogMovement"),
  sl("GamePadRunThreshold", 0, 1, 0.05),
  { header = "CTRL_GROUP_CURSOR" },
  cb("GamePadCursorAutoEnable"),
  cb("GamePadCursorCentering"),
  cb("GamePadCursorCenteredEmulation"),
  cb("GamePadCursorAutoDisableJump"),
  dd("GamePadCursorAutoDisableSticks", STICKS),
  sl("GamePadCursorSpeedStart", 0.05, 1, 0.05),
  sl("GamePadCursorSpeedAccel", 0, 5, 0.25),
  sl("GamePadCursorSpeedMax", 0.25, 3, 0.25),
  cb("GamePadTouchCursorEnable"),
  sl("GamePadOverlapMouseMs", 0, 5000, 250),
  { header = "CTRL_GROUP_BUTTONS" },
  pb("GamePadCursorLeftClick"),
  pb("GamePadCursorRightClick"),
  pb("GamePadEmulateShift"),
  pb("GamePadEmulateCtrl"),
  pb("GamePadEmulateAlt"),
  pb("GamePadEmulateEsc"),
  sl("GamePadEmulateTapWindowMs", 100, 1000, 50),
  sl("GamePadVibrationStrength", 0, 2, 0.1),
  { header = "CTRL_GROUP_TARGETING" },
  dd("SoftTargetInteract", SOFT),
  dd("SoftTargetEnemy", SOFT),
  dd("SoftTargetFriend", SOFT),
  sl("SoftTargetInteractRange", 5, 30, 1),
  dd("SoftTargetEnemyArc", ARC),
  cb("SoftTargetIconInteract"),
  cb("SoftTargetIconEnemy"),
  cb("SoftTargetIconGameObject"),
  cb("SoftTargetNameplateEnemy"),
  sl("SoftTargetNameplateSize", 10, 40, 1),
}

-- padbutton entries become dropdowns over the pad button list at build time.
local function expanded(list)
  local out = {}
  for i, entry in ipairs(list) do
    if entry.kind == "padbutton" then
      out[i] = { cvar = entry.cvar, kind = "dropdown", options = padOptions(), label = entry.label, help = entry.help }
    else
      out[i] = entry
    end
  end
  return out
end

local Controller = NN.CVarSection.New({
  curated = CURATED,
  match = function(name) return name:sub(1, 7) == "GamePad" or name:sub(1, 10) == "SoftTarget" end,
  note = "OPT_CONTROLLER_NOTE",
  otherHeader = "OPT_CONTROLLER_OTHER",
  resetLabel = "OPT_CONTROLLER_RESET",
})
NN.Controller = Controller
Controller.PAD_BUTTONS = PAD_BUTTONS
Controller.PAD_NAMES = PAD_NAMES
Controller.PadLabel = function(_, token) return padLabel(token) end
Controller.PadOptions = padOptions
Controller.session = false

-- Draft values, confirmed in game (docs/testing-checklist.md §0). Presets
-- never touch the modifier or click buttons.
Controller.PRESETS = {
  deck = {
    GamePadEnable = 1, GamePadTouchCursorEnable = 1, GamePadOverlapMouseMs = 500, GamePadCursorCentering = 0,
    GamePadTurnWithCamera = 2, GamePadFaceMovementMaxAngle = 115, GamePadFaceMovementMaxAngleCombat = 115,
    GamePadAnalogMovement = 1, SoftTargetInteract = 1, SoftTargetIconInteract = 1, SoftTargetIconEnemy = 1,
    SoftTargetNameplateEnemy = 1,
  },
  pad = {
    GamePadEnable = 1, GamePadCursorCentering = 0, GamePadTurnWithCamera = 2,
    GamePadFaceMovementMaxAngle = 115, GamePadFaceMovementMaxAngleCombat = 115, GamePadAnalogMovement = 1,
    SoftTargetInteract = 1, SoftTargetIconInteract = 1, SoftTargetIconEnemy = 1, SoftTargetNameplateEnemy = 1,
  },
}

function Controller:ApplyPreset(name)
  local preset = self.PRESETS[name]
  if not preset then return 0 end
  local changed = self:Apply(preset)
  NN:Say(L.CONTROLLER_PRESET_DONE:format(changed))
  return changed
end

-------------------------------------------------------------------------------
-- Options page (only when the client has gamepad support)
-------------------------------------------------------------------------------

if C_GamePad then
  NN.Options.RegisterPage("controller", "OPT_CONTROLLER", function(category, layout)
    local Options = NN.Options
    if Controller.AddPanelOptions then Controller:AddPanelOptions(category, layout) end
    Options.AddHeader(layout, L.OPT_CONTROLLER_PRESETS)
    Options.AddButton(layout, L.OPT_CONTROLLER_PRESET_DECK, L.OPT_BUTTON_DO, function() Controller:ApplyPreset("deck") end, L.OPT_CONTROLLER_PRESET_TT)
    Options.AddButton(layout, L.OPT_CONTROLLER_PRESET_PAD, L.OPT_BUTTON_DO, function() Controller:ApplyPreset("pad") end, L.OPT_CONTROLLER_PRESET_TT)
    Controller:AddControls(category, layout, expanded(CURATED))
  end)
end
