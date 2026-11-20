local L = function() return NewbieNudge.L end

-- Item IDs used by these tests
local BAG6, BAG10, QUIVER = 4496, 4241, 2101

local function setup()
  local s = WOW.state
  s.itemInfo[BAG6] = { name = "Small Brown Pouch", classID = 1, subclassID = 0, family = 0, numSlots = 6 }
  s.itemInfo[BAG10] = { name = "Green Leather Bag", classID = 1, subclassID = 0, family = 0, numSlots = 10 }
  s.itemInfo[QUIVER] = { name = "Light Quiver", classID = 1, subclassID = 2, family = 1, numSlots = 6 }
  s.itemInfo[2589] = { name = "Linen Cloth", classID = 7, subclassID = 5, family = 0 }
end

local function equipBag(bagID, itemID, numSlots, family)
  WOW.state.bags[bagID] = { numSlots = numSlots, family = family or 0, items = {} }
  WOW.state.inventory[19 + bagID] = { itemID = itemID }
end

local function putInBackpack(slot, itemID)
  WOW.state.bags[0].items[slot] = { itemID = itemID }
end

local function fill(bagID, n, itemID)
  for i = 1, n do WOW.state.bags[bagID].items[i] = { itemID = itemID or 2589 } end
end

return {
  nothing_before_bags_loaded = function()
    setup(); putInBackpack(1, BAG6)
    load_addon()
    run_checks()
    assert_eq(#results_of("bag_unequipped"), 0)
  end,
  bag_slots_resolved_through_container_api = function()
    -- The client decides which inventory slots hold the bags; 20-23 is not a given.
    setup()
    WOW.state.bagSlotBase = 29
    for b = 1, 4 do
      WOW.state.bags[b] = { numSlots = 6, family = 0, items = {} }
      WOW.state.inventory[29 + b] = { itemID = BAG6 }
    end
    putInBackpack(1, BAG6)
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("bag_unequipped"), 0, "equal bags and no empty slot: no row")
  end,
  bag_in_inventory_with_empty_slot = function()
    setup(); putInBackpack(1, BAG6)
    load_addon(); load_bags(); run_checks()
    local r = results_of("bag_unequipped")
    assert_eq(r[1].text, L().BAG_UNEQUIPPED_ROW_EMPTY)
    assert_eq(r[1].highlight, "bags")
    r[1].onClick()
    assert_eq(WOW.calls[#WOW.calls][1], "ToggleAllBags")
  end,
  bigger_bag_than_smallest_equipped = function()
    setup()
    for b = 1, 4 do equipBag(b, BAG6, 6) end
    putInBackpack(1, BAG10)
    load_addon(); load_bags(); run_checks()
    assert_eq(results_of("bag_unequipped")[1].text, L().BAG_UNEQUIPPED_ROW_BIGGER)
  end,
  smaller_bag_is_fine = function()
    setup()
    for b = 1, 4 do equipBag(b, BAG10, 10) end
    putInBackpack(1, BAG6)
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("bag_unequipped"), 0)
  end,
  equal_bag_is_fine = function()
    setup()
    for b = 1, 4 do equipBag(b, BAG6, 6) end
    putInBackpack(1, BAG6)
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("bag_unequipped"), 0)
  end,
  quiver_ignored_for_non_ammo_user = function()
    setup(); putInBackpack(1, QUIVER)
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("bag_unequipped"), 0)
  end,
  quiver_counts_for_ammo_user = function()
    setup(); putInBackpack(1, QUIVER)
    WOW.state.usesAmmo = true
    load_addon(); load_bags(); run_checks()
    assert_eq(results_of("bag_unequipped")[1].text, L().BAG_UNEQUIPPED_ROW_EMPTY)
  end,
  bag_full_below_three_free = function()
    setup()
    fill(0, 14)
    load_addon(); load_bags(); run_checks()
    local r = results_of("bag_full")
    assert_eq(r[1].text, L().BAG_FULL_ROW:format(2))
    assert_eq(r[1].highlight, "bags")
  end,
  bag_full_ok_at_three = function()
    setup()
    fill(0, 13)
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("bag_full"), 0)
  end,
  bag_full_ignores_quiver_family = function()
    setup()
    fill(0, 15)
    equipBag(1, QUIVER, 6, 1) -- 6 free quiver slots must not count
    load_addon(); load_bags(); run_checks()
    assert_eq(results_of("bag_full")[1].text, L().BAG_FULL_ROW:format(1))
  end,
  bag_rules_update_in_combat = function()
    assert_eq(NewbieNudge == nil, true)
    load_addon()
    assert_eq(NewbieNudge.ruleByName.bag_full.combat, true)
    assert_eq(NewbieNudge.ruleByName.bag_unequipped.combat, true)
  end,
}
