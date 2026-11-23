-- The Paddles window (0.5.0): NewbieNudge's own editor for the back paddles,
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
  -- controller mode: lists instead of dragging
  spell_choices_are_known_top_ranks = function()
    setup()
    WOW.state.spellBook.lines = { { name = "Balance", offset = 0, num = 4 } }
    WOW.state.spellBook.items = {
      [1] = { spellID = 774 }, [2] = { spellID = 5185, lowRank = true }, [3] = { spellID = 5186 },
      [4] = { spellID = 9999, passive = true },
    }
    WOW.state.spellInfo[5185] = { name = "Healing Touch" }; WOW.state.spellInfo[5186] = { name = "Healing Touch" }
    WOW.state.spellInfo[9999] = { name = "Aura" }
    WOW.FireEvent("SPELLS_CHANGED")
    local labels = {}
    for _, c in ipairs(W():Choices("spells")) do labels[#labels + 1] = c.label .. "=" .. c.action.value end
    assert_eq(labels, { "Healing Touch=5186", "Rejuvenation=774" })
  end,
  item_choices_have_a_use = function()
    setup()
    WOW.state.itemInfo[6948] = { name = "Hearthstone", icon = 134414, useSpell = "Hearthstone" }
    WOW.state.itemInfo[2589] = { name = "Linen Cloth" }
    WOW.state.bags[0].items = { [1] = { itemID = 6948 }, [2] = { itemID = 2589 }, [3] = { itemID = 6948 } }
    local list = W():Choices("items")
    assert_eq(#list, 1)
    assert_eq(list[1].label, "Hearthstone"); assert_eq(list[1].action, { kind = "item", value = 6948 })
  end,
  macro_choices_account_and_character = function()
    setup()
    WOW.state.macros = { [1] = { name = "Mount", icon = 1 }, [121] = { name = "Heal", icon = 2 } }
    local labels = {}
    for _, c in ipairs(W():Choices("macros")) do labels[#labels + 1] = c.action.value end
    assert_eq(labels, { "Mount", "Heal" })
  end,
  command_choices_start_with_layer_for_a_paddle = function()
    setup()
    local list = W():Choices("commands", true)
    assert_eq(list[1].action, { kind = "layer" })
    assert_eq(list[2].header, true); assert_nil(list[2].action)
    local found = false
    for _, c in ipairs(list) do if c.action and c.action.value == "TOGGLEWORLDMAP" then found = true end end
    assert_true(found)
    assert_true(W():Choices("commands", false)[1].header, "no Layer inside a layer")
  end,
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
  slot_click_opens_picker = function()
    setup()
    W():Show()
    row(1).slot:GetScript("OnClick")(row(1).slot)
    assert_eq(W().picker.n, 1); assert_nil(W().picker.slot)
    assert_eq(W().picker.tab, "spells")
    assert_true(W().frame.picker:IsShown())
  end,
  picking_an_entry_sets_the_action = function()
    setup()
    W():Show()
    W():OpenPicker(1)
    W():PickerSetTab("commands")
    local entries = W().frame.picker.entries
    assert_eq(entries[1].text:GetText(), L().PADDLES_LAYER)
    local idx
    for i, e in ipairs(entries) do if e:IsShown() and e.text:GetText() == "Toggle World Map" then idx = i end end
    assert_true(idx, "command listed")
    entries[idx]:GetScript("OnClick")(entries[idx])
    assert_eq(P():Get(1).action, { kind = "command", value = "TOGGLEWORLDMAP" })
    assert_nil(W().picker); assert_true(not W().frame.picker:IsShown())
  end,
  header_rows_are_not_picked = function()
    setup()
    W():Show()
    W():OpenPicker(1); W():PickerSetTab("commands")
    W().picker.index = 2 -- "Movement Keys" header
    W():PickerChoose()
    assert_nil(P():Get(1).action)
    assert_true(W().picker ~= nil, "still open")
  end,
  picker_tabs_and_pages = function()
    setup()
    for i = 1, 25 do WOW.state.macros[i] = { name = ("M%02d"):format(i), icon = 1 } end
    W():Show()
    W():OpenPicker(2, "PAD1")
    W():PickerTab(1); assert_eq(W().picker.tab, "items")
    W():PickerTab(1); assert_eq(W().picker.tab, "macros")
    assert_eq(W().frame.picker.entries[1].text:GetText(), "M01")
    W():PickerPage(1)
    assert_eq(W().frame.picker.entries[1].text:GetText(), "M11")
    W():PickerPage(5)
    assert_eq(W().frame.picker.entries[1].text:GetText(), "M21", "last page")
    W():PickerTab(-3); assert_eq(W().picker.tab, "commands", "wraps")
    W():ClosePicker(); assert_nil(W().picker)
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
