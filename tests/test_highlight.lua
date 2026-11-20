local function rows(...)
  local out = {}
  for _, h in ipairs({ ... }) do
    out[#out + 1] = { rule = { name = "r" }, result = { text = "t", highlight = h.highlight }, stale = h.stale or false }
  end
  return out
end

local function calls(name, frame)
  local n = 0
  for _, c in ipairs(WOW.calls) do if c[1] == name and (frame == nil or c[2] == frame) then n = n + 1 end end
  return n
end

return {
  key_target_glows_and_clears = function()
    load_addon()
    NewbieNudge.Highlight:Apply(rows({ highlight = "bags" }))
    assert_eq(calls("glow_show", MainMenuBarBackpackButton), 1)
    NewbieNudge.Highlight:Apply(rows({ highlight = "bags" }))
    assert_eq(calls("glow_show", MainMenuBarBackpackButton), 1, "no re-glow while still wanted")
    NewbieNudge.Highlight:Apply({})
    assert_eq(calls("glow_hide", MainMenuBarBackpackButton), 1)
  end,
  missing_frame_is_ignored = function()
    load_addon()
    NewbieNudge.Highlight:Apply(rows({ highlight = "tracking" }))
    assert_eq(calls("glow_show"), 0)
  end,
  talents_falls_back_to_player_spells_button = function()
    load_addon()
    NewbieNudge.Highlight:Apply(rows({ highlight = "talents" }))
    assert_eq(calls("glow_show", PlayerSpellsMicroButton), 1)
  end,
  action_slot_resolves_to_button = function()
    load_addon()
    NewbieNudge.Highlight:Apply(rows({ highlight = { action = { 3 } } }))
    assert_eq(calls("glow_show", ActionButton3), 1)
    NewbieNudge.Highlight:Apply({})
    assert_eq(calls("glow_hide", ActionButton3), 1)
  end,
  stale_rows_keep_their_glow = function()
    load_addon()
    NewbieNudge.Highlight:Apply(rows({ highlight = { action = { 3 } }, stale = true }, { highlight = "bags", stale = true }))
    assert_eq(calls("glow_show", ActionButton3), 1)
    assert_eq(calls("glow_show", MainMenuBarBackpackButton), 1)
  end,
  fallback_pulse_when_no_blizzard_glow = function()
    load_addon()
    _G.ActionButton_ShowOverlayGlow = nil
    _G.ActionButton_HideOverlayGlow = nil
    NewbieNudge.Highlight:Apply(rows({ highlight = "bags" }))
    assert_true(MainMenuBarBackpackButton.NewbieNudgeGlow)
    assert_true(MainMenuBarBackpackButton.NewbieNudgeGlow:IsShown())
    local a1 = MainMenuBarBackpackButton.NewbieNudgeGlow:GetAlpha()
    WOW.AdvanceTime(0.5)
    assert_true(MainMenuBarBackpackButton.NewbieNudgeGlow:GetAlpha() ~= a1, "alpha pulses")
    NewbieNudge.Highlight:Apply({})
    assert_true(not MainMenuBarBackpackButton.NewbieNudgeGlow:IsShown())
  end,
  clear_all_hides_everything = function()
    load_addon()
    NewbieNudge.Highlight:Apply(rows({ highlight = "bags" }, { highlight = { action = { 1, 2 } } }))
    NewbieNudge.Highlight:ClearAll()
    assert_eq(calls("glow_hide"), 3)
  end,
  bagslot_highlight_glows_item_button_and_backpack = function()
    load_addon()
    local cf = WOW.NewContainerFrame(0, 16)
    local rows = { { rule = { name = "r" }, result = { text = "t", highlight = { key = "bags", bagslots = { { 0, 3 } } } }, stale = false } }
    NewbieNudge.Highlight:Apply(rows)
    local shown = {}
    for _, c in ipairs(WOW.calls) do if c[1] == "glow_show" then shown[c[2]] = true end end
    assert_true(shown[MainMenuBarBackpackButton]); assert_true(shown[cf.Items[3]])
    NewbieNudge.Highlight:Apply({})
    assert_eq(WOW.calls[#WOW.calls][1], "glow_hide")
  end,
  bagslot_without_open_bags_only_glows_backpack = function()
    load_addon()
    NewbieNudge.Highlight:Apply({ { rule = { name = "r" }, result = { text = "t", highlight = { key = "bags", bagslots = { { 0, 3 } } } }, stale = false } })
    local n = 0
    for _, c in ipairs(WOW.calls) do if c[1] == "glow_show" then n = n + 1 end end
    assert_eq(n, 1)
  end,
  node_highlight_glows_talent_button_when_frame_exists = function()
    WOW.state.talents.nodes = { [11] = { ranks = 0, maxRanks = 2, spellID = 1 } }
    load_addon(); WOW.NewTalentFrame()
    NewbieNudge.Highlight:Apply({ { rule = { name = "r" }, result = { text = "t", highlight = { key = "talents", node = 11 } }, stale = false } })
    local shown = {}
    for _, c in ipairs(WOW.calls) do if c[1] == "glow_show" then shown[c[2]] = true end end
    assert_true(shown[PlayerSpellsMicroButton]); assert_true(shown[PlayerSpellsFrame.TalentsFrame.buttons[11]])
  end,
  node_highlight_without_frame_only_glows_micro_button = function()
    load_addon()
    NewbieNudge.Highlight:Apply({ { rule = { name = "r" }, result = { text = "t", highlight = { key = "talents", node = 11 } }, stale = false } })
    local n = 0
    for _, c in ipairs(WOW.calls) do if c[1] == "glow_show" then n = n + 1 end end
    assert_eq(n, 1)
  end,
  bagslot_buttons_rescanned_after_bag_open = function()
    load_addon()
    local rows = { { rule = { name = "r" }, result = { text = "t", highlight = { bagslots = { { 0, 3 } } } }, stale = false } }
    NewbieNudge.Highlight:Apply(rows)
    local cf = WOW.NewContainerFrame(0, 16)
    WOW.FireEvent("BAG_OPEN", 0)
    NewbieNudge.Highlight:Apply(rows)
    local shown = false
    for _, c in ipairs(WOW.calls) do if c[1] == "glow_show" and c[2] == cf.Items[3] then shown = true end end
    assert_true(shown, "item button found after the bag opened")
  end,
  -- review fix 1: opening the bags (no bag event) must glow the quest item
  bagslot_glow_appears_when_bags_open_without_bag_event = function()
    local cf = WOW.NewContainerFrame(0, 16); cf:Hide()
    load_addon()
    local rows = { { rule = { name = "r" }, result = { text = "t", highlight = { key = "bags", bagslots = { { 0, 3 } } } }, stale = false } }
    NewbieNudge.Highlight:Apply(rows)
    local before = 0
    for _, c in ipairs(WOW.calls) do if c[1] == "glow_show" and c[2] == cf.Items[3] then before = before + 1 end end
    assert_eq(before, 0, "hidden bag: no item glow yet")
    cf:Show()
    local after = 0
    for _, c in ipairs(WOW.calls) do if c[1] == "glow_show" and c[2] == cf.Items[3] then after = after + 1 end end
    assert_eq(after, 1, "item glows once the bag frame shows")
  end,
  -- review fix 6: a bag update must not replay every other glow
  bag_update_does_not_replay_other_glows = function()
    load_addon()
    local rows = { { rule = { name = "r" }, result = { text = "t", highlight = "talents" }, stale = false } }
    NewbieNudge.Highlight:Apply(rows)
    WOW.FireEvent("BAG_UPDATE_DELAYED")
    NewbieNudge.Highlight:Apply(rows)
    local n = 0
    for _, c in ipairs(WOW.calls) do if c[1] == "glow_show" and c[2] == PlayerSpellsMicroButton then n = n + 1 end end
    assert_eq(n, 1, "talent glow shown once, not replayed by a bag event")
  end,
}
