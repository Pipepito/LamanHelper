# NewbieNudge in-game testing checklist

Run with `/console scriptErrors 1` so Lua errors show. `/reload` after each
code change. The offline suite (`python tests/run.py`) must be green first.

## 0. API shape checks (do these first, once per client build)

Type each in chat and note whether the shape matches what the rule expects.
Where it differs, fix the rule and `tests/wow_stub.lua` together and add a test.

| `/dump …` | Rule | Expected |
|---|---|---|
| `/dump UnitUsesAmmo("player")` | ammo | `true`/`false`; `nil` function means rule never applies |
| `/dump GetInventoryItemCount("player", 0)` | ammo | ammo count number |
| `/dump C_PetInfo.GetPetHappiness()` | pet | number 1–3 first, or a table with `happiness` |
| `/dump C_PetInfo.GetPetTrainingPoints()` | pet | `total, spent` or a table `{totalPoints, spent}` |
| `/dump HasPetUI()` | pet | `hasUI, isHunterPet` |
| `/dump GetProfessions()` | professions | `prof1, prof2, …` indexes or nil |
| `/dump C_SkillInfo.GetSkillLineInfo(1)` | professions | table with `skillName`/`isHeader` (only matters if `GetProfessions` is nil) |
| `/dump C_Item.GetWeaponEnchantInfo()` or `/dump GetWeaponEnchantInfo()` | buffs | boolean first, or table with `hasMainHandEnchant` |
| `/dump C_Minimap.GetTrackingInfo(1)` | tracking | table with `name`, `texture`, `active`, maybe `spellID` |
| `/dump C_TooltipInfo.GetBagItem(0, 1)` (with a bag item in backpack slot 1) | bag_unequipped | `lines[n].leftText` contains "N Slot Bag" |
| `/dump C_Traits.GetTreeCurrencyInfo(C_ClassTalents.GetActiveConfigID(), C_Traits.GetConfigInfo(C_ClassTalents.GetActiveConfigID()).treeIDs[1], false)` | talents | `[1].quantity` = unspent points |
| `/dump C_QuestLog.GetMaxNumQuestsCanAccept()` | quests | 25 or similar |
| `/dump TalentMicroButton, SpellbookMicroButton, PlayerSpellsMicroButton` | highlights | at least one non-nil |
| `/dump MinimapCluster.Tracking, MinimapCluster.TrackingFrame, MiniMapTrackingButton` | highlights | one non-nil |
| `/dump MinimapCluster.IndicatorFrame.MailFrame, MiniMapMailFrame` | highlights | one non-nil |
| `/dump ToggleTalentFrame, PlayerSpellsUtil` | talents click | one non-nil |
| `/dump ActionButton_ShowOverlayGlow` | highlights | function (else the fallback pulse is used) |
| `/dump #C_Console.GetAllCommands()` | camera | a few hundred |
| `/dump C_CVar.GetCVar("cameraDistanceMaxZoomFactor")` | camera | "1.9" or similar |
| `/dump type(MenuUtil), type(MenuUtil and MenuUtil.CreateContextMenu), type(EasyMenu)` | minimap menu (v4) | `table function …`; if `nil`, the EasyMenu fallback is used |
| `/dump type(AddonCompartmentFrame), type(GetMinimapShape)` | AddOns drop-down, square minimap (v4) | `table`/`nil`, `function`/`nil` |
| `/dump type(PickupBagFromSlot), type(PutItemInBag)` | materials bag move (v4) | `function function` |

### Materials bag (v2, rule `materials_bag`)

Confirmed 2026-11-20: the materials slot is inventory slot 35
(`Enum.BagIndex.ReagentBag`, bag 5) and held an Apprentice's Mining Pack
(item family 1024, container subclass 6). The rule treats any container with
a non-zero item family other than arrows (1) and bullets (2) as a materials
bag. Bag inventory slots are 31–34.

### v2 shapes (confirmed 2026-11-20 on a warrior, enUS)

