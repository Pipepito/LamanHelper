# NewbieNudge — design spec

Date: 2026-11-20
Target game: World of Warcraft Forever (Mainline-based client, TOC interface `16001`)
Status: approved in brainstorming, awaiting implementation plan

## 1. Purpose

A low-maintenance addon that shows new Forever players a short list of things
they should do or keep an eye on, and highlights the default UI button that
fixes each one. Reminders appear only when relevant to the character, only
while the condition holds, and disappear on their own once fixed.

Goals:
- Help a newbie who can drop a folder in `Interface\AddOns` and nothing more.
- Near-zero maintenance: derive everything live from the character; the only
  hand-kept data is a per-class buff name list and the TOC interface number.
- Never break the UI: a faulty reminder disables itself, the rest keep working.

Also in scope for version one:
- Localization: English (default) and Spanish (`esES` only). The language is
  whatever the game client is set to; the addon has no language option.
- An options window in the Blizzard Settings panel.
- A compact in-combat mode that keeps the still-readable reminders live and
  freezes the rest.

Non-goals (for version one):
- "New spells at the trainer" reminders. Planned for v2; see section 9.
- Reading buffs, cooldowns or unit stats in combat, dungeons, raids or PvP.
  Forever applies Midnight's secret-value restrictions there, so rules that
  depend on those values freeze in combat instead of re-evaluating.

## 2. Platform facts the design relies on

- Forever addons live in `World of Warcraft\_forever_\Interface\AddOns`.
- TOC: `## Interface: 16001`, `## AllowLoadGameType: forever`, and
  `## ExcludeLoadGameType: standard, classic`. `WOW_PROJECT_ID ==
  WOW_PROJECT_CAMELOT` is the runtime check.
- APIs confirmed in use by addons installed on this machine:
  `C_Container.*`, `C_UnitAuras.GetAuraDataBySpellName`,
  `C_UnitAuras.GetPlayerAuraBySpellID`, `C_Traits.GetTreeCurrencyInfo`,
  `C_ClassTalents.GetActiveConfigID`, `C_SpellBook.IsSpellBookItemLowRank`,
  `C_SpellBook.FindSpellBookSlotForSpell`, `C_Spell.PickupSpell`,
  `PlaceAction`, `GetActionInfo`.
- APIs documented for 1.60.1 but not yet verified live on this machine:
  `UnitUsesAmmo`, `C_PaperDollInfo.AmmoNeeded`, `C_PetInfo.GetPetHappiness`,
  `C_PetInfo.GetPetTrainingPoints`, `C_SkillInfo.GetNumSkillLines`,
  `C_SkillInfo.GetSkillLineInfo`, `C_Item.GetWeaponEnchantInfo`.
  Rules built on these must stay silent when the function is missing or
  returns nothing or a secret value.
- Secret values: any value for which `issecretvalue(v)` is true must be
  treated as "unknown" and the rule must return "nothing to say".

## 3. Architecture

```
NewbieNudge/
  NewbieNudge.toc
  Locales/
    enUS.lua        -- every user-facing string, the fallback
    esES.lua        -- Spanish (Spain); loads only when the client locale is esES
  Core.lua          -- event hub, scheduler, rule registry, saved variables, slash command
  Panel.lua         -- the reminder frame, row widgets, and the compact combat strip
  Highlight.lua     -- pulsing glow on default UI buttons
  Options.lua       -- Blizzard Settings panel page
  Data_Buffs.lua    -- per-class buff name list (the only hand-maintained data)
  Rules/
    Bags.lua        -- unequipped/better bag, bags nearly full
    Talents.lua     -- unspent talent points
    Buffs.lua       -- missing self-buffs, weapon enhancements
    SpellRanks.lua  -- low-rank spells on action bars
    Tracking.lua    -- gathering tracking not enabled
    Durability.lua
    Ammo.lua
    Pet.lua         -- hunter pet absent / unhappy / training points
    Professions.lua -- no primary profession
    Hearthstone.lua
    QuestLog.lua
    Mail.lua
    Rested.lua      -- logging out outside an inn
    GearUpgrade.lua -- better gear in bags (off by default)
```

### 3.1 Rule interface

