-- Rule hearth_bind: an innkeeper far from where the Hearthstone is set.
local L = function() return NewbieNudge.L end
local BIND_ICON = 132052
local function innkeeper()
  WOW.state.gossipOptions = {
    { name = "I want to browse your goods.", icon = 132060, gossipOptionID = 1 },
    { name = "Make this inn your home.", icon = BIND_ICON, gossipOptionID = 3 },
  }
end
local function talk() WOW.FireEvent("GOSSIP_SHOW"); run_checks() end

return {
  innkeeper_elsewhere_shows_row_and_says_once = function()
    WOW.state.bindLocation = "Goldshire"; WOW.state.subZone = "Sentinel Hill"; WOW.state.zone = "Westfall"
    load_addon(); innkeeper()
    local printed = #WOW.printed
    talk()
    local r = results_of("hearth_bind")
    assert_eq(r[1].text, L().HEARTH_BIND_ROW:format("Goldshire"))
    assert_eq(#WOW.printed, printed + 1)
    WOW.FireEvent("GOSSIP_CLOSED"); run_checks()
    talk()
    assert_eq(#WOW.printed, printed + 1, "second visit this session says nothing")
    assert_eq(#results_of("hearth_bind"), 1, "but the row still shows")
  end,
  same_inn_no_row = function()
    WOW.state.bindLocation = "Goldshire"; WOW.state.subZone = "Goldshire"; WOW.state.zone = "Elwynn Forest"
    load_addon(); innkeeper(); talk()
    assert_eq(#results_of("hearth_bind"), 0)
  end,
  non_innkeeper_gossip_ignored = function()
    WOW.state.bindLocation = "Goldshire"; WOW.state.subZone = "Sentinel Hill"; WOW.state.zone = "Westfall"
    load_addon(); WOW.state.gossipOptions = { { name = "What is this place?", icon = 132053 } }
    talk(); assert_eq(#results_of("hearth_bind"), 0)
  end,
  row_clears_on_gossip_closed = function()
    WOW.state.bindLocation = "Goldshire"; WOW.state.subZone = "Sentinel Hill"; WOW.state.zone = "Westfall"
    load_addon(); innkeeper(); talk()
    assert_eq(#results_of("hearth_bind"), 1)
    WOW.FireEvent("GOSSIP_CLOSED"); run_checks()
    assert_eq(#results_of("hearth_bind"), 0)
  end,
}
