-- Rule: profession_rank — a primary profession can learn its next rank
-- (Journeyman at skill 50 / level 10, Expert at 125 / 20, Artisan at
-- 200 / 35). Secondary professions reach their higher ranks through books
-- and quests, so they are left out.
local _, NN = ...
local L = NN.L

local PROF_ICON = 136240
local MAX_ROWS = 2
-- current cap -> character level needed for the next rank
local RANKS = { [75] = 10, [150] = 20, [225] = 35 }
local MARGIN = 25 -- the next trainer rank opens 25 points below the cap

function NN.ProfessionRankReady(skill, maxSkill, level)
  local needLevel = RANKS[maxSkill]
  if not needLevel then return false end
  return skill >= maxSkill - MARGIN and level >= needLevel
end

local function primaries()
  if not GetProfessions then return {} end
  local prof1, prof2 = GetProfessions()
  local out = {}
  if NN.Plain(prof1) then out[#out + 1] = prof1 end
  if NN.Plain(prof2) then out[#out + 1] = prof2 end
  return out
end

NN:RegisterRule({
  name = "profession_rank",
  title = L.PROFESSION_RANK_TITLE,
  help = L.PROFESSION_RANK_HELP,
  events = { "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "PLAYER_LEVEL_UP" },
  applies = function() return #primaries() > 0 end,
  check = function()
    if not GetProfessionInfo then return nil end
    local level = NN.Plain(UnitLevel("player"))
    if level == nil then return NN.UNKNOWN end
    local results = {}
    for _, index in ipairs(primaries()) do
      local name, _, skill, maxSkill = GetProfessionInfo(index)
      name, skill, maxSkill = NN.Plain(name, "string"), NN.Plain(skill), NN.Plain(maxSkill)
      if name and skill and maxSkill and NN.ProfessionRankReady(skill, maxSkill, level) and #results < MAX_ROWS then
        results[#results + 1] = { text = L.PROFESSION_RANK_ROW:format(name, skill, maxSkill, name), icon = PROF_ICON }
      end
    end
    if #results == 0 then return nil end
    return results
  end,
  sample = function() return { { text = L.PROFESSION_RANK_ROW:format("Alchemy", 60, 75, "Alchemy"), icon = PROF_ICON } } end,
})
