-- GameSettings: the game's own options a new player should set, gathered
-- in one page with plain labels and a one-click preset. Built on
-- CVarSection; curated only, no discovery. Values live in the game's config.
local _, NN = ...
local L = NN.L

local function cb(cvar) return { cvar = cvar, kind = "checkbox", label = "GS_" .. cvar, help = "GS_" .. cvar .. "_TT" } end
local function sl(cvar, min, max, step) return { cvar = cvar, kind = "slider", min = min, max = max, step = step, label = "GS_" .. cvar, help = "GS_" .. cvar .. "_TT" } end
local function dd(cvar, options) return { cvar = cvar, kind = "dropdown", options = options, label = "GS_" .. cvar, help = "GS_" .. cvar .. "_TT" } end

local THREAT = { { "0", "GS_OPT_THREAT_OFF" }, { "1", "GS_OPT_THREAT_DUNGEONS" }, { "2", "GS_OPT_THREAT_GROUPS" }, { "3", "GS_OPT_THREAT_ALWAYS" } }
local STATUS = { { "NUMERIC", "GS_OPT_STATUS_NUMERIC" }, { "PERCENT", "GS_OPT_STATUS_PERCENT" }, { "BOTH", "GS_OPT_STATUS_BOTH" } }
local OUTLINE = { { "0", "GS_OPT_OUTLINE_OFF" }, { "1", "GS_OPT_OUTLINE_MOUSEOVER" }, { "2", "GS_OPT_OUTLINE_BOTH" } }
local FIND = { { "0", "GS_OPT_FIND_CIRCLE" }, { "1", "GS_OPT_FIND_CIRCLE_OUTLINE" }, { "2", "GS_OPT_FIND_OUTLINE" } }

-- Each entry names the options page it appears on (bags, map, combat, names,
-- interface); the preset and the reset still cover the whole list.
local CURATED = {}
local function on(page, entries)
  for _, e in ipairs(entries) do
    e.page = page
    CURATED[#CURATED + 1] = e
  end
end

on("bags", { cb("autoLootDefault"), cb("lootUnderMouse"), cb("expandBagBar"), cb("combinedBags") })
on("map", { cb("mapFade"), cb("rotateMinimap"), cb("questPOI") })
on("names", {
  cb("nameplateShowEnemies"), cb("nameplateShowEnemyMinus"), cb("nameplateShowAll"),
  cb("nameplateShowFriendlyPlayers"), cb("nameplateShowFriendlyNpcs"), cb("nameplateShowSelf"),
  sl("nameplateMaxDistance", 20, 60, 5),
  cb("UnitNameNPC"), cb("UnitNameInteractiveNPC"), cb("UnitNameFriendlyPlayerName"), cb("UnitNameEnemyPlayerName"), cb("UnitNameOwn"),
})
on("combat", {
  cb("ActionButtonUseKeyDown"), cb("autoSelfCast"), cb("lockActionBars"), cb("AutoPushSpellToActionBar"), cb("countdownForCooldowns"),
  sl("SpellQueueWindow", 0, 400, 50),
  cb("deselectOnClick"), cb("TargetEnemyAttacker"), cb("assistAttack"), cb("stopAutoAttackOnTargetChange"),
  dd("threatWarning", THREAT),
  cb("enableFloatingCombatText"), cb("floatingCombatTextCombatDamage_v2"), cb("floatingCombatTextCombatHealing_v2"),
  cb("displaySpellActivationOverlays"), sl("spellActivationOverlayOpacity", 0, 1, 0.05), cb("secureAbilityToggle"),
})
on("interface", {
  { header = "GS_GROUP_MOVE" },
  cb("interactOnLeftClick"), cb("autoDismount"), cb("autoClearAFK"), cb("autoInteract"),
  { header = "GS_GROUP_QUESTS" },
  cb("autoQuestWatch"), cb("autoQuestProgress"), cb("showQuestObjectivesInLog"), cb("ShowQuestUnitCircles"),
  cb("showTutorials"), cb("showNPETutorials"), cb("screenEdgeFlash"), cb("doNotFlashLowHealthWarning"),
  cb("statusText"), dd("statusTextDisplay", STATUS),
  dd("Outline", OUTLINE), dd("findYourselfMode", FIND), cb("chatBubbles"), cb("guildMemberNotify"), cb("Sound_EnableErrorSpeech"),
})

local GameSettings = NN.CVarSection.New({
  curated = CURATED,
  match = function() return false end,
  note = "OPT_GS_NOTE",
  resetLabel = nil, -- the page adds its own buttons below
})
NN.GameSettings = GameSettings

-- The "Recommended for new players" values. Blank rows in the design leave
-- the player's own choice alone and are simply absent here.
GameSettings.PRESET = {
  autoLootDefault = 1, lootUnderMouse = 1,
  nameplateShowEnemies = 1, nameplateShowEnemyMinus = 1, nameplateShowAll = 1,
  nameplateShowFriendlyPlayers = 0, nameplateShowFriendlyNpcs = 0,
  UnitNameNPC = 1, UnitNameInteractiveNPC = 1, UnitNameFriendlyPlayerName = 1, UnitNameEnemyPlayerName = 1,
  ActionButtonUseKeyDown = 1, autoSelfCast = 1, lockActionBars = 1, AutoPushSpellToActionBar = 1, countdownForCooldowns = 1,
  SpellQueueWindow = 400, deselectOnClick = 0, TargetEnemyAttacker = 1, stopAutoAttackOnTargetChange = 0, threatWarning = 3,
  enableFloatingCombatText = 1, floatingCombatTextCombatDamage_v2 = 1, floatingCombatTextCombatHealing_v2 = 1,
  displaySpellActivationOverlays = 1, secureAbilityToggle = 1,
  interactOnLeftClick = 1, autoDismount = 1, autoClearAFK = 1,
  autoQuestWatch = 1, autoQuestProgress = 1, showQuestObjectivesInLog = 1, questPOI = 1, ShowQuestUnitCircles = 1,
  showTutorials = 1, showNPETutorials = 1, screenEdgeFlash = 1, doNotFlashLowHealthWarning = 0,
  mapFade = 1, rotateMinimap = 0, statusText = 1, statusTextDisplay = "BOTH", expandBagBar = 1, Outline = 2, chatBubbles = 1,
}

-- Secure CVars cannot be written in combat.
function GameSettings:ApplyPreset()
  if InCombatLockdown and InCombatLockdown() then
    NN:Say(L.GS_IN_COMBAT)
    return nil
  end
  local changed = self:Apply(self.PRESET)
  NN:Say(L.GS_PRESET_DONE:format(changed))
  return changed
end

function GameSettings:Reset()
  self:ResetCurated()
end

-- One page's slice of the curated list (headers included).
function GameSettings:AddPageControls(category, layout, page)
  local entries = {}
  for _, e in ipairs(self.CURATED) do
    if e.page == page then entries[#entries + 1] = e end
  end
  self:AddControls(category, layout, entries)
end

-- The three pages that hold nothing but game settings.
for _, p in ipairs({ { "gs_combat", "OPT_GS_COMBAT", "combat" }, { "gs_names", "OPT_GS_NAMES", "names" },
                     { "gs_interface", "OPT_GS_INTERFACE", "interface" } }) do
  NN.Options.RegisterPage(p[1], p[2], function(category, layout)
    NN.Options.AddHeader(layout, L.OPT_GS_PAGE_INTRO)
    GameSettings:AddPageControls(category, layout, p[3])
  end)
end
