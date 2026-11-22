-- Rule: weapon_trainers — weapon skills the class can learn but hasn't, and
-- the city of the player's faction that teaches them (not every city teaches
-- every weapon). One row per city. Data: Data/WeaponTrainers.lua.
local _, NN = ...
local L = NN.L

local SKILL_ICON = 135324
local FROM_LEVEL = 10
local WEAPON_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2

local function data() return NN.WeaponTrainers end

local function playerClass()
  return select(2, UnitClass("player"))
end

local function faction()
  local f = NN.Plain(UnitFactionGroup("player"), "string")
  if f == "Alliance" or f == "Horde" then return f end
  return nil
end

local function weaponName(skillID)
  local sub = data().subclass[skillID]
  local name = sub and C_Item and C_Item.GetItemSubClassInfo and NN.Plain(C_Item.GetItemSubClassInfo(WEAPON_CLASS, sub), "string")
  return name or tostring(skillID)
end

local function cityName(city)
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(city.mapID)
  return (info and NN.Plain(info.name, "string")) or city.name
end

-- Set of known skill line IDs, or nil when the client can't tell yet.
local function knownSkills()
  local lines = NN.SkillLines and NN.SkillLines()
  if not lines then return nil end
  local known, anyWeapon = {}, false
  for _, line in ipairs(lines) do
    known[line.skillID] = true
    if data().subclass[line.skillID] or line.skillID == 228 then anyWeapon = true end
  end
  -- every character knows at least one weapon; none means the list isn't loaded
  if not anyWeapon then return nil end
  return known
end

NN:RegisterRule({
  name = "weapon_trainers",
  group = "spells",
  title = L.WEAPON_TRAINERS_TITLE,
  help = L.WEAPON_TRAINERS_HELP,
  events = { "SKILL_LINES_CHANGED", "PLAYER_LEVEL_UP" },
  applies = function()
    if not (data() and data().classes[playerClass()] and faction()) then return false end
    if not (C_SkillInfo and C_SkillInfo.GetNumSkillLines) then return false end
    return (NN.Plain(UnitLevel("player")) or 0) >= FROM_LEVEL
  end,
  check = function()
    local known = knownSkills()
    if not known then return nil end
    local level = NN.Plain(UnitLevel("player")) or 0
    local missing = {}
    for _, id in ipairs(data().classes[playerClass()] or {}) do
      if not known[id] and level >= (data().minLevel[id] or 0) then missing[id] = true end
    end
    local results, listed = {}, {}
    for _, city in ipairs(data().cities[faction()] or {}) do
      local weapons, trainers, ids = {}, {}, {}
      for _, trainer in ipairs(city.trainers) do
        local teaches = false
        for _, id in ipairs(trainer.skills) do
          if missing[id] and (not listed[id] or listed[id] == city) then
            if not listed[id] then listed[id] = city; weapons[#weapons + 1] = id end
            teaches = true
          end
        end
        if teaches then trainers[#trainers + 1] = trainer.name; ids[#ids + 1] = trainer.id end
      end
      if #weapons > 0 then
        local names = {}
        for _, id in ipairs(weapons) do names[#names + 1] = weaponName(id) end
        results[#results + 1] = {
          text = L.WEAPON_TRAINERS_ROW:format(table.concat(names, ", "), cityName(city),
            table.concat(trainers, " " .. L.WEAPON_TRAINERS_OR .. " ")),
          icon = SKILL_ICON,
          service = { kind = "weapon", npcIDs = ids },
        }
      end
    end
    if #results == 0 then return nil end
    return results
  end,
  sample = function()
    return { { text = L.WEAPON_TRAINERS_ROW:format("Staves", "Thunder Bluff", "Ansekhwa"), icon = SKILL_ICON } }
  end,
})
