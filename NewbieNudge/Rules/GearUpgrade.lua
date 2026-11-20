-- Rule: gear_upgrade — an armor piece in the bags with a clearly higher item
-- level than what is equipped in that slot. Off by default: item level is a
-- rough proxy, stat weights are ignored and weapons are not covered.
local _, NN = ...
local L = NN.L

local MAX_ROWS = 3
local MIN_GAIN = 5
local FALLBACK_ICON = 134400
local ARMOR_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Armor) or 4
local SUB = (Enum and Enum.ItemArmorSubclass) or { Generic = 0, Cloth = 1, Leather = 2, Mail = 3, Plate = 4 }

local SLOT_FOR_EQUIPLOC = {
  INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
  INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
  INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
}

local ARMOR_FOR_CLASS = {
  MAGE = { SUB.Cloth }, PRIEST = { SUB.Cloth }, WARLOCK = { SUB.Cloth },
  DRUID = { SUB.Cloth, SUB.Leather }, ROGUE = { SUB.Cloth, SUB.Leather },
  HUNTER = { SUB.Cloth, SUB.Leather, SUB.Mail }, SHAMAN = { SUB.Cloth, SUB.Leather, SUB.Mail },
  WARRIOR = { SUB.Cloth, SUB.Leather, SUB.Mail, SUB.Plate }, PALADIN = { SUB.Cloth, SUB.Leather, SUB.Mail, SUB.Plate },
}

local function canWear(subclassID)
  if subclassID == SUB.Generic then return true end -- necks, rings, trinkets, cloaks
  for _, allowed in ipairs(ARMOR_FOR_CLASS[NN.classFile] or { SUB.Cloth }) do
    if allowed == subclassID then return true end
  end
  return false
end

local function equippedLevel(slots)
  local lowest
  for _, slot in ipairs(slots) do
    local link = GetInventoryItemLink("player", slot)
    local level = 0
    if link then level = NN.Plain(C_Item.GetDetailedItemLevelInfo(link)) or 0 end
    if not lowest or level < lowest then lowest = level end
  end
  return lowest or 0
end

local function upgradeIn(bag, slot)
  local info = C_Container.GetContainerItemInfo(bag, slot)
  local itemID = info and NN.Plain(info.itemID)
  if not itemID then return nil end
  local _, _, _, equipLoc, icon, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
  if NN.Plain(classID) ~= ARMOR_CLASS then return nil end
  local slots = SLOT_FOR_EQUIPLOC[equipLoc]
  if not slots or not canWear(NN.Plain(subclassID)) then return nil end
  local link = info.hyperlink
  local _, fullLink, _, itemLevel, reqLevel = C_Item.GetItemInfo(link or itemID)
  itemLevel, reqLevel = NN.Plain(itemLevel), NN.Plain(reqLevel)
  if not itemLevel then return nil end -- data not cached yet
  if (reqLevel or 0) > (NN.Plain(UnitLevel("player")) or 0) then return nil end
  local current = equippedLevel(slots)
  if current == 0 or itemLevel >= current + MIN_GAIN then
    return { text = L.GEAR_UPGRADE_ROW:format(fullLink or link or ("item:" .. itemID)), icon = icon or FALLBACK_ICON,
             onClick = ToggleAllBags, highlight = "bags" }
  end
  return nil
end

NN:RegisterRule({
  name = "gear_upgrade",
  title = L.GEAR_UPGRADE_TITLE,
  help = L.GEAR_UPGRADE_HELP,
  events = { "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" },
  default = false,
  applies = function() return true end,
  check = function()
    if not NN.bagsLoaded then return nil end
    local results = {}
    for bag = 0, 4 do
      for slot = 1, NN.Plain(C_Container.GetContainerNumSlots(bag)) or 0 do
        local result = upgradeIn(bag, slot)
        if result then results[#results + 1] = result end
      end
    end
    if #results > MAX_ROWS then
      local extra = #results - MAX_ROWS
      for i = #results, MAX_ROWS + 1, -1 do results[i] = nil end
      results[MAX_ROWS + 1] = { text = L.MORE_ROWS:format(extra), icon = FALLBACK_ICON, onClick = ToggleAllBags, highlight = "bags" }
    end
    if #results == 0 then return nil end
    return results
  end,
  sample = function() return { { text = L.GEAR_UPGRADE_ROW:format("[Tough Jerkin]"), icon = 132724 } } end,
})
