-- Weapon masters and which weapon skills each class can learn on WoW Forever.
-- Hand-written (2026-11-22) from Warcraft Tavern's WoW Forever weapon-trainer
-- guide (https://www.warcrafttavern.com/forever/guides/weapon-trainers/),
-- checked against warcraft.wiki.gg's weapon master page. Skill line IDs:
-- 43 swords, 44 axes, 45 bows, 46 guns, 54 maces, 55 two-handed swords,
-- 136 staves, 160 two-handed maces, 172 two-handed axes, 173 daggers,
-- 176 thrown, 226 crossbows, 229 polearms, 473 fist weapons.
-- Trainer ids are QuestieDB NPC ids (Data/Services.lua).
-- Wands (228) are built in for mages, priests and warlocks: no trainer.
local _, NN = ...

NN.WeaponTrainers = {
  -- weapon skill line ID -> weapon item subclass (for the client's own name)
  subclass = {
    [44] = 0, [172] = 1, [45] = 2, [46] = 3, [54] = 4, [160] = 5, [229] = 6,
    [43] = 7, [55] = 8, [136] = 10, [473] = 13, [173] = 15, [176] = 16, [226] = 18,
  },
  minLevel = { [229] = 20 }, -- polearms
  -- per faction, cities in display order; uiMapID gives the localized name
  cities = {
    Alliance = {
      { mapID = 1453, name = "Stormwind City", trainers = {
        { name = "Woo Ping", id = 11867, skills = { 43, 55, 173, 136, 226, 229 } } } },
      { mapID = 1455, name = "Ironforge", trainers = {
        { name = "Buliwyf Stonehand", id = 11865, skills = { 44, 172, 54, 160, 473, 46 } },
        { name = "Bixi Wobblebonk", id = 13084, skills = { 226, 173, 176 } } } },
      { mapID = 1457, name = "Darnassus", trainers = {
        { name = "Ilyenia Moonfire", id = 11866, skills = { 45, 173, 473, 136, 176 } } } },
    },
    Horde = {
      { mapID = 1454, name = "Orgrimmar", trainers = {
        { name = "Sayoc", id = 11868, skills = { 45, 173, 473, 44, 136, 176, 172 } },
        { name = "Hanashi", id = 2704, skills = { 45, 44, 136, 176, 172 } } } },
      { mapID = 1456, name = "Thunder Bluff", trainers = {
        { name = "Ansekhwa", id = 11869, skills = { 46, 54, 136, 160 } } } },
      { mapID = 1458, name = "Undercity", trainers = {
        { name = "Archibald", id = 11870, skills = { 226, 173, 43, 229, 55 } } } },
    },
  },
  -- class file token -> weapon skill line IDs it can learn (wands left out)
  classes = {
    DRUID = { 173, 473, 54, 229, 136, 160 },
    HUNTER = { 45, 226, 173, 473, 46, 44, 43, 229, 136, 176, 172, 55 },
    MAGE = { 173, 43, 136 },
    PALADIN = { 44, 54, 43, 229, 172, 160, 55 },
    PRIEST = { 173, 54, 136 },
    ROGUE = { 45, 226, 173, 473, 46, 44, 54, 43, 176 },
    SHAMAN = { 173, 473, 44, 54, 136, 172, 160 },
    WARLOCK = { 173, 43, 136 },
    WARRIOR = { 45, 226, 173, 473, 46, 44, 54, 43, 229, 136, 176, 172, 160, 55 },
  },
}
