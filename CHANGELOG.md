# Changelog

Each released version has a `## <version> - <date>` section. The release
workflow publishes that section as the GitHub release notes and the CurseForge
changelog, so write it for players, in English. Spanish notes for friends live
in `dist/` and are not tracked.

## 0.6.0 - 2026-11-25

- **Settings window made for the controller:** press Esc (or open the game menu) and pick **NewbieNudge**, right above AddOns. Every NewbieNudge settings page in one window: LB/RB switch pages, d-pad up/down picks a setting, left/right changes it, A ticks boxes and presses buttons, B closes. Each setting's explanation shows at the bottom. The mouse works too. It is what `/nudge`, `/nudge settings`, the minimap button's Settings, the map list's settings button and the "Open NewbieNudge options" key binding open now; NewbieNudge is no longer in the game's Esc > Options > AddOns list: everything moved to this window.
- **Bag addons:** with Baganator, Bagnon, AdiBags, ArkInventory, BetterBags and the like, NewbieNudge no longer makes the backpack button or bag items glow, so the bag addon's own "hover a bag to highlight its items" keeps working. Glows elsewhere no longer block the mouse over the button they sit on.
- **Dungeon suggestions** say whose land each dungeon is in (Alliance or Horde), and warn you when it is the other faction's — no more sending a Horde player to the Deadmines without a word.
- **New spell ranks go on your bars by themselves:** when you learn a new rank, the older ranks of that spell on your action bars are swapped for it (after combat if you are fighting), and a chat line says so. Low ranks you put on a bar yourself afterwards are left alone. Turn it off under Options → Reminders, below "Old spell ranks on your bars".
- **Paddles are now "Back buttons"**, and their rows are named L4, L5, R4 and R5 like the Steam Deck's back grips, instead of Paddle 1–4. Open them with `/nudge back` (`/nudge paddles` still works). They only work with the game's controller mode on: turn it off and your back buttons stop doing NewbieNudge's actions (they come back when you turn it on again), the window does not open (a chat line says where to turn it on) and the minimap menu leaves it out.
- **Missing buffs** no longer asks you to cast buffs that come from a passive ability.

## 0.5.0 - 2026-11-23

- **Back paddles:** give your controller's back paddles (Steam Deck L4/R4/L5/R5 and the like) their own actions. Open the Paddles window (minimap menu, `/nudge paddles`, Options → Controller, or a key binding), press Learn, then press the paddle. Each paddle does any game command (open your bags, the map…), casts a spell, uses an item or runs a macro. Or make it a **layer**: while you hold it, A/B/X/Y and the d-pad do eight extra actions. Works in combat; changes wait until combat ends. On the Steam Deck, map the back grips to free keys in Steam first.
- **Made for the controller:** the Paddles window works with the pad alone — d-pad to move, A to select, B to go back, X to clear, LB/RB to switch between your spells, items, macros and game commands, Y to search. It shows the game's own button icons and the real icons of your spells, items and action bar slots.
- **Controller fix:** changing controller settings (camera, cursor, soft targeting, button assignments) on NewbieNudge's Controller page broke WoW Forever's controller interface — the game blocked its actions and asked to disable the addon. NewbieNudge no longer changes the game's controller settings at all, and the Steam Deck / controller presets are gone. If you used those presets in 0.4.0 and your controller behaves oddly, reset its settings in the game's own options.
- **Controller fix, part two:** the minimap button's menu is now NewbieNudge's own. Opened from an addon, the game's pop-up menus upset its controller interface, which then blocked its own actions at vendors and when looting.
- **Weapon skills to learn** no longer keeps listing Fist Weapons after you learn them (WoW Forever adds the skill without a skill line).
- Small fixes: the map's NewbieNudge button stays above pins, the map list fits under the top of the map, the profession count follows the switches, other factions' flight points are left out even without a faction from the game, zooming the map only rescales the pins, class-quest wording.

## 0.4.0 - 2026-11-22

- **Minimap button** with a quick menu: lock or unlock the panel, switch its style, show the info bar, snooze everything, wake all reminders, hide the panel, open the settings. Drag it around the minimap. Also in the game's AddOns drop-down.
- **Icons only:** a new panel style that keeps the panel as small as the combat strip all the time. Point at an icon to read the reminder.
- **Info bar** on top of the panel: bag space, gold and gear condition at a glance. Each part can be turned off.
- **Materials bag in a normal bag slot:** if a profession bag sits in one of your four bag slots while the materials slot is empty, a reminder offers to move it for you.
- **Weapon skills to learn:** lists the weapons your class can use but hasn't learned, and the city of your faction whose weapon master teaches them (WoW Forever's trainers, including rogue axes and druid polearms).
- **Map marks:** reminders that send you to an NPC (repair, class trainer, weapon master, food, inn, profession trainer) get a button that marks the closest one on the world map — for your faction, and never in a zone far above your level. Several marks at once; right-click a pin to remove it. Repair, inn and food marks also turn on the minimap tracking for them.
- **Quickest, not nearest:** marks count the flight paths you have discovered, and show up to 4 options (one per zone or city, numbered, best first) so you can pick one on your way. "Options per mark" sets how many.
- **Show services on the world map:** repair vendors, inns, food vendors and your trainers on the map you're looking at (minimap menu or `/nudge services`).
- **NewbieNudge list on the world map:** click the NewbieNudge icon on the map for switches per kind of service and the list of your marks (jump to the zone, remove one, remove all).
- **Icon layout:** icons per line, rows or columns, icon size and gap for the icons-only panel.
- **New spells for your level** tells trainer spells from class-quest spells ("Class quest (level 10): Bear Form. Your class trainer starts it."), and no longer counts warlock demon abilities, which the demon learns.
- **Flight points on the map:** a "Flight points" line in the map list; each pin says whether you've discovered it. The "flight path to unlock" reminder marks the nearest flight masters (and now works on Forever: discovered flight points are remembered each time you open a flight master's map).
- **City badges on zone maps:** with services shown, each city on a zone map gets a small row of icons for what it holds (your class trainer, weapon master, profession trainers, flight point); hover names who, click opens the city. Marked options inside a city also show on the zone map.
- **Profession filter:** the map list has a line per profession (yours ticked at first) and a "My professions only" button.
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
