-- Locales: the loader, the fallback chain and the data files.
return {
  english_loads_by_default = function()
    load_addon()
    assert_eq(NewbieNudge.L.PANEL_TITLE, "Reminders")
    assert_eq(NewbieNudge.Locales.active, "enUS")
  end,
  spanish_loads_for_esES = function()
    WOW.state.locale = "esES"
    load_addon()
    assert_eq(NewbieNudge.L.PANEL_TITLE, "Recordatorios")
  end,
  esMX_falls_back_to_esES = function()
    WOW.state.locale = "esMX"
    load_addon()
    assert_eq(NewbieNudge.Locales.active, "esES")
    assert_eq(NewbieNudge.L.PANEL_TITLE, "Recordatorios")
  end,
  enGB_is_english = function()
    WOW.state.locale = "enGB"
    load_addon()
    assert_eq(NewbieNudge.L.PANEL_TITLE, "Reminders")
  end,
  unknown_client_locale_gets_english = function()
    WOW.state.locale = "koKR"
    load_addon()
    assert_eq(NewbieNudge.L.PANEL_TITLE, "Reminders")
  end,
  missing_key_returns_key = function()
    WOW.state.locale = "esES"
    load_addon()
    assert_eq(NewbieNudge.L.NOT_A_KEY, "NOT_A_KEY")
  end,
  registering_a_new_language_applies_only_to_that_client = function()
    WOW.state.locale = "frFR"
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/locale_frFR.lua" }
    load_addon()
    assert_eq(NewbieNudge.L.PANEL_TITLE, "Rappels")
    assert_eq(NewbieNudge.L.CHAT_PREFIX, "|cff7fd5ffNewbieNudge|r: ", "untranslated keys stay English")
    assert_true(NewbieNudge.Locales.registered.frFR)
  end,
  other_language_file_does_not_leak_into_english_client = function()
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/locale_frFR.lua" }
    load_addon()
    assert_eq(NewbieNudge.L.PANEL_TITLE, "Reminders")
  end,
  locale_files_are_pure_data = function()
    for _, name in ipairs({ "enUS", "esES" }) do
      local f = assert(io.open(ADDON_DIR .. "/Locales/" .. name .. ".lua", "r"))
      local text = f:read("*a"); f:close()
      assert_true(text:find('NN.RegisterLocale("' .. name .. '"', 1, true), name .. " registers itself")
      assert_true(not text:find("GetLocale", 1, true), name .. " has no locale logic")
    end
  end,
}
