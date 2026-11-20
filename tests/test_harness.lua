return {
  stub_fires_events_to_registered_frames = function()
    local got
    local f = CreateFrame("Frame")
    f:RegisterEvent("BAG_UPDATE_DELAYED")
    f:SetScript("OnEvent", function(_, e, a) got = e .. ":" .. tostring(a) end)
    WOW.FireEvent("BAG_UPDATE_DELAYED", 7)
    assert_eq(got, "BAG_UPDATE_DELAYED:7")
  end,
  timers_fire_when_time_advances = function()
    local n = 0
    C_Timer.After(0.5, function() n = n + 1 end)
    WOW.AdvanceTime(0.4); assert_eq(n, 0)
    WOW.AdvanceTime(0.2); assert_eq(n, 1)
  end,
  secret_marker_is_detected = function()
    assert_true(issecretvalue(WOW.secret(5)))
    assert_true(not issecretvalue(5))
  end,
  print_is_captured = function()
    print("hello", 3)
    assert_eq(WOW.printed[#WOW.printed], "hello 3")
  end,
  lua_is_51_semantics = function()
    assert_eq(_VERSION, "Lua 5.1")
    assert_eq(string.format("%d", 3), "3")
  end,
}
