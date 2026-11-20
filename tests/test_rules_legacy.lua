-- Rule legacy: the Legacy system nudge at 25 and unviewed challenges.
local L = function() return NewbieNudge.L end
local function run() load_addon(); WOW.FireEvent("PLAYER_LEVEL_UP", WOW.state.level); run_checks() end

return {
  unlock_nudge_at_25_until_the_window_is_opened = function()
    WOW.state.level = 25
    run()
    local r = results_of("legacy")
    assert_eq(r[1].text, L().LEGACY_ROW_UNLOCK)
    r[1].onClick(); assert_eq(WOW.calls[#WOW.calls][1], "ToggleLegacySystemUI")
    run_checks()
    assert_eq(#results_of("legacy"), 0, "opening the window counts as seen")
    assert_eq(NewbieNudge.db.seen.legacy, true)
  end,
  unviewed_challenges_row = function()
    WOW.state.level = 30; _G.NewbieNudgeDB = { seen = { legacy = true } }
    load_addon(); LegacyChallengesUnviewed[101] = true
    WOW.FireEvent("PLAYER_ENTERING_WORLD", false, false); run_checks()
    assert_eq(results_of("legacy")[1].text, L().LEGACY_ROW_CHALLENGES)
    LegacyChallengesUnviewed[101] = nil; WOW.AdvanceTime(31)
    assert_eq(#results_of("legacy"), 0)
  end,
  not_applicable_below_25_or_without_the_window = function()
    WOW.state.level = 20; load_addon()
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.legacy))
    _G.ToggleLegacySystemUI = nil; WOW.state.level = 30; wipe(NewbieNudge.appliesCache)
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.legacy))
  end,
}
