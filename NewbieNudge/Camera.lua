-- Camera: console variables (CVars) the game exposes but Blizzard's own
-- settings window does not show. Values live in the game's config, not in
-- the addon's saved variables.
local _, NN = ...
local L = NN.L

local Camera = {}
NN.Camera = Camera

-- Curated list with proper controls. Labels and help are locale keys.
Camera.CURATED = {
  { cvar = "cameraDistanceMaxZoomFactor",      kind = "slider",   min = 1.0, max = 2.6, step = 0.1, label = "CAM_MAX_ZOOM",        help = "CAM_MAX_ZOOM_TT" },
  { cvar = "cameraDistanceMoveSpeed",          kind = "slider",   min = 1,   max = 50,  step = 1,   label = "CAM_ZOOM_SPEED",      help = "CAM_ZOOM_SPEED_TT" },
  { cvar = "cameraKeepCharacterCentered",      kind = "checkbox", label = "CAM_KEEP_CENTERED",   help = "CAM_KEEP_CENTERED_TT" },
  { cvar = "cameraReduceUnexpectedMovement",   kind = "checkbox", label = "CAM_REDUCE_MOVEMENT", help = "CAM_REDUCE_MOVEMENT_TT" },
  { cvar = "test_cameraDynamicPitch",          kind = "checkbox", label = "CAM_DYNAMIC_PITCH",   help = "CAM_DYNAMIC_PITCH_TT" },
  { cvar = "test_cameraOverShoulder",          kind = "slider",   min = -2.0, max = 2.0, step = 0.1, label = "CAM_OVER_SHOULDER", help = "CAM_OVER_SHOULDER_TT" },
  { cvar = "test_cameraTargetFocusEnemyEnable",    kind = "checkbox", label = "CAM_FOCUS_ENEMY",    help = "CAM_FOCUS_ENEMY_TT" },
  { cvar = "test_cameraTargetFocusInteractEnable", kind = "checkbox", label = "CAM_FOCUS_INTERACT", help = "CAM_FOCUS_INTERACT_TT" },
  { cvar = "test_cameraHeadMovementStrength",  kind = "slider",   min = 0,   max = 2,   step = 0.1, label = "CAM_HEAD_MOVEMENT",  help = "CAM_HEAD_MOVEMENT_TT" },
}

-- Variables Blizzard's own settings window already exposes.
Camera.EXCLUDE = {
  cameraSmoothStyle = true, cameraSmoothTrackingStyle = true, cameraBobbing = true, cameraWaterCollision = true,
  cameraYawMoveSpeed = true, cameraPitchMoveSpeed = true, cameraSmoothYaw = true, cameraSmoothPitch = true,
  cameraTerrainTilt = true,
}

local curatedSet = {}
for _, entry in ipairs(Camera.CURATED) do curatedSet[entry.cvar] = true end

local function getCVar(name)
  if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
  if GetCVar then return GetCVar(name) end
  return nil
end

local function getDefault(name)
  if C_CVar and C_CVar.GetCVarDefault then return C_CVar.GetCVarDefault(name) end
  if GetCVarDefault then return GetCVarDefault(name) end
  return nil
end

function Camera:Get(cvar)
  local raw = getCVar(cvar)
  raw = NN.Plain(raw, "string")
  if raw == nil then return nil end
  return tonumber(raw)
end

function Camera:Set(cvar, value)
  local text = tostring(value)
  if type(value) == "number" then
    -- keep "2" rather than "2.0" and strip float noise
    text = string.format("%.4f", value):gsub("0+$", ""):gsub("%.$", "")
  end
  if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(cvar, text) elseif SetCVar then SetCVar(cvar, text) end
end

function Camera:ResetCurated()
  for _, entry in ipairs(self.CURATED) do
    local default = getDefault(entry.cvar)
    if default ~= nil then self:Set(entry.cvar, default) end
  end
end

local function classify(cvar, help)
  local default = NN.Plain(getDefault(cvar), "string")
  local current = Camera:Get(cvar)
  local defaultNumber = tonumber(default)
  if defaultNumber == nil then return nil end
  if default == "0" or default == "1" then
    return { cvar = cvar, help = help, default = defaultNumber, current = current, kind = "checkbox" }
  end
  local max = math.max(1, defaultNumber * 2, current or 0)
  local step = default:find("%.") and 0.1 or 1
  return { cvar = cvar, help = help, default = defaultNumber, current = current, kind = "slider", min = 0, max = max, step = step }
end

function Camera:Discover()
  local found = {}
  if not (C_Console and C_Console.GetAllCommands) then return found end
  local cvarType = Enum and Enum.ConsoleCommandType and Enum.ConsoleCommandType.Cvar or 0
  for _, cmd in ipairs(C_Console.GetAllCommands() or {}) do
    local name = NN.Plain(cmd.command, "string")
    if name and cmd.commandType == cvarType and name:lower():find("camera", 1, true)
      and not curatedSet[name] and not self.EXCLUDE[name] then
      local entry = classify(name, NN.Plain(cmd.help, "string") or "")
      if entry then found[#found + 1] = entry end
    end
  end
  table.sort(found, function(a, b) return a.cvar < b.cvar end)
  return found
end

local function addControl(category, entry, label, tooltip)
  local variable = "NN_cvar_" .. entry.cvar
  if entry.kind == "checkbox" then
    NN.Options.AddCheckbox(category, variable, label, tooltip,
      function() return Camera:Get(entry.cvar) == 1 end,
      function(value) Camera:Set(entry.cvar, value and 1 or 0) end)
  else
    NN.Options.AddSlider(category, variable, label, tooltip, entry.min, entry.max, entry.step,
      function() return Camera:Get(entry.cvar) or entry.min end,
      function(value) Camera:Set(entry.cvar, value) end)
  end
end

function Camera:AddToOptions(category, layout)
  NN.Options.AddHeader(layout, L.OPT_CAMERA)
  for _, entry in ipairs(self.CURATED) do
    addControl(category, entry, L[entry.label], L[entry.help] .. "\n\n|cff999999" .. L.OPT_CAMERA_NOTE .. "|r")
  end
  NN.Options.AddButton(layout, L.OPT_CAMERA_RESET, L.OPT_BUTTON_DO, function() Camera:ResetCurated() end)
  local discovered = self:Discover()
  if #discovered > 0 then
    NN.Options.AddHeader(layout, L.OPT_CAMERA_OTHER)
    for _, entry in ipairs(discovered) do
      addControl(category, entry, entry.cvar, entry.help ~= "" and entry.help or entry.cvar)
    end
  end
end