- `GetProfessionInfo(index)` returns the rank cap as max skill (`Blacksmithing 22 75`).
- `C_QuestLog.GetQuestObjectives(questID)` entries: `type="item"`, `text="0/4 Venomtail Poison Sac"`, `numFulfilled`, `numRequired`, `finished`.
- `UnitQuestTrivialLevelRange("player") = 5`; `C_QuestLog.IsQuestTrivial` exists.
- `GetRealZoneText(36) = "Deadmines"`; `C_GamePad.IsEnabled() = true`.
- `GetBindingText("PADRTRIGGER")` returns a font glyph, so pad names come from the addon's own table.
- Bag inventory slots 31–34, materials slot 35; Icy Veins `nodeId`/rank-1 spell match the client (warrior node 105926 = Improved Intercept, spell 20504, 2 ranks).

### v2 shapes still to confirm

| In chat | Feature | Expected |
|---|---|---|
| `/run local n=0 for p in WorldMapFrame:EnumeratePinsByTemplate("MapExplorationPinTemplate") do n=n+1 print("pin",p.layerIndex,type(p.RefreshOverlays)) end print("pins",n)` (open the map once first) | map reveal | `pins 1`, `RefreshOverlays` a function |
| `/dump #C_MapExplorationInfo.GetExploredMapTextures(C_Map.GetBestMapForUnit("player")), C_Map.GetMapArtLayers(C_Map.GetBestMapForUnit("player"))[1]` | map reveal | a count and a layer with `tileWidth`/`tileHeight` |
| `/run local f=PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame or ClassTalentFrame and ClassTalentFrame.TalentsTab print(f and f:GetName(),f and type(f.GetTalentButtonByNodeID))` (open talents once first) | talent build glow | a frame name and `function` |
| `/dump type(ContainerFrameUtil_EnumerateContainerFrames), type(ContainerFrameCombinedBags)` | quest item glow | `function` and `table` |
| `/dump C_Container.GetContainerItemQuestInfo(0,1), Enum.ItemClass.Questitem, Enum.ItemClass.Projectile, Enum.ItemClass.Reagent, Enum.ItemClass.Key` | bag-full helper | table with `isQuestItem`, and 12, 6, 5, 13 |
| `/dump type(LootFrame), ERR_INV_FULL, type(OpenWorldMap), type(StaticPopup_Show), type(Settings.RegisterVerticalLayoutSubcategory), type(Settings.CreateDropdown), type(C_Traits.GetTreeNodes)` | several | all present |
| `/dump GetCVar("GamePadCursorLeftClick"), GetCVar("GamePadFaceMovementMaxAngle"), GetCVar("SoftTargetInteract"), GetCVar("countdownForCooldowns"), GetCVar("statusTextDisplay")` | controller, game settings | values, not nil |

### Presets to confirm

- [ ] Options → Controller → "Apply the Steam Deck preset" on the Deck: movement, camera and interact feel right; note anything to change in `Controller.PRESETS.deck`.
- [ ] "Apply the controller preset" on an Xbox pad: same, `Controller.PRESETS.pad`.
- [ ] Options → Game settings → "Recommended for new players": chat says how many changed; auto loot, enemy health bars, NPC names and cooldown numbers are on afterwards.

## 1. Panel and commands

