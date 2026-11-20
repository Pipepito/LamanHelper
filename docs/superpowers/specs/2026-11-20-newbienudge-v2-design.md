# NewbieNudge v2 — design spec

Date: 2026-11-20. Extends the v1 spec
(`2026-11-20-newbienudge-design.md`); everything there still holds unless a
section below says otherwise. Section numbers continue from v1 so the plan
can reference both.

## 10. Purpose of v2

Seven additions, all switchable in the options window, all in the same
"reminders in a panel, glanceable, nothing to read" style as v1:

1. **Map reveal**: the world map shows the whole zone, with unexplored parts
   drawn dimmed instead of blank.
2. **Tips as reminders**: "new spells at your class trainer", "you can learn
   the next profession rank", "a dungeon fits your level", "this zone is
   below (or above) your level".
3. **Quest planning**: which quests to turn in, which to finish before they
   stop giving experience, which already give almost none; plus how many bag
   slots the current quests will need.
4. **Bag-full helper**: when the bags are full and the player is trying to
   pick something up, a small list of the cheapest things to destroy, with a
   button per row, without closing the loot or quest window.
5. **Controller support**: a Controller section in the options for the
   gamepad settings Blizzard hides, one-click presets for the Steam Deck and
   for a plain controller, and the addon itself scaling up and showing
   controller button hints when a controller is in use. The user plays in the
   game's native gamepad mode on a Steam Deck with the trackpad as mouse;
   friends use Xbox controllers the same way.
6. **Game settings for new players**: the game's own options a beginner
   should set, gathered in one place with plain labels and a one-click
   preset (§23).
7. **Talent build from an Icy Veins link**: paste a build and the panel
   names the next talent to pick and glows it in the talent window (§24).

Two smaller reminders came with these: a materials bag not in use
(§13.5) and an item in the bags that starts a quest (§14.0).

The audience and the "low maintenance" goal from v1 §1 are unchanged. The
one new maintenance cost, static data for the map and the tips, is
contained in a single import script (§11) so a refresh is one command.

