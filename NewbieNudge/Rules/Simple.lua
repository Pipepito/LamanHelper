-- Rules with one-line conditions: durability, hearthstone, mail, quests.
local _, NN = ...
local L = NN.L

local HEARTHSTONE_ID = 6948
local DEFAULT_MAX_QUESTS = 25

local function openPaperDoll() ToggleCharacter("PaperDollFrame") end

NN:RegisterRule({
  name = "durability",
  title = L.DURABILITY_TITLE,
  help = L.DURABILITY_HELP,
  events = { "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED" },
  combat = true,
  applies = function() return true end,
  check = function()
    local low, broken = false, false
    for slot = INVSLOT_FIRST_EQUIPPED or 1, INVSLOT_LAST_EQUIPPED or 17 do
      local cur, max = GetInventoryItemDurability(slot)
      if issecretvalue and (issecretvalue(cur) or issecretvalue(max)) then return NN.UNKNOWN end
      if cur ~= nil or max ~= nil then
        cur, max = NN.Plain(cur), NN.Plain(max)
        if cur == nil or max == nil then return NN.UNKNOWN end
        if max > 0 then
          if cur == 0 then broken = true
          elseif cur / max < 0.20 then low = true end
        end
      end
    end
    if broken then
      return { text = L.DURABILITY_ROW_BROKEN, icon = 136241, onClick = openPaperDoll, highlight = "character" }
    elseif low then
      return { text = L.DURABILITY_ROW_LOW, icon = 136241, onClick = openPaperDoll, highlight = "character" }
    end
    return nil
  end,
  sample = function() return { { text = L.DURABILITY_ROW_LOW, icon = 136241 } } end,
})

NN:RegisterRule({
  name = "hearthstone",
  title = L.HEARTHSTONE_TITLE,
  help = L.HEARTHSTONE_HELP,
  events = { "BAG_UPDATE_DELAYED" },
  combat = true,
  applies = function() return true end,
  check = function()
    if not NN.bagsLoaded then return nil end
    local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not getCount then return nil end
    local count = NN.Plain(getCount(HEARTHSTONE_ID))
    if count == nil then return NN.UNKNOWN end
    if count == 0 then
      return { text = L.HEARTHSTONE_ROW, icon = 134414 }
    end
    return nil
  end,
  sample = function() return { { text = L.HEARTHSTONE_ROW, icon = 134414 } } end,
})

NN:RegisterRule({
  name = "mail",
  title = L.MAIL_TITLE,
  help = L.MAIL_HELP,
  events = { "UPDATE_PENDING_MAIL", "MAIL_INBOX_UPDATE", "MAIL_CLOSED", "PLAYER_ENTERING_WORLD" },
  combat = true,
  applies = function() return true end,
  check = function()
    if HasNewMail and HasNewMail() then
      return { text = L.MAIL_ROW, icon = 133469, highlight = "mail" }
    end
    return nil
  end,
  sample = function() return { { text = L.MAIL_ROW, icon = 133469 } } end,
})

NN:RegisterRule({
  name = "quests",
  title = L.QUESTS_TITLE,
  help = L.QUESTS_HELP,
  events = { "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED" },
  applies = function() return true end,
  check = function()
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries) then return nil end
    local _, numQuests = C_QuestLog.GetNumQuestLogEntries()
    numQuests = NN.Plain(numQuests)
    if numQuests == nil then return NN.UNKNOWN end
    local max = DEFAULT_MAX_QUESTS
    if C_QuestLog.GetMaxNumQuestsCanAccept then
      max = NN.Plain(C_QuestLog.GetMaxNumQuestsCanAccept()) or DEFAULT_MAX_QUESTS
    end
    if numQuests >= max - 3 then
      return { text = L.QUESTS_ROW:format(numQuests, max), icon = 136797, onClick = ToggleQuestLog, highlight = "quests" }
    end
    return nil
  end,
  sample = function() return { { text = L.QUESTS_ROW:format(23, 25), icon = 136797 } } end,
})
