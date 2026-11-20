-- Rule materials_bag: the separate materials (reagent) bag slot.
local L = function() return NewbieNudge.L end
local MAT12, MAT16 = 7001, 7002
local function setup()
  WOW.state.itemInfo[MAT12] = { name = "Small Materials Bag", classID = 1, subclassID = 11, family = 2048, numSlots = 12 }
  WOW.state.itemInfo[MAT16] = { name = "Big Materials Bag", classID = 1, subclassID = 11, family = 2048, numSlots = 16 }
end
local function withConstants() NewbieNudge.REAGENT_BAG_FAMILY = 2048; wipe(NewbieNudge.appliesCache) end

return {
  silent_until_constants_are_known = function()
    setup(); WOW.state.bags[0].items[1] = { itemID = MAT12 }
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("materials_bag"), 0)
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.materials_bag))
  end,
  empty_materials_slot_with_bag_in_inventory = function()
    setup(); WOW.state.bags[0].items[1] = { itemID = MAT12 }
    load_addon(); withConstants(); load_bags(); run_checks()
    local r = results_of("materials_bag")
    assert_eq(r[1].text, L().MATERIALS_BAG_ROW_EMPTY); assert_eq(r[1].highlight, "bags")
    r[1].onClick(); assert_eq(WOW.calls[#WOW.calls][1], "ToggleAllBags")
  end,
  bigger_materials_bag_than_equipped = function()
    setup(); WOW.state.bags[5] = { numSlots = 12, family = 2048, items = {} }; WOW.state.inventory[24] = { itemID = MAT12 }
    WOW.state.bags[0].items[1] = { itemID = MAT16 }
    load_addon(); withConstants(); load_bags(); run_checks()
    assert_eq(results_of("materials_bag")[1].text, L().MATERIALS_BAG_ROW_BIGGER)
  end,
  equal_or_smaller_is_fine_and_regular_rule_ignores_it = function()
    setup(); WOW.state.bags[5] = { numSlots = 16, family = 2048, items = {} }; WOW.state.inventory[24] = { itemID = MAT16 }
    WOW.state.bags[0].items[1] = { itemID = MAT12 }
    load_addon(); withConstants(); load_bags(); run_checks()
    assert_eq(#results_of("materials_bag"), 0); assert_eq(#results_of("bag_unequipped"), 0)
  end,
  subclass_constant_also_identifies_the_bag = function()
    setup(); WOW.state.bags[0].items[1] = { itemID = MAT12 }
    load_addon(); NewbieNudge.REAGENT_BAG_SUBCLASS = 11; wipe(NewbieNudge.appliesCache); load_bags(); run_checks()
    assert_eq(results_of("materials_bag")[1].text, L().MATERIALS_BAG_ROW_EMPTY)
  end,
}
