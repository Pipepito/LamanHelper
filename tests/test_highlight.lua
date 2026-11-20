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
}
