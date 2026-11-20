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
  not_applicable_without_a_materials_slot = function()
    setup(); Enum.BagIndex.ReagentBag = nil
    load_addon()
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.materials_bag))
  end,
}