**Non-goals.** No readable handbook window. No d-pad navigation of the panel
(ConsolePort's job). No auction prices in the bag-full helper. No automatic
deletion. No map pins for trainers or nodes.

**Anti-goals.** A map tint that hides where the player has actually been. A
"slots needed" number that is confidently wrong. Destroying something the
player needed (a quest item, a bag, the Hearthstone).

## 11. Licence and vendored data

### 11.1 Licence

NewbieNudge becomes **GPL-3.0** (user decision, 2026-11-20). The repo gains
a `LICENSE` file with the full GPL-3.0 text, the TOC gains
`## X-License: GPL-3.0`, and the README gains a "Credits" section naming
WoW Handbook (Arcaneology/WowHandbookAddon, GPL-3.0) and, through it,
Questie / QuestieDB (GPL-3.0) as the source of the vendored data.

### 11.2 What is vendored and from where

Source repository: `https://github.com/Arcaneology/WowHandbookAddon`, branch
`main`. Four generated Lua files under `WowHandbook/Data/`, all keyed as
noted and all with the header "auto-generated data file, do not edit by
hand":

| Upstream file | Upstream shape | What we keep |
|---|---|---|
| `MapOverlays.lua` | `ns.Data.mapOverlays[uiMapID] = { { w, h, offsetX, offsetY, fileDataID, ... }, ... }` (45 maps) | Everything, unchanged. |
| `Spells.lua` | `ns.Data.spells[classToken] = { { name = {enUS,zhCN}, tab, icon, races?, ranks = { { rank, level, id? } } } }` | Per class: `{ level, id, rankIndex, spellIndex, races? }` for ranks that have an `id`. `spellIndex` groups ranks of one spell; `rankIndex` is the 1-based position in `ranks`. Names and icons are dropped (the client supplies them). |
| `Zones.lua` | `ns.Data.zones[uiMapID] = { slug, kind, levels = {min,max}?, faction?, name }` | `{ min, max }` for entries with `levels` and `kind == "zone"`. |
| `Dungeons.lua` | entries with `slug, kind, instanceID, levels = {min,max}, faction?, name = {enUS,zhCN}, entrance = {map,x,y}, quests = {...}, aggregateOnly?, dataPending?` | `{ instanceID, min, max, faction?, mapID, nameEN, quests }` for entries that are not `aggregateOnly` and not `dataPending`. |

Upstream class keys are lowercase (`warrior`); ours are the client's class
tokens (`WARRIOR`). Upstream `races` values are display names (`"Night Elf"`,
`"Undead"`); ours are the client's race tokens (`NightElf`, `Scourge`), using
the same mapping Handbook uses: strip spaces, `Undead → Scourge`.

### 11.3 The import script `tools/import_handbook.py`

- Python 3, no new dependencies: it already has `lupa` in `tools/pylib` and
  uses it to *execute* each upstream Lua file in a sandbox (a fake `...`
  returning an addon name and an `ns` table), then reads the resulting
  tables. No regex parsing of Lua.
- Downloads the four raw files from a commit hash given on the command line
  (`--ref main` to take the branch head). Prints the resolved commit hash.
- Writes four files into `NewbieNudge/Data/`: `MapFog.lua`,
  `TrainerSpells.lua`, `Zones.lua`, `Dungeons.lua`. Each starts with a
  header stating: generated by `tools/import_handbook.py`, source
  repository URL, source file path, source commit hash, generation date,
  "GPL-3.0, see LICENSE", "do not edit by hand". Each defines one table on
  the addon namespace: `NN.MapFog`, `NN.TrainerSpells`, `NN.Zones`,
  `NN.Dungeons`.
- Deterministic output (sorted keys) so a re-import with no upstream change
  produces no diff.
- The TOC loads the four data files right after `Data_Buffs.lua`.
- `README.md` documents the one command to refresh the data after a game
  patch.
- An offline test loads the generated files and checks their shapes (every
  map entry has at least five numbers; every spell entry has `level` and
  `id`; every dungeon has `instanceID`, `min`, `max`). The first import is
  committed as part of the implementation.

The generated files are the only place v2 depends on hand-kept game data.

## 12. Map reveal (`MapReveal.lua`)

### 12.1 Behaviour

When the world map shows a zone that is in `NN.MapFog`, every overlay tile
the player has **not** explored is drawn under Blizzard's own explored
tiles, desaturated and darkened, so the shape of the whole zone is visible
and the unexplored parts read as "not yet". Explored tiles look exactly as
Blizzard draws them. Zones not in the table (none of the 45 Forever zones is
missing, but a future patch could add one) simply get no reveal.

### 12.2 Mechanism

- The exploration layer is Blizzard's `MapExplorationPinTemplate` pin,
  acquired once by `MapExplorationDataProviderMixin` and refreshed through
  `pin:RefreshOverlays(fullUpdate)` on map change, on
  `MAP_EXPLORATION_UPDATED`, on show, and on canvas layer change.
- On `PLAYER_LOGIN`, or on `ADDON_LOADED` for `Blizzard_WorldMap` if
  `WorldMapFrame` does not exist yet, `MapReveal` finds the pin with
  `WorldMapFrame:EnumeratePinsByTemplate("MapExplorationPinTemplate")` and
  post-hooks `RefreshOverlays` on that pin with `hooksecurefunc(pin,
  "RefreshOverlays", fn)`. If no pin exists yet, it does not hook the data
  provider; it retries the enumeration each time `WorldMapFrame` is shown
  (`HookScript("OnShow")`) until a pin is found. The pin is
  remembered; if a later enumeration yields a different pin object, the new
  one is hooked too and the old one forgotten.
- The hook body:
  1. Release all textures in our own pool (`CreateTexturePool(pin, "ARTWORK",
     -1)`, created lazily per pin). Using our own pool means our tint never
     leaks into a texture Blizzard later reuses, so no reset pass is needed.
  2. If the option is off, stop.
  3. `mapID = pin:GetMap():GetMapID()`; `data = NN.MapFog[mapID]`; stop if
     nil.
  4. Build the explored set from
     `C_MapExplorationInfo.GetExploredMapTextures(mapID)`: key
     `w .. ":" .. h .. ":" .. x .. ":" .. y` from `textureWidth`,
     `textureHeight`, `offsetX`, `offsetY`. If the call returns nil or any
     field is a secret value, stop (draw nothing this refresh).
  5. `layers = C_Map.GetMapArtLayers(mapID)`; `layer = layers[pin.layerIndex]`
     (fallback `layers[1]`); `tileW, tileH = layer.tileWidth, layer.tileHeight`.
  6. For each data entry whose key is not in the explored set: lay the
     `fileDataIDs` out row by row exactly as Blizzard's `RefreshOverlays`
     does (`numWide = ceil(w / tileW)`, `numTall = ceil(h / tileH)`; the
     texture for row `j`, column `k` is `ids[(j-1)*numWide + k]`; edge tiles
     use the remainder width/height and texcoords against the next power of
     two of at least 16; `SetPoint("TOPLEFT", pin, "TOPLEFT", x + tileW*(k-1),
     -(y + tileH*(j-1)))`; `SetTexture(fileID, nil, nil, "TRILINEAR")`).
  7. Style each texture: `SetDesaturated(desaturate)`,
     `SetVertexColor(b, b, b, 1)` with `b = brightness`, draw layer
     `"ARTWORK"` sub-level `-1` so Blizzard's explored tiles (sub-level 0)
     draw over ours. If `pin:GetMap().AddMaskableTexture` exists, pass the
     texture to it so continent masks still apply.
- Option changes call `pin:RefreshOverlays()` if the map is shown so the
  change is visible at once.
- The pin's `textureLoadGroup` is left alone; our tiles may pop in a frame
  later than Blizzard's. Acceptable.

### 12.3 Options (a "Map" subcategory, §16)

- "Show unexplored areas on the world map" (checkbox, default on).
  Saved as `db.map.reveal`.
- "Unexplored area brightness" (slider 10–100 %, step 5, default 60),
  `db.map.brightness` stored as 0.1–1.0.
- "Unexplored areas in grey" (checkbox, default on), `db.map.desaturate`.
- `/nudge map` toggles the first option.

### 12.4 Tests

The stub gains `WorldMapFrame` with `EnumeratePinsByTemplate` returning one
fake pin (`GetMap()` → `{ GetMapID, AddMaskableTexture }`, `layerIndex = 1`,
`RefreshOverlays`), `C_MapExplorationInfo.GetExploredMapTextures` reading
`WOW.state.explored[mapID]`, `C_Map.GetMapArtLayers`, `CreateTexturePool`
returning textures that record `SetTexture`, `SetPoint`, `SetVertexColor`,
`SetDesaturated`, `SetDrawLayer`, and `hooksecurefunc` on tables. Tests:
unexplored tiles drawn and explored ones skipped; grid layout for a 2×2
entry; option off draws nothing; secret value in explored data draws
nothing; unknown map draws nothing; brightness applied; pool released on
every refresh (no texture growth across three refreshes).

## 13. Tips as reminders (new rules)

All four are ordinary rules per v1 §3.1, each with its own checkbox, each
hiding once the condition clears. New locale keys for every string.

### 13.1 `trainer_spells` — new spells at your class trainer

Replaces v1 §9 (the three options there are superseded by the vendored
table).

- Applies: `NN.TrainerSpells[playerClassToken]` exists.
- Condition: group entries by `spellIndex`. For each spell, skip entries
  whose `races` list exists and does not contain the player's race token
  (`select(2, UnitRace("player"))`). Skip entries whose `id` fails
  `C_Spell.DoesSpellExist(id)` (stale data must not produce a permanent
  row). `knownRank` = the highest `rankIndex` whose `id` passes
  `IsPlayerSpell(id)` (fallback `IsSpellKnown`). A spell is **trainable**
  when some entry has `rankIndex > knownRank` and `level <= UnitLevel("player")`.
  Result when at least one spell is trainable.
- Text: "N spells or ranks for your level you haven't learned. Visit your
  class trainer." (N = trainable spells, counted per spell not per rank).
  The help text adds that a few class spells come from quests instead, so
  a row that stays after a trainer visit means a class quest is waiting.
  (Builder-check ruling: the data has no "learned from quest" marker and a
  hand-kept exclusion list would break the low-maintenance goal.)
- Click: open the spellbook (`ToggleSpellBook(BOOKTYPE_SPELL)` fallback
  `PlayerSpellsUtil.ToggleSpellBookFrame`). Highlight: `spellbook`.
- Events: `PLAYER_LEVEL_UP`, `SPELLS_CHANGED`, `LEARNED_SPELL_IN_SKILL_LINE`.
  Not combat.
- The spell-ID-keyed design means it works in any client language.
- Known limitation, stated in the help text: the list follows the data
  file, so a rebalance can make it off by a spell until the data is
  refreshed.

### 13.2 `profession_rank` — next profession rank available

- Applies: `GetProfessions()` returns a primary profession (either of its
  first two values).
- Condition: for each of the first two values of `GetProfessions()` that
  is non-nil (primary professions only; Cooking, First Aid and Fishing
  reach Expert and Artisan through books and quests, so "visit a trainer"
  would be wrong for them),
  `GetProfessionInfo(index)` gives `name, icon, skillLevel, maxSkillLevel`.
  Rank table: `{ [75] = 10, [150] = 20, [225] = 35 }` mapping the current
  cap to the character level needed for the next rank (Apprentice →
  Journeyman at skill 50 / level 10, → Expert at 125 / level 20, → Artisan
  at 200 / level 35). A profession is **ready** when
  `rankTable[maxSkillLevel]` exists, `skillLevel >= maxSkillLevel - 25` and
  `UnitLevel("player") >= rankTable[maxSkillLevel]`. One result per ready
  profession, at most 2 rows then `MORE_ROWS`.
- Text: "You can learn the next rank of %s (%d/%d). Visit a %s trainer."
  with the profession name from the client (already localized).
- Click: none. Highlight: none. Snooze is the way to dismiss it until the
  trainer visit; it clears itself when `maxSkillLevel` rises.
- Events: `SKILL_LINES_CHANGED`, `CHAT_MSG_SKILL`, `PLAYER_LEVEL_UP`. Not
  combat.
- In-game check (checklist §0): that `GetProfessionInfo` on Forever returns
  the rank cap (75/150/225/300) as `maxSkillLevel`, not 300 flat. If it
  returns 300 flat, the rule falls back to the thresholds 50/125/200 against
  `skillLevel` alone (builder implements both paths behind one function;
  the checklist decides which is live).

### 13.3 `dungeon_ready` — a dungeon fits your level

- Applies: any.
- Condition: from `NN.Dungeons`, entries whose `faction` is nil or matches
  `UnitFactionGroup("player")` (lowercased), whose `min <= level <= max`,
  and which are not **done**. Done means `db.seen.dungeons[instanceID]` is
  true. It is set when `GetInstanceInfo()` reports that `instanceID` (the
  player went in), or when at least half of the entry's `quests` pass
  `C_QuestLog.IsQuestFlaggedCompleted`. Sorted by `min`; at most 2 rows.
- Text: "%s (%d–%d) fits your level. Pick up its quests before you go."
  Name: `GetRealZoneText(instanceID)` if it returns a non-empty string,
  else `nameEN`.
- Click: open the world map at the entrance zone (`OpenWorldMap(mapID)` if
  present, else `WorldMapFrame:SetMapID(mapID)` after `ToggleWorldMap()`).
  Highlight: none.
- Events: `PLAYER_LEVEL_UP`, `PLAYER_ENTERING_WORLD`, `ZONE_CHANGED_NEW_AREA`,
  `QUEST_TURNED_IN`. Not combat.

### 13.4 `zone_level` — this zone is below or above your level

- Applies: any.
- Condition: `mapID = C_Map.GetBestMapForUnit("player")`; walk up with
  `C_Map.GetMapInfo(mapID).parentMapID` until a map in `NN.Zones` is found
  or the map type is continent/world (stop). Skip inside instances
  (`IsInInstance()`). With `{min, max}` found: **below** when
  `level > max + 2`; **above** when `level < min - 2`.
- Text: below: "%s (%d–%d) is below your level. Quests here give less XP."
  above: "%s (%d–%d) is above your level. Be careful here." Name from
  `C_Map.GetMapInfo(zoneMapID).name`.
- Click: `ToggleWorldMap()`. Highlight: none.
- Events: `ZONE_CHANGED_NEW_AREA`, `ZONE_CHANGED`, `PLAYER_LEVEL_UP`,
  `PLAYER_ENTERING_WORLD`. Not combat.
- One rule, default on, covering both directions; there is no separate
  toggle for "above". A snooze lasts the usual 60 minutes, which covers
  "I know, I'm passing through".

### 13.5 `materials_bag` — a materials bag not in use

Forever has a separate materials (reagent) bag slot. v1's `bag_unequipped`
already ignores it (it only looks at family-0 containers and bags 1–4);
this rule tracks it on its own.

- Applies: `Enum.BagIndex.ReagentBag` exists and
  `C_Container.ContainerIDToInventoryID(Enum.BagIndex.ReagentBag)` returns
  a slot.
- Condition: a container item in bags 0–4 is a materials bag, and either
  the materials slot is empty, or the equipped materials bag has fewer
  slots (tooltip count as in v1 §4.1). "Is a materials bag" is decided by
  `NN.IsReagentBag(itemID)`: item class Container and item family equal to
  `NN.REAGENT_BAG_FAMILY`, a constant confirmed in game (checklist §0 asks
  for `/dump C_Item.GetItemFamily(id)` and `/dump select(7,
  C_Item.GetItemInfoInstant(id))` on a materials bag; the builder writes
  the family value and, as a fallback, the container subclass).
- Text: "You have a materials bag in your inventory that isn't equipped."
  or "A materials bag in your inventory is bigger than the one you're
  using."
- Click: `ToggleAllBags()`. Highlight: `bags`. Combat: true, like the other
  bag rules.
- Events: `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`.

### 14.0 `quest_item` — an item in your bags starts a quest

Listed under quest planning because that is where a new player looks.

- Applies: any.
- Condition: a stack in bags 0–4 for which
  `C_Container.GetContainerItemQuestInfo(bag, slot)` returns a `questID`
  and `isActive` is false (the item starts a quest the player has not
  accepted). One result per item, at most 3 rows then `MORE_ROWS`.
- Text: "%s starts a quest. Right-click it in your bags." with the item
  name from the client.
- Click: `ToggleAllBags()`. Highlight: `bags` **and** the item itself:
  `highlight = { key = "bags", bagslots = { { bag, slot } } }`. §3.7 gains
  a third target kind, `bagslots`: while the default bag frames are shown,
  each `{bag, slot}` is resolved to its item button
  (`ContainerFrameUtil_EnumerateContainerFrames()` →
  `frame:EnumerateValidItems()` → match `button:GetBagID()` and
  `button:GetID()`; combined-bag frame included), and glowed with the same
  overlay glow as action buttons. The mapping is rebuilt on `BAG_OPEN`,
  `BAG_CLOSED`, `BAG_UPDATE_DELAYED` and when a container frame is shown
  (`hooksecurefunc` on `ContainerFrame_Update` when present, else the
  `BAG_UPDATE_DELAYED` path alone). Blizzard's own "!" quest marker on the
  item stays; the glow is on top of it.
- Events: `BAG_UPDATE_DELAYED`, `QUEST_ACCEPTED`, `QUEST_LOG_UPDATE`. Not
  combat.

## 14. Quest planning (new rules)

Three small rules rather than one, so each has its own checkbox. They share
one helper, `NN.QuestScan()`, that walks the quest log once per check cycle
(memoised for the duration of one `RunChecks`) and returns a list of
`{ questID, title, level, isComplete, isTrivial, turnsGreyIn }`:

- Entries from `C_QuestLog.GetNumQuestLogEntries()` and
  `C_QuestLog.GetInfo(i)`, skipping `isHeader` and `isHidden`.
- `isComplete` = `C_QuestLog.IsComplete(questID)` (fallback
  `info.isComplete`).
- `isTrivial` = `C_QuestLog.IsQuestTrivial(questID)` when present, else
  `level + range < playerLevel` where `range = UnitQuestTrivialLevelRange
  and UnitQuestTrivialLevelRange("player") or GetQuestGreenRange and
  GetQuestGreenRange() or 5`.
- `turnsGreyIn` = `(level + range) - playerLevel + 1` levels from now
  (1 means "next level"), using `C_QuestLog.GetQuestDifficultyLevel(questID)`
  for `level` when available, else `info.level`.
- Any secret value in the scan makes the helper return `NN.UNKNOWN`, which
  the three rules pass through.

### 14.1 `quest_turnin` — quests ready to turn in

- Condition: `#complete >= 1`.
- Text: "N quest(s) complete: turn them in." Click: `ToggleQuestLog()`.
  Highlight: `quests`.

### 14.2 `quest_soon` — quests about to turn grey

- Condition: quests that are not complete, not trivial, and
  `turnsGreyIn <= 2`.
- Text: "N quest(s) stop giving full XP within 2 levels: finish them soon."
  Click: `ToggleQuestLog()`. Highlight: `quests`.

### 14.3 `quest_grey` — quests that give almost no XP

- Condition: quests that are trivial and not complete.
- Text: "N grey quest(s) give almost no XP: do them last or abandon them."
  Click: `ToggleQuestLog()`. Highlight: none (the turn-in row owns the glow).

Events for all three: `QUEST_LOG_UPDATE`, `QUEST_ACCEPTED`, `QUEST_REMOVED`,
`QUEST_TURNED_IN`, `PLAYER_LEVEL_UP`. Not combat. Priority order in
`NN.PRIORITY`: `materials_bag` right after `bag_unequipped`; `quest_item`
and `quest_turnin` right after `quests`, then `quest_slots`, `quest_soon`,
`quest_grey`, then the tips in the order 13.1–13.4.

### 14.4 `quest_slots` — bag slots the current quests will need

- Condition: `needed` = sum over quests in the log of:
  - for each objective from `C_QuestLog.GetQuestObjectives(questID)` with
    `type == "item"` and not `finished`: the objective text is of the form
    "Name: 3/10" or "3/10 Name" (locale-dependent); strip the `%d+/%d+`
    token and surrounding punctuation to get the item name. Find a stack in
    bags 0–4 whose item name equals it (`C_Container.GetContainerItemInfo`
    → `hyperlink` → `C_Item.GetItemInfo` name). If found: `stackSize =
    C_Item.GetItemMaxStackSizeByID(itemID)`; slots needed =
    `ceil(numRequired / stackSize) - stacksHeld`, floored at 0. If not
    found: 1.
  - for each quest with `isComplete`: `GetNumQuestLogRewards(questID)` plus
    1 if `GetNumQuestLogChoices(questID)` is greater than 0.
  `free` = regular free slots as in v1 §4.2. Result when `free < needed`.
- Text: "Keep %d bag slots free for your quests (you have %d)."
- Click: `ToggleAllBags()`. Highlight: `bags`.
- Events: `BAG_UPDATE_DELAYED`, `QUEST_LOG_UPDATE`, `QUEST_ACCEPTED`,
  `QUEST_REMOVED`, `QUEST_TURNED_IN`. Not combat.
- Help text says it is an estimate. In-game check: the shape of
  `GetQuestObjectives` entries (`type`, `text`, `numFulfilled`,
  `numRequired`, `finished`) on Forever, and the objective text format in
  English and Spanish.

## 15. Bag-full helper (`BagFull.lua`)

A small standalone frame, not a rule: it has no row in the panel and does
not go through `RunChecks`. The user will disable the DeleteCheapestItem
addon once this exists, so it must cover the everyday case on its own.

### 15.1 When it shows

- `UI_ERROR_MESSAGE` whose second argument equals the global string
  `ERR_INV_FULL`.
- `LOOT_OPENED` when regular free slots are 0.
- `/nudge trash` at any time, even with free slots. A frame opened this
  way ignores the automatic hiding below and closes only with its close
  button.
- Never while the option is off.

### 15.2 When it hides

- The player clicks its close button.
- Regular free slots become ≥ 1 **and** `LootFrame` is not shown (so the
  player can free several slots during one loot).
- `LOOT_CLOSED` arrives while free slots are ≥ 1.
- 90 seconds after it was shown, if neither of the above happened.

### 15.3 What it lists

Candidates: every stack in the backpack and in equipped bags whose family
is 0 (quivers, ammo pouches, soul bags and other special bags are skipped
whole), except:
- quest items (`C_Container.GetContainerItemQuestInfo(bag, slot).isQuestItem`
  or item class `Enum.ItemClass.Questitem`), and items that start a quest;
- items whose name matches an unfinished item objective of a quest in the
  log (reusing the name matching of §14.4);
- container items (bags), the Hearthstone (item 6948), locked slots;
- item classes `Projectile`, `Quiver`, `Key`, `Reagent` (ammo, soul shards,
  class reagents);
- items that can be equipped (`GetItemInfoInstant` equip location not
  empty), unless Poor quality (profession tools and fishing poles are
  white equippables; grey weapons and armour are the usual junk);
- items with a sell price of 0, unless Poor quality (conjured food and
  water, no-value consumables);
- anything above the "max quality" option (default: Uncommon/green).
These rules are class-based, so no item list is kept by hand.
Each candidate: `icon, name, quality, count, sellPrice` from
`C_Item.GetItemInfo(hyperlink)`; `value = sellPrice * count`. If any of
those is a secret value, the stack is skipped.

Order: Poor (grey) quality first, then ascending `value`, then ascending
quality, then ascending count. The frame shows the first 6.

Row layout, left to right: 20 px icon, name in its quality colour with
`×count` when count > 1, value as a money string
(`C_CurrencyInfo.GetCoinTextureString(value)` fallback `GetMoneyString`),
and a "Destroy" button.

### 15.4 Destroy

- Click: `ClearCursor(); C_Container.PickupContainerItem(bag, slot); if
  CursorHasItem() then DeleteCursorItem() else ClearCursor() end`.
- For Common and Uncommon quality the first click turns the button into
  "Sure?" for 3 seconds; the second click destroys. Grey destroys on one
  click.
- Before acting, the row re-reads `GetContainerItemInfo(bag, slot)` and
  compares `itemID` and `stackCount` with what it listed; a mismatch (the
  bag changed) refreshes the list instead of destroying.
- After a destroy the list refreshes on the next `BAG_UPDATE_DELAYED`.

### 15.5 Frame

- Title "Bags full — cheapest to destroy", a close button, rows as above,
  one line of small text at the bottom: "Quest items and bags are never
  listed." Width about 300 px.
- Anchored to the right of `LootFrame` when it is shown, otherwise at the
  saved position (`db.bagfull.point/x/y`, default centre-left). Draggable
  always (title bar), position saved.
- All buttons are plain `UIPanelButtonTemplate` buttons, so the gamepad
  cursor can click them.
- Options ("Bags" subcategory, §16): enable (default on), max quality
  dropdown (Poor / Common / Uncommon, default Uncommon), "Also open on
  loot when bags are full" (default on).

### 15.6 Tests

Stub additions: `UI_ERROR_MESSAGE` firing with `ERR_INV_FULL`, `LootFrame`
with `IsShown`, `C_Container.GetContainerItemQuestInfo`, `CursorHasItem`,
`DeleteCursorItem`, `ClearCursor`, `GetContainerItemInfo` returning `isLocked`.
Tests: order (grey first, then value); exclusions (quest item, objective
item by name, bag, Hearthstone, locked, above max quality); shows on error
message and on loot with 0 free; hides when a slot frees and loot is
closed; stays while loot is open; destroy calls pickup then delete; "Sure?"
gate on green; mismatch refreshes instead of destroying; secret value skips
the stack.

## 16. Options window restructure

The single long page becomes a parent category with subcategories, all
through `Settings.RegisterVerticalLayoutSubcategory(parentCategory, name)`:

| Category | Contents |
|---|---|
| NewbieNudge | General (v1 §3.4 part 1) and Reminders (v1 §3.4 part 2, now including the eight new rules). |
| Map | §12.3 |
| Bags | §15.5 options |
| Camera | v1 §3.4 part 3, moved unchanged |
| Controller | §17 |
| Game settings | §23 |
| Talent build | §24 |

`/nudge` opens the parent. `Options.AddDropdown(layout, name, variable,
label, help, optionsTable)` is added for the new dropdowns, built on
`Settings.CreateDropdown` with `Settings.CreateControlTextContainer`.

## 17. Controller (`Controller.lua`)

### 17.1 Controller section in the options

Shown only when `C_GamePad` exists (every Forever client; the guard is for
the test stub and for safety). Built from the same three parts as the
camera section: a curated list, presets, and discovery.

**Curated list.** Labels and help are locale keys. Kinds: `checkbox`,
`slider`, `dropdown`, `padbutton`.

| CVar | Control | Notes |
|---|---|---|
| `GamePadEnable` | checkbox | First in the list. |
| `GamePadCameraYawSpeed` | slider 0.25–4, step 0.25 | |
| `GamePadCameraPitchSpeed` | slider 0.25–4, step 0.25 | |
| `GamePadTurnWithCamera` | dropdown 0 Never / 1 In combat / 2 Always | |
| `GamePadFaceMovementMaxAngle` | slider 0–180, step 5 | help names 115 as the strafing sweet spot |
| `GamePadFaceMovementMaxAngleCombat` | slider 0–180, step 5 | |
| `GamePadAnalogMovement` | checkbox | |
| `GamePadRunThreshold` | slider 0–1, step 0.05 | |
| `GamePadCursorAutoEnable` | checkbox | |
| `GamePadCursorCentering` | checkbox | |
| `GamePadCursorCenteredEmulation` | checkbox | |
| `GamePadCursorAutoDisableJump` | checkbox | |
| `GamePadCursorAutoDisableSticks` | dropdown 0 Never / 1 Movement / 2 Movement and cursor | |
| `GamePadCursorSpeedStart` | slider 0.05–1, step 0.05 | |
| `GamePadCursorSpeedAccel` | slider 0–5, step 0.25 | |
| `GamePadCursorSpeedMax` | slider 0.25–3, step 0.25 | |
| `GamePadTouchCursorEnable` | checkbox | Steam Deck trackpad |
| `GamePadOverlapMouseMs` | slider 0–5000, step 250 | how long mouse and pad input overlap before switching |
| `GamePadCursorLeftClick` | padbutton | |
| `GamePadCursorRightClick` | padbutton | |
| `GamePadEmulateShift` | padbutton | |
| `GamePadEmulateCtrl` | padbutton | |
| `GamePadEmulateAlt` | padbutton | |
| `GamePadEmulateEsc` | padbutton | |
| `GamePadEmulateTapWindowMs` | slider 100–1000, step 50 | |
| `GamePadVibrationStrength` | slider 0–2, step 0.1 | |
| `SoftTargetInteract` | dropdown 0 Off / 1 Gamepad / 2 Keyboard and mouse / 3 Always | |
| `SoftTargetEnemy` | same dropdown | |
| `SoftTargetFriend` | same dropdown | |
| `SoftTargetInteractRange` | slider 5–30, step 1 | |
| `SoftTargetEnemyArc` | dropdown 0 In front / 1 Front arc / 2 Anywhere | |
| `SoftTargetIconInteract` | checkbox | |
| `SoftTargetIconEnemy` | checkbox | |
| `SoftTargetIconGameObject` | checkbox | |
| `SoftTargetNameplateEnemy` | checkbox | |
| `SoftTargetNameplateSize` | slider 10–40, step 1 | |

`padbutton` is a dropdown over: `none`, `PADLTRIGGER`, `PADRTRIGGER`,
`PADLSHOULDER`, `PADRSHOULDER`, `PADLSTICK`, `PADRSTICK`, `PADBACK`,
`PADFORWARD`, `PADSYSTEM`, `PADSOCIAL`, `PADPADDLE1`–`PADPADDLE4`,
`PAD1`–`PAD6`, `PADDUP`, `PADDDOWN`, `PADDLEFT`, `PADDRIGHT`. Each shows
`GetBindingText(name)` as its label (the client's own short names, e.g.
"RT"), falling back to the raw name. A CVar whose current value is not in
the list shows that raw value as an extra entry rather than being lost.

Dropdown CVars whose live value is outside the listed set show the raw
value as an extra entry too. Sliders clamp the live value into the range
for display but never write unless the player moves them.

**Presets.** Three buttons: "Apply Steam Deck preset", "Apply controller
preset", "Reset controller settings to defaults" (writes
`GetCVarDefault` for every curated CVar). A preset is a table of CVar →
value, applied with `Controller:Set`, followed by one chat line listing
what changed. Values are **draft**, to be confirmed by the user in game
(checklist §0 has a line per preset); the table lives in one place
(`Controller.PRESETS`) so a correction is a one-line change:

