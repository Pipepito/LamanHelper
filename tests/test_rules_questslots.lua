-- Rule quest_slots: bag slots the current quests will need.
local L = function() return NewbieNudge.L end
local function item(id, name, stack) WOW.state.itemInfo[id] = { name = name, stackCount = stack or 20 } end
local function bagItem(slot, id, count) WOW.state.bags[0].items[slot] = { itemID = id, count = count } end
local function run() load_addon(); load_bags(); WOW.FireEvent("QUEST_LOG_UPDATE"); run_checks() end

return {
  objective_name_both_orders = function()
    load_addon()
    assert_eq(NewbieNudge.ObjectiveItemName("Boar Meat: 3/10"), "Boar Meat")
    assert_eq(NewbieNudge.ObjectiveItemName("3/10 Boar Meat"), "Boar Meat")
    assert_eq(NewbieNudge.ObjectiveItemName("Carne de jabalí: 0/10"), "Carne de jabalí")
    assert_nil(NewbieNudge.ObjectiveItemName("Kill Hogger"), "no counter means no item name")
  end,
  unstarted_item_objective_needs_one_slot = function()
    WOW.state.bags[0].numSlots = 3; bagItem(1, 1); bagItem(2, 1); item(1, "Junk")
    WOW.Quest({ questID = 1, title = "A", level = 20, objectives = { { type = "item", text = "Boar Meat: 0/10", numFulfilled = 0, numRequired = 10 } } })
    run()
    assert_eq(#results_of("quest_slots"), 0, "1 free slot covers 1 needed: no row")
  end,
  row_when_free_below_needed = function()
    WOW.state.bags[0].numSlots = 2; bagItem(1, 1); bagItem(2, 1); item(1, "Junk")
    WOW.Quest({ questID = 1, title = "A", level = 20, objectives = {
      { type = "item", text = "Boar Meat: 0/10", numFulfilled = 0, numRequired = 10 },
      { type = "item", text = "Wolf Pelt: 0/5", numFulfilled = 0, numRequired = 5 },
      { type = "monster", text = "Hogger: 0/1", numFulfilled = 0, numRequired = 1 } } })
    run()
    assert_eq(results_of("quest_slots")[1].text, L().QUEST_SLOTS_ROW:format(2, 0))
    assert_eq(results_of("quest_slots")[1].highlight, "bags")
  end,
  started_stack_counts_remaining_stacks = function()
    WOW.state.bags[0].numSlots = 3; item(2, "Boar Meat", 5); bagItem(1, 2, 3); bagItem(2, 1); bagItem(3, 1); item(1, "Junk")
    WOW.Quest({ questID = 1, title = "A", level = 20, objectives = { { type = "item", text = "Boar Meat: 3/12", numFulfilled = 3, numRequired = 12 } } })
    run() -- 12 needed / stack 5 = 3 stacks, 1 held -> 2 more slots, 0 free
    assert_eq(results_of("quest_slots")[1].text, L().QUEST_SLOTS_ROW:format(2, 0))
  end,
  finished_objectives_and_rewards_of_complete_quests = function()
    WOW.state.bags[0].numSlots = 2; bagItem(1, 1); bagItem(2, 1); item(1, "Junk")
    WOW.Quest({ questID = 1, title = "A", level = 20, isComplete = true, rewards = { 10 }, choices = { 11, 12 },
      objectives = { { type = "item", text = "Boar Meat: 10/10", numFulfilled = 10, numRequired = 10, finished = true } } })
    run() -- 1 reward + 1 choice = 2
    assert_eq(results_of("quest_slots")[1].text, L().QUEST_SLOTS_ROW:format(2, 0))
  end,
  no_row_without_quests = function()
    WOW.state.questLog = {}; WOW.state.bags[0].numSlots = 1; bagItem(1, 1); item(1, "Junk")
    run(); assert_eq(#results_of("quest_slots"), 0)
  end,
}
