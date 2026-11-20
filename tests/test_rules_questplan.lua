-- Rules quest_turnin / quest_soon / quest_grey, sharing NN.QuestScan.
local L = function() return NewbieNudge.L end
local function run() WOW.FireEvent("QUEST_LOG_UPDATE"); run_checks() end

return {
  turnin_counts_complete_quests = function()
    WOW.Quest({ questID = 1, title = "A", level = 20, isComplete = true }); WOW.Quest({ questID = 2, title = "B", level = 20 })
    WOW.Quest({ title = "Header", isHeader = true })
    load_addon(); run()
    local r = results_of("quest_turnin")
    assert_eq(r[1].text, L().QUEST_TURNIN_ROW:format(1)); assert_eq(r[1].highlight, "quests")
    r[1].onClick(); assert_eq(WOW.calls[#WOW.calls][1], "ToggleQuestLog")
  end,
  turnin_hides_when_handed_in = function()
    WOW.Quest({ questID = 1, title = "A", level = 20, isComplete = true })
    load_addon(); run(); assert_eq(#results_of("quest_turnin"), 1)
    WOW.state.questLog = {}; WOW.FireEvent("QUEST_TURNED_IN", 1); run_checks()
    assert_eq(#results_of("quest_turnin"), 0)
  end,
  soon_uses_trivial_range = function()
    WOW.state.level = 20; WOW.state.trivialRange = 5
    WOW.Quest({ questID = 1, title = "A", level = 14, trivial = true }) -- the client says grey; not soon
    WOW.Quest({ questID = 2, title = "B", level = 16 }) -- grey at 22 -> turnsGreyIn 2 -> soon
    WOW.Quest({ questID = 3, title = "C", level = 18 }) -- grey at 24 -> not soon
    load_addon(); run()
    assert_eq(results_of("quest_soon")[1].text, L().QUEST_SOON_ROW:format(1))
    assert_eq(results_of("quest_grey")[1].text, L().QUEST_GREY_ROW:format(1))
  end,
  grey_prefers_client_api_when_present = function()
    WOW.state.level = 20
    WOW.Quest({ questID = 1, title = "A", level = 19, trivial = true })
    load_addon(); run()
    assert_eq(results_of("quest_grey")[1].text, L().QUEST_GREY_ROW:format(1))
    assert_eq(#results_of("quest_soon"), 0, "trivial quests are not 'soon'")
  end,
  grey_fallback_without_api = function()
    WOW.state.level = 20; C_QuestLog.IsQuestTrivial = nil
    WOW.Quest({ questID = 1, title = "A", level = 10 })
    load_addon(); run()
    assert_eq(#results_of("quest_grey"), 1)
  end,
  complete_quests_are_neither_soon_nor_grey = function()
    WOW.state.level = 20
    WOW.Quest({ questID = 1, title = "A", level = 10, isComplete = true, trivial = true })
    load_addon(); run()
    assert_eq(#results_of("quest_grey"), 0); assert_eq(#results_of("quest_soon"), 0); assert_eq(#results_of("quest_turnin"), 1)
  end,
  scan_runs_once_per_check_cycle = function()
    WOW.Quest({ questID = 1, title = "A", level = 20 })
    load_addon()
    local calls = 0
    local orig = C_QuestLog.GetInfo
    C_QuestLog.GetInfo = function(...) calls = calls + 1; return orig(...) end
    run()
    C_QuestLog.GetInfo = orig
    assert_eq(calls, 1, "three rules share one scan")
  end,
  secret_level_keeps_previous = function()
    WOW.state.level = 20
    local q = WOW.Quest({ questID = 1, title = "A", level = 20, isComplete = true })
    load_addon(); run(); assert_eq(#results_of("quest_turnin"), 1)
    q.level = WOW.secret(20); run()
    assert_eq(#results_of("quest_turnin"), 1)
  end,
  priority_puts_turnin_after_quests = function()
    load_addon()
    local idx = {}
    for i, n in ipairs(NewbieNudge.PRIORITY) do idx[n] = i end
    assert_true(idx.quests < idx.quest_turnin and idx.quest_turnin < idx.quest_soon and idx.quest_soon < idx.quest_grey)
  end,
}
