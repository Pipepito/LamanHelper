-- Rule: spell_ranks — an action bar holds an old rank of a spell whose higher
-- rank the character already knows. Clicking the row swaps every such slot.
local _, NN = ...
local L = NN.L

local MAX_ACTION_SLOT = 180
local MAX_ROWS = 3
local FALLBACK_ICON = 134400

local function swap(slots, topID, ruleName)
  if InCombatLockdown() then return end
  if GetCursorInfo and GetCursorInfo() then return end
  for _, slot in ipairs(slots) do
    C_Spell.PickupSpell(topID)
    PlaceAction(slot)
  end
  ClearCursor()
  NN:MarkDirty(ruleName)
  NN:Schedule()
end

NN:RegisterRule({
  name = "spell_ranks",
  group = "spells",
  title = L.SPELL_RANKS_TITLE,
  help = L.SPELL_RANKS_HELP,
  events = { "ACTIONBAR_SLOT_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" },
  applies = function() return true end,
  check = function()
    if not GetActionInfo then return nil end
    local byName, order = {}, {}
    for slot = 1, MAX_ACTION_SLOT do
      local kind, id = GetActionInfo(slot)
      if kind == "spell" and NN.Plain(id) and NN.Spellbook:IsLowRank(id) then
        local name = C_Spell.GetSpellName(id)
        if name then
          local entry = byName[name]
          if not entry then
            entry = { lowID = id, slots = {} }
            byName[name] = entry
            order[#order + 1] = name
          end
          entry.slots[#entry.slots + 1] = slot
        end
      end
    end
    local results = {}
    for _, name in ipairs(order) do
      local entry = byName[name]
      local topID = NN.Spellbook:TopRankByName(name)
      if topID and topID ~= entry.lowID then
        local lowRank = C_Spell.GetSpellSubtext(entry.lowID)
        local topRank = C_Spell.GetSpellSubtext(topID)
        local text
        if lowRank and topRank then
          text = L.SPELL_RANKS_ROW:format(name, lowRank, topRank)
        else
          text = L.SPELL_RANKS_ROW_NORANK:format(name)
        end
        local slots = entry.slots
        results[#results + 1] = {
          text = text,
          icon = C_Spell.GetSpellTexture(topID) or FALLBACK_ICON,
          highlight = { action = slots },
          onClick = function() swap(slots, topID, "spell_ranks") end,
        }
      end
    end
    if #results > MAX_ROWS then
      local extra = #results - MAX_ROWS
      for i = #results, MAX_ROWS + 1, -1 do results[i] = nil end
      results[MAX_ROWS + 1] = { text = L.MORE_ROWS:format(extra), icon = FALLBACK_ICON }
    end
    if #results == 0 then return nil end
    return results
  end,
  sample = function() return { { text = L.SPELL_RANKS_ROW:format("Fireball", "Rank 2", "Rank 4"), icon = 135812 } } end,
})
