-- Rule: profession_rank — the next rank of a profession is within reach.
-- Primaries: Journeyman at skill 50 / level 10, Expert at 125 / 20, Artisan
-- at 200 / 35, all from a trainer. Secondaries (Cooking, First Aid, Fishing,
-- positions 3-6 of GetProfessions): Journeyman from a trainer at skill 50,
-- Expert from a vendor book at 125, Artisan from a quest at 225 and level 35
-- (Icy Veins First Aid guide, 2026-11-20).
local _, NN = ...
local L = NN.L

local PROF_ICON = 136240
local MAX_ROWS = 3
local MARGIN = 25 -- the next trainer rank opens 25 points below the cap
-- current cap -> character level needed for the next primary rank
local PRIMARY_LEVELS = { [75] = 10, [150] = 20, [225] = 35 }
-- current cap -> { step, skill needed, level needed } for secondaries
local SECONDARY_STEPS = {
  [75] = { "trainer", 50, 10 },
  [150] = { "book", 125, 20 },
  [225] = { "quest", 225, 35 },
}

function NN.ProfessionRankReady(skill, maxSkill, level)
  local needLevel = PRIMARY_LEVELS[maxSkill]
  if not needLevel then return false end
  return skill >= maxSkill - MARGIN and level >= needLevel
end

-- "trainer", "book", "quest", or nil when the next rank is not in reach.
function NN.ProfessionRankStep(skill, maxSkill, level, isSecondary)
  if not isSecondary then
    return NN.ProfessionRankReady(skill, maxSkill, level) and "trainer" or nil
  end
  local step = SECONDARY_STEPS[maxSkill]
  if not step then return nil end
  if skill >= step[2] and level >= step[3] then return step[1] end
  return nil
end

-- { { index =, secondary = bool }, ... } in GetProfessions order.
local function professionSlots()
  if not GetProfessions then return {} end
  local slots = { GetProfessions() }
  local out = {}
  for i = 1, 6 do
    local index = NN.Plain(slots[i])
    if index then out[#out + 1] = { index = index, secondary = i >= 3 } end
  end
  return out
end

local function rowFor(step, name, skill, maxSkill)
  if step == "book" then return L.PROFESSION_RANK_ROW_BOOK:format(name, maxSkill) end
  if step == "quest" then return L.PROFESSION_RANK_ROW_QUEST:format(name, maxSkill) end
  return L.PROFESSION_RANK_ROW:format(name, skill, maxSkill, name)
end

NN:RegisterRule({
  name = "profession_rank",
  group = "professions",
  title = L.PROFESSION_RANK_TITLE,
  help = L.PROFESSION_RANK_HELP,
  events = { "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "PLAYER_LEVEL_UP" },
  applies = function() return #professionSlots() > 0 end,
  check = function()
    if not GetProfessionInfo then return nil end
    local level = NN.Plain(UnitLevel("player"))
    if level == nil then return NN.UNKNOWN end
    local results = {}
    for _, slot in ipairs(professionSlots()) do
      if #results >= MAX_ROWS then break end
      local name, _, skill, maxSkill = GetProfessionInfo(slot.index)
      name, skill, maxSkill = NN.Plain(name, "string"), NN.Plain(skill), NN.Plain(maxSkill)
      if name and skill and maxSkill then
        local step = NN.ProfessionRankStep(skill, maxSkill, level, slot.secondary)
        if step then results[#results + 1] = { text = rowFor(step, name, skill, maxSkill), icon = PROF_ICON } end
      end
    end
    if #results == 0 then return nil end
    return results
  end,
  sample = function() return { { text = L.PROFESSION_RANK_ROW:format("Alchemy", 60, 75, "Alchemy"), icon = PROF_ICON } } end,
})