| CVar | Steam Deck | Controller |
|---|---|---|
| `GamePadEnable` | 1 | 1 |
| `GamePadTouchCursorEnable` | 1 | (unchanged) |
| `GamePadOverlapMouseMs` | 500 | (unchanged) |
| `GamePadCursorCentering` | 0 | 0 |
| `GamePadTurnWithCamera` | 2 | 2 |
| `GamePadFaceMovementMaxAngle` | 115 | 115 |
| `GamePadFaceMovementMaxAngleCombat` | 115 | 115 |
| `GamePadAnalogMovement` | 1 | 1 |
| `SoftTargetInteract` | 1 | 1 |
| `SoftTargetIconInteract` | 1 | 1 |
| `SoftTargetIconEnemy` | 1 | 1 |
| `SoftTargetNameplateEnemy` | 1 | 1 |

Presets never touch the modifier or click buttons.

**Discovery.** As the camera one (v1 §3.4 part 3): every CVar from
`C_Console.GetAllCommands()` whose name starts with `GamePad` or
`SoftTarget` and is not curated. The camera discovery code is generalised
into `NN.CVarSection` (prefix filter, curated list, exclude list, reset)
and both Camera and Controller use it; Camera's behaviour is unchanged.

### 17.2 The addon when a controller is in use

