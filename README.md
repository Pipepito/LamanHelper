# NewbieNudge

A World of Warcraft Forever addon for new players. It shows a small checklist
of things worth fixing (unspent talent points, a missing buff, a bag you never
equipped, broken gear, and so on) and makes the button that fixes each one
glow. Rows appear only when they apply to your character and vanish the moment
the problem is gone. In combat the list shrinks to a row of icons.

English and Spanish (Spain) are included; the game's language setting decides.

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
| `/nudge trash` | Open the "cheapest to destroy" list for your bags right now. |
| `/nudge build <link>` | Set an Icy Veins talent build from its calculator link (`/nudge build clear` removes it, `/nudge build` shows the status). |
| `/nudge show` | Bring the panel back after hiding it with the key binding. |

Right-click a row to snooze it for an hour (configurable). Shift+right-click
snoozes it until your next login. Left-click a row to open the related window,
or to swap an old spell rank on your bar for the new one.

## Reminders

Bag not equipped or smaller than one in your inventory · bags nearly full ·
unspent talent points · long-duration self-buffs missing (the bar button glows)
· old spell ranks on your bars (click to swap) · gathering tracking not turned
on · damaged or broken gear · out of ammo · hunter pet not summoned, unhappy or
with unspent training points · no profession by level 10 · no Hearthstone ·
quest log nearly full · new mail · logging out outside an inn or city · gear
upgrade sitting in your bags (off by default: `/nudge on gear_upgrade`) ·
materials bag not equipped · an item in your bags that starts a quest (the
item glows) · quests ready to turn in · quests about to turn grey · grey
quests · bag slots your current quests will need · new spells for your level
you haven't learned · next profession rank available · a dungeon that fits
your level · the zone you are in is below or above your level · the next
talent of your Icy Veins build · no food, drink or bandages in your bags ·
quests that need a group · the next rank of Cooking, First Aid or Fishing
(trainer, book or quest) · an innkeeper who could set your Hearthstone nearby
· saving up for your mount from level 30, and learning to ride at 40 · a
weapon skill far behind its cap · the Legacy system opening at 25, and new
Legacy challenges to look at · a flight path in your zone you have not
unlocked yet.

Every reminder has its own checkbox in the options.

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

Options → Game settings lists the game's own options a new player should set
(auto loot, enemy health bars, NPC names, cast on key down, cooldown numbers,
quest tracking, and so on) with plain labels, and a **Recommended for new
players** button that applies them in one go. Camera has its own page with
the maximum camera distance and other hidden camera settings.

## Adding a reminder

Each reminder is one small table in a file under `NewbieNudge/Rules/`,
registered with `NN:RegisterRule`:

```lua
local _, NN = ...
local L = NN.L
NN:RegisterRule({
  name = "my_rule",            -- lowercase, used by /nudge and the options page
  title = L.MY_RULE_TITLE,     -- add the strings to both Locales files
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

## Credits and licence

NewbieNudge is released under the GNU General Public License v3.0 (see
`LICENSE`).

- Map fog tiles, spells by level, zone level ranges and dungeon data come
  from [WoW Handbook](https://github.com/Arcaneology/WowHandbookAddon)
  (Arcaneology / ArcaneStudio, GPL-3.0), which in turn builds its trainer
  and profession data on [Questie](https://github.com/Questie/Questie) and
  QuestieDB (GPL-3.0). The generated files name the upstream commit.
- Talent build identifiers (node and spell IDs per talent) come from
  Icy Veins' public talent data; only identifiers are kept.
