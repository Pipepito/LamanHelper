# NewbieNudge v4 — design spec (minimap button, icon style, info bar, tidier options)

Date: 2026-11-22. Extends the v1–v3 specs; conventions (rule interface,
`NN.Plain`, locales in `Locales/*.lua` for enUS and esES, options built
through `NN.Options`, offline tests in `tests/`) are unchanged. Target
version 0.4.0.

## Intent

NewbieNudge is for new players. Four requests from the owner, all about
making the addon easier to reach and less overwhelming:

1. A minimap button with a small menu (lock/unlock, snooze everything,
   open the settings).
2. A panel style that shows only icons (like the combat strip) out of
   combat too, with the row text in a tooltip above the icon.
3. An info bar on top of the panel: bag slots, gold, gear condition, each
   part switchable in the options.
4. The options window is overwhelming: the main page holds the panel
   settings plus 34 reminder checkboxes, and "Game settings" is one page of
   ~60 game options. Group things, and put game options next to the addon
   feature they relate to (bag options in Bags), clearly labelled as game
   settings.

**Workflow constraint:** nothing is pushed or tagged until the owner has
tested in game. Work happens locally; `tools/deploy.ps1` already links the
addon folder into the game, so `/reload` picks up changes. The version bump
and changelog entry are part of the work, but the tag/push is the owner's
call after testing.

### Goals
- Every feature is reachable from the minimap button in one click.
- A player can keep the panel small (icons) without losing the text.
- The info bar answers "how full are my bags, how much gold, does my gear
  need repair" at a glance.
- The main options page fits on one screen without scrolling much.

### Non-goals
- No external libraries (LibDBIcon, LibDataBroker, Ace). The repo has
  none and the button is small enough to write by hand.
- No new reminders, no changes to rule logic.
- No change to which game settings are offered or to the preset values.

### Anti-goals
- Breaking existing saved settings: every existing `NewbieNudgeDB` key keeps
  its meaning; new keys get defaults through `NN.defaults`.
- Renaming settings variables (`NN_*`) that already exist: the Settings
  API keys on them; moving a control to another page keeps its variable.
- The info bar making the combat strip big.

## Approaches considered

