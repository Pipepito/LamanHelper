-- Rule: professions — level 10+ with no primary profession.
local _, NN = ...
local L = NN.L

local PROF_ICON = 136240

-- Number of primary professions, or nil when no API can tell us.
function NN.PrimaryProfessionCount()
  if GetProfessions then
    local prof1, prof2 = GetProfessions()
    local n = 0
    if NN.Plain(prof1) then n = n + 1 end
    if NN.Plain(prof2) then n = n + 1 end
    return n
  end
  if C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo then
    local count, underProfessions = 0, false
    for i = 1, NN.Plain(C_SkillInfo.GetNumSkillLines()) or 0 do
      local a, b = C_SkillInfo.GetSkillLineInfo(i)
      local name, isHeader
      if type(a) == "table" then name, isHeader = a.skillName, a.isHeader else name, isHeader = a, b end
      if isHeader then
        underProfessions = (name == TRADE_SKILLS)
      elseif underProfessions then
        count = count + 1
      end
    end
    return count
  end
  return nil
end

local function openSkills()
  if ToggleCharacter then ToggleCharacter("SkillFrame") end
end

NN:RegisterRule({
  name = "professions",
  group = "professions",
  title = L.PROFESSIONS_TITLE,
  help = L.PROFESSIONS_HELP,
  events = { "SKILL_LINES_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" },
  applies = function() return (NN.Plain(UnitLevel("player")) or 0) >= 10 end,
  check = function()
    local count = NN.PrimaryProfessionCount()
    if count == nil then return nil end
    if count == 0 then
      return { text = L.PROFESSIONS_ROW, icon = PROF_ICON, onClick = openSkills, highlight = "character" }
    end
    return nil
  end,
  sample = function() return { { text = L.PROFESSIONS_ROW, icon = PROF_ICON } } end,
})
