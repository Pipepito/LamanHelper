local L = function() return NewbieNudge.L end

return {
  professions_row_when_none = function()
    WOW.state.professions = {}
    load_addon(); run_checks()
    local r = results_of("professions")
    assert_eq(r[1].text, L().PROFESSIONS_ROW)
    assert_eq(r[1].highlight, "character")
    r[1].onClick()
    assert_eq(WOW.calls[#WOW.calls][2], "SkillFrame")
  end,
  professions_fine_with_one = function()
    WOW.state.professions = { prof2 = 2 }
    load_addon(); run_checks()
    assert_eq(#results_of("professions"), 0)
  end,
  professions_not_applicable_below_10 = function()
    WOW.state.level = 9
    WOW.state.professions = {}
    load_addon(); run_checks()
    assert_eq(NewbieNudge:Applies(NewbieNudge.ruleByName.professions), false)
  end,
  professions_skillinfo_path_counts_under_header = function()
    _G.GetProfessions = nil
    WOW.state.skillLines = {
      { name = "Weapon Skills", isHeader = true }, { name = "Swords" },
      { name = "Professions", isHeader = true }, { name = "Herbalism" },
      { name = "Secondary Skills", isHeader = true }, { name = "Cooking" },
    }
    load_addon(); run_checks()
    assert_eq(#results_of("professions"), 0)
    WOW.state.skillLines[4] = { name = "Secondary Skills", isHeader = true }
    WOW.FireEvent("SKILL_LINES_CHANGED"); run_checks()
    assert_eq(results_of("professions")[1].text, L().PROFESSIONS_ROW)
  end,
  professions_skillinfo_tuple_shape = function()
    _G.GetProfessions = nil
    C_SkillInfo.GetSkillLineInfo = function(i)
      local l = WOW.state.skillLines[i]
      if l then return l.name, l.isHeader or false end
    end
    WOW.state.skillLines = { { name = "Professions", isHeader = true }, { name = "Mining" } }
    load_addon(); run_checks()
    assert_eq(#results_of("professions"), 0)
  end,
  professions_silent_when_no_api = function()
    _G.GetProfessions = nil
    _G.C_SkillInfo = nil
    load_addon(); run_checks()
    assert_eq(#results_of("professions"), 0)
  end,
  rested_row_when_menu_opens_unrested = function()
    load_addon(); run_checks()
    assert_eq(#results_of("rested"), 0)
    WOW.ShowGameMenu(true); run_checks()
    assert_eq(results_of("rested")[1].text, L().RESTED_ROW)
    assert_eq(WOW.printed[#WOW.printed], L().CHAT_PREFIX .. L().RESTED_ROW)
  end,
  rested_says_once_per_session = function()
    load_addon(); run_checks()
    WOW.ShowGameMenu(true); run_checks()
    local printed = #WOW.printed
    WOW.ShowGameMenu(false); run_checks()
    WOW.ShowGameMenu(true); run_checks()
    assert_eq(#WOW.printed, printed)
    assert_eq(results_of("rested")[1].text, L().RESTED_ROW, "row still shows")
  end,
  rested_nothing_when_resting = function()
    WOW.state.resting = true
    load_addon(); run_checks()
    local printed = #WOW.printed
    WOW.ShowGameMenu(true); run_checks()
    assert_eq(#results_of("rested"), 0)
    assert_eq(#WOW.printed, printed)
  end,
  rested_row_clears_on_menu_hide = function()
    load_addon(); run_checks()
    WOW.ShowGameMenu(true); run_checks()
    WOW.ShowGameMenu(false); run_checks()
    assert_eq(#results_of("rested"), 0)
  end,
  rested_row_clears_when_player_becomes_rested = function()
    load_addon(); run_checks()
    WOW.ShowGameMenu(true); run_checks()
    WOW.state.resting = true
    WOW.FireEvent("PLAYER_UPDATE_RESTING"); run_checks()
    assert_eq(#results_of("rested"), 0)
  end,
  rested_not_applicable_at_max_level = function()
    WOW.state.level = 60
    load_addon(); run_checks()
    assert_eq(NewbieNudge:Applies(NewbieNudge.ruleByName.rested), false)
  end,
}
