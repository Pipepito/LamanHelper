-- FlightPoints (v4): Forever's map flight-point list has no "discovered"
-- state (snapshot 2026-11-22: state nil on all 38 Kalimdor nodes), so the
-- addon remembers the flight points the player knows whenever a flight
-- master's map is open.
local function FP() return NewbieNudge.FlightPoints end
local function barrens()
  WOW.state.mapID = 1413
  WOW.state.mapInfo[1413] = { name = "The Barrens", mapType = 3, parentMapID = 1414 }
  WOW.state.mapInfo[1414] = { name = "Kalimdor", mapType = 2 }
end

return {
  records_known_points_from_the_flight_map = function()
    barrens(); load_addon()
    WOW.state.taxiMap = { mapID = 1414, nodes = {
      { name = "Crossroads, The Barrens", state = 0 }, { name = "Orgrimmar, Durotar", state = 1 }, { name = "Ratchet, The Barrens", state = 2 },
    } }
    WOW.FireEvent("TAXIMAP_OPENED")
    assert_true(FP():IsKnown("Crossroads, The Barrens")); assert_true(FP():IsKnown("Orgrimmar, Durotar"))
    assert_true(not FP():IsKnown("Ratchet, The Barrens"))
    assert_true(FP():Seen(1414)); assert_true(not FP():Seen(1415))
    assert_eq(NewbieNudge.db.flights.known["Orgrimmar, Durotar"], true, "saved per character")
  end,
  classic_calls_when_the_modern_one_is_missing = function()
    barrens(); C_TaxiMap.GetAllTaxiNodes = nil
    load_addon()
    WOW.state.taxiClassic = { { name = "Crossroads, The Barrens", type = "CURRENT" }, { name = "Orgrimmar, Durotar", type = "REACHABLE" },
      { name = "Thunder Bluff, Mulgore", type = "DISTANT" }, { name = "Ratchet, The Barrens", type = "NONE" } }
    WOW.FireEvent("TAXIMAP_OPENED")
    assert_true(FP():IsKnown("Thunder Bluff, Mulgore")); assert_true(not FP():IsKnown("Ratchet, The Barrens"))
  end,
  never_forgets_a_point = function()
    barrens(); load_addon()
    WOW.state.taxiMap = { mapID = 1414, nodes = { { name = "Orgrimmar, Durotar", state = 1 } } }
    WOW.FireEvent("TAXIMAP_OPENED")
    WOW.state.taxiMap = { mapID = 1414, nodes = { { name = "Orgrimmar, Durotar", state = 2 } } }
    WOW.FireEvent("TAXIMAP_OPENED")
    assert_true(FP():IsKnown("Orgrimmar, Durotar"))
  end,
  routes_use_the_remembered_points = function()
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/services.lua" }
    load_addon()
    for _, node in ipairs(WOW.state.taxiNodes[1414]) do node.state = nil end -- as on Forever
    assert_eq(#NewbieNudge.Services:FlightMasters(), 0, "nothing known yet")
    NewbieNudge.db.flights.known = { ["Near Field"] = true, ["City Port"] = true }
    local _, route = NewbieNudge.Services:TravelTime(5)
    assert_eq(route, { kind = "fly", from = "Near Field", to = "City Port" })
  end,
  -- review: the modern call may carry no state either
  modern_call_without_state_falls_back_to_classic = function()
    barrens(); load_addon()
    WOW.state.taxiMap = { mapID = 1414, nodes = { { name = "Crossroads, The Barrens" }, { name = "Orgrimmar, Durotar" } } }
    WOW.state.taxiClassic = { { name = "Crossroads, The Barrens", type = "CURRENT" }, { name = "Orgrimmar, Durotar", type = "NONE" } }
    WOW.FireEvent("TAXIMAP_OPENED")
    assert_true(FP():IsKnown("Crossroads, The Barrens"))
    assert_true(not FP():IsKnown("Orgrimmar, Durotar"))
    assert_true(FP():Seen(1414))
  end,
  nothing_recorded_means_not_seen = function()
    barrens(); load_addon()
    WOW.state.taxiMap = { mapID = 1414, nodes = { { name = "Crossroads, The Barrens" } } }
    WOW.state.taxiClassic = {}
    WOW.FireEvent("TAXIMAP_OPENED")
    assert_true(not FP():Seen(1414), "a continent with nothing recorded isn't judged")
  end,
}