Every file under `Rules/` registers one or more rule tables with
`NewbieNudge:RegisterRule(rule)`. A rule is:

```lua
{
  name     = "talents",         -- unique, lowercase, used by /nudge, options and snoozes
  title    = L.TALENTS_TITLE,   -- shown in /nudge list and the options window
  help     = L.TALENTS_HELP,    -- tooltip text
  events   = { "TRAIT_TREE_CURRENCY_INFO_UPDATED", "PLAYER_LEVEL_UP" },
  default  = true,              -- enabled unless the player turns it off
  combat   = false,             -- true if check() stays reliable in combat (see 3.6)
  applies  = function() ... end,  -- true if this rule can ever matter for this character
  check    = function() ... end,  -- nil when fine, else one result or a list of results
}
```

A result is:

```lua
{
  text      = L.TALENTS_ROW:format(2),  -- "You have 2 unspent talent points."
  icon      = 136116,                   -- texture file ID or path
  onClick   = function() ... end,       -- optional; left-click action
  highlight = "talents",                -- optional; a key from 3.7, or { action = { slots } }
}
```

`check()` may return a list of results when one rule has several distinct
things to say (missing buffs, low-rank spells). Each result becomes a row;
snoozing applies to the whole rule.

Rules never create frames and never print to chat. The one exception is
`rested`, which prints a single line through `NewbieNudge:Say()`.

### 3.2 Core

- On `PLAYER_LOGIN`: load saved variables, call `applies()` on every rule once,
  keep the ones that return true, and register the union of their events.
  `applies()` is re-run on `PLAYER_LEVEL_UP`, `SPELLS_CHANGED` and
  `PLAYER_SPECIALIZATION_CHANGED`, because a rule can become relevant later
  (a hunter reaching level 10, a character learning Herbalism).
- Event handling: any registered event marks the rules that listen to it as
  dirty. A single timer runs at most every 0.5 s and re-checks only dirty
  rules. A full re-check of every rule happens on `PLAYER_ENTERING_WORLD`
  and `PLAYER_REGEN_ENABLED` (leaving combat).
- Gating: while `InCombatLockdown()` is true, or `C_RestrictedActions`
  reports addon restrictions active, or the player is in a party or raid
  instance, only rules flagged `combat = true` are re-checked. All other rules
  keep their last known results, shown as stale (see 3.6). Any result built
  from a value for which `issecretvalue()` is true is discarded and the rule's
  previous result is kept.
- Safety: each `check()` runs through `pcall`. On error the rule is disabled
  for the session, its rows are removed, and one chat line names the rule and
  says to report it. The message is stored in `NewbieNudgeDB.errors[name]`
  so a bug report can include it.
- Saved variables (`NewbieNudgeDB`, per character):
  `disabled = { [name] = true }`, `snoozed = { [name] = expiryTime }`,
  `panel = { point, x, y, locked, scale }`, `combatStrip = true`,
  `snoozeMinutes = 60`, `errors = {}`.
  A snooze with expiry `0` means "until next login" and is cleared at
  `PLAYER_LOGIN`.

### 3.3 Slash command `/nudge`

| Command | Effect |
|---|---|
| `/nudge` | Open the options window. |
| `/nudge lock` | Toggle panel lock. Unlocked shows the title bar and allows dragging. |
| `/nudge list` | Print every rule with its title, on/off and snoozed state. |
| `/nudge off <name>` / `/nudge on <name>` | Disable or enable a rule for this character. |
| `/nudge reset` | Clear every snooze, leave test mode, and re-check now. |
| `/nudge test` | Show every rule with sample text for layout checking. |

### 3.4 Options window

Registered in the Blizzard Settings panel (Escape → Options → AddOns →
NewbieNudge) through `Settings.RegisterVerticalLayoutCategory` and
`Settings.RegisterAddOnCategory`, so it looks native and needs no library.
Contents, top to bottom:

1. **General**: lock panel position (checkbox), panel scale (slider 0.8–1.5),
   snooze length in minutes (slider 15–240, step 15), show compact strip in
   combat (checkbox), "Reset snoozes" and "Reset position" buttons.
