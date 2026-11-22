-- Fixture: a small service world for Services / MapPins tests.
-- Maps 1429 (Elwynn, 1-10) and 1431 (level 30-40) and 1453 (city, no range)
-- share continent 0; 1439 (level 10-20) and 1457 are on continent 1.
local _, NN = ...
NN.ServiceData = {
  npcs = {
    [1] = { "Near Smith", "Armorer", 1429, 40, 60, "A" },
    [2] = { "Far Smith", "Armorer", 1429, 90, 10, "A" },
    [3] = { "Horde Smith", "Armorer", 1429, 41, 61, "H" },
    [4] = { "High Smith", "Armorer", 1431, 50, 50, "A" },
    [5] = { "City Smith", "Armorer", 1453, 50, 50, "AH" },
    [6] = { "Kalimdor Smith", "Armorer", 1439, 40, 61, "A" },
    [7] = { "Innkeeper Farley", "Innkeeper", 1429, 43.77, 65.8, "A" },
    [8] = { "Jor", "Mage Trainer", 1429, 30, 30, "A" },
    [9] = { "Ilyenia Moonfire", "Weapon Master", 1457, 57, 46, "A" },
    [10] = { "Bread Guy", "Baker", 1429, 45, 65, "A" },
    [11] = { "Herb Lady", "Herbalist", 1429, 5, 5, "A" },
    [11867] = { "Woo Ping", "Weapon Master", 1453, 63.88, 69.09, "A" },
  },
  kinds = {
    repair = { 1, 2, 3, 4, 5, 6 }, inn = { 7 }, supplies = { 10 }, trainer_MAGE = { 8 },
    weapon = { 11867, 9 }, prof_182 = { 11 },
  },
}
NN.Zones = { [1429] = { min = 1, max = 10 }, [1431] = { min = 30, max = 40 }, [1439] = { min = 10, max = 20 } }
WOW.state.mapID = 1429
WOW.state.playerPos = { x = 0.40, y = 0.61 }
WOW.state.mapWorld = {
  [1429] = { 0, 0, 0, 1000, 1000 }, [1431] = { 0, 1000, 0, 1000, 1000 }, [1453] = { 0, -2000, 0, 1000, 1000 },
  [1439] = { 1, 0, 0, 1000, 1000 }, [1457] = { 1, 3000, 0, 1000, 1000 },
}
WOW.state.mapInfo[1429] = { name = "Elwynn Forest" }
WOW.state.mapInfo[1453] = { name = "Stormwind City" }
WOW.state.mapInfo[1457] = { name = "Darnassus" }
WOW.state.tracking = { { name = "Find Herbs" }, { name = "Repair" }, { name = "Innkeeper" }, { name = "Food & Drink" }, { name = "Class Trainer" } }
MINIMAP_TRACKING_REPAIR, MINIMAP_TRACKING_INNKEEPER, MINIMAP_TRACKING_VENDOR_FOOD = "Repair", "Innkeeper", "Food & Drink"
