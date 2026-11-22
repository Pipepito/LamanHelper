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
local function kindRow(kind)
  for _, row in ipairs(rows("kindKey")) do if row.kindKey == kind then return row end end
end
local function markRow(npcID)
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
    assert_eq(kindRow("inn").checked, true, "other kinds follow the master switch")
    WOW.Click(kindRow("repair"), "LeftButton")
    assert_eq(NewbieNudge.db.services.kinds.repair, false)
    assert_eq(kindRow("repair").checked, false)
    WOW.ViewMap(1429)
    for _, pin in ipairs(NewbieNudge.MapPins.pins) do
      if pin:IsShown() then assert_true(pin.kind ~= "repair", "no repair pins") end
    end
    assert_true(#NewbieNudge.MapPins.pins > 0, "other kinds still drawn")
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
    local opened
    for _, c in ipairs(WOW.calls) do if c[1] == "OpenToCategory" then opened = c[2] end end
    assert_eq(opened, NewbieNudge.L.OPT_MAP)
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
    for _, row in ipairs(rows("markKind")) do if row.isHeading then heading = row end end
    assert_true(heading, "heading row")
    assert_eq(heading.label:GetText(), ML().KindLabel("repair"))
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
}
