-- Rule: supplies — the leveling guides' first tip: keep food, drink and
-- bandages ready. No food or drink at all in the bags makes a row; no
-- bandages makes a row only for characters who know First Aid.
local _, NN = ...
local L = NN.L

local SUPPLY_ICON = 133950
local CONSUMABLE = (Enum and Enum.ItemClass and Enum.ItemClass.Consumable) or 0
local SUB = (Enum and Enum.ItemConsumableSubclass) or {}
local FOOD_DRINK = SUB.FoodDrink or 5
local BANDAGE = SUB.Bandage or 7
local FIRST_AID_SKILL_LINE = 129

-- True when a secondary profession slot holds First Aid.
function NN.KnowsFirstAid()
  if not (GetProfessions and GetProfessionInfo) then return false end
  local slots = { GetProfessions() }
  for i = 3, 6 do
    local index = NN.Plain(slots[i])
    if index then
      local name, _, _, _, _, _, skillLine = GetProfessionInfo(index)
      if NN.Plain(skillLine) == FIRST_AID_SKILL_LINE then return true end
      if NN.Plain(name, "string") and FIRST_AID and name == FIRST_AID then return true end
    end
  end
  return false
end

local function countConsumables(subclass)
  local n = 0
  for bag = 0, 4 do
    for slot = 1, NN.Plain(C_Container.GetContainerNumSlots(bag)) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local itemID = info and NN.Plain(info.itemID)
      if itemID then
        local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
        if NN.Plain(classID) == CONSUMABLE and NN.Plain(subclassID) == subclass then n = n + 1 end
      end
    end
  end
  return n
end

NN:RegisterRule({
  name = "supplies",
  group = "gear",
  title = L.SUPPLIES_TITLE,
  help = L.SUPPLIES_HELP,
  events = { "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED" },
  applies = function() return (NN.Plain(UnitLevel("player")) or 0) >= 5 end,
  check = function()
    if not NN.bagsLoaded then return NN.UNKNOWN end
    local results = {}
    if countConsumables(FOOD_DRINK) == 0 then
      results[#results + 1] = { text = L.SUPPLIES_ROW_FOOD, icon = SUPPLY_ICON, onClick = ToggleAllBags, highlight = "bags", service = { kind = "supplies" } }
    end
    if NN.KnowsFirstAid() and countConsumables(BANDAGE) == 0 then
      results[#results + 1] = { text = L.SUPPLIES_ROW_BANDAGE, icon = 133682, onClick = ToggleAllBags, highlight = "bags" }
    end
    if #results == 0 then return nil end
    return results
  end,
  sample = function() return { { text = L.SUPPLIES_ROW_FOOD, icon = SUPPLY_ICON } } end,
})
