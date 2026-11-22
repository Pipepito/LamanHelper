-- Services (v4): the closest suitable NPC for a service, and map marks.
local L = function() return NewbieNudge.L end
local function S() return NewbieNudge.Services end
local function load(state)
  WOW.extraFiles = { TESTS_DIR .. "/fixtures/services.lua" }
  if state then state() end
  load_addon()
end
local function said(text) return WOW.printed[#WOW.printed]:find(text, 1, true) ~= nil end
local function calls(name)
  local out = {}
  for _, c in ipairs(WOW.calls) do if c[1] == name then out[#out + 1] = c end end
  return out
end

return {
  closest_by_world_distance = function()
    load()
    assert_eq(S():Closest("repair"), 1)
  end,
  faction_filter = function()
    load(); WOW.state.faction = "Horde"
    assert_eq(S():Closest("repair"), 3)
  end,
  level_filter_skips_zones_above_level_plus_three = function()
    load()
    WOW.state.level = 20
    assert_true(not tContains(S():Candidates("repair"), 4), "level 30 zone skipped at 20")
    WOW.state.level = 27
    assert_true(tContains(S():Candidates("repair"), 4), "allowed at 27")
  end,
  cities_have_no_level_range_and_are_allowed = function()
    load(); WOW.state.level = 1
    assert_true(tContains(S():Candidates("repair"), 5))
  end,
  same_continent_beats_a_nearer_other_continent = function()
    load()
    -- 6 sits at the same coordinates as the player but on another continent
    assert_eq(S():Closest("repair", { 6, 5 }), 5)
    assert_eq(S():Closest("repair", { 6 }), 6, "still chosen when it's the only one")
  end,
  unreadable_position = function()
    load(); WOW.state.playerPos = nil
    local id, reason = S():Closest("repair")
    assert_nil(id); assert_eq(reason, "position")
    assert_nil(S():MarkClosest("repair", nil, true))
    assert_true(said(L().SERVICES_NO_POSITION))
    assert_eq(#S():Marks(), 0)
  end,
  nothing_suitable = function()
    load(); WOW.state.faction = "Horde"
    assert_nil(S():MarkClosest("inn", nil, true))
    assert_true(said(L().SERVICES_NONE:format(L().SERVICE_KIND_INN)))
  end,
  mark_closest_marks_says_and_opens_the_map = function()
    load()
    assert_eq(S():MarkClosest("repair", nil, true), 1)
    assert_true(S():IsMarked("repair"))
    assert_true(said(L().SERVICES_MARKED:format("Near Smith", "Armorer", "Elwynn Forest")))
    assert_eq(calls("OpenWorldMap")[1][2], 1429)
  end,
  same_kind_replaces_and_marks_are_saved = function()
    load()
    S():Mark("repair", 1, true); S():Mark("repair", 2, true); S():Mark("inn", 7, false)
    local marks = S():Marks()
    assert_eq(#marks, 2)
    assert_eq(NewbieNudge.db.marks, { { kind = "repair", npcs = { 2 }, npcID = 2, fromRow = true }, { kind = "inn", npcs = { 7 }, npcID = 7, fromRow = false } })
  end,
  unknown_npc_dropped_on_load = function()
    load(function() _G.NewbieNudgeDB = { marks = { { kind = "repair", npcID = 999, fromRow = true }, { kind = "inn", npcID = 7 } } } end)
    assert_eq(#S():Marks(), 1)
    assert_eq(S():Marks()[1].npcID, 7)
  end,
  unmark_and_clear = function()
    load()
    S():Mark("repair", 1, true); S():Mark("inn", 7, true)
    S():Unmark("repair")
    assert_true(not S():IsMarked("repair")); assert_true(S():IsMarked("inn"))
    S():ClearMarks()
    assert_eq(#S():Marks(), 0)
  end,
  weapon_rows_restrict_candidates = function()
    load()
    assert_eq(S():Closest("weapon", { 9 }), 9)
  end,
  prune_removes_row_marks_whose_reminder_went_away = function()
    load()
    S():Mark("repair", 1, true); S():Mark("inn", 7, false); S():Mark("trainer_MAGE", 8, true)
    S():PruneRowMarks({ trainer_MAGE = true })
    assert_true(not S():IsMarked("repair"), "row mark gone")
    assert_true(S():IsMarked("inn"), "map-made mark kept")
    assert_true(S():IsMarked("trainer_MAGE"), "still-active row kept")
  end,
  tracking_turned_on_for_repair_inn_and_supplies = function()
    load()
    S():MarkClosest("repair", nil, true)
    assert_eq(WOW.state.tracking[2].active, true)
    S():MarkClosest("inn", nil, true)
    assert_eq(WOW.state.tracking[3].active, true)
    S():MarkClosest("supplies", nil, true)
    assert_eq(WOW.state.tracking[4].active, true)
  end,
  no_tracking_for_trainers = function()
    load()
    S():MarkClosest("trainer_MAGE", nil, true)
    assert_eq(#calls("SetTracking"), 0)
  end,
  -- v4 §4g: quickest route, counting discovered flight points
  walking_wins_when_near = function()
    load()
    local _, route = S():TravelTime(1)
    assert_eq(route.kind, "foot")
  end,
  flying_wins_with_both_flight_points_known = function()
    load()
    local fly, route = S():TravelTime(5)
    assert_eq(route, { kind = "fly", from = "Near Field", to = "City Port" })
    assert_true(fly < 1900 / 7, "quicker than running all the way")
  end,
  undiscovered_landing_point_is_ignored = function()
    load(); WOW.state.level = 30
    local _, route = S():TravelTime(4)
    assert_eq(route.kind, "foot")
  end,
  no_taxi_api_means_straight_line = function()
    load(); C_TaxiMap = nil
    local _, route = S():TravelTime(5)
    assert_eq(route.kind, "foot")
  end,
  ranked_quickest_first_one_per_map = function()
    load()
    local ids = {}
    for _, r in ipairs(S():Ranked("repair", nil, 4)) do ids[#ids + 1] = r.id end
    -- 1 and 2 share map 1429 (1 is nearer); 5 by air; 6 on another continent last
    assert_eq(ids, { 1, 5, 6 })
  end,
  chat_names_the_flight = function()
    load()
    S():MarkClosest("weapon", { 11867 }, true)
    assert_true(said(L().SERVICES_ROUTE_FLY:format("Near Field", "City Port")))
  end,
  -- v4 §4g: several options per mark
  mark_closest_marks_up_to_n_options_one_per_map = function()
    load()
    S():MarkClosest("repair", nil, true)
    assert_eq(S():MarkOf("repair").npcs, { 1, 5, 6 })
    assert_eq(S():MarkOf("repair").npcID, 1, "best option first")
    assert_true(said(L().SERVICES_MORE:format(2)))
  end,
  one_option_setting = function()
    load()
    NewbieNudge.db.services.options = 1
    S():MarkClosest("repair", nil, true)
    assert_eq(S():MarkOf("repair").npcs, { 1 })
    assert_true(not said(L().SERVICES_MORE:format(0)))
  end,
  old_single_marks_load_as_one_option = function()
    load(function() _G.NewbieNudgeDB = { marks = { { kind = "inn", npcID = 7, fromRow = true } } } end)
    assert_eq(S():Marks()[1].npcs, { 7 })
  end,
  remove_one_option = function()
    load()
    S():Mark("repair", { 1, 5, 6 }, true)
    S():UnmarkOption("repair", 5)
    assert_eq(S():MarkOf("repair").npcs, { 1, 6 })
    S():UnmarkOption("repair", 1); S():UnmarkOption("repair", 6)
    assert_true(not S():IsMarked("repair"), "last option gone, mark gone")
  end,
  marked_check_against_a_rows_trainers = function()
    load()
    S():Mark("weapon", { 11867, 9 }, true)
    assert_true(S():IsMarked("weapon", { 9 }))
    assert_true(not S():IsMarked("weapon", { 12345 }))
  end,
}
