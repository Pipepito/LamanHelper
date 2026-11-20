-- Loaded by load_addon() after the TOC files unless WOW.keepData is true:
-- empties the generated data tables so the default test character
-- (level 20, Alliance, mage) gets no dungeon, zone or trainer rows. Test
-- fixtures in WOW.extraFiles load after this and may fill them again.
local _, NN = ...
NN.Dungeons = {}
NN.Zones = {}
NN.TrainerSpells = {}
