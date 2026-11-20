-- TalentBuild: parsing an Icy Veins talent-calculator link, storing it, and
-- (Task 16) the talent_build rule.
local function setup() WOW.extraFiles = { TESTS_DIR .. "/fixtures/icy_talents.lua" } end
local P = function(t, c) return NewbieNudge.TalentBuild.Parse(t, c or "MAGE") end

return {
  parses_full_url_fragment_and_bare = function()
    setup(); load_addon()
    local url = "https://www.icy-veins.com/wow-forever/mage-talent-calculator#tc-11BBz~3-c"
    local b = P(url)
    assert_eq(b.class, "MAGE"); assert_eq(b.version, "3-c"); assert_eq(b.picks, { "1", "1", "B", "B", "z" }); assert_nil(b.warning)
    assert_eq(P("#tc-11BBz~3-c").picks, b.picks); assert_eq(P("tc-11BBz~3-c").picks, b.picks); assert_eq(P("11BBz~3-c").picks, b.picks)
  end,
  rejects_unknown_talent_wrong_class_and_no_link = function()
    setup(); load_addon()
    local b, why = P("#tc-11Q~3-c"); assert_nil(b); assert_eq(why, "unknown_talent")
    b, why = P("https://www.icy-veins.com/wow-forever/priest-talent-calculator#tc-11~3-c"); assert_nil(b); assert_eq(why, "wrong_class")
    b, why = P("hello"); assert_nil(b); assert_eq(why, "no_link")
  end,
  rejects_more_points_than_max_rank = function()
    setup(); load_addon()
    local b, why = P("#tc-111~3-c"); assert_nil(b); assert_eq(why, "too_many_points")
  end,
  old_version_warns_but_loads = function()
    setup(); load_addon()
    local b = P("#tc-1B~1-a"); assert_eq(b.warning, "old_version"); assert_eq(#b.picks, 2)
  end,
  set_and_clear_store_in_db_and_say = function()
    setup(); load_addon()
    NewbieNudge.TalentBuild:Set("#tc-11B~3-c")
    assert_eq(NewbieNudge.db.build.picks, { "1", "1", "B" }); assert_eq(NewbieNudge.db.build.version, "3-c")
    assert_true(WOW.printed[#WOW.printed]:find(NewbieNudge.L.BUILD_SET:format(3), 1, true))
    NewbieNudge.TalentBuild:Set("#tc-Q~3-c")
    assert_eq(#NewbieNudge.db.build.picks, 3, "a bad link does not clear the good one")
    assert_true(WOW.printed[#WOW.printed]:find(NewbieNudge.L.BUILD_ERR_UNKNOWN_TALENT, 1, true))
    NewbieNudge:HandleSlash("build clear"); assert_nil(NewbieNudge.db.build)
    NewbieNudge:HandleSlash("build #tc-1~3-c"); assert_eq(#NewbieNudge.db.build.picks, 1)
  end,
  -- Task 16: the rule, the highlight and the options popup
  next_pick_walks_build_order = function()
    setup(); load_addon()
    local data = NewbieNudge.IcyTalents.MAGE
    local picks = { "1", "1", "B", "B", "z" }
    local idx, url = NewbieNudge.TalentBuild.NextPick(picks, {}, data); assert_eq(idx, 1); assert_eq(url, "1")
    idx, url = NewbieNudge.TalentBuild.NextPick(picks, { [11] = 2, [12] = 1 }, data); assert_eq(idx, 4); assert_eq(url, "B")
    idx = NewbieNudge.TalentBuild.NextPick(picks, { [11] = 2, [12] = 2, [13] = 1 }, data); assert_nil(idx)
    idx, url = NewbieNudge.TalentBuild.NextPick(picks, { [12] = 2, [13] = 1 }, data); assert_eq(idx, 1, "skipped talent comes back first")
  end,
  rule_row_with_name_rank_and_node_highlight = function()
    setup(); WOW.state.level = 12
    WOW.state.talents = { configID = 1, treeID = 10, unspent = 1, nodes = {
      [11] = { ranks = 1, maxRanks = 2, spellID = 1001 }, [12] = { ranks = 0, maxRanks = 5, spellID = 1002 }, [13] = { ranks = 0, maxRanks = 1, spellID = 1003 } } }
    WOW.state.spellInfo[1001] = { name = "Arcane Subtlety" }
    load_addon(); NewbieNudge.TalentBuild:Set("#tc-11BBz~3-c"); WOW.FireEvent("TRAIT_CONFIG_UPDATED"); run_checks()
    local r = results_of("talent_build")
    assert_eq(r[1].text, NewbieNudge.L.BUILD_NEXT_ROW:format("Arcane Subtlety", 2, 2))
    assert_eq(r[1].highlight, { key = "talents", node = 11 })
    assert_eq(#r, 1)
    r[1].onClick(); assert_eq(WOW.calls[#WOW.calls][1], "ToggleTalentFrame")
  end,
  no_row_without_unspent_points_or_when_done = function()
    setup(); WOW.state.level = 12
    WOW.state.talents = { configID = 1, treeID = 10, unspent = 0, nodes = { [11] = { ranks = 0, maxRanks = 2, spellID = 1001 } } }
    load_addon(); NewbieNudge.TalentBuild:Set("#tc-1~3-c"); WOW.FireEvent("TRAIT_CONFIG_UPDATED"); run_checks()
    assert_eq(#results_of("talent_build"), 0)
    WOW.state.talents.unspent = 1; WOW.state.talents.nodes[11].ranks = 1; WOW.FireEvent("TRAIT_NODE_CHANGED"); run_checks()
    assert_eq(#results_of("talent_build"), 0, "build complete")
  end,
  differs_row_when_player_went_off_build = function()
    setup(); WOW.state.level = 12
    WOW.state.talents = { configID = 1, treeID = 10, unspent = 1, nodes = {
      [11] = { ranks = 0, maxRanks = 2, spellID = 1001 }, [13] = { ranks = 1, maxRanks = 1, spellID = 1003 } } }
    WOW.state.spellInfo[1001] = { name = "A" }
    load_addon(); NewbieNudge.TalentBuild:Set("#tc-11~3-c"); WOW.FireEvent("TRAIT_CONFIG_UPDATED"); run_checks()
    local r = results_of("talent_build"); assert_eq(#r, 2); assert_eq(r[2].text, NewbieNudge.L.BUILD_DIFFERS_ROW)
  end,
  not_applicable_without_build_or_below_ten = function()
    setup(); WOW.state.level = 12; load_addon()
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.talent_build))
    NewbieNudge.TalentBuild:Set("#tc-1~3-c"); wipe(NewbieNudge.appliesCache)
    assert_true(NewbieNudge:Applies(NewbieNudge.ruleByName.talent_build))
    WOW.state.level = 9; wipe(NewbieNudge.appliesCache); assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.talent_build))
  end,
  options_popup_sets_build = function()
    setup(); load_addon()
    local buttons = 0
    for _, c in ipairs(WOW.calls) do if c[1] == "initializer" and c[2] == "button" and c[3] == NewbieNudge.L.OPT_BUILD_PASTE then buttons = buttons + 1 end end
    assert_eq(buttons, 1)
    local dialog = StaticPopupDialogs.NEWBIENUDGE_BUILD
    assert_true(dialog and dialog.hasEditBox)
    local fake = { EditBox = CreateFrame("EditBox") } -- the live client's field name
    fake.EditBox:SetText("stale")
    dialog.OnShow(fake)
    assert_eq(fake.EditBox:GetText(), "", "OnShow clears the box")
    fake.EditBox:SetText("#tc-1B~3-c")
    dialog.OnAccept(fake)
    assert_eq(#NewbieNudge.db.build.picks, 2)
    local old = { editBox = CreateFrame("EditBox") } -- older clients' field name still works
    old.editBox:SetText("#tc-1~3-c")
    dialog.OnAccept(old)
    assert_eq(#NewbieNudge.db.build.picks, 1)
  end,
  status_counts_spent_points = function()
    setup(); WOW.state.level = 12
    WOW.state.talents = { configID = 1, treeID = 10, unspent = 0, nodes = { [11] = { ranks = 2, maxRanks = 2, spellID = 1001 }, [12] = { ranks = 1, maxRanks = 5, spellID = 1002 } } }
    load_addon(); NewbieNudge.TalentBuild:Set("#tc-11BBz~3-c")
    assert_eq(NewbieNudge.TalentBuild:Status(), NewbieNudge.L.BUILD_STATUS:format("Mage", 5, 3))
  end,
  status_text = function()
    setup(); load_addon()
    assert_eq(NewbieNudge.TalentBuild:Status(), NewbieNudge.L.BUILD_STATUS_NONE)
    NewbieNudge.TalentBuild:Set("#tc-11B~3-c")
    assert_true(NewbieNudge.TalentBuild:Status():find("3", 1, true))
  end,
  talent_window_button_opens_popup_and_right_click_clears = function()
    setup(); WOW.state.talents.nodes = { [11] = { ranks = 0, maxRanks = 2, spellID = 1001 } }
    load_addon()
    local f = WOW.NewTalentFrame()
    WOW.FireEvent("ADDON_LOADED", "Blizzard_PlayerSpells")
    local b = NewbieNudgeBuildButton
    assert_true(b, "button created on the talent frame"); assert_true(b:GetParent() == f, "parented to the talent frame")
    assert_eq(b:GetText(), NewbieNudge.L.BUILD_BUTTON)
    WOW.Click(b)
    assert_eq(WOW.calls[#WOW.calls], { "StaticPopup_Show", "NEWBIENUDGE_BUILD" })
    NewbieNudge.TalentBuild:Set("#tc-1~3-c"); assert_true(NewbieNudge.db.build)
    WOW.Click(b, "RightButton")
    assert_nil(NewbieNudge.db.build)
  end,
  talent_window_button_created_when_frame_exists_at_login = function()
    setup(); WOW.state.talents.nodes = { [11] = { ranks = 0, maxRanks = 2, spellID = 1001 } }
    WOW.NewTalentFrame()
    load_addon()
    assert_true(NewbieNudgeBuildButton)
  end,
}
