-- Rule demon: warlock without a demon summoned.
local L = function() return NewbieNudge.L end
local IMP, VOIDWALKER = 688, 697
local function warlock(level)
  WOW.state.class = "WARLOCK"; WOW.state.level = level or 12
  WOW.state.spellInfo[IMP] = { name = "Summon Imp" }; WOW.state.spellInfo[VOIDWALKER] = { name = "Summon Voidwalker" }
end
local function knows(id) WOW.state.spellBook.items[id] = { spellID = id } end
local function run() load_addon(); WOW.FireEvent("UNIT_PET", "player"); run_checks() end

return {
  no_demon_out_makes_a_row_with_bar_glow = function()
    warlock(); knows(IMP); WOW.state.actions[7] = { type = "spell", id = IMP }
    run()
    local r = results_of("demon")
    assert_eq(r[1].text, L().DEMON_ROW_MISSING)
    assert_eq(r[1].highlight, { action = { 7 } })
  end,
  demon_out_no_row = function()
    warlock(); knows(IMP); WOW.state.pet.exists = true
    run(); assert_eq(#results_of("demon"), 0)
  end,
  suppressed_when_resting_mounted_or_dead = function()
    warlock(); knows(IMP)
    WOW.state.resting = true; run(); assert_eq(#results_of("demon"), 0)
    WOW.state.resting = false; WOW.state.mounted = true; WOW.FireEvent("UNIT_PET", "player"); run_checks(); assert_eq(#results_of("demon"), 0)
    WOW.state.mounted = false; WOW.state.dead = true; WOW.FireEvent("UNIT_PET", "player"); run_checks(); assert_eq(#results_of("demon"), 0)
    WOW.state.dead = false; WOW.FireEvent("PLAYER_UPDATE_RESTING"); run_checks(); assert_eq(#results_of("demon"), 1)
  end,
  not_applicable_without_a_summon_spell_or_for_other_classes = function()
    warlock(); load_addon()
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.demon), "no summon spell known yet")
    knows(VOIDWALKER); WOW.FireEvent("SPELLS_CHANGED")
    assert_true(NewbieNudge:Applies(NewbieNudge.ruleByName.demon))
    WOW.state.class = "MAGE"; wipe(NewbieNudge.appliesCache); NewbieNudge.classFile = "MAGE"
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.demon))
  end,
}
