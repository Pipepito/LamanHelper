-- Builds a spellbook with one skill line holding the given items.
local function book(items)
  local s = WOW.state
  s.spellBook.lines = { { name = "Fire", offset = 0, num = #items } }
  s.spellBook.items = {}
  for i, it in ipairs(items) do
    s.spellBook.items[i] = { spellID = it.id, passive = it.passive, lowRank = it.lowRank }
    s.spellInfo[it.id] = s.spellInfo[it.id] or { name = it.name, subtext = it.subtext }
  end
end

return {
  top_rank_by_name_skips_low_ranks_and_passives = function()
    book({ { id = 133, name = "Fireball", lowRank = true }, { id = 143, name = "Fireball" }, { id = 999, name = "Fireball", passive = true } })
    load_addon()
    assert_eq(NewbieNudge.Spellbook:TopRankByName("Fireball"), 143)
    assert_nil(NewbieNudge.Spellbook:TopRankByName("Frostbolt"))
  end,
  knows_by_name_matches_other_rank = function()
    book({ { id = 143, name = "Fireball" } })
    WOW.state.spellInfo[133] = { name = "Fireball" }
    load_addon()
    assert_true(NewbieNudge.Spellbook:Knows(133))
    assert_true(NewbieNudge.Spellbook:KnowsAny({ 1, 133 }))
    assert_true(not NewbieNudge.Spellbook:Knows(1))
  end,
  offspec_lines_ignored = function()
    book({ { id = 143, name = "Fireball" } })
    WOW.state.spellBook.lines[1].offSpecID = 63
    load_addon()
    assert_nil(NewbieNudge.Spellbook:TopRankByName("Fireball"))
  end,
  -- Forever (2026-11-22, druid herbalist): the skill lines cover slots 1-34,
  -- but Find Herbs sits at slot 38, outside every line.
  knows_spell_outside_every_skill_line = function()
    book({ { id = 143, name = "Fireball" } })
    WOW.state.spellBook.items[38] = { spellID = 2383 }
    WOW.state.spellInfo[2383] = { name = "Find Herbs" }
    load_addon()
    assert_true(NewbieNudge.Spellbook:Knows(2383))
  end,
  offspec_spell_found_by_slot_is_still_unknown = function()
    book({ { id = 143, name = "Fireball" } })
    WOW.state.spellBook.lines[1].offSpecID = 63
    load_addon()
    assert_true(not NewbieNudge.Spellbook:Knows(143))
  end,
  future_spell_found_by_slot_is_unknown = function()
    book({})
    WOW.state.spellBook.items[38] = { spellID = 2383, type = "FUTURESPELL" }
    WOW.state.spellInfo[2383] = { name = "Find Herbs" }
    load_addon()
    assert_true(not NewbieNudge.Spellbook:Knows(2383))
  end,
  invalidate_rebuilds_after_spells_changed = function()
    book({ { id = 143, name = "Fireball" } })
    load_addon()
    assert_nil(NewbieNudge.Spellbook:TopRankByName("Frostbolt"))
    WOW.state.spellBook.items[2] = { spellID = 116 }
    WOW.state.spellBook.lines[1].num = 2
    WOW.state.spellInfo[116] = { name = "Frostbolt" }
    assert_nil(NewbieNudge.Spellbook:TopRankByName("Frostbolt"), "still cached")
    WOW.FireEvent("SPELLS_CHANGED")
    assert_eq(NewbieNudge.Spellbook:TopRankByName("Frostbolt"), 116)
  end,
  is_low_rank_guarded_when_spell_not_in_book = function()
    book({ { id = 133, name = "Fireball", lowRank = true } })
    load_addon()
    assert_eq(NewbieNudge.Spellbook:IsLowRank(133), true)
    assert_eq(NewbieNudge.Spellbook:IsLowRank(4242), false)
  end,
  action_slots_for_name_finds_every_rank = function()
    book({ { id = 133, name = "Fireball", lowRank = true }, { id = 143, name = "Fireball" } })
    WOW.state.actions[2] = { type = "spell", id = 133 }
    WOW.state.actions[14] = { type = "spell", id = 143 }
    WOW.state.actions[3] = { type = "macro", id = 1 }
    load_addon()
    assert_eq(NewbieNudge.Spellbook:ActionSlotsForName("Fireball"), { 2, 14 })
  end,
}
