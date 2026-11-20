-- Rule: legacy — Forever's Legacy system (account-wide challenges and
-- perks) opens around level 25 and lives behind the Y key. The client offers
-- no scripting API for it (checked 2026-11-20), only the window toggle and a
-- table of challenge IDs the player has not looked at yet. So: one nudge at
-- the unlock until the window is opened, and a row while that table is
-- non-empty.
local _, NN = ...
local L = NN.L

local LEGACY_ICON = 134419
local UNLOCK_LEVEL = 25

local function windowAvailable()
  return type(ToggleLegacySystemUI) == "function"
end

local function hasUnviewed()
  return type(LegacyChallengesUnviewed) == "table" and next(LegacyChallengesUnviewed) ~= nil
end

local function openLegacy()
  if windowAvailable() then ToggleLegacySystemUI() end
end

-- Opening the window, by us or by the player, counts as having seen it. The
-- window's code can load late, so the hook is installed whenever it is first
-- seen to exist.
local function ensureHook()
  if windowAvailable() and not NN.legacyHooked then
    NN.legacyHooked = true
    hooksecurefunc("ToggleLegacySystemUI", function()
      if NN.db then NN.db.seen.legacy = true; NN:MarkDirty("legacy"); NN:Schedule() end
    end)
  end
end
NN:AfterLogin(ensureHook)

NN:RegisterRule({
  name = "legacy",
  title = L.LEGACY_TITLE,
  help = L.LEGACY_HELP,
  events = { "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" },
  applies = function()
    ensureHook()
    return windowAvailable() and (NN.Plain(UnitLevel("player")) or 0) >= UNLOCK_LEVEL
  end,
  check = function()
    local results = {}
    if not NN.db.seen.legacy then
      results[#results + 1] = { text = L.LEGACY_ROW_UNLOCK, icon = LEGACY_ICON, onClick = openLegacy }
    end
    if hasUnviewed() then
      results[#results + 1] = { text = L.LEGACY_ROW_CHALLENGES, icon = LEGACY_ICON, onClick = openLegacy }
    end
    if #results == 0 then return nil end
    return results
  end,
  sample = function() return { { text = L.LEGACY_ROW_UNLOCK, icon = LEGACY_ICON } } end,
})
