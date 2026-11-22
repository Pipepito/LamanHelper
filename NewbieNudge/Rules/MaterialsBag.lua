-- Rule: materials_bag — Forever's separate materials bag slot. Confirmed in
-- game (2026-11-20): the slot (Enum.BagIndex.ReagentBag, inventory slot 35)
-- holds profession bags; an Apprentice's Mining Pack there reported item
-- family 1024 and container subclass 6. So a "materials bag" is any
-- container with a non-zero item family other than the ammo families
-- (1 = arrows, 2 = bullets). bag_unequipped ignores those (family-0
-- containers in bags 1-4 only); this rule tracks them on its own.
local _, NN = ...
local L = NN.L

local BAG_ICON = 133634
local CONTAINER_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Container) or 1
local AMMO_FAMILIES = { [1] = true, [2] = true }

local function reagentBagIndex()
  return Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
end

function NN.IsReagentBag(itemID)
  local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
  if NN.Plain(classID) ~= CONTAINER_CLASS then return false end
  local family = NN.Plain(C_Item.GetItemFamily(itemID)) or 0
  return family ~= 0 and not AMMO_FAMILIES[family]
end

-- Moves an equipped bag from a regular bag slot into the materials slot.
-- True when it landed there; otherwise the cursor is cleared and the player
-- is told how to drag it.
function NN.MoveBagToMaterialsSlot(fromSlot)
  if InCombatLockdown and InCombatLockdown() then
    NN:Say(L.MATERIALS_BAG_IN_COMBAT)
    return false
  end
  local index = reagentBagIndex()
  local toSlot = index and NN.BagInventorySlot(index)
  if toSlot and PickupBagFromSlot and PutItemInBag then
    PickupBagFromSlot(fromSlot)
    PutItemInBag(toSlot)
    if not (CursorHasItem and CursorHasItem()) and GetInventoryItemID("player", fromSlot) == nil then return true end
  end
  if ClearCursor then ClearCursor() end
  ToggleAllBags()
  NN:Say(L.MATERIALS_BAG_MOVE_FAILED)
  return false
end

-- A profession bag equipped in one of the four regular bag slots while the
-- materials slot is empty: that bag wastes a slot a normal bag could use.
local function professionBagInRegularSlot()
  for bag = 1, 4 do
    local slot = NN.BagInventorySlot(bag)
    local itemID = NN.Plain(GetInventoryItemID("player", slot))
    if itemID and NN.IsReagentBag(itemID) then
      local name = NN.Plain(C_Item.GetItemInfo(itemID), "string")
      return {
        text = L.MATERIALS_BAG_ROW_SLOT:format(name or L.MATERIALS_BAG_GENERIC),
        icon = BAG_ICON, highlight = "bags",
        onClick = function() NN.MoveBagToMaterialsSlot(slot) end,
      }
    end
  end
  return nil
end

NN:RegisterRule({
  name = "materials_bag",
  title = L.MATERIALS_BAG_TITLE,
  help = L.MATERIALS_BAG_HELP,
  events = { "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" },
  combat = true,
  applies = function()
    local index = reagentBagIndex()
    return index ~= nil and NN.BagInventorySlot(index) ~= nil
  end,
  check = function()
    if not NN.bagsLoaded then return nil end
    local index = reagentBagIndex()
    local slot = NN.BagInventorySlot(index)
    local equippedID = GetInventoryItemID("player", slot)
    local equippedSlots = equippedID and (NN.Plain(C_Container.GetContainerNumSlots(index)) or 0) or nil
    if equippedID == nil then
      local row = professionBagInRegularSlot()
      if row then return row end
    end
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
