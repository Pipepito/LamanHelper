# NewbieNudge

A World of Warcraft Forever addon for new players. It shows a small checklist
of things worth fixing (unspent talent points, a missing buff, a bag you never
equipped, broken gear, and so on) and makes the button that fixes each one
glow. Rows appear only when they apply to your character and vanish the moment
the problem is gone. In combat the list shrinks to a row of icons; choose
"Icons only" to keep it that small all the time (point at an icon to read it).
A bar on top of the panel shows your bag space, gold and gear condition, and a
button on the minimap opens a quick menu.

English and Spanish (Spain) are included; the game's language setting decides.
Each language is one data file under `NewbieNudge/Locales/`; see
[Locales/README.md](NewbieNudge/Locales/README.md) to add another.

Beyond the checklist it also: shows the unexplored parts of a zone on the
world map, dimmed; lists the cheapest things to destroy when your bags are
full; follows an Icy Veins leveling build and names the next talent; gathers
the game's own new-player settings and the hidden controller and camera
settings in its options; and scales up for a controller or a Steam Deck.

## Install

Copy the `NewbieNudge` folder into:

```
World of Warcraft\_forever_\Interface\AddOns\
```

Then start the game or type `/reload`.

## Commands

| Command | What it does |
|---|---|
| `/nudge` | Open the options page (also under Escape → Options → AddOns → NewbieNudge). |
| `/nudge lock` | Lock or unlock the panel. Unlocked, drag the title bar to move it. |
| `/nudge list` | List every reminder and whether it is on, off, snoozed or not relevant. |
| `/nudge off <name>` / `/nudge on <name>` | Turn one reminder off or on for this character. |
| `/nudge reset` | Clear snoozes and leave test mode. |
| `/nudge test` | Show every reminder with sample text, to check the layout. |
| `/nudge map` | Toggle the dimmed unexplored areas on the world map. |
| `/nudge minimap` | Show or hide the minimap button. |
| `/nudge style` | Switch the panel between the full list and icons only. |
| `/nudge bar` | Turn the info bar on top of the panel on or off. |
| `/nudge services` | Show or hide nearby services (repair, inns, trainers…) on the world map. |
| `/nudge trash` | Open the "cheapest to destroy" list for your bags right now. |
| `/nudge build <link>` | Set an Icy Veins talent build from its calculator link (`/nudge build clear` removes it, `/nudge build` shows the status). |
| `/nudge show` | Bring the panel back after hiding it with the key binding. |
| `/nudge dev` | Developer log window. `/nudge dev on` records every Lua error, `/nudge dev snap` saves a state snapshot, `/nudge dev clear` empties the log. |
| `/nudge dump <expr>` | Evaluate a Lua expression and keep the result in the developer log (no 255-character limit on the output). |

Right-click a row to snooze it for an hour (configurable). Shift+right-click
snoozes it until your next login. Left-click a row to open the related window,
or to swap an old spell rank on your bar for the new one.

## Reminders

Bag not equipped or smaller than one in your inventory · bags nearly full ·
unspent talent points · long-duration self-buffs missing (the bar button glows)
· old spell ranks on your bars (click to swap) · gathering tracking not turned
on · damaged or broken gear · out of ammo · hunter pet not summoned, unhappy or
with unspent training points · warlock demon not summoned · no profession by level 10 · no Hearthstone ·
quest log nearly full · new mail · logging out outside an inn or city · gear
upgrade sitting in your bags (off by default: `/nudge on gear_upgrade`) ·
materials bag not equipped, or sitting in a normal bag slot while the
materials slot is empty (click to move it) · an item in your bags that starts a quest (the
item glows) · quests ready to turn in · quests about to turn grey · grey
quests · bag slots your current quests will need · new spells for your level
you haven't learned · next profession rank available · a dungeon that fits
your level · the zone you are in is below or above your level · the next
talent of your Icy Veins build · no food, drink or bandages in your bags ·
quests that need a group · the next rank of Cooking, First Aid or Fishing
(trainer, book or quest) · an innkeeper who could set your Hearthstone nearby
· saving up for your mount from level 30, and learning to ride at 40 · a
weapon skill far behind its cap · weapon skills your class can learn, and which
city of your faction teaches them · the Legacy system opening at 25, and new
Legacy challenges to look at · a flight path in your zone you have not
unlocked yet.

