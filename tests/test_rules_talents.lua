local L = function() return NewbieNudge.L end

return {
  not_applicable_below_10 = function()
    WOW.state.level = 9
    WOW.state.talents.unspent = 3
    load_addon(); run_checks()
    assert_eq(#results_of("talents"), 0)
    assert_eq(NewbieNudge:Applies(NewbieNudge.ruleByName.talents), false)
  end,
  one_point_text = function()
    WOW.state.talents.unspent = 1
    load_addon(); run_checks()
    local r = results_of("talents")
    assert_eq(r[1].text, L().TALENTS_ROW_ONE)
    assert_eq(r[1].highlight, "talents")
    r[1].onClick()
    assert_eq(WOW.calls[#WOW.calls][1], "ToggleTalentFrame")
  end,
  many_points_text = function()
    WOW.state.talents.unspent = 4
    load_addon(); run_checks()
    assert_eq(results_of("talents")[1].text, L().TALENTS_ROW_MANY:format(4))
  end,
  zero_points_nothing = function()
    load_addon(); run_checks()
    assert_eq(#results_of("talents"), 0)
  end,
  missing_config_is_silent = function()
    WOW.state.talents.unspent = 4
    WOW.state.talents.configID = nil
    load_addon(); run_checks()
    assert_eq(#results_of("talents"), 0)
  end,
  secret_quantity_keeps_previous = function()
    WOW.state.talents.unspent = 2
    load_addon(); run_checks()
    WOW.state.talents.unspent = WOW.secret(0)
    WOW.FireEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED"); run_checks()
    assert_eq(results_of("talents")[1].text, L().TALENTS_ROW_MANY:format(2))
  end,
  click_falls_back_to_player_spells_util = function()
    WOW.state.talents.unspent = 1
    _G.ToggleTalentFrame = nil
    local opened = false
    _G.PlayerSpellsUtil = { ToggleClassTalentFrame = function() opened = true end }
    load_addon(); run_checks()
    results_of("talents")[1].onClick()
    assert_true(opened)
  end,
}
