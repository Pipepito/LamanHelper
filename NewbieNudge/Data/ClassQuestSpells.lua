-- Class spells that come from a class quest rather than the trainer
-- (classic class quests, hand-written 2026-11-22; check on Forever with the
-- testing checklist). { id = spellID, level = level the quest opens }.
-- A spell here counts as a quest spell even if Data/TrainerSpells.lua lists it.
local _, NN = ...
NN.ClassQuestSpells = {
  WARRIOR = { { id = 71, level = 10 }, { id = 2458, level = 30 } },            -- Defensive / Berserker Stance
  DRUID = { { id = 5487, level = 10 }, { id = 8946, level = 14 }, { id = 1066, level = 16 } }, -- Bear Form, Cure Poison, Aquatic Form
  HUNTER = { { id = 1515, level = 10 } },                                      -- Tame Beast
  PALADIN = { { id = 7328, level = 12 }, { id = 13819, level = 40 }, { id = 23214, level = 60 } }, -- Redemption, Warhorse, Charger
  WARLOCK = { { id = 697, level = 10 }, { id = 712, level = 20 }, { id = 691, level = 30 },   -- Voidwalker, Succubus, Felhunter
    { id = 1122, level = 50 }, { id = 18540, level = 60 }, { id = 23161, level = 60 } },      -- Inferno, Ritual of Doom, Dreadsteed
  ROGUE = { { id = 2842, level = 20 } },                                       -- Poisons
}
