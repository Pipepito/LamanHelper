-- Rule trainer_spells: spells or ranks for your level you have not learned.
local L = function() return NewbieNudge.L end
local function known(...) for _, id in ipairs({ ... }) do WOW.state.spellBook.items[id] = { spellID = id } end end
local function exist(...) for _, id in ipairs({ ... }) do WOW.state.spellInfo[id] = WOW.state.spellInfo[id] or { name = "S" .. id } end end
local function setup() WOW.extraFiles = { TESTS_DIR .. "/fixtures/trainer_spells.lua" }; exist(133, 143, 145, 5143, 1180) end
local function run() load_addon(); WOW.FireEvent("SPELLS_CHANGED"); run_checks() end

return {
  counts_spells_not_ranks = function()
    setup(); WOW.state.level = 10; known(133)
    run() -- Fireball r2 (lvl 6) trainable, Arcane Missiles trainable; r3 needs 14; stale skipped; Gnome-only skipped
    local r = results_of("trainer_spells")
    assert_eq(r[1].text, L().TRAINER_SPELLS_ROW:format(2)); assert_eq(r[1].highlight, "spellbook")
    r[1].onClick(); assert_eq(WOW.calls[#WOW.calls][1], "ToggleSpellBook")
  end,
  higher_rank_known_suppresses_lower = function()
    setup(); WOW.state.level = 10; known(145, 5143)
    run(); assert_eq(#results_of("trainer_spells"), 0)
  end,
  race_locked_spell_counts_for_that_race = function()
    setup(); WOW.state.level = 10; WOW.state.raceToken = "Gnome"; known(133, 143, 5143)
    run(); assert_eq(results_of("trainer_spells")[1].text, L().TRAINER_SPELLS_ROW:format(1))
  end,
  level_gates_and_level_up_rechecks = function()
    setup(); WOW.state.level = 5; known(133)
    run(); assert_eq(#results_of("trainer_spells"), 0)
    WOW.state.level = 6; WOW.FireEvent("PLAYER_LEVEL_UP", 6); run_checks()
    assert_eq(results_of("trainer_spells")[1].text, L().TRAINER_SPELLS_ROW:format(1))
  end,
  not_applicable_for_class_without_data = function()
    setup(); WOW.state.class = "DEATHKNIGHT"
    load_addon()
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.trainer_spells))
  end,
  learning_the_spell_clears_the_row = function()
    setup(); WOW.state.level = 10; known(133, 143)
    run(); assert_eq(results_of("trainer_spells")[1].text, L().TRAINER_SPELLS_ROW:format(1))
    known(5143); WOW.FireEvent("LEARNED_SPELL_IN_SKILL_LINE", 5143); run_checks()
    assert_eq(#results_of("trainer_spells"), 0)
  end,
  -- v4 §4h: class quests and pet spells
  pet_spells_and_quest_spells_never_in_the_trainer_count = function()
    setup(); exist(5555, 7777); WOW.state.level = 10; known(133)
    run()
    assert_eq(results_of("trainer_spells")[1].text, L().TRAINER_SPELLS_ROW:format(2))
  end,
  quest_spell_gets_its_own_row = function()
    setup(); exist(7777); WOW.state.level = 10; known(133, 143, 5143)
    run()
    local r = results_of("trainer_spells")
    assert_eq(#r, 1)
    assert_eq(r[1].text, L().TRAINER_SPELLS_ROW_QUEST:format(10, "S7777"))
    assert_eq(r[1].service, { kind = "trainer_MAGE" })
  end,
  known_quest_spell_has_no_row = function()
    setup(); exist(7777); WOW.state.level = 10; known(133, 143, 5143, 7777)
    run()
    assert_eq(#results_of("trainer_spells"), 0)
  end,
  quest_spell_waits_for_its_level = function()
    setup(); exist(7777); WOW.state.level = 9; known(133, 143)
    run()
    assert_eq(#results_of("trainer_spells"), 0)
  end,
  two_quest_rows_then_a_count = function()
    setup(); exist(7777, 7778, 7779, 7780); WOW.state.level = 12; known(133, 143, 5143)
    run()
    local r = results_of("trainer_spells")
    assert_eq(#r, 3)
    assert_eq(r[1].text, L().TRAINER_SPELLS_ROW_QUEST:format(10, "S7777"))
    assert_eq(r[2].text, L().TRAINER_SPELLS_ROW_QUEST:format(12, "S7778"))
    assert_eq(r[3].text, L().TRAINER_SPELLS_ROW_QUEST_MORE:format(2))
  end,
}
