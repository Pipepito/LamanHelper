-- Rule: ammo — the character uses a ranged weapon that needs ammo and has
-- none, or fewer than 50 rounds, in the ammo slot.
local _, NN = ...
local L = NN.L

local AMMO_ICON = 132382
local LOW_THRESHOLD = 50

local function openPaperDoll() ToggleCharacter("PaperDollFrame") end

local WEAPON_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2
local AMMO_WEAPON_SUBCLASSES = { [2] = true, [3] = true, [18] = true } -- bow, gun, crossbow
local RANGED_SLOT = INVSLOT_RANGED or 18

-- Forever's UnitUsesAmmo answers true for characters without an ammo weapon,
-- so the ranged slot must hold a bow, gun or crossbow as well.
local function hasAmmoWeapon()
  local itemID = NN.Plain(GetInventoryItemID("player", RANGED_SLOT))
  if not itemID then return false end
  local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
  return NN.Plain(classID) == WEAPON_CLASS and AMMO_WEAPON_SUBCLASSES[NN.Plain(subclassID) or -1] == true
end

NN:RegisterRule({
  name = "ammo",
  group = "gear",
  title = L.AMMO_TITLE,
  help = L.AMMO_HELP,
  events = { "UNIT_INVENTORY_CHANGED:player", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" },
  combat = true,
  applies = function()
    return UnitUsesAmmo ~= nil and UnitUsesAmmo("player") == true
  end,
  check = function()
    if not GetInventoryItemCount then return nil end
    if not hasAmmoWeapon() then return nil end
    local count = NN.Plain(GetInventoryItemCount("player", INVSLOT_AMMO or 0))
    if count == nil then return NN.UNKNOWN end
    if count == 0 then
      return { text = L.AMMO_ROW_NONE, icon = AMMO_ICON, onClick = openPaperDoll, highlight = "character", service = { kind = "goods" } }
    elseif count < LOW_THRESHOLD then
      return { text = L.AMMO_ROW_LOW:format(count), icon = AMMO_ICON, onClick = openPaperDoll, highlight = "character", service = { kind = "goods" } }
    end
    return nil
  end,
  sample = function() return { { text = L.AMMO_ROW_LOW:format(20), icon = AMMO_ICON } } end,
})
