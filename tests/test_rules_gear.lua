local L = function() return NewbieNudge.L end
local ARMOR, CLOTH, LEATHER, PLATE, MISC = 4, 1, 2, 4, 0

local nextID = 5000
local function item(over)
  nextID = nextID + 1
  local id = nextID
  local info = { name = "Item" .. id, link = "item:" .. id, classID = ARMOR, subclassID = CLOTH,
                 equipLoc = "INVTYPE_CHEST", itemLevel = 10, reqLevel = 1 }
  for k, v in pairs(over or {}) do info[k] = v end
  WOW.state.itemInfo[id] = info
  return id
end

local function equip(slot, id) WOW.state.inventory[slot] = { itemID = id } end
local function inBag(slot, id) WOW.state.bags[0].items[slot] = { itemID = id } end

local function enabledLoad()
  _G.NewbieNudgeDB = { seen = { rules = { gear_upgrade = true } } } -- already seen: stays enabled
  load_addon(); load_bags(); run_checks()
end

return {
  disabled_by_default = function()
    equip(5, item({ itemLevel = 10 })); inBag(1, item({ itemLevel = 30 }))
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("gear_upgrade"), 0)
    assert_eq(NewbieNudge.db.disabled.gear_upgrade, true)
    NewbieNudge:HandleSlash("on gear_upgrade"); run_checks()
    assert_eq(#results_of("gear_upgrade"), 1)
  end,
  cloth_chest_five_ilvl_higher_is_upgrade = function()
    equip(5, item({ itemLevel = 10 })); local up = item({ itemLevel = 15 }); inBag(1, up)
    enabledLoad()
    local r = results_of("gear_upgrade")
    assert_eq(r[1].text, L().GEAR_UPGRADE_ROW:format("item:" .. up))
    assert_eq(r[1].highlight, "bags")
    r[1].onClick()
    assert_eq(WOW.calls[#WOW.calls][1], "ToggleAllBags")
  end,
  four_ilvl_higher_is_not = function()
    equip(5, item({ itemLevel = 10 })); inBag(1, item({ itemLevel = 14 }))
    enabledLoad()
    assert_eq(#results_of("gear_upgrade"), 0)
  end,
  empty_slot_counts_as_upgrade = function()
    inBag(1, item({ itemLevel = 5, equipLoc = "INVTYPE_HEAD" }))
    enabledLoad()
    assert_eq(#results_of("gear_upgrade"), 1)
  end,
  plate_ignored_for_mage = function()
    inBag(1, item({ itemLevel = 50, subclassID = PLATE }))
    enabledLoad()
    assert_eq(#results_of("gear_upgrade"), 0)
  end,
  leather_allowed_for_rogue = function()
    WOW.state.class = "ROGUE"
    inBag(1, item({ itemLevel = 50, subclassID = LEATHER }))
    enabledLoad()
    assert_eq(#results_of("gear_upgrade"), 1)
  end,
  ring_compares_to_lower_of_two = function()
    equip(11, item({ itemLevel = 30, equipLoc = "INVTYPE_FINGER", subclassID = MISC }))
    equip(12, item({ itemLevel = 10, equipLoc = "INVTYPE_FINGER", subclassID = MISC }))
    inBag(1, item({ itemLevel = 20, equipLoc = "INVTYPE_FINGER", subclassID = MISC }))
    enabledLoad()
    assert_eq(#results_of("gear_upgrade"), 1)
  end,
  too_high_required_level_ignored = function()
    inBag(1, item({ itemLevel = 50, reqLevel = 40 }))
    enabledLoad()
    assert_eq(#results_of("gear_upgrade"), 0)
  end,
  weapons_ignored = function()
    inBag(1, item({ itemLevel = 50, classID = 2, subclassID = 7, equipLoc = "INVTYPE_WEAPON" }))
    enabledLoad()
    assert_eq(#results_of("gear_upgrade"), 0)
  end,
  uncached_item_skipped = function()
    inBag(1, item({ itemLevel = 50, uncached = true }))
    enabledLoad()
    assert_eq(#results_of("gear_upgrade"), 0)
  end,
  more_than_three_collapses = function()
    for i = 1, 5 do inBag(i, item({ itemLevel = 20 + i })) end
    enabledLoad()
    local r = results_of("gear_upgrade")
    assert_eq(#r, 4)
    assert_eq(r[4].text, L().MORE_ROWS:format(2))
  end,
}
