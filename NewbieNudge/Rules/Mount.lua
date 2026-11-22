-- Rule: mount — riding and a mount cost about 100 gold at level 40 (Icy
-- Veins leveling guides). From 30: save up when short. From 40: learn to
-- ride, when the skill API can tell whether Riding is known.
local _, NN = ...
local L = NN.L

local MOUNT_ICON = 132261
local SAVE_FROM_LEVEL, RIDE_LEVEL = 30, 40
local MOUNT_COST = 1000000 -- copper

local moneyText = NN.MoneyText

-- true / false when a skill API can answer, nil when none can (Task 8 wires
-- the real skill-line lookup; until then the riding row stays silent).
function NN.HasRidingSkill()
  if NN.SkillLines then
    for _, line in ipairs(NN.SkillLines() or {}) do
      if line.isRiding then return true end
    end
    return false
  end
  return nil
end

NN:RegisterRule({
  name = "mount",
  group = "travel",
  title = L.MOUNT_TITLE,
  help = L.MOUNT_HELP,
  events = { "PLAYER_MONEY", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED" },
  applies = function() return (NN.Plain(UnitLevel("player")) or 0) >= SAVE_FROM_LEVEL end,
  check = function()
    local level = NN.Plain(UnitLevel("player"))
    if level == nil then return NN.UNKNOWN end
    if level < RIDE_LEVEL then
      local money = GetMoney and NN.Plain(GetMoney())
      if money == nil then return NN.UNKNOWN end
      if money < MOUNT_COST then
        return { text = L.MOUNT_ROW_SAVE:format(moneyText(money)), icon = MOUNT_ICON }
      end
      return nil
    end
    if NN.HasRidingSkill() == false then
      return { text = L.MOUNT_ROW_RIDE, icon = MOUNT_ICON }
    end
    return nil
  end,
  sample = function() return { { text = L.MOUNT_ROW_SAVE:format("42g"), icon = MOUNT_ICON } } end,
})