Every reminder has its own checkbox in the options (Reminders page, grouped).

## Minimap button

A round button on the edge of the minimap. Click it for a menu: lock or
unlock the panel, switch between the full list and icons only, show the info
bar, snooze everything on the panel for your snooze length, wake every snoozed
reminder, hide or show the panel, open the settings. Drag it around the
minimap edge to move it. `/nudge minimap` or Options → NewbieNudge hides it;
the same menu is also in the game's AddOns drop-down by the minimap when the
client has one.

## Map marks

Reminders that send you to an NPC (damaged gear, new spells, weapon skills,
no food, logging out outside an inn, the next profession rank) get a small
map-pin button at the end of the row; in the icons-only style, Ctrl+click the
icon. It marks the closest suitable NPC on the world map: friendly to your
faction, never in a zone more than 3 levels above you, and on your continent
first. The map opens there and a chat line says who and where. Marking a
repair vendor, innkeeper or food vendor also turns on the game's own minimap
tracking for it. Several marks can be up at once (one per kind); right-click
a pin, click the row's button again, or use "Remove all map marks" in the
minimap menu to remove them. A mark made from a reminder goes away with the
reminder.

"Show services on the world map" (minimap menu, Options → Map and minimap,
or `/nudge services`) shows every repair vendor, inn, food vendor, your class
trainer, the weapon masters and your profession trainers on the map you are
looking at; click one to mark it. NPC positions come from QuestieDB's WoW
Forever database (`tools/import_questie_npcs.py`).

The NewbieNudge icon on the world map (bottom right) opens a list beside it:
the unexplored-areas switch, one switch per kind of service to show on the
map (with its icon), and your marks — click one to jump to its zone, or ✕ to
remove it. Right-click the icon to toggle the unexplored areas.

In the icons-only style, Options → NewbieNudge sets how many icons go on a
line (1 makes a column), whether they fill rows or columns, the icon size and
the gap between them.

## Info bar

A row on top of the panel: bag space (used/total and free; orange below 6
free, red below 3), gold, and gear condition (all your equipped items
together; red when one item is about to break). Click bags to open them, gear
to open your character. Hidden in combat. Each part can be turned off under
Options → NewbieNudge → Info bar, or the whole bar with `/nudge bar`.

## World map

Zones you have not fully explored show their missing parts dimmed and in grey
instead of blank, so you can see the shape of the whole zone. Options → Map
sets the brightness, turns the grey off, or turns the feature off;
`/nudge map` toggles it.

## Bags full

When the game says your inventory is full, or you open loot with no free
slot, a small window appears next to the loot listing the cheapest stacks to
destroy: grey items first, then by vendor value, with a Destroy button per
row. Quest items, items that start a quest, items your quests still need,
bags, ammo, reagents, keys, the Hearthstone, and white or green gear are
never listed. Grey items go with one click; white and green ones ask "Sure?"
first. It closes by itself once a slot is free and the loot window is gone.
`/nudge trash` opens it at any time. Options → Bags.

## Vendors and tooltips

Opening a merchant sells every grey item and repairs your gear when the
merchant can and you can afford it, each with a chat line saying what
happened; both are on by default under Options → Vendors. Item tooltips show
the vendor sell price when you are not at a vendor (Options → Tooltips).

## Talent builds from Icy Veins

Open the Icy Veins leveling guide for your class, pick a build under
"Leveling Talent Build", click **Open in Calculator** and copy that page's
address. Paste it with `/nudge build <link>` or through Options → Talent
build. The panel then names the next talent to pick, with how many points it
has, and the talent glows in the talent window. If you stray from the build,
a second row says so and the suggestion keeps following the build's order.

The link carries the whole order: one character per talent point. The
addon only needs a table of talent identifiers, refreshed with
`tools/import_icy_talents.py`.

## Playing with a controller or a Steam Deck

With the game's own controller support on, Options → Controller gathers the
gamepad and soft-targeting settings Blizzard's window hides, with plain
labels, plus two one-click presets (Steam Deck, plain controller) that never
touch your button assignments. Once a controller is in use, the panel and
the combat strip scale up (Options → Controller sets the factor) and row
tooltips name the pad buttons instead of mouse buttons. Four actions can be
bound to pad combinations in the game's Key Bindings window under
"NewbieNudge": show/hide the panel, open the top reminder, snooze the top
reminder, open the options.

