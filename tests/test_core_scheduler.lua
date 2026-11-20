-- Registers a rule whose check() returns opts.result (a table, or a function
-- returning one) and counts calls in rule.calls.
local function fakeRule(name, opts)
  opts = opts or {}
  local rule = {
    name = name, title = "T_" .. name, help = "H", events = opts.events or { "TEST_EVENT" },
    combat = opts.combat, default = opts.default, calls = 0,
    applies = opts.applies or function() return true end,
    sample = opts.sample,
  }
  rule.check = function()
    rule.calls = rule.calls + 1
    local r = opts.result
    if type(r) == "function" then return r() end
    return r
  end
  NewbieNudge:RegisterRule(rule)
  return rule
end

local function fireAndRun(event)
  WOW.FireEvent(event or "TEST_EVENT")
  WOW.AdvanceTime(0.5)
end

return {
  event_marks_dirty_and_runs_after_half_second = function()
    load_addon()
    local r = fakeRule("a", { result = { text = "x" } })
    WOW.FireEvent("TEST_EVENT")
    assert_eq(r.calls, 0)
    WOW.AdvanceTime(0.5)
    assert_eq(r.calls, 1)
    assert_eq(results_of("a")[1].text, "x")
  end,
  two_events_coalesce_into_one_run = function()
    load_addon()
    local r = fakeRule("a", { result = { text = "x" } })
    WOW.FireEvent("TEST_EVENT"); WOW.FireEvent("TEST_EVENT")
    WOW.AdvanceTime(0.5)
    assert_eq(r.calls, 1)
  end,
  nil_result_gives_empty_array = function()
    load_addon()
    fakeRule("a", { result = nil })
    fireAndRun()
    assert_eq(#results_of("a"), 0)
  end,
  single_result_is_wrapped = function()
    load_addon()
    fakeRule("a", { result = { text = "x" } })
    fireAndRun()
    assert_eq(#results_of("a"), 1)
  end,
  list_result_kept_as_is = function()
    load_addon()
    fakeRule("a", { result = { { text = "x" }, { text = "y" } } })
    fireAndRun()
    assert_eq(#results_of("a"), 2)
  end,
  non_combat_rule_frozen_in_combat = function()
    load_addon()
    local text = "x"
    fakeRule("a", { result = function() return { text = text } end })
    fireAndRun()
    WOW.state.inCombat = true
    text = "y"
    fireAndRun()
    assert_eq(results_of("a")[1].text, "x")
    assert_eq(NewbieNudge:ActiveRows()[1].stale, true)
  end,
  combat_rule_updates_in_combat = function()
    load_addon()
    local text = "x"
    fakeRule("a", { combat = true, result = function() return { text = text } end })
    fireAndRun()
    WOW.state.inCombat = true
    text = "y"
    fireAndRun()
    assert_eq(results_of("a")[1].text, "y")
    assert_eq(NewbieNudge:ActiveRows()[1].stale, false)
  end,
  regen_enabled_rechecks_everything = function()
    load_addon()
    local text = "x"
    fakeRule("a", { result = function() return { text = text } end })
    fireAndRun()
    WOW.state.inCombat = true
    text = "y"
    fireAndRun()
    WOW.state.inCombat = false
    fireAndRun("PLAYER_REGEN_ENABLED")
    assert_eq(results_of("a")[1].text, "y")
  end,
  secret_in_result_keeps_previous = function()
    load_addon()
    local result = { text = "x" }
    fakeRule("a", { result = function() return result end })
    fireAndRun()
    result = { text = WOW.secret("y") }
    fireAndRun()
    assert_eq(results_of("a")[1].text, "x")
  end,
  unknown_sentinel_keeps_previous = function()
    load_addon()
    local result = { text = "x" }
    fakeRule("a", { result = function() return result end })
    fireAndRun()
    result = NewbieNudge.UNKNOWN
    fireAndRun()
    assert_eq(results_of("a")[1].text, "x")
    assert_eq(NewbieNudge.ruleState.a.dirty, false)
  end,
  erroring_rule_is_disabled_once = function()
    load_addon()
    local r = fakeRule("a", { result = function() error("boom") end })
    fireAndRun()
    assert_eq(#results_of("a"), 0)
    assert_true(NewbieNudge.ruleState.a.disabled)
    local printed = #WOW.printed
    assert_true(WOW.printed[printed]:find("hit an error", 1, true), WOW.printed[printed])
    assert_true(tostring(NewbieNudge.db.errors.a):find("boom", 1, true))
    local calls = r.calls
    fireAndRun()
    assert_eq(r.calls, calls)
    assert_eq(#WOW.printed, printed)
  end,
  snooze_hides_then_expires = function()
    load_addon()
    fakeRule("a", { result = { text = "x" } })
    fireAndRun()
    assert_eq(#NewbieNudge:ActiveRows(), 1)
    NewbieNudge:Snooze("a", 60)
    WOW.AdvanceTime(0.5)
    assert_eq(#NewbieNudge:ActiveRows(), 0)
    WOW.state.epoch = WOW.state.epoch + 3601 -- wall clock, not uptime
    WOW.AdvanceTime(30)
    assert_eq(#NewbieNudge:ActiveRows(), 1)
  end,
  snooze_until_login_clears_on_login = function()
    _G.NewbieNudgeDB = { snoozed = { a = 0, b = 5 } }
    load_addon()
    assert_nil(NewbieNudge.db.snoozed.a)
    assert_eq(NewbieNudge.db.snoozed.b, 5)
  end,
  disabled_rule_not_checked = function()
    load_addon()
    local r = fakeRule("a", { result = { text = "x" } })
    NewbieNudge:SetRuleEnabled("a", false)
    fireAndRun()
    assert_eq(r.calls, 0)
    assert_eq(NewbieNudge.db.disabled.a, true)
  end,
  applies_false_rule_not_checked_until_level_up = function()
    WOW.state.level = 5
    load_addon()
    local r = fakeRule("a", { result = { text = "x" }, applies = function() return UnitLevel("player") >= 10 end })
    fireAndRun()
    assert_eq(r.calls, 0)
    WOW.state.level = 10
    fireAndRun("PLAYER_LEVEL_UP")
    assert_eq(r.calls, 1)
  end,
  priority_orders_rows = function()
    -- mail is registered before durability in the TOC order but ranks lower
    WOW.state.newMail = true
    WOW.state.inventory[5] = { itemID = 1, durability = { 0, 100 } }
    load_addon()
    fakeRule("zz_unlisted", { result = { text = "z" } })
    fireAndRun()
    local names = {}
    for _, row in ipairs(NewbieNudge:ActiveRows()) do names[#names + 1] = row.rule.name end
    assert_eq(names[1], "durability")
    assert_eq(names[2], "mail")
    assert_eq(names[#names], "zz_unlisted", "rules not in PRIORITY come last")
  end,
  test_mode_uses_sample = function()
    load_addon()
    fakeRule("a", { result = nil, sample = function() return { { text = "S" } } end })
    NewbieNudge.testMode = true
    NewbieNudge:MarkAllDirty(); NewbieNudge:Schedule()
    WOW.AdvanceTime(0.5)
    assert_eq(results_of("a")[1].text, "S")
  end,
  default_false_rule_is_disabled_on_first_login = function()
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/default_false_rule.lua" }
    load_addon()
    assert_eq(NewbieNudge.db.disabled.optional_rule, true)
    assert_eq(NewbieNudge.db.seen.rules.optional_rule, true)
  end,
  default_false_rule_stays_enabled_once_seen = function()
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/default_false_rule.lua" }
    _G.NewbieNudgeDB = { seen = { rules = { optional_rule = true } } }
    load_addon()
    assert_nil(NewbieNudge.db.disabled.optional_rule)
  end,
  unit_event_form_is_registered_and_matched = function()
    load_addon()
    local r = fakeRule("a", { events = { "UNIT_AURA:player" }, result = { text = "x" } })
    assert_true(NewbieNudge.events:IsEventRegistered("UNIT_AURA"))
    fireAndRun("UNIT_AURA")
    assert_eq(r.calls, 1)
  end,
  periodic_ticker_rechecks_without_events = function()
    load_addon()
    local r = fakeRule("a", { result = { text = "x" } })
    fireAndRun()
    assert_eq(r.calls, 1)
    WOW.AdvanceTime(31)
    assert_eq(r.calls, 2)
  end,
}