2. **Reminders**: one checkbox per rule, labelled with the rule's `title`,
   with the rule's `help` text as the tooltip. Rules whose `applies()` is
   false for this character are still listed but shown greyed with the note
   "Not relevant for this character".

All controls read and write `NewbieNudgeDB` directly through
`Settings.RegisterAddOnSetting` with a proxy table, so there is no separate
settings copy to keep in sync. Changing any reminder checkbox triggers a
re-check.

### 3.5 Localization

- `Locales/enUS.lua` creates `NewbieNudge.L` as a table with every string,
  and sets a metatable whose `__index` returns the key itself, so a missing
  translation shows the English key text rather than erroring. It always
  loads; it serves both `enUS` and `enGB` clients, and is the fallback for
  every other locale.
- `Locales/esES.lua` runs only when `GetLocale()` returns `esES` and
  overwrites the keys it translates. Any other client language, including
  `esMX`, gets English. There is no language setting in the addon; the game's
  own language setting decides.
- Strings use `%s` and `%d` placeholders with `string.format`; no string
  concatenation of sentence fragments, so Spanish word order can differ.
- Spell and item **names** are never localized by hand. The buff list in
  `Data_Buffs.lua` holds English names, and `C_Spell.GetSpellInfo` resolves
  them to IDs on an English client only. To work on a Spanish client the list
  is keyed by spell ID with the English name as a comment, and the displayed
  name comes from the client (`C_Spell.GetSpellName(id)`). Section 4.4 spells
  out the matching. Each group lists only base-rank IDs, on the assumption
  that `C_SpellBook.IsSpellKnown` and the aura lookup by name cover higher
  ranks. If live testing shows otherwise, the group holds the IDs of all ranks.
- The TOC carries `## Title-esES` and `## Notes-esES`.

### 3.6 Panel

- One frame, movable when unlocked, position and scale saved. Width fixed at
  about 260 px; height follows the row count. Hidden when there are zero
  active rows. Default anchor: right side of the screen, below the minimap.
- Row: 20 px icon, one line of text (wraps to two if needed), subtle
  background. Hover shows a tooltip with the rule's `help` text.
- Left-click: run `onClick` if present, else nothing.
- Right-click: snooze the rule for 60 minutes. Shift-right-click: snooze until
  next login. A snoozed row disappears immediately.
- Rows are ordered by a fixed priority list (durability, bags, talents,
  spell ranks, buffs, then the rest) so the most urgent items sit on top.

**Compact combat strip.** On `PLAYER_REGEN_DISABLED` the panel swaps to a
single horizontal row of 24 px icons at the same anchor, one icon per active
result, no text. Rules flagged `combat = true` (ammo, pet, bag_full,
durability, bag_unequipped, hearthstone, mail) keep updating; a result that
newly appears in combat pulses its icon three times. Results from rules with
`combat = false` stay at their last known state and dim to 50 percent alpha
so the player can see they are stale. Hovering an icon shows its text and
help in a tooltip. On `PLAYER_REGEN_ENABLED` the strip expands back into the
full checklist and every rule is re-checked. The strip is disabled by the
"show compact strip in combat" option, in which case the panel hides in
combat. The strip never highlights default UI buttons.

### 3.7 Highlights

`Highlight.lua` maps a key to a default UI frame and pulses it while any
active row names that key. Keys and targets:

| Key | Frame |
|---|---|
| `bags` | `MainMenuBarBackpackButton` |
| `talents` | `TalentMicroButton` (fallback `PlayerSpellsMicroButton`) |
| `spellbook` | `SpellbookMicroButton` (fallback `PlayerSpellsMicroButton`) |
| `character` | `CharacterMicroButton` |
| `quests` | `QuestLogMicroButton` |
| `tracking` | `MinimapCluster.Tracking.Button` |
| `mail` | `MinimapCluster.IndicatorFrame.MailFrame` |

