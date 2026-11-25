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

-------------------------------------------------------------------------------
-- Auto swap: when a new rank is learned, the old ranks of THAT spell on the
-- bars are replaced by it (option ranks.autoSwap). Only on learning, so a low
-- rank the player puts on a bar on purpose (downranking) is left alone.
-------------------------------------------------------------------------------

local AutoRanks = { pending = {} }
NN.AutoRanks = AutoRanks
local SWAP_DELAY = 0.5

function AutoRanks:Enabled()
  return NN.db and NN.db.ranks and NN.db.ranks.autoSwap ~= false
end

-- Swaps every bar slot holding a lower rank of a pending spell name.
function AutoRanks:Run()
  if not self:Enabled() or not GetActionInfo then wipe(self.pending); return end
  if next(self.pending) == nil then return end
  if InCombatLockdown() then return end -- PLAYER_REGEN_ENABLED runs it again
  if GetCursorInfo and GetCursorInfo() then
    C_Timer.After(1, function() AutoRanks:Run() end) -- the player is dragging something
    return
  end
  NN.Spellbook:Invalidate()
  local swapped = {}
  for slot = 1, MAX_ACTION_SLOT do
    local kind, id = GetActionInfo(slot)
    id = NN.Plain(id)
    local name = kind == "spell" and id and C_Spell.GetSpellName(id)
    if name and self.pending[name] then
      local topID = NN.Spellbook:TopRankByName(name)
      if topID and topID ~= id and NN.Spellbook:IsLowRank(id) then
        C_Spell.PickupSpell(topID)
        PlaceAction(slot)
        ClearCursor()
        swapped[name] = topID
      end
    end
  end
  wipe(self.pending)
  for name, topID in pairs(swapped) do
    local rank = C_Spell.GetSpellSubtext(topID)
    NN:Say(rank and rank ~= "" and L.SPELL_RANKS_AUTO:format(name, rank) or L.SPELL_RANKS_AUTO_NORANK:format(name))
  end
  if next(swapped) then NN:MarkDirty("spell_ranks"); NN:Schedule() end
end

function AutoRanks:Learned(spellID)
  if not self:Enabled() then return end
  local name = spellID and C_Spell.GetSpellName(spellID)
  if not name then return end
  self.pending[name] = true
  -- after the spellbook has caught up with the new rank
  C_Timer.After(SWAP_DELAY, function() AutoRanks:Run() end)
end

NN:OnAnyEvent(function(event, arg1)
  if event == "LEARNED_SPELL_IN_SKILL_LINE" then
    AutoRanks:Learned(NN.Plain(arg1))
  elseif event == "PLAYER_REGEN_ENABLED" then
    AutoRanks:Run()
  end
end)

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
  options = function(category)
    NN.Options.AddCheckbox(category, "NN_ranks_autoSwap", L.OPT_RANKS_AUTO, L.OPT_RANKS_AUTO_TT,
      function() return NN.db.ranks.autoSwap ~= false end,
      function(value) NN.db.ranks.autoSwap = value and true or false end)
  end,
})
