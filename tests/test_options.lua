local function withRules()
  WOW.extraFiles = { TESTS_DIR .. "/fixtures/two_rules.lua" }
  load_addon()
end

local function callsNamed(name)
  local out = {}
  for _, c in ipairs(WOW.calls) do if c[1] == name then out[#out + 1] = c end end
  return out
end


-- Calls recorded while the named options page was being built.
local function pageCalls(title)
  local out, inPage = {}, false
  for _, c in ipairs(WOW.calls) do
    if c[1] == "RegisterVerticalLayoutSubcategory" then inPage = (c[3] == title)
    elseif c[1] == "RegisterAddOnCategory" then inPage = false
    elseif inPage then out[#out + 1] = c end
  end
  return out
end
local function varsOf(calls)
  local out = {}
  for _, c in ipairs(calls) do if c[1] == "checkbox" or c[1] == "slider" or c[1] == "dropdown" then out[#out + 1] = c[2] end end
  return out
end
local function mainPageCalls()
  local out = {}
  for _, c in ipairs(WOW.calls) do
    if c[1] == "RegisterVerticalLayoutSubcategory" then break end
    out[#out + 1] = c
  end
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
  -- v4: reminders on their own page, grouped.
  every_real_rule_has_a_group = function()
    load_addon()
    local valid = { gear = true, spells = true, quests = true, professions = true, travel = true }
    for _, rule in ipairs(NewbieNudge.rules) do assert_true(valid[rule.group], rule.name) end
  end,
  reminders_page_is_a_subcategory = function()
    withRules()
    local found = false
    for _, c in ipairs(callsNamed("RegisterVerticalLayoutSubcategory")) do
      if c[3] == NewbieNudge.L.OPT_REMINDERS then found = true end
    end
    assert_true(found)
  end,
  rule_checkboxes_not_on_main_page = function()
    withRules()
    local page, firstRule
    for i, c in ipairs(WOW.calls) do
      if c[1] == "RegisterVerticalLayoutSubcategory" and c[3] == NewbieNudge.L.OPT_REMINDERS then page = page or i end
      if c[1] == "checkbox" and c[2]:find("^NN_rule_") then firstRule = firstRule or i end
    end
    assert_true(page and firstRule and firstRule > page)
  end,
  group_headers_in_order = function()
    withRules()
    local L = NewbieNudge.L
    local inPage, headers = false, {}
    for _, c in ipairs(WOW.calls) do
      if c[1] == "RegisterVerticalLayoutSubcategory" then inPage = (c[3] == L.OPT_REMINDERS) end
      if inPage and c[1] == "initializer" and c[2] == "header" then headers[#headers + 1] = c[3] end
    end
    assert_eq(headers, { L.OPT_GROUP_GEAR, L.OPT_GROUP_SPELLS, L.OPT_GROUP_QUESTS, L.OPT_GROUP_PROFESSIONS,
      L.OPT_GROUP_TRAVEL, L.OPT_GROUP_OTHER })
  end,
  rules_in_priority_order_within_group = function()
    withRules()
    local order = {}
    for i, c in ipairs(callsNamed("checkbox")) do order[c[2]] = i end
    assert_true(order.NN_rule_durability < order.NN_rule_bag_unequipped)
    assert_true(order.NN_rule_bag_full < order.NN_rule_ammo)
  end,
  -- v4: page order and the merged Bags page.
  subpage_order = function()
    withRules()
    local L = NewbieNudge.L
    local names = {}
    for _, c in ipairs(callsNamed("RegisterVerticalLayoutSubcategory")) do names[#names + 1] = c[3] end
    local expected = { L.OPT_REMINDERS, L.OPT_BAGS, L.OPT_MAP, L.OPT_GS_COMBAT, L.OPT_GS_NAMES, L.OPT_GS_INTERFACE, L.OPT_CAMERA }
    if tContains(names, L.OPT_CONTROLLER) then expected[#expected + 1] = L.OPT_CONTROLLER end
    expected[#expected + 1] = L.OPT_BUILD
    expected[#expected + 1] = L.OPT_DEV
    assert_eq(names, expected)
  end,
  unknown_page_key_goes_last = function()
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/failing_page.lua" }
    load_addon()
    local subs = callsNamed("RegisterVerticalLayoutSubcategory")
    assert_eq(subs[#subs][3], "Boom page")
    assert_eq(subs[#subs - 1][3], NewbieNudge.L.OPT_DEV)
  end,
  main_page_sections = function()
    withRules()
    local L = NewbieNudge.L
    local headers = {}
    for _, c in ipairs(mainPageCalls()) do if c[1] == "initializer" and c[2] == "header" then headers[#headers + 1] = c[3] end end
    assert_eq(headers, { L.OPT_GENERAL, L.OPT_INFOBAR_HEADER, L.OPT_MINIMAP_HEADER, L.OPT_SETUP })
  end,
  bags_page_holds_vendor_tooltip_and_game_controls = function()
    withRules()
    local L = NewbieNudge.L
    local calls = pageCalls(L.OPT_BAGS)
    local vars = varsOf(calls)
    for _, v in ipairs({ "NN_bagfull_enabled", "NN_vendor_sellJunk", "NN_vendor_repair", "NN_tooltipPrice",
      "NN_cvar_autoLootDefault", "NN_cvar_lootUnderMouse", "NN_cvar_expandBagBar", "NN_cvar_combinedBags" }) do
      assert_true(tContains(vars, v), v)
    end
    local gsHeader, firstCvar
    for i, c in ipairs(calls) do
      if c[1] == "initializer" and c[3] == L.OPT_GS_HEADER then gsHeader = gsHeader or i end
      if c[2] == "NN_cvar_autoLootDefault" then firstCvar = i end
    end
    assert_true(gsHeader and firstCvar and gsHeader < firstCvar, "game settings sit under their header")
  end,
  no_vendors_tooltips_or_game_settings_pages = function()
    withRules()
    local L = NewbieNudge.L
    for _, c in ipairs(callsNamed("RegisterVerticalLayoutSubcategory")) do
      assert_true(c[3] ~= L.OPT_BAGS_VENDOR and c[3] ~= L.OPT_TOOLTIPS and c[3] ~= "Game settings", c[3])
    end
  end,
  map_page_holds_its_game_settings = function()
    withRules()
    local vars = varsOf(pageCalls(NewbieNudge.L.OPT_MAP))
    for _, v in ipairs({ "NN_map_reveal", "NN_cvar_mapFade", "NN_cvar_rotateMinimap", "NN_cvar_questPOI" }) do
      assert_true(tContains(vars, v), v)
    end
  end,
  icon_layout_options_round_trip = function()
    withRules()
    local function slider(var) for _, c in ipairs(callsNamed("slider")) do if c[2] == var then return c end end end
    assert_eq({ select(3, unpack(slider("NN_panel_iconsPerLine"))) }, { 1, 12, 1 })
    assert_eq({ select(3, unpack(slider("NN_panel_iconSize"))) }, { 16, 40, 2 })
    assert_eq({ select(3, unpack(slider("NN_panel_iconGap"))) }, { 0, 12, 1 })
    WOW.settings["NN_panel_iconsPerLine"].setter(4)
    WOW.settings["NN_panel_iconFlow"].setter("columns")
    WOW.settings["NN_panel_iconSize"].setter(32)
    WOW.settings["NN_panel_iconGap"].setter(2)
    local p = NewbieNudge.db.panel
    assert_eq({ p.iconsPerLine, p.iconFlow, p.iconSize, p.iconGap }, { 4, "columns", 32, 2 })
  end,
}
