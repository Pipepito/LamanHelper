-- Rule weapon_trainers (v4): weapon skills the class can learn but hasn't,
-- grouped by the city of the player's faction that teaches them.
local L = function() return NewbieNudge.L end
local NAMES = { [0] = "One-Handed Axes", [1] = "Two-Handed Axes", [2] = "Bows", [3] = "Guns", [4] = "One-Handed Maces",
  [5] = "Two-Handed Maces", [6] = "Polearms", [7] = "One-Handed Swords", [8] = "Two-Handed Swords", [10] = "Staves",
  [13] = "Fist Weapons", [15] = "Daggers", [16] = "Thrown", [18] = "Crossbows" }

-- class, faction, level, known weapon skill IDs
local function char(class, faction, level, known)
  local s = WOW.state
  s.class, s.faction, s.level = class, faction, level
  s.subclassNames = NAMES
  s.mapInfo = { [1453] = { name = "Stormwind City" }, [1455] = { name = "Ironforge" }, [1457] = { name = "Darnassus" },
    [1454] = { name = "Orgrimmar" }, [1456] = { name = "Thunder Bluff" }, [1458] = { name = "Undercity" } }
  s.skillLines = { { name = "Weapon Skills", isHeader = true } }
  for _, id in ipairs(known) do s.skillLines[#s.skillLines + 1] = { name = "skill" .. id, skillID = id, rank = 1, maxRank = 5 } end
end
local function run() load_addon(); WOW.FireEvent("SKILL_LINES_CHANGED"); run_checks() end
local function texts()
  local out = {}
  for _, r in ipairs(results_of("weapon_trainers")) do out[#out + 1] = r.text end
  return out
end
local function row(weapons, city, trainers) return L().WEAPON_TRAINERS_ROW:format(weapons, city, trainers) end

return {
  -- Forever (2026-11-23, druid): learning Fist Weapons adds no skill line 473,
  -- only the Fist Weapons spell (15590) in the spellbook.
  weapon_known_by_its_spell_without_a_skill_line = function()
    char("DRUID", "Horde", 15, { 173, 54, 136, 160, 162 })
    WOW.state.spellBook.items[40] = { spellID = 15590, passive = true }
    WOW.state.spellInfo[15590] = { name = "Fist Weapons" }
    run()
    assert_eq(#results_of("weapon_trainers"), 0)
  end,
  alliance_mage_learns_everything_in_stormwind = function()
    char("MAGE", "Alliance", 12, { 228 }) -- wands only
    run()
    assert_eq(texts(), { row("One-Handed Swords, Daggers, Staves", "Stormwind City", "Woo Ping") })
  end,
  learned_skills_drop_out = function()
    char("MAGE", "Alliance", 12, { 228, 173, 136 })
    run()
    assert_eq(texts(), { row("One-Handed Swords", "Stormwind City", "Woo Ping") })
  end,
  nothing_left_to_learn_no_row = function()
    char("MAGE", "Alliance", 12, { 228, 173, 136, 43 })
    run()
    assert_eq(#results_of("weapon_trainers"), 0)
  end,
  horde_mage_two_cities_and_shared_shop = function()
    char("MAGE", "Horde", 12, { 228 })
    run()
    assert_eq(texts(), {
      row("Daggers, Staves", "Orgrimmar", "Sayoc " .. L().WEAPON_TRAINERS_OR .. " Hanashi"),
      row("One-Handed Swords", "Undercity", "Archibald"),
    })
  end,
  only_trainers_teaching_a_missing_skill_are_named = function()
    char("MAGE", "Horde", 12, { 228, 136 }) -- staves known: only daggers left in Orgrimmar (Sayoc)
    run()
    assert_eq(texts()[1], row("Daggers", "Orgrimmar", "Sayoc"))
  end,
  polearms_only_from_level_20 = function()
    char("DRUID", "Alliance", 15, { 54, 136, 173, 473, 160 }) -- missing only polearms
    run()
    assert_eq(#results_of("weapon_trainers"), 0)
    char("DRUID", "Alliance", 20, { 54, 136, 173, 473, 160 })
    run()
    assert_eq(texts(), { row("Polearms", "Stormwind City", "Woo Ping") })
  end,
  forever_rogue_axes_go_to_ironforge = function()
    char("ROGUE", "Alliance", 12, { 45, 226, 173, 473, 46, 54, 43, 176 }) -- all but one-handed axes
    run()
    assert_eq(texts(), { row("One-Handed Axes", "Ironforge", "Buliwyf Stonehand") })
  end,
  a_skill_taught_twice_shows_under_the_first_city = function()
    char("WARRIOR", "Alliance", 20, { 43, 55, 136, 226, 229, 44, 172, 54, 160, 473, 46, 45, 176 }) -- missing daggers only
    run()
    assert_eq(texts(), { row("Daggers", "Stormwind City", "Woo Ping") })
  end,
  not_before_level_10 = function()
    char("MAGE", "Alliance", 9, { 228 })
    run()
    assert_eq(NewbieNudge:Applies(NewbieNudge.ruleByName.weapon_trainers), false)
  end,
  silent_when_no_weapon_skill_is_known_yet = function()
    char("MAGE", "Alliance", 12, {}) -- skill list not loaded yet
    run()
    assert_eq(#results_of("weapon_trainers"), 0)
  end,
  silent_without_skill_api = function()
    char("MAGE", "Alliance", 12, { 228 })
    C_SkillInfo = nil
    run()
    assert_eq(#results_of("weapon_trainers"), 0)
  end,
  weapon_names_come_from_the_client = function()
    char("MAGE", "Alliance", 12, { 228, 173, 136 })
    WOW.state.subclassNames = { [7] = "Espadas de una mano" }
    run()
    assert_eq(texts(), { row("Espadas de una mano", "Stormwind City", "Woo Ping") })
  end,
  grouped_with_spells_after_weapon_skill = function()
    char("MAGE", "Alliance", 12, { 228 })
    load_addon()
    local rule = NewbieNudge.ruleByName.weapon_trainers
    assert_eq(rule.group, "spells")
    local pos = {}
    for i, name in ipairs(NewbieNudge.PRIORITY) do pos[name] = i end
    assert_eq(pos.weapon_trainers, pos.weapon_skill + 1)
  end,
}
