-- Minimap button and its menu (v4).
local L = function() return NewbieNudge.L end
local function MB() return NewbieNudge.MinimapButton end
local function near(a, b) return math.abs(a - b) < 0.01 end

local function rule(name)
  NewbieNudge:RegisterRule({ name = name, title = "T_" .. name, help = "H", events = {},
    applies = function() return true end, check = function() return { text = "row " .. name } end })
end
local function rows(...)
  for _, name in ipairs({ ... }) do rule(name) end
  NewbieNudge:MarkAllDirty(); run_checks()
end

local function entry(label)
  for _, e in ipairs(MB():MenuEntries()) do if e.label == label then return e end end
end

return {
  button_created_on_the_minimap = function()
    load_addon()
    assert_true(NewbieNudgeMinimapButton)
    assert_true(NewbieNudgeMinimapButton.parent == Minimap, "parented to the minimap")
    assert_true(NewbieNudgeMinimapButton:IsShown())
  end,
  position_for_angle_on_round_minimap = function()
    load_addon()
    local x, y = MB():PositionForAngle(0)
    assert_true(near(x, 80) and near(y, 0), x .. "," .. y)
    x, y = MB():PositionForAngle(90)
    assert_true(near(x, 0) and near(y, 80), x .. "," .. y)
  end,
  square_minimap_clamps_to_the_edge = function()
    GetMinimapShape = function() return "SQUARE" end
    load_addon()
    local x, y = MB():PositionForAngle(45)
    assert_true(near(x, 80) and near(y, 80), x .. "," .. y)
    x, y = MB():PositionForAngle(30)
    assert_true(near(x, 80) and y < 80, x .. "," .. y)
  end,
  drag_saves_angle = function()
    load_addon()
    WOW.state.cursorX, WOW.state.cursorY = 1000, 780 -- straight above the centre (1000, 700)
    local b = NewbieNudgeMinimapButton
    b:Fire("OnDragStart"); b:Fire("OnUpdate", 0.1); b:Fire("OnDragStop")
    assert_true(near(NewbieNudge.db.minimap.angle, 90), tostring(NewbieNudge.db.minimap.angle))
  end,
  defaults_for_a_0_3_database = function()
    _G.NewbieNudgeDB = { panel = { locked = true } }
    load_addon()
    assert_eq(NewbieNudge.db.minimap.hide, false)
    assert_eq(NewbieNudge.db.minimap.angle, 225)
  end,
  menu_lock_entry_follows_state = function()
    load_addon()
    NewbieNudge.db.panel.locked = true
    assert_true(entry(L().MENU_UNLOCK)); assert_nil(entry(L().MENU_LOCK))
    entry(L().MENU_UNLOCK).onClick()
    assert_eq(NewbieNudge.db.panel.locked, false)
    assert_true(entry(L().MENU_LOCK))
  end,
  menu_style_radios = function()
    load_addon()
    assert_eq(entry(L().MENU_STYLE_LIST).kind, "radio")
    assert_eq(entry(L().MENU_STYLE_LIST).checked, true)
    assert_eq(entry(L().MENU_STYLE_ICONS).checked, false)
    entry(L().MENU_STYLE_ICONS).onClick()
    assert_eq(NewbieNudge.db.panel.style, "icons")
  end,
  menu_infobar_checkbox = function()
    load_addon()
    local e = entry(L().MENU_INFOBAR)
    assert_eq(e.kind, "checkbox"); assert_eq(e.checked, true)
    e.onClick()
    assert_eq(NewbieNudge.db.infobar.enabled, false)
  end,
  menu_snooze_everything_only_when_rows = function()
    load_addon()
    local label = L().MENU_SNOOZE_ALL:format(L().MENU_DURATION_HOURS:format(1))
    assert_nil(entry(label))
    rows("a", "b")
    NewbieNudge:RegisterRule({ name = "quiet", title = "Q", help = "H", events = {},
      applies = function() return true end, check = function() return nil end })
    entry(label).onClick()
    assert_true(NewbieNudge.db.snoozed.a); assert_true(NewbieNudge.db.snoozed.b)
    assert_nil(NewbieNudge.db.snoozed.quiet)
    assert_true(WOW.printed[#WOW.printed]:find(L().SNOOZE_ALL_DONE:format(2, 60), 1, true))
  end,
  menu_snooze_label_in_minutes = function()
    load_addon()
    NewbieNudge.db.snoozeMinutes = 45
    rows("a")
    assert_true(entry(L().MENU_SNOOZE_ALL:format(L().MENU_DURATION_MINUTES:format(45))))
  end,
  menu_wake_all_only_when_snoozed = function()
    load_addon()
    rows("a")
    assert_nil(entry(L().MENU_WAKE_ALL))
    NewbieNudge:Snooze("a", 60)
    entry(L().MENU_WAKE_ALL).onClick()
    assert_nil(next(NewbieNudge.db.snoozed))
  end,
  menu_hide_show_and_settings = function()
    load_addon()
    entry(L().MENU_HIDE).onClick()
    assert_eq(NewbieNudge.db.panel.hidden, true)
    assert_true(entry(L().MENU_SHOW))
    entry(L().MENU_SETTINGS).onClick()
    local found = false
    for _, c in ipairs(WOW.calls) do if c[1] == "OpenToCategory" then found = true end end
    assert_true(found)
  end,
  click_opens_menu_with_title = function()
    load_addon()
    WOW.Click(NewbieNudgeMinimapButton, "LeftButton")
    assert_eq(WOW.lastMenu.items[1].kind, "title")
    assert_eq(WOW.lastMenu.items[1].label, L().ADDON_TITLE)
    WOW.lastMenu = nil
    WOW.Click(NewbieNudgeMinimapButton, "RightButton")
    assert_true(WOW.lastMenu)
  end,
  tooltip_counts_rows = function()
    load_addon()
    WOW.Hover(NewbieNudgeMinimapButton)
    assert_true(tContains(GameTooltip.lines, L().MINIMAP_TT_NONE))
    rows("a", "b", "c")
    WOW.Hover(NewbieNudgeMinimapButton)
    assert_true(tContains(GameTooltip.lines, L().MINIMAP_TT_COUNT:format(3)))
  end,
  hide_setting = function()
    load_addon()
    MB():SetShown(false)
    assert_true(not NewbieNudgeMinimapButton:IsShown())
    assert_eq(NewbieNudge.db.minimap.hide, true)
    assert_eq(WOW.settings["NN_minimap_show"].getter(), false)
    WOW.settings["NN_minimap_show"].setter(true)
    assert_true(NewbieNudgeMinimapButton:IsShown())
  end,
  compartment_entry_opens_menu_even_when_hidden = function()
    load_addon()
    assert_eq(WOW.compartment.text, L().ADDON_TITLE)
    MB():SetShown(false)
    WOW.compartment.func()
    WOW.AdvanceTime(0)
    assert_eq(WOW.lastMenu.items[1].label, L().ADDON_TITLE)
  end,
  fallback_without_menuutil = function()
    MenuUtil = nil
    local got
    EasyMenu = function(list) got = list end
    load_addon()
    WOW.Click(NewbieNudgeMinimapButton, "LeftButton")
    assert_true(got)
    assert_eq(got[1].isTitle, true)
    assert_eq(got[1].text, L().ADDON_TITLE)
  end,
  -- Review fixes (v4)
  menu_ticks_follow_live_state_after_a_click = function()
    load_addon()
    WOW.Click(NewbieNudgeMinimapButton, "LeftButton")
    local box, icons
    for _, it in ipairs(WOW.lastMenu.items) do
      if it.label == L().MENU_INFOBAR then box = it end
      if it.label == L().MENU_STYLE_ICONS then icons = it end
    end
    box.onClick()
    assert_eq(box.isSelected(), false, "checkbox reads the new state")
    icons.onClick()
    assert_eq(icons.isSelected(), true, "radio reads the new state")
  end,
  compartment_menu_not_anchored_to_hidden_button = function()
    load_addon()
    MB():SetShown(false)
    local anchor = CreateFrame("Button", nil, UIParent)
    WOW.compartment.func(anchor)
    WOW.AdvanceTime(0)
    assert_true(WOW.lastMenu, "menu opened")
    assert_true(WOW.lastMenuOwner ~= NewbieNudgeMinimapButton, "not anchored to the hidden button")
  end,
}