A second kind of target is an **action slot**: a result may set
`highlight = { action = { slot1, slot2, ... } }`. `Highlight.lua` resolves each
slot to the on-screen button by walking the default bars (`ActionButton1-12`,
`MultiBarBottomLeftButton`, `MultiBarBottomRightButton`, `MultiBarRightButton`,
`MultiBarLeftButton`, `MultiBar5Button`, `MultiBar6Button`, `MultiBar7Button`)
and comparing each button's `action` (via `button:GetAttribute("action")` or
`button.action`, whichever the client exposes), with paging taken into account
through `GetActionInfo` matching the spell ID rather than the raw slot number.
The resolved button list is cached and rebuilt on `ACTIONBAR_SLOT_CHANGED`,
`ACTIONBAR_PAGE_CHANGED` and `UPDATE_BONUS_ACTIONBAR`. Third-party bar addons
are not supported in version one; with no matching default button the fallback
in the rule applies.

The glow uses Blizzard's `ActionButton_ShowOverlayGlow` /
`ActionButton_HideOverlayGlow` when available (the same proc glow the default
UI uses, so it looks native), otherwise a simple alpha pulse of a yellow border
texture created once per target. Glows are removed the moment the result that
asked for them disappears. Frame names are looked up lazily; a missing frame
means no highlight and no error. Glows are never applied or removed while
`InCombatLockdown()` is true on a protected frame; action buttons are not
protected for texture changes, so glowing them in combat is allowed, but the
buff rule itself does not update in combat (3.6), so its glows freeze too.

## 4. Rules

Each rule below lists: when it applies, the condition, the text, the click
action, the highlight, and the events that trigger a re-check. "Any" under
applies means every character. Text is shown in English; every string is a
key in the locale files. Rules marked **combat** carry `combat = true` and
keep updating in combat (3.6); all others freeze.

### 4.1 `bag_unequipped` — a bag not in use (combat)
- Applies: any.
- Condition: a container item (item class Container; quivers and ammo pouches
  count only when the character uses ammo) sits in bags **and** either a bag
  slot (inventory slots 20–23) is empty, or that container has more slots than
  the smallest equipped bag. The reagent bag slot is ignored.
- Text: "You have a bag in your inventory that isn't equipped." or
  "A bag in your inventory is bigger than one you're using."
- Click: `ToggleAllBags()`. Highlight: `bags`.
- Events: `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`.

### 4.2 `bag_full` — bags nearly full (combat)
- Applies: any.
- Condition: `C_Container.GetContainerNumFreeSlots` summed over bags 0–4
  (regular bag family only) is below 3.
- Text: "Your bags are almost full (N slots left)."
- Click: `ToggleAllBags()`. Highlight: `bags`.
- Events: `BAG_UPDATE_DELAYED`.

### 4.3 `talents` — unspent talent points
- Applies: level 10 or higher.
- Condition: `C_Traits.GetTreeCurrencyInfo(configID, treeID, false)[1].quantity > 0`
  where `configID = C_ClassTalents.GetActiveConfigID()` and `treeID` comes from
  `C_Traits.GetConfigInfo(configID).treeIDs[1]`.
- Text: "You have N unspent talent point(s)."
- Click: `ToggleTalentFrame()` (fallback `PlayerSpellsUtil.ToggleClassTalentFrame`).
  Highlight: `talents`.
- Events: `TRAIT_TREE_CURRENCY_INFO_UPDATED`, `TRAIT_CONFIG_UPDATED`,
  `PLAYER_LEVEL_UP`, `PLAYER_TALENT_UPDATE`.

### 4.4 `buffs` — self-buffs not active
- Applies: class has entries in `Data_Buffs.lua`.
- Data shape: a per-class list of groups; a group is one or more spell IDs
  (base rank, English name as a comment), satisfied when **any** aura in the
  group is on the player. Example for Mage:
  `{ 1459 --[[Arcane Intellect]] }`, `{ 168 --[[Frost Armor]], 7302 --[[Ice Armor]], 6117 --[[Mage Armor]] }`.
  Groups whose spells the character does not know are skipped. Knowledge is
  checked with `C_SpellBook.IsSpellKnown(spellID)`; presence with
  `C_UnitAuras.GetPlayerAuraBySpellID`, falling back to
  `C_UnitAuras.GetAuraDataBySpellName(C_Spell.GetSpellName(spellID))` so a
  higher rank's aura still satisfies the group. Displayed names come from
  `C_Spell.GetSpellName`, so they are already in the client's language.
