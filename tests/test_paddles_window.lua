-- The Paddles window (0.4.1): NewbieNudge's own editor for the back paddles,
-- opened from the minimap menu and /nudge paddles (never from the game's
-- Options window, whose commit tainted the controller interface).
local L = function() return NewbieNudge.L end
local function P() return NewbieNudge.Paddles end
local function W() return NewbieNudge.PaddlesWindow end
local function row(n) return W().rows[n] end

local function setup()
  WOW.state.spellInfo[774] = { name = "Rejuvenation", icon = 136081 }
  WOW.state.spellBook.items[1] = { spellID = 774 }
  WOW.state.macros = { { name = "Mount", icon = 132261 } }
  WOW.state.bindingNames = { TOGGLEBACKPACK = "Open Backpack", TOGGLEWORLDMAP = "Toggle World Map", JUMP = "Jump" }
  WOW.state.bindingList = {
    { "JUMP", "BINDING_HEADER_MOVEMENT", "SPACE" },
    { "TOGGLEBACKPACK", "BINDING_HEADER_INTERFACE", "B" },
    { "TOGGLEWORLDMAP", "BINDING_HEADER_INTERFACE", "M" },
    { "NONAMECOMMAND", "BINDING_HEADER_INTERFACE" },
  }
  _G.BINDING_HEADER_MOVEMENT = "Movement Keys"; _G.BINDING_HEADER_INTERFACE = "Interface Panel"
  load_addon()
end

local function findItem(items, label)
  for _, it in ipairs(items) do if it.label == label then return it end end
end

