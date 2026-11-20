-- Vendor automation: sell grey items and repair when a merchant opens.
local L = function() return NewbieNudge.L end
local function item(id, f) WOW.state.itemInfo[id] = { name = f.name or ("I" .. id), quality = f.quality or 1, sellPrice = f.price or 10 } end
local function put(slot, id, extra) local it = { itemID = id }; for k, v in pairs(extra or {}) do it[k] = v end; WOW.state.bags[0].items[slot] = it end
local function sold() local n = 0 for _, c in ipairs(WOW.calls) do if c[1] == "UseContainerItem" then n = n + 1 end end return n end
local function repaired() for _, c in ipairs(WOW.calls) do if c[1] == "RepairAllItems" then return true end end return false end

return {
  sells_grey_stacks_and_says_total = function()
    item(1, { name = "Grey", quality = 0, price = 7 }); item(2, { name = "White", quality = 1, price = 100 }); item(3, { name = "Grey2", quality = 0, price = 3 })
    put(1, 1, { count = 2 }); put(2, 2); put(3, 3)
    load_addon(); load_bags()
    WOW.OpenMerchant(); WOW.AdvanceTime(1)
    assert_eq(sold(), 2); assert_true(WOW.state.bags[0].items[2] ~= nil, "white kept")
    assert_eq(WOW.state.money, 10000 + 14 + 3)
    local text = WOW.printed[#WOW.printed]
    assert_true(text:find(L().VENDOR_SOLD:format(2, "17c"), 1, true), text)
  end,
  stale_slot_is_skipped = function()
    item(1, { quality = 0 }); put(1, 1)
    load_addon(); load_bags()
    WOW.state.bags[0].items[1] = nil -- gone before the first tick
    WOW.OpenMerchant(); WOW.AdvanceTime(1)
    assert_eq(sold(), 0)
  end,
  locked_stack_not_sold = function()
    item(1, { quality = 0 }); put(1, 1, { locked = true })
    load_addon(); load_bags(); WOW.OpenMerchant(); WOW.AdvanceTime(1)
    assert_eq(sold(), 0)
  end,
  stops_when_merchant_closes = function()
    WOW.state.bags[0].numSlots = 30
    item(1, { quality = 0 })
    for i = 1, 25 do put(i, 1) end
    load_addon(); load_bags(); WOW.OpenMerchant()
    WOW.CloseMerchant(); WOW.AdvanceTime(2)
    assert_eq(sold(), 10, "exactly the first tick's worth")
  end,
  repairs_when_affordable = function()
    WOW.state.canRepair = true; WOW.state.repairCost = 500
    load_addon(); load_bags(); WOW.OpenMerchant(); WOW.AdvanceTime(1)
    assert_true(repaired()); assert_eq(WOW.state.money, 9500)
    assert_true(WOW.printed[#WOW.printed]:find(L().VENDOR_REPAIRED:format("500c"), 1, true))
  end,
  cannot_afford_repair_says_so = function()
    WOW.state.canRepair = true; WOW.state.repairCost = 50000
    load_addon(); load_bags(); WOW.OpenMerchant(); WOW.AdvanceTime(1)
    assert_true(not repaired())
    assert_true(WOW.printed[#WOW.printed]:find(L().VENDOR_REPAIR_POOR:format("50000c", "10000c"), 1, true))
  end,
  options_toggle_both_off = function()
    item(1, { quality = 0 }); put(1, 1); WOW.state.canRepair = true; WOW.state.repairCost = 500
    load_addon(); load_bags(); NewbieNudge.db.vendor.sellJunk = false; NewbieNudge.db.vendor.repair = false
    WOW.OpenMerchant(); WOW.AdvanceTime(1)
    assert_eq(sold(), 0); assert_true(not repaired())
    assert_true(WOW.settings["NN_vendor_sellJunk"] and WOW.settings["NN_vendor_repair"])
  end,
  repair_waits_for_sale_proceeds = function()
    WOW.state.money = 400; WOW.state.canRepair = true; WOW.state.repairCost = 500
    item(1, { quality = 0, price = 100 }); put(1, 1, { count = 2 })
    load_addon(); load_bags(); WOW.OpenMerchant(); WOW.AdvanceTime(1)
    assert_true(repaired(), "200c of junk sold first makes the 500c repair affordable")
    assert_eq(WOW.state.money, 100)
  end,
  repair_runs_at_once_when_nothing_to_sell = function()
    WOW.state.canRepair = true; WOW.state.repairCost = 500
    load_addon(); load_bags(); WOW.OpenMerchant()
    assert_true(repaired(), "no ticker needed")
  end,
  unsellable_grey_not_counted = function()
    item(1, { quality = 0, price = 0 }); put(1, 1); item(2, { quality = 0, price = 5 }); put(2, 2)
    load_addon(); load_bags(); WOW.OpenMerchant(); WOW.AdvanceTime(1)
    assert_true(WOW.printed[#WOW.printed]:find(L().VENDOR_SOLD:format(1, "5c"), 1, true), WOW.printed[#WOW.printed])
  end,
}
