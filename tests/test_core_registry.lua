local function rule(over)
  local r = { name = "demo", title = "T", help = "H", events = {},
              applies = function() return true end, check = function() return nil end }
  for k, v in pairs(over or {}) do r[k] = v end
  return r
end

return {
  register_stores_rule_with_defaults = function()
    load_addon()
    NewbieNudge:RegisterRule(rule())
    local r = NewbieNudge.ruleByName.demo
    assert_true(r.default)
    assert_eq(r.combat, false)
    assert_eq(NewbieNudge.rules[#NewbieNudge.rules], r)
  end,
  register_rejects_duplicate_name = function()
    load_addon()
    NewbieNudge:RegisterRule(rule())
    local ok, err = pcall(NewbieNudge.RegisterRule, NewbieNudge, rule())
    assert_true(not ok)
    assert_true(tostring(err):find("invalid rule demo: name", 1, true), err)
  end,
  register_rejects_bad_name = function()
    load_addon()
    local ok = pcall(NewbieNudge.RegisterRule, NewbieNudge, rule({ name = "Bad Name" }))
    assert_true(not ok)
  end,
  register_rejects_missing_check = function()
    load_addon()
    local r = rule(); r.check = nil
    local ok, err = pcall(NewbieNudge.RegisterRule, NewbieNudge, r)
    assert_true(not ok)
    assert_true(tostring(err):find("check", 1, true), err)
  end,
  plain_filters_secrets_and_types = function()
    load_addon()
    assert_eq(NewbieNudge.Plain(3), 3)
    assert_nil(NewbieNudge.Plain(WOW.secret(3)))
    assert_nil(NewbieNudge.Plain("x"))
    assert_eq(NewbieNudge.Plain("x", "string"), "x")
  end,
  db_gets_defaults_without_clobbering = function()
    _G.NewbieNudgeDB = { snoozeMinutes = 30 }
    load_addon()
    assert_eq(NewbieNudge.db.snoozeMinutes, 30)
    assert_eq(NewbieNudge.db.panel.locked, true)
    assert_eq(NewbieNudge.db.combatStrip, true)
    assert_eq(NewbieNudge.db, NewbieNudgeDB)
  end,
  say_uses_prefix = function()
    load_addon()
    NewbieNudge:Say("hi")
    assert_eq(WOW.printed[#WOW.printed], "|cff7fd5ffNewbieNudge|r: hi")
  end,
  class_and_project_detected = function()
    load_addon()
    assert_eq(NewbieNudge.classFile, "MAGE")
    assert_true(NewbieNudge.isForever)
  end,
  missing_or_bad_group_becomes_other = function()
    load_addon()
    local base = { title = "T", help = "H", events = {}, applies = function() return true end, check = function() end }
    local a = NewbieNudge:RegisterRule(setmetatable({ name = "no_group" }, { __index = base }))
    local b = NewbieNudge:RegisterRule(setmetatable({ name = "bad_group", group = "nope" }, { __index = base }))
    local c = NewbieNudge:RegisterRule(setmetatable({ name = "good_group", group = "quests" }, { __index = base }))
    assert_eq(a.group, "other"); assert_eq(b.group, "other"); assert_eq(c.group, "quests")
  end,
}
