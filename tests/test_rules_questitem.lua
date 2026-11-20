-- Rule quest_item: an item in the bags that starts a quest.
local L = function() return NewbieNudge.L end

return {
  item_that_starts_a_quest_gets_a_row_and_bag_highlight = function()
    WOW.state.itemInfo[9] = { name = "Gnarled Note" }
    WOW.state.bags[0].items[3] = { itemID = 9, questID = 500, isActive = false, isQuestItem = true }
    load_addon(); load_bags(); run_checks()
    local r = results_of("quest_item")
    assert_eq(r[1].text, L().QUEST_ITEM_ROW:format("Gnarled Note"))
    assert_eq(r[1].highlight, { key = "bags", bagslots = { { 0, 3 } } })
    r[1].onClick(); assert_eq(WOW.calls[#WOW.calls][1], "ToggleAllBags")
  end,
  active_quest_item_is_not_listed = function()
    WOW.state.itemInfo[9] = { name = "Note" }
    WOW.state.bags[0].items[3] = { itemID = 9, questID = 500, isActive = true, isQuestItem = true }
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("quest_item"), 0)
  end,
  disappears_once_accepted = function()
    WOW.state.itemInfo[9] = { name = "Note" }
    local it = { itemID = 9, questID = 500, isActive = false, isQuestItem = true }
    WOW.state.bags[0].items[3] = it
    load_addon(); load_bags(); run_checks(); assert_eq(#results_of("quest_item"), 1)
    it.isActive = true; WOW.FireEvent("QUEST_ACCEPTED", 500); run_checks()
    assert_eq(#results_of("quest_item"), 0)
  end,
  at_most_three_rows = function()
    for i = 1, 5 do
      WOW.state.itemInfo[i] = { name = "Note" .. i }
      WOW.state.bags[0].items[i] = { itemID = i, questID = 500 + i, isActive = false, isQuestItem = true }
    end
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("quest_item"), 4)
    assert_eq(results_of("quest_item")[4].text, L().MORE_ROWS:format(2))
  end,
  -- review fix 5: an item that starts a quest already done is not a reminder
  completed_quest_starter_not_listed = function()
    WOW.state.itemInfo[9] = { name = "Note" }
    WOW.state.bags[0].items[3] = { itemID = 9, questID = 500, isActive = false, isQuestItem = true }
    WOW.state.completedQuests[500] = true
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("quest_item"), 0)
  end,
}
