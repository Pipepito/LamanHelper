-- Rules dungeon_ready and zone_level.
local L = function() return NewbieNudge.L end
local function setup() WOW.extraFiles = { TESTS_DIR .. "/fixtures/dungeons_zones.lua" }; WOW.state.zoneNames = { [36] = "Las Minas" } end
local function run() load_addon(); WOW.FireEvent("PLAYER_LEVEL_UP", WOW.state.level); run_checks() end

return {
  dungeons_in_range_for_faction_sorted_by_min = function()
    setup(); WOW.state.level = 18; WOW.state.faction = "Horde"
    run() -- RFC 13-18 (horde) and WC 17-24 (neutral); Deadmines is alliance
    local r = results_of("dungeon_ready")
    assert_eq(#r, 2)
    assert_eq(r[1].text, L().DUNGEON_ROW:format("Ragefire Chasm", 13, 18))
    r[1].onClick(); assert_eq(WOW.calls[#WOW.calls], { "OpenWorldMap", 1454 })
  end,
  client_name_preferred = function()
    setup(); WOW.state.level = 20; WOW.state.faction = "Alliance"
    run(); assert_eq(results_of("dungeon_ready")[1].text, L().DUNGEON_ROW:format("Las Minas", 16, 26))
  end,
  seen_after_entering_or_half_quests_done = function()
    setup(); WOW.state.level = 20; WOW.state.faction = "Alliance"
    run(); assert_eq(#results_of("dungeon_ready"), 2)
    WOW.state.completedQuests[166] = true; WOW.FireEvent("QUEST_TURNED_IN", 166); run_checks()
    assert_eq(#results_of("dungeon_ready"), 1, "half of Deadmines quests done")
    WOW.state.instance = { name = "Wailing Caverns", type = "party", instanceID = 43 }
    WOW.FireEvent("PLAYER_ENTERING_WORLD", false, true)
    WOW.state.instance = { name = "", type = "none", instanceID = 0 }
    WOW.FireEvent("ZONE_CHANGED_NEW_AREA"); run_checks()
    assert_eq(#results_of("dungeon_ready"), 0)
    assert_eq(NewbieNudge.db.seen.dungeons[43], true)
  end,
  zone_below_and_above = function()
    setup()
    WOW.state.mapInfo = {
      [1440] = { name = "Ashenvale", mapType = 3, parentMapID = 1414 },
      [1414] = { name = "Kalimdor", mapType = 2 },
      [7001] = { name = "Astranaar", mapType = 5, parentMapID = 1440 },
    }
    WOW.state.mapID = 7001; WOW.state.level = 33
    run(); assert_eq(results_of("zone_level")[1].text, L().ZONE_BELOW_ROW:format("Ashenvale", 19, 30))
    results_of("zone_level")[1].onClick(); assert_eq(WOW.calls[#WOW.calls][1], "ToggleWorldMap")
    WOW.state.level = 16; WOW.FireEvent("ZONE_CHANGED_NEW_AREA"); run_checks()
    assert_eq(results_of("zone_level")[1].text, L().ZONE_ABOVE_ROW:format("Ashenvale", 19, 30))
    WOW.state.level = 25; WOW.FireEvent("ZONE_CHANGED_NEW_AREA"); run_checks()
    assert_eq(#results_of("zone_level"), 0)
  end,
  zone_rule_silent_in_instances_and_unknown_maps = function()
    setup(); WOW.state.mapInfo = { [1440] = { name = "Ashenvale", mapType = 3 } }; WOW.state.mapID = 1440; WOW.state.level = 40
    load_addon()
    WOW.state.instanceType = "party"; WOW.FireEvent("ZONE_CHANGED_NEW_AREA"); run_checks()
    assert_eq(#results_of("zone_level"), 0, "frozen/silent inside an instance")
    WOW.state.instanceType = "none"; WOW.state.mapID = 5555; WOW.FireEvent("ZONE_CHANGED_NEW_AREA"); run_checks()
    assert_eq(#results_of("zone_level"), 0, "unknown map")
  end,
}