## Game settings for new players

The game's own options a new player should set (auto loot, enemy health bars,
NPC names, cast on key down, cooldown numbers, quest tracking, and so on) are
gathered with plain labels next to the feature they belong to: loot and bag
options on the Bags and vendors page, minimap options on Map and minimap, and
three pages of their own (Combat and action bars, Names and health bars,
Quests and interface). **Apply recommended game settings** on the main page
sets all of them in one go. Camera has its own page with
the maximum camera distance and other hidden camera settings.

## Adding a reminder

Each reminder is one small table in a file under `NewbieNudge/Rules/`,
registered with `NN:RegisterRule`:

```lua
local _, NN = ...
local L = NN.L
NN:RegisterRule({
  name = "my_rule",            -- lowercase, used by /nudge and the options page
  group = "gear",              -- options page group: gear | spells | quests | professions | travel
  title = L.MY_RULE_TITLE,     -- add the strings to every Locales file
  help = L.MY_RULE_HELP,
  events = { "SOME_EVENT" },   -- when to re-check; "UNIT_AURA:player" form is allowed
  combat = false,              -- true only if the data it reads is still readable in combat
  applies = function() return true end,  -- can this ever matter for this character?
  check = function()           -- nil when all is fine, or one result, or a list of them
    return { text = L.MY_RULE_ROW, icon = 134400, onClick = nil, highlight = "bags" }
  end,
})
```

Add the file to `NewbieNudge.toc`. Return `NN.UNKNOWN` from `check()` when the
game hands you a secret value and you cannot tell; the previous result is kept.
Run every value you read through `NN.Plain(value, "number"|"string")`.

## Development

Tests run outside the game with Python and LuaJIT (same Lua 5.1 semantics as
the client) against a small fake of the WoW API in `tests/wow_stub.lua`:

```bash
python -m pip install --target tools/pylib -r tools/requirements.txt
```

```bash
python tests/run.py
```

To work on the addon with the game running, link the folder into your AddOns
directory once (edit the path inside the script if your game lives elsewhere):

```bash
powershell -File tools/deploy.ps1
```

Then `/reload` in game after each change. The in-game checklist is in
`docs/testing-checklist.md`. Design notes live in `docs/superpowers/specs/`.

Releases are cut by pushing a `v*` tag; a GitHub Actions workflow builds the
zip, publishes the GitHub release and uploads to CurseForge. Steps and setup in
`docs/releasing.md`; the player-facing notes come from `CHANGELOG.md`.

## Reporting a problem

Turn on developer mode (`/nudge dev on`, or Options → Developer), reproduce
the problem, type `/nudge dev snap` while the misbehaving window is open, then
`/reload`. The client writes the log to
`WTF\Account\<account>\SavedVariables\NewbieNudge.lua`; attach that file, or
open `/nudge dev` in game and copy the text. Every Lua error from any addon is
recorded while the mode is on, so turn it off again afterwards.

## Refreshing game data

Some reminders and the map reveal use tables generated from other projects.
After a game patch that changes maps, spells or dungeons, regenerate them
(each command rewrites files under `NewbieNudge/Data/`; commit the result):

```powershell
python tools/import_handbook.py --ref main
```
```powershell
python tools/import_icy_talents.py
```
```powershell
python tools/import_questie_npcs.py
```

## Credits and licence

NewbieNudge is released under the GNU General Public License v3.0 (see
`LICENSE`).

- Map fog tiles, spells by level, zone level ranges and dungeon data come
  from [WoW Handbook](https://github.com/Arcaneology/WowHandbookAddon)
  (Arcaneology / ArcaneStudio, GPL-3.0), which in turn builds its trainer
  and profession data on [Questie](https://github.com/Questie/Questie) and
  QuestieDB (GPL-3.0). The generated files name the upstream commit.
- Service NPC positions (repair, inns, food vendors, trainers) come from
  [QuestieDB](https://github.com/Questie/QuestieDB)'s WoW Forever data
  (GPL-3.0); the generated file names the upstream commit.
- Talent build identifiers (node and spell IDs per talent) come from
  Icy Veins' public talent data; only identifiers are kept.
