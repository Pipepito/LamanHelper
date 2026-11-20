# NewbieNudge v3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the ten "easy wins" of the v3 spec: supplies, group quests, secondary profession ranks, innkeeper bind, vendor auto-sell/repair, tooltip prices, one-bag toggle, mount milestone, weapon skill and Legacy (the last two once their API probes are in).

**Architecture:** Each reminder is a rule file under `Rules/` on the v1 interface; vendor automation and tooltips are two small modules with their own events. All strings in both locale files; offline tests per task against `tests/wow_stub.lua`.

**Tech Stack:** Lua 5.1 (WoW Forever client), Python harness (`python tests/run.py`).

**Spec:** `docs/superpowers/specs/2026-11-20-newbienudge-v3-design.md` (+ v1/v2 specs).

## Global Constraints

Same as the v2 plan: Lua 5.1; every string in `enUS.lua` and `esES.lua`; `NN.Plain` on API values; rules never create frames; new state keys get `DEFAULT_STATE` defaults; suite green and one commit per task.

## Review Focus

1. Vendor auto-sell must never sell a quality-0 item that is locked or that the merchant window has already consumed (stale slot): re-read the slot before each `UseContainerItem` (Task 5 test `stale_slot_is_skipped`).
2. Vendor auto-sell must stop when the merchant window closes mid-run (Task 5 `stops_when_merchant_closes`).
3. Repair with insufficient money must not call `RepairAllItems` (Task 5 `cannot_afford_repair_says_so`).
4. Innkeeper rule must not fire for a vendor's or quest giver's gossip (Task 4 `non_innkeeper_gossip_ignored`).
5. Secondary-profession ranks must not call for a trainer at Expert/Artisan (Task 3 `expert_says_book_artisan_says_quest`).

---

### Task 1: `supplies` rule

**Files:** Create `NewbieNudge/Rules/Supplies.lua`, `tests/test_rules_supplies.lua`; modify TOC, locales, stub (`GetProfessionInfo` already; add `Enum.ItemConsumableSubclass = { FoodDrink = 5, Bandage = 7 }`).

