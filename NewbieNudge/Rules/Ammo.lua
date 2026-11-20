-- Rule: ammo — the character uses a ranged weapon that needs ammo and has
-- none, or fewer than 50 rounds, in the ammo slot.
local _, NN = ...
local L = NN.L

local AMMO_ICON = 132382
local LOW_THRESHOLD = 50

local function openPaperDoll() ToggleCharacter("PaperDollFrame") end

NN:RegisterRule({
  name = "ammo",
  title = L.AMMO_TITLE,
  help = L.AMMO_HELP,
  events = { "UNIT_INVENTORY_CHANGED:player", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" },
  combat = true,
  applies = function()
    return UnitUsesAmmo ~= nil and UnitUsesAmmo("player") == true
  end,
  check = function()
    if not GetInventoryItemCount then return nil end
    local count = NN.Plain(GetInventoryItemCount("player", INVSLOT_AMMO or 0))
    if count == nil then return NN.UNKNOWN end
    if count == 0 then
      return { text = L.AMMO_ROW_NONE, icon = AMMO_ICON, onClick = openPaperDoll, highlight = "character" }
    elseif count < LOW_THRESHOLD then
      return { text = L.AMMO_ROW_LOW:format(count), icon = AMMO_ICON, onClick = openPaperDoll, highlight = "character" }
    end
    return nil
  end,
  sample = function() return { { text = L.AMMO_ROW_LOW:format(20), icon = AMMO_ICON } } end,
})
