-- Rules: bag_unequipped (a bag sitting in your inventory that should be
-- equipped) and bag_full (fewer than 3 free regular slots).
local _, NN = ...
local L = NN.L

local BAG_ICON = 133634
local FIRST_BAG, LAST_BAG = 1, 4
local CONTAINER_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Container) or 1
local REGULAR_FAMILY = 0

local function usesAmmo()
  return UnitUsesAmmo ~= nil and UnitUsesAmmo("player") == true
end

-- Pattern that pulls the slot count out of a bag item's tooltip line,
-- derived from the client's own CONTAINER_SLOTS format so it follows the
-- client language ("%d|4Slot:Slots; %s" -> "(%d+) ").
local slotPattern
local function containerSlotPattern()
  if slotPattern then return slotPattern end
  local fmt = CONTAINER_SLOTS or "%d|4Slot:Slots; %s"
  local head = fmt:match("^(.-)|4") or fmt
  head = head:gsub("%%d", "\1"):gsub("%p", "%%%0"):gsub("\1", "(%%d+)")
  slotPattern = "^" .. head
  return slotPattern
end

-- Number of slots a container item in (bag, slot) has, read from its tooltip.
local function containerSlots(bag, slot)
  if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return nil end
  local data = C_TooltipInfo.GetBagItem(bag, slot)
  if not data or not data.lines then return nil end
  local pattern = containerSlotPattern()
  for _, line in ipairs(data.lines) do
    local text = NN.Plain(line.leftText, "string")
    local n = text and text:match(pattern)
    if n then return tonumber(n) end
  end
  return nil
end

local function isEligibleContainer(itemID)
  local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
  if NN.Plain(classID) ~= CONTAINER_CLASS then return false end
  local family = NN.Plain(C_Item.GetItemFamily(itemID)) or 0
  if family == REGULAR_FAMILY then return true end
  return usesAmmo()
end

-- Inventory slot that holds the given bag; the client decides the numbering.
local function bagInventorySlot(bag)
  local f = (C_Container and C_Container.ContainerIDToInventoryID) or ContainerIDToInventoryID
  local slot = f and NN.Plain(f(bag))
  return slot or (19 + bag)
end

NN.ContainerSlots = containerSlots
NN.BagInventorySlot = bagInventorySlot

local function hasEmptyBagSlot()
  for bag = FIRST_BAG, LAST_BAG do
    if GetInventoryItemID("player", bagInventorySlot(bag)) == nil then return true end
  end
  return false
end

local function smallestEquippedBag()
  local smallest
  for bag = 1, 4 do
    local n = NN.Plain(C_Container.GetContainerNumSlots(bag)) or 0
    if n > 0 and (not smallest or n < smallest) then smallest = n end
  end
  return smallest
end

NN:RegisterRule({
  name = "bag_unequipped",
  title = L.BAG_UNEQUIPPED_TITLE,
  help = L.BAG_UNEQUIPPED_HELP,
  events = { "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" },
  combat = true,
  applies = function() return true end,
  check = function()
    if not NN.bagsLoaded then return nil end
    local emptySlot = hasEmptyBagSlot()
    local smallest = smallestEquippedBag()
    for bag = 0, 4 do
      local numSlots = NN.Plain(C_Container.GetContainerNumSlots(bag)) or 0
      for slot = 1, numSlots do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        local itemID = info and NN.Plain(info.itemID)
        if itemID and isEligibleContainer(itemID) then
          if emptySlot then
            return { text = L.BAG_UNEQUIPPED_ROW_EMPTY, icon = BAG_ICON, onClick = ToggleAllBags, highlight = "bags" }
          end
          local slots = containerSlots(bag, slot)
          if slots and smallest and slots > smallest then
            return { text = L.BAG_UNEQUIPPED_ROW_BIGGER, icon = BAG_ICON, onClick = ToggleAllBags, highlight = "bags" }
          end
        end
      end
    end
    return nil
  end,
  sample = function() return { { text = L.BAG_UNEQUIPPED_ROW_EMPTY, icon = BAG_ICON } } end,
})

-- Free slots across the regular bags (0-4, family 0), or NN.UNKNOWN.
function NN.RegularFreeSlots()
  local free = 0
  for bag = 0, 4 do
    local n, family = C_Container.GetContainerNumFreeSlots(bag)
    n, family = NN.Plain(n), NN.Plain(family)
    if n == nil then return NN.UNKNOWN end
    if (family or 0) == REGULAR_FAMILY then free = free + n end
  end
  return free
end

NN:RegisterRule({
  name = "bag_full",
  title = L.BAG_FULL_TITLE,
  help = L.BAG_FULL_HELP,
  events = { "BAG_UPDATE_DELAYED" },
  combat = true,
  applies = function() return true end,
  check = function()
    if not NN.bagsLoaded then return nil end
    local free = NN.RegularFreeSlots()
    if free == NN.UNKNOWN then return NN.UNKNOWN end
    if free < 3 then
      return { text = L.BAG_FULL_ROW:format(free), icon = BAG_ICON, onClick = ToggleAllBags, highlight = "bags" }
    end
    return nil
  end,
  sample = function() return { { text = L.BAG_FULL_ROW:format(1), icon = BAG_ICON } } end,
})