- Weapon enhancements are groups flagged `weapon = true` (Rogue poisons,
  Shaman imbues). They are satisfied when `C_Item.GetWeaponEnchantInfo()`
  reports a main-hand temporary enchant. The off-hand is not checked.
- Condition: at least one known group has no active aura.
- Text: "Buff missing: Arcane Intellect" (one row per missing group, capped
  at 3 rows, then "…and N more").
- Highlight: the **action bar buttons** that cast any spell in the missing
  group (any rank), found through the `action` highlight target (3.7). This is
  the main visual cue, so the player sees the glow on the exact button to
  press. If no bar button holds the spell, the highlight falls back to
  `spellbook` and the row text adds "(not on your action bar)".
- Click: an addon cannot cast from a plain click, so the click opens the
  spellbook to the spell's tab when no bar button holds it, else does nothing.
- Events: `UNIT_AURA` (player only, via `RegisterUnitEvent`), `SPELLS_CHANGED`,
  `PLAYER_ENTERING_WORLD`.
- The buff list ships with: Mage, Priest, Druid, Warlock, Shaman, Paladin,
  Hunter (Aspects), Rogue (poisons). Warriors get no entries. Each class list
  is a handful of lines. Base-rank IDs are stable across rebalances; if a
  live check shows an ID no longer exists, the group is skipped silently.

### 4.5 `spell_ranks` — higher rank known but low rank on the bar
- Applies: any.
- Condition: for action slots 1–180, `GetActionInfo(slot)` returns a spell
  whose `C_SpellBook.FindSpellBookSlotForSpell` slot is reported low rank by
  `C_SpellBook.IsSpellBookItemLowRank`. Pet bar excluded. Macros excluded.
- Text: "Fireball on your action bar is Rank 2; you know Rank 4." (one row
  per distinct spell name, capped at 3, then "…and N more"). Rank text comes
  from `C_Spell.GetSpellSubtext`.
- Highlight: `{ action = { the low-rank slots } }` so the exact button glows.
- Click: for each low-rank slot of that spell, `C_Spell.PickupSpell(topRankID)`
  then `PlaceAction(slot)`, then `ClearCursor()`. Only when not in combat and
  the cursor is empty. The top rank is the spellbook entry with the same name
  for which `IsSpellBookItemLowRank` is false.
- Events: `ACTIONBAR_SLOT_CHANGED`, `LEARNED_SPELL_IN_SKILL_LINE`,
  `SPELLS_CHANGED`.

### 4.6 `tracking` — gathering tracking not set
- Applies: the character knows Find Herbs (spell 2383) or Find Minerals
  (spell 2580). (Skinning has no tracking spell. Track Beasts is a hunter
  combat tool, so it is not nagged about.) Checked with
  `C_SpellBook.IsSpellKnown`.
- Condition: `C_Minimap.GetNumTrackingTypes` / `C_Minimap.GetTrackingInfo(i)`
  shows none of the applicable tracking types active.
- Text: "Turn on Find Herbs on the minimap to spot herbs." (first applicable).
- Click: `C_Minimap.SetTracking(index, true)` for the first applicable type.
  Highlight: `tracking`.
- Events: `MINIMAP_UPDATE_TRACKING`, `SPELLS_CHANGED`, `PLAYER_ENTERING_WORLD`.

### 4.7 `durability` — gear damaged or broken (combat)
- Applies: any.
- Condition: any equipped slot 1–17 where `GetInventoryItemDurability`
  returns current/max below 0.20, or current equal to 0.
- Text: "Some of your gear is below 20% durability." or "You have broken
  gear; repair it at a vendor."
- Click: `ToggleCharacter("PaperDollFrame")`. Highlight: `character`.
- Events: `UPDATE_INVENTORY_DURABILITY`, `PLAYER_EQUIPMENT_CHANGED`.

### 4.8 `ammo` — no ammo or running low (combat)
- Applies: `UnitUsesAmmo` exists and returns true for `"player"`.
- Condition: ammo count from the ammo slot, `GetInventoryItemCount("player", 0)`,
  is 0 or below 50. `C_PaperDollInfo.AmmoNeeded` is used only to confirm the
  equipped ranged weapon needs ammo at all.
