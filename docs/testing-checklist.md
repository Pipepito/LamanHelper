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

## 3. Edge cases

- [ ] Log in: no "no Hearthstone" or bag rows flash before bags load.
- [ ] A rule error (temporarily add `error("x")` to a check): one chat line, panel still works, `NewbieNudgeDB.errors` holds the message.
- [ ] Reload with the Spanish client and English client both show the same number of rows for the same character.
