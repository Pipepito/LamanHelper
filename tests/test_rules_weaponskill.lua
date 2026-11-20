-- Rule weapon_skill: skill with the equipped weapon far behind its cap.
local L = function() return NewbieNudge.L end
local function skills(list) WOW.state.skillLines = list end
local function weapon(slot, id, subclass) WOW.state.itemInfo[id] = { name = "W" .. id, classID = 2, subclassID = subclass }; WOW.state.inventory[slot] = { itemID = id } end
local function run() load_addon(); WOW.FireEvent("SKILL_LINES_CHANGED"); run_checks() end
local LINES = {
  { name = "Weapon Skills", isHeader = true, category = 6 },
  { name = "Maces", rank = 5, maxRank = 40, skillID = 54, category = 6 },
  { name = "Staves", rank = 33, maxRank = 40, skillID = 136, category = 6 },
  { name = "Bows", rank = 2, maxRank = 40, skillID = 45, category = 6 },
}

return {
  mace_far_behind_makes_a_row = function()
    skills(LINES); weapon(16, 1, 4) -- one-hand mace
    run()
    local r = results_of("weapon_skill")
    assert_eq(r[1].text, L().WEAPON_SKILL_ROW:format("Maces", 5, 40))
    r[1].onClick(); assert_eq(WOW.calls[#WOW.calls], { "ToggleCharacter", "SkillFrame" })
  end,
  staff_within_twenty_no_row = function()
    skills(LINES); weapon(16, 2, 10) -- staff, 33/40
    run(); assert_eq(#results_of("weapon_skill"), 0)
  end,
  ranged_bow_counts_too = function()
    skills(LINES); weapon(16, 2, 10); weapon(18, 3, 2) -- bow 2/40
    run(); assert_eq(results_of("weapon_skill")[1].text, L().WEAPON_SKILL_ROW:format("Bows", 2, 40))
  end,
  two_handed_mace_maps_to_its_own_skill = function()
    skills({ { name = "Two-Handed Maces", rank = 1, maxRank = 40, skillID = 160, category = 6 } }); weapon(16, 4, 5)
    run(); assert_eq(results_of("weapon_skill")[1].text, L().WEAPON_SKILL_ROW:format("Two-Handed Maces", 1, 40))
  end,
  not_applicable_without_skill_api = function()
    _G.C_SkillInfo = nil
    load_addon()
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.weapon_skill))
  end,
  skill_lines_helper_marks_riding = function()
    skills({ { name = "Riding", rank = 75, maxRank = 75, skillID = 762, category = 9 }, { name = "Maces", rank = 5, maxRank = 40, skillID = 54, category = 6 } })
    load_addon()
    local lines = NewbieNudge.SkillLines()
    assert_eq(#lines, 2); assert_eq(lines[1].isRiding, true); assert_eq(lines[2].isRiding, false)
    assert_eq(NewbieNudge.HasRidingSkill(), true)
    skills({}); assert_eq(NewbieNudge.HasRidingSkill(), false)
  end,
}
