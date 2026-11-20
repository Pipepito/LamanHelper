local L = function() return NewbieNudge.L end

-- Puts the given spells (id -> name) in the spellbook as top ranks.
local function knows(spells)
  local s = WOW.state
  local items, i = {}, 0
  for id, name in pairs(spells) do
    i = i + 1
    items[i] = { spellID = id }
    s.spellInfo[id] = { name = name, icon = 100 + id }
  end
  s.spellBook.lines = { { name = "Class", offset = 0, num = i } }
  s.spellBook.items = items
end

local function mage()
  WOW.state.class = "MAGE"
  knows({ [1459] = "Arcane Intellect", [168] = "Frost Armor" })
  WOW.state.spellInfo[7302] = { name = "Ice Armor" }
  WOW.state.spellInfo[6117] = { name = "Mage Armor" }
end

return {
  missing_buff_row_with_action_glow = function()
    mage()
    WOW.state.actions[5] = { type = "spell", id = 1459 }
    WOW.state.auras[168] = true
    load_addon(); run_checks()
    local r = results_of("buffs")
    assert_eq(#r, 1)
    assert_eq(r[1].text, L().BUFFS_ROW:format("Arcane Intellect"))
    assert_eq(r[1].highlight, { action = { 5 } })
    assert_nil(r[1].onClick)
    assert_eq(r[1].icon, 100 + 1459)
  end,
  missing_buff_not_on_bar_uses_spellbook_highlight = function()
    mage()
    WOW.state.auras[168] = true
    load_addon(); run_checks()
    local r = results_of("buffs")
    assert_eq(r[1].text, L().BUFFS_ROW_NOT_ON_BAR:format("Arcane Intellect"))
    assert_eq(r[1].highlight, "spellbook")
    r[1].onClick()
    assert_eq(WOW.calls[#WOW.calls][1], "ToggleSpellBook")
  end,
  aura_by_higher_rank_name_satisfies = function()
    mage()
    WOW.state.auras["Arcane Intellect"] = true
    WOW.state.auras[168] = true
    load_addon(); run_checks()
    assert_eq(#results_of("buffs"), 0)
  end,
  unknown_group_skipped = function()
    WOW.state.class = "MAGE"
    knows({ [1459] = "Arcane Intellect" })
    load_addon(); run_checks()
    assert_eq(#results_of("buffs"), 1)
  end,
  armor_group_any_of = function()
    mage()
    WOW.state.auras[1459] = true
    WOW.state.auras[7302] = true -- Ice Armor satisfies the armor group even though only Frost Armor is known
    load_addon(); run_checks()
    assert_eq(#results_of("buffs"), 0)
  end,
  weapon_group_uses_enchant = function()
    WOW.state.class = "SHAMAN"
    knows({ [8017] = "Rockbiter Weapon", [324] = "Lightning Shield" })
    WOW.state.auras[324] = true
    load_addon(); run_checks()
    local r = results_of("buffs")
    assert_eq(r[1].text, L().BUFFS_ROW_WEAPON:format("Rockbiter Weapon"))
    WOW.state.weaponEnchant.main = true
    WOW.FireEvent("UNIT_AURA", "player"); run_checks()
    assert_eq(#results_of("buffs"), 0)
  end,
  weapon_enchant_table_shape_handled = function()
    WOW.state.class = "SHAMAN"
    knows({ [8017] = "Rockbiter Weapon" })
    C_Item.GetWeaponEnchantInfo = function() return { hasMainHandEnchant = true } end
    load_addon(); run_checks()
    assert_eq(#results_of("buffs"), 0)
  end,
  warrior_not_applicable = function()
    WOW.state.class = "WARRIOR"
    load_addon(); run_checks()
    assert_eq(NewbieNudge:Applies(NewbieNudge.ruleByName.buffs), false)
  end,
  more_than_three_collapses = function()
    WOW.state.class = "MAGE"
    knows({ [1] = "A", [2] = "B", [3] = "C", [4] = "D" })
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/four_buff_groups.lua" }
    load_addon(); run_checks()
    local r = results_of("buffs")
    assert_eq(#r, 4)
    assert_eq(r[4].text, L().MORE_ROWS:format(1))
  end,
  reacts_to_unit_aura_player = function()
    mage()
    WOW.state.auras[1459] = true; WOW.state.auras[168] = true
    load_addon(); run_checks()
    assert_eq(#results_of("buffs"), 0)
    WOW.state.auras[1459] = nil
    WOW.FireEvent("UNIT_AURA", "player"); run_checks()
    assert_eq(#results_of("buffs"), 1)
  end,
  buff_data_has_expected_classes = function()
    load_addon()
    for _, class in ipairs({ "MAGE", "PRIEST", "DRUID", "WARLOCK", "SHAMAN", "PALADIN", "HUNTER", "ROGUE" }) do
      assert_true(NewbieNudge.BuffData[class], class)
    end
    assert_nil(NewbieNudge.BuffData.WARRIOR)
    assert_eq(NewbieNudge.BuffData.MAGE[1].ids, { 1459 })
    assert_eq(NewbieNudge.BuffData.ROGUE[1].weapon, true)
  end,
}
