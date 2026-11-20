-- Shape checks on the generated data files under NewbieNudge/Data/.
return {
  map_fog_entries_have_geometry_and_ids = function()
    WOW.keepData = true; load_addon()
    assert_true(NewbieNudge.MapFog[1412], "Mulgore present")
    for mapID, entries in pairs(NewbieNudge.MapFog) do
      for _, e in ipairs(entries) do assert_true(#e >= 5, "map " .. mapID .. " entry too short") end
    end
  end,
  trainer_spells_have_level_and_id = function()
    WOW.keepData = true; load_addon()
    assert_true(NewbieNudge.TrainerSpells.WARRIOR and #NewbieNudge.TrainerSpells.WARRIOR > 10)
    for class, list in pairs(NewbieNudge.TrainerSpells) do
      for _, e in ipairs(list) do
        assert_true(type(e.level) == "number" and type(e.id) == "number" and e.spell and e.rank, class)
      end
    end
  end,
  zones_and_dungeons_shapes = function()
    WOW.keepData = true; load_addon()
    assert_eq(NewbieNudge.Zones[1440], { min = 19, max = 30 })
    assert_true(#NewbieNudge.Dungeons >= 10)
    for _, d in ipairs(NewbieNudge.Dungeons) do
      assert_true(d.instanceID and d.min and d.max and d.mapID and d.nameEN, d.nameEN)
    end
    assert_true(NewbieNudge.Dungeons[1].min <= NewbieNudge.Dungeons[2].min)
  end,
  icy_talents_shape_and_confirmed_node = function()
    WOW.keepData = true; load_addon()
    local t = NewbieNudge.IcyTalents
    assert_true(type(t.version) == "string" and t.compatible[t.version])
    for _, class in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
      assert_true(t[class], class)
      for id, e in pairs(t[class]) do assert_true(#id == 1 and e.node and e.spell and e.maxRank, class .. ":" .. id) end
    end
    -- confirmed in game 2026-11-20: warrior node 105926 = Improved Intercept, spell 20504, 2 ranks
    assert_eq(t.WARRIOR.u, { node = 105926, spell = 20504, maxRank = 2 })
  end,
}
