-- Rule profession_rank: the next rank of a primary profession is available.
local L = function() return NewbieNudge.L end
local function prof(idx, name, skill, max) WOW.state.professionInfo[idx] = { name = name, skill = skill, maxSkill = max } end
local function run() load_addon(); WOW.FireEvent("SKILL_LINES_CHANGED"); run_checks() end

return {
  ready_table = function()
    load_addon()
    local f = NewbieNudge.ProfessionRankReady
    assert_true(f(50, 75, 10)); assert_true(not f(49, 75, 10)); assert_true(not f(50, 75, 9))
    assert_true(f(125, 150, 20)); assert_true(f(200, 225, 35)); assert_true(not f(290, 300, 60)); assert_true(not f(70, 80, 60))
  end,
  row_per_ready_primary_with_client_name = function()
    WOW.state.level = 22; WOW.state.professions = { prof1 = 1, prof2 = 2 }
    prof(1, "Alchemy", 60, 75); prof(2, "Herbalism", 130, 150)
    run()
    local r = results_of("profession_rank")
    assert_eq(#r, 2)
    assert_eq(r[1].text, L().PROFESSION_RANK_ROW:format("Alchemy", 60, 75, "Alchemy"))
  end,
  secondary_professions_ignored = function()
    WOW.state.level = 22; WOW.state.professions = { prof1 = nil, prof2 = nil }
    prof(5, "Cooking", 70, 75)
    load_addon()
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.profession_rank))
  end,
  clears_when_cap_rises = function()
    WOW.state.level = 22; WOW.state.professions = { prof1 = 1 }; prof(1, "Alchemy", 60, 75)
    run(); assert_eq(#results_of("profession_rank"), 1)
    WOW.state.professionInfo[1].maxSkill = 150; WOW.FireEvent("SKILL_LINES_CHANGED"); run_checks()
    assert_eq(#results_of("profession_rank"), 0)
  end,
  not_ready_below_level_requirement = function()
    WOW.state.level = 18; WOW.state.professions = { prof1 = 1 }; prof(1, "Mining", 140, 150)
    run(); assert_eq(#results_of("profession_rank"), 0)
    WOW.state.level = 20; WOW.FireEvent("PLAYER_LEVEL_UP", 20); run_checks()
    assert_eq(#results_of("profession_rank"), 1)
  end,
  -- secondaries: trainer at 50, a vendor book at 125, a level-35 quest at 225
  secondary_journeyman_from_trainer = function()
    WOW.state.level = 12; WOW.state.professions = { firstAid = 6 }; prof(6, "First Aid", 55, 75)
    run()
    assert_eq(results_of("profession_rank")[1].text, L().PROFESSION_RANK_ROW:format("First Aid", 55, 75, "First Aid"))
  end,
  expert_says_book_artisan_says_quest = function()
    WOW.state.level = 36; WOW.state.professions = { fishing = 4, cooking = 5 }
    prof(4, "Fishing", 130, 150); prof(5, "Cooking", 226, 225)
    run()
    local r = results_of("profession_rank")
    assert_eq(r[1].text, L().PROFESSION_RANK_ROW_BOOK:format("Fishing", 150))
    assert_eq(r[2].text, L().PROFESSION_RANK_ROW_QUEST:format("Cooking", 225))
    WOW.state.level = 34; WOW.FireEvent("SKILL_LINES_CHANGED"); run_checks()
    assert_eq(#results_of("profession_rank"), 1, "artisan quest needs level 35")
  end,
  applies_with_only_a_secondary = function()
    WOW.state.professions = { prof1 = nil, cooking = 5 }; prof(5, "Cooking", 1, 75)
    load_addon(); assert_true(NewbieNudge:Applies(NewbieNudge.ruleByName.profession_rank))
  end,
  row_cap_three = function()
    WOW.state.level = 40; WOW.state.professions = { prof1 = 1, prof2 = 2, fishing = 4, cooking = 5 }
    prof(1, "Alchemy", 60, 75); prof(2, "Mining", 60, 75); prof(4, "Fishing", 130, 150); prof(5, "Cooking", 130, 150)
    run(); assert_eq(#results_of("profession_rank"), 3)
  end,
}
