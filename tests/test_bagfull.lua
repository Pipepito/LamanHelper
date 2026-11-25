-- BagFull: the "cheapest to destroy" frame shown when the bags are full.
local L = function() return NewbieNudge.L end
local function item(id, f)
  local t = { name = f.name or ("I" .. id), quality = f.quality or 1, sellPrice = f.price or 10, classID = f.class or 0,
              equipLoc = f.equip or "", family = f.family or 0, stackCount = 20 }
  WOW.state.itemInfo[id] = t
  return t
end
local function put(slot, id, extra)
  local it = { itemID = id }
  for k, v in pairs(extra or {}) do it[k] = v end
  WOW.state.bags[0].items[slot] = it
  return it
end
local function names()
  local out = {}
  for _, c in ipairs(NewbieNudge.BagFull:Candidates()) do out[#out + 1] = c.name end
  return out
end

return {
  order_grey_first_then_value = function()
    item(1, { name = "Grey", quality = 0, price = 500 }); item(2, { name = "Cheap", price = 1 }); item(3, { name = "Dear", price = 100 })
    put(1, 3); put(2, 2); put(3, 1)
    load_addon(); load_bags()
    assert_eq(names(), { "Grey", "Cheap", "Dear" })
  end,
  exclusions = function()
    item(1, { name = "Quest", class = 12 }); item(2, { name = "Starter" }); item(3, { name = "Bag", class = 1 }); item(4, { name = "Hearth" })
    item(5, { name = "Locked" }); item(6, { name = "Blue", quality = 3 }); item(7, { name = "Arrow", class = 6 }); item(8, { name = "Pick", equip = "INVTYPE_WEAPON" })
    item(9, { name = "GreySword", quality = 0, equip = "INVTYPE_WEAPON" }); item(10, { name = "Water", price = 0 }); item(11, { name = "GreyNoValue", quality = 0, price = 0 })
    item(12, { name = "Objective" }); item(13, { name = "Fine" })
    put(1, 1); put(2, 2, { questID = 5, isActive = false }); put(3, 3); put(4, 6948); WOW.state.itemInfo[6948] = { name = "Hearthstone" }
    put(5, 5, { locked = true }); put(6, 6); put(7, 7); put(8, 8); put(9, 9); put(10, 10); put(11, 11); put(12, 12); put(13, 13)
    WOW.state.bags[1] = { numSlots = 6, family = 4, items = { [1] = { itemID = 13 } } } -- soul bag contents skipped
    WOW.Quest({ questID = 1, title = "A", level = 20, objectives = { { type = "item", text = "Objective: 0/5", numFulfilled = 0, numRequired = 5 } } })
    load_addon(); load_bags()
    assert_eq(names(), { "GreyNoValue", "GreySword", "Fine" })
  end,
  shows_on_inventory_full_error_and_hides_when_slot_frees = function()
    item(1, { name = "Junk" }); WOW.state.bags[0].numSlots = 1; put(1, 1)
    load_addon(); load_bags()
    WOW.FireEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL)
    assert_true(NewbieNudgeBagFull:IsShown())
    assert_true(NewbieNudge.BagFull.rows[1].name:GetText():find("Junk", 1, true) ~= nil)
    WOW.state.bags[0].items[1] = nil; WOW.FireEvent("BAG_UPDATE_DELAYED")
    assert_true(not NewbieNudgeBagFull:IsShown())
  end,
  stays_while_loot_open_then_hides_on_close = function()
    item(1, { name = "Junk" }); WOW.state.bags[0].numSlots = 1; put(1, 1)
    load_addon(); load_bags(); LootFrame:Show()
    WOW.FireEvent("LOOT_OPENED", false)
    assert_true(NewbieNudgeBagFull:IsShown())
    WOW.state.bags[0].items[1] = nil; WOW.FireEvent("BAG_UPDATE_DELAYED")
    assert_true(NewbieNudgeBagFull:IsShown(), "still looting")
    LootFrame:Hide(); WOW.FireEvent("LOOT_CLOSED")
    assert_true(not NewbieNudgeBagFull:IsShown())
  end,
  not_shown_while_the_bank_is_open = function()
    item(1, { name = "Junk" }); WOW.state.bags[0].numSlots = 1; put(1, 1)
    load_addon(); load_bags(); WOW.OpenBank()
    WOW.FireEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL)
    assert_true(not NewbieNudgeBagFull:IsShown(), "the bank is where you make room, not the destroy list")
    LootFrame:Show(); WOW.FireEvent("LOOT_OPENED", false)
    assert_true(not NewbieNudgeBagFull:IsShown())
  end,
  opening_the_bank_hides_an_automatic_window_but_not_a_manual_one = function()
    item(1, { name = "Junk" }); WOW.state.bags[0].numSlots = 1; put(1, 1)
    load_addon(); load_bags()
    WOW.FireEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL)
    assert_true(NewbieNudgeBagFull:IsShown())
    WOW.OpenBank()
    assert_true(not NewbieNudgeBagFull:IsShown())
    NewbieNudge.BagFull:Show("manual")
    assert_true(NewbieNudgeBagFull:IsShown(), "/nudge trash at the bank is deliberate")
  end,
  loot_trigger_respects_option = function()
    item(1, { name = "Junk" }); WOW.state.bags[0].numSlots = 1; put(1, 1)
    load_addon(); load_bags(); NewbieNudge.db.bagfull.onLoot = false; LootFrame:Show()
    WOW.FireEvent("LOOT_OPENED", false)
    assert_true(not NewbieNudgeBagFull:IsShown())
  end,
  destroy_grey_one_click_and_green_asks_sure = function()
    item(1, { name = "Grey", quality = 0 }); item(2, { name = "Green", quality = 2 }); put(1, 1); put(2, 2)
    load_addon(); load_bags(); NewbieNudge.BagFull:Show("manual")
    local rows = NewbieNudge.BagFull.rows
    WOW.Click(rows[1].button)
    assert_eq(WOW.calls[#WOW.calls], { "DeleteCursorItem", 0, 1 })
    WOW.FireEvent("BAG_UPDATE_DELAYED")
    assert_eq(rows[1].data.name, "Green")
    WOW.Click(rows[1].button)
    assert_eq(rows[1].button:GetText(), L().BAGFULL_SURE); assert_true(WOW.state.bags[0].items[2] ~= nil)
    WOW.Click(rows[1].button)
    assert_true(WOW.state.bags[0].items[2] == nil)
  end,
  sure_expires_after_three_seconds = function()
    item(2, { name = "Green", quality = 2 }); put(1, 2)
    load_addon(); load_bags(); NewbieNudge.BagFull:Show("manual")
    WOW.Click(NewbieNudge.BagFull.rows[1].button); WOW.AdvanceTime(3.1)
    assert_eq(NewbieNudge.BagFull.rows[1].button:GetText(), L().BAGFULL_DESTROY)
  end,
  mismatch_refreshes_instead_of_destroying = function()
    item(1, { name = "Grey", quality = 0 }); item(3, { name = "Other", quality = 0 }); put(1, 1)
    load_addon(); load_bags(); NewbieNudge.BagFull:Show("manual")
    WOW.state.bags[0].items[1] = { itemID = 3 }
    WOW.Click(NewbieNudge.BagFull.rows[1].button)
    assert_true(WOW.state.bags[0].items[1] ~= nil); assert_eq(NewbieNudge.BagFull.rows[1].data.name, "Other")
  end,
  manual_open_ignores_auto_hide = function()
    item(1, { name = "Junk" }); put(1, 1)
    load_addon(); load_bags(); NewbieNudge:HandleSlash("trash")
    assert_true(NewbieNudgeBagFull:IsShown())
    WOW.FireEvent("BAG_UPDATE_DELAYED"); WOW.AdvanceTime(100)
    assert_true(NewbieNudgeBagFull:IsShown())
    NewbieNudge.BagFull:Hide(); assert_true(not NewbieNudgeBagFull:IsShown())
  end,
  auto_hides_after_ninety_seconds = function()
    item(1, { name = "Junk" }); WOW.state.bags[0].numSlots = 1; put(1, 1)
    load_addon(); load_bags(); WOW.FireEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL)
    WOW.AdvanceTime(91); assert_true(not NewbieNudgeBagFull:IsShown())
  end,
  uncached_item_skipped_then_refreshed = function()
    item(1, { name = "Junk" }); WOW.state.itemInfo[2] = { uncached = true }; put(1, 1); put(2, 2)
    load_addon(); load_bags(); NewbieNudge.BagFull:Show("manual")
    assert_eq(#NewbieNudge.BagFull:Candidates(), 1)
    WOW.state.itemInfo[2] = { name = "Late", quality = 0, sellPrice = 1 }
    WOW.FireEvent("GET_ITEM_INFO_RECEIVED", 2, true)
    assert_eq(NewbieNudge.BagFull.rows[1].data.name, "Late")
  end,
  secret_price_skips_stack = function()
    item(1, { name = "Junk" }); WOW.state.itemInfo[1].sellPrice = WOW.secret(5); put(1, 1)
    load_addon(); load_bags(); assert_eq(#NewbieNudge.BagFull:Candidates(), 0)
  end,
  disabled_option_never_shows = function()
    item(1, { name = "Junk" }); WOW.state.bags[0].numSlots = 1; put(1, 1)
    load_addon(); load_bags(); NewbieNudge.db.bagfull.enabled = false
    WOW.FireEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL); assert_true(not NewbieNudgeBagFull:IsShown())
  end,
  max_quality_option = function()
    item(1, { name = "White" }); item(2, { name = "Green", quality = 2 }); put(1, 1); put(2, 2)
    load_addon(); load_bags(); NewbieNudge.db.bagfull.maxQuality = 1
    assert_eq(names(), { "White" })
  end,
  options_page_registered = function()
    load_addon()
    local found = false
    for _, c in ipairs(WOW.calls) do if c[1] == "page" and c[2] == L().OPT_BAGS then found = true end end
    assert_true(found)
    assert_true(WOW.settings["NN_bagfull_enabled"] and WOW.settings["NN_bagfull_quality"] and WOW.settings["NN_bagfull_onLoot"])
    WOW.settings["NN_bagfull_quality"].setter("0"); assert_eq(NewbieNudge.db.bagfull.maxQuality, 0)
  end,
  -- review fix 2: the frame follows the controller scale boost
  frame_uses_controller_scale_boost = function()
    item(1, { name = "Junk" }); put(1, 1)
    load_addon(); load_bags(); NewbieNudge.BagFull:Show("manual")
    assert_eq(NewbieNudgeBagFull:GetScale(), 1)
    WOW.FireEvent("GAME_PAD_ACTIVE_CHANGED", true)
    assert_eq(NewbieNudgeBagFull:GetScale(), 1.25)
    WOW.settings["NN_controller_boost"].setter(false)
    assert_eq(NewbieNudgeBagFull:GetScale(), 1)
  end,
  -- review fix 3: item-info events only reach the addon while the frame is shown
  item_info_event_only_while_shown = function()
    item(1, { name = "Junk" }); put(1, 1)
    load_addon(); load_bags()
    assert_true(not NewbieNudge.events:IsEventRegistered("GET_ITEM_INFO_RECEIVED"), "core frame must not drive the scheduler on item info")
    assert_true(not NewbieNudge.BagFull.events:IsEventRegistered("GET_ITEM_INFO_RECEIVED"))
    NewbieNudge.BagFull:Show("manual")
    assert_true(NewbieNudge.BagFull.events:IsEventRegistered("GET_ITEM_INFO_RECEIVED"))
    NewbieNudge.BagFull:Hide()
    assert_true(not NewbieNudge.BagFull.events:IsEventRegistered("GET_ITEM_INFO_RECEIVED"))
  end,
}
