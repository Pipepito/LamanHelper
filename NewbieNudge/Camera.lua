-- Camera: console variables (CVars) the game exposes but Blizzard's own
-- settings window does not show. Built on CVarSection; this file only holds
-- the curated list and the exclude list.
local _, NN = ...
local L = NN.L

local Camera = NN.CVarSection.New({
  -- Curated list with proper controls. Labels and help are locale keys.
  curated = {
    { cvar = "cameraDistanceMaxZoomFactor",      kind = "slider",   min = 1.0, max = 2.6, step = 0.1, label = "CAM_MAX_ZOOM",        help = "CAM_MAX_ZOOM_TT" },
    { cvar = "cameraDistanceMoveSpeed",          kind = "slider",   min = 1,   max = 50,  step = 1,   label = "CAM_ZOOM_SPEED",      help = "CAM_ZOOM_SPEED_TT" },
    { cvar = "cameraKeepCharacterCentered",      kind = "checkbox", label = "CAM_KEEP_CENTERED",   help = "CAM_KEEP_CENTERED_TT" },
    { cvar = "cameraReduceUnexpectedMovement",   kind = "checkbox", label = "CAM_REDUCE_MOVEMENT", help = "CAM_REDUCE_MOVEMENT_TT" },
    { cvar = "test_cameraDynamicPitch",          kind = "checkbox", label = "CAM_DYNAMIC_PITCH",   help = "CAM_DYNAMIC_PITCH_TT" },
    { cvar = "test_cameraOverShoulder",          kind = "slider",   min = -2.0, max = 2.0, step = 0.1, label = "CAM_OVER_SHOULDER", help = "CAM_OVER_SHOULDER_TT" },
    { cvar = "test_cameraTargetFocusEnemyEnable",    kind = "checkbox", label = "CAM_FOCUS_ENEMY",    help = "CAM_FOCUS_ENEMY_TT" },
    { cvar = "test_cameraTargetFocusInteractEnable", kind = "checkbox", label = "CAM_FOCUS_INTERACT", help = "CAM_FOCUS_INTERACT_TT" },
    { cvar = "test_cameraHeadMovementStrength",  kind = "slider",   min = 0,   max = 2,   step = 0.1, label = "CAM_HEAD_MOVEMENT",  help = "CAM_HEAD_MOVEMENT_TT" },
  },
  -- Variables Blizzard's own settings window already exposes.
  exclude = {
    cameraSmoothStyle = true, cameraSmoothTrackingStyle = true, cameraBobbing = true, cameraWaterCollision = true,
    cameraYawMoveSpeed = true, cameraPitchMoveSpeed = true, cameraSmoothYaw = true, cameraSmoothPitch = true,
    cameraTerrainTilt = true,
  },
  match = function(name) return name:lower():find("camera", 1, true) ~= nil end,
  note = "OPT_CAMERA_NOTE",
  otherHeader = "OPT_CAMERA_OTHER",
  resetLabel = "OPT_CAMERA_RESET",
})
NN.Camera = Camera

function Camera:AddToOptions(category, layout)
  NN.Options.AddHeader(layout, L.OPT_CAMERA)
  self:AddControls(category, layout)
end
