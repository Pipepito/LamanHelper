local L = function() return NewbieNudge.L end
local HERBS, MINERALS = 2383, 2580

local function knows(ids)
  local s = WOW.state
  s.spellInfo[HERBS] = { name = "Find Herbs", icon = 1 }
  s.spellInfo[MINERALS] = { name = "Find Minerals", icon = 2 }
  s.spellBook.lines = { { name = "General", offset = 0, num = #ids } }
  s.spellBook.items = {}
  for i, id in ipairs(ids) do s.spellBook.items[i] = { spellID = id } end
end

local function tracking(list) WOW.state.tracking = list end

return {
  not_applicable_without_gathering = function()
    tracking({ { name = "Find Herbs", spellID = HERBS } })
    load_addon(); run_checks()
    assert_eq(NewbieNudge:Applies(NewbieNudge.ruleByName.tracking), false)
  end,
  herbs_known_and_off_gives_row = function()
    knows({ HERBS })
    tracking({ { name = "Track Beasts", spellID = 1494 }, { name = "Find Herbs", spellID = HERBS, texture = 77 } })
    load_addon(); run_checks()
    local r = results_of("tracking")
    assert_eq(r[1].text, L().TRACKING_ROW_HERBS:format("Find Herbs"))
    assert_eq(r[1].highlight, "tracking")
    assert_eq(r[1].icon, 77)
  end,
  herbs_active_gives_nothing = function()
    knows({ HERBS })
    tracking({ { name = "Find Herbs", spellID = HERBS, active = true } })
    load_addon(); run_checks()
    assert_eq(#results_of("tracking"), 0)
  end,
  click_enables_tracking = function()
    knows({ HERBS })
    tracking({ { name = "Track Beasts", spellID = 1494 }, { name = "Find Herbs", spellID = HERBS } })
    load_addon(); run_checks()
    results_of("tracking")[1].onClick()
    assert_eq(WOW.state.tracking[2].active, true)
    WOW.FireEvent("MINIMAP_UPDATE_TRACKING"); run_checks()
    assert_eq(#results_of("tracking"), 0)
  end,
  both_known_both_off_two_rows = function()
    knows({ HERBS, MINERALS })
    tracking({ { name = "Find Herbs", spellID = HERBS }, { name = "Find Minerals", spellID = MINERALS } })
    load_addon(); run_checks()
    local r = results_of("tracking")
    assert_eq(#r, 2)
    assert_eq(r[2].text, L().TRACKING_ROW_MINERALS:format("Find Minerals"))
  end,
  match_by_name_when_no_spellid = function()
    knows({ MINERALS })
    tracking({ { name = "Find Minerals" } })
    load_addon(); run_checks()
    assert_eq(results_of("tracking")[1].text, L().TRACKING_ROW_MINERALS:format("Find Minerals"))
  end,
  known_but_not_in_tracking_menu_is_silent = function()
    knows({ HERBS })
    tracking({})
    load_addon(); run_checks()
    assert_eq(#results_of("tracking"), 0)
  end,
}
