-- Paddles (0.4.1): the Steam Deck's back paddles, learned as whatever key
-- they send, doing a game command, a spell, an item, a macro or a layer.
-- Override bindings on NewbieNudge's own owner; never the game's settings.
local function P() return NewbieNudge.Paddles end
local function binds() return (WOW.state.overrides or {}).NewbieNudgePaddleOwner or {} end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

local function setup()
  WOW.state.spellInfo[774] = { name = "Rejuvenation", icon = 136081 }
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
  no_cvar_is_written = function()
    setup()
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "spell", value = 774 })
    P():SetEnabled(false); P():SetEnabled(true)
    for _, c in ipairs(WOW.calls) do assert_true(c[1] ~= "SetCVar", "no CVar write") end
  end,
}
