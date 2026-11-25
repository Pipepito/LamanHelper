-- NewbieNudge's own settings window: every options page, driven by the pad,
-- opened from the game's Esc menu.
local L = function() return NewbieNudge.L end
local function W() return NewbieNudge.SettingsWindow end
local function callsNamed_any(name)
  local out = {}
  for _, c in ipairs(WOW.calls) do if c[1] == name then out[#out + 1] = c end end
  return out
end
local function pad(button)
  local f = W().frame
  local h = f:GetScript("OnGamePadButtonDown")
  assert_true(h, "the window takes pad buttons")
  h(f, button)
end
local function selectLabel(label)
  for i, e in ipairs(W():Entries()) do if e.label == label then W().sel = i; return e end end
  error("no entry " .. label)
end

-- A stand-in for the game's list-built Esc menu (InitButtons/AddButton).
local function fakeGameMenu()
  local buttons = {}
  rawset(GameMenuFrame, "AddButton", function(self, text, callback)
    local b = { text = text, callback = callback, layoutIndex = #buttons + 1 }
    function b:GetText() return self.text end
    buttons[#buttons + 1] = b
    return b
  end)
  GameMenuFrame.buttonPool = { EnumerateActive = function()
    local i = 0
    return function() i = i + 1; return buttons[i] end
  end }
  GameMenuFrame.MarkDirty = function() end
  return buttons
end

return {
  every_options_page_is_listed = function()
    load_addon()
    W():Show()
    local titles = {}
    for _, page in ipairs(W().pages) do titles[#titles + 1] = page.title end
    assert_eq(titles[1], L().OPT_GENERAL)
    local has = {}
    for _, t in ipairs(titles) do has[t] = true end
    assert_true(has[L().OPT_REMINDERS]); assert_true(has[L().OPT_BAGS]); assert_true(has[L().OPT_MAP])
    assert_eq(W():Entries()[1].kind, "header")
    assert_eq(W().sel, 2, "starts on the first setting, not the header")
    for key, err in pairs(NewbieNudge.db.errors) do
      assert_true(not key:find("^settings:"), "page failed to record: " .. key .. " " .. tostring(err))
    end
    assert_eq(#W().pages, #NewbieNudge.Options.OrderedPages() + 1, "no page left out")
  end,
  a_toggles_a_checkbox = function()
    load_addon()
    W():Show()
    selectLabel(L().OPT_LOCK)
    local before = NewbieNudge.db.panel.locked
    pad("PAD1")
    assert_eq(NewbieNudge.db.panel.locked, not before)
  end,
  left_right_change_sliders_within_range = function()
    load_addon()
    W():Show()
    selectLabel(L().OPT_SCALE)
    NewbieNudge.db.panel.scale = 1
    pad("PADDRIGHT")
    assert_eq(NewbieNudge.db.panel.scale, 1.1)
    for _ = 1, 20 do pad("PADDRIGHT") end
    assert_eq(NewbieNudge.db.panel.scale, 1.5, "stops at the maximum")
    assert_eq(W().ValueText(W():Selected()), "1.5")
  end,
  left_right_cycle_dropdowns = function()
    load_addon()
    W():Show()
    selectLabel(L().OPT_STYLE)
    NewbieNudge.db.panel.style = "list"
    pad("PADDRIGHT")
    assert_eq(NewbieNudge.db.panel.style, "icons")
    pad("PADDRIGHT")
    assert_eq(NewbieNudge.db.panel.style, "list", "wraps around")
  end,
  shoulders_switch_pages_and_b_closes = function()
    load_addon()
    W():Show()
    pad("PADRSHOULDER")
    assert_eq(W().page, 2)
    pad("PADLSHOULDER"); pad("PADLSHOULDER")
    assert_eq(W().page, #W().pages, "wraps to the last page")
    pad("PAD2")
    assert_true(not W().frame:IsShown())
  end,
  dpad_skips_headers_and_shows_help = function()
    load_addon()
    W():Show()
    for _ = 1, 30 do pad("PADDDOWN") end
    assert_true(W():Selected().kind ~= "header")
    assert_true(W().sel > 15 and W().offset > 0, "scrolled down")
    selectLabel(L().OPT_LOCK); W():Render()
    assert_eq(W().frame.desc:GetText(), L().OPT_LOCK_TT)
  end,
  wheel_scrolls_the_list_not_the_selection = function()
    load_addon()
    W():Show()
    assert_true(#W():Entries() > 15, "the General page needs scrolling")
    local sel = W().sel
    W().frame:Fire("OnMouseWheel", -1)
    assert_eq(W().offset, 3)
    assert_eq(W().sel, sel, "selection stays")
    for _ = 1, 50 do W().frame:Fire("OnMouseWheel", -1) end
    assert_eq(W().offset, W():MaxOffset(), "stops at the bottom")
    for _ = 1, 50 do W().frame:Fire("OnMouseWheel", 1) end
    assert_eq(W().offset, 0, "stops at the top")
  end,
  scroll_bar_arrows_and_thumb = function()
    load_addon()
    W():Show()
    local bar = W().frame.bar
    assert_true(bar:IsShown(), "shown on a long page")
    bar.down:Fire("OnClick")
    assert_eq(W().offset, 1)
    bar.up:Fire("OnClick")
    assert_eq(W().offset, 0)
    local h, y = W():ThumbLayout()
    assert_eq(y, 0)
    assert_true(h >= 24 and h < 15 * 26, "thumb smaller than the track")
    -- drag the thumb all the way down
    W():DragTo(0, 10000)
    assert_eq(W().offset, W():MaxOffset())
    local _, y2 = W():ThumbLayout()
    assert_eq(y2, 15 * 26 - 2 * 16 - h, "thumb at the bottom of the track")
  end,
  scroll_bar_hidden_when_page_fits = function()
    load_addon()
    W():Show()
    local short
    for i, page in ipairs(W().pages) do if #page.entries <= 15 then short = i end end
    assert_true(short, "some page fits")
    W():SetPage(short)
    assert_true(not W().frame.bar:IsShown())
  end,
  not_in_the_games_addons_options = function()
    load_addon()
    W():Show()
    assert_nil(NewbieNudge.Options.recorder, "recording switched off again")
    assert_eq(#callsNamed_any("RegisterAddOnCategory"), 0, "nothing in the game's AddOns options list")
  end,
  slash_and_binding_open_it = function()
    load_addon()
    NewbieNudge:HandleSlash("settings")
    assert_true(W().frame:IsShown())
    W():Toggle()
    assert_true(not W().frame:IsShown())
  end,
  esc_menu_gets_a_button_above_addons = function()
    local buttons = fakeGameMenu()
    load_addon()
    ADDONS = "AddOns"
    GameMenuFrame:AddButton(ADDONS, function() end).topPadding = 10
    GameMenuFrame:Fire("OnShow")
    local ours
    for _, b in ipairs(buttons) do if b.text == L().ADDON_TITLE then ours = b end end
    assert_true(ours, "button added")
    assert_eq(ours.layoutIndex, 1 - 0.4)
    assert_eq(ours.topPadding, 10, "heads the AddOns section")
    ours.callback()
    assert_true(W().frame:IsShown())
  end,
  esc_menu_button_closes_the_menu = function()
    local buttons = fakeGameMenu()
    load_addon()
    HideUIPanel = function() end -- as if the game's panel manager left it open
    WOW.ShowGameMenu(true)
    local ours
    for _, b in ipairs(buttons) do if b.text == L().ADDON_TITLE then ours = b end end
    assert_true(ours, "button added")
    ours.callback()
    assert_true(not GameMenuFrame:IsShown(), "game menu closed")
    assert_true(W().frame:IsShown())
    -- reopened by the game's own click handling: closed again next frame
    GameMenuFrame:Show()
    WOW.AdvanceTime(0.1)
    assert_true(not GameMenuFrame:IsShown(), "closed again on the next frame")
    assert_true(W().frame:IsShown())
    HideUIPanel = nil
  end,
}
