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
