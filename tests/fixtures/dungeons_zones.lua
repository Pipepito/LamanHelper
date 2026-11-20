-- Fixture: small dungeon and zone tables replacing the generated ones.
local _, NN = ...
NN.Dungeons = {
  { instanceID = 36,  min = 16, max = 26, faction = "alliance", mapID = 1436, nameEN = "The Deadmines", quests = { 166, 214 } },
  { instanceID = 389, min = 13, max = 18, faction = "horde",    mapID = 1454, nameEN = "Ragefire Chasm", quests = { 5722 } },
  { instanceID = 43,  min = 17, max = 24,                       mapID = 1413, nameEN = "Wailing Caverns", quests = {} },
}
NN.Zones = { [1440] = { min = 19, max = 30 }, [1429] = { min = 1, max = 10 } }
