-- The Paddles window (0.5.0): NewbieNudge's own editor for the back paddles,
-- opened from the minimap menu and /nudge paddles (never from the game's
-- Options window, whose commit tainted the controller interface).
local L = function() return NewbieNudge.L end
local function P() return NewbieNudge.Paddles end
local function W() return NewbieNudge.PaddlesWindow end
local function row(n) return W().rows[n] end
local function pad(button)
  local f = W().frame
  local h = f:GetScript("OnGamePadButtonDown")
  assert_true(h, "the window takes pad buttons")
  h(f, button)
end

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
  -- controller mode: d-pad, A, B, X, LB/RB while the window is open
  dpad_moves_the_highlight = function()
    setup()
    W():Show()
    assert_true(W():Focused() == row(1).learn, "starts on paddle 1's Learn")
    pad("PADDRIGHT"); assert_true(W():Focused() == row(1).slot)
    pad("PADDDOWN"); assert_true(W():Focused() == row(2).slot)
    pad("PADDUP"); pad("PADDUP"); assert_true(W():Focused() == W().frame.enable)
    pad("PADDUP"); assert_true(W():Focused() == W().frame.enable, "stops at the top")
    assert_true(W().frame.focusMark:IsShown())
  end,
  dpad_reaches_layer_slots = function()
    setup()
    P():SetKey(1, "F10"); P():SetAction(1, { kind = "layer" })
    W():Show()
    pad("PADDDOWN")
    assert_true(W():Focused() == row(1).layer.PAD1)
  end,
  a_opens_picker_and_chooses = function()
    setup()
    W():Show()
    pad("PADDRIGHT"); pad("PAD1")
    assert_eq(W().picker.n, 1)
    pad("PADRSHOULDER"); pad("PADRSHOULDER"); pad("PADRSHOULDER")
    assert_eq(W().picker.tab, "commands")
    pad("PAD1") -- "Layer" is the first command for a paddle
    assert_eq(P():Get(1).action, { kind = "layer" })
    assert_nil(W().picker)
  end,
  a_on_learn_starts_learning = function()
    setup()
    W():Show()
    pad("PAD1")
    assert_eq(P():IsLearning(), true)
    assert_nil(W().frame:GetScript("OnGamePadButtonDown"), "the window lets go of the pad while learning")
    local l = _G.NewbieNudgePaddleListener
    l:GetScript("OnKeyDown")(l, "F9")
    assert_eq(P():Get(1).key, "F9")
    assert_true(W().frame:GetScript("OnGamePadButtonDown"), "and takes it back after")
  end,
  picker_dpad_moves_and_pages = function()
    setup()
    for i = 1, 25 do WOW.state.macros[i] = { name = ("M%02d"):format(i), icon = 1 } end
    W():Show()
    W():OpenPicker(1); W():PickerSetTab("macros")
    pad("PADDDOWN"); assert_eq(W().picker.index, 2)
    pad("PADDRIGHT"); assert_eq(W().picker.page, 2)
    pad("PADDLEFT"); assert_eq(W().picker.page, 1)
    pad("PADLSHOULDER"); assert_eq(W().picker.tab, "items")
  end,
  b_backs_out = function()
    setup()
    W():Show()
    W():OpenPicker(1)
    pad("PAD2"); assert_nil(W().picker)
    assert_true(W().frame:IsShown())
    pad("PAD2"); assert_true(not W().frame:IsShown())
  end,
  x_clears = function()
    setup()
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "command", value = "TOGGLEBACKPACK" })
    W():Show()
    pad("PADDRIGHT"); pad("PAD3")
    assert_nil(P():Get(1).action)
    P():SetAction(2, { kind = "command", value = "TOGGLEBACKPACK" })
    W():OpenPicker(2); pad("PAD3")
    assert_nil(P():Get(2).action); assert_nil(W().picker)
  end,
  pad_taken_only_while_open_and_out_of_combat = function()
    setup()
    W():Show()
    local f = W().frame
    assert_eq(f.gamepad, true); assert_true(f:GetScript("OnGamePadButtonDown"))
    assert_eq(f.propagatePad, false)
    W():Hide()
    assert_eq(f.gamepad, false); assert_nil(f:GetScript("OnGamePadButtonDown"))
    W():Show()
    WOW.FireEvent("PLAYER_REGEN_DISABLED")
    assert_eq(f.gamepad, false); assert_nil(f:GetScript("OnGamePadButtonDown"))
    WOW.FireEvent("PLAYER_REGEN_ENABLED")
    assert_eq(f.gamepad, true)
  end,
  -- second review (2026-11-23)
  second_learn_click_keeps_the_pad_free = function()
    setup()
    W():Show()
    row(1).learn:GetScript("OnClick")(row(1).learn)
    row(2).learn:GetScript("OnClick")(row(2).learn)
    assert_eq(P():IsLearning(), true)
    assert_nil(W().frame:GetScript("OnGamePadButtonDown"), "the listener gets the paddle")
  end,
  picker_fits_in_the_window = function()
    setup()
    W():Show()
    W():OpenPicker(1)
    assert_true(W().frame:GetHeight() >= 56 + 10 * 24 + 50, "ten entries and the footer fit")
  end,
  picker_starts_and_moves_past_headers = function()
    setup()
    W():Show()
    W():OpenPicker(2, "PAD1"); W():PickerSetTab("commands")
    assert_eq(W().picker.index, 2, "first entry, not the header")
    W():PickerMove(-1)
    assert_eq(W().picker.index, 2, "no stopping on a header")
    W():PickerMove(1); W():PickerMove(1)
    assert_true(not W().picker.list[W().picker.index].header)
  end,
  pad_taken_back_when_the_ui_returns = function()
    setup()
    W():Show()
    local f = W().frame
    f:GetScript("OnHide")(f)
    assert_nil(f:GetScript("OnGamePadButtonDown"))
    f:GetScript("OnShow")(f)
    assert_true(f:GetScript("OnGamePadButtonDown"))
  end,
  -- Forever returns some icons as file paths, not file IDs (2026-11-23)
  icons_given_as_paths_are_shown = function()
    setup()
    WOW.state.spellInfo[774].icon = "Interface/Icons/Spell_Nature_Rejuvenation"
    WOW.state.itemInfo[6948] = { name = "Hearthstone", icon = "Interface/Icons/INV_Misc_Rune_01", useSpell = "Hearthstone" }
    WOW.state.bags[0].items = { [1] = { itemID = 6948 } }
    P():SetKey(1, "F9"); P():SetAction(1, { kind = "spell", value = 774 })
    P():SetKey(2, "F10"); P():SetAction(2, { kind = "item", value = 6948 })
    W():Show()
    assert_eq(row(1).slot.icon:GetTexture(), "Interface/Icons/Spell_Nature_Rejuvenation")
    assert_eq(row(2).slot.icon:GetTexture(), "Interface/Icons/INV_Misc_Rune_01")
    WOW.state.spellBook.lines = { { name = "Balance", offset = 0, num = 1 } }
    WOW.FireEvent("SPELLS_CHANGED")
    assert_eq(W():Choices("spells")[1].icon, "Interface/Icons/Spell_Nature_Rejuvenation")
    assert_eq(W():Choices("items")[1].icon, "Interface/Icons/INV_Misc_Rune_01")
  end,
  -- pad button markers, so the player knows which button does what
  picker_marks_its_buttons = function()
    setup()
    W():Show()
    W():OpenPicker(1)
    local ui = W().frame.picker
    assert_eq(ui.lb.text:GetText(), "LB"); assert_eq(ui.rb.text:GetText(), "RB")
    assert_true(ui.lb:IsShown() and ui.rb:IsShown())
    assert_eq(ui.back.badge.text:GetText(), "B"); assert_eq(ui.clear.badge.text:GetText(), "X")
    W():PickerSetTab("commands")
    local marked
    for _, e in ipairs(ui.entries) do if e:IsShown() and e.mark:IsShown() then marked = e end end
    assert_true(marked and marked.badge:IsShown() and marked.badge.text:GetText() == "A", "A on the marked entry")
  end,
  window_legend_names_the_buttons = function()
    setup()
    W():Show()
    local seen = {}
    for _, b in ipairs(W().frame.legend.badges) do seen[b.text:GetText()] = b.label:GetText() end
    assert_eq(seen.A, L().PADDLES_KEY_SELECT); assert_eq(seen.X, L().PADDLES_KEY_CLEAR)
    assert_eq(seen.B, L().PADDLES_KEY_CLOSE); assert_eq(seen[L().PADDLES_DPAD], L().PADDLES_KEY_MOVE)
  end,
  -- Forever's GetBindingText gives "|A:Gamepad_Gen_1_64:24:24|a" for pad buttons:
  -- the game's own icon for the controller in use (snapshot, 2026-11-23)
  markers_use_the_games_button_icons = function()
    WOW.state.bindingTexts = { PAD1 = "|A:Gamepad_Gen_1_64:24:24|a", PADLSHOULDER = "|A:Gamepad_Gen_LShoulder_64:24:24|a" }
    WOW.state.atlases = { Gamepad_Gen_1_64 = { width = 64, height = 64 }, Gamepad_Gen_LShoulder_64 = { width = 64, height = 64 } }
    setup()
    W():Show()
    W():OpenPicker(1)
    local lb = W().frame.picker.lb
    assert_eq(lb.icon.atlas, "Gamepad_Gen_LShoulder_64"); assert_true(lb.icon:IsShown())
    assert_true(not lb.text:IsShown(), "no drawn marker when the game has the icon")
    local rb = W().frame.picker.rb
    assert_true(rb.text:IsShown() and rb.text:GetText() == "RB", "drawn marker when it doesn't")
  end,
  command_list_shows_action_bar_icons = function()
    setup()
    WOW.state.bindingNames.ACTIONBUTTON6 = "Action Button 6"
    table.insert(WOW.state.bindingList, { "ACTIONBUTTON6", "BINDING_HEADER_ACTIONBAR" })
    WOW.state.actions[6] = { type = "spell", id = 774 }
    local found
    for _, c in ipairs(W():Choices("commands", true)) do if c.action and c.action.value == "ACTIONBUTTON6" then found = c end end
    assert_eq(found.icon, 136081)
  end,
  layer_slot_with_an_action_button_shows_its_spell = function()
    setup()
    WOW.state.actions[6] = { type = "spell", id = 774 }
    P():SetKey(3, "F10"); P():SetAction(3, { kind = "layer" })
    P():SetLayerAction(3, "PAD1", { kind = "command", value = "ACTIONBUTTON6" })
    W():Show()
    assert_eq(row(3).layer.PAD1.icon:GetTexture(), 136081)
  end,
  -- the game's own prompts use the Xbox-style images (letters), not the
  -- generic numbered ones GetBindingText names (snapshot, 2026-11-23)
  markers_prefer_the_letter_buttons = function()
    WOW.state.bindingTexts = { PAD1 = "|A:Gamepad_Gen_1_64:24:24|a", PAD2 = "|A:Gamepad_Gen_2_64:24:24|a",
      PADPADDLE1 = "|A:Gamepad_Gen_Paddle1_64:24:24|a" }
    WOW.state.atlases = { ["Gamepad-Xbox1-ButtonA-Normal"] = {}, Gamepad_Ltr_B_64 = {}, Gamepad_Gen_1_64 = {},
      Gamepad_Gen_2_64 = {}, Gamepad_Gen_Paddle1_64 = {} }
    setup()
    W():Show()
    W():OpenPicker(1)
    local ui = W().frame.picker
    assert_eq(ui.entries[1].badge.icon.atlas, "Gamepad-Xbox1-ButtonA-Normal", "A: the game's prompt image")
    assert_eq(ui.back.badge.icon.atlas, "Gamepad_Ltr_B_64", "B: the letter set when there is no Xbox image")
    assert_eq(W().PadAtlas("PADPADDLE1"), "Gamepad_Gen_Paddle1_64", "paddles: the game's own")
  end,
  button_icons_sit_inside_their_buttons = function()
    setup()
    W():Show()
    W():OpenPicker(1)
    for _, b in ipairs({ W().frame.picker.back, W().frame.picker.clear }) do
      assert_true(b.badge:GetParent() == b, "inside the button")
      local point, _, _, x = b.badge:GetPoint(1)
      assert_eq(point, "LEFT"); assert_true(x > 0, "on the button's left edge, inside")
    end
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
  options_button_only_opens_the_window = function()
    setup()
    local button
    for _, c in ipairs(WOW.calls) do
      if c[1] == "initializer" and c[2] == "button" and c[3] == L().OPT_CONTROLLER_PADDLES then button = c end
    end
    assert_true(button, "Controller page has a Paddles button")
    local before = #WOW.calls
    button[4].fn()
    assert_true(_G.NewbieNudgePaddles:IsShown())
    for i = before + 1, #WOW.calls do
      assert_true(WOW.calls[i][1] ~= "SetCVar" and WOW.calls[i][1] ~= "SetValue", "writes no setting")
    end
  end,
  binding_opens_the_window = function()
    setup()
    assert_eq(_G.BINDING_NAME_NEWBIENUDGE_PADDLES, L().BINDING_PADDLES)
    local xml = io.open("NewbieNudge/Bindings.xml"):read("*a")
    assert_true(xml:find('name="NEWBIENUDGE_PADDLES"', 1, true), "binding declared")
    assert_true(xml:find("NewbieNudge.PaddlesWindow:Toggle()", 1, true))
  end,
}
