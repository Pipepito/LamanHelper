-- MapReveal: unexplored map tiles drawn dimmed under Blizzard's explored ones.
local function fog(mapID, entries) NewbieNudge.MapFog[mapID] = entries end
local function activeTextures(pin)
  local out = {}
  local pool = NewbieNudge.MapReveal.pools[pin]
  if not pool then return out end
  for t in pool:EnumerateActive() do out[#out + 1] = t end
  return out
end

return {
  tiles_for_lays_out_grid_and_edge_texcoords = function()
    load_addon()
    local tiles = NewbieNudge.MapReveal.TilesFor({ { 300, 270, 10, 20, 1, 2, 3, 4 } }, {}, 256, 256)
    assert_eq(#tiles, 4)
    assert_eq(tiles[1], { fileID = 1, x = 10, y = 20, w = 256, h = 256, u = 1, v = 1 })
    assert_eq(tiles[2], { fileID = 2, x = 266, y = 20, w = 44, h = 256, u = 44 / 64, v = 1 })
    assert_eq(tiles[3], { fileID = 3, x = 10, y = 276, w = 256, h = 14, u = 1, v = 14 / 16 })
    assert_eq(tiles[4].fileID, 4)
  end,
  explored_entries_are_skipped = function()
    load_addon()
    local tiles = NewbieNudge.MapReveal.TilesFor({ { 100, 100, 0, 0, 7 }, { 100, 100, 100, 0, 8 } }, { ["100:100:0:0"] = true }, 256, 256)
    assert_eq(#tiles, 1); assert_eq(tiles[1].fileID, 8)
  end,
  refresh_draws_unexplored_tiles_dimmed = function()
    load_addon()
    fog(1412, { { 100, 100, 0, 0, 7 }, { 100, 100, 100, 0, 8 } })
    WOW.state.explored[1412] = { { textureWidth = 100, textureHeight = 100, offsetX = 0, offsetY = 0, fileDataIDs = { 7 } } }
    local pin = WOW.NewMapPin(1412)
    NewbieNudge.MapReveal:HookPins()
    pin:RefreshOverlays(true)
    local ts = activeTextures(pin)
    assert_eq(#ts, 1); assert_eq(ts[1].texture, 8)
    assert_eq(ts[1].vertexColor, { 0.6, 0.6, 0.6, 1 }); assert_eq(ts[1].desaturated, true); assert_eq(ts[1].subLevel, -1)
  end,
  option_off_draws_nothing = function()
    load_addon(); fog(1412, { { 100, 100, 0, 0, 7 } }); WOW.state.explored[1412] = {}
    NewbieNudge.db.map.reveal = false
    local pin = WOW.NewMapPin(1412); NewbieNudge.MapReveal:HookPins(); pin:RefreshOverlays()
    assert_eq(#activeTextures(pin), 0)
  end,
  secret_or_missing_explored_data_draws_nothing = function()
    load_addon(); fog(1412, { { 100, 100, 0, 0, 7 } })
    WOW.state.explored[1412] = { { textureWidth = WOW.secret(100), textureHeight = 100, offsetX = 0, offsetY = 0 } }
    local pin = WOW.NewMapPin(1412); NewbieNudge.MapReveal:HookPins(); pin:RefreshOverlays()
    assert_eq(#activeTextures(pin), 0)
    WOW.state.explored[1412] = nil; pin:RefreshOverlays()
    assert_eq(#activeTextures(pin), 0)
  end,
  unknown_map_draws_nothing = function()
    load_addon(); WOW.state.explored[999] = {}
    local pin = WOW.NewMapPin(999); NewbieNudge.MapReveal:HookPins(); pin:RefreshOverlays()
    assert_eq(#activeTextures(pin), 0)
  end,
  pool_released_each_refresh = function()
    load_addon(); fog(1412, { { 100, 100, 0, 0, 7 }, { 100, 100, 100, 0, 8 } }); WOW.state.explored[1412] = {}
    local pin = WOW.NewMapPin(1412); NewbieNudge.MapReveal:HookPins()
    for _ = 1, 3 do pin:RefreshOverlays() end
    assert_eq(NewbieNudge.MapReveal.pools[pin]:GetNumActive(), 2)
  end,
  layer_fallback_to_first = function()
    load_addon(); fog(1412, { { 100, 100, 0, 0, 7, 8, 9, 10 } }); WOW.state.explored[1412] = {}
    WOW.state.mapLayers[1412] = { { tileWidth = 64, tileHeight = 64 } }
    local pin = WOW.NewMapPin(1412); pin.layerIndex = 3
    NewbieNudge.MapReveal:HookPins(); pin:RefreshOverlays()
    assert_eq(#activeTextures(pin), 4) -- 100x100 on 64px tiles = 2x2
  end,
  brightness_option_and_refresh = function()
    load_addon(); fog(1412, { { 100, 100, 0, 0, 7 } }); WOW.state.explored[1412] = {}
    local pin = WOW.NewMapPin(1412); NewbieNudge.MapReveal:HookPins(); WorldMapFrame:Show()
    WOW.settings["NN_map_brightness"].setter(40)
    assert_eq(NewbieNudge.db.map.brightness, 0.4)
    assert_eq(activeTextures(pin)[1].vertexColor, { 0.4, 0.4, 0.4, 1 })
  end,
  slash_map_toggles_option = function()
    load_addon()
    NewbieNudge:HandleSlash("map")
    assert_eq(NewbieNudge.db.map.reveal, false)
    assert_true(WOW.printed[#WOW.printed]:find(NewbieNudge.L.SLASH_MAP_OFF, 1, true))
  end,
  pins_found_on_first_map_show = function()
    load_addon() -- no pin yet at login
    NewbieNudge.MapReveal:HookPins()
    fog(1412, { { 100, 100, 0, 0, 7 } }); WOW.state.explored[1412] = {}
    local pin = WOW.NewMapPin(1412)
    WorldMapFrame:Show()
    pin:RefreshOverlays()
    assert_eq(#activeTextures(pin), 1)
  end,
}
