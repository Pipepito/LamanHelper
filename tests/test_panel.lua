-- Registers a rule returning the given result list and runs the checks.
local function ruleWith(name, results, combat)
  NewbieNudge:RegisterRule({
    name = name, title = "T_" .. name, help = "Help for " .. name, events = {}, combat = combat,
    applies = function() return true end,
    check = function() return results end,
  })
end

local function show(results, name)
  ruleWith(name or "a", results)
  NewbieNudge:MarkAllDirty(); NewbieNudge:Schedule(); WOW.AdvanceTime(0.5)
end

local function visibleStripIcons()
  local n = 0
  for _, icon in ipairs(NewbieNudge.Panel.stripIcons) do if icon:IsShown() then n = n + 1 end end
  return n
end

return {
  hidden_when_no_rows = function()
    load_addon()
    show({})
    assert_true(not NewbieNudgePanel:IsShown())
  end,
  shows_one_row_per_result_in_order = function()
    load_addon()
    show({ { text = "one" }, { text = "two" } })
    assert_true(NewbieNudgePanel:IsShown())
    assert_eq(row_texts(), { "one", "two" })
  end,
  overflow_row_after_ten = function()
    load_addon()
    local results = {}
    for i = 1, 12 do results[i] = { text = "r" .. i } end
    show(results)
    local texts = row_texts()
    assert_eq(#texts, 11)
    assert_eq(texts[11], NewbieNudge.L.MORE_ROWS:format(2))
  end,
  left_click_runs_onclick = function()
    load_addon()
    local clicked = false
    show({ { text = "one", onClick = function() clicked = true end } })
    WOW.Click(NewbieNudge.Panel.rows[1], "LeftButton")
    assert_true(clicked)
  end,
  right_click_snoozes_for_db_minutes = function()
    load_addon()
    NewbieNudge.db.snoozeMinutes = 45
    show({ { text = "one" } })
    WOW.Click(NewbieNudge.Panel.rows[1], "RightButton")
    assert_eq(NewbieNudge.db.snoozed.a, time() + 45 * 60)
    WOW.AdvanceTime(0.5)
    assert_true(not NewbieNudgePanel:IsShown())
  end,
  shift_right_click_snoozes_until_login = function()
    load_addon()
    show({ { text = "one" } })
    WOW.state.shiftDown = true
    WOW.Click(NewbieNudge.Panel.rows[1], "RightButton")
    assert_eq(NewbieNudge.db.snoozed.a, 0)
  end,
  tooltip_shows_title_help_and_hints = function()
    load_addon()
    show({ { text = "one", onClick = function() end } })
    WOW.Hover(NewbieNudge.Panel.rows[1])
    assert_eq(GameTooltip.lines[1], "T_a")
    assert_eq(GameTooltip.lines[2], "one", "the reminder text itself (the strip has no text otherwise)")
    assert_eq(GameTooltip.lines[3], "Help for a")
    assert_eq(GameTooltip.lines[4], NewbieNudge.L.ROW_HINT_CLICK)
    assert_eq(GameTooltip.lines[5], NewbieNudge.L.ROW_HINT_SNOOZE:format(60))
  end,
  stale_rows_are_half_alpha = function()
    load_addon()
    show({ { text = "one" } })
    assert_eq(NewbieNudge.Panel.rows[1]:GetAlpha(), 1)
    WOW.state.inCombat = true
    NewbieNudge:MarkAllDirty(); NewbieNudge:Schedule(); WOW.AdvanceTime(0.5)
    NewbieNudge.Panel:SetCombatMode(false) -- force list view to inspect the row
    NewbieNudge.Panel:Refresh(NewbieNudge:ActiveRows())
    assert_eq(NewbieNudge.Panel.rows[1]:GetAlpha(), 0.5)
  end,
  combat_mode_shows_strip_with_same_count = function()
    load_addon()
    show({ { text = "one" }, { text = "two" } })
    WOW.state.inCombat = true
    WOW.FireEvent("PLAYER_REGEN_DISABLED")
    assert_true(NewbieNudge.Panel.strip:IsShown())
    assert_true(not NewbieNudge.Panel.list:IsShown())
    assert_eq(visibleStripIcons(), 2)
    assert_eq(NewbieNudge.Panel.stripIcons[1]:GetAlpha(), 0.5, "stale icon dims")
  end,
  combat_mode_hides_when_strip_disabled = function()
    load_addon()
    NewbieNudge.db.combatStrip = false
    show({ { text = "one" } })
    WOW.state.inCombat = true
    WOW.FireEvent("PLAYER_REGEN_DISABLED")
    assert_true(not NewbieNudgePanel:IsShown())
  end,
  leaving_combat_restores_rows = function()
    load_addon()
    show({ { text = "one" } })
    WOW.state.inCombat = true
    WOW.FireEvent("PLAYER_REGEN_DISABLED")
    WOW.state.inCombat = false
    WOW.FireEvent("PLAYER_REGEN_ENABLED")
    WOW.AdvanceTime(0.5)
    assert_true(NewbieNudge.Panel.list:IsShown())
    assert_true(not NewbieNudge.Panel.strip:IsShown())
    assert_eq(row_texts(), { "one" })
  end,
  combat_rule_icon_stays_bright_in_strip = function()
    load_addon()
    ruleWith("c", { { text = "live" } }, true)
    show({ { text = "one" } })
    WOW.state.inCombat = true
    WOW.FireEvent("PLAYER_REGEN_DISABLED")
    local bright = 0
    for _, icon in ipairs(NewbieNudge.Panel.stripIcons) do if icon:IsShown() and icon:GetAlpha() == 1 then bright = bright + 1 end end
    assert_eq(bright, 1)
  end,
  drag_stop_saves_position = function()
    load_addon()
    NewbieNudge.Panel:SetLocked(false)
    NewbieNudgePanel.points = { { point = "TOPLEFT", relPoint = "TOPLEFT", x = 123, y = -45 } }
    NewbieNudgePanel:Fire("OnDragStop")
    assert_eq(NewbieNudge.db.panel.point, "TOPLEFT")
    assert_eq(NewbieNudge.db.panel.x, 123)
    assert_eq(NewbieNudge.db.panel.y, -45)
  end,
  locked_hides_title_bar = function()
    load_addon()
    assert_true(not NewbieNudge.Panel.title:IsShown())
    NewbieNudge.Panel:SetLocked(false)
    assert_true(NewbieNudge.Panel.title:IsShown())
    NewbieNudge.Panel:SetLocked(true)
    assert_true(not NewbieNudge.Panel.title:IsShown())
  end,
  long_text_rows_get_two_line_height = function()
    load_addon()
    show({ { text = string.rep("long text ", 8) }, { text = "short" } })
    assert_eq(NewbieNudge.Panel.rows[1]:GetHeight(), 36)
    assert_eq(NewbieNudge.Panel.rows[2]:GetHeight(), 24)
    assert_eq(select(5, NewbieNudge.Panel.rows[2]:GetPoint(1)), -36, "second row starts below the wrapped first row")
  end,
  scale_applied_from_db = function()
    _G.NewbieNudgeDB = { panel = { scale = 1.3 } }
    load_addon()
    assert_eq(NewbieNudgePanel:GetScale(), 1.3)
  end,
  test_mode_shows_panel_even_with_no_real_rows = function()
    load_addon()
    ruleWith("a", {})
    NewbieNudge:HandleSlash("test")
    WOW.AdvanceTime(0.5)
    assert_true(NewbieNudgePanel:IsShown())
    -- every rule shows its sample; durability is first in priority so it is never cut off
    assert_true(tContains(row_texts(), NewbieNudge.L.DURABILITY_ROW_LOW))
    assert_eq(#row_texts(), NewbieNudge.MAX_ROWS + 1)
  end,
}