- `NN.Controller.session` becomes true the first time
  `GAME_PAD_ACTIVE_CHANGED` arrives with `isActive == true`, or at login
  when `C_GamePad.IsEnabled()` is true and `GamePadEnable` is `"1"` and
  `C_GamePad.GetActiveDeviceID()` returns a non-zero number. It stays true
  until logout (the Deck trackpad flips active input to mouse constantly;
  a sticky flag avoids the panel resizing every few seconds).
- While `session` is true and `db.controller.boost` is on (default on):
  - The panel's effective scale is `db.panel.scale × db.controller.scale`
    (`db.controller.scale` default 1.25, slider 1.0–1.6, step 0.05). The
    combat strip icons grow from 24 to 32 px.
  - Row tooltips replace "Left-click" with the left-click pad button and
    "Right-click" with the right-click pad button, names from
    `GetBindingText(GetCVar("GamePadCursorLeftClick"))` and the right-click
    CVar; "Shift" becomes the `GamePadEmulateShift` button. Locale keys
    `ROW_HINT_CLICK_PAD` ("%s: open") and `ROW_HINT_SNOOZE_PAD` ("%s: snooze,
    %s+%s: snooze until next login").
  - The bag-full frame and its buttons use the same boosted scale.
- Options ("Controller" subcategory, above the CVars): "Scale up the panel
  when a controller is in use" (checkbox), the scale slider, and "Show
  controller button hints" (checkbox, default on, `db.controller.hints`).
- A `Bindings.xml` registers four bindable actions under the header
  "NewbieNudge": toggle panel (`NEWBIENUDGE_TOGGLE`), open the top row
  (`NEWBIENUDGE_OPEN_TOP`), snooze the top row (`NEWBIENUDGE_SNOOZE_TOP`),
  open options (`NEWBIENUDGE_OPTIONS`). The game's own key-binding window
  lets players put them on pad combinations once `GamePadEnable` is on.
  Toggle adds `db.panel.hidden`; while hidden the panel stays hidden until
  toggled back, and `/nudge` prints a one-line reminder that it is hidden.

### 17.3 Tests

Stub: `C_GamePad` (`IsEnabled`, `GetActiveDeviceID`), `GetBindingText`,
events `GAME_PAD_ACTIVE_CHANGED`, `GAME_PAD_CONNECTED`. Tests: session flag
set by event and sticky; set at login from the three conditions; panel
scale multiplied while session and boost on, not otherwise; strip icon
size; tooltip hint text uses pad button names; preset applies its table
and prints one line; reset writes defaults; padbutton dropdown includes the
raw current value when unknown; dropdown values round-trip as strings;
`CVarSection` discovery prefix filter; bindings functions act on the top
row; hidden panel stays hidden through `Refresh`.

## 18. Saved variables added

```lua
map        = { reveal = true, brightness = 0.6, desaturate = true },
bagfull    = { enabled = true, maxQuality = 2, onLoot = true, point = "LEFT", x = 40, y = 0 },
controller = { boost = true, scale = 1.25, hints = true },
build      = nil, -- { picks, version, source, savedAt } once a link is pasted
seen.dungeons = { [instanceID] = true },
panel.hidden = false,
```

Defaults merge as in v1 (missing keys filled, nothing overwritten).

## 19. Locale and text

Every new string is a key in `enUS.lua` and translated in `esES.lua`; the
parity test keeps them aligned. Pad button names, spell names, profession
names, zone names and dungeon names come from the client. Dungeon `nameEN`
is the only English fallback and is used only when `GetRealZoneText` has
nothing.

## 20. Testing

- Offline: sections 11.3, 12.4, 15.6, 17.3 plus one test per new rule in
  13 and 14 (appear, disappear, snooze, secret value keeps previous) and
  the options subcategory registration. Target: the existing 202 tests plus
  the new ones, all green on `python tests/run.py`.
- In-game checklist (`docs/testing-checklist.md`) gains a §0 block per
  feature for the API shapes this spec assumes but could not verify
  offline: `GetQuestObjectives` entry fields and text format (EN and ES),
  `GetProfessionInfo` max skill per rank, `GetRealZoneText(instanceID)`,
  `C_QuestLog.IsQuestTrivial`, `UnitQuestTrivialLevelRange`,
  `GetBindingText("PADRTRIGGER")`, `GAME_PAD_ACTIVE_CHANGED` on the Deck,
  `C_MapExplorationInfo.GetExploredMapTextures` on a partly explored zone,
  `GetContainerItemQuestInfo` (fields `isQuestItem`, `questID`,
  `isActive`), the materials bag family and subclass, the controller and
  new-player preset tables, Icy Veins `nodeId` against
  `C_Traits.GetNodeInfo`, and `GetTalentButtonByNodeID` on the talent
  frame.

## 21. What is left to the builder

- Exact frame layout and textures of the bag-full frame and the panel
  scaling, within the sizes above.
- How `NN.QuestScan` memoises within one `RunChecks` (a generation counter
  is the obvious way).
- The Lua sandbox details in the import script and the compact formatting
  of the generated files.
- Whether `Options.AddDropdown` uses `Settings.CreateDropdown` or the
  `CreateSettingsListSectionHeaderInitializer` path; whichever renders in
  Forever's Settings panel.
- Order of the four tips rules in the Reminders list (after the quest
  rules, in the order 13.1–13.4 is the default).
- The exact plain-language labels in §23 (the table gives the intent;
  the builder may shorten them to fit the Settings panel's label width).

## 22. Approaches considered

- **Data source for map, spells, zones, dungeons.** (a) Vendor WoW
  Handbook's generated tables under GPL-3.0 with an import script;
  (b) generate our own from wago.tools DB2 exports and keep the original
  licence; (c) borrow Mapster's Forever fog table. Chosen: (a), user
  decision: cheapest, upstream maintains it, and one script refreshes it.
  (b) is more tooling to maintain; (c) is "All rights reserved".
- **Controller support.** (1) Settings only; (2) settings plus a
  controller-aware addon (scale, hints, bindings); (3) full d-pad
  navigation. Chosen: (2), user decision. (3) is ConsolePort's territory.
- **Quest planning.** One rule with three rows vs three rules. Chosen:
  three rules, so each is switchable, matching "all configurable".
- **Bag-full helper.** Rule row in the panel vs a standalone frame next to
  the loot window. Chosen: standalone frame, because the point is to act
  without closing what the player has open, and a panel row is not where
  their eyes are at that moment.
- **Talent build input.** (a) Paste the guide URL and ship a table of
  guide → build strings; (b) paste the "Open in Calculator" link, which
  carries the whole pick order; (c) ask the player to type the talents.
  Chosen: (b). The guide pages block scripted downloads, so (a) would
  need hand upkeep for 27 guides × 3 builds; (b) also covers a player's
  own build made in the calculator.
- **Bag-full exclusions.** A hand-kept list of protected item IDs vs
  class-based rules. Chosen: class-based (ammo, reagents, keys, equippable
  non-grey, zero-value non-grey, special bags skipped whole), so nothing
  needs maintaining; the cost is that some junk white equippables are not
  offered.
- **Map tint.** Colour picker with alpha (Mapster) vs brightness slider
  plus grey toggle. Chosen: the latter; two controls a new player
  understands, and the default already looks right.

## 23. Game settings for new players (`GameSettings.lua`)

User request (2026-11-20): gather the game's own settings a new player
should set, scattered across Blizzard's menus, into one place with plain
labels and a one-click preset. Same machinery as Camera and Controller
(`NN.CVarSection`, §17.1), curated only, no discovery. Shown as the "Game
settings" subcategory (§16).

### 23.1 Groups and controls

Each row: plain label, a one-sentence help text saying what a new player
gets from it, the control, and the value the "Recommended for new
players" preset writes (blank = the preset leaves it alone). Scope is from
the client; character-scoped values apply to the current character only
and the help text says so for those rows.

**Looting**
| CVar | Control | Preset |
|---|---|---|
| `autoLootDefault` | checkbox "Loot everything with one click" | 1 |
| `lootUnderMouse` | checkbox "Open loot at the mouse" | 1 |

**Names and nameplates**
| `nameplateShowEnemies` | checkbox "Health bars over enemies" | 1 |
| `nameplateShowEnemyMinus` | checkbox "Health bars over weak enemies too" | 1 |
| `nameplateShowAll` | checkbox "Show enemy health bars outside combat" | 1 |
| `nameplateShowFriendlyPlayers` | checkbox "Health bars over friendly players" | 0 |
| `nameplateShowFriendlyNpcs` | checkbox "Health bars over friendly NPCs" | 0 |
| `nameplateShowSelf` | checkbox "Your own resource bar under your character" | |
| `nameplateMaxDistance` | slider 20–60 "How far away health bars show" | |
| `UnitNameNPC` | checkbox "Names over NPCs" | 1 |
| `UnitNameInteractiveNPC` | checkbox "Names over NPCs you can talk to" | 1 |
| `UnitNameFriendlyPlayerName` | checkbox "Names over friendly players" | 1 |
| `UnitNameEnemyPlayerName` | checkbox "Names over enemy players" | 1 |
| `UnitNameOwn` | checkbox "Your own name over your head" | |

**Combat and casting**
| `ActionButtonUseKeyDown` | checkbox "Cast when the key goes down (faster)" | 1 |
| `autoSelfCast` | checkbox "Heal yourself when you have no friendly target" | 1 |
| `lockActionBars` | checkbox "Lock the action bars so spells can't be dragged off" | 1 |
| `AutoPushSpellToActionBar` | checkbox "Put newly learned spells on the bar" | 1 |
| `countdownForCooldowns` | checkbox "Numbers on cooldowns" | 1 |
| `SpellQueueWindow` | slider 0–400 step 50 "Queue the next spell this early (ms)" | 400 |
| `deselectOnClick` | checkbox "Clicking the ground clears your target" | 0 |
| `TargetEnemyAttacker` | checkbox "Target whoever attacks you" | 1 |
| `assistAttack` | checkbox "Start attacking after assisting" | |
| `stopAutoAttackOnTargetChange` | checkbox "Stop attacking when you change target" | 0 |
| `threatWarning` | dropdown 0 Off / 1 Dungeons / 2 Groups / 3 Always "Warn when a monster turns on you" | 3 |
| `enableFloatingCombatText` | checkbox "Damage and healing numbers over your head" | 1 |
| `floatingCombatTextCombatDamage_v2` | checkbox "Damage numbers on enemies" | 1 |
| `floatingCombatTextCombatHealing_v2` | checkbox "Healing numbers" | 1 |
| `displaySpellActivationOverlays` | checkbox "Big glow when a special ability is ready" | 1 |
| `spellActivationOverlayOpacity` | slider 0–1 step 0.05 "How strong that glow is" | |
| `secureAbilityToggle` | checkbox "Protect against double-clicking an ability off" | 1 |

**Moving and interacting**
| `interactOnLeftClick` | checkbox "Left-click talks to NPCs" | 1 |
| `autoDismount` | checkbox "Dismount automatically when needed" | 1 |
| `autoClearAFK` | checkbox "Clear AFK when you move or chat" | 1 |
| `autoInteract` | checkbox "Walk to the thing you clicked" | |

**Quests, map and screen**
| `autoQuestWatch` | checkbox "Track new quests automatically" | 1 |
| `autoQuestProgress` | checkbox "Show quest progress as you go" | 1 |
| `showQuestObjectivesInLog` | checkbox "Objectives in the quest log list" | 1 |
| `questPOI` | checkbox "Quest markers on the map" | 1 |
| `ShowQuestUnitCircles` | checkbox "Circle under quest monsters" | 1 |
| `showTutorials` | checkbox "Game tutorials" | 1 |
| `showNPETutorials` | checkbox "New-player tutorials" | 1 |
| `screenEdgeFlash` | checkbox "Red flash when attacked with the map open" | 1 |
| `doNotFlashLowHealthWarning` | checkbox "Don't flash red at low health" | 0 |
| `mapFade` | checkbox "See through the map while moving" | 1 |
| `rotateMinimap` | checkbox "Rotate the minimap with you" | 0 |
| `statusText` | checkbox "Numbers on health and mana bars" | 1 |
| `statusTextDisplay` | dropdown NUMERIC / PERCENT / BOTH "Which numbers" | BOTH |
| `expandBagBar` | checkbox "Show every bag next to the backpack" | 1 |
| `Outline` | dropdown 0 Off / 1 Mouseover / 2 Mouseover and target "Outline around targets" | 2 |
| `findYourselfMode` | dropdown 0 Circle / 1 Circle and outline / 2 Outline "How to spot yourself in a crowd" | |
| `chatBubbles` | checkbox "Speech bubbles" | 1 |
| `guildMemberNotify` | checkbox "Tell me when guild members log in" | |
| `Sound_EnableErrorSpeech` | checkbox "Spoken error messages ('I can't do that yet')" | |

### 23.2 Buttons

- "Recommended for new players": writes every preset value in 23.1
  through `C_CVar.SetCVar`, skipping CVars the client does not know
  (`GetCVarDefault` nil), and prints one chat line with how many changed.
  Secure CVars cannot be set in combat; the button is disabled while
  `InCombatLockdown()` and the help text says to try again out of combat.
- "Reset these to game defaults": writes `GetCVarDefault` for every row.

### 23.3 Out of scope

Action bar 2–8 visibility and layout live in Edit Mode, not in CVars, and
no documented addon API toggles them; the help text of the "Combat" group
points the player to Edit Mode for extra bars. `uiScale` is left to
Blizzard's own slider. Names come from the client, so every row works in
Spanish too; labels and help are locale keys.

### 23.4 Tests

Preset writes exactly its table and skips unknown CVars; reset writes
defaults; the section registers under the "Game settings" subcategory;
dropdown string values (`statusTextDisplay`) round-trip; the preset button
refuses in combat.

## 24. Talent build from an Icy Veins link (`TalentBuild.lua`, rule `talent_build`)

User request (2026-11-20): paste an Icy Veins leveling build and have the
addon point at the next talent to pick, like the level slider on the site.

### 24.1 What the player pastes, and why

An addon cannot read the web, so the link has to carry the build itself.
On every Forever leveling guide the "Leveling Talent Build" section embeds
Icy Veins' own talent calculator, with an **"Open in Calculator"** link per
build of the form

```
https://www.icy-veins.com/wow-forever/priest-talent-calculator#tc-11BBBBBDDCCC…KLzz~70938-3ee47080
```

The part after `#tc-` is the whole leveling path: **one character per
talent point, in the order the guide takes them** (character 1 is the
point at level 10, character 51 the point at level 60). Each character is
a talent's `urlId` in Icy Veins' per-class talent data; `~70938-3ee47080`
is the version of that data. The guide page URL itself carries none of
this and the site blocks non-browser downloads, so the player pastes the
"Open in Calculator" link, not the guide URL. The options text says
exactly that, in one sentence, with the guide's three builds in mind:
"open the guide, pick a build, click Open in Calculator, copy the address."

### 24.2 Vendored data: `Data/IcyTalents.lua`

Icy Veins serves its talent data as static JSON that plain HTTP clients
can download (verified 2026-11-20):

- `https://static.icy-veins.com/r2/icydb/wowf/talents/index.json` →
  `{ product = "wowf", latest = "<version>", versions = { { version,
  build, created, changed, layoutChanged }, ... } }`.
- `https://static.icy-veins.com/r2/icydb/wowf/talents/<version>/<class>.json`
  → `{ class, slug, classId, talentGroups = { { name, slug, talents = {
  { name, slug, nodeId, icon, urlId, requiredPoints, maxRank, ranks = {
  { id, tooltip }, ... } } or null, ... } }, ... } }`.

`tools/import_icy_talents.py` (no new dependencies, `urllib`) downloads
the index and the nine class files of the latest version and writes
`NewbieNudge/Data/IcyTalents.lua`:

```lua
NN.IcyTalents = {
  version = "70959-a8fe1dab",
  compatible = { ["70959-a8fe1dab"] = true, ["70938-3ee47080"] = true, ... },
  PRIEST = { ["0"] = { node = 12345, spell = 1309969, maxRank = 5 }, ["B"] = {...}, ... },
  ...
}
```

`compatible` lists every version in the index back to, and including, the
most recent one with `layoutChanged = true` (urlIds only move when the
layout changes). Names and icons are not vendored; the client supplies
them. Same header rules and determinism as §11.3. The talent-data files
are Icy Veins' own; the import keeps only identifiers and credits the
source in the header and the README.

### 24.3 Parsing a pasted link

`NN.TalentBuild.Parse(text)` accepts the full URL, or just the fragment
with or without `#tc-`. It returns `{ class = "PRIEST", version =
"70938-3ee47080", picks = { "1", "1", "B", ... } }` or `nil, reason`:
- class from the `<class>-talent-calculator` path segment, upper-cased;
  when the text has no path (fragment only), the player's own class;
- picks from the characters between `tc-` and `~`; every character must be
  a key of `NN.IcyTalents[class]`, else `reason = "unknown talent"`;
- the build's class must be the player's class, else `reason = "wrong
  class"`;
- a version not in `compatible` is accepted with a one-line warning that
  the guide data is older than the addon's and names may be off.
The result is stored per character in `db.build = { picks, version,
source = text, savedAt = time() }`.

### 24.4 The rule

- Applies: `db.build` exists and level ≥ 10.
- Condition: with `configID`, `treeID` as in v1 §4.3, read every node's
  purchased ranks: for each `nodeID` in `C_Traits.GetTreeNodes(treeID)`,
  `C_Traits.GetNodeInfo(configID, nodeID).ranksPurchased` (fallback
  `activeRank`). Walk `picks` in order keeping a running count per urlId;
  the **next pick** is the first position whose running count exceeds the
  player's purchased ranks on that talent's node. If every pick is
  satisfied, no row. If unspent points (v1 §4.3) are 0, no row either, but
  the computation is cached so the row appears the moment a point is
  available.
- Text: "Next talent: %s (%d/%d)." with the talent name from
  `C_Traits.GetDefinitionInfo(entry.definitionID).spellID` →
  `C_Spell.GetSpellName`, falling back to `C_Spell.GetSpellName(spell)`
  from the data; `%d/%d` is purchased plus one over `maxRank`. A second
  row "Your talents differ from the build; the next suggestion follows the
  build's order." appears only when the player has purchased ranks on a
  node the build never reaches before the next pick (so they know why the
  suggestion may look out of order).
- Click: open talents (v1 §4.3). Highlight: `talents`, plus the talent
  button itself when the talent frame is shown: a fourth target kind,
  `node = nodeID`, resolved through
  `PlayerSpellsFrame.TalentsFrame:GetTalentButtonByNodeID(nodeID)` or
  `ClassTalentFrame.TalentsTab:GetTalentButtonByNodeID(nodeID)`, whichever
  exists, re-resolved when the frame shows (`HookScript("OnShow")`) and on
  `TRAIT_NODE_CHANGED`. No frame or no button means no glow and no error.
- Events: `TRAIT_TREE_CURRENCY_INFO_UPDATED`, `TRAIT_CONFIG_UPDATED`,
  `TRAIT_NODE_CHANGED`, `PLAYER_TALENT_UPDATE`, `PLAYER_LEVEL_UP`. Not
  combat.
- In-game check (checklist §0): that `nodeId` in Icy Veins' data equals
  the client's trait node ID (compare one talent through
  `C_Traits.GetNodeInfo`), and which talent frame exposes
  `GetTalentButtonByNodeID`. If `nodeId` does not match, the mapping falls
  back to the rank-1 spell ID against `GetDefinitionInfo(...).spellID`,
  which the import also stores.

### 24.5 Options ("Talent build" subcategory, §16) and slash

- A multi-line edit box "Paste an Icy Veins talent calculator link", an
  "Use this build" button, a "Clear build" button, and a status line:
  "Shadow Priest build, 51 points, 12 taken, next: Spirit Tap" or "No
  build set" or the parse error in plain words.
- `/nudge build <link>` does the same; `/nudge build clear` clears.
- Saved variables: `db.build` (24.3).

### 24.6 Tests

Fixture: a small `IcyTalents` table for one class. Tests: full URL,
fragment-only and `#tc-`-prefixed inputs parse to the same picks; unknown
character rejected; wrong class rejected; incompatible version warns but
loads; next pick with no points spent is pick 1; after the first three
picks' ranks are purchased the next is pick 4; a player who skipped a
talent gets that earliest missing talent back; all picks satisfied gives
no row; zero unspent points gives no row; the "differs" row appears only
when the player holds ranks the build has not reached; highlight carries
the node ID; `/nudge build clear` empties `db.build`.
