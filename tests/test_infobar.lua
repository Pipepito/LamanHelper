-- Info bar (v4): bag space, gold and gear condition on top of the panel.
local L = function() return NewbieNudge.L end
local RED, ORANGE, YELLOW, WHITE = { 1, 0.2, 0.2 }, { 1, 0.6, 0 }, { 1, 0.82, 0 }, { 1, 1, 1 }

local function seg(name) return NewbieNudge.InfoBar.segments[name] end
local function fill(bag, used)
  for i = 1, used do WOW.state.bags[bag].items[i] = { itemID = 9000 + i } end
end
local function refresh() NewbieNudge.Panel:Refresh(NewbieNudge:ActiveRows()) end
local function wear(list)
  for slot, d in pairs(list) do
    WOW.state.inventory[slot] = { itemID = 8000 + slot, durability = d }
    WOW.state.itemInfo[8000 + slot] = { name = "Item " .. slot }
  end
end

return {
  bag_counts_regular_bags_only = function()
    fill(0, 4)
    WOW.state.bags[1] = { numSlots = 6, family = 1, items = {} }
    load_addon(); load_bags()
    assert_eq({ NewbieNudge.InfoBar.BagCounts() }, { 4, 16, 12 })
  end,
  bag_text_format = function()
    fill(0, 4)
    load_addon(); load_bags(); refresh()
    assert_eq(seg("bags").text:GetText(), L().INFOBAR_BAGS:format(4, 16, 12))
  end,
  bag_text_colour = function()
    load_addon(); load_bags()
    fill(0, 14); refresh()
    assert_eq(seg("bags").text.textColor, RED)
    WOW.state.bags[0].items = {}; fill(0, 11); refresh()
    assert_eq(seg("bags").text.textColor, ORANGE)
    WOW.state.bags[0].items = {}; fill(0, 10); refresh()
    assert_eq(seg("bags").text.textColor, WHITE)
  end,
  gear_percent_sum_over_max = function()
    wear({ [1] = { 50, 100 }, [5] = { 100, 100 } })
    load_addon(); refresh()
    local g = NewbieNudge.InfoBar.GearStatus()
    assert_eq(g.percent, 75); assert_eq(g.anyLow, false)
    assert_eq(seg("gear").text:GetText(), L().INFOBAR_GEAR:format(75))
    assert_eq(seg("gear").text.textColor, WHITE)
  end,
  gear_red_when_one_item_nearly_broken = function()
    wear({ [1] = { 10, 100 }, [5] = { 100, 100 } })
    load_addon(); refresh()
    assert_eq(NewbieNudge.InfoBar.GearStatus().anyLow, true)
    assert_eq(seg("gear").text.textColor, RED)
  end,
  gear_yellow_below_half_overall = function()
    wear({ [1] = { 30, 100 }, [5] = { 50, 100 } })
    load_addon(); refresh()
    assert_eq(seg("gear").text.textColor, YELLOW)
  end,
  gear_dash_when_no_durability = function()
    load_addon(); refresh()
    assert_eq(seg("gear").text:GetText(), "—")
  end,
  secret_money_shows_question_mark = function()
    load_addon()
    WOW.state.money = WOW.secret(5)
    refresh()
    assert_eq(seg("gold").text:GetText(), L().INFOBAR_UNKNOWN)
  end,
  bar_only_panel_when_no_rows = function()
    load_addon(); load_bags(); refresh()
    assert_true(NewbieNudgePanel:IsShown())
    assert_true(NewbieNudge.InfoBar.frame:IsShown())
    assert_eq(#row_texts(), 0)
  end,
  panel_hidden_when_no_rows_and_bar_off = function()
    load_addon()
    NewbieNudge.db.infobar.enabled = false
    refresh()
    assert_true(not NewbieNudgePanel:IsShown())
  end,
  bar_hidden_in_combat = function()
    load_addon(); refresh()
    WOW.FireEvent("PLAYER_REGEN_DISABLED")
    assert_true(not NewbieNudge.InfoBar.frame:IsShown())
    assert_true(not NewbieNudge.InfoBar:IsActive())
  end,
  hide_panel_hides_bar = function()
    load_addon(); refresh()
    NewbieNudge.Panel:ToggleHidden()
    assert_true(not NewbieNudgePanel:IsShown())
    assert_true(not NewbieNudge.InfoBar:IsActive())
  end,
  segment_toggles = function()
    load_addon()
    NewbieNudge.db.infobar.gold = false
    refresh()
    assert_true(not seg("gold"):IsShown())
    assert_true(seg("bags"):IsShown()); assert_true(seg("gear"):IsShown())
  end,
  all_segments_off_means_no_bar = function()
    load_addon()
    NewbieNudge.db.infobar.bags, NewbieNudge.db.infobar.gold, NewbieNudge.db.infobar.gear = false, false, false
    refresh()
    assert_true(not NewbieNudge.InfoBar:IsActive())
    assert_true(not NewbieNudgePanel:IsShown())
  end,
  updates_on_money_event = function()
    load_addon(); refresh()
    WOW.state.money = 123456
    WOW.FireEvent("PLAYER_MONEY"); run_checks()
    assert_eq(seg("gold").text:GetText(), NewbieNudge.MoneyText(123456))
  end,
  bar_sits_above_the_rows = function()
    load_addon()
    NewbieNudge:RegisterRule({ name = "a", title = "T", help = "H", events = {}, applies = function() return true end,
      check = function() return { text = "one" } end })
    NewbieNudge:MarkAllDirty(); run_checks()
    assert_eq(select(5, NewbieNudge.InfoBar.frame:GetPoint(1)), -6)
    assert_eq(select(5, NewbieNudge.Panel.list:GetPoint(1)), -(6 + NewbieNudge.InfoBar.HEIGHT + 2))
  end,
  clicks = function()
    load_addon(); refresh()
    WOW.Click(seg("bags"), "LeftButton")
    assert_eq(WOW.calls[#WOW.calls][1], "ToggleAllBags")
    WOW.Click(seg("gear"), "LeftButton")
    assert_eq({ WOW.calls[#WOW.calls][1], WOW.calls[#WOW.calls][2] }, { "ToggleCharacter", "PaperDollFrame" })
  end,
  segment_tooltips = function()
    fill(0, 4)
    wear({ [1] = { 10, 100 }, [5] = { 100, 100 } })
    load_addon(); load_bags(); refresh()
    WOW.Hover(seg("bags"))
    assert_eq(GameTooltip.lines[1], L().INFOBAR_BAGS_TITLE)
    assert_eq(GameTooltip.lines[2], L().INFOBAR_BAG_LINE:format(NewbieNudge.InfoBar.BagName(0), 12, 16))
    WOW.Hover(seg("gear"))
    assert_eq(GameTooltip.lines[2], L().INFOBAR_GEAR_LOWEST:format("Item 1", 10))
  end,
  options_checkboxes_round_trip = function()
    load_addon()
    for _, key in ipairs({ "enabled", "bags", "gold", "gear" }) do
      local s = WOW.settings["NN_infobar_" .. key]
      assert_true(s, key)
      assert_eq(s.getter(), true)
      s.setter(false)
      assert_eq(NewbieNudge.db.infobar[key], false)
    end
  end,
}
