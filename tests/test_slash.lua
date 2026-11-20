local function rule(name, applies)
  NewbieNudge:RegisterRule({
    name = name, title = "T_" .. name, help = "H", events = {},
    applies = applies or function() return true end,
    check = function() return { text = "x" } end,
  })
end

local function last() return WOW.printed[#WOW.printed] end
local function L() return NewbieNudge.L end

return {
  slash_command_is_registered = function()
    load_addon()
    assert_eq(SLASH_NEWBIENUDGE1, "/nudge")
    assert_eq(type(SlashCmdList.NEWBIENUDGE), "function")
  end,
  empty_opens_options = function()
    load_addon()
    local opened = false
    NewbieNudge.OpenOptions = function() opened = true end
    SlashCmdList.NEWBIENUDGE("")
    assert_true(opened)
  end,
  lock_toggles_and_prints = function()
    load_addon()
    NewbieNudge:HandleSlash("lock")
    assert_eq(NewbieNudge.db.panel.locked, false)
    assert_eq(last(), L().CHAT_PREFIX .. L().SLASH_UNLOCKED)
    NewbieNudge:HandleSlash("LOCK ")
    assert_eq(NewbieNudge.db.panel.locked, true)
    assert_eq(last(), L().CHAT_PREFIX .. L().SLASH_LOCKED)
  end,
  list_shows_each_rule_with_state = function()
    load_addon()
    rule("a"); rule("b"); rule("c", function() return false end)
    NewbieNudge:SetRuleEnabled("b", false)
    NewbieNudge:Snooze("a", 30)
    local before = #WOW.printed
    NewbieNudge:HandleSlash("list")
    assert_eq(WOW.printed[before + 1], L().CHAT_PREFIX .. L().SLASH_LIST_HEADER)
    assert_eq(#WOW.printed - before, 1 + #NewbieNudge.rules)
    assert_true(tContains(WOW.printed, L().SLASH_LIST_LINE:format("T_a", "a", L().STATE_SNOOZED)))
    assert_true(tContains(WOW.printed, L().SLASH_LIST_LINE:format("T_b", "b", L().STATE_OFF)))
    assert_true(tContains(WOW.printed, L().SLASH_LIST_LINE:format("T_c", "c", L().STATE_NA)))
  end,
  off_disables_rule = function()
    load_addon()
    rule("a")
    NewbieNudge:HandleSlash("off a")
    assert_eq(NewbieNudge.db.disabled.a, true)
    assert_eq(last(), L().CHAT_PREFIX .. L().SLASH_RULE_SET:format("T_a", L().STATE_OFF))
  end,
  on_enables_rule = function()
    load_addon()
    rule("a")
    NewbieNudge:SetRuleEnabled("a", false)
    NewbieNudge:HandleSlash("on a")
    assert_nil(NewbieNudge.db.disabled.a)
    assert_eq(last(), L().CHAT_PREFIX .. L().SLASH_RULE_SET:format("T_a", L().STATE_ON))
  end,
  unknown_rule_name_is_reported = function()
    load_addon()
    NewbieNudge:HandleSlash("off nope")
    assert_eq(last(), L().CHAT_PREFIX .. L().SLASH_UNKNOWN_RULE:format("nope"))
  end,
  reset_clears_snoozes_and_test_mode = function()
    load_addon()
    rule("a")
    NewbieNudge:Snooze("a", 30)
    NewbieNudge.testMode = true
    NewbieNudge:HandleSlash("reset")
    assert_nil(NewbieNudge.db.snoozed.a)
    assert_eq(NewbieNudge.testMode, false)
    assert_eq(last(), L().CHAT_PREFIX .. L().SLASH_RESET_DONE)
  end,
  test_enables_test_mode = function()
    load_addon()
    rule("a")
    NewbieNudge:HandleSlash("test")
    assert_eq(NewbieNudge.testMode, true)
    assert_eq(last(), L().CHAT_PREFIX .. L().SLASH_TEST_ON)
  end,
  unknown_command_prints_help = function()
    load_addon()
    NewbieNudge:HandleSlash("whatever")
    assert_eq(last(), L().CHAT_PREFIX .. L().SLASH_HELP)
  end,
}
