-- Tests added after the final review, one per finding taken into the fix pass.
local function fakeRule(name, opts)
  opts = opts or {}
  local rule = { name = name, title = "T_" .. name, help = "H", events = opts.events or { "TEST_EVENT" }, calls = 0,
                 applies = function() return true end }
  rule.check = function() rule.calls = rule.calls + 1; return opts.result end
  NewbieNudge:RegisterRule(rule)
  return rule
end


return {
  -- Finding 1: snoozes must use wall-clock time, not seconds since boot
  snooze_uses_epoch_time_not_uptime = function()
    load_addon()
    fakeRule("a", { result = { text = "x" } })
    WOW.FireEvent("TEST_EVENT"); run_checks()
    NewbieNudge:Snooze("a", 60)
    assert_eq(NewbieNudge.db.snoozed.a, time() + 3600)
    run_checks()
    assert_eq(#NewbieNudge:ActiveRows(), 0)
    -- wall clock moves on 2 hours while uptime barely moves (as after a reboot)
    WOW.state.epoch = WOW.state.epoch + 7200
    WOW.AdvanceTime(30)
    assert_eq(#NewbieNudge:ActiveRows(), 1, "expired snooze must lift even though uptime is small")
  end,
  snooze_still_held_after_reboot_when_not_expired = function()
    load_addon()
    fakeRule("a", { result = { text = "x" } })
    WOW.FireEvent("TEST_EVENT"); run_checks()
    NewbieNudge:Snooze("a", 60)
    WOW.state.time = 999999 -- long uptime must not expire a fresh snooze
    WOW.AdvanceTime(30)
    assert_eq(#NewbieNudge:ActiveRows(), 0)
  end,
  -- Finding 3: an event name the client does not know must not kill the rule file
  unknown_event_does_not_break_rule_registration = function()
    WOW.unknownEvents = { BOGUS_EVENT = true }
    load_addon()
    local r = fakeRule("a", { events = { "BOGUS_EVENT", "TEST_EVENT" }, result = { text = "x" } })
    WOW.FireEvent("TEST_EVENT"); run_checks()
    assert_eq(r.calls, 1)
    assert_true(not NewbieNudge.events:IsEventRegistered("BOGUS_EVENT"))
  end,
  -- Finding 4: Blizzard hides proc glows on loading screens; we must re-show ours
  glow_reshown_after_entering_world = function()
    load_addon()
    local rows = { { rule = { name = "r" }, result = { text = "t", highlight = { action = { 3 } } }, stale = false } }
    NewbieNudge.Highlight:Apply(rows)
    WOW.FireEvent("PLAYER_ENTERING_WORLD", false, true)
    NewbieNudge.Highlight:Apply(rows)
    local shows = 0
    for _, c in ipairs(WOW.calls) do if c[1] == "glow_show" and c[2] == ActionButton3 then shows = shows + 1 end end
    assert_eq(shows, 2)
  end,
  glow_reshown_after_shapeshift = function()
    load_addon()
    local rows = { { rule = { name = "r" }, result = { text = "t", highlight = "bags" }, stale = false } }
    NewbieNudge.Highlight:Apply(rows)
    WOW.FireEvent("UPDATE_SHAPESHIFT_FORM")
    NewbieNudge.Highlight:Apply(rows)
    local shows = 0
    for _, c in ipairs(WOW.calls) do if c[1] == "glow_show" and c[2] == MainMenuBarBackpackButton then shows = shows + 1 end end
    assert_eq(shows, 2)
  end,
  -- In-game finding: a login hook that errors must not stop the later ones
  -- (the options window is built by one of them).
  failing_login_hook_does_not_block_the_others = function()
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/failing_login_hook.lua" }
    load_addon()
    assert_eq(NewbieNudge_LaterHookRan, true)
    assert_true(NewbieNudge.SettingsWindow, "later files still loaded")
    assert_true(tostring(NewbieNudge.db.errors["login:1"]):find("hook boom", 1, true))
    assert_true(WOW.printed[#WOW.printed]:find("hook boom", 1, true) or WOW.printed[#WOW.printed - 1]:find("hook boom", 1, true))
  end,
}
