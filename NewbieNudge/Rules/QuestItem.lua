-- Rule: quest_item — an item in the bags starts a quest the player has not
-- accepted yet. The row names the item; the backpack button and the item
-- itself (while the bags are open) glow.
local _, NN = ...
local L = NN.L

local ITEM_ICON = 134939
local MAX_ITEMS = 3

NN:RegisterRule({
  name = "quest_item",
  group = "quests",
  title = L.QUEST_ITEM_TITLE,
  help = L.QUEST_ITEM_HELP,
  events = { "BAG_UPDATE_DELAYED", "QUEST_ACCEPTED", "QUEST_LOG_UPDATE" },
  applies = function() return true end,
  check = function()
    if not NN.bagsLoaded then return nil end
    if not (C_Container and C_Container.GetContainerItemQuestInfo) then return nil end
    local results = {}
    local extra = 0
    for bag = 0, 4 do
      for slot = 1, NN.Plain(C_Container.GetContainerNumSlots(bag)) or 0 do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
          local q = C_Container.GetContainerItemQuestInfo(bag, slot)
          local questID = q and NN.Plain(q.questID)
          local done = questID and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
            and C_QuestLog.IsQuestFlaggedCompleted(questID) == true
          if questID and q.isActive ~= true and not done then
            if #results < MAX_ITEMS then
              local link = NN.Plain(info.hyperlink, "string")
              local name = link and NN.Plain((C_Item.GetItemInfo(link)), "string") or L.QUEST_ITEM_UNKNOWN
              results[#results + 1] = {
                text = L.QUEST_ITEM_ROW:format(name), icon = NN.Plain(info.iconFileID) or ITEM_ICON,
                onClick = ToggleAllBags, highlight = { key = "bags", bagslots = { { bag, slot } } },
              }
            else
              extra = extra + 1
            end
          end
        end
      end
    end
    if extra > 0 then results[#results + 1] = { text = L.MORE_ROWS:format(extra), icon = ITEM_ICON } end
    if #results == 0 then return nil end
    return results
  end,
  sample = function() return { { text = L.QUEST_ITEM_ROW:format("Gnarled Note"), icon = ITEM_ICON } } end,
})
