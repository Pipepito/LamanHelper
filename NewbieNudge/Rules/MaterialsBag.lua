-- Rule: materials_bag — Forever's separate materials (reagent) bag slot.
-- bag_unequipped ignores it (family-0 containers in bags 1-4 only); this rule
-- tracks it on its own.
--
-- The two constants below identify a materials bag item. They are confirmed
-- in game (docs/testing-checklist.md §0: /dump C_Item.GetItemFamily(id) and
-- select(7, C_Item.GetItemInfoInstant(id)) on a materials bag). While both
-- are nil the rule does not apply, so it can never misfire.
local _, NN = ...
local L = NN.L

NN.REAGENT_BAG_FAMILY = NN.REAGENT_BAG_FAMILY or nil    -- item family bitmask of a materials bag
NN.REAGENT_BAG_SUBCLASS = NN.REAGENT_BAG_SUBCLASS or nil -- container subclass of a materials bag

local BAG_ICON = 133634
local CONTAINER_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Container) or 1

local function reagentBagIndex()
  return Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
end

function NN.IsReagentBag(itemID)
  if not (NN.REAGENT_BAG_FAMILY or NN.REAGENT_BAG_SUBCLASS) then return false end
  local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
  if NN.Plain(classID) ~= CONTAINER_CLASS then return false end
  if NN.REAGENT_BAG_FAMILY then
    local family = NN.Plain(C_Item.GetItemFamily(itemID)) or 0
    if family == NN.REAGENT_BAG_FAMILY then return true end
  end
  if NN.REAGENT_BAG_SUBCLASS and NN.Plain(subclassID) == NN.REAGENT_BAG_SUBCLASS then return true end
  return false
end

NN:RegisterRule({
  name = "materials_bag",
  title = L.MATERIALS_BAG_TITLE,
  help = L.MATERIALS_BAG_HELP,
  events = { "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" },
  combat = true,
  applies = function()
    if not (NN.REAGENT_BAG_FAMILY or NN.REAGENT_BAG_SUBCLASS) then return false end
    local index = reagentBagIndex()
    return index ~= nil and NN.BagInventorySlot(index) ~= nil
  end,
  check = function()
    if not NN.bagsLoaded then return nil end
    local index = reagentBagIndex()
    local slot = NN.BagInventorySlot(index)
    local equippedID = GetInventoryItemID("player", slot)
    local equippedSlots = equippedID and (NN.Plain(C_Container.GetContainerNumSlots(index)) or 0) or nil
    for bag = 0, 4 do
      for s = 1, NN.Plain(C_Container.GetContainerNumSlots(bag)) or 0 do
        local info = C_Container.GetContainerItemInfo(bag, s)
        local itemID = info and NN.Plain(info.itemID)
        if itemID and NN.IsReagentBag(itemID) then
          if equippedID == nil then
            return { text = L.MATERIALS_BAG_ROW_EMPTY, icon = BAG_ICON, onClick = ToggleAllBags, highlight = "bags" }
          end
          local slots = NN.ContainerSlots(bag, s)
          if slots and equippedSlots and slots > equippedSlots then
            return { text = L.MATERIALS_BAG_ROW_BIGGER, icon = BAG_ICON, onClick = ToggleAllBags, highlight = "bags" }
          end
        end
      end
    end
    return nil
  end,
  sample = function() return { { text = L.MATERIALS_BAG_ROW_EMPTY, icon = BAG_ICON } } end,
})
