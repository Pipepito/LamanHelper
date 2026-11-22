-- Rule: trainer_spells — spells or ranks for the player's level that they
-- have not learned. Data: Data/TrainerSpells.lua (WoW Handbook, GPL-3.0),
-- keyed by spell ID so it works in any client language. Class quest spells
-- (Data/ClassQuestSpells.lua) get rows of their own; warlock demon abilities
-- (pet = true) are learned by the demon and left out.
local _, NN = ...
local L = NN.L

local SPELL_ICON = 133741
local MAX_QUEST_ROWS = 2

local function questSet()
  local set = {}
  for _, q in ipairs((NN.ClassQuestSpells and NN.ClassQuestSpells[NN.classFile]) or {}) do set[q.id] = true end
  return set
end

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
  local quests = questSet()
  for _, e in ipairs(list) do
    if not e.pet and not quests[e.id] and spellExists(e.id) and raceAllowed(e.races) then
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

-- Class quest spells the player is old enough for and doesn't know:
-- { { id, level, name }, ... } in table order.
function NN.ClassQuestSpellsDue()
  local out = {}
  local level = NN.Plain(UnitLevel("player")) or 0
  for _, q in ipairs((NN.ClassQuestSpells and NN.ClassQuestSpells[NN.classFile]) or {}) do
    if q.level <= level and spellExists(q.id) and not spellKnown(q.id) then
      local name = C_Spell and C_Spell.GetSpellName and NN.Plain(C_Spell.GetSpellName(q.id), "string")
      out[#out + 1] = { id = q.id, level = q.level, name = name or tostring(q.id) }
    end
  end
  return out
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
  group = "spells",
  title = L.TRAINER_SPELLS_TITLE,
  help = L.TRAINER_SPELLS_HELP,
  events = { "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE" },
  applies = function() return data() ~= nil end,
  check = function()
    local results = {}
    local service = { kind = "trainer_" .. tostring(NN.classFile) }
    local count = NN.TrainableSpells()
    if count > 0 then
      results[#results + 1] = { text = L.TRAINER_SPELLS_ROW:format(count), icon = SPELL_ICON, onClick = openSpellbook,
        highlight = "spellbook", service = service }
    end
    local quests = NN.ClassQuestSpellsDue()
    for i, q in ipairs(quests) do
      if i > MAX_QUEST_ROWS then
        results[#results + 1] = { text = L.TRAINER_SPELLS_ROW_QUEST_MORE:format(#quests - MAX_QUEST_ROWS), icon = SPELL_ICON,
          service = { kind = service.kind } }
        break
      end
      results[#results + 1] = { text = L.TRAINER_SPELLS_ROW_QUEST:format(q.level, q.name), icon = SPELL_ICON,
        service = { kind = service.kind } }
    end
    if #results == 0 then return nil end
    return results
  end,
  sample = function() return { { text = L.TRAINER_SPELLS_ROW:format(3), icon = SPELL_ICON } } end,
})
