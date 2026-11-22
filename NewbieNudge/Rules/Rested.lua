-- Rule: rested — the game menu was opened (likely to log out) outside an inn
-- or city. Shows a row while the menu is open and says it once in chat.
local _, NN = ...
local L = NN.L

local RESTED_ICON = 136081

NN.restedPrompt = false
NN.restedSaid = false

local function onMenuShow()
  NN.restedPrompt = not IsResting()
  if NN.restedPrompt and not NN.restedSaid and NN:Applies(NN.ruleByName.rested) then
    NN.restedSaid = true
    NN:Say(L.RESTED_ROW)
  end
  NN:MarkDirty("rested")
  NN:Schedule()
end

local function onMenuHide()
  NN.restedPrompt = false
  NN:MarkDirty("rested")
  NN:Schedule()
end

NN:RegisterRule({
  name = "rested",
  group = "travel",
  title = L.RESTED_TITLE,
  help = L.RESTED_HELP,
  events = { "PLAYER_UPDATE_RESTING" },
  applies = function()
    local level = NN.Plain(UnitLevel("player")) or 0
    local max = (GetMaxPlayerLevel and NN.Plain(GetMaxPlayerLevel())) or 60
    return level < max
  end,
  check = function()
    if NN.restedPrompt and not IsResting() then
      return { text = L.RESTED_ROW, icon = RESTED_ICON, service = { kind = "inn" } }
    end
    return nil
  end,
  sample = function() return { { text = L.RESTED_ROW, icon = RESTED_ICON } } end,
})

NN:AfterLogin(function()
  if GameMenuFrame and GameMenuFrame.HookScript then
    GameMenuFrame:HookScript("OnShow", onMenuShow)
    GameMenuFrame:HookScript("OnHide", onMenuHide)
  end
end)
