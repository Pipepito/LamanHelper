-- Spellbook cache: spell name -> highest known rank's spell ID.
-- Shared by the buff, spell-rank and tracking rules. Rebuilt lazily after
-- SPELLS_CHANGED / LEARNED_SPELL_IN_SKILL_LINE / PLAYER_ENTERING_WORLD.
local _, NN = ...

local Spellbook = { topByName = nil }
NN.Spellbook = Spellbook

local PLAYER_BANK = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
local SPELL_TYPE = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
local MAX_ACTION_SLOT = 180

function Spellbook:Invalidate()
  self.topByName = nil
end

function Spellbook:Refresh()
  local map = {}
  self.topByName = map
  if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return map end
  local numLines = NN.Plain(C_SpellBook.GetNumSpellBookSkillLines()) or 0
  for line = 1, numLines do
    local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
    if info and not info.offSpecID then
      local first = (info.itemIndexOffset or 0) + 1
      local last = (info.itemIndexOffset or 0) + (info.numSpellBookItems or 0)
      for slot = first, last do
        local itemType = C_SpellBook.GetSpellBookItemType(slot, PLAYER_BANK)
        if itemType == SPELL_TYPE
          and not C_SpellBook.IsSpellBookItemPassive(slot, PLAYER_BANK)
          and not C_SpellBook.IsSpellBookItemLowRank(slot, PLAYER_BANK) then
          local item = C_SpellBook.GetSpellBookItemInfo(slot, PLAYER_BANK)
          local name = item and NN.Plain(item.name, "string")
          local spellID = item and NN.Plain(item.spellID)
          if name and spellID then map[name] = spellID end
        end
      end
    end
  end
  return map
end

local function map(self)
  return self.topByName or self:Refresh()
end

function Spellbook:TopRankByName(name)
  if not name then return nil end
  return map(self)[name]
end

function Spellbook:Knows(spellID)
  local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
  return name ~= nil and map(self)[name] ~= nil
end

function Spellbook:KnowsAny(ids)
  for _, id in ipairs(ids) do
    if self:Knows(id) then return true end
  end
  return false
end

function Spellbook:IsLowRank(spellID)
  if not (C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell and C_SpellBook.IsSpellBookItemLowRank) then
    return false
  end
  local slot, bank = C_SpellBook.FindSpellBookSlotForSpell(spellID)
  if not slot then return false end
  return C_SpellBook.IsSpellBookItemLowRank(slot, bank or PLAYER_BANK) == true
end

-- Action slots (1..180) holding any rank of the named spell, ascending.
function Spellbook:ActionSlotsForName(name)
  local slots = {}
  if not name or not GetActionInfo then return slots end
  for slot = 1, MAX_ACTION_SLOT do
    local kind, id = GetActionInfo(slot)
    if kind == "spell" and id and C_Spell.GetSpellName(id) == name then
      slots[#slots + 1] = slot
    end
  end
  return slots
end

NN:OnAnyEvent(function(event)
  if event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_SKILL_LINE" or event == "PLAYER_ENTERING_WORLD" then
    Spellbook:Invalidate()
  end
end)
NN:RegisterEvent("LEARNED_SPELL_IN_SKILL_LINE")
