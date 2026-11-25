-- Rule: buffs — long-duration self-buffs the character knows but does not
-- have up. The action-bar button that casts the buff glows.
local _, NN = ...
local L = NN.L

local MAX_ROWS = 3
local FALLBACK_ICON = 134400

local function openSpellbook()
  if ToggleSpellBook then
    ToggleSpellBook("spell")
  elseif PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then
    PlayerSpellsUtil.ToggleSpellBookFrame()
  end
end

-- True when the main hand carries a temporary enchant (poison, imbue, stone).
function NN.MainHandEnchanted()
  local f = (C_Item and C_Item.GetWeaponEnchantInfo) or GetWeaponEnchantInfo
  if not f then return nil end
  local r = f()
  if type(r) == "table" then return NN.Plain(r.hasMainHandEnchant, "boolean") end
  return NN.Plain(r, "boolean")
end

local function auraActive(ids)
  for _, id in ipairs(ids) do
    if C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(id) then return true end
    local name = C_Spell.GetSpellName(id)
    if name and C_UnitAuras.GetAuraDataBySpellName and C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL") then
      return true
    end
  end
  return false
end

-- First spell of the group the character can cast. Passive spells are
-- skipped: their aura is always on (or never shows), there is nothing to cast.
local function firstKnown(ids)
  for _, id in ipairs(ids) do
    if NN.Spellbook:Knows(id) and not NN.Spellbook:IsPassive(id) then return id end
  end
  return nil
end

local function resultFor(group, knownID)
  local baseName = C_Spell.GetSpellName(knownID)
  local topID = NN.Spellbook:TopRankByName(baseName) or knownID
  local name = C_Spell.GetSpellName(topID) or baseName
  local icon = C_Spell.GetSpellTexture(topID) or FALLBACK_ICON
  local slots = NN.Spellbook:ActionSlotsForName(name)
  local fmt = group.weapon and L.BUFFS_ROW_WEAPON or L.BUFFS_ROW
  if #slots > 0 then
    return { text = fmt:format(name), icon = icon, highlight = { action = slots } }
  end
  return { text = (group.weapon and L.BUFFS_ROW_WEAPON or L.BUFFS_ROW_NOT_ON_BAR):format(name), icon = icon,
           highlight = "spellbook", onClick = openSpellbook }
end

NN:RegisterRule({
  name = "buffs",
  group = "spells",
  title = L.BUFFS_TITLE,
  help = L.BUFFS_HELP,
  events = { "UNIT_AURA:player", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED" },
  applies = function() return NN.BuffData[NN.classFile] ~= nil end,
  check = function()
    local groups = NN.BuffData[NN.classFile]
    if not groups then return nil end
    local results = {}
    for _, group in ipairs(groups) do
      local knownID = firstKnown(group.ids)
      if knownID then
        local satisfied
        if group.weapon then
          satisfied = NN.MainHandEnchanted()
          if satisfied == nil then return NN.UNKNOWN end
        else
          satisfied = auraActive(group.ids)
        end
        if not satisfied then results[#results + 1] = resultFor(group, knownID) end
      end
    end
    if #results > MAX_ROWS then
      local extra = #results - MAX_ROWS
      for i = #results, MAX_ROWS + 1, -1 do results[i] = nil end
      results[MAX_ROWS + 1] = { text = L.MORE_ROWS:format(extra), icon = FALLBACK_ICON, highlight = "spellbook" }
    end
    if #results == 0 then return nil end
    return results
  end,
  sample = function() return { { text = L.BUFFS_ROW:format("Arcane Intellect"), icon = 135932 } } end,
})
