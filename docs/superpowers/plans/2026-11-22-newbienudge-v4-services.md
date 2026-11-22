# NewbieNudge v4 — service markers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mark the closest suitable service NPC (repair, inn, supplies, class/weapon/profession trainer) on the world map from a button beside the reminder; several marks; removable; plus a "show nearby services" switch.

**Architecture:** A Python importer turns QuestieDB's Forever NPC database into `Data/Services.lua`. `Services.lua` picks the closest NPC (faction, level filter, world distance) and keeps marks in `db.marks`. `MapPins.lua` draws marks and show-all pins on the world map canvas. Rules attach `service` to rows; `Panel.lua` draws a pin button on those rows.

**Tech Stack:** Lua 5.1 (WoW Forever), Python 3 + lupa for the importer; offline tests (`python tests/run.py`, `python -m unittest discover -s tests -p "test_*.py"`).

**Spec:** `docs/superpowers/specs/2026-11-22-newbienudge-v4-design.md` §4d (and §4c for weapon masters).

## Global Constraints

- Same as the main v4 plan: no pushes or tags; enUS + esES strings; new files in the TOC; values through `NN.Plain`; existing settings variables unchanged; full suite green after each task.
- Data licence: QuestieDB is GPL-3.0; the generated file names the upstream commit, like `import_handbook.py` output.
- No minimap pins. Minimap help is only the game's own tracking (repair, inn, supplies); never for trainers; the addon never turns tracking off.
- Level filter: skip NPCs in zones whose `NN.Zones[map].min > playerLevel + 3`; maps without a range (cities) always allowed.

## Review Focus

1. Player position unreadable (instance, secret value, no map) — the mark button says so in chat and changes nothing. Test in Task 10.
2. A mark whose NPC is not in the data any more (data refresh between sessions) — dropped silently on load, no error. Test in Task 10.
3. World map closed/opened on a different zone — pins only for that map; no leftover pins from the previous map. Test in Task 11.
4. Show-all on a busy city map — pins drawn once per refresh (pool reused, no growth on every redraw). Test in Task 11.
5. Marks created from the show-all view must not be auto-removed by the "row went away" rule. Test in Task 10.

---

### Task 9: NPC importer and `Data/Services.lua`

**Files:** Create `tools/import_questie_npcs.py`, `tests/test_import_questie_npcs.py`, `NewbieNudge/Data/Services.lua` (generated, committed; TOC after `Data\WeaponTrainers.lua`).

**Interfaces — produces** `NN.Services.data = { npcs = { [npcID] = { name, title, map, x, y, faction } }, kinds = { [kind] = { npcID, ... } } }` with kinds `repair`, `inn`, `supplies`, `weapon`, `trainer_<CLASS>` (DRUID … WARRIOR), `prof_<skillLineID>` (171 alchemy, 164 blacksmithing, 333 enchanting, 202 engineering, 182 herbalism, 165 leatherworking, 186 mining, 393 skinning, 197 tailoring, 185 cooking, 129 first aid, 356 fishing). One entry per NPC: its first spawn whose area converts (QuestieDB `conversion.json` `geometry.transforms[].area_id → ui_map_id`). NPCs friendly to neither faction are dropped.