**Interfaces:** `NN.KnowsFirstAid() -> bool` (a secondary profession whose `GetProfessionInfo` skillLine is 129 or whose name equals the client's First Aid name; stub: `professionInfo[idx].skillLine`).

- [ ] Tests: `no_food_row_from_level_5` (level 5, empty bags → `SUPPLIES_ROW_FOOD`, highlight bags, click ToggleAllBags); `food_present_no_row` (a Consumable/5 stack); `bandage_row_only_with_first_aid` (professions `{prof1=1}` + `professionInfo[6]={name="First Aid", skillLine=129}` → `SUPPLIES_ROW_BANDAGE`; without First Aid → none); `below_level_5_not_applicable`.
- [ ] RED → implement → GREEN. Strings: `SUPPLIES_TITLE = "Food and bandages"`, `SUPPLIES_HELP`, `SUPPLIES_ROW_FOOD = "You have no food or drink in your bags."`, `SUPPLIES_ROW_BANDAGE = "You have no bandages. First Aid makes them from cloth."`. Priority: after `hearthstone`.
- [ ] Commit `feat: supplies reminder (food, drink, bandages)`.

### Task 2: `quest_group` rule

**Files:** Modify `Rules/QuestPlan.lua`, `tests/test_rules_questplan.lua`, stub (`C_QuestLog.GetQuestTagInfo(id)` → entry `.tag` as `{ tagID = n, tagName = "Group" }`; `Enum.QuestTag = { Group = 1, Raid = 62, Dungeon = 81 }`), locales.

- [ ] Tests: `group_counts_tagged_quests` (tags 1, 81 counted; untagged not; text `QUEST_GROUP_ROW:format(2)`); `complete_group_quest_not_counted`; priority after `quest_grey`.
- [ ] RED → implement (scan adds `needsGroup`) → GREEN → commit `feat: quest_group — quests that need a group`.

### Task 3: secondary profession ranks

**Files:** Modify `Rules/ProfessionRank.lua`, `tests/test_rules_professionrank.lua`, locales.

**Interfaces:** `NN.ProfessionRankStep(skill, maxSkill, level, isSecondary) -> "trainer"|"book"|"quest"|nil`; secondaries from positions 3–6 of `GetProfessions()`.

- [ ] Tests: `secondary_journeyman_from_trainer` (cap 75, skill 50, level 10 → `PROFESSION_RANK_ROW`); `expert_says_book_artisan_says_quest` (cap 150 skill 125 → `PROFESSION_RANK_ROW_BOOK`; cap 225 skill 225 level 35 → `PROFESSION_RANK_ROW_QUEST`; level 34 → none); `applies_with_only_a_secondary`; `row_cap_three`.
- [ ] RED → implement → GREEN → commit `feat: profession_rank covers cooking, first aid and fishing`.

### Task 4: `hearth_bind` rule

**Files:** Create `Rules/HearthBind.lua`, `tests/test_rules_hearthbind.lua`; stub: `C_GossipInfo = { GetOptions = function() return S().gossipOptions end }`, `GetBindLocation()` → `S().bindLocation`, `GetSubZoneText()`/`GetZoneText()` → state; events `GOSSIP_SHOW`/`GOSSIP_CLOSED`; locales.

- [ ] Tests: `innkeeper_elsewhere_shows_row_and_says_once` (options include icon 132052; bind "Goldshire", zone "Westfall" → row `HEARTH_BIND_ROW:format("Goldshire")`, one Say; second GOSSIP_SHOW same session → no second Say); `same_inn_no_row` (bind equals subzone); `non_innkeeper_gossip_ignored` (no 132052 option); `row_clears_on_gossip_closed`.
- [ ] RED → implement (combat false; `applies` true; state kept in a module-local `current` set on GOSSIP_SHOW via `NN:OnAnyEvent`, cleared on GOSSIP_CLOSED; `check` reads it) → GREEN → commit `feat: hearth_bind — offer to set the Hearthstone at a far innkeeper`.

### Task 5: vendor automation

**Files:** Create `NewbieNudge/Vendor.lua`, `tests/test_vendor.lua`; stub: `MERCHANT_SHOW/CLOSED` events, `MerchantFrame` (shown flag), `C_Container.UseContainerItem(bag, slot)` (at merchant: removes stack, adds price×count to `S().money`, records), `CanMerchantRepair()`, `GetRepairAllCost()` (→ `S().repairCost`, `canRepair`), `RepairAllItems()` (records; deducts), `GetMoney()`; Core defaults `vendor = { sellJunk = true, repair = true }`; Options Bags page checkboxes; locales.

**Interfaces:** `NN.Vendor:OnMerchantShow()`, `:SellJunk()` (returns count, copper; ticks of 10 per 0.3 s via `C_Timer.NewTicker`), `:Repair()`, `:OnMerchantClosed()`.

- [ ] Tests: `sells_grey_stacks_and_says_total` (2 greys + 1 white → two UseContainerItem calls, Say `VENDOR_SOLD:format(2, "<money>")`); `stale_slot_is_skipped` (stack vanishes before the tick → not sold, no error); `stops_when_merchant_closes` (25 greys, MERCHANT_CLOSED after first tick → ≤10 sold); `repairs_when_affordable` (cost 500, money 1000 → RepairAllItems, Say); `cannot_afford_repair_says_so` (cost 5000 → no RepairAllItems, Say `VENDOR_REPAIR_POOR`); `options_toggle_both_off` (nothing happens); `locked_stack_not_sold`.
- [ ] RED → implement → GREEN → commit `feat: auto-sell grey items and auto-repair at vendors`.

### Task 6: tooltip sell price and one-bag toggle

**Files:** Create `NewbieNudge/Tooltips.lua`, `tests/test_tooltips.lua`; modify `GameSettings.lua` (+`combinedBags` row, `GS_combinedBags` strings), Core defaults `tooltipPrice = true`, Options Bags page checkbox; stub: `TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) S().tooltipCalls[#+1] = fn end }`, `Enum.TooltipDataType = { Item = 0 }`, `GameTooltip:GetItem()` → `S().tooltipItem` link, `MerchantFrame`.

- [ ] Tests: `adds_sell_price_line_outside_vendor` (item sellPrice 150 → AddDoubleLine with `SELL_PRICE`-ish label and "150c"); `no_line_at_vendor` (MerchantFrame shown); `no_line_for_zero_price`; `option_off_no_line`; `game_settings_has_combined_bags` (`NN_cvar_combinedBags` checkbox, not in PRESET).
- [ ] RED → implement → GREEN → commit `feat: sell price in tooltips; one-bag view toggle`.

### Task 7: `mount` rule (money row now, riding row guarded)

**Files:** Create `Rules/Mount.lua`, `tests/test_rules_mount.lua`; stub `GetMoney()` → `S().money`, `PLAYER_MONEY` event; `NN.HasRidingSkill()` returns nil when no skill API (rule then shows only the money row); locales.

- [ ] Tests: `save_up_row_between_30_and_39_when_poor` (level 32, 20g → `MOUNT_ROW_SAVE:format("<money>")`; 120g → none); `not_applicable_below_30`; `riding_row_at_40_without_skill_when_api_present` (fake `NN.HasRidingSkill = function() return false end` → `MOUNT_ROW_RIDE`; `true` → none; `nil` → none).
- [ ] RED → implement → GREEN → commit `feat: mount milestone reminders`.

### Task 8: `weapon_skill` (after the skill-API probe)

- [ ] Wire `NN.SkillLines()` to whichever API the probe shows (`C_SkillInfo.GetNumSkillLines/GetSkillLineInfo` or none). If the client lists no weapon skill lines, the rule is omitted and the spec entry is marked "not on Forever".
- [ ] Tests per spec 25.2 with the stub's `skillLines` state; commit.

### Task 9: `legacy` (after the Legacy probe)

- [ ] Wire to the functions the probe shows; unlock nudge keyed on level 25 with `ToggleLegacySystemUI` as the click; unspent points only if an API exposes them.
- [ ] Tests; commit.

### Task 10: docs and version 0.3.0

- [ ] README (new reminders, vendor and tooltip options), checklist §2 rows, TOC `## Version: 0.3.0`, full suite, commit.
