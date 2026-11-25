local L = function() return NewbieNudge.L end

local function fireballBook()
  local s = WOW.state
  s.spellInfo[133] = { name = "Fireball", subtext = "Rank 1", icon = 1133 }
  s.spellInfo[143] = { name = "Fireball", subtext = "Rank 2", icon = 1143 }
  s.spellInfo[116] = { name = "Frostbolt", subtext = "Rank 1", icon = 1116 }
  s.spellBook.lines = { { name = "Class", offset = 0, num = 3 } }
  s.spellBook.items = {
    [1] = { spellID = 133, lowRank = true },
    [2] = { spellID = 143 },
    [3] = { spellID = 116 },
  }
end

-- Learns Fireball Rank 2 (143) while Rank 1 (133) is on the bars.
local function learnRank2()
  WOW.FireEvent("LEARNED_SPELL_IN_SKILL_LINE", 143, 1)
  WOW.AdvanceTime(1)
end

return {
  learning_a_rank_swaps_old_ones_on_the_bars = function()
    fireballBook()
    WOW.state.actions[2] = { type = "spell", id = 133 }
    WOW.state.actions[25] = { type = "spell", id = 133 }
    WOW.state.actions[3] = { type = "spell", id = 116 }
    load_addon()
    learnRank2()
    assert_eq(WOW.state.actions[2].id, 143)
    assert_eq(WOW.state.actions[25].id, 143)
    assert_eq(WOW.state.actions[3].id, 116, "other spells untouched")
    assert_nil(WOW.state.cursor)
    assert_eq(WOW.printed[#WOW.printed], L().CHAT_PREFIX .. L().SPELL_RANKS_AUTO:format("Fireball", "Rank 2"))
  end,
  auto_swap_off_leaves_the_bars_alone = function()
    fireballBook()
    WOW.state.actions[2] = { type = "spell", id = 133 }
    load_addon()
    NewbieNudge.db.ranks.autoSwap = false
    learnRank2()
    assert_eq(WOW.state.actions[2].id, 133)
  end,
  in_combat_waits_until_combat_ends = function()
    fireballBook()
    WOW.state.actions[2] = { type = "spell", id = 133 }
    load_addon()
    WOW.state.inCombat = true
    learnRank2()
    assert_eq(WOW.state.actions[2].id, 133)
    WOW.state.inCombat = false
    WOW.FireEvent("PLAYER_REGEN_ENABLED")
    assert_eq(WOW.state.actions[2].id, 143)
  end,
  low_rank_placed_by_hand_later_is_kept = function()
    fireballBook()
    load_addon()
    learnRank2()
    WOW.state.actions[7] = { type = "spell", id = 133 }
    WOW.FireEvent("SPELLS_CHANGED"); WOW.AdvanceTime(1)
    assert_eq(WOW.state.actions[7].id, 133)
  end,
  low_rank_on_bar_is_reported_with_ranks = function()
    fireballBook()
    WOW.state.actions[2] = { type = "spell", id = 133 }
    load_addon(); run_checks()
    local r = results_of("spell_ranks")
    assert_eq(#r, 1)
    assert_eq(r[1].text, L().SPELL_RANKS_ROW:format("Fireball", "Rank 1", "Rank 2"))
    assert_eq(r[1].highlight, { action = { 2 } })
    assert_eq(r[1].icon, 1143)
  end,
  top_rank_on_bar_is_fine = function()
    fireballBook()
    WOW.state.actions[2] = { type = "spell", id = 143 }
    WOW.state.actions[3] = { type = "spell", id = 116 }
    load_addon(); run_checks()
    assert_eq(#results_of("spell_ranks"), 0)
  end,
  two_slots_same_spell_one_row_both_glow = function()
    fireballBook()
    WOW.state.actions[2] = { type = "spell", id = 133 }
    WOW.state.actions[25] = { type = "spell", id = 133 }
    load_addon(); run_checks()
    local r = results_of("spell_ranks")
    assert_eq(#r, 1)
    assert_eq(r[1].highlight, { action = { 2, 25 } })
  end,
  click_swaps_every_slot_and_clears_cursor = function()
    fireballBook()
    WOW.state.actions[2] = { type = "spell", id = 133 }
    WOW.state.actions[25] = { type = "spell", id = 133 }
    load_addon(); run_checks()
    results_of("spell_ranks")[1].onClick()
    assert_eq(WOW.state.actions[2].id, 143)
    assert_eq(WOW.state.actions[25].id, 143)
    assert_nil(WOW.state.cursor)
    run_checks()
    assert_eq(#results_of("spell_ranks"), 0)
  end,
  click_refuses_in_combat = function()
    fireballBook()
    WOW.state.actions[2] = { type = "spell", id = 133 }
    load_addon(); run_checks()
    WOW.state.inCombat = true
    results_of("spell_ranks")[1].onClick()
    assert_eq(WOW.state.actions[2].id, 133)
  end,
  click_refuses_with_full_cursor = function()
    fireballBook()
    WOW.state.actions[2] = { type = "spell", id = 133 }
    load_addon(); run_checks()
    WOW.state.cursor = { type = "item", id = 6948 }
    results_of("spell_ranks")[1].onClick()
    assert_eq(WOW.state.actions[2].id, 133)
    assert_eq(WOW.state.cursor.id, 6948)
  end,
  macros_ignored = function()
    fireballBook()
    WOW.state.actions[2] = { type = "macro", id = 133 }
    load_addon(); run_checks()
    assert_eq(#results_of("spell_ranks"), 0)
  end,
  missing_subtext_uses_norank_text = function()
    fireballBook()
    WOW.state.spellInfo[133].subtext = nil
    WOW.state.actions[2] = { type = "spell", id = 133 }
    load_addon(); run_checks()
    assert_eq(results_of("spell_ranks")[1].text, L().SPELL_RANKS_ROW_NORANK:format("Fireball"))
  end,
}
