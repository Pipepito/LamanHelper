-- Rule: trainer_spells — spells or ranks for the player's level that they
-- have not learned. Data: Data/TrainerSpells.lua (WoW Handbook, GPL-3.0),
-- keyed by spell ID so it works in any client language. Most come from the
-- class trainer; a few class spells come from quests, which the help text
-- says.
local _, NN = ...
local L = NN.L

local SPELL_ICON = 133741

local function data()
  return NN.TrainerSpells and NN.TrainerSpells[NN.classFile]
end

local function spellKnown(id)
  if IsPlayerSpell then return IsPlayerSpell(id) == true end
  if IsSpellKnown then return IsSpellKnown(id) == true end
  return false
end

local function spellExists(id)
  if C_Spell and C_Spell.DoesSpellExist then return C_Spell.DoesSpellExist(id) == true end
  return true
end

local function raceAllowed(races)
  if not races then return true end
  local _, token = UnitRace("player")
  for _, r in ipairs(races) do if r == token then return true end end
  return false
end

-- Returns the number of spells with at least one trainable rank, and the
-- list of { spell, rank, id, level } entries that are trainable.
function NN.TrainableSpells()
  local list = data()
  if not list then return 0, {} end
  local level = NN.Plain(UnitLevel("player")) or 0
  local known, candidates = {}, {}
  for _, e in ipairs(list) do
    if spellExists(e.id) and raceAllowed(e.races) then
      if spellKnown(e.id) then
        if (known[e.spell] or 0) < e.rank then known[e.spell] = e.rank end
      end
      candidates[#candidates + 1] = e
    end
  end
  local trainable, spells, count = {}, {}, 0
  for _, e in ipairs(candidates) do
    if e.rank > (known[e.spell] or 0) and e.level <= level then
      trainable[#trainable + 1] = e
      if not spells[e.spell] then spells[e.spell] = true; count = count + 1 end
    end
  end
  return count, trainable
end

local function openSpellbook()
  if ToggleSpellBook then
    ToggleSpellBook(BOOKTYPE_SPELL or "spell")
  elseif PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then
    PlayerSpellsUtil.ToggleSpellBookFrame()
  end
end

NN:RegisterRule({
  name = "trainer_spells",
  title = L.TRAINER_SPELLS_TITLE,
  help = L.TRAINER_SPELLS_HELP,
  events = { "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE" },
  applies = function() return data() ~= nil end,
  check = function()
    local count = NN.TrainableSpells()
    if count > 0 then
      return { text = L.TRAINER_SPELLS_ROW:format(count), icon = SPELL_ICON, onClick = openSpellbook, highlight = "spellbook" }
    end
    return nil
  end,
  sample = function() return { { text = L.TRAINER_SPELLS_ROW:format(3), icon = SPELL_ICON } } end,
})
