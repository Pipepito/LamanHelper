-- MapPins (v4): marks and nearby services on the world map.
local L = function() return NewbieNudge.L end
local function load()
  WOW.extraFiles = { TESTS_DIR .. "/fixtures/services.lua" }
  load_addon()
end
local function shown()
  local out = {}
  for _, pin in ipairs(NewbieNudge.MapPins.pins) do if pin:IsShown() then out[#out + 1] = pin end end
  return out
end
local function pinFor(npcID)
  for _, pin in ipairs(shown()) do if pin.npcID == npcID then return pin end end
end

return {
  marked_npc_on_the_viewed_map = function()
    load()
    NewbieNudge.Services:Mark("inn", 7, true)
    WOW.ViewMap(1429)
    local pins = shown()
    assert_eq(#pins, 1)
    local point, rel, _, x, y = pins[1]:GetPoint(1)
    assert_eq(point, "CENTER"); assert_true(rel == WorldMapFrame.ScrollContainer.Child)
    assert_true(math.abs(x - 437.7) < 0.001 and math.abs(y + 0.658 * 667) < 0.001, x .. "," .. y)
    assert_eq(pins[1].marked, true); assert_eq(pins[1]:GetWidth(), 20)
  end,
  other_map_shows_nothing_and_old_pins_go = function()
    load()
    NewbieNudge.Services:Mark("inn", 7, true)
    WOW.ViewMap(1429); assert_eq(#shown(), 1)
    WOW.ViewMap(1453); assert_eq(#shown(), 0)
  end,
  marking_refreshes_an_open_map = function()
    load()
    WOW.ViewMap(1429); assert_eq(#shown(), 0)
    NewbieNudge.Services:Mark("repair", 1, true)
    assert_eq(#shown(), 1)
  end,
  show_all_lists_every_service_for_class_and_professions = function()
    load()
    WOW.state.professions = { prof1 = 1 }; WOW.state.professionInfo = { [1] = { name = "Herbalism", skill = 1, maxSkill = 75, skillLine = 182 } }
    NewbieNudge.MapPins:SetShowAll(true)
    WOW.ViewMap(1429)
    local ids = {}
    for _, pin in ipairs(shown()) do ids[#ids + 1] = pin.npcID end
    table.sort(ids)
    -- repair 1, 2 (3 is Horde), inn 7, mage trainer 8, baker 10, herbalism trainer 11,
    -- general goods 12, trade supplies 13
    assert_eq(ids, { 1, 2, 7, 8, 10, 11, 12, 13 })
    assert_eq(pinFor(1):GetWidth(), 14); assert_eq(pinFor(1).marked, false)
  end,
  a_marked_npc_is_drawn_once = function()
    load()
    NewbieNudge.MapPins:SetShowAll(true)
    NewbieNudge.Services:Mark("repair", 1, true)
    WOW.ViewMap(1429)
    local n = 0
    for _, pin in ipairs(shown()) do if pin.npcID == 1 then n = n + 1 end end
    assert_eq(n, 1); assert_eq(pinFor(1).marked, true)
  end,
  refresh_reuses_the_pool = function()
    load()
    NewbieNudge.MapPins:SetShowAll(true)
    WOW.ViewMap(1429)
    local size = #NewbieNudge.MapPins.pins
    NewbieNudge.MapPins:Refresh(); NewbieNudge.MapPins:Refresh()
    assert_eq(#NewbieNudge.MapPins.pins, size)
  end,
  tooltips = function()
    load()
    NewbieNudge.Services:Mark("inn", 7, true)
    NewbieNudge.MapPins:SetShowAll(true)
    WOW.ViewMap(1429)
    WOW.Hover(pinFor(7))
    assert_eq(GameTooltip.lines[2], "Innkeeper Farley", "option line first, then the name")
    assert_true(tContains(GameTooltip.lines, "Innkeeper")); assert_true(tContains(GameTooltip.lines, "Elwynn Forest"))
    assert_true(tContains(GameTooltip.lines, L().MAPPIN_REMOVE_OPTION))
    WOW.Hover(pinFor(1))
    assert_true(tContains(GameTooltip.lines, L().MAPPIN_CLICK_MARK))
  end,
  right_click_removes_a_mark = function()
    load()
    NewbieNudge.Services:Mark("inn", 7, true)
    WOW.ViewMap(1429)
    WOW.Click(pinFor(7), "RightButton")
    assert_true(not NewbieNudge.Services:IsMarked("inn"))
    assert_eq(#shown(), 0)
  end,
  left_click_marks_a_nearby_service = function()
    load()
    NewbieNudge.MapPins:SetShowAll(true)
    WOW.ViewMap(1429)
    WOW.Click(pinFor(2), "LeftButton")
    local m = NewbieNudge.Services:MarkOf("repair")
    assert_eq({ m.npcID, m.fromRow }, { 2, false })
  end,
  show_all_saved_in_db = function()
    load()
    NewbieNudge.MapPins:SetShowAll(true)
    assert_eq(NewbieNudge.db.services.showAll, true)
  end,
  -- Review fixes
  pins_follow_the_canvas_scale_and_zoom = function()
    load()
    WOW.state.canvasScale = 2
    NewbieNudge.Services:Mark("inn", 7, true)
    WOW.ViewMap(1429)
    local pin = pinFor(7)
    assert_eq(pin:GetScale(), 0.5)
    local _, _, _, x = pin:GetPoint(1)
    assert_true(math.abs(x - 437.7 * 2) < 0.001, "offset in the pin's own scale: " .. x)
    WOW.state.canvasScale = 4
    WorldMapFrame:OnCanvasScaleChanged()
    _, _, _, x = pinFor(7):GetPoint(1)
    assert_true(math.abs(x - 437.7 * 4) < 0.001, "redrawn on zoom: " .. x)
  end,
  pins_keep_the_map_strata_above_its_canvas = function()
    load()
    NewbieNudge.Services:Mark("inn", 7, true)
    WOW.ViewMap(1429)
    assert_nil(pinFor(7).strata)
    assert_true(pinFor(7):GetFrameLevel() > WorldMapFrame.ScrollContainer.Child:GetFrameLevel())
  end,
  marking_from_a_map_pin_says_so_and_tracks = function()
    load()
    NewbieNudge.MapPins:SetShowAll(true)
    WOW.ViewMap(1429)
    local opened = 0
    for _, c in ipairs(WOW.calls) do if c[1] == "OpenWorldMap" then opened = opened + 1 end end
    WOW.Click(pinFor(2), "LeftButton")
    assert_true(WOW.printed[#WOW.printed]:find(L().SERVICES_MARKED:format("Far Smith", "Armorer", "Elwynn Forest"), 1, true))
    assert_eq(WOW.state.tracking[2].active, true)
    local after = 0
    for _, c in ipairs(WOW.calls) do if c[1] == "OpenWorldMap" then after = after + 1 end end
    assert_eq(after, opened, "map already open: not reopened")
  end,
  -- The tracking-border ring's opening is centred at (15.5, -14.5) of its
  -- 53 px texture and about 21 px wide: the 20 px icon fills that opening.
  ring_is_centred_on_the_icon_and_the_icon_fills_it = function()
    load()
    NewbieNudge.Services:Mark("inn", 7, true)
    WOW.ViewMap(1429)
    local pin = pinFor(7)
    local k = 20 / 21
    assert_true(math.abs(pin.ring:GetWidth() - 53 * k) < 0.01, "ring size " .. pin.ring:GetWidth())
    local point, rel, relPoint, x, y = pin.ring:GetPoint(1)
    assert_eq({ point, relPoint }, { "TOPLEFT", "TOPLEFT" }); assert_true(rel == pin)
    -- the ring's opening centre lands on the icon centre (10, -10)
    assert_true(math.abs(x + 15.5 * k - 10) < 0.01 and math.abs(y - 14.5 * k + 10) < 0.01, x .. "," .. y)
  end,
  icon_is_round = function()
    load()
    NewbieNudge.Services:Mark("inn", 7, true)
    WOW.ViewMap(1429)
    local mask = pinFor(7).icon.mask
    assert_true(mask, "icon masked")
    assert_eq(mask.texture, "Interface\\CharacterFrame\\TempPortraitAlphaMask")
  end,
  class_trainers_show_the_class_icon = function()
    load()
    NewbieNudge.Services:Mark("trainer_MAGE", 8, true)
    WOW.ViewMap(1429)
    local icon = pinFor(8).icon
    assert_eq(icon.texture, "Interface\\TargetingFrame\\UI-Classes-Circles")
    assert_eq(icon.texCoord, { 0.25, 0.49609375, 0, 0.25 })
  end,
  other_pins_reset_the_texture_coords = function()
    load()
    NewbieNudge.Services:Mark("trainer_MAGE", 8, true)
    WOW.ViewMap(1429)
    NewbieNudge.Services:ClearMarks()
    NewbieNudge.Services:Mark("inn", 7, true) -- reuses the same pooled pin
    local icon = pinFor(7).icon
    assert_eq(icon.texture, "Interface\\Icons\\INV_Misc_Rune_01")
    assert_eq(icon.texCoord, { 0, 1, 0, 1 })
  end,
  -- Forever: a hard-coded icon id drew nothing (herbalism pin, 2026-11-22).
  profession_pins_use_the_client_profession_icon = function()
    load()
    WOW.state.professions = { prof1 = 1 }
    WOW.state.professionInfo = { [1] = { name = "Herbalism", icon = 4620675, skill = 1, maxSkill = 75, skillLine = 182 } }
    NewbieNudge.Services:Mark("prof_182", 11, true)
    WOW.ViewMap(1429)
    assert_eq(pinFor(11).icon.texture, 4620675)
  end,
  profession_pins_without_that_profession_use_a_named_icon = function()
    load()
    NewbieNudge.Services:Mark("prof_182", 11, true)
    WOW.ViewMap(1429)
    assert_eq(pinFor(11).icon.texture, "Interface\\Icons\\Trade_Herbalism")
  end,
  numbered_pins_gold_ring_first = function()
    load()
    NewbieNudge.Services:Mark("repair", { 1, 2 }, true)
    WOW.ViewMap(1429)
    local a, b = pinFor(1), pinFor(2)
    assert_eq({ a.rank, b.rank }, { 1, 2 })
    assert_eq(a.rankText:GetText(), "1"); assert_eq(b.rankText:GetText(), "2")
    assert_eq(a.ring.vertexColor, { 1, 0.82, 0 })
    assert_eq(b.ring.vertexColor, { 0.75, 0.75, 0.75 })
  end,
  single_option_has_no_number = function()
    load()
    NewbieNudge.Services:Mark("inn", { 7 }, true)
    WOW.ViewMap(1429)
    assert_true(not pinFor(7).rankText:IsShown())
  end,
  right_click_removes_just_that_option = function()
    load()
    NewbieNudge.Services:Mark("repair", { 1, 2 }, true)
    WOW.ViewMap(1429)
    WOW.Click(pinFor(2), "RightButton")
    assert_eq(NewbieNudge.Services:MarkOf("repair").npcs, { 1 })
  end,
  option_tooltip_shows_rank_time_and_route = function()
    load()
    NewbieNudge.Services:Mark("repair", { 1, 2 }, true)
    WOW.ViewMap(1429)
    WOW.Hover(pinFor(1))
    assert_eq(GameTooltip.lines[1], L().MAPPIN_OPTION:format(1, 1, L().SERVICES_ROUTE_FOOT))
    assert_eq(GameTooltip.lines[2], "Near Smith")
  end,
  -- In game the explored-area layer covered our pins (tooltip worked, nothing
  -- visible): pins go above every pin the map itself has.
  pins_sit_above_the_maps_own_pins = function()
    load()
    local explored = WOW.NewMapPin(1429)
    explored:SetFrameLevel(2000)
    NewbieNudge.Services:Mark("inn", 7, true)
    WOW.ViewMap(1429)
    assert_true(pinFor(7):GetFrameLevel() > 2000, tostring(pinFor(7):GetFrameLevel()))
  end,
  the_map_list_sits_above_the_pins = function()
    load()
    NewbieNudge.Services:Mark("inn", 7, true)
    WOW.ViewMap(1429)
    NewbieNudge.MapList:Toggle()
    assert_eq(NewbieNudge.MapList.frame.strata, "DIALOG")
  end,
  other_continent_option_says_so = function()
    load()
    NewbieNudge.Services:Mark("repair", { 1, 6 }, true)
    WOW.ViewMap(1439)
    WOW.Hover(pinFor(6))
    assert_eq(GameTooltip.lines[1], L().MAPPIN_OPTION_FAR:format(2, L().SERVICES_ROUTE_CONTINENT))
  end,
  show_all_has_food_goods_and_trade = function()
    load()
    local kinds = NewbieNudge.MapPins.ShowAllKinds()
    assert_true(tContains(kinds, "food")); assert_true(tContains(kinds, "goods")); assert_true(tContains(kinds, "trade"))
    assert_true(not tContains(kinds, "supplies"))
  end,
  show_all_offers_every_profession_trainer = function()
    load()
    assert_true(tContains(NewbieNudge.MapPins.ShowAllKinds(), "prof_all"))
    NewbieNudge.MapList:Toggle()
    local found
    for _, row in ipairs(NewbieNudge.MapList.rows) do if row.kindKey == "prof_all" then found = row end end
    assert_eq(found.label:GetText(), L().MAPLIST_KIND_PROF_ALL)
  end,
}
