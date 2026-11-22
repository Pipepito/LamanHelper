-- Rule flight_path: a flight master in the current zone you have not unlocked.
local L = function() return NewbieNudge.L end
local U, R, C = 2, 1, 0
local function zone(mapID, nodes)
  WOW.state.mapID = mapID; WOW.state.mapInfo[mapID] = { name = "Westfall", mapType = 3 }
  WOW.state.taxiNodes[mapID] = nodes
end
local function run() load_addon(); WOW.FireEvent("ZONE_CHANGED_NEW_AREA"); run_checks() end

return {
  unreachable_node_in_zone_makes_a_row = function()
    zone(1436, { { name = "Sentinel Hill", state = U }, { name = "Moonbrook", state = R } })
    run()
    local r = results_of("flight_path")
    assert_eq(r[1].text, L().FLIGHT_PATH_ROW:format("Westfall", "Sentinel Hill"))
    r[1].onClick(); assert_eq(WOW.calls[#WOW.calls][1], "ToggleWorldMap")
  end,
  all_known_no_row = function()
    zone(1436, { { name = "Sentinel Hill", state = C }, { name = "Moonbrook", state = R } })
    run(); assert_eq(#results_of("flight_path"), 0)
  end,
  two_names_joined_more_counted = function()
    zone(1436, { { name = "A", state = U }, { name = "B", state = U }, { name = "C", state = U } })
    run()
    assert_eq(results_of("flight_path")[1].text, L().FLIGHT_PATH_ROW_MANY:format("Westfall", "A, B", 1))
  end,
  learning_it_clears_the_row = function()
    local nodes = { { name = "Sentinel Hill", state = U } }
    zone(1436, nodes); run(); assert_eq(#results_of("flight_path"), 1)
    nodes[1].state = R; WOW.FireEvent("TAXIMAP_CLOSED"); run_checks()
    assert_eq(#results_of("flight_path"), 0)
  end,
  silent_in_instances_and_without_api = function()
    zone(1436, { { name = "Sentinel Hill", state = U } })
    WOW.state.instanceType = "party"; load_addon(); WOW.state.instanceType = "none"
    WOW.state.instanceType = "party"; WOW.FireEvent("ZONE_CHANGED_NEW_AREA"); run_checks()
    assert_eq(#results_of("flight_path"), 0)
    _G.C_TaxiMap = nil; WOW.state.instanceType = "none"; wipe(NewbieNudge.appliesCache)
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.flight_path))
  end,
  -- Forever: no state on map nodes; judged from the remembered flight points
  no_state_and_no_flight_map_seen_is_silent = function()
    zone(1436, { { name = "Sentinel Hill" } })
    WOW.state.mapInfo[1436].parentMapID = 1415; WOW.state.mapInfo[1415] = { name = "Eastern Kingdoms", mapType = 2 }
    run()
    assert_eq(#results_of("flight_path"), 0)
  end,
  no_state_unknown_point_after_a_flight_map_was_seen = function()
    zone(1436, { { name = "Sentinel Hill" }, { name = "Moonbrook" } })
    WOW.state.mapInfo[1436].parentMapID = 1415; WOW.state.mapInfo[1415] = { name = "Eastern Kingdoms", mapType = 2 }
    load_addon()
    WOW.state.taxiMap = { mapID = 1415, nodes = { { name = "Moonbrook", state = 0 }, { name = "Sentinel Hill", state = 2 } } }
    WOW.FireEvent("TAXIMAP_OPENED"); WOW.FireEvent("TAXIMAP_CLOSED"); run_checks()
    assert_eq(results_of("flight_path")[1].text, L().FLIGHT_PATH_ROW:format("Westfall", "Sentinel Hill"))
  end,
  other_factions_points_are_skipped = function()
    WOW.state.faction = "Horde"
    zone(1436, { { name = "Sentinel Hill", faction = 2 } })
    WOW.state.mapInfo[1436].parentMapID = 1415; WOW.state.mapInfo[1415] = { name = "Eastern Kingdoms", mapType = 2 }
    load_addon()
    WOW.state.taxiMap = { mapID = 1415, nodes = {} }
    WOW.FireEvent("TAXIMAP_OPENED"); WOW.FireEvent("TAXIMAP_CLOSED"); run_checks()
    assert_eq(#results_of("flight_path"), 0)
  end,
  row_marks_flight_masters = function()
    zone(1436, { { name = "Sentinel Hill", state = U } })
    run()
    local service = results_of("flight_path")[1].service
    assert_eq(service.kind, "flight")
    assert_true(#service.npcIDs > 0, "the zone's undiscovered flight masters")
  end,
  -- Forever may give no faction on map nodes: the flight master in the
  -- NPC data at the same spot tells whose it is
  other_factions_point_skipped_without_a_faction_field = function()
    WOW.state.faction = "Horde"
    zone(1436, { { name = "Sentinel Hill", position = { x = 0.5, y = 0.5 } } })
    WOW.state.mapInfo[1436].parentMapID = 1415; WOW.state.mapInfo[1415] = { name = "Eastern Kingdoms", mapType = 2 }
    load_addon()
    NewbieNudge.ServiceData = { npcs = { [523] = { "Thor", "Gryphon Master", 1436, 50.5, 49.5, "A" } }, kinds = { flight = { 523 } } }
    WOW.state.taxiMap = { mapID = 1415, nodes = { { name = "Grom'gol", state = 0 } } }
    WOW.FireEvent("TAXIMAP_OPENED"); WOW.FireEvent("TAXIMAP_CLOSED"); run_checks()
    assert_eq(#results_of("flight_path"), 0)
  end,
}