**Minimap button:** (a) embed LibDBIcon + LibDataBroker — standard, works
with minimap-button collector addons, but adds two libraries and a
`Libs/` folder to a library-free addon; (b) hand-written button on the
minimap ring, draggable, angle saved — ~120 lines, testable with the
existing stub. **Picked (b)** (builder's call, owner handed over the how).
Also registers in the game's AddOns compartment drop-down when the client
has `AddonCompartmentFrame` (guarded).

**Info bar placement:** (A) on top of the reminder panel, moving with it;
(B) a separate bar placed anywhere. **Owner picked A.**

**Rule grouping on the Reminders page:** (a) a lookup table in Options.lua;
(b) an optional `group` field on each rule. **Picked (b)**: a new rule
declares its own group, and the README's "Adding a reminder" section
documents it.

## 1. Minimap button (`Minimap.lua`, new)

- A 31×31 round button parented to `Minimap`, standard minimap-button look
  (`Interface\Minimap\MiniMap-TrackingBorder` border, the addon icon
  `Interface\AddOns\NewbieNudge\Media\icon` inside, circular mask).
- Position: on the minimap edge at `db.minimap.angle` degrees (default
  225, bottom-left). Radius = minimap width / 2 + 10. Honour
  `GetMinimapShape()` when it exists and returns a square shape (clamp to
  the square's edge, the way LibDBIcon does); otherwise round.
- Drag with left button held: follows the cursor around the ring
  (`GetCursorPosition` / effective scale), saves the angle on drag stop.
  Dragging works even when the panel is locked.
- Hover tooltip: "NewbieNudge", the count of reminders showing ("3
  reminders" / "Nothing to fix"), then grey hints "Click: menu",
  "Drag: move this button".
- Click (left or right): opens the menu below at the cursor.
- `db.minimap = { hide = false, angle = 225 }`. Options checkbox "Show
  minimap button" (variable `NN_minimap_show`) and `/nudge minimap`
  toggle it.

### Menu

Built with `MenuUtil.CreateContextMenu` when present; fallback to
`EasyMenu` / `UIDropDownMenu` when not (which one Forever has is a probe
for the testing checklist). Items, top to bottom:

| Item | Shown | Action |
|---|---|---|
| **NewbieNudge** (title) | always | — |
| **Unlock panel** / **Lock panel** | label follows `db.panel.locked` | same as `/nudge lock` |
| **Panel style ▸ List / Icons** | radio pair | sets `db.panel.style` |
| **Show info bar** | checkbox | toggles `db.infobar.enabled` |
| **Snooze everything (1 h)** | when ≥1 reminder is showing; the "1 h" text follows `db.snoozeMinutes` (e.g. "45 min") | snoozes every rule that currently has a row, for `db.snoozeMinutes` |
| **Wake all reminders** | when any snooze is active | `NN:ClearSnoozes()` |
| **Hide panel** / **Show panel** | label follows `db.panel.hidden` | `Panel:ToggleHidden()` |
| **Settings…** | always | `NN:OpenOptions()` |

"Snooze everything" snoozes only the rules showing rows at that moment
(each with the normal per-rule snooze), so a new problem that appears
during the hour still shows. Builder's call; one chat line confirms
("Snoozed 4 reminders for 60 minutes.").

## 2. Panel style: list or icons (`Panel.lua`)

- `db.panel.style = "list" | "icons"`, default `"list"`. Options dropdown
  "Panel style" (`NN_panel_style`): "Full list" / "Icons only". Also in the
  minimap menu.
- `Panel:Refresh`: use the strip when `self.combat` **or** style is
  `"icons"`. The existing `combatStrip = false` rule (hide in combat)
  still applies in combat only.
- Strip wraps: at most 8 icons per line, extra icons on the next line
  below. Frame height grows with the number of lines.
- Strip tooltips anchor **above** the icon (`ANCHOR_TOP`) in both icons
  style and combat; list rows keep `ANCHOR_LEFT`. Tooltip content is
  unchanged (title, row text, help, click/snooze hints).
- New-icon pulse: in icons style the "seen" set is not reset on leaving
  combat (so leaving combat doesn't make every icon pulse again).
- Left-click / right-click on icons behave exactly as on rows (already
  true via `bindClickable`).

## 3. Info bar (`InfoBar.lua`, new; laid out by `Panel.lua`)

- A row inside the panel frame, below the title (when unlocked) and above
  the list/strip. Height 18. Three segments left to right, each icon +
  text, only the enabled ones shown:
  - **Bags:** `used/total (free free)`, e.g. bag icon `34/80 (46 free)` —
    regular bags 0–4 only, family 0, same as the `bag_full` rule
    (quivers, soul bags, herb bags not counted). Builder's call. Text
    turns orange at < 6 free and red at < 3.
  - **Gold:** `NN.MoneyText(GetMoney())`.
  - **Gear:** armour icon `87%` — sum of current durability / sum of max
    over equipped items that have durability. Red when any item is below
    20% or broken (same threshold as the `durability` rule), yellow when
    the overall is below 50%. Shows `—` when nothing equipped has
    durability.
- Values that read as secret or nil show `?` instead of a number.
- Hover tooltips per segment: bags — free/total per bag; gear — the
  lowest item's name and %; gold — none. Clicks: bags → `ToggleAllBags()`,
  gear → `ToggleCharacter("PaperDollFrame")`, gold → nothing. The bar is
  not draggable separately (dragging the panel title still moves all).
- Updates on `BAG_UPDATE_DELAYED`, `PLAYER_MONEY`,
  `UPDATE_INVENTORY_DURABILITY`, `PLAYER_EQUIPMENT_CHANGED`,
  `PLAYER_ENTERING_WORLD`, through `NN:OnAnyEvent` and registered with
  `NN:RegisterEvent`; then the panel re-lays out.
- Visibility: shown when `db.infobar.enabled` and at least one segment is
  on, **out of combat only** (hidden in combat so the strip stays small;
  builder's call). When the bar is shown and there are no reminders, the
  panel shows just the bar instead of hiding. Hidden panel (key binding,
  menu) hides the bar too.
- Width: in list style the panel stays 260 wide; in icons style the frame
  width is `max(strip width, bar width)`.
- `db.infobar = { enabled = true, bags = true, gold = true, gear = true }`.

## 4. Options reorganisation (`Options.lua` and each page's file)

Blizzard's AddOns list shows one level of subpages. New order and
contents (✱ = game setting, keeps the existing grey "Game setting, saved by
the game itself" note in its tooltip; each mixed page puts them under a
**Game settings** header so it is clear they are the game's, not the
addon's):

1. **NewbieNudge** (main page)
   - *Panel:* lock, panel style, scale, compact strip in combat, snooze
     length, Reset snoozes, Reset position.
   - *Info bar:* show info bar, bags, gold, gear condition (the three are
     greyed/ignored when the bar is off — plain checkboxes, no
     dependency wiring needed).
   - *Minimap:* show minimap button.
   - *New player setup:* "Apply recommended game settings" and "Reset
     these game settings to defaults" (the two buttons from today's Game
     settings page; the preset still covers every curated game setting).
2. **Reminders** — the 34 rule checkboxes, under group headers in this
   order:
   - *Bags and gear:* bag_unequipped, materials_bag, bag_full, durability,
     gear_upgrade, ammo, supplies
   - *Spells and talents:* talents, talent_build, spell_ranks,
     trainer_spells, buffs, tracking, weapon_skill, pet, demon
   - *Quests:* quests, quest_item, quest_turnin, quest_slots, quest_soon,
     quest_grey, quest_group
   - *Professions:* professions, profession_rank
   - *Travel and levelling:* hearthstone, hearth_bind, flight_path, mount,
     dungeon_ready, zone_level, rested, legacy, mail
   - *Other:* any rule without a `group` (none today; fixtures in tests).
   Within a group, rules follow `NN.PRIORITY` order.
   Mechanism: optional `group` field on `RegisterRule` (one of
   `"gear"`, `"spells"`, `"quests"`, `"professions"`, `"travel"`); invalid
   or missing → `"other"`. README documents it.
3. **Bags and vendors** (merges today's Bags, Vendors and Tooltips pages):
   bag-full window options; auto-sell, auto-repair; sell price in
   tooltips; *Game settings:* ✱ autoLootDefault, ✱ lootUnderMouse,
   ✱ expandBagBar, ✱ combinedBags.
4. **Map and minimap:** unexplored-area options; *Game settings:*
   ✱ mapFade, ✱ rotateMinimap, ✱ questPOI.
5. **Combat and action bars** (all ✱): today's GS_GROUP_COMBAT list.
6. **Names and health bars** (all ✱): today's GS_GROUP_NAMES list.
7. **Quests and interface** (all ✱): today's GS_GROUP_MOVE list, the
   quest settings except questPOI, and the interface ones (tutorials,
   screen-edge flash, low-health flash, status text and its display,
   outline, find yourself, chat bubbles, guild notify, error speech).
8. **Camera** (unchanged).
9. **Controller** (unchanged; only when `C_GamePad` exists).
10. **Talent build** (unchanged).
11. **Developer** (unchanged).

Pages 5–7 start with a one-line header "These are the game's own
settings, gathered here with plain labels." Page titles 5–7 carry no
"Game" prefix (the header says it).

Mechanism: `GameSettings.lua` keeps the single curated list and the preset,
but each entry carries a `page` key (`"bags"`, `"map"`, `"combat"`,
`"names"`, `"interface"`); `GameSettings:AddControls(category, layout,
page)` adds only that page's entries. Page builders call it. Settings
variable names (`NN_cvar_<cvar>`) do not change. The Vendors and Tooltips
`RegisterPage` calls become functions the Bags page calls, so one page
build adds all three. Page order is set explicitly in `Options:Build`
(a list of page keys), not by TOC load order.

## 4b. Materials bag in a regular bag slot (`Rules/MaterialsBag.lua`)

Owner request (2026-11-22). A profession bag (the existing
`NN.IsReagentBag` test: container, non-zero item family, not arrows or
bullets) in one of the four regular bag slots only holds its own kind of
material, so it wastes a slot a normal bag could use. When the materials
slot (`Enum.BagIndex.ReagentBag`, inventory slot 35) is empty, the player
should move it there.

- Extends the existing `materials_bag` rule (same title, same checkbox,
  same `applies`) with a third row instead of a new rule. Checked before
  the two existing rows; only one row is returned.
- Condition: the materials slot is empty **and** one of regular bags 1–4
  (`GetInventoryItemID("player", NN.BagInventorySlot(bag))`) is a
  materials bag.
- Text: "Your %s is in a normal bag slot. Click to move it to the
  materials slot and free that slot for a normal bag." (`%s` = the bag's
  name from `C_Item.GetItemInfo`, or "materials bag" until it is cached.)
- Click: moves the bag, out of combat only: `PickupBagFromSlot(fromSlot)`
  then `PutItemInBag(materialsSlot)`; if the cursor still holds an item
  afterwards, `ClearCursor()` and fall back to `ToggleAllBags()` plus a
  chat line explaining how to drag it. In combat the click does nothing
  but say so. Whether the client allows moving a non-empty bag this way is
  a testing-checklist probe; if it doesn't, the click opens the bags and
  the text says "Drag it to the materials slot".
- Highlight: `bags`. Events unchanged (`BAG_UPDATE_DELAYED`,
  `PLAYER_EQUIPMENT_CHANGED`).
- Tests in `tests/test_rules_materialsbag.lua`: row shows in the case
  above; no row when the materials slot is taken, when the regular-slot
  bag is a normal bag, or when it is a quiver/ammo pouch; click calls
  the two API functions with the right slots and refuses in combat.

## 4c. `weapon_trainers` — weapon skills you could learn, and where

Owner request (2026-11-22): list **every** weapon skill the character's
class can learn but hasn't, and the city of the player's faction that
teaches it, because not every city teaches every weapon.

- **Data** (`Data/WeaponTrainers.lua`, hand-written; source: Warcraft
  Tavern's WoW Forever weapon-trainer guide, checked against
  warcraft.wiki.gg): per faction, the trainers with city, NPC name and the
  skill line IDs they teach; per class, the skill line IDs it can learn
  (Forever's table: rogues get one-handed axes, druids get polearms; wands
  are excluded — built in, no trainer). Polearms: level 20.
  - Alliance: Stormwind / Woo Ping (43, 55, 173, 136, 226, 229);
    Ironforge / Buliwyf Stonehand (44, 172, 54, 160, 473, 46) and Bixi
    Wobblebonk (226, 173, 176); Darnassus / Ilyenia Moonfire (45, 173,
    473, 136, 176).
  - Horde: Orgrimmar / Sayoc (45, 173, 473, 44, 136, 176, 172) and Hanashi
    (45, 44, 136, 176, 172); Thunder Bluff / Ansekhwa (46, 54, 136, 160);
    Undercity / Archibald (226, 173, 43, 229, 55).
- **Known skills:** `NN.SkillLines()` by skill ID (already used by
  `weapon_skill`). Silent when the skill API is missing.
- **Rows:** one row per city that teaches at least one missing skill
  (at most three), nearest-to-home order not attempted — cities in data
  order. Text: "Learn %s in %s (%s)." → "Learn Two-Handed Maces and Staves
  in Thunder Bluff (Ansekhwa)." Weapon names from the client
  (`C_Item.GetItemSubClassInfo(2, subclass)`), so they follow the game
  language. Two trainers in one city are joined ("Sayoc or Hanashi").
  A skill taught in two cities appears only under the first. Polearms only
  from level 20.
- **Applies:** level ≥ 10 (builder's call: before that the player can't
  travel to other cities easily), faction Alliance or Horde, the skill API
  exists. Group `spells`, priority right after `weapon_skill`. Icon 135324.
  Events: `SKILL_LINES_CHANGED`, `PLAYER_LEVEL_UP`. No click action.
- **Tests:** per faction/class the right cities and weapons; learned skills
  drop out; polearms hidden below 20; a level-9 character sees nothing; no
  skill API → silent; weapon names come from the client.

## 5. Slash commands, bindings, docs

- `/nudge minimap` toggles the minimap button. `/nudge style` toggles list
  ↔ icons. `/nudge bar` toggles the info bar. Help text updated.
- README: commands table, a short "Minimap button" and "Info bar"
  section, the Reminders `group` field in "Adding a reminder".
- `docs/testing-checklist.md`: probes for `MenuUtil`,
  `AddonCompartmentFrame`, `GetMinimapShape`, and a v4 section.
- `CHANGELOG.md`: `## 0.4.0 - <date>` section for players; TOC version
  0.4.0. No tag or push until the owner says so.
- All new strings in enUS and esES (Spanish written by the builder; owner
  can correct).

## 6. Tests

Offline, extending `tests/wow_stub.lua` with `Minimap` (frame with width,
`GetEffectiveScale`), `GetCursorPosition`, `MenuUtil` recording the
menu description, and `AddonCompartmentFrame`. New test files:
`test_minimap.lua`, `test_infobar.lua`; extended `test_panel.lua`
(icons style, wrapping, tooltip anchor, bar visibility in combat and with
no rows), `test_options.lua` (page order, rule groups, game settings per
page, variables unchanged), `test_gamesettings.lua` (every curated entry
has a valid page; per-page filtering), `test_slash.lua`.

## Settled after the builder check (builder's calls)

- AddOns compartment entry opens the same menu, and stays even when the
  minimap button is hidden (so the menu is always reachable).
- Info bar in list style stays 260 wide; it uses `GameFontHighlightSmall`
  and, if the three segments still overflow, drops copper from the gold
  text when the player has 1 gold or more.
- No new key bindings.
- Inside a Reminders group, rules follow `NN.PRIORITY`; the lists in §4
  only say which group each rule is in, not the order.
- Pages registered under keys not in the explicit order list go at the end,
  in registration order.
- `MapReveal:OpenSettings` finds its page by title; it is updated for the
  new "Map and minimap" title (use the stored subcategory by page key, not
  by title).
- `CVarSection:AddControls` already takes `entries` as its third argument;
  `GameSettings` gets its own `AddPageControls(category, layout, page)`
  that filters the curated list (headers included) and passes it on.
- `CHANGELOG.md` gets `## 0.4.0 - unreleased` until the owner decides to
  release; the date goes in at tag time.

## Left to the builder

Exact pixel sizes and colours, Spanish wording, the menu fallback's exact
code, how strip wrapping computes positions, helper names.
