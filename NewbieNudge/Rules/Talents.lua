-- Rule: talents — unspent talent points. Forever's classic-style trees run on
-- the trait system, so the unspent count is the tree's currency quantity.
local _, NN = ...
local L = NN.L

local TALENT_ICON = 136116

local function openTalents()
  if ToggleTalentFrame then
    ToggleTalentFrame()
  elseif PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentFrame then
    PlayerSpellsUtil.ToggleClassTalentFrame()
  end
end

NN:RegisterRule({
  name = "talents",
  title = L.TALENTS_TITLE,
  help = L.TALENTS_HELP,
  events = { "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP" },
  applies = function() return (NN.Plain(UnitLevel("player")) or 0) >= 10 end,
  check = function()
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeCurrencyInfo) then
      return nil
    end
    local configID = NN.Plain(C_ClassTalents.GetActiveConfigID())
    if not configID then return nil end
    local info = C_Traits.GetConfigInfo(configID)
    local treeID = info and info.treeIDs and NN.Plain(info.treeIDs[1])
    if not treeID then return nil end
    local currencies = C_Traits.GetTreeCurrencyInfo(configID, treeID, false)
    local first = currencies and currencies[1]
    if not first then return nil end
    local unspent = NN.Plain(first.quantity)
    if unspent == nil then return NN.UNKNOWN end
    if unspent <= 0 then return nil end
    local text = unspent == 1 and L.TALENTS_ROW_ONE or L.TALENTS_ROW_MANY:format(unspent)
    return { text = text, icon = TALENT_ICON, onClick = openTalents, highlight = "talents" }
  end,
  sample = function() return { { text = L.TALENTS_ROW_MANY:format(2), icon = TALENT_ICON } } end,
})
