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
    -- repair 1, 2 (3 is Horde), inn 7, mage trainer 8, baker 10, herbalism trainer 11
    assert_eq(ids, { 1, 2, 7, 8, 10, 11 })
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
    assert_eq(GameTooltip.lines[1], "Innkeeper Farley")
    assert_true(tContains(GameTooltip.lines, "Innkeeper")); assert_true(tContains(GameTooltip.lines, "Elwynn Forest"))
    assert_true(tContains(GameTooltip.lines, L().MAPPIN_REMOVE))
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
}