- [ ] Tests (`unittest`, fixture strings in the test like `test_import_handbook.py`): flag/title classification (repair 16384; inn 128 + "Innkeeper"; supplies titles Food & Drink / General Goods / General Supplies / Baker / Butcher; "Mage Trainer"+16 → `trainer_MAGE`; "Weapon Master" → `weapon`; "Herbalism Trainer" → `prof_182`; "Herbalist" without trainer flag → nothing); unmapped area skipped; faction "AH"/"A"/"H" kept, nil dropped; output deterministic (sorted ids); header names source URL and commit. Run → FAIL (module missing).
- [ ] Implement `transform(npc_src: str, conversion: dict, commit: str) -> str` plus `main()` that downloads `data/Forever/foreverNpcDB.lua` and `conversion.json` from `Questie/QuestieDB` at `--ref` (default `main`) and writes `NewbieNudge/Data/Services.lua`. Parse rows in chunks of 1500 lines through lupa (LuaJIT's 65536-constant limit). Run → PASS.
- [ ] Generate the real file (`python tools/import_questie_npcs.py`); check it loads in the suite (`python tests/run.py` green; add `tests/test_data_files.lua` case: `NN.Services.data.kinds.repair` non-empty, every kind entry has an npc). Commit.

### Task 10: Closest NPC and marks (`NewbieNudge/Services.lua`)

**Files:** Create `NewbieNudge/Services.lua` (TOC after `Data\Services.lua`; module table `NN.Services`, data from Task 9 at `NN.Services.data`); modify `Core.lua` defaults `marks = {}`, `services = { showAll = false }`; stub additions in `tests/wow_stub.lua`: `CreateVector2D`, `C_Map.GetPlayerMapPosition(map, unit)` (from `S().playerPos = { map, x, y }`), `C_Map.GetWorldPosFromMapPos(map, vec)` (from `S().mapWorld[map] = { continent, left, top, width, height }` → continent, vector of `left + x*width, top + y*height`); test `tests/test_services.lua`.

**Interfaces — produces:**
- `Services:Candidates(kind) -> { npcID, ... }` (faction + level filter applied)
- `Services:Closest(kind, npcIDs?) -> npcID|nil, reason` (`reason` = `"position"` when the player's position is unreadable, `"none"` when no candidate)
- `Services:Mark(kind, npcID, fromRow: bool)`, `Services:Unmark(kind)`, `Services:IsMarked(kind) -> bool`, `Services:ClearMarks()`, `Services:Marks() -> { { kind, npcID, fromRow }, ... }`
- `Services:MarkClosest(kind, npcIDs?, fromRow) -> npcID|nil` (chat line, opens world map on the NPC's map, turns on tracking)
- `Services:PruneRowMarks(activeKinds: set)` called from `NN:RunChecks` after rows are built.

- [ ] Tests: closest by world distance; other continent loses to same continent but still wins when it's the only one; faction filter; level filter (zone min 30 skipped at level 20, allowed at 27); city (no range) allowed; unreadable position → nil + `"position"`, chat `L.SERVICES_NO_POSITION`, no mark; `npcIDs` restricts candidates (weapon rows); mark replaces same kind, survives `/reload` (db), unknown npc dropped on load; unmark/clear; `PruneRowMarks` removes `fromRow` marks whose kind is not active and keeps others; `MarkClosest("repair")` turns on the tracking entry named `MINIMAP_TRACKING_REPAIR` (stub global "Repair"), `"inn"` → `MINIMAP_TRACKING_INNKEEPER` ("Innkeeper"), `"supplies"` → `MINIMAP_TRACKING_VENDOR_FOOD` ("Food & Drink"); `trainer_MAGE` turns on nothing; records `OpenWorldMap` with the NPC's map; chat `L.SERVICES_MARKED:format(name, title, zone)`. Run → FAIL.
- [ ] Implement. Distance: squared world distance; other continent adds `1e12`. Run → PASS, full suite green. Commit.

### Task 11: World map pins (`NewbieNudge/MapPins.lua`)

**Files:** Create `NewbieNudge/MapPins.lua` (TOC after `MapReveal.lua`); stub: `WorldMapFrame.ScrollContainer = { Child = frame(width 1000, height 667), GetCanvasScale = 1 }`, `WorldMapFrame:GetMapID()` from `S().worldMapID`, `WorldMapFrame:OnMapChanged()` (hookable); test `tests/test_mappins.lua`.

**Interfaces — produces** `NN.MapPins:Refresh()`, `MapPins.pins` (pool, array of frames with `.npcID`, `.kind`, `.marked`), `MapPins:SetShowAll(on)`. Consumes Task 10.

- [ ] Tests: marked NPC on the viewed map → one shown pin at `TOPLEFT` `(x/100*1000, -y/100*667)`, 20 px, `marked = true`; viewed map without it → no shown pins; switching maps hides old pins; show-all off → only marks; show-all on → every candidate of repair, inn, supplies, `trainer_<class>`, weapon, and `prof_<id>` for the player's professions on that map (14 px, unmarked), a marked one drawn once (marked); refreshing twice doesn't grow the pool; hover tooltip lines (name, title, zone, `L.MAPPIN_REMOVE` for marks / `L.MAPPIN_CLICK_MARK` for show-all); right-click a mark unmarks; left-click a show-all pin marks it (`fromRow = false`). Run → FAIL.
- [ ] Implement: frames parented to the canvas child, `SetScale(1 / canvasScale)`; refresh hooked to `OnMapChanged`, `WorldMapFrame` `OnShow`, and `Services` mark changes. Icons: repair 136241, inn 134414, supplies 133950, trainers 136243, weapon 135324, professions 136240; marks get a gold ring (`Interface\\Minimap\\MiniMap-TrackingBorder`, tinted). Run → PASS. Commit.

### Task 12: Row buttons, menu, options, slash, docs

**Files:** modify `Rules/Simple.lua` (durability → `service = { kind = "repair" }`), `Rules/TrainerSpells.lua` (`trainer_<class>`), `Rules/WeaponTrainers.lua` (+ NPC IDs in `Data/WeaponTrainers.lua`: Woo Ping 11867, Buliwyf Stonehand 11865, Bixi Wobblebonk 13084, Ilyenia Moonfire 11866, Sayoc 11868, Hanashi 2704, Ansekhwa 11869, Archibald 11870; `service = { kind = "weapon", npcIDs = {…that row's trainers} }`), `Rules/Supplies.lua` (food row only → supplies), `Rules/Rested.lua` (→ inn), `Rules/ProfessionRank.lua` (trainer rows only → `prof_<skillLine>` from the 7th return of `GetProfessionInfo`); `Panel.lua` (row pin button; Ctrl+click in strip; tooltip hint), `Minimap.lua` (menu: checkbox `L.MENU_SERVICES`, button `L.MENU_CLEAR_MARKS` when any mark), `MapReveal.lua` options page (checkbox `NN_services_showAll`), `Core.lua` (`/nudge services`, `PruneRowMarks` call), locales, README, CHANGELOG, testing checklist; tests in the matching `tests/test_rules_*.lua`, `test_panel.lua`, `test_minimap.lua`, `test_slash.lua`, `test_options.lua`.

- [ ] Tests: each wired rule's row carries the right `service`; bandage/book/quest rows carry none; list row with a service shows `row.pinButton` (others hidden), its click marks (and again unmarks), gold when marked; strip Ctrl+click marks; tooltip line `L.ROW_HINT_MARK`; menu checkbox toggles `db.services.showAll`, "Remove all marks" only when marks exist; options checkbox round-trips; `/nudge services` toggles and prints; a row-made mark disappears when the row does (repair done). Run → FAIL.
- [ ] Implement; locale strings (enUS/esES): `SERVICES_MARKED = "Marked %s (%s) in %s."`, `SERVICES_NO_POSITION = "Can't tell where you are right now (try outside an instance)."`, `SERVICES_NONE = "No suitable %s found for your level and faction."`, `SERVICE_KIND_REPAIR/INN/SUPPLIES/WEAPON/TRAINER/PROF`, `MAPPIN_REMOVE = "Right-click: remove this mark"`, `MAPPIN_CLICK_MARK = "Click: mark it"`, `ROW_HINT_MARK = "Map button (or Ctrl+click): mark the closest on the world map"`, `MENU_SERVICES = "Show services on the world map"`, `MENU_CLEAR_MARKS = "Remove all map marks"`, `OPT_SERVICES = "Show nearby services on the world map"`, `OPT_SERVICES_TT`, `SLASH_SERVICES_ON/OFF`; `SLASH_HELP` gains `/nudge services`. Docs: README section "Map marks", CHANGELOG bullet, checklist lines + probes `/dump MINIMAP_TRACKING_REPAIR, MINIMAP_TRACKING_INNKEEPER, MINIMAP_TRACKING_VENDOR_FOOD` and `/dump C_Map.GetWorldPosFromMapPos(1453, CreateVector2D(0.5,0.5))`. Run → PASS, all suites green. Commit.

Then: whole-branch review of Tasks 9–12 (fresh reviewer), fix Critical/Important with RED→GREEN tests.

---

## Addendum (2026-11-22): spec §4e and §4f

### Task 13: Icon layout options (spec §4f)

**Files:** `Core.lua` (defaults `panel.iconsPerLine = 8, iconFlow = "rows", iconSize = 24, iconGap = 4`), `Panel.lua` (`Panel.STRIP_ICON()` = iconSize × (32/24 when the controller boost is on); layout reads the four settings), `Options.lua` (under Panel style: sliders `NN_panel_iconsPerLine` 1–12 step 1, `NN_panel_iconSize` 16–40 step 2, `NN_panel_iconGap` 0–12 step 1; dropdown `NN_panel_iconFlow` rows/columns), locales; tests in `tests/test_panel.lua`, `tests/test_options.lua`.

- [ ] Tests: defaults for an old database; rows with 3 per line (icon 4 at (0, −28), icon 3 at (56, 0), frame 3×28−4+12 square for 7 icons); columns with 3 per line (icon 2 at (0, −28), icon 4 at (28, 0)); size 30 / gap 0 (icon 2 at x 30, width 30); controller boost turns size 30 into 40; options round-trip and ranges. Run → FAIL.
- [ ] Implement; strings `OPT_ICONS_PER_LINE = "Icons per line"`, `OPT_ICON_FLOW = "Direction"`, `OPT_ICON_FLOW_TT`, `OPT_ICON_FLOW_ROWS = "Rows (left to right)"`, `OPT_ICON_FLOW_COLUMNS = "Columns (top to bottom)"`, `OPT_ICON_SIZE = "Icon size"`, `OPT_ICON_GAP = "Gap between icons"`. Run → PASS. Commit.

### Task 14: NewbieNudge list on the world map (spec §4e)

**Files:** create `NewbieNudge/MapList.lua` (TOC after `MapPins.lua`; `NN.MapList` with `frame`, `Toggle()`, `Refresh()`, `rows`); modify `MapReveal.lua` (left-click → `NN.MapList:Toggle()`, tooltip text), `MapPins.lua` (export `MapPins.IconFor(kind) -> texture, coords`; show-all draws only kinds with `db.services.kinds[kind] ~= false`), `Core.lua` (defaults `services.kinds = {}`, `map.listOpen = false`), locales; stub `WorldMapFrame:SetMapID(id)` (sets `S().worldMapID`, calls `OnMapChanged`); tests `tests/test_maplist.lua`, update `tests/test_mapreveal.lua` (left-click now toggles the list).

- [ ] Tests: left-click on the map icon shows the list, again hides it, `db.map.listOpen` follows; right-click still toggles reveal; rows: reveal checkbox, then one per kind of `MapPins.ShowAllKinds()` (label per kind; class trainer label uses the class name; profession lines use the profession name) with the pin icon; clicking a kind row flips `db.services.kinds[kind]` and sets `showAll = true`; a kind switched off draws no show-all pins; marks section lists each mark (name · zone) with a remove button that unmarks; clicking a mark line calls `WorldMapFrame:SetMapID(npc.map)`; "(none)" when no marks; "Remove all marks" clears; "Settings…" opens the Map page; list refreshes when a mark is added; opening the map with `listOpen = true` shows it. Run → FAIL.
- [ ] Implement; strings `MAPLIST_TITLE`, `MAPLIST_SHOW`, `MAPLIST_MARKS`, `MAPLIST_NONE`, `MAPLIST_REVEAL`, `MAPLIST_KIND_REPAIR/INN/SUPPLIES/WEAPON`, `MAPLIST_KIND_TRAINER = "%s trainers"`, `MAPLIST_KIND_PROF = "%s trainers"`, `MAPLIST_REMOVE_ALL`, `MAPLIST_SETTINGS`, `MAPLIST_REMOVE_TT`, `MAP_BUTTON_TT` updated. Run → PASS, all suites green. Docs (README map section, CHANGELOG bullets, checklist lines). Commit.

Then: review of Tasks 13–14 and the fixes since the last review; fix Critical/Important RED→GREEN.

### Task 15: Quickest route (spec §4g)

**Files:** `Services.lua`, fixture `tests/fixtures/services.lua` (+ taxi nodes on a continent map 1414 = continent 0, `mapWorld[1414]`), `tests/test_services.lua`, locales.

**Interfaces:** `Services:FlightMasters() -> { { name, continent, x, y } }` (discovered only, world yards); `Services:TravelTime(npcID, from?) -> seconds, route` with `route = { kind = "foot" }` or `{ kind = "fly", from = name, to = name }` and other-continent targets + 1e9; `Services:Ranked(kind, npcIDs?, count) -> { { id, time, route }, ... }` (quickest first, one per map); `Closest` = first of `Ranked(…, 1)`. Constants: run 7 yd/s, flight 30 yd/s × 1.3 route factor, 20 s take-off.

- [ ] Tests: walking wins when near; flying wins with both nodes known (player far from target, near node A; node B next to target); undiscovered landing node ignored; no `C_TaxiMap` → straight line; other continent loses; one result per map; `Ranked` order; chat line names the route `L.SERVICES_ROUTE_FLY:format(from, to)`. Run → FAIL; implement; PASS; commit.

### Task 16: Several options per mark (spec §4g)

**Files:** `Services.lua` (marks `{ kind, npcs = {…}, fromRow, rule }`, old `npcID` migrated; `MarkClosest` marks `Ranked(kind, npcIDs, db.services.options)`; `UnmarkOption(kind, npcID)`; `IsMarked(kind, npcIDs)` true when any option is in `npcIDs`), `MapPins.lua` (one pin per option, `pin.rank`, rank number fontstring, gold ring for rank 1, grey for others, tooltip `L.MAPPIN_OPTION:format(rank, minutes, routeText)`; right-click removes that option), `MapList.lua` (heading per mark + option lines with ✕), `Core.lua` default `services.options = 4`, Map page slider `NN_services_options` 1–5, Dev snapshot shows `npcs`, locales; tests updated across `test_services`, `test_mappins`, `test_maplist`, `test_service_rows`, `test_dev`.

- [ ] Tests: N options ranked, one per map; setting 1 → one option; old saved mark loads as `npcs = { id }`; numbered pins, gold ring only on rank 1; right-click removes one option; list heading + options with ✕; chat `L.SERVICES_MORE:format(n)`. Run → FAIL; implement; PASS; docs (README, CHANGELOG, checklist); commit.
