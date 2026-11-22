-- Service buttons on reminder rows (v4): which rows carry a service, the
-- row pin button, Ctrl+click in the strip, menu, options, /nudge services.
local L = function() return NewbieNudge.L end
local function services() WOW.extraFiles = { TESTS_DIR .. "/fixtures/services.lua" } end
local function rule(name, result)
  NewbieNudge:RegisterRule({ name = name, title = "T_" .. name, help = "H", events = {},
    applies = function() return true end, check = function() return result end })
  NewbieNudge:MarkAllDirty(); run_checks()
end
-- The panel row / strip icon showing the given text (other rules show rows too).
local function rowWith(text)
  for _, row in ipairs(NewbieNudge.Panel.rows) do if row:IsShown() and row.data and row.data.result.text == text then return row end end
end
local function iconWith(text)
  for _, icon in ipairs(NewbieNudge.Panel.stripIcons) do if icon:IsShown() and icon.data and icon.data.result.text == text then return icon end end
end
local function entry(label)
  for _, e in ipairs(NewbieNudge.MinimapButton:MenuEntries()) do if e.label == label then return e end end
end

return {
  -- which rows carry a service
  durability_row_marks_repair = function()
    WOW.state.inventory[5] = { itemID = 1005, durability = { 10, 100 } }
    load_addon(); run_checks()
    assert_eq(results_of("durability")[1].service, { kind = "repair" })
  end,
  trainer_spells_row_marks_class_trainer = function()
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/trainer_spells.lua" }
    WOW.state.spellInfo[133] = { name = "S133" }; WOW.state.spellInfo[143] = { name = "S143" }
    WOW.state.spellInfo[145] = { name = "S145" }; WOW.state.spellInfo[5143] = { name = "S5143" }
    WOW.state.level = 10; WOW.state.spellBook.items[133] = { spellID = 133 }
    load_addon(); WOW.FireEvent("SPELLS_CHANGED"); run_checks()
    assert_eq(results_of("trainer_spells")[1].service, { kind = "trainer_MAGE" })
  end,
  supplies_food_row_only = function()
    WOW.state.level = 5
    load_addon(); load_bags(); run_checks()
    assert_eq(results_of("supplies")[1].service, { kind = "supplies" })
  end,
  rested_row_marks_inn = function()
    load_addon(); run_checks()
    WOW.ShowGameMenu(true); run_checks()
    assert_eq(results_of("rested")[1].service, { kind = "inn" })
  end,
  profession_trainer_row_marks_that_trainer = function()
    WOW.state.level = 22; WOW.state.professions = { prof1 = 1, prof2 = 2 }
    WOW.state.professionInfo[1] = { name = "Alchemy", skill = 60, maxSkill = 75, skillLine = 171 }
    WOW.state.professionInfo[2] = { name = "Herbalism", skill = 130, maxSkill = 150, skillLine = 182 }
    load_addon(); WOW.FireEvent("SKILL_LINES_CHANGED"); run_checks()
    local r = results_of("profession_rank")
    assert_eq(r[1].service, { kind = "prof_171" })
    assert_eq(r[2].service, { kind = "prof_182" })
  end,
  weapon_row_marks_its_own_trainers = function()
    local s = WOW.state
    s.class, s.faction, s.level = "MAGE", "Horde", 12
    s.skillLines = { { name = "Wands", skillID = 228, rank = 1, maxRank = 5 } }
    load_addon(); WOW.FireEvent("SKILL_LINES_CHANGED"); run_checks()
    local r = results_of("weapon_trainers")
    assert_eq(r[1].service, { kind = "weapon", npcIDs = { 11868, 2704 } }) -- Sayoc, Hanashi
    assert_eq(r[2].service, { kind = "weapon", npcIDs = { 11870 } })       -- Archibald
  end,
  -- the row button
  pin_button_only_on_service_rows = function()
    services(); load_addon()
    rule("a", { { text = "with", service = { kind = "repair" } }, { text = "without" } })
    assert_true(rowWith("with").pinButton:IsShown())
    assert_true(not rowWith("without").pinButton:IsShown())
  end,
  pin_button_marks_then_unmarks = function()
    services(); load_addon()
    rule("a", { { text = "with", service = { kind = "repair" } } })
    local button = rowWith("with").pinButton
    WOW.Click(button, "LeftButton")
    assert_eq(NewbieNudge.Services:MarkOf("repair").npcID, 1)
    assert_eq(NewbieNudge.Services:MarkOf("repair").fromRow, true)
    assert_true(button.marked, "button shows the mark")
    WOW.Click(button, "LeftButton")
    assert_true(not NewbieNudge.Services:IsMarked("repair"))
  end,
  weapon_rows_mark_only_their_trainers = function()
    services(); load_addon()
    rule("a", { { text = "with", service = { kind = "weapon", npcIDs = { 9 } } } })
    WOW.Click(rowWith("with").pinButton, "LeftButton")
    assert_eq(NewbieNudge.Services:MarkOf("weapon").npcID, 9)
  end,
  ctrl_click_in_the_strip_marks = function()
    services(); load_addon()
    NewbieNudge.Panel:SetStyle("icons")
    rule("a", { { text = "with", service = { kind = "inn" } } })
    WOW.state.ctrlDown = true
    WOW.Click(iconWith("with"), "LeftButton")
    assert_true(NewbieNudge.Services:IsMarked("inn"))
  end,
  tooltip_hint_on_service_rows = function()
    services(); load_addon()
    rule("a", { { text = "with", service = { kind = "inn" } } })
    WOW.Hover(rowWith("with"))
    assert_true(tContains(GameTooltip.lines, L().ROW_HINT_MARK))
  end,
  row_mark_goes_when_the_row_does = function()
    services(); load_addon()
    local result = { { text = "with", service = { kind = "repair" } } }
    NewbieNudge:RegisterRule({ name = "a", title = "T", help = "H", events = {},
      applies = function() return true end, check = function() return result end })
    NewbieNudge:MarkAllDirty(); run_checks()
    WOW.Click(rowWith("with").pinButton, "LeftButton")
    result = nil
    NewbieNudge:MarkAllDirty(); NewbieNudge:Schedule(); run_checks()
    assert_true(not NewbieNudge.Services:IsMarked("repair"))
  end,
  -- menu, options, slash
  menu_services_checkbox_and_clear_marks = function()
    services(); load_addon()
    local e = entry(L().MENU_SERVICES)
    assert_eq(e.kind, "checkbox"); assert_eq(e.checked, false)
    e.onClick()
    assert_eq(NewbieNudge.db.services.showAll, true)
    assert_nil(entry(L().MENU_CLEAR_MARKS))
    NewbieNudge.Services:Mark("inn", 7, false)
    entry(L().MENU_CLEAR_MARKS).onClick()
    assert_eq(#NewbieNudge.Services:Marks(), 0)
  end,
  options_checkbox_round_trips = function()
    load_addon()
    local s = WOW.settings["NN_services_showAll"]
    assert_eq(s.getter(), false)
    s.setter(true)
    assert_eq(NewbieNudge.db.services.showAll, true)
  end,
  slash_services_toggles = function()
    load_addon()
    NewbieNudge:HandleSlash("services")
    assert_eq(NewbieNudge.db.services.showAll, true)
    assert_eq(WOW.printed[#WOW.printed], L().CHAT_PREFIX .. L().SLASH_SERVICES_ON)
    NewbieNudge:HandleSlash("services")
    assert_eq(WOW.printed[#WOW.printed], L().CHAT_PREFIX .. L().SLASH_SERVICES_OFF)
  end,
}
