return {
  english_loads_by_default = function()
    load_addon()
    assert_eq(NewbieNudge.L.PANEL_TITLE, "Reminders")
  end,
  spanish_loads_for_esES = function()
    WOW.state.locale = "esES"
    load_addon()
    assert_eq(NewbieNudge.L.PANEL_TITLE, "Recordatorios")
  end,
  esMX_gets_english = function()
    WOW.state.locale = "esMX"
    load_addon()
    assert_eq(NewbieNudge.L.PANEL_TITLE, "Reminders")
  end,
  missing_key_returns_key = function()
    WOW.state.locale = "esES"
    load_addon()
    assert_eq(NewbieNudge.L.NOT_A_KEY, "NOT_A_KEY")
  end,
}
