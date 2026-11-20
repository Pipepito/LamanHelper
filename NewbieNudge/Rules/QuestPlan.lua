-- Quest planning: which quests to turn in, which to finish before they stop
-- giving full experience, and which already give almost none. Three small
-- rules (each with its own checkbox) sharing one walk of the quest log per
-- check cycle.
local _, NN = ...
local L = NN.L

local QUEST_ICON = 136797
local DEFAULT_RANGE = 5
local SOON_LEVELS = 2

local function trivialRange()
  local range
  if UnitQuestTrivialLevelRange then range = NN.Plain(UnitQuestTrivialLevelRange("player")) end
  if range == nil and GetQuestGreenRange then range = NN.Plain(GetQuestGreenRange()) end
  return range or DEFAULT_RANGE
end

local QT = (Enum and Enum.QuestTag) or {}
local GROUP_TAGS = { [QT.Group or 1] = true, [QT.Raid or 62] = true, [QT.Dungeon or 81] = true }

-- True when the quest is tagged for a group (Group, Dungeon, Raid) or the
-- client suggests more than one player for it.
local function needsGroup(questID)
  if C_QuestLog.GetQuestTagInfo then
    local tag = C_QuestLog.GetQuestTagInfo(questID)
    if tag and GROUP_TAGS[NN.Plain(tag.tagID) or -1] then return true end
  end
  if C_QuestLog.GetSuggestedGroupSize then
    local n = NN.Plain(C_QuestLog.GetSuggestedGroupSize(questID))
    if n and n > 1 then return true end
  end
  return false
end

local scanCache, scanGeneration

-- Returns a list of { questID, title, level, isComplete, isTrivial, turnsGreyIn }
-- or NN.UNKNOWN when any value is secret. Memoised for one RunChecks pass.
function NN.QuestScan()
  if scanCache and scanGeneration == NN.generation then return scanCache end
  local result = {}
  local ok = true
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
    local playerLevel = NN.Plain(UnitLevel("player"))
    local numEntries = NN.Plain((C_QuestLog.GetNumQuestLogEntries()))
    local range = trivialRange()
    if playerLevel == nil or numEntries == nil then ok = false end
    for i = 1, ok and numEntries or 0 do
      local info = C_QuestLog.GetInfo(i)
      if info and not info.isHeader and not info.isHidden then
        local questID = NN.Plain(info.questID)
        local level = info.level
        if C_QuestLog.GetQuestDifficultyLevel and questID then
          level = C_QuestLog.GetQuestDifficultyLevel(questID) or level
        end
        level = NN.Plain(level)
        if questID == nil or level == nil then ok = false; break end
        local isComplete
        if C_QuestLog.IsComplete then isComplete = C_QuestLog.IsComplete(questID) == true
        else isComplete = info.isComplete == true end
        local isTrivial
        if C_QuestLog.IsQuestTrivial then
          local t = C_QuestLog.IsQuestTrivial(questID)
          if issecretvalue and issecretvalue(t) then ok = false; break end
          isTrivial = t == true
        else
          isTrivial = (level + range) < playerLevel
        end
        result[#result + 1] = {
          questID = questID, title = NN.Plain(info.title, "string") or "", level = level,
          isComplete = isComplete, isTrivial = isTrivial, needsGroup = needsGroup(questID),
          turnsGreyIn = (level + range) - playerLevel + 1,
        }
      end
    end
  end
  scanCache = ok and result or NN.UNKNOWN
  scanGeneration = NN.generation
  return scanCache
end

local function countWhere(pred)
  local scan = NN.QuestScan()
  if scan == NN.UNKNOWN then return NN.UNKNOWN end
  local n = 0
  for _, q in ipairs(scan) do if pred(q) then n = n + 1 end end
  return n
end

local EVENTS = { "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP" }

NN:RegisterRule({
  name = "quest_turnin",
  title = L.QUEST_TURNIN_TITLE,
  help = L.QUEST_TURNIN_HELP,
  events = EVENTS,
  applies = function() return true end,
  check = function()
    local n = countWhere(function(q) return q.isComplete end)
    if n == NN.UNKNOWN then return NN.UNKNOWN end
    if n > 0 then
      return { text = L.QUEST_TURNIN_ROW:format(n), icon = QUEST_ICON, onClick = ToggleQuestLog, highlight = "quests" }
    end
    return nil
  end,
  sample = function() return { { text = L.QUEST_TURNIN_ROW:format(2), icon = QUEST_ICON } } end,
})

NN:RegisterRule({
  name = "quest_soon",
  title = L.QUEST_SOON_TITLE,
  help = L.QUEST_SOON_HELP,
  events = EVENTS,
  applies = function() return true end,
  check = function()
    local n = countWhere(function(q) return not q.isComplete and not q.isTrivial and q.turnsGreyIn <= SOON_LEVELS end)
    if n == NN.UNKNOWN then return NN.UNKNOWN end
    if n > 0 then
      return { text = L.QUEST_SOON_ROW:format(n), icon = QUEST_ICON, onClick = ToggleQuestLog, highlight = "quests" }
    end
    return nil
  end,
  sample = function() return { { text = L.QUEST_SOON_ROW:format(3), icon = QUEST_ICON } } end,
})

NN:RegisterRule({
  name = "quest_grey",
  title = L.QUEST_GREY_TITLE,
  help = L.QUEST_GREY_HELP,
  events = EVENTS,
  applies = function() return true end,
  check = function()
    local n = countWhere(function(q) return q.isTrivial and not q.isComplete end)
    if n == NN.UNKNOWN then return NN.UNKNOWN end
    if n > 0 then
      return { text = L.QUEST_GREY_ROW:format(n), icon = QUEST_ICON, onClick = ToggleQuestLog }
    end
    return nil
  end,
  sample = function() return { { text = L.QUEST_GREY_ROW:format(2), icon = QUEST_ICON } } end,
})

NN:RegisterRule({
  name = "quest_group",
  title = L.QUEST_GROUP_TITLE,
  help = L.QUEST_GROUP_HELP,
  events = EVENTS,
  applies = function() return true end,
  check = function()
    local n = countWhere(function(q) return q.needsGroup and not q.isComplete end)
    if n == NN.UNKNOWN then return NN.UNKNOWN end
    if n > 0 then
      return { text = L.QUEST_GROUP_ROW:format(n), icon = 136221, onClick = ToggleQuestLog }
    end
    return nil
  end,
  sample = function() return { { text = L.QUEST_GROUP_ROW:format(1), icon = 136221 } } end,
})