- Text: "You're out of ammo." / "Ammo is running low (N left)."
- Click: `ToggleCharacter("PaperDollFrame")`. Highlight: `character`.
- Events: `UNIT_INVENTORY_CHANGED`, `BAG_UPDATE_DELAYED`.
- Fail-safe: if any call returns nil or a secret, the rule says nothing.

### 4.9 `pet` — hunter pet (combat)
- Applies: class Hunter, level 10 or higher. (Warlock pets are not reminded
  about: summoning costs a shard and newbies may be saving them.)
- Conditions, one row each:
  - No pet: `UnitExists("pet")` is false, the hunter owns a pet (via
    `C_StableInfo` or `HasPetUI`), not mounted, not in a rest area. In combat
    this is the "your pet is dead or missing" warning and is the main reason
    the rule is combat-enabled. Text: "Your pet isn't summoned."
  - Unhappy: `C_PetInfo.GetPetHappiness()` returns 1 (unhappy) or 2 (content).
    Text: "Your pet is unhappy; feed it." Click: none. Highlight: none.
  - Training points: `C_PetInfo.GetPetTrainingPoints()` unspent above 0.
    Text: "Your pet has N unspent training points."
- Events: `UNIT_PET`, `UNIT_HAPPINESS`, `UNIT_PET_TRAINING_POINTS`,
  `PET_UI_UPDATE`, `PLAYER_LEVEL_UP`.
- Fail-safe as in 4.8.

### 4.10 `professions` — no profession learned
- Applies: level 10 or higher.
- Condition: `C_SkillInfo` (or legacy `GetProfessions()`) reports zero primary
  professions.
- Text: "You have no profession yet. Gathering (Herbalism, Mining, Skinning)
  makes gold while you level."
- Click: `ToggleCharacter("SkillFrame")` if that frame exists, else none.
  Highlight: `character`.
- Events: `SKILL_LINES_CHANGED`, `PLAYER_LEVEL_UP`.

### 4.11 `hearthstone` — Hearthstone missing (combat)
- Applies: any.
- Condition: no Hearthstone (item ID 6948, matched by ID) in any bag. Checked
  only after bags are loaded (first `BAG_UPDATE_DELAYED` after login).
- Text: "You have no Hearthstone. Any innkeeper gives you one for free."
- Click: none. Highlight: none.
- Events: `BAG_UPDATE_DELAYED`.

### 4.12 `quests` — quest log nearly full
- Applies: any.
- Condition: the number of quests (not headers) from
  `C_QuestLog.GetNumQuestLogEntries()` is at least max minus 3, where max is
  `C_QuestLog.GetMaxNumQuestsCanAccept()` if present, else 25.
- Text: "Your quest log is almost full (N of M)."
- Click: `ToggleQuestLog()`. Highlight: `quests`.
- Events: `QUEST_LOG_UPDATE` (debounced), `QUEST_ACCEPTED`, `QUEST_REMOVED`.

### 4.13 `mail` — new mail (combat)
- Applies: any.
- Condition: `HasNewMail()`.
- Text: "You have new mail waiting at a mailbox."
- Click: none. Highlight: `mail`.
- Events: `UPDATE_PENDING_MAIL`, `MAIL_INBOX_UPDATE`, `MAIL_CLOSED`.

### 4.14 `rested` — logging out outside an inn
- Applies: below max level.
- Trigger: `GameMenuFrame` `OnShow` hook (not an event). Condition:
  `IsResting()` is false.
- Text: "You're not in an inn or city. Log out there to earn rested XP."
- Also prints that line once per session through `NewbieNudge:Say()`.
- The row is removed when `GameMenuFrame` hides or `PLAYER_UPDATE_RESTING`
  reports resting. Click: none. Highlight: none.

