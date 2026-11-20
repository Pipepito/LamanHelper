-- Rule supplies: no food or drink, and no bandages for a First Aid user.
local L = function() return NewbieNudge.L end
local function item(id, class, sub) WOW.state.itemInfo[id] = { name = "I" .. id, classID = class, subclassID = sub } end
local function put(slot, id) WOW.state.bags[0].items[slot] = { itemID = id } end
local function run() load_addon(); load_bags(); run_checks() end

return {
  no_food_row_from_level_5 = function()
    WOW.state.level = 5
    run()
    local r = results_of("supplies")
    assert_eq(r[1].text, L().SUPPLIES_ROW_FOOD); assert_eq(r[1].highlight, "bags")
    r[1].onClick(); assert_eq(WOW.calls[#WOW.calls][1], "ToggleAllBags")
  end,
  food_present_no_row = function()
    WOW.state.level = 20; item(1, 0, 5); put(1, 1)
    run(); assert_eq(#results_of("supplies"), 0)
  end,
  bandage_row_only_with_first_aid = function()
    WOW.state.level = 20; item(1, 0, 5); put(1, 1)
    WOW.state.professions = { prof1 = 1, firstAid = 6 }; WOW.state.professionInfo[6] = { name = "First Aid", skill = 30, maxSkill = 75, skillLine = 129 }
    run()
    assert_eq(results_of("supplies")[1].text, L().SUPPLIES_ROW_BANDAGE)
    item(2, 0, 7); put(2, 2); WOW.FireEvent("BAG_UPDATE_DELAYED"); run_checks()
    assert_eq(#results_of("supplies"), 0)
  end,
  no_bandage_row_without_first_aid = function()
    WOW.state.level = 20; item(1, 0, 5); put(1, 1)
    run(); assert_eq(#results_of("supplies"), 0)
  end,
  below_level_5_not_applicable = function()
    WOW.state.level = 4; load_addon()
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.supplies))
  end,
}
