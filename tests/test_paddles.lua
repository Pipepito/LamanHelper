-- Paddles (0.4.1): the Steam Deck's back paddles, learned as whatever key
-- they send, doing a game command, a spell, an item, a macro or a layer.
-- Override bindings on NewbieNudge's own owner; never the game's settings.
local function P() return NewbieNudge.Paddles end
local function binds() return (WOW.state.overrides or {}).NewbieNudgePaddleOwner or {} end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

local function setup()
  WOW.state.spellInfo[774] = { name = "Rejuvenation", icon = 136081 }
  WOW.state.spellBook.items[1] = { spellID = 774 }
  WOW.state.macros = { { name = "Mount", icon = 132261 } }
  load_addon()
end

return {
  command_paddle_binds_the_command = function()
    setup()
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "command", value = "TOGGLEBACKPACK" })
    assert_eq(binds().F9, "TOGGLEBACKPACK")
  end,
  spell_paddle_clicks_a_secure_button = function()
    setup()
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "spell", value = 774 })
    assert_eq(binds().F9, "CLICK NewbieNudgePaddle1:LeftButton")
    local b = _G.NewbieNudgePaddle1
    assert_eq(b.attributes.type, "spell"); assert_eq(b.attributes.spell, "Rejuvenation")
  end,
  item_and_macro_paddles = function()
    setup()
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "item", value = 6948 })
    assert_eq(_G.NewbieNudgePaddle1.attributes.type, "item"); assert_eq(_G.NewbieNudgePaddle1.attributes.item, "item:6948")
    P():SetKey(2, "F10"); P():SetAction(2, { kind = "macro", value = "Mount" })
    assert_eq(_G.NewbieNudgePaddle2.attributes.type, "macro"); assert_eq(_G.NewbieNudgePaddle2.attributes.macro, "Mount")
    assert_eq(binds().F10, "CLICK NewbieNudgePaddle2:LeftButton")
  end,
  missing_macro_is_not_bound = function()
    setup()
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "macro", value = "Gone" })
    assert_nil(binds().F9)
    local _, _, missing = P():Describe(P():Get(1).action)
    assert_eq(missing, true)
  end,
  unknown_spell_is_not_bound = function()
    setup()
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "spell", value = 999999 })
    assert_nil(binds().F9)
    local _, _, missing = P():Describe(P():Get(1).action)
    assert_eq(missing, true)
  end,
  describe_names_and_icons = function()
    setup()
    local name, icon, missing = P():Describe({ kind = "spell", value = 774 })
    assert_eq(name, "Rejuvenation"); assert_eq(icon, 136081); assert_eq(missing, false)
    name = P():Describe({ kind = "macro", value = "Mount" })
    assert_eq(name, "Mount")
    assert_nil(P():Describe(nil))
  end,
  combat_queues_apply = function()
    setup()
    WOW.state.inCombat = true
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "command", value = "TOGGLEBACKPACK" })
    assert_nil(binds().F9, "nothing bound in combat")
    assert_eq(P():Get(1).action.value, "TOGGLEBACKPACK", "the choice is saved")
    WOW.state.inCombat = false
    WOW.FireEvent("PLAYER_REGEN_ENABLED")
    assert_eq(binds().F9, "TOGGLEBACKPACK")
  end,
  key_moves_between_paddles = function()
    setup()
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "command", value = "TOGGLEBACKPACK" })
    P():SetAction(2, { kind = "command", value = "TOGGLEWORLDMAP" })
    P():SetKey(2, "F9")
    assert_nil(P():Get(1).key)
    assert_eq(binds().F9, "TOGGLEWORLDMAP")
    assert_eq(count(binds()), 1)
  end,
  disabled_clears_every_binding = function()
    setup()
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "command", value = "TOGGLEBACKPACK" })
    P():SetEnabled(false)
    assert_eq(count(binds()), 0)
    assert_eq(NewbieNudge.db.paddles.enabled, false)
    P():SetEnabled(true)
    assert_eq(binds().F9, "TOGGLEBACKPACK")
  end,
  saved_paddles_bound_at_login = function()
    _G.NewbieNudgeDB = { paddles = { enabled = true, [1] = { key = "F11", action = { kind = "command", value = "TOGGLECHARACTER0" } } } }
    setup()
    assert_eq(binds().F11, "TOGGLECHARACTER0")
  end,
  layer_paddle_clicks_its_handler = function()
    setup()
    P():SetKey(2, "F10"); P():SetAction(2, { kind = "layer" })
    assert_eq(binds().F10, "CLICK NewbieNudgePaddleLayer2:LeftButton")
    assert_eq(_G.NewbieNudgePaddleLayer2.clicks, { "AnyDown", "AnyUp" })
  end,
  layer_snippet_binds_filled_slots_on_down = function()
    setup()
    P():SetKey(2, "F10"); P():SetAction(2, { kind = "layer" })
    P():SetLayerAction(2, "PAD1", { kind = "spell", value = 774 })
    P():SetLayerAction(2, "PADDUP", { kind = "command", value = "TOGGLEWORLDMAP" })
    local snippet = _G.NewbieNudgePaddleLayer2.wrapped.OnClick
    assert_true(snippet:find('SetBindingClick(true, "PAD1", "NewbieNudgeLayer2PAD1")', 1, true), snippet)
    assert_true(snippet:find('SetBinding(true, "PADDUP", "TOGGLEWORLDMAP")', 1, true), snippet)
    assert_true(snippet:find("ClearBindings()", 1, true), snippet)
    assert_true(not snippet:find("PAD2", 1, true), "empty slots left out")
  end,
  layer_slot_buttons_get_their_actions = function()
    setup()
    P():SetKey(2, "F10"); P():SetAction(2, { kind = "layer" })
    P():SetLayerAction(2, "PAD1", { kind = "spell", value = 774 })
    local b = _G.NewbieNudgeLayer2PAD1
    assert_eq(b.attributes.type, "spell"); assert_eq(b.attributes.spell, "Rejuvenation")
  end,
  layer_only_offers_working_slots = function()
    setup()
    assert_eq(P():SetLayerAction(2, "PADBACK", { kind = "command", value = "TOGGLEWORLDMAP" }), false)
    assert_nil((P():Get(2).layer or {}).PADBACK)
  end,
  layer_kind_refused_for_layer_slots = function()
    setup()
    assert_eq(P():SetLayerAction(2, "PAD1", { kind = "layer" }), false)
    assert_nil((P():Get(2).layer or {}).PAD1)
  end,
  turning_off_releases_a_held_layer = function()
    setup()
    P():SetKey(2, "F10"); P():SetAction(2, { kind = "layer" })
    P():SetLayerAction(2, "PAD1", { kind = "spell", value = 774 })
    P():SetEnabled(false)
    local cleared = false
    for _, c in ipairs(WOW.calls) do
      if c[1] == "Execute" and c[2] == "NewbieNudgePaddleLayer2" and c[3]:find("ClearBindings", 1, true) then cleared = true end
    end
    assert_true(cleared, "layer bindings cleared")
  end,
  learning_stores_a_keyboard_key = function()
    setup()
    local got
    P():StartLearning(1, function(key, reason) got = { key, reason } end)
    local l = _G.NewbieNudgePaddleListener
    assert_eq(l.propagateKeys, true)
    l:GetScript("OnKeyDown")(l, "F9")
    assert_eq(P():Get(1).key, "F9"); assert_eq(got[1], "F9")
    assert_nil(l:GetScript("OnKeyDown")); assert_nil(l:GetScript("OnGamePadButtonDown"))
    assert_eq(l.gamepad, false); assert_eq(l.keyboard, false)
    assert_eq(P():IsLearning(), false)
  end,
  learning_stores_a_paddle_button = function()
    setup()
    P():StartLearning(2)
    local l = _G.NewbieNudgePaddleListener
    l:GetScript("OnGamePadButtonDown")(l, "PADPADDLE1")
    assert_eq(P():Get(2).key, "PADPADDLE1")
  end,
  learning_refuses_the_games_buttons = function()
    setup()
    local l
    for _, b in ipairs({ "PAD1", "PADRTRIGGER", "PADDUP", "PADFORWARD" }) do
      local got
      P():StartLearning(1, function(key, reason) got = { key, reason } end)
      l = _G.NewbieNudgePaddleListener
      l:GetScript("OnGamePadButtonDown")(l, b)
      assert_nil(P():Get(1).key, b); assert_eq(got[2], "refused", b)
    end
    local got
    P():StartLearning(1, function(key, reason) got = { key, reason } end)
    l:GetScript("OnKeyDown")(l, "ENTER")
    assert_eq(got[2], "refused")
    P():StartLearning(1, function(key, reason) got = { key, reason } end)
    l:GetScript("OnKeyDown")(l, "ESCAPE")
    assert_eq(got[2], "cancel"); assert_nil(P():Get(1).key)
  end,
  listener_has_no_scripts_until_learning = function()
    setup()
    local l = _G.NewbieNudgePaddleListener
    if l then
      assert_nil(l:GetScript("OnGamePadButtonDown")); assert_nil(l:GetScript("OnKeyDown"))
      assert_true(not l.gamepad)
    end
  end,
  combat_cancels_learning = function()
    setup()
    local got
    P():StartLearning(1, function(key, reason) got = { key, reason } end)
    WOW.state.inCombat = true
    WOW.FireEvent("PLAYER_REGEN_DISABLED")
    assert_eq(P():IsLearning(), false); assert_eq(got[2], "combat")
    assert_nil(_G.NewbieNudgePaddleListener:GetScript("OnGamePadButtonDown"))
  end,
  learning_refused_in_combat = function()
    setup()
    WOW.state.inCombat = true
    local got
    assert_eq(P():StartLearning(1, function(key, reason) got = { key, reason } end), false)
    assert_eq(got[2], "combat")
  end,
  -- final review (2026-11-23)
  unlearned_spell_is_missing_until_learned = function()
    setup()
    WOW.state.spellInfo[8936] = { name = "Regrowth", icon = 136085 }
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "spell", value = 8936 })
    assert_nil(binds().F9, "not known: not bound")
    local _, _, missing = P():Describe(P():Get(1).action)
    assert_eq(missing, true)
    WOW.state.spellBook.items[2] = { spellID = 8936 }
    WOW.FireEvent("SPELLS_CHANGED")
    assert_eq(binds().F9, "CLICK NewbieNudgePaddle1:LeftButton", "bound once learned")
  end,
  held_layer_released_on_loading_screen = function()
    setup()
    P():SetKey(2, "F10"); P():SetAction(2, { kind = "layer" })
    WOW.calls = {}
    WOW.FireEvent("PLAYER_ENTERING_WORLD")
    local cleared = false
    for _, c in ipairs(WOW.calls) do
      if c[1] == "Execute" and c[2] == "NewbieNudgePaddleLayer2" and c[3]:find("ClearBindings", 1, true) then cleared = true end
    end
    assert_true(cleared)
  end,
  action_buttons_follow_key_down_setting = function()
    setup()
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "spell", value = 774 })
    assert_eq(_G.NewbieNudgePaddle1.clicks, { "AnyUp", "AnyDown" })
  end,
  learning_skips_lone_modifiers_and_keeps_chords = function()
    setup()
    P():StartLearning(1)
    local l = _G.NewbieNudgePaddleListener
    l:GetScript("OnKeyDown")(l, "LCTRL")
    assert_eq(P():IsLearning(), true, "a lone modifier is not the paddle")
    WOW.state.ctrlDown = true
    l:GetScript("OnKeyDown")(l, "F1")
    assert_eq(P():Get(1).key, "CTRL-F1")
    WOW.state.ctrlDown = false
    WOW.state.altDown, WOW.state.shiftDown = true, true
    P():StartLearning(2)
    l:GetScript("OnKeyDown")(l, "F2")
    assert_eq(P():Get(2).key, "ALT-SHIFT-F2")
  end,
  no_cvar_is_written = function()
    setup()
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "spell", value = 774 })
    P():SetEnabled(false); P():SetEnabled(true)
    for _, c in ipairs(WOW.calls) do assert_true(c[1] ~= "SetCVar", "no CVar write") end
  end,
}
