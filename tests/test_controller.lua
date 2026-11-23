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
  -- 2026-11-23 (taint log): writing the game's controller settings from the
  -- addon's Settings page tainted Forever's gamepad UI (protected actions
  -- blocked, the addon had to be disabled). NewbieNudge only reads them now.
  page_never_writes_the_games_controller_settings = function()
    cvars({ GamePadEnable = { default = "0" }, GamePadEmulateAlt = { default = "none" }, SoftTargetInteract = { default = "1" } })
    load_addon()
    for variable in pairs(WOW.settings) do
      assert_true(not variable:find("^NN_cvar_GamePad") and not variable:find("^NN_cvar_SoftTarget"), variable)
    end
    assert_nil(NewbieNudge.Controller.ApplyPreset, "no presets")
    assert_true(has(callsNamed("initializer"), function(c) return c[2] == "header" and c[3] == L().OPT_CONTROLLER_GAME_NOTE end))
  end,
  no_page_can_write_controller_settings = function()
    cvars({ GamePadEmulateAlt = { default = "none" }, SoftTargetInteract = { default = "1" }, cameraDistanceMaxZoomFactor = { default = "1.9" } })
    load_addon()
    assert_eq(NewbieNudge.Camera:Set("GamePadEmulateAlt", "PADPADDLE1"), false)
    assert_eq(NewbieNudge.Camera:Set("SoftTargetInteract", 3), false)
    assert_eq(C_CVar.GetCVar("GamePadEmulateAlt"), "none"); assert_eq(C_CVar.GetCVar("SoftTargetInteract"), "1")
    assert_eq(NewbieNudge.Camera:Set("cameraDistanceMaxZoomFactor", 2.6), true, "other settings still written")
  end,
  section_absent_without_gamepad_api = function()
    _G.C_GamePad = nil
    load_addon()
    assert_nil(has(callsNamed("RegisterVerticalLayoutSubcategory"), function(c) return c[3] == L().OPT_CONTROLLER end))
  end,
  section_present_with_gamepad_api = function()
    load_addon()
    assert_true(has(callsNamed("RegisterVerticalLayoutSubcategory"), function(c) return c[3] == L().OPT_CONTROLLER end))
  end,
  -- Task 13: the addon when a controller is in use
  session_set_by_active_event_and_sticky = function()
    load_addon(); assert_eq(NewbieNudge.Controller.session, false)
    WOW.FireEvent("GAME_PAD_ACTIVE_CHANGED", true); assert_eq(NewbieNudge.Controller.session, true)
    WOW.FireEvent("GAME_PAD_ACTIVE_CHANGED", false); assert_eq(NewbieNudge.Controller.session, true)
  end,
  session_detected_at_login = function()
    WOW.state.gamepad = { enabled = true, deviceID = 3 }; WOW.state.cvars = { GamePadEnable = { value = "1", default = "0" } }
    load_addon(); assert_eq(NewbieNudge.Controller.session, true)
  end,
  panel_scale_boosted_in_session = function()
    load_addon(); NewbieNudge.db.panel.scale = 1.2
    NewbieNudge.Panel:ApplyScale(); assert_eq(NewbieNudgePanel:GetScale(), 1.2)
    WOW.FireEvent("GAME_PAD_ACTIVE_CHANGED", true)
    assert_eq(NewbieNudgePanel:GetScale(), 1.5)
    NewbieNudge.db.controller.boost = false; NewbieNudge.Panel:ApplyScale(); assert_eq(NewbieNudgePanel:GetScale(), 1.2)
    assert_eq(NewbieNudge.Panel.STRIP_ICON(), 24)
    NewbieNudge.db.controller.boost = true; assert_eq(NewbieNudge.Panel.STRIP_ICON(), 32)
  end,
  tooltip_hints_use_pad_buttons = function()
    WOW.state.cvars = {
      GamePadCursorLeftClick = { value = "PADRTRIGGER", default = "PADRTRIGGER" },
      GamePadCursorRightClick = { value = "PADRSHOULDER", default = "PADRSHOULDER" },
      GamePadEmulateShift = { value = "PADLTRIGGER", default = "PADLTRIGGER" },
    }
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/two_rules.lua" }
    load_addon(); WOW.FireEvent("TEST_EVENT"); run_checks(); WOW.FireEvent("GAME_PAD_ACTIVE_CHANGED", true)
    WOW.Hover(NewbieNudge.Panel.rows[1])
    local text = table.concat(GameTooltip.lines, "\n")
    assert_true(text:find(L().ROW_HINT_CLICK_PAD:format("RT"), 1, true), text)
    assert_true(text:find(L().ROW_HINT_SNOOZE_PAD:format("RB", "LT", "RB"), 1, true), text)
  end,
  hint_falls_back_to_raw_token = function()
    WOW.state.cvars = { GamePadCursorLeftClick = { value = "PADPADDLE9", default = "PADRTRIGGER" } }
    load_addon(); WOW.FireEvent("GAME_PAD_ACTIVE_CHANGED", true)
    local left = NewbieNudge.Controller:HintButtons()
    assert_eq(left, "PADPADDLE9")
  end,
  hints_absent_without_session_or_when_disabled = function()
    load_addon()
    assert_nil(NewbieNudge.Controller:HintButtons())
    WOW.FireEvent("GAME_PAD_ACTIVE_CHANGED", true); NewbieNudge.db.controller.hints = false
    assert_nil(NewbieNudge.Controller:HintButtons())
  end,
  bindings_act_on_top_row_and_toggle_hidden = function()
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/two_rules.lua" }
    load_addon(); WOW.FireEvent("TEST_EVENT"); run_checks()
    assert_true(NewbieNudgePanel:IsShown())
    NewbieNudge.Panel:ToggleHidden(); assert_true(not NewbieNudgePanel:IsShown()); assert_eq(NewbieNudge.db.panel.hidden, true)
    NewbieNudge.Panel:Refresh(NewbieNudge:ActiveRows()); assert_true(not NewbieNudgePanel:IsShown(), "stays hidden through refresh")
    NewbieNudge.Panel:ToggleHidden(); assert_true(NewbieNudgePanel:IsShown())
    NewbieNudge.Panel:OpenTop()
    NewbieNudge.Panel:SnoozeTop(); assert_true(NewbieNudge.db.snoozed.first_rule ~= nil)
    assert_eq(type(BINDING_NAME_NEWBIENUDGE_TOGGLE), "string"); assert_eq(type(BINDING_HEADER_NEWBIENUDGE), "string")
  end,
  controller_panel_options_registered = function()
    load_addon()
    assert_true(WOW.settings["NN_controller_boost"] and WOW.settings["NN_controller_scale"] and WOW.settings["NN_controller_hints"])
    WOW.settings["NN_controller_scale"].setter(1.4); assert_eq(NewbieNudge.db.controller.scale, 1.4)
  end,
}
