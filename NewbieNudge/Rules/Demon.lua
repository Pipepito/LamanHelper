-- Rule: demon — a warlock who knows a summon spell but has no demon out.
-- The hunter pet rule's quiet conditions apply: nothing while resting,
-- mounted or dead. The bar button of a known summon spell glows.
local _, NN = ...
local L = NN.L

local DEMON_ICON = 136218
-- Summon Imp, Summon Voidwalker, Summon Succubus, Summon Felhunter (base IDs)
local SUMMONS = { 688, 697, 712, 691 }

local function spellKnown(id)
  if IsPlayerSpell then return IsPlayerSpell(id) == true end
  if IsSpellKnown then return IsSpellKnown(id) == true end
  return false
end

local function knownSummons()
  local out = {}
  for _, id in ipairs(SUMMONS) do if spellKnown(id) then out[#out + 1] = id end end
  return out
end

local function summonSlots(ids)
  local slots = {}
  for _, id in ipairs(ids) do
    local name = C_Spell and C_Spell.GetSpellName and NN.Plain(C_Spell.GetSpellName(id), "string")
    for _, slot in ipairs(name and NN.Spellbook:ActionSlotsForName(name) or {}) do slots[#slots + 1] = slot end
  end
  table.sort(slots)
  return slots
end

NN:RegisterRule({
  name = "demon",
  title = L.DEMON_TITLE,
  help = L.DEMON_HELP,
  events = { "UNIT_PET:player", "PLAYER_UPDATE_RESTING", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_LEVEL_UP" },
  combat = true,
  applies = function() return NN.classFile == "WARLOCK" and #knownSummons() > 0 end,
  check = function()
    if UnitExists("pet") then return nil end
    if IsMounted() or IsResting() or UnitIsDeadOrGhost("player") then return nil end
    local slots = summonSlots(knownSummons())
    local result = { text = L.DEMON_ROW_MISSING, icon = DEMON_ICON }
    if #slots > 0 then result.highlight = { action = slots } else result.highlight = "spellbook" end
    return result
  end,
  sample = function() return { { text = L.DEMON_ROW_MISSING, icon = DEMON_ICON } } end,
})
