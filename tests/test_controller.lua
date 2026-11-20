-- Controller: the gamepad CVar page, presets, and (Task 13) the
-- controller-aware panel.
local L = function() return NewbieNudge.L end
local function cvars(list)
  WOW.state.cvars = {}
  for n, v in pairs(list) do WOW.state.cvars[n] = { value = v.value or v.default, default = v.default } end
end
local function callsNamed(name)
  local out = {}
  for _, c in ipairs(WOW.calls) do if c[1] == name then out[#out + 1] = c end end
  return out
end
local function has(list, pred) for _, c in ipairs(list) do if pred(c) then return c end end end

return {
  curated_starts_with_enable_and_has_expected_kinds = function()
    load_addon()
    local c = NewbieNudge.Controller.CURATED
    assert_eq(c[1].cvar, "GamePadEnable"); assert_eq(c[1].kind, "checkbox")
    assert_true(has(c, function(e) return e.cvar == "GamePadCursorLeftClick" and e.kind == "padbutton" end))
    assert_true(has(c, function(e) return e.cvar == "SoftTargetInteract" and e.kind == "dropdown" and #e.options == 4 end))
  end,
  padbutton_becomes_dropdown_with_own_labels_and_raw_current = function()
    cvars({ GamePadEnable = { default = "0" }, GamePadCursorLeftClick = { default = "PADRTRIGGER", value = "PADPADDLE9" } })
    load_addon()
    local dd = has(callsNamed("dropdown"), function(c) return c[2] == "NN_cvar_GamePadCursorLeftClick" end)
    assert_true(dd)
    assert_eq(dd[3][1], { value = "none", label = L().PAD_NONE })
    assert_true(has(dd[3], function(o) return o.value == "PADRTRIGGER" and o.label == "RT" end)) -- from PAD_NAMES, not GetBindingText
    assert_eq(dd[3][#dd[3]], { value = "PADPADDLE9", label = "PADPADDLE9" })
  end,
  preset_applies_table_and_says_once = function()
    cvars({ GamePadEnable = { default = "0" }, GamePadFaceMovementMaxAngle = { default = "0" }, GamePadTurnWithCamera = { default = "1" }, SoftTargetInteract = { default = "1" } })
    load_addon()
    local printed = #WOW.printed
    local n = NewbieNudge.Controller:ApplyPreset("deck")
    assert_true(n >= 3)
    assert_eq(C_CVar.GetCVar("GamePadFaceMovementMaxAngle"), "115"); assert_eq(C_CVar.GetCVar("GamePadTurnWithCamera"), "2")
    assert_eq(#WOW.printed, printed + 1)
    assert_true(WOW.printed[#WOW.printed]:find(L().CONTROLLER_PRESET_DONE:format(n), 1, true))
  end,
  presets_never_touch_modifier_buttons = function()
    load_addon()
    for _, p in pairs(NewbieNudge.Controller.PRESETS) do
      for _, cv in ipairs({ "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt", "GamePadCursorLeftClick", "GamePadCursorRightClick" }) do
        assert_nil(p[cv])
      end
    end
  end,
  reset_writes_defaults_for_curated = function()
    cvars({ GamePadEnable = { default = "0", value = "1" }, GamePadCameraYawSpeed = { default = "1", value = "3" } })
    load_addon(); NewbieNudge.Controller:ResetCurated()
    assert_eq(C_CVar.GetCVar("GamePadEnable"), "0"); assert_eq(C_CVar.GetCVar("GamePadCameraYawSpeed"), "1")
  end,
  discovery_prefix = function()
    cvars({ GamePadEnable = { default = "0" }, GamePadFoo = { default = "0" }, SoftTargetBar = { default = "2" }, cameraX = { default = "1" } })
    WOW.state.consoleCommands = {}
    for _, n in ipairs({ "GamePadEnable", "GamePadFoo", "SoftTargetBar", "cameraX" }) do
      WOW.state.consoleCommands[#WOW.state.consoleCommands + 1] = { command = n, help = "", commandType = 0 }
    end
    load_addon()
    local names = {}
    for _, d in ipairs(NewbieNudge.Controller:Discover()) do names[#names + 1] = d.cvar end
    assert_eq(names, { "GamePadFoo", "SoftTargetBar" })
  end,
  section_absent_without_gamepad_api = function()
    _G.C_GamePad = nil
    load_addon()
    assert_nil(has(callsNamed("RegisterVerticalLayoutSubcategory"), function(c) return c[3] == L().OPT_CONTROLLER end))
  end,
  section_present_with_gamepad_api = function()
    load_addon()
    assert_true(has(callsNamed("RegisterVerticalLayoutSubcategory"), function(c) return c[3] == L().OPT_CONTROLLER end))
    assert_true(has(callsNamed("initializer"), function(c) return c[2] == "button" and c[3] == L().OPT_CONTROLLER_PRESET_DECK end))
  end,
}
