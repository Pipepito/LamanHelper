-- Rule: pet — hunter pet not summoned, unhappy, or holding unspent training
-- points. "Not summoned" only fires once the character has been seen with a
-- pet, so a fresh hunter without one is not nagged.
local _, NN = ...
local L = NN.L

local ICON_MISSING, ICON_UNHAPPY, ICON_TRAINING = 132161, 132214, 132835

local function isHunterPetOut()
  if not UnitExists("pet") then return false end
  if HasPetUI then
    local hasUI, isHunterPet = HasPetUI()
    return hasUI == true and isHunterPet ~= false
  end
  return true
end

-- Remember that this character has owned a pet.
NN:OnAnyEvent(function(event)
  if (event == "UNIT_PET" or event == "PLAYER_ENTERING_WORLD" or event == "PET_UI_UPDATE") and NN.db then
    if NN.classFile == "HUNTER" and isHunterPetOut() then NN.db.seen.pet = true end
  end
end)

-- Happiness: 1 unhappy, 2 content, 3 happy. Handles both return shapes.
function NN.PetHappiness()
  if not (C_PetInfo and C_PetInfo.GetPetHappiness) then return nil end
  local r = C_PetInfo.GetPetHappiness()
  if type(r) == "table" then return NN.Plain(r.happiness) end
  return NN.Plain(r)
end

function NN.PetUnspentTraining()
  if not (C_PetInfo and C_PetInfo.GetPetTrainingPoints) then return nil end
  local a, b = C_PetInfo.GetPetTrainingPoints()
  local total, spent
  if type(a) == "table" then total, spent = NN.Plain(a.totalPoints), NN.Plain(a.spent)
  else total, spent = NN.Plain(a), NN.Plain(b) end
  if total == nil then return nil end
  return total - (spent or 0)
end

NN:RegisterRule({
  name = "pet",
  group = "spells",
  title = L.PET_TITLE,
  help = L.PET_HELP,
  events = { "UNIT_PET:player", "UNIT_HAPPINESS", "UNIT_PET_TRAINING_POINTS", "PET_UI_UPDATE",
             "PLAYER_LEVEL_UP", "PLAYER_UPDATE_RESTING", "PLAYER_ENTERING_WORLD" },
  combat = true,
  applies = function()
    return NN.classFile == "HUNTER" and (NN.Plain(UnitLevel("player")) or 0) >= 10
  end,
  check = function()
    local results = {}
    if not UnitExists("pet") then
      if NN.db.seen.pet and not IsMounted() and not IsResting() and not UnitIsDeadOrGhost("player") then
        results[#results + 1] = { text = L.PET_ROW_MISSING, icon = ICON_MISSING }
      end
    else
      local happiness = NN.PetHappiness()
      if happiness and happiness <= 2 then
        results[#results + 1] = { text = L.PET_ROW_UNHAPPY, icon = ICON_UNHAPPY }
      end
      local unspent = NN.PetUnspentTraining()
      if unspent and unspent > 0 then
        results[#results + 1] = { text = L.PET_ROW_TRAINING:format(unspent), icon = ICON_TRAINING }
      end
    end
    if #results == 0 then return nil end
    return results
  end,
  sample = function() return { { text = L.PET_ROW_UNHAPPY, icon = ICON_UNHAPPY } } end,
})
