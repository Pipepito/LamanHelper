-- GameSettings: the new-player page of game settings and its preset.
local L = function() return NewbieNudge.L end
local function cvars(list)
  WOW.state.cvars = {}
  for n, v in pairs(list) do WOW.state.cvars[n] = { value = v.value or v.default, default = v.default } end
end


-- Calls recorded while the named options page was being built.
local function pageCalls(title)
  local out, inPage = {}, false
  for _, c in ipairs(WOW.calls) do
    if c[1] == "page" then inPage = (c[2] == title)
    elseif inPage then out[#out + 1] = c end
  end
  return out
end
local function varsOf(calls)
  local out = {}
  for _, c in ipairs(calls) do if c[1] == "checkbox" or c[1] == "slider" or c[1] == "dropdown" then out[#out + 1] = c[2] end end
  return out
end
local function mainPageCalls() return pageCalls(NewbieNudge.L.OPT_GENERAL) end

return {
  preset_writes_its_table_and_skips_unknown = function()
    cvars({ autoLootDefault = { default = "0" }, statusTextDisplay = { default = "NONE" }, nameplateShowAll = { default = "0", value = "1" } })
    load_addon()
    local n = NewbieNudge.GameSettings:ApplyPreset()
    assert_eq(n, 2) -- autoLootDefault 0->1, statusTextDisplay NONE->BOTH; nameplateShowAll already 1; the rest unknown to this client
    assert_eq(C_CVar.GetCVar("autoLootDefault"), "1"); assert_eq(C_CVar.GetCVar("statusTextDisplay"), "BOTH")
    assert_nil(C_CVar.GetCVar("lootUnderMouse"))
    assert_true(WOW.printed[#WOW.printed]:find(L().GS_PRESET_DONE:format(2), 1, true))
  end,
  preset_refuses_in_combat = function()
    cvars({ autoLootDefault = { default = "0" } }); load_addon(); WOW.state.inCombat = true
    assert_nil(NewbieNudge.GameSettings:ApplyPreset())
    assert_true(WOW.printed[#WOW.printed]:find(L().GS_IN_COMBAT, 1, true)); assert_eq(C_CVar.GetCVar("autoLootDefault"), "0")
  end,
  dropdown_string_round_trip = function()
    cvars({ statusTextDisplay = { default = "NONE" } }); load_addon()
    WOW.settings["NN_cvar_statusTextDisplay"].setter("PERCENT")
    assert_eq(C_CVar.GetCVar("statusTextDisplay"), "PERCENT"); assert_eq(WOW.settings["NN_cvar_statusTextDisplay"].getter(), "PERCENT")
  end,
  no_discovery_section = function()
    cvars({ autoLootDefault = { default = "0" } }); load_addon()
    assert_eq(NewbieNudge.GameSettings:Discover(), {})
  end,
  reset_writes_defaults = function()
    cvars({ autoLootDefault = { default = "0", value = "1" }, SpellQueueWindow = { default = "400", value = "100" } }); load_addon()
    NewbieNudge.GameSettings:Reset()
    assert_eq(C_CVar.GetCVar("autoLootDefault"), "0"); assert_eq(C_CVar.GetCVar("SpellQueueWindow"), "400")
  end,
  every_preset_cvar_is_curated = function()
    load_addon()
    local curated = {}
    for _, e in ipairs(NewbieNudge.GameSettings.CURATED) do if e.cvar then curated[e.cvar] = true end end
    for cvar in pairs(NewbieNudge.GameSettings.PRESET) do assert_true(curated[cvar], cvar .. " in preset but not curated") end
  end,
  -- v4: the curated list is split across pages.
  every_curated_entry_has_a_valid_page = function()
    load_addon()
    local valid = { bags = true, map = true, combat = true, names = true, interface = true }
    for i, e in ipairs(NewbieNudge.GameSettings.CURATED) do assert_true(valid[e.page], tostring(e.cvar or e.header or i)) end
  end,
  each_cvar_on_exactly_one_page = function()
    load_addon()
    local seen = {}
    for _, c in ipairs(WOW.calls) do
      if (c[1] == "checkbox" or c[1] == "slider" or c[1] == "dropdown") and c[2]:find("^NN_cvar_") then
        assert_nil(seen[c[2]], c[2]); seen[c[2]] = true
      end
    end
    for _, e in ipairs(NewbieNudge.GameSettings.CURATED) do
      if e.cvar then assert_true(seen["NN_cvar_" .. e.cvar], e.cvar) end
    end
  end,
  preset_buttons_on_main_page = function()
    load_addon()
    local names = {}
    for _, c in ipairs(mainPageCalls()) do if c[1] == "initializer" then names[#names + 1] = c[2] .. ":" .. c[3] end end
    assert_true(tContains(names, "button:" .. L().OPT_GS_PRESET)); assert_true(tContains(names, "button:" .. L().OPT_GS_RESET))
  end,
  game_pages_start_with_intro = function()
    load_addon()
    for _, key in ipairs({ "OPT_GS_COMBAT", "OPT_GS_NAMES", "OPT_GS_INTERFACE" }) do
      local calls = pageCalls(L()[key])
      assert_true(#calls > 1, key)
      assert_eq({ calls[1][2], calls[1][3] }, { "header", L().OPT_GS_PAGE_INTRO })
    end
  end,
  combat_and_interface_pages_hold_their_cvars = function()
    load_addon()
    local combat = varsOf(pageCalls(L().OPT_GS_COMBAT))
    assert_true(tContains(combat, "NN_cvar_ActionButtonUseKeyDown")); assert_true(tContains(combat, "NN_cvar_secureAbilityToggle"))
    local names = varsOf(pageCalls(L().OPT_GS_NAMES))
    assert_true(tContains(names, "NN_cvar_nameplateShowEnemies")); assert_true(tContains(names, "NN_cvar_UnitNameOwn"))
    local ui = varsOf(pageCalls(L().OPT_GS_INTERFACE))
    for _, v in ipairs({ "NN_cvar_interactOnLeftClick", "NN_cvar_autoQuestWatch", "NN_cvar_statusTextDisplay", "NN_cvar_Sound_EnableErrorSpeech" }) do
      assert_true(tContains(ui, v), v)
    end
    assert_true(not tContains(ui, "NN_cvar_questPOI"), "questPOI lives on the Map page")
  end,
}
