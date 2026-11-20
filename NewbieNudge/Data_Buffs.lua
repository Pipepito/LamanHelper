-- Long-duration self-buffs per class. The only hand-maintained data in the
-- addon. A group is satisfied when ANY aura in it is on the player; a group
-- flagged weapon=true is satisfied by a main-hand temporary enchant instead.
-- IDs are base ranks; names come from the client, so this works in any
-- language. Groups the character does not know any spell of are skipped.
local _, NN = ...

NN.BuffData = {
  MAGE = {
    { ids = { 1459 } },                       -- Arcane Intellect
    { ids = { 168, 7302, 6117 } },            -- Frost Armor / Ice Armor / Mage Armor
  },
  PRIEST = {
    { ids = { 1243 } },                       -- Power Word: Fortitude
    { ids = { 588 } },                        -- Inner Fire
    { ids = { 14752 } },                      -- Divine Spirit
  },
  DRUID = {
    { ids = { 1126 } },                       -- Mark of the Wild
    { ids = { 467 } },                        -- Thorns
    { ids = { 16864 } },                      -- Omen of Clarity
  },
  WARLOCK = {
    { ids = { 687, 706 } },                   -- Demon Skin / Demon Armor
  },
  SHAMAN = {
    { ids = { 324, 24398 } },                 -- Lightning Shield / Water Shield
    { ids = { 8017, 8024, 8033, 8232 }, weapon = true }, -- Rockbiter / Flametongue / Frostbrand / Windfury
  },
  PALADIN = {
    { ids = { 19740, 19742, 20217, 20911, 19977, 1038 } }, -- Blessings on self
    { ids = { 465, 7294, 19746, 19876, 19888, 19891, 20218 } }, -- Auras
  },
  HUNTER = {
    { ids = { 13163, 13165, 5118, 13161, 13159, 20043 } }, -- Aspects
    { ids = { 19506 } },                      -- Trueshot Aura
  },
  ROGUE = {
    { ids = { 8679, 2823, 3408, 5761, 13219 }, weapon = true }, -- Poisons
  },
}
