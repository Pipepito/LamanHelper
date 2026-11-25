-- MapList (v4): the NewbieNudge list on the world map.
local L = function() return NewbieNudge.L end
local function load(state)
  WOW.extraFiles = { TESTS_DIR .. "/fixtures/services.lua" }
  if state then state() end
  load_addon()
end
local function ML() return NewbieNudge.MapList end
local function rows(field)
  local out = {}
  for _, row in ipairs(ML().rows) do if row:IsShown() and row[field] ~= nil then out[#out + 1] = row end end
  return out
end
-- Opens the professions section and every mark, for tests about their lines.
local function openAll()
  NewbieNudge.db.map.sections.professions = true
  for _, m in ipairs(NewbieNudge.Services:Marks()) do NewbieNudge.db.map.openMarks[m.kind] = true end
  ML():Refresh()
end
local function kindRow(kind)
  if kind:find("^prof_") then openAll() end
  for _, row in ipairs(rows("kindKey")) do if row.kindKey == kind then return row end end
end
local function markRow(npcID)
  openAll()
  for _, row in ipairs(rows("npcID")) do if row.npcID == npcID then return row end end
end
local function herbalist()
  WOW.state.professions = { prof1 = 1 }
  WOW.state.professionInfo = { [1] = { name = "Herbalism", skill = 1, maxSkill = 75, skillLine = 182 } }
end

return {
  left_click_toggles_the_list = function()
    load()
    WOW.Click(NewbieNudgeMapButton, "LeftButton")
    assert_true(ML().frame:IsShown()); assert_eq(NewbieNudge.db.map.listOpen, true)
    WOW.Click(NewbieNudgeMapButton, "LeftButton")
    assert_true(not ML().frame:IsShown()); assert_eq(NewbieNudge.db.map.listOpen, false)
  end,
  right_click_still_toggles_unexplored_areas = function()
    load()
    WOW.Click(NewbieNudgeMapButton, "RightButton")
    assert_eq(NewbieNudge.db.map.reveal, false)
  end,
  reveal_row_then_one_row_per_service_kind = function()
    load(herbalist)
    ML():Toggle()
    openAll()
    local first = ML().rows[1]
    assert_true(first.isReveal); assert_eq(first.label:GetText(), L().MAPLIST_REVEAL); assert_eq(first.checked, true)
    local kinds = {}
    for _, row in ipairs(rows("kindKey")) do kinds[#kinds + 1] = row.kindKey end
    assert_eq(kinds, NewbieNudge.MapPins.ShowAllKinds())
    assert_eq(kindRow("repair").label:GetText(), L().MAPLIST_KIND_REPAIR)
    assert_eq(kindRow("trainer_MAGE").label:GetText(), L().MAPLIST_KIND_TRAINER:format("Mage"))
    assert_eq(kindRow("prof_182").label:GetText(), L().MAPLIST_KIND_PROF:format("Herbalism"))
    assert_eq(kindRow("trainer_MAGE").icon.texture, "Interface\\TargetingFrame\\UI-Classes-Circles")
  end,
  reveal_row_click_toggles_unexplored_areas = function()
    load(); ML():Toggle()
    WOW.Click(ML().rows[1], "LeftButton")
    assert_eq(NewbieNudge.db.map.reveal, false)
    assert_eq(ML().rows[1].checked, false)
  end,
  kind_row_switches_that_kind_and_turns_services_on = function()
    load(); ML():Toggle()
    assert_eq(kindRow("repair").checked, false, "services start off")
    WOW.Click(kindRow("repair"), "LeftButton")
    assert_eq(NewbieNudge.db.services.kinds.repair, true)
    assert_eq(NewbieNudge.db.services.showAll, true)
    assert_eq(kindRow("repair").checked, true)
    assert_eq(kindRow("inn").checked, false, "only the ticked kind (owner, 2026-11-22)")
    WOW.Click(kindRow("inn"), "LeftButton") -- now repair and inn
    WOW.Click(kindRow("repair"), "LeftButton") -- inn only
    assert_eq(NewbieNudge.db.services.kinds.repair, false)
    assert_eq(kindRow("repair").checked, false)
    WOW.ViewMap(1429)
    local shown = 0
    for _, pin in ipairs(NewbieNudge.MapPins.pins) do
      if pin:IsShown() then shown = shown + 1; assert_true(pin.kind ~= "repair", "no repair pins") end
    end
    assert_true(shown > 0, "inn pins still drawn")
  end,
  rows_unchecked_while_services_are_off = function()
    load(); ML():Toggle()
    NewbieNudge.MapPins:SetShowAll(false)
    assert_eq(kindRow("inn").checked, false)
    NewbieNudge.MapPins:SetShowAll(true)
    assert_eq(kindRow("inn").checked, true)
  end,
  marks_listed_with_remove = function()
    load(); ML():Toggle()
    assert_true(ML().noneLabel:IsShown())
    NewbieNudge.Services:Mark("inn", 7, true)
    local row = markRow(7)
    assert_true(row.label:GetText():find("Innkeeper Farley · Elwynn Forest", 1, true), row.label:GetText())
    assert_true(not ML().noneLabel:IsShown())
    WOW.Click(row.removeButton, "LeftButton")
    assert_true(not NewbieNudge.Services:IsMarked("inn"))
    assert_nil(markRow(7))
  end,
  clicking_a_mark_shows_its_zone = function()
    load(); ML():Toggle()
    NewbieNudge.Services:Mark("weapon", 9, false)
    WOW.Click(markRow(9), "LeftButton")
    assert_eq(WOW.state.worldMapID, 1457)
  end,
  remove_all_and_settings = function()
    load(); ML():Toggle()
    NewbieNudge.Services:Mark("inn", 7, true); NewbieNudge.Services:Mark("repair", 1, true)
    WOW.Click(ML().removeAll, "LeftButton")
    assert_eq(#NewbieNudge.Services:Marks(), 0)
    WOW.Click(ML().settings, "LeftButton")
    local W = NewbieNudge.SettingsWindow
    assert_true(W.frame:IsShown())
    assert_eq(W.pages[W.page].title, NewbieNudge.L.OPT_MAP)
  end,
  reopens_with_the_map_when_left_open = function()
    load(function() _G.NewbieNudgeDB = { map = { listOpen = true } } end)
    WOW.ViewMap(1429)
    assert_true(ML().frame:IsShown())
  end,
  mark_heading_with_its_options = function()
    load(); ML():Toggle()
    NewbieNudge.Services:Mark("repair", { 1, 5 }, true)
    local heading
    openAll()
    for _, row in ipairs(rows("markKind")) do if row.isHeading then heading = row end end
    assert_true(heading, "heading row")
    assert_eq(heading.label:GetText(), ML().KindLabel("repair") .. " · " .. L().MAPLIST_OPTIONS:format(2))
    assert_true(markRow(1).label:GetText():find("1. Near Smith · Elwynn Forest", 1, true), markRow(1).label:GetText())
    assert_true(markRow(5).label:GetText():find("2. City Smith · Stormwind City", 1, true))
    WOW.Click(markRow(5).removeButton, "LeftButton")
    assert_eq(NewbieNudge.Services:MarkOf("repair").npcs, { 1 })
    for _, row in ipairs(rows("markKind")) do if row.isHeading then heading = row end end
    WOW.Click(heading.removeButton, "LeftButton")
    assert_true(not NewbieNudge.Services:IsMarked("repair"))
  end,
  options_setting_on_the_map_page = function()
    load()
    WOW.settings["NN_services_options"].setter(2)
    assert_eq(NewbieNudge.db.services.options, 2)
  end,
  -- review fixes
  ticking_one_kind_while_all_are_off_shows_only_that_kind = function()
    load(); ML():Toggle()
    WOW.Click(kindRow("inn"), "LeftButton")
    assert_eq(kindRow("inn").checked, true)
    assert_eq(kindRow("repair").checked, false, "the others stay off")
    WOW.Click(kindRow("inn"), "LeftButton")
    assert_eq(NewbieNudge.db.services.showAll, false, "last one off turns services off")
  end,
  long_lists_stay_inside_the_map_and_scroll = function()
    load(); ML():Toggle()
    WOW.state.taxiNodes = {}
    local S = NewbieNudge.Services
    S:Mark("repair", { 1, 2, 5, 6 }, true); S:Mark("inn", { 7 }, true); S:Mark("food", { 10 }, true)
    S:Mark("trainer_MAGE", { 8 }, true); S:Mark("weapon", { 11867, 9 }, true); S:Mark("prof_182", { 11 }, true)
    WorldMapFrame.ScrollContainer:SetSize(1002, 300)
    ML():Refresh()
    assert_true(ML().frame:GetHeight() <= 300, "height " .. ML().frame:GetHeight())
    assert_true(ML().content:GetHeight() > ML().scroll:GetHeight(), "content taller than the visible part")
    ML().scroll:Fire("OnMouseWheel", -1)
    assert_true(ML().scroll:GetVerticalScroll() > 0, "wheel scrolls")
  end,
  labels_stay_on_one_line = function()
    load(); ML():Toggle()
    NewbieNudge.Services:Mark("inn", { 7 }, true)
    assert_eq(markRow(7).label.maxLines, 1)
  end,
  option_remove_tooltip_names_an_option = function()
    load(); ML():Toggle()
    NewbieNudge.Services:Mark("inn", { 7 }, true)
    WOW.Hover(markRow(7).removeButton)
    assert_eq(GameTooltip.lines[1], L().MAPLIST_REMOVE_OPTION_TT)
  end,
  -- owner 2026-11-22: profession filter
  only_your_professions_are_ticked_at_first = function()
    load(herbalist); ML():Toggle()
    NewbieNudge.MapPins:SetShowAll(true)
    assert_eq(kindRow("prof_182").checked, true, "herbalism: yours")
    assert_eq(kindRow("prof_171").checked, false, "alchemy: not yours")
    assert_eq(kindRow("prof_171").label:GetText(), L().MAPLIST_KIND_PROF:format(L().PROF_NAME_171))
  end,
  ticking_another_profession_shows_its_trainers = function()
    load(herbalist); ML():Toggle()
    NewbieNudge.MapPins:SetShowAll(true)
    WOW.Click(kindRow("prof_171"), "LeftButton")
    assert_eq(kindRow("prof_171").checked, true)
    assert_true(NewbieNudge.MapPins.KindShown("prof_171"))
  end,
  my_professions_only_button = function()
    load(herbalist); ML():Toggle()
    NewbieNudge.MapPins:SetShowAll(true)
    WOW.Click(kindRow("prof_171"), "LeftButton")
    WOW.Click(kindRow("prof_182"), "LeftButton")
    openAll()
    WOW.Click(ML().myProfessions, "LeftButton")
    assert_eq(kindRow("prof_182").checked, true)
    assert_eq(kindRow("prof_171").checked, false)
    assert_eq(NewbieNudge.db.services.showAll, true)
  end,
  professions_section_has_its_header = function()
    load(herbalist); ML():Toggle()
    local header
    for _, row in ipairs(rows("sectionKey")) do if row.sectionKey == "professions" then header = row end end
    assert_eq(header.label:GetText(), L().MAPLIST_SECTION_PROF:format(0, 12), "services off: none shown")
    NewbieNudge.MapPins:SetShowAll(true)
    for _, row in ipairs(rows("sectionKey")) do if row.sectionKey == "professions" then header = row end end
    assert_eq(header.label:GetText(), L().MAPLIST_SECTION_PROF:format(1, 12))
  end,
  -- owner 2026-11-22: the list was too big; sections fold
  professions_section_starts_closed_and_remembers = function()
    load(herbalist); ML():Toggle()
    for _, row in ipairs(rows("kindKey")) do assert_true(not row.kindKey:find("^prof_"), "no profession lines while closed") end
    local header
    for _, row in ipairs(rows("sectionKey")) do if row.sectionKey == "professions" then header = row end end
    WOW.Click(header, "LeftButton")
    assert_eq(NewbieNudge.db.map.sections.professions, true)
    local found = false
    for _, row in ipairs(rows("kindKey")) do if row.kindKey == "prof_182" then found = true end end
    assert_true(found, "profession lines after opening")
  end,
  services_section_can_fold_too = function()
    load(); ML():Toggle()
    local header
    for _, row in ipairs(rows("sectionKey")) do if row.sectionKey == "services" then header = row end end
    WOW.Click(header, "LeftButton")
    assert_eq(#rows("kindKey"), 0)
  end,
  a_marks_options_fold_under_its_heading = function()
    load(); ML():Toggle()
    NewbieNudge.Services:Mark("repair", { 1, 5 }, true)
    assert_eq(#rows("npcID"), 0, "options closed at first")
    local heading
    for _, row in ipairs(rows("markKind")) do if row.isHeading then heading = row end end
    WOW.Click(heading, "LeftButton")
    assert_eq(#rows("npcID"), 2)
  end,
  my_professions_button_takes_clicks = function()
    load(herbalist); ML():Toggle()
    openAll()
    assert_true(ML().myProfessions.mouse, "mouse enabled")
    assert_eq(ML().myProfessions.clicks, { "LeftButtonUp" })
  end,
  level_filter_row_under_unexplored_areas = function()
    load(); ML():Toggle()
    local row = ML().rows[2]
    assert_true(row.isLevelFilter)
    assert_eq(row.label:GetText(), L().MAPLIST_LEVEL_FILTER)
    assert_eq(row.checked, true)
    WOW.Click(row, "LeftButton")
    assert_eq(NewbieNudge.db.services.levelFilter, false)
    assert_eq(ML().rows[2].checked, false)
  end,
  level_filter_setting_on_the_map_page = function()
    load()
    WOW.settings["NN_services_levelFilter"].setter(false)
    assert_eq(NewbieNudge.db.services.levelFilter, false)
  end,
  -- small review items
  list_never_taller_than_the_room_above_its_button = function()
    load(); ML():Toggle()
    local S = NewbieNudge.Services
    S:Mark("repair", { 1, 2, 5, 6 }, true); S:Mark("inn", { 7 }, true); S:Mark("food", { 10 }, true)
    S:Mark("trainer_MAGE", { 8 }, true); S:Mark("weapon", { 11867, 9 }, true); S:Mark("prof_182", { 11 }, true)
    openAll()
    WorldMapFrame.ScrollContainer:SetSize(1002, 300)
    ML():Refresh()
    assert_true(ML().frame:GetHeight() <= 300 - 44, "height " .. ML().frame:GetHeight())
  end,
  profession_count_is_zero_while_services_are_off = function()
    load(herbalist); ML():Toggle()
    local header
    for _, row in ipairs(rows("sectionKey")) do if row.sectionKey == "professions" then header = row end end
    assert_eq(header.label:GetText(), L().MAPLIST_SECTION_PROF:format(0, 12))
  end,
}