- [ ] `/nudge test` shows up to 10 rows plus "…and N more"; icons and text readable; hover a row shows title, help and hints.
- [ ] `/nudge lock` shows the title bar; drag it; `/reload`; position kept. `/nudge lock` again hides it.
- [ ] `/nudge list` prints every rule with on/off/snoozed/not relevant.
- [ ] `/nudge off talents` then `/nudge on talents` print confirmations and change `/nudge list`.
- [ ] Right-click a row: it disappears; `/nudge reset` brings it back. Shift+right-click: gone until the next login (a `/reload` keeps it snoozed; log out and back in to clear it).
- [ ] `/nudge` opens Options → AddOns → NewbieNudge. Lock, scale, snooze length, combat strip, two reset buttons, one checkbox per reminder, Camera section with Max camera distance first.
- [ ] Drag Max camera distance to 2.6, close options, zoom out: the camera goes much farther. "Reset camera to defaults" brings it back.
- [ ] `/console addonCombatRestrictionsForced 1` → panel becomes an icon strip; stale icons are dim; hover shows text. `/console addonCombatRestrictionsForced 0` → list again. Try once in a real fight on a low-level mob too.
- [ ] Options: untick "Show compact strip in combat", repeat: the panel hides in combat.
- [ ] Spanish: set the client to Español (EU) in Battle.net, log in, every row, tooltip and option label is Spanish; no raw KEY_NAMES visible.
- [ ] Options has subcategories under NewbieNudge: Camera, Controller, Game settings, Map, Bags, Talent build; each opens and its controls read the live value.
- [ ] Map: open a partly explored zone: unexplored parts are dimmed grey; `/nudge map` hides them; Options → Map brightness changes them while the map is open.
- [ ] Bags full: with 0 free slots, loot a mob: the "Bags full" window appears next to the loot; grey items first; Destroy on a grey item frees the slot; a green item asks "Sure?". `/nudge trash` opens it with free slots too and only the close button closes it.
- [ ] Talent build: paste an "Open in Calculator" link via Options → Talent build or `/nudge build <link>`; chat confirms the point count; with an unspent point the panel names the next talent and it glows in the talent window.
- [ ] Controller (Deck): after moving the stick, the panel is bigger and row tooltips say "RT: open."; Key Bindings → NewbieNudge lists four actions; bind "Show or hide the reminder panel" to a pad combo and press it.

## 2. Rules: make it appear / make it disappear

| Rule | Appear | Disappear |
|---|---|---|
| bag_unequipped | Buy or loot a bag, leave it in the backpack with a bag slot empty. Or carry a 10-slot while a 6-slot is equipped. | Equip it / replace the smaller bag. |
| bag_full | Fill bags to 2 free slots. | Free a third slot. |
| talents | Level up past 10 without spending. | Spend the point (talent button glow goes off). |
| buffs | Let Arcane Intellect / Mark of the Wild / etc. fall off. The bar button glows. | Cast it. If the spell is not on a bar: row says so and the spellbook button glows. |
| spell_ranks | Train a new rank; the old rank stays on the bar and glows. | Left-click the row: bar updated, row gone. Try with the cursor holding an item: nothing happens. |
| tracking | Know Herbalism/Mining with tracking off. | Click the row or pick it from the minimap magnifier. |
| durability | Die a few times or fight until an item is under 20%. | Repair. |
| ammo | Hunter/ranged: drop below 50 ammo, then 0. | Buy ammo. |
| pet | Hunter 10+: dismiss pet (not in an inn, not mounted); let it get hungry; have unspent training points. | Summon / feed / spend. |
| professions | Level 10 with no profession. | Learn one. |
| hearthstone | Destroy or bank the Hearthstone. | Get one from an innkeeper. |
| quests | Hold 22 quests. | Finish or abandon one. |
| mail | Have someone mail you. | Open the mailbox. |
| rested | Open the game menu (Escape) in the open world below max level: row and one chat line. Open it again: no second chat line. | Close the menu, or walk into an inn. |
| gear_upgrade | `/nudge on gear_upgrade`; carry a cloth chest 5+ ilvl above yours (mage). | Equip it. Plate in a mage's bags must not show. |
| materials_bag | (after the constants are set) carry a materials bag with the materials slot empty. | Equip it. |
| quest_item | Loot an item that starts a quest. The backpack glows; open the bags: the item glows. | Right-click it and accept the quest. |
| quest_turnin | Complete a quest's objectives. | Hand it in. |
| quest_soon | Hold a quest whose level is 2 below "grey". | Level past it (becomes quest_grey) or finish it. |
| quest_grey | Hold a quest far below your level. | Abandon or finish it. |
| quest_slots | Have more item objectives than free slots. | Free slots or finish the objectives. |
| trainer_spells | Level up with a new rank available. | Train it (or do the class quest). |
| profession_rank | Reach 50/75 in a primary at level 10+. | Learn Journeyman. |
| dungeon_ready | Be in a dungeon's level range for your faction. | Enter it once, or complete half its quests. |
| zone_level | Walk into a zone 3+ levels below or above you. | Leave it or snooze. |
| talent_build | Set a build and have an unspent point. | Pick the named talent. |
| supplies | Level 5+, no food or drink in the bags; with First Aid, no bandages. | Buy food; make a bandage. |
| quest_group | Hold an elite or dungeon quest. | Finish or abandon it. |
| profession_rank (secondary) | First Aid 50/75 at level 10 (trainer); 125/150 (book); 225/225 at 35 (quest). | Learn the rank. |
| hearth_bind | Talk to an innkeeper in a zone other than your bind point. | Close the talk window (row); the chat line comes once per inn per session. Also: talk to the innkeeper where you are bound → no row, no line (bind there once first so the spot is recorded); turn the rule off → no chat line. |
| demon | Warlock with a summon spell known and no demon out (not resting, mounted or dead). The summon button glows. | Summon it. |
| mount | Level 30–39 with under 100 gold; level 40 without Riding (skill ID 762). | Reach 100 gold; learn to ride. |
| weapon_skill | Equip a weapon type whose skill is 20+ below its cap (skills under C_SkillInfo, category 6). | Train it on weak enemies. |
| legacy | Reach level 25 (one nudge until you press Y); have unviewed Legacy challenges. | Open the Legacy window; view the challenges. |
| flight_path | Stand in a zone whose flight master you have not visited (`/dump C_TaxiMap.GetTaxiNodesForMap(C_Map.GetBestMapForUnit("player"))` shows nodes with `state`). | Talk to the flight master. |
| vendor (not a rule) | Open a merchant with grey items and damaged gear. | Chat says what was sold and what the repair cost; "Repairing would cost X" when too poor. |
| tooltips (not a rule) | Hover an item away from a vendor. | "Sell price: X each" line; none at a vendor or for 0-value items. |

