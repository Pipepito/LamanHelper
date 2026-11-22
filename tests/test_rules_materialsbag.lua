-- Rule materials_bag: Forever's separate materials bag slot takes profession
-- bags (confirmed 2026-11-20: an Apprentice's Mining Pack, family 1024,
-- container subclass 6, sat in slot 35).
local L = function() return NewbieNudge.L end
local MINING12, MINING16, HERB, QUIVER, PLAIN = 7001, 7002, 7003, 7004, 7005
local function setup()
  WOW.state.itemInfo[MINING12] = { name = "Small Mining Pack", classID = 1, subclassID = 6, family = 1024, numSlots = 12 }
  WOW.state.itemInfo[MINING16] = { name = "Big Mining Pack", classID = 1, subclassID = 6, family = 1024, numSlots = 16 }
  WOW.state.itemInfo[HERB] = { name = "Herb Pouch", classID = 1, subclassID = 2, family = 32, numSlots = 12 }
  WOW.state.itemInfo[QUIVER] = { name = "Light Quiver", classID = 1, subclassID = 2, family = 1, numSlots = 6 }
  WOW.state.itemInfo[PLAIN] = { name = "Linen Bag", classID = 1, subclassID = 0, family = 0, numSlots = 6 }
end

return {
  profession_bag_in_inventory_with_empty_materials_slot = function()
    setup(); WOW.state.bags[0].items[1] = { itemID = MINING12 }
    load_addon(); load_bags(); run_checks()
    local r = results_of("materials_bag")
    assert_eq(r[1].text, L().MATERIALS_BAG_ROW_EMPTY); assert_eq(r[1].highlight, "bags")
    r[1].onClick(); assert_eq(WOW.calls[#WOW.calls][1], "ToggleAllBags")
  end,
  any_profession_family_counts = function()
    setup(); WOW.state.bags[0].items[1] = { itemID = HERB }
    load_addon(); load_bags(); run_checks()
    assert_eq(results_of("materials_bag")[1].text, L().MATERIALS_BAG_ROW_EMPTY)
  end,
  ammo_bags_and_plain_bags_are_not_materials_bags = function()
    setup(); WOW.state.bags[0].items[1] = { itemID = QUIVER }; WOW.state.bags[0].items[2] = { itemID = PLAIN }
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("materials_bag"), 0)
  end,
  bigger_materials_bag_than_equipped = function()
    setup(); WOW.state.bags[5] = { numSlots = 12, family = 1024, items = {} }; WOW.state.inventory[24] = { itemID = MINING12 }
    WOW.state.bags[0].items[1] = { itemID = MINING16 }
    load_addon(); load_bags(); run_checks()
    assert_eq(results_of("materials_bag")[1].text, L().MATERIALS_BAG_ROW_BIGGER)
  end,
  equal_or_smaller_is_fine_and_regular_rule_ignores_it = function()
    setup(); WOW.state.bags[5] = { numSlots = 16, family = 1024, items = {} }; WOW.state.inventory[24] = { itemID = MINING16 }
    WOW.state.bags[0].items[1] = { itemID = MINING12 }
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("materials_bag"), 0); assert_eq(#results_of("bag_unequipped"), 0)
  end,
  -- Owner request 2026-11-22: a profession bag in a normal bag slot while the
  -- materials slot is empty. Default stub numbering: bag 2 -> slot 21, materials -> 24.
  profession_bag_in_regular_slot_with_empty_materials_slot = function()
    setup(); WOW.state.inventory[21] = { itemID = MINING12 }
    load_addon(); load_bags(); run_checks()
    local r = results_of("materials_bag")
    assert_eq(#r, 1)
    assert_eq(r[1].text, L().MATERIALS_BAG_ROW_SLOT:format("Small Mining Pack"))
    assert_eq(r[1].highlight, "bags")
  end,
  no_slot_row_when_materials_slot_taken = function()
    setup(); WOW.state.bags[5] = { numSlots = 12, family = 32, items = {} }
    WOW.state.inventory[21] = { itemID = MINING12 }; WOW.state.inventory[24] = { itemID = HERB }
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("materials_bag"), 0)
  end,
  no_slot_row_for_plain_bag_or_quiver = function()
    setup(); WOW.state.inventory[20] = { itemID = PLAIN }; WOW.state.inventory[21] = { itemID = QUIVER }
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("materials_bag"), 0)
  end,
  click_moves_bag_to_materials_slot = function()
    setup(); WOW.state.inventory[21] = { itemID = MINING12 }
    load_addon(); load_bags(); run_checks()
    results_of("materials_bag")[1].onClick()
    assert_eq(WOW.state.inventory[24].itemID, MINING12); assert_nil(WOW.state.inventory[21])
    assert_nil(WOW.state.cursor)
  end,
  failed_move_clears_cursor_and_opens_bags = function()
    setup(); WOW.state.refuseBagMove = true; WOW.state.inventory[21] = { itemID = MINING12 }
    load_addon(); load_bags(); run_checks()
    results_of("materials_bag")[1].onClick()
    assert_nil(WOW.state.cursor)
    local names = {}; for _, c in ipairs(WOW.calls) do names[#names + 1] = c[1] end
    assert_true(tContains(names, "ClearCursor")); assert_true(tContains(names, "ToggleAllBags"))
    assert_true(WOW.printed[#WOW.printed]:find(L().MATERIALS_BAG_MOVE_FAILED, 1, true))
  end,
  click_refuses_in_combat = function()
    setup(); WOW.state.inventory[21] = { itemID = MINING12 }
    load_addon(); load_bags(); run_checks()
    WOW.state.inCombat = true
    results_of("materials_bag")[1].onClick()
    assert_eq(WOW.state.inventory[21].itemID, MINING12)
    assert_true(WOW.printed[#WOW.printed]:find(L().MATERIALS_BAG_IN_COMBAT, 1, true))
  end,
  not_applicable_without_a_materials_slot = function()
    setup(); Enum.BagIndex.ReagentBag = nil
    load_addon()
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.materials_bag))
  end,
}