return {
  slash_and_menu_open_the_window = function()
    setup()
    NewbieNudge:HandleSlash("paddles")
    assert_true(_G.NewbieNudgePaddles:IsShown())
    local found
    for _, e in ipairs(NewbieNudge.MinimapButton:MenuEntries()) do if e.label == L().MENU_PADDLES then found = e end end
    assert_true(found, "minimap menu entry")
    _G.NewbieNudgePaddles:Hide(); found.onClick()
    assert_true(_G.NewbieNudgePaddles:IsShown())
  end,
  rows_show_key_and_action = function()
    setup()
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "command", value = "TOGGLEBACKPACK" })
    W():Show()
    assert_eq(row(1).key:GetText(), "F9")
    assert_eq(row(1).action:GetText(), "Open Backpack")
    assert_eq(row(3).key:GetText(), L().PADDLES_NOT_SET)
  end,
  drop_a_spell_on_a_slot = function()
    setup()
    W():Show()
    WOW.state.cursor = { type = "spell", id = 774 }
    row(1).slot:GetScript("OnReceiveDrag")(row(1).slot)
    assert_eq(P():Get(1).action, { kind = "spell", value = 774 })
    assert_nil(WOW.state.cursor, "cursor cleared")
    WOW.state.cursor = { type = "item", id = 6948 }
    row(2).slot:GetScript("OnReceiveDrag")(row(2).slot)
    assert_eq(P():Get(2).action, { kind = "item", value = 6948 })
    WOW.state.cursor = { type = "macro", id = 1 }
    row(3).slot:GetScript("OnReceiveDrag")(row(3).slot)
    assert_eq(P():Get(3).action, { kind = "macro", value = "Mount" })
  end,
  layer_rows_only_when_layer = function()
    setup()
    P():SetKey(2, "F10"); P():SetAction(2, { kind = "layer" })
    W():Show()
    local shown = 0
    for _, slot in ipairs(P().LAYER_SLOTS) do
      assert_true(row(2).layer[slot]:IsShown(), slot); shown = shown + 1
      assert_true(not row(1).layer[slot]:IsShown(), slot)
    end
    assert_eq(shown, #P().LAYER_SLOTS)
    WOW.state.cursor = { type = "spell", id = 774 }
    row(2).layer.PAD1:GetScript("OnReceiveDrag")(row(2).layer.PAD1)
    assert_eq(P():Get(2).layer.PAD1, { kind = "spell", value = 774 })
  end,
  replaced_binding_is_named = function()
    setup()
    WOW.state.bindings = { F9 = "TOGGLEWORLDMAP" }
    P():SetKey(1, "F9")
    W():Show()
    assert_eq(row(1).replaces:GetText(), L().PADDLES_REPLACES:format("Toggle World Map"))
  end,
  missing_action_is_marked = function()
    setup()
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "macro", value = "Gone" })
    P():SetKey(2, "F10"); P():SetAction(2, { kind = "item", value = 6948 })
    W():Show()
    assert_eq(row(1).action:GetText(), L().PADDLES_MISSING:format("Gone"))
    assert_eq(row(2).slot.icon.desaturated, true, "item not in the bags")
  end,
  window_locks_in_combat = function()
    setup()
    W():Show()
    -- PLAYER_REGEN_DISABLED fires before InCombatLockdown() turns true
    WOW.FireEvent("PLAYER_REGEN_DISABLED")
    assert_eq(row(1).learn:IsEnabled(), false); assert_eq(row(1).slot:IsEnabled(), false)
    assert_true(W().frame.combat:IsShown())
    WOW.state.inCombat = false
    WOW.FireEvent("PLAYER_REGEN_ENABLED")
    assert_eq(row(1).learn:IsEnabled(), true)
    assert_true(not W().frame.combat:IsShown())
  end,
  learn_button_learns_and_explains_refusals = function()
    setup()
    W():Show()
    row(1).learn:GetScript("OnClick")(row(1).learn)
    assert_eq(W().frame.status:GetText(), L().PADDLES_PRESS)
    local l = _G.NewbieNudgePaddleListener
    l:GetScript("OnGamePadButtonDown")(l, "PAD1")
    assert_eq(W().frame.status:GetText(), L().PADDLES_REFUSED)
    row(1).learn:GetScript("OnClick")(row(1).learn)
    l:GetScript("OnKeyDown")(l, "F9")
    assert_eq(row(1).key:GetText(), "F9")
  end,
  command_list_comes_from_the_game = function()
    setup()
    W():Show()
    W():OpenActionMenu(1)
    local commands = findItem(WOW.lastMenu.items, L().PADDLES_COMMAND)
    assert_true(commands, "command submenu")
    local iface = findItem(commands.items, "Interface Panel")
    assert_true(iface and findItem(commands.items, "Movement Keys"), "grouped by header")
    assert_nil(findItem(iface.items, "NONAMECOMMAND"), "unnamed commands left out")
    findItem(iface.items, "Toggle World Map").onClick()
    assert_eq(P():Get(1).action, { kind = "command", value = "TOGGLEWORLDMAP" })
    W():OpenActionMenu(1)
    assert_true(findItem(WOW.lastMenu.items, L().PADDLES_LAYER), "layer offered for a paddle")
    findItem(WOW.lastMenu.items, L().PADDLES_CLEAR).onClick()
    assert_nil(P():Get(1).action)
    W():OpenActionMenu(1, "PAD1")
    assert_nil(findItem(WOW.lastMenu.items, L().PADDLES_LAYER), "no layer inside a layer")
  end,
  window_stays_out_of_the_esc_list = function()
    _G.UISpecialFrames = {}
    setup()
    W():Show()
    for _, name in ipairs(UISpecialFrames) do assert_true(name ~= "NewbieNudgePaddles") end
  end,
  use_paddles_checkbox = function()
    setup()
    W():Show()
    W().frame.enable:SetChecked(false); W().frame.enable:GetScript("OnClick")(W().frame.enable)
    assert_eq(P():IsEnabled(), false)
  end,
  never_opened_from_settings = function()
    setup()
    for _, c in ipairs(WOW.calls) do
      if c[1] == "initializer" and c[2] == "button" then assert_true(c[3] ~= L().MENU_PADDLES, "no settings button") end
    end
    local line = false
    for _, c in ipairs(WOW.calls) do
      if c[1] == "initializer" and c[2] == "header" and c[3] == L().OPT_CONTROLLER_PADDLES then line = true end
    end
    assert_true(line, "the Controller page points to the window")
  end,
}