## 3. Edge cases

- [ ] Log in: no "no Hearthstone" or bag rows flash before bags load.
- [ ] A rule error (temporarily add `error("x")` to a check): one chat line, panel still works, `NewbieNudgeDB.errors` holds the message.
- [ ] Reload with the Spanish client and English client both show the same number of rows for the same character.

## v4 (0.4.0)

- **Minimap button:** it sits on the minimap edge; drag it all the way round (also with a square-minimap addon if you use one); `/reload` keeps its place. Hover: reminder count and hints. Click: every menu entry does what it says (ticks update after clicking "Show info bar" or a panel style); "Snooze everything" only appears with rows on the panel, "Wake all reminders" only while something is snoozed. `/nudge minimap` hides and shows it; the AddOns drop-down entry opens the same menu while it is hidden.
- **Icons only:** switch in the menu, the options or `/nudge style`. Out of combat the panel is a row of icons, a second line after 8; hovering shows the text above the icon; clicks and right-click snooze work. Enter and leave combat: icons don't all flash again. With "compact strip in combat" off, the panel hides in combat in both styles.
- **Info bar:** right numbers for bags (only normal bags count; a quiver doesn't), gold after buying or selling, gear % after a death and after repairing. Colours: bags orange under 6 free, red under 3; gear red when one item is under 20%. Clicks open bags / character. Hidden in combat, back afterwards. With no reminders the panel shows only the bar. Each checkbox under Options → Info bar hides its part.
- **Materials bag:** put a profession bag in bag slot 2 with the materials slot empty → the row names the bag; click → it moves to the materials slot (try with items inside it, and in combat: it refuses with a chat line). On a warlock, a Soul Pouch in a bag slot must not trigger this row. The click must not print "Couldn't move it" when the bag did move.
- **Weapon skills to learn:** at level 10+, the row names the city and weapon master for each weapon your class hasn't learned (your faction only); learn one and it drops off; polearms only from 20.
- **Gathering tracking:** an herbalist or miner with tracking off sees the row; clicking it turns tracking on.
- **Options:** the AddOns list shows NewbieNudge, Reminders, Bags and vendors, Map and minimap, Combat and action bars, Names and health bars, Quests and interface, Camera, (Controller), Talent build, Developer. Every page opens; no setting appears on two pages; "Apply recommended game settings" on the main page still works; the world-map icon opens Map and minimap.
