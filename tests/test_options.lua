local function withRules()
  WOW.extraFiles = { TESTS_DIR .. "/fixtures/two_rules.lua" }
  load_addon()
end

local function callsNamed(name)
  local out = {}
  for _, c in ipairs(WOW.calls) do if c[1] == name then out[#out + 1] = c end end
  return out
end

return {
  registers_category_and_addon_category = function()
    withRules()
    assert_eq(callsNamed("RegisterVerticalLayoutCategory")[1][2], "NewbieNudge")
    assert_eq(callsNamed("RegisterAddOnCategory")[1][2], "NewbieNudge")
    assert_eq(NewbieNudge.optionsCategoryID, "NewbieNudge")
  end,
  general_controls_are_registered = function()
    withRules()
    local boxes = callsNamed("checkbox")
    assert_eq(boxes[1][2], "NN_lock")
    assert_eq(boxes[2][2], "NN_combatStrip")
    local sliders = callsNamed("slider")
    assert_eq(sliders[1][2], "NN_scale")
    assert_eq(sliders[2][2], "NN_snooze")
  end,
  scale_slider_range_is_0_8_to_1_5 = function()
    withRules()
    local s = callsNamed("slider")[1]
    assert_eq({ s[3], s[4], s[5] }, { 0.8, 1.5, 0.1 })
    local snooze = callsNamed("slider")[2]
    assert_eq({ snooze[3], snooze[4], snooze[5] }, { 15, 240, 15 })
  end,
  one_checkbox_per_rule_in_order = function()
    withRules()
    local boxes = callsNamed("checkbox")
    local byVar, order = {}, {}
    for i, c in ipairs(boxes) do byVar[c[2]] = c; order[c[2]] = i end
    for _, rule in ipairs(NewbieNudge.rules) do assert_true(byVar["NN_rule_" .. rule.name], "checkbox for " .. rule.name) end
    assert_true(order["NN_rule_first_rule"] < order["NN_rule_second_rule"])
    assert_true(order["NN_rule_first_rule"] > order["NN_combatStrip"], "rules come after general")
    assert_eq(WOW.settings["NN_rule_first_rule"].name, "First")
    assert_true(byVar["NN_rule_first_rule"][3]:find("Help first", 1, true))
    assert_true(byVar["NN_rule_second_rule"][3]:find(NewbieNudge.L.OPT_NOT_RELEVANT, 1, true), "non-applying rule says so")
    assert_true(not byVar["NN_rule_first_rule"][3]:find(NewbieNudge.L.OPT_NOT_RELEVANT, 1, true))
  end,
  rule_checkbox_setter_disables_rule = function()
    withRules()
    local s = WOW.settings["NN_rule_first_rule"]
    assert_eq(s.getter(), true)
    s.setter(false)
    assert_eq(NewbieNudge.db.disabled.first_rule, true)
    assert_eq(s.getter(), false)
    s.setter(true)
    assert_nil(NewbieNudge.db.disabled.first_rule)
  end,
  lock_setting_round_trips_to_panel = function()
    withRules()
    local s = WOW.settings["NN_lock"]
    s.setter(false)
    assert_eq(NewbieNudge.db.panel.locked, false)
    assert_true(NewbieNudge.Panel.title:IsShown())
  end,
  scale_setting_applies_to_panel = function()
    withRules()
    WOW.settings["NN_scale"].setter(1.2)
    assert_eq(NewbieNudgePanel:GetScale(), 1.2)
    assert_eq(NewbieNudge.db.panel.scale, 1.2)
  end,
  headers_and_buttons_present = function()
    withRules()
    local inits = callsNamed("initializer")
    assert_eq(inits[1][2], "header"); assert_eq(inits[1][3], NewbieNudge.L.OPT_GENERAL)
    local names = {}
    for _, c in ipairs(inits) do names[#names + 1] = c[2] .. ":" .. c[3] end
    assert_true(tContains(names, "button:" .. NewbieNudge.L.OPT_RESET_SNOOZE))
    assert_true(tContains(names, "button:" .. NewbieNudge.L.OPT_RESET_POS))
    assert_true(tContains(names, "header:" .. NewbieNudge.L.OPT_REMINDERS))
  end,
  open_options_calls_open_to_category = function()
    withRules()
    NewbieNudge:OpenOptions()
    assert_eq(callsNamed("OpenToCategory")[1][2], "NewbieNudge")
  end,
  helpers_exposed_for_other_modules = function()
    withRules()
    assert_eq(type(NewbieNudge.Options.AddCheckbox), "function")
    assert_eq(type(NewbieNudge.Options.AddSlider), "function")
    assert_eq(type(NewbieNudge.Options.AddHeader), "function")
    assert_eq(type(NewbieNudge.Options.AddButton), "function")
  end,
  camera_lives_in_its_own_subcategory = function()
    withRules()
    local subs = callsNamed("RegisterVerticalLayoutSubcategory")
    assert_true(#subs >= 1)
    assert_eq(subs[1][2], "NewbieNudge")
    local names = {}
    for _, c in ipairs(subs) do names[#names + 1] = c[3] end
    assert_true(tContains(names, NewbieNudge.L.OPT_CAMERA))
  end,
  dropdown_helper_registers_string_setting = function()
    withRules()
    local value = "1"
    NewbieNudge.Options.AddDropdown(NewbieNudge.Options.category, "NN_test_dd", "DD", "tt",
      { { value = "0", label = "Zero" }, { value = "1", label = "One" } },
      function() return value end, function(v) value = v end)
    local dd
    for _, c in ipairs(callsNamed("dropdown")) do if c[2] == "NN_test_dd" then dd = c end end
    assert_true(dd, "dropdown registered")
    assert_eq(dd[3], { { value = "0", label = "Zero" }, { value = "1", label = "One" } })
    assert_eq(WOW.settings["NN_test_dd"].type, "string")
    WOW.settings["NN_test_dd"].setter("0"); assert_eq(value, "0")
  end,
  failing_page_does_not_block_the_category = function()
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/two_rules.lua" }
    NewbieNudge_TestPage = function() error("page boom") end
    WOW.extraFiles[#WOW.extraFiles + 1] = TESTS_DIR .. "/fixtures/failing_page.lua"
    load_addon()
    assert_eq(callsNamed("RegisterAddOnCategory")[1][2], "NewbieNudge", "category still registered")
    local printed = WOW.printed[#WOW.printed]
    assert_true(printed:find("page boom", 1, true), printed)
    assert_true(tostring(NewbieNudge.db.errors["options:Boom page"]):find("page boom", 1, true))
  end,
  style_dropdown_round_trips = function()
    withRules()
    local s = WOW.settings["NN_panel_style"]
    assert_eq(s.getter(), "list")
    s.setter("icons")
    assert_eq(NewbieNudge.db.panel.style, "icons")
    assert_true(NewbieNudge.Panel:UsesStrip())
  end,
}
