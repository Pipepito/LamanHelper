-- Developer mode: an account-wide log (NewbieNudgeDev) of Lua errors, value
-- dumps and state snapshots, written to disk by the client on /reload, plus
-- an in-game copy window. Off by default.
local function L() return NewbieNudge.L end
local function last() return WOW.printed[#WOW.printed] end
local function log() return NewbieNudgeDev.log end
local function dev() return NewbieNudge.Dev end

return {
  off_by_default_and_no_error_handler = function()
    load_addon()
    assert_eq(dev():IsEnabled(), false)
    assert_eq(geterrorhandler(), WOW.defaultErrorHandler)
    assert_eq(NewbieNudgeDev.enabled, false)
    assert_eq(#log(), 0)
  end,

  on_installs_a_handler_that_records_and_chains = function()
    load_addon()
    NewbieNudge:HandleSlash("dev on")
    assert_eq(dev():IsEnabled(), true)
    assert_eq(NewbieNudgeDev.enabled, true)
    assert_eq(last(), L().CHAT_PREFIX .. L().DEV_ON)
    geterrorhandler()("Interface/AddOns/Foo/Foo.lua:12: attempt to index nil")
    assert_eq(#log(), 1)
    assert_eq(log()[1].kind, "error")
    assert_true(log()[1].text:find("attempt to index nil", 1, true))
    assert_true(log()[1].stack ~= nil, "stack captured")
    assert_eq(WOW.errorsSeen[#WOW.errorsSeen], "Interface/AddOns/Foo/Foo.lua:12: attempt to index nil", "previous handler still called")
  end,

  repeated_error_counts_instead_of_repeating = function()
    load_addon()
    NewbieNudge:HandleSlash("dev on")
    geterrorhandler()("boom")
    geterrorhandler()("boom")
    geterrorhandler()("other")
    assert_eq(#log(), 2)
    assert_eq(log()[1].count, 2)
    assert_eq(log()[2].count, 1)
  end,

  off_restores_the_previous_handler_and_stops_recording = function()
    load_addon()
    NewbieNudge:HandleSlash("dev on")
    NewbieNudge:HandleSlash("dev off")
    assert_eq(dev():IsEnabled(), false)
    assert_eq(last(), L().CHAT_PREFIX .. L().DEV_OFF)
    assert_eq(geterrorhandler(), WOW.defaultErrorHandler)
    geterrorhandler()("boom")
    assert_eq(#log(), 0)
  end,

  enabled_in_saved_variables_installs_before_login = function()
    NewbieNudgeDev = { enabled = true, log = {} }
    load_addon()
    assert_eq(dev():IsEnabled(), true)
    assert_true(geterrorhandler() ~= WOW.defaultErrorHandler)
  end,

  dump_records_the_serialized_value = function()
    load_addon()
    _G.Probe = { a = 1, b = "x", c = { d = true } }
    NewbieNudge:HandleSlash("dump Probe")
    assert_eq(#log(), 1)
    assert_eq(log()[1].kind, "dump")
    assert_eq(log()[1].expr, "Probe")
    local text = log()[1].text
    assert_true(text:find("a = 1", 1, true), text)
    assert_true(text:find('b = "x"', 1, true), text)
    assert_true(text:find("d = true", 1, true), text)
    assert_true(last():find(L().CHAT_PREFIX, 1, true))
    assert_true(last():find("a = 1", 1, true), "chat shows the start of the dump: " .. last())
  end,

  dump_works_without_dev_mode_and_keeps_multiple_returns = function()
    load_addon()
    NewbieNudge:HandleSlash("dump 1, nil, 'two'")
    assert_eq(log()[1].text, '1, nil, "two"')
  end,

  dump_reports_evaluation_errors = function()
    load_addon()
    NewbieNudge:HandleSlash("dump NoSuchFunction()")
    assert_eq(log()[1].kind, "dump")
    assert_true(log()[1].text:find("attempt to call", 1, true), log()[1].text)
    assert_true(last():find("attempt to call", 1, true), last())
  end,

  dump_without_expression_prints_usage = function()
    load_addon()
    NewbieNudge:HandleSlash("dump")
    assert_eq(#log(), 0)
    assert_eq(last(), L().CHAT_PREFIX .. L().DEV_DUMP_USAGE)
  end,

  serialize_limits_depth_and_item_count = function()
    load_addon()
    local deep = { { { { { { x = 1 } } } } } }
    local text = dev().Serialize(deep)
    assert_true(text:find("{...}", 1, true), text)
    assert_true(not text:find("x = 1", 1, true), text)
    local wide = {}
    for i = 1, 100 do wide[i] = i end
    text = dev().Serialize(wide)
    assert_true(text:find("(+60 more)", 1, true), text)
  end,

  serialize_describes_frames_functions_and_secrets = function()
    load_addon()
    assert_eq(dev().Serialize(WOW.secret(5)), "<secret>")
    assert_eq(dev().Serialize(UIParent), "<Frame UIParent>")
    assert_eq(dev().Serialize(print), "<function>")
    assert_eq(dev().Serialize("a\nb"), '"a\\nb"')
    assert_true(#dev().Serialize(string.rep("y", 500)) < 260, "long strings are cut")
  end,

  snapshot_records_client_addon_rules_and_bags = function()
    WOW.NewContainerFrame(0, 16)
    load_addon(); load_bags()
    NewbieNudge:HandleSlash("dev snap")
    assert_eq(log()[1].kind, "snapshot")
    local text = log()[1].text
    assert_true(text:find("build 70425", 1, true), text)
    assert_true(text:find("durability", 1, true), "rule states listed")
    assert_true(text:find("containers:", 1, true), text)
    assert_true(text:find("bag 0: 16 slots", 1, true), text)
    assert_true(text:find("inventory slot for bag 1: 20", 1, true), text)
    assert_eq(last(), L().CHAT_PREFIX .. L().DEV_SNAPSHOT_SAVED)
  end,

  snapshot_records_the_controller_setup = function()
    WOW.state.cvars = { GamePadEmulateAlt = { value = "PADPADDLE2", default = "none" }, cameraFoo = { default = "0" } }
    WOW.state.consoleCommands = {
      { command = "GamePadEmulateAlt", help = "", category = 4, commandType = Enum.ConsoleCommandType.Cvar },
      { command = "cameraFoo", help = "", category = 4, commandType = Enum.ConsoleCommandType.Cvar },
    }
    WOW.state.bindings = { PAD1 = "JUMP", ["SHIFT-PAD2"] = "ACTIONBUTTON2" }
    WOW.state.bindingList = { { "JUMP", "Movement", "SPACE", "PAD1" }, { "ACTIONBUTTON2", "ActionBar", "2" } }
    load_addon()
    NewbieNudge:HandleSlash("dev snap")
    local text = log()[1].text
    assert_true(text:find("[gamepad]", 1, true), text)
    assert_true(text:find("GamePadEmulateAlt = PADPADDLE2", 1, true), text)
    assert_true(not text:find("cameraFoo =", 1, true), "only controller settings")
    assert_true(text:find("PAD1 -> JUMP", 1, true), text)
    assert_true(text:find("SHIFT-PAD2 -> ACTIONBUTTON2", 1, true), text)
    assert_true(text:find("JUMP [Movement]: SPACE, PAD1", 1, true), text)
    assert_true(text:find("C_GamePad.IsEnabled", 1, true), text)
  end,

  snapshot_records_the_games_pad_icons = function()
    WOW.state.atlases = { Gamepad_Ltr_A_64 = { width = 64, height = 64, file = 123 } }
    load_addon()
    local legend = CreateFrame("Frame", "GamepadPersistentInputLegend", UIParent)
    local tex = legend:CreateTexture(nil, "ARTWORK")
    tex:SetAtlas("Gamepad_Shp_Cross_64")
    local fs = legend:CreateFontString(nil, "OVERLAY")
    fs:SetText("Jump")
    NewbieNudge:HandleSlash("dev snap")
    local text = log()[1].text
    assert_true(text:find("[gamepad icons]", 1, true), text)
    assert_true(text:find("atlas Gamepad_Shp_Cross_64", 1, true), "textures drawn by the game's controller frames")
    assert_true(text:find('text "Jump"', 1, true), "their text")
    assert_true(text:find("Gamepad_Ltr_A_64 exists", 1, true), "probed atlas names")
    assert_true(text:find("PAD1 binding text", 1, true), "binding text bytes")
  end,

  snapshot_records_the_bank_state = function()
    WOW.bank[Enum.BankType.Character] = { viewable = true, locked = Enum.BankLockedReason.BankConversionFailed, tabs = 0 }
    load_addon()
    WOW.OpenBank()
    NewbieNudge:HandleSlash("dev snap")
    local text = log()[1].text
    assert_true(text:find("bank frame: true", 1, true), text)
    assert_true(text:find("Character: viewable true, locked BankConversionFailed, 0 tab(s)", 1, true), text)
    assert_true(text:find("Account: viewable false, locked nil, 0 tab(s)", 1, true), text)
    assert_true(text:find("any bank viewable: true", 1, true), text)
  end,

  blocked_and_forbidden_actions_are_recorded_while_on = function()
    load_addon()
    WOW.FireEvent("ADDON_ACTION_BLOCKED", "NewbieNudge", "CastSpellByName()")
    assert_eq(#log(), 0, "nothing recorded while off")
    NewbieNudge:HandleSlash("dev on")
    WOW.FireEvent("ADDON_ACTION_BLOCKED", "NewbieNudge", "CastSpellByName()")
    WOW.FireEvent("ADDON_ACTION_FORBIDDEN", "Other", "C_Bank.CloseBankFrame()")
    assert_eq(#log(), 2)
    assert_eq(log()[1].kind, "blocked")
    assert_true(log()[1].text:find("NewbieNudge", 1, true) and log()[1].text:find("CastSpellByName()", 1, true), log()[1].text)
    assert_eq(log()[2].kind, "forbidden")
    assert_true(log()[2].text:find("C_Bank.CloseBankFrame()", 1, true), log()[2].text)
    NewbieNudge:HandleSlash("dev off")
    WOW.FireEvent("ADDON_ACTION_BLOCKED", "NewbieNudge", "CastSpellByName()")
    assert_eq(#log(), 2, "nothing recorded after off")
  end,

  snapshot_survives_a_failing_section = function()
    load_addon()
    GetBuildInfo = function() error("no build") end
    NewbieNudge:HandleSlash("dev snap")
    assert_eq(log()[1].kind, "snapshot")
    assert_true(log()[1].text:find("no build", 1, true), "the failure is written into the snapshot")
  end,

  log_keeps_only_the_newest_entries = function()
    load_addon()
    NewbieNudge:HandleSlash("dev on")
    for i = 1, 120 do geterrorhandler()("e" .. i) end
    assert_eq(#log(), dev().MAX_ENTRIES)
    assert_eq(log()[#log()].text, "e120")
    assert_eq(log()[1].text, "e21")
  end,

  show_opens_a_copy_window_with_the_log_text = function()
    load_addon()
    NewbieNudge:HandleSlash("dump 42")
    NewbieNudge:HandleSlash("dev")
    assert_true(dev().frame and dev().frame:IsShown(), "window shown")
    assert_true(dev().frame.editBox:GetText():find("42", 1, true))
    assert_true(dev().frame.editBox:GetText():find("dump 42", 1, true), "entries carry their kind and source")
  end,

  show_with_empty_log_says_so = function()
    load_addon()
    NewbieNudge:HandleSlash("dev show")
    assert_eq(last(), L().CHAT_PREFIX .. L().DEV_LOG_EMPTY)
    assert_true(not (dev().frame and dev().frame:IsShown()))
  end,

  clear_empties_the_log = function()
    load_addon()
    NewbieNudge:HandleSlash("dump 1")
    NewbieNudge:HandleSlash("dev clear")
    assert_eq(#log(), 0)
    assert_eq(last(), L().CHAT_PREFIX .. L().DEV_CLEARED)
  end,

  options_page_is_registered = function()
    load_addon()
    local found
    for _, page in ipairs(NewbieNudge.Options.pages) do if page.key == "dev" then found = page end end
    assert_true(found, "dev page")
    assert_eq(found.titleKey, "OPT_DEV")
  end,

  help_mentions_dev_and_dump = function()
    load_addon()
    assert_true(L().SLASH_HELP:find("/nudge dev", 1, true))
    assert_true(L().SLASH_HELP:find("/nudge dump", 1, true))
  end,
  -- v4: enough map / service state to debug a pin from one snapshot.
  snapshot_records_map_pins_marks_taxi_professions_and_tracking = function()
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/services.lua" }
    WOW.state.professions = { prof1 = 1 }
    WOW.state.professionInfo = { [1] = { name = "Herbalism", icon = 4620675, skill = 10, maxSkill = 75, skillLine = 182 } }
    load_addon()
    WOW.state.taxiNodes = { [1414] = { { name = "The Crossroads", state = 1, position = { x = 0.5, y = 0.5 } } } }
    NewbieNudge.Services:Mark("prof_182", 11, true, "profession_rank")
    WOW.ViewMap(1429)
    NewbieNudge:HandleSlash("dev snap")
    local text = log()[1].text
    for _, want in ipairs({
      "[services]", "showAll false", "mark prof_182 npc 11 fromRow true rule profession_rank",
      "[map]", "world map shown true, map 1429", "map's own pins: 0, highest level -", "canvas 1000x667 scale 1",
      "pin 1: npc 11 kind prof_182 marked true shown true", "texture 4620675", "ring shown true",
      "[player]", "map 1429 at 0.40,0.61", "continent 0",
      "[taxi]", "The Crossroads state 1",
      "[professions]", "Herbalism skillLine 182 icon 4620675 10/75",
      "[tracking]", "Repair active false",
    }) do
      assert_true(text:find(want, 1, true), "missing: " .. want .. " in " .. text)
    end
  end,
}
