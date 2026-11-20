local L = function() return NewbieNudge.L end
local HEARTH = 6948

local function equip(slot, cur, max)
  WOW.state.inventory[slot] = { itemID = 1000 + slot, durability = { cur, max } }
end

return {
  durability_low_at_19_percent = function()
    equip(5, 19, 100)
    load_addon(); run_checks()
    local r = results_of("durability")
    assert_eq(r[1].text, L().DURABILITY_ROW_LOW)
    assert_eq(r[1].highlight, "character")
    r[1].onClick()
    assert_eq(WOW.calls[#WOW.calls][2], "PaperDollFrame")
  end,
  durability_ok_at_20_percent = function()
    equip(5, 20, 100)
    load_addon(); run_checks()
    assert_eq(#results_of("durability"), 0)
  end,
  durability_broken_wins_over_low = function()
    equip(5, 10, 100); equip(7, 0, 80)
    load_addon(); run_checks()
    assert_eq(results_of("durability")[1].text, L().DURABILITY_ROW_BROKEN)
  end,
  durability_secret_value_keeps_previous = function()
    equip(5, 10, 100)
    load_addon(); run_checks()
    assert_eq(results_of("durability")[1].text, L().DURABILITY_ROW_LOW)
    local printed = #WOW.printed
    WOW.state.inventory[5].durability = { WOW.secret(1), 100 }
    WOW.state.inCombat = true
    WOW.FireEvent("UPDATE_INVENTORY_DURABILITY"); run_checks()
    assert_eq(results_of("durability")[1].text, L().DURABILITY_ROW_LOW)
    assert_eq(#WOW.printed, printed)
  end,
  hearthstone_silent_before_bags_loaded = function()
    load_addon(); run_checks()
    assert_eq(#results_of("hearthstone"), 0)
  end,
  hearthstone_missing_after_bags_loaded = function()
    load_addon(); load_bags(); run_checks()
    local r = results_of("hearthstone")
    assert_eq(r[1].text, L().HEARTHSTONE_ROW)
    assert_nil(r[1].onClick); assert_nil(r[1].highlight)
  end,
  hearthstone_present_is_fine = function()
    WOW.state.itemCounts[HEARTH] = 1
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("hearthstone"), 0)
  end,
  mail_row_when_new_mail = function()
    load_addon(); run_checks()
    assert_eq(#results_of("mail"), 0)
    WOW.state.newMail = true
    WOW.FireEvent("UPDATE_PENDING_MAIL"); run_checks()
    assert_eq(results_of("mail")[1].text, L().MAIL_ROW)
    assert_eq(results_of("mail")[1].highlight, "mail")
  end,
  quests_row_at_22_of_25 = function()
    WOW.state.quests.num = 22
    load_addon(); run_checks()
    local r = results_of("quests")
    assert_eq(r[1].text, L().QUESTS_ROW:format(22, 25))
    assert_eq(r[1].highlight, "quests")
    r[1].onClick()
    assert_eq(WOW.calls[#WOW.calls][1], "ToggleQuestLog")
  end,
  quests_ok_at_21 = function()
    WOW.state.quests.num = 21
    load_addon(); run_checks()
    assert_eq(#results_of("quests"), 0)
  end,
  quests_uses_max_from_api = function()
    WOW.state.quests.num = 17; WOW.state.quests.max = 20
    load_addon(); run_checks()
    assert_eq(results_of("quests")[1].text, L().QUESTS_ROW:format(17, 20))
  end,
  quests_default_max_when_api_missing = function()
    C_QuestLog.GetMaxNumQuestsCanAccept = nil
    WOW.state.quests.num = 22
    load_addon(); run_checks()
    assert_eq(results_of("quests")[1].text, L().QUESTS_ROW:format(22, 25))
  end,
  combat_flags = function()
    load_addon()
    assert_eq(NewbieNudge.ruleByName.durability.combat, true)
    assert_eq(NewbieNudge.ruleByName.hearthstone.combat, true)
    assert_eq(NewbieNudge.ruleByName.mail.combat, true)
    assert_eq(NewbieNudge.ruleByName.quests.combat, false)
  end,
}
