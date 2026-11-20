-- NN.CVarSection: the generic curated/discovered CVar page builder.
local function cvars(list)
  WOW.state.cvars = {}
  for name, v in pairs(list) do WOW.state.cvars[name] = { value = v.value or v.default, default = v.default } end
end
local function callsNamed(name)
  local out = {}
  for _, c in ipairs(WOW.calls) do if c[1] == name then out[#out + 1] = c end end
  return out
end
local function has(list, pred) for _, c in ipairs(list) do if pred(c) then return c end end end
local function section()
  return NewbieNudge.CVarSection.New({
    curated = {
      { header = "OPT_GENERAL" },
      { cvar = "fooA", kind = "checkbox", label = "OPT_LOCK", help = "OPT_LOCK_TT" },
      { cvar = "fooB", kind = "dropdown", options = { { "0", "STATE_OFF" }, { "2", "STATE_ON" } }, label = "OPT_SCALE", help = "OPT_SCALE" },
    },
    exclude = { fooX = true },
    match = function(name) return name:sub(1, 3) == "foo" end,
    otherHeader = "OPT_CAMERA_OTHER", resetLabel = "OPT_CAMERA_RESET",
  })
end

return {
  apply_counts_changes_and_skips_unknown = function()
    cvars({ fooA = { default = "0" }, fooB = { default = "1", value = "1" } })
    load_addon()
    local s = section()
    assert_eq(s:Apply({ fooA = 1, fooB = "1", nope = 1 }), 1)
    assert_eq(s:GetString("fooA"), "1")
    assert_nil(s:Get("nope"))
  end,
  discover_uses_match_and_exclude = function()
    cvars({ fooA = { default = "0" }, fooC = { default = "3" }, fooX = { default = "1" }, bar = { default = "1" } })
    WOW.state.consoleCommands = {}
    for _, n in ipairs({ "fooA", "fooC", "fooX", "bar" }) do
      WOW.state.consoleCommands[#WOW.state.consoleCommands + 1] = { command = n, help = "", commandType = 0 }
    end
    load_addon()
    local found = section():Discover()
    assert_eq(#found, 1); assert_eq(found[1].cvar, "fooC")
  end,
  dropdown_shows_raw_value_when_unknown = function()
    cvars({ fooA = { default = "0" }, fooB = { default = "1", value = "7" } })
    load_addon()
    local cat, layout = NewbieNudge.Options.AddSubcategory("X")
    section():AddControls(cat, layout)
    local dd = callsNamed("dropdown")[1]
    assert_eq(dd[2], "NN_cvar_fooB")
    assert_eq(dd[3][#dd[3]], { value = "7", label = "7" })
    local inits = callsNamed("initializer")
    assert_true(has(inits, function(c) return c[2] == "header" and c[3] == NewbieNudge.L.OPT_GENERAL end))
    assert_eq(inits[#inits][2], "button") -- the reset button comes last when nothing is discovered
  end,
  dropdown_setter_writes_string = function()
    cvars({ fooB = { default = "1" } })
    load_addon()
    local cat, layout = NewbieNudge.Options.AddSubcategory("X")
    section():AddControls(cat, layout)
    WOW.settings["NN_cvar_fooB"].setter("2")
    assert_eq(C_CVar.GetCVar("fooB"), "2")
    assert_eq(WOW.settings["NN_cvar_fooB"].getter(), "2")
  end,
}
