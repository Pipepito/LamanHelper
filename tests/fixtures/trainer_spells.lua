-- Fixture: a small trainer-spell table for the stub's default class (MAGE).
-- Loaded after the real data file, so it replaces NN.TrainerSpells.MAGE.
local _, NN = ...
NN.TrainerSpells = NN.TrainerSpells or {}
NN.TrainerSpells.MAGE = {
  { level = 1,  id = 133,   spell = 1, rank = 1 },  -- Fireball r1
  { level = 6,  id = 143,   spell = 1, rank = 2 },  -- Fireball r2
  { level = 14, id = 145,   spell = 1, rank = 3 },
  { level = 10, id = 5143,  spell = 2, rank = 1 },  -- Arcane Missiles
  { level = 10, id = 99999, spell = 3, rank = 1 },  -- stale id, does not exist
  { level = 4,  id = 1180,  spell = 4, rank = 1, races = { "Gnome" } }, -- race-locked
}
-- v4: a warlock-demon-style pet spell (never counted) and class quest spells
table.insert(NN.TrainerSpells.MAGE, { level = 1, id = 5555, spell = 5, rank = 1, pet = true })
table.insert(NN.TrainerSpells.MAGE, { level = 10, id = 7777, spell = 6, rank = 1 }) -- also a quest spell
NN.ClassQuestSpells = { MAGE = { { id = 7777, level = 10 }, { id = 7778, level = 12 }, { id = 7779, level = 12 }, { id = 7780, level = 12 } } }
