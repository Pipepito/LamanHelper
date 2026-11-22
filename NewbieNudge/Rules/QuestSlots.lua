-- Rule: quest_slots — an estimate of the bag slots the current quests will
-- need: one per item objective not yet started, the missing stacks for
-- started ones, and the rewards of quests ready to turn in.
local _, NN = ...
local L = NN.L

local BAG_ICON = 133634
local EN_DASH = "\226\128\147"

-- "Boar Meat: 3/10", "3/10 Boar Meat" or "Carne de jabalí: 0/10" -> the item
-- name; nil when the text carries no n/m counter.
function NN.ObjectiveItemName(text)
  text = NN.Plain(text, "string")
  if not text or not text:find("%d+%s*/%s*%d+") then return nil end
  local name = text:gsub("%d+%s*/%s*%d+", "")
  name = name:gsub("^" .. EN_DASH, ""):gsub(EN_DASH .. "$", "")
  name = name:gsub("^[%s:%-%(%)]+", ""):gsub("[%s:%-%(%)]+$", "")
  name = strtrim(name)
  if name == "" then return nil end
  return name
end

-- name -> { itemID, stacks } for every stack in the regular bags.
local function heldByName()
  local held = {}
  for bag = 0, 4 do
    for slot = 1, NN.Plain(C_Container.GetContainerNumSlots(bag)) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local link = info and NN.Plain(info.hyperlink, "string")
      local itemID = info and NN.Plain(info.itemID)
      if link and itemID then
        local name = NN.Plain((C_Item.GetItemInfo(link)), "string")
        if name then
          local entry = held[name]
          if not entry then entry = { itemID = itemID, stacks = 0 }; held[name] = entry end
          entry.stacks = entry.stacks + 1
        end
      end
    end
  end
  return held
end

-- Slots needed, or NN.UNKNOWN.
function NN.QuestSlotsNeeded()
  local scan = NN.QuestScan()
  if scan == NN.UNKNOWN then return NN.UNKNOWN end
  local held
  local total = 0
  for _, q in ipairs(scan) do
    local objectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(q.questID)
    for _, o in ipairs(objectives or {}) do
      if NN.Plain(o.type, "string") == "item" and o.finished ~= true then
        local required = NN.Plain(o.numRequired) or 0
        local name = NN.ObjectiveItemName(o.text)
        held = held or heldByName()
        local h = name and held[name]
        if h then
          local stackSize = C_Item.GetItemMaxStackSizeByID and NN.Plain(C_Item.GetItemMaxStackSizeByID(h.itemID)) or 1
          local extra = math.ceil(required / math.max(stackSize, 1)) - h.stacks
          if extra > 0 then total = total + extra end
        else
          total = total + 1
        end
      end
    end
    if q.isComplete then
      total = total + (GetNumQuestLogRewards and NN.Plain(GetNumQuestLogRewards(q.questID)) or 0)
      if (GetNumQuestLogChoices and NN.Plain(GetNumQuestLogChoices(q.questID)) or 0) > 0 then total = total + 1 end
    end
  end
  return total
end

NN:RegisterRule({
  name = "quest_slots",
  group = "quests",
  title = L.QUEST_SLOTS_TITLE,
  help = L.QUEST_SLOTS_HELP,
  events = { "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN" },
  applies = function() return true end,
  check = function()
    if not NN.bagsLoaded then return nil end
    local needed = NN.QuestSlotsNeeded()
    if needed == NN.UNKNOWN then return NN.UNKNOWN end
    if needed <= 0 then return nil end
    local free = NN.RegularFreeSlots()
    if free == NN.UNKNOWN then return NN.UNKNOWN end
    if free < needed then
      return { text = L.QUEST_SLOTS_ROW:format(needed, free), icon = BAG_ICON, onClick = ToggleAllBags, highlight = "bags" }
    end
    return nil
  end,
  sample = function() return { { text = L.QUEST_SLOTS_ROW:format(4, 2), icon = BAG_ICON } } end,
})
