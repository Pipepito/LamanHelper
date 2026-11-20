-- Rule mount: save up from 30, learn to ride at 40.
local L = function() return NewbieNudge.L end
local function run() load_addon(); WOW.FireEvent("PLAYER_MONEY"); run_checks() end

return {
  save_up_row_between_30_and_39_when_poor = function()
    WOW.state.level = 32; WOW.state.money = 200000 -- 20 gold
    run()
    assert_eq(results_of("mount")[1].text, L().MOUNT_ROW_SAVE:format("200000c"))
    WOW.state.money = 1200000; WOW.FireEvent("PLAYER_MONEY"); run_checks()
    assert_eq(#results_of("mount"), 0, "120 gold is enough")
  end,
  not_applicable_below_30 = function()
    WOW.state.level = 29; load_addon()
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.mount))
  end,
  riding_row_at_40_without_skill_when_api_present = function()
    WOW.state.level = 40; WOW.state.money = 50
    load_addon()
    NewbieNudge.HasRidingSkill = function() return false end
    WOW.FireEvent("PLAYER_LEVEL_UP", 40); run_checks()
    assert_eq(results_of("mount")[1].text, L().MOUNT_ROW_RIDE)
    NewbieNudge.HasRidingSkill = function() return true end
    WOW.FireEvent("SKILL_LINES_CHANGED"); run_checks()
    assert_eq(#results_of("mount"), 0)
  end,
  riding_row_silent_without_skill_api = function()
    WOW.state.level = 40; WOW.state.money = 50
    load_addon()
    NewbieNudge.HasRidingSkill = function() return nil end
    WOW.FireEvent("PLAYER_LEVEL_UP", 40); run_checks()
    assert_eq(#results_of("mount"), 0, "no save-up row at 40 and no riding row without the API")
  end,
}
