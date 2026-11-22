-- Shape checks on the generated data files under NewbieNudge/Data/.
return {
  toc_icon_texture_is_a_64px_tga_inside_the_addon = function()
    local toc = assert(io.open(ADDON_DIR .. "/NewbieNudge.toc", "rb")):read("*a")
    local path = toc:match("## IconTexture:%s*([^\r\n]+)")
    assert_true(path, "TOC has an IconTexture line")
    local rel = path:match("^Interface\\AddOns\\NewbieNudge\\(.+)$")
    assert_true(rel, "icon lives inside the addon folder, got " .. tostring(path))
    local f = assert(io.open(ADDON_DIR .. "/" .. rel:gsub("\\", "/") .. ".tga", "rb"), "icon file missing")
    local header = f:read(18); f:close()
    assert_eq(header:byte(3), 2, "uncompressed true-colour TGA")
    assert_eq(header:byte(13) + header:byte(14) * 256, 64, "width 64")
    assert_eq(header:byte(15) + header:byte(16) * 256, 64, "height 64")
    assert_eq(header:byte(17), 32, "32 bits per pixel")
  end,
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
  real_warrior_link_parses_against_live_data = function()
    -- a link the user copied from the Icy Veins arms warrior guide on 2026-11-20
    WOW.keepData = true; WOW.state.class = "WARRIOR"; load_addon()
    local link = "https://www.icy-veins.com/wow-forever/warrior-talent-calculator#tc-zzzzzCCCDDFFDEHJIIIHNNNMHOOOOOP222iiiiikkkkkqqqqqQ1~70755-d1899b7d"
    local b, why = NewbieNudge.TalentBuild.Parse(link, "WARRIOR")
    assert_true(b, tostring(why))
    assert_eq(#b.picks, 51); assert_eq(b.version, "70755-d1899b7d"); assert_nil(b.warning)
    assert_true(NewbieNudge.TalentBuild:Set(link))
    assert_eq(#NewbieNudge.db.build.picks, 51)
  end,
  service_npcs_have_positions_and_every_kind_points_at_an_npc = function()
    WOW.keepData = true; load_addon()
    local data = NewbieNudge.ServiceData
    assert_true(data and #data.kinds.repair > 100, "repair vendors")
    for _, kind in ipairs({ "inn", "food", "goods", "trade", "weapon", "trainer_MAGE", "trainer_WARRIOR", "prof_182", "prof_129" }) do
      assert_true(data.kinds[kind] and #data.kinds[kind] > 0, kind)
    end
    assert_eq(#data.kinds.weapon, 8)
    for kind, ids in pairs(data.kinds) do
      for _, id in ipairs(ids) do
        local npc = data.npcs[id]
        assert_true(npc, kind .. " -> " .. id)
        assert_true(type(npc[3]) == "number" and npc[4] >= 0 and npc[4] <= 100 and npc[5] >= 0 and npc[5] <= 100, "position of " .. id)
        assert_true(npc[6] == "A" or npc[6] == "H" or npc[6] == "AH", "faction of " .. id)
      end
    end
  end,
}
