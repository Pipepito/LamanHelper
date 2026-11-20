-- GameSettings: the new-player page of game settings and its preset.
local L = function() return NewbieNudge.L end
local function cvars(list)
  WOW.state.cvars = {}
  for n, v in pairs(list) do WOW.state.cvars[n] = { value = v.value or v.default, default = v.default } end
end

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
  page_has_groups_and_buttons = function()
    cvars({ autoLootDefault = { default = "0" } }); load_addon()
    local inits = {}
    for _, c in ipairs(WOW.calls) do if c[1] == "initializer" then inits[#inits + 1] = c end end
    local names = {}
    for _, c in ipairs(inits) do names[#names + 1] = c[2] .. ":" .. c[3] end
    for _, k in ipairs({ "GS_GROUP_LOOT", "GS_GROUP_NAMES", "GS_GROUP_COMBAT", "GS_GROUP_MOVE", "GS_GROUP_QUESTS" }) do
      assert_true(tContains(names, "header:" .. L()[k]), k)
    end
    assert_true(tContains(names, "button:" .. L().OPT_GS_PRESET)); assert_true(tContains(names, "button:" .. L().OPT_GS_RESET))
    local found = false
    for _, c in ipairs(WOW.calls) do if c[1] == "RegisterVerticalLayoutSubcategory" and c[3] == L().OPT_GAME_SETTINGS then found = true end end
    assert_true(found)
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
}