### 4.15 `gear_upgrade` — better gear in bags (off by default)
- Applies: any. `default = false`; enable with `/nudge on gear_upgrade`.
- Condition: an item in bags passes all of:
  1. `C_Item.GetItemInfo` gives an equip location that maps to one equipment
     slot (rings and trinkets compare against the better of the two slots).
  2. The character can wear it: armor subclass is in a small class→armor table
     (cloth for everyone, leather for Druid/Rogue/Hunter/Shaman, mail for
     Hunter/Shaman/Warrior/Paladin, plate for Warrior/Paladin). Weapons are
     skipped in version one because proficiency checks are unreliable.
  3. `C_Item.GetDetailedItemLevelInfo` for the bag item exceeds the equipped
     item's by at least 5, or the slot is empty.
  4. The item's required level is at or below the character's level.
- Text: "An item in your bags looks like an upgrade: [item link]."
- Click: `ToggleAllBags()`. Highlight: `bags`.
- Events: `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`.
- Known limits, documented in the file header: item level is a rough proxy,
  stat weights are deliberately ignored, weapons are not covered.

## 5. Text and help

Every rule has a `help` string shown in the row tooltip, one or two sentences
in plain language aimed at someone on their first character. All user-facing
strings are keys in `Locales/enUS.lua` and `Locales/esES.lua` (see 3.5); rule
files and UI files contain no literal English. The Spanish translation is
written by hand in this project, using the informal "tú" form that the
Spanish WoW client uses.

## 6. Error handling summary

- `pcall` around every `check()` and every `onClick`.
- Secret values and missing APIs are treated as "unknown, keep the previous
  result". If a combat-enabled rule unexpectedly meets a secret value, it is
  treated as frozen for that combat and re-checked when combat ends.
- Rules without `combat = true` are not re-evaluated in combat or in
  restricted instances; their rows freeze and dim.
- Missing default UI frames mean no highlight, never an error.
- A rule that throws is disabled for the session and logged to
  `NewbieNudgeDB.errors`.

## 7. Testing

- In-game manual checks on this machine's Forever install, one rule at a
  time, using `/nudge test` for layout and `/dump` to confirm return values
  of the APIs marked "not yet verified" in section 2 before relying on them.
- A checklist in `docs/testing-checklist.md` listing for each rule how to make
  the condition true and false in game (for example: put a bag in your
  inventory with a slot empty → row appears; equip it → row disappears).
- `/console scriptErrors 1` on during development so Lua errors surface.
- Combat behaviour is tested with the simulation CVar
  `addonCombatRestrictionsForced 1`, which makes the client hand out secret
  values without fighting anything, plus one real fight on a low-level mob.
- Localization is tested by switching the game client to Spanish (Spain) in
  the Battle.net app, logging in, and reading every row, tooltip and options
  label. No in-addon language override exists, not even for development.
- Offline unit tests: a Python runner (`tests/run.py`) using the `lupa`
  package, which bundles LuaJIT (Lua 5.1 semantics, the same as the game),
  loads a small fake of the WoW API (`tests/wow_stub.lua`) and then the
  addon files in TOC order. Tests set the fake's state (bags, auras, action
  slots, combat flag) and assert on rule results, panel rows and saved
  variables. The fake implements only what the addon calls and never
  simulates game behaviour beyond returning the state a test set. Live API
  shapes are still confirmed in game; the fake is for logic, not for API
  discovery. The runner also checks that `enUS.lua` and `esES.lua` have the
  same keys.

## 8. Future extensions (not in scope now)

The rule interface is the extension point. Ideas noted during brainstorming:
warlock pet reminders, reagent counts, more languages (for example `esMX`).
Each would be a new file under `Rules/` or `Locales/` plus a TOC line.

## 9. Planned for v2: new spells at the trainer

Deferred, not dropped. The reminder would tell a player that their class
trainer has new spells or ranks for their level. The honest options are:

1. A hand-kept table of class → level → spell IDs. Simple, but it goes stale
   on every rebalance and contradicts the low-maintenance goal.
2. Deriving it live: when the player visits a trainer, record through
   `C_Trainer` which spells were available and at what level, and remind on
   later level-ups when the recorded table says something new unlocks. Zero
   hand data, but only knows about spells it has seen at a trainer once.
3. Checking whether `C_SpellBook` exposes the "available at trainer" flag the
   default spellbook uses to show unlearned spells in Forever. If it does,
   the rule becomes trivial. This needs live investigation and is the first
   thing to try when v2 starts.

The rule interface in 3.1 needs no change for any of the three.
