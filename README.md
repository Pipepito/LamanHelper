# NewbieNudge

A World of Warcraft Forever addon for new players. It shows a small checklist
of things worth fixing (unspent talent points, a missing buff, a bag you never
equipped, broken gear, and so on) and makes the button that fixes each one
glow. Rows appear only when they apply to your character and vanish the moment
the problem is gone. In combat the list shrinks to a row of icons.

English and Spanish (Spain) are included; the game's language setting decides.

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
upgrade sitting in your bags (off by default: `/nudge on gear_upgrade`).

The options page also has a **Camera** section with game settings Blizzard's
own window hides, such as the maximum camera distance.

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
