-- TalentBuild: parsing an Icy Veins talent-calculator link, storing it, and
-- (Task 16) the talent_build rule.
local function setup() WOW.extraFiles = { TESTS_DIR .. "/fixtures/icy_talents.lua" } end
local P = function(t, c) return NewbieNudge.TalentBuild.Parse(t, c or "MAGE") end

return {
  parses_full_url_fragment_and_bare = function()
    setup(); load_addon()
    local url = "https://www.icy-veins.com/wow-forever/mage-talent-calculator#tc-11BBz~3-c"
    local b = P(url)
    assert_eq(b.class, "MAGE"); assert_eq(b.version, "3-c"); assert_eq(b.picks, { "1", "1", "B", "B", "z" }); assert_nil(b.warning)
    assert_eq(P("#tc-11BBz~3-c").picks, b.picks); assert_eq(P("tc-11BBz~3-c").picks, b.picks); assert_eq(P("11BBz~3-c").picks, b.picks)
  end,
  rejects_unknown_talent_wrong_class_and_no_link = function()
    setup(); load_addon()
    local b, why = P("#tc-11Q~3-c"); assert_nil(b); assert_eq(why, "unknown_talent")
    b, why = P("https://www.icy-veins.com/wow-forever/priest-talent-calculator#tc-11~3-c"); assert_nil(b); assert_eq(why, "wrong_class")
    b, why = P("hello"); assert_nil(b); assert_eq(why, "no_link")
  end,
  rejects_more_points_than_max_rank = function()
    setup(); load_addon()
    local b, why = P("#tc-111~3-c"); assert_nil(b); assert_eq(why, "too_many_points")
  end,
  old_version_warns_but_loads = function()
    setup(); load_addon()
    local b = P("#tc-1B~1-a"); assert_eq(b.warning, "old_version"); assert_eq(#b.picks, 2)
  end,
  set_and_clear_store_in_db_and_say = function()
    setup(); load_addon()
    NewbieNudge.TalentBuild:Set("#tc-11B~3-c")
    assert_eq(NewbieNudge.db.build.picks, { "1", "1", "B" }); assert_eq(NewbieNudge.db.build.version, "3-c")
    assert_true(WOW.printed[#WOW.printed]:find(NewbieNudge.L.BUILD_SET:format(3), 1, true))
    NewbieNudge.TalentBuild:Set("#tc-Q~3-c")
    assert_eq(#NewbieNudge.db.build.picks, 3, "a bad link does not clear the good one")
    assert_true(WOW.printed[#WOW.printed]:find(NewbieNudge.L.BUILD_ERR_UNKNOWN_TALENT, 1, true))
    NewbieNudge:HandleSlash("build clear"); assert_nil(NewbieNudge.db.build)
    NewbieNudge:HandleSlash("build #tc-1~3-c"); assert_eq(#NewbieNudge.db.build.picks, 1)
  end,
  status_text = function()
    setup(); load_addon()
    assert_eq(NewbieNudge.TalentBuild:Status(), NewbieNudge.L.BUILD_STATUS_NONE)
    NewbieNudge.TalentBuild:Set("#tc-11B~3-c")
    assert_true(NewbieNudge.TalentBuild:Status():find("3", 1, true))
  end,
}
