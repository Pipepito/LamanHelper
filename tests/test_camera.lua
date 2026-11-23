local L = function() return NewbieNudge.L end

local function cvars(list)
  WOW.state.cvars = {}
  for name, v in pairs(list) do WOW.state.cvars[name] = { value = v.value or v.default, default = v.default } end
end

local function console(list)
  WOW.state.consoleCommands = {}
  for _, c in ipairs(list) do
    WOW.state.consoleCommands[#WOW.state.consoleCommands + 1] = {
      command = c[1], help = c[2] or "", category = 4, commandType = c.kind or Enum.ConsoleCommandType.Cvar,
    }
  end
end

local function callsNamed(name)
  local out = {}
  for _, c in ipairs(WOW.calls) do if c[1] == name then out[#out + 1] = c end end
  return out
end

local function has(list, pred)
  for _, c in ipairs(list) do if pred(c) then return c end end
  return nil
end

return {
  curated_order_starts_with_max_zoom = function()
    load_addon()
    local c = NewbieNudge.Camera.CURATED
    assert_eq(c[1].cvar, "cameraDistanceMaxZoomFactor")
    assert_eq({ c[1].min, c[1].max, c[1].step }, { 1.0, 2.6, 0.1 })
    assert_eq(#c, 9)
  end,
  get_returns_number_or_nil = function()
    cvars({ cameraDistanceMaxZoomFactor = { value = "1.9", default = "1.9" } })
    load_addon()
    assert_eq(NewbieNudge.Camera:Get("cameraDistanceMaxZoomFactor"), 1.9)
    assert_nil(NewbieNudge.Camera:Get("noSuchCVar"))
  end,
  set_writes_string = function()
    cvars({ cameraDistanceMaxZoomFactor = { value = "1.9", default = "1.9" } })
    load_addon()
    NewbieNudge.Camera:Set("cameraDistanceMaxZoomFactor", 2.6)
    local c = callsNamed("SetCVar")[#callsNamed("SetCVar")]
    assert_eq(c[2], "cameraDistanceMaxZoomFactor"); assert_eq(c[3], "2.6")
    assert_eq(NewbieNudge.Camera:Get("cameraDistanceMaxZoomFactor"), 2.6)
  end,
  reset_curated_uses_defaults = function()
    cvars({ cameraDistanceMaxZoomFactor = { value = "2.6", default = "1.9" }, cameraKeepCharacterCentered = { value = "0", default = "1" } })
    load_addon()
    NewbieNudge.Camera:ResetCurated()
    assert_eq(NewbieNudge.Camera:Get("cameraDistanceMaxZoomFactor"), 1.9)
    assert_eq(NewbieNudge.Camera:Get("cameraKeepCharacterCentered"), 1)
  end,
  discover_filters_and_classifies = function()
    cvars({
      cameraFoo = { default = "0" }, cameraBar = { default = "2.5", value = "3" }, cameraBaz = { default = "abc" },
      cameraSmoothStyle = { default = "4" }, cameraDistanceMaxZoomFactor = { default = "1.9" }, soundFoo = { default = "1" },
      CameraUpper = { default = "7" },
    })
    console({ { "cameraFoo", "foo help" }, { "cameraBar" }, { "cameraBaz" }, { "cameraSmoothStyle" },
              { "cameraDistanceMaxZoomFactor" }, { "soundFoo" }, { "CameraUpper" }, { "cameraCmd", kind = Enum.ConsoleCommandType.Command } })
    load_addon()
    local found = NewbieNudge.Camera:Discover()
    local names = {}
    for i, d in ipairs(found) do names[i] = d.cvar end
    assert_eq(names, { "CameraUpper", "cameraBar", "cameraFoo" })
    assert_eq(found[3].kind, "checkbox"); assert_eq(found[3].help, "foo help")
    assert_eq(found[2].kind, "slider"); assert_eq({ found[2].min, found[2].max, found[2].step }, { 0, 5, 0.1 })
    assert_eq(found[1].kind, "slider"); assert_eq({ found[1].min, found[1].max, found[1].step }, { 0, 14, 1 })
  end,
  discover_empty_without_console_api = function()
    _G.C_Console = nil
    load_addon()
    assert_eq(NewbieNudge.Camera:Discover(), {})
  end,
  add_to_options_registers_curated_then_discovered = function()
    cvars({ cameraDistanceMaxZoomFactor = { default = "1.9" }, cameraKeepCharacterCentered = { default = "1" }, cameraFoo = { default = "0" } })
    console({ { "cameraFoo", "foo help" } })
    load_addon()
    local inits = callsNamed("initializer")
    assert_true(has(inits, function(c) return c[2] == "header" and c[3] == L().OPT_CAMERA end))
    assert_true(has(inits, function(c) return c[2] == "button" and c[3] == L().OPT_CAMERA_RESET end))
    assert_true(has(inits, function(c) return c[2] == "header" and c[3] == L().OPT_CAMERA_OTHER end))
    local slider = has(callsNamed("slider"), function(c) return c[2] == "NN_cvar_cameraDistanceMaxZoomFactor" end)
    assert_true(slider); assert_eq({ slider[3], slider[4], slider[5] }, { 1.0, 2.6, 0.1 })
    assert_true(has(callsNamed("checkbox"), function(c) return c[2] == "NN_cvar_cameraKeepCharacterCentered" end))
    assert_true(has(callsNamed("checkbox"), function(c) return c[2] == "NN_cvar_cameraFoo" end))
    assert_eq(WOW.settings["NN_cvar_cameraDistanceMaxZoomFactor"].name, L().CAM_MAX_ZOOM)
    -- camera section comes after the reminders page (its first group header)
    local order = {}
    for i, c in ipairs(inits) do if c[2] == "header" then order[c[3]] = i end end
    assert_true(order[L().OPT_CAMERA] > order[L().OPT_GROUP_GEAR])
  end,
  no_other_header_when_nothing_discovered = function()
    cvars({ cameraDistanceMaxZoomFactor = { default = "1.9" } })
    console({})
    load_addon()
    assert_nil(has(callsNamed("initializer"), function(c) return c[2] == "header" and c[3] == L().OPT_CAMERA_OTHER end))
  end,
  discovered_setter_writes_cvar = function()
    cvars({ cameraFoo = { default = "0" }, cameraBar = { default = "2.5" } })
    console({ { "cameraFoo" }, { "cameraBar" } })
    load_addon()
    WOW.settings["NN_cvar_cameraFoo"].setter(true)
    assert_eq(NewbieNudge.Camera:Get("cameraFoo"), 1)
    assert_eq(WOW.settings["NN_cvar_cameraFoo"].getter(), true)
    WOW.settings["NN_cvar_cameraBar"].setter(4)
    assert_eq(NewbieNudge.Camera:Get("cameraBar"), 4)
  end,
  curated_checkbox_round_trips = function()
    cvars({ cameraKeepCharacterCentered = { default = "1" } })
    load_addon()
    local s = WOW.settings["NN_cvar_cameraKeepCharacterCentered"]
    assert_eq(s.getter(), true)
    s.setter(false)
    assert_eq(NewbieNudge.Camera:Get("cameraKeepCharacterCentered"), 0)
    assert_eq(s.getter(), false)
  end,
  gamepad_camera_cvars_are_on_no_page = function()
    -- The live client refuses a second registration of the same variable; a
    -- GamePad* CVar that contains "camera" must not be registered by both pages.
    cvars({ cameraDistanceMaxZoomFactor = { default = "1.9" }, GamePadCameraYawSpeed = { default = "1" }, GamePadTurnWithCamera = { default = "1" } })
    console({ { "GamePadCameraYawSpeed", "yaw" }, { "GamePadTurnWithCamera", "turn" } })
    load_addon()
    local regs = 0
    for _, c in ipairs(callsNamed("RegisterProxySetting")) do if c[2] == "NN_cvar_GamePadCameraYawSpeed" then regs = regs + 1 end end
    assert_eq(regs, 0, "no page offers the game's controller settings (2026-11-23)")
    for _, d in ipairs(NewbieNudge.Camera:Discover()) do assert_true(d.cvar:sub(1, 7) ~= "GamePad", d.cvar) end
    assert_eq(callsNamed("RegisterAddOnCategory")[1][2], "NewbieNudge")
  end,
}
