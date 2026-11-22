# Changelog

Each released version has a `## <version> - <date>` section. The release
workflow publishes that section as the GitHub release notes and the CurseForge
changelog, so write it for players, in English. Spanish notes for friends live
in `dist/` and are not tracked.

## 0.4.0 - unreleased

- **Minimap button** with a quick menu: lock or unlock the panel, switch its style, show the info bar, snooze everything, wake all reminders, hide the panel, open the settings. Drag it around the minimap. Also in the game's AddOns drop-down.
- **Icons only:** a new panel style that keeps the panel as small as the combat strip all the time. Point at an icon to read the reminder.
- **Info bar** on top of the panel: bag space, gold and gear condition at a glance. Each part can be turned off.
- **Materials bag in a normal bag slot:** if a profession bag sits in one of your four bag slots while the materials slot is empty, a reminder offers to move it for you.
- **Weapon skills to learn:** lists the weapons your class can use but hasn't learned, and the city of your faction whose weapon master teaches them (WoW Forever's trainers, including rogue axes and druid polearms).
- **Map marks:** reminders that send you to an NPC (repair, class trainer, weapon master, food, inn, profession trainer) get a button that marks the closest one on the world map — for your faction, and never in a zone far above your level. Several marks at once; right-click a pin to remove it. Repair, inn and food marks also turn on the minimap tracking for them.
- **Show services on the world map:** repair vendors, inns, food vendors and your trainers on the map you're looking at (minimap menu or `/nudge services`).
- **Gathering tracking** now notices Find Herbs and Find Minerals on WoW Forever (profession spells sit apart from the class spells in the spellbook).
- **Tidier options:** reminders have their own page, grouped; the game's own settings sit next to the feature they belong to, with Combat, Names and Interface pages of their own. "Apply recommended game settings" is on the main page.

## 0.3.4 - 2026-11-21

- NewbieNudge has its own icon in the AddOns list.
- First release published on CurseForge; releases are now built and uploaded automatically from GitHub.

## 0.3.3 - 2026-11-21

- **Bank:** the "cheapest to destroy" window no longer opens by itself while the bank is open, and closes when the bank opens. Quest-item glows ignore the bank's bag frames.
- **Developer mode** (Options → Developer, or `/nudge dev on`): records every Lua error and every blocked addon action while it is on. `/nudge dev snap` saves a snapshot of the client, the loaded addons, the rules, the bags and the bank state; `/nudge dev` opens a window to copy the log; `/reload` also writes it to `WTF\Account\<account>\SavedVariables\NewbieNudge.lua`. Off by default.
- `/nudge dump <expression>` evaluates a Lua expression and keeps the result in that log.
- Languages now live in one file each under `Locales/`, with a guide for adding a new one.

## 0.3.2 - 2026-11-20

- Supplies (food, drink, bandages), group quests, secondary profession ranks, Hearthstone binding at a new inn, vendor auto-sell and auto-repair, sell price in tooltips, single-bag toggle, mount savings, weapon skill, Legacy system, flight paths, warlock demon.
- First public release on GitHub.
