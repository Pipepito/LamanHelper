-- Rule: weapon_skill — your skill with the equipped weapon is far behind its
-- cap ("a good weapon performs poorly if your skill with it is far behind",
-- Icy Veins leveling tips). Skill lines come from C_SkillInfo (live shape
-- confirmed 2026-11-20: name, rank, maxRank, skillID, skillLineCategoryID,
-- isHeader). Weapon lines are matched by skill ID, so no name matching.
local _, NN = ...
local L = NN.L

local SKILL_ICON = 135324
local BEHIND = 20
local RIDING_SKILL = 762
local WEAPON_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2
local MAINHAND, RANGED = INVSLOT_MAINHAND or 16, INVSLOT_RANGED or 18

-- weapon item subclass -> weapon skill line ID
local SKILL_FOR_SUBCLASS = {
  [0] = 44,   -- one-hand axes
  [1] = 172,  -- two-hand axes
  [2] = 45,   -- bows
  [3] = 46,   -- guns
  [4] = 54,   -- one-hand maces
  [5] = 160,  -- two-hand maces
  [6] = 229,  -- polearms
  [7] = 43,   -- one-hand swords
  [8] = 55,   -- two-hand swords
  [10] = 136, -- staves
  [13] = 473, -- fist weapons
  [15] = 173, -- daggers
  [16] = 176, -- thrown
  [18] = 226, -- crossbows
  [19] = 228, -- wands
}

-- All skill lines as { name, rank, maxRank, skillID, category, isHeader, isRiding };
-- nil when the client has no skill API.
function NN.SkillLines()
  if not (C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo) then return nil end
  local lines = {}
  for i = 1, NN.Plain(C_SkillInfo.GetNumSkillLines()) or 0 do
    local info = C_SkillInfo.GetSkillLineInfo(i)
    if info and not info.isHeader then
      local skillID = NN.Plain(info.skillID) or 0
      lines[#lines + 1] = {
        name = NN.Plain(info.name, "string") or NN.Plain(info.skillName, "string") or "",
        rank = NN.Plain(info.rank) or NN.Plain(info.skillRank) or 0,
        maxRank = NN.Plain(info.maxRank) or NN.Plain(info.skillMaxRank) or 0,
        skillID = skillID, category = NN.Plain(info.skillLineCategoryID) or 0,
        isRiding = skillID == RIDING_SKILL,
      }
    end
  end
  return lines
end

local function skillLineByID(lines, skillID)
  for _, line in ipairs(lines) do if line.skillID == skillID then return line end end
  return nil
end

local function openSkills()
  if ToggleCharacter then ToggleCharacter("SkillFrame") end
end

NN:RegisterRule({
  name = "weapon_skill",
  group = "spells",
  title = L.WEAPON_SKILL_TITLE,
  help = L.WEAPON_SKILL_HELP,
  events = { "SKILL_LINES_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "CHAT_MSG_SKILL" },
  applies = function() return C_SkillInfo ~= nil and C_SkillInfo.GetSkillLineInfo ~= nil end,
  check = function()
    local lines = NN.SkillLines()
    if not lines then return nil end
    local results, seen = {}, {}
    for _, slot in ipairs({ MAINHAND, RANGED }) do
      local itemID = NN.Plain(GetInventoryItemID("player", slot))
      if itemID then
        local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
        local skillID = NN.Plain(classID) == WEAPON_CLASS and SKILL_FOR_SUBCLASS[NN.Plain(subclassID) or -1]
        local line = skillID and not seen[skillID] and skillLineByID(lines, skillID)
        if line and line.maxRank > 0 and line.rank < line.maxRank - BEHIND then
          seen[skillID] = true
          results[#results + 1] = { text = L.WEAPON_SKILL_ROW:format(line.name, line.rank, line.maxRank), icon = SKILL_ICON, onClick = openSkills }
        end
      end
    end
    if #results == 0 then return nil end
    return results
  end,
  sample = function() return { { text = L.WEAPON_SKILL_ROW:format("Swords", 12, 100), icon = SKILL_ICON } } end,
})
