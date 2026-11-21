# Changelog

Each released version has a `## <version> - <date>` section. The release
workflow publishes that section as the GitHub release notes and the CurseForge
changelog, so write it for players, in English. Spanish notes for friends live
in `dist/` and are not tracked.

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
