-- Tooltips: the sell price on item tooltips when no vendor is open.
local L = function() return NewbieNudge.L end
local function lines() return table.concat(GameTooltip.lines, "\n") end

return {
  adds_sell_price_line_outside_vendor = function()
    WOW.state.itemInfo[1] = { name = "Linen Cloth", sellPrice = 150, link = "item:1" }
    load_addon(); WOW.ShowItemTooltip("item:1")
    assert_true(lines():find("150c", 1, true), lines())
    assert_true(lines():find(SELL_PRICE, 1, true), lines())
  end,
  no_line_at_vendor = function()
    WOW.state.itemInfo[1] = { name = "Linen Cloth", sellPrice = 150, link = "item:1" }
    load_addon(); MerchantFrame:Show(); WOW.ShowItemTooltip("item:1")
    assert_true(not lines():find("150c", 1, true), lines())
  end,
  no_line_for_zero_price = function()
    WOW.state.itemInfo[1] = { name = "Soul Shard", sellPrice = 0, link = "item:1" }
    load_addon(); WOW.ShowItemTooltip("item:1")
    assert_true(not lines():find(SELL_PRICE, 1, true), lines())
  end,
  option_off_no_line = function()
    WOW.state.itemInfo[1] = { name = "Linen Cloth", sellPrice = 150, link = "item:1" }
    load_addon(); NewbieNudge.db.tooltipPrice = false; WOW.ShowItemTooltip("item:1")
    assert_true(not lines():find("150c", 1, true), lines())
    assert_true(WOW.settings["NN_tooltipPrice"], "option registered")
  end,
  game_settings_has_combined_bags = function()
    WOW.state.cvars = { combinedBags = { default = "0" } }
    load_addon()
    local found = false
    for _, c in ipairs(WOW.calls) do if c[1] == "checkbox" and c[2] == "NN_cvar_combinedBags" then found = true end end
    assert_true(found)
    assert_nil(NewbieNudge.GameSettings.PRESET.combinedBags, "the preset leaves it alone")
  end,
  uses_data_id_when_the_tooltip_has_no_getitem = function()
    WOW.state.itemInfo[1] = { name = "Linen Cloth", sellPrice = 150, link = "item:1" }
    load_addon()
    local getItem = GameTooltip.GetItem; GameTooltip.GetItem = nil
    WOW.ShowItemTooltip("item:1")
    GameTooltip.GetItem = getItem
    assert_true(lines():find("150c", 1, true), lines())
  end,
}
