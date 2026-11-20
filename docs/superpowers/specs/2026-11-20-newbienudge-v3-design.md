# NewbieNudge v3 — design spec (easy wins from the guides)

Date: 2026-11-20. Extends the v1 and v2 specs; conventions (rule interface,
`NN.Plain`, locales, options pages, tests) are unchanged. Sources: Icy Veins
WoW Forever guides (leveling tips, First Aid, professions, camping, Legacy),
Blizzard's "What's new" article (Experience Presets), and the feature lists of
Leatrix Plus, Scrap and Questie. User decision: all ten items (2026-11-20).

## 25. New rules

### 25.1 `supplies` — no food, drink or bandages
- Applies: level ≥ 5.
- Condition, outside combat: count stacks in bags 0–4 by item class
  `Consumable` (0): subclass Food & Drink (5) and subclass Bandage (7).
  Row "You have no food or drink in your bags." when the food/drink count is
  0. Row "You have no bandages." when the bandage count is 0 **and** the
  character knows First Aid (a secondary profession whose `GetProfessionInfo`
  name equals the First Aid skill-line name, see 25.4). Icon 133950.
- Click: `ToggleAllBags()`. Highlight: `bags`. Events: `BAG_UPDATE_DELAYED`,
  `SKILL_LINES_CHANGED`. Not combat.

### 25.2 `weapon_skill` — skill with your equipped weapon far behind
- Applies: the skill API lists weapon skills (checklist probe; the rule is
  silent when it does not).
- Condition: for the main-hand item (`INVSLOT_MAINHAND`, 16) and the ranged
  item (18), map the item subclass to the weapon skill line name via the
  client's own item subclass names (`C_Item.GetItemSubClassInfo(2, sub)`),
  find that skill line's `rank, maxRank`. Row when `rank < maxRank - 20`.
- Text: "Your %s skill is %d/%d. Fight weaker enemies to train it." Icon
  135324. Click: `ToggleCharacter("SkillFrame")` when present.
- Events: `SKILL_LINES_CHANGED`, `PLAYER_EQUIPMENT_CHANGED`, `CHAT_MSG_SKILL`.
  Not combat.

### 25.3 `quest_group` — quests that need a group
- Uses `NN.QuestScan` plus `C_QuestLog.GetQuestTagInfo(questID)`; a quest
  counts when `tagID` is Group (1), Dungeon (81), Raid (62) or Elite (the
  client's `Enum.QuestTag` values when present, else those numbers), or
  `info.isElite`/`suggestedGroup > 1` when exposed.
- Text: "%d quest(s) in your log need a group." Icon 136221. Click:
  `ToggleQuestLog()`. Highlight: none. Events as the quest rules. Priority:
  after `quest_grey`.

### 25.4 `profession_rank` covers secondary professions
- Positions 3–6 of `GetProfessions()` are secondaries. Per the First Aid
  guide (and the same pattern for Cooking and Fishing): Journeyman from a
  trainer at skill 50 (level 10), Expert from a **book** at skill 125 (level
  20), Artisan from a **quest** at skill 225 and level 35.
- Rows: cap 75 → "You can learn Journeyman %s (%d/%d). Visit a %s trainer.";
  cap 150 → "Read the Expert %s book to go past %d (vendors sell it)."; cap
  225 → "Complete the Artisan %s quest (level 35) to go past %d." Primaries
  keep the existing text. Row cap rises from 2 to 3.

### 25.5 `legacy` — the Legacy system
- Applies: the Legacy API exists (checklist probe lists globals containing
  "Legacy"; the builder wires the real names, guarded).
- Rows: once at the unlock (level 25, or 150 skill in a crafting primary, or
  the full map): "The Legacy system is open. Press Y to spend your first
  point." (`db.seen.legacy = true` afterwards). While the API reports unspent
  Legacy points: "You have %d unspent Legacy point(s)." Icon 134419.
- Click: the Legacy window toggle when the API has one, else nothing.

### 25.6 `mount` — riding at 40
- Applies: level ≥ 30.
- Rows: levels 30–39 with money below 100 gold (1,000,000 copper): "Save up:
  riding and a mount cost about 100 gold at level 40 (you have %s)." Level
  ≥ 40 with no Riding skill line (skill API; silent when absent): "You can
  learn to ride now. Visit a riding trainer." Icon 132261.
- Events: `PLAYER_MONEY`, `PLAYER_LEVEL_UP`, `SKILL_LINES_CHANGED`. The money
  row re-checks at most once a minute (the 30 s ticker already does).

### 25.7 `hearth_bind` — set your Hearthstone here
- On `GOSSIP_SHOW`, when `C_GossipInfo.GetOptions()` contains the innkeeper's
  bind option (the option whose `icon` is the Hearthstone icon 132052, or
  whose name matches the client's bind string; probe), and
  `GetBindLocation()` differs from `GetSubZoneText()` and `GetZoneText()`:
  row "Your Hearthstone is set to %s. This innkeeper can set it here."
  (icon 134414) plus one `NN:Say` per innkeeper per session. The row clears
  on `GOSSIP_CLOSED`. Click: nothing (the gossip window is open).

## 26. Vendor automation (`Vendor.lua`)

- On `MERCHANT_SHOW`, when `db.vendor.sellJunk` (default on): every stack in
  bags 0–4 with quality 0, not locked, sold with
  `C_Container.UseContainerItem(bag, slot)`, at most 10 per 0.3 s tick until
  done or `MERCHANT_CLOSED`. Afterwards one line: "Sold %d junk items for
  %s." The bag-full exclusions are **not** applied: grey is grey.
- Then, when `db.vendor.repair` (default on) and `CanMerchantRepair()`:
  `cost = GetRepairAllCost()`; if `cost > 0` and `cost <= GetMoney()`,
  `RepairAllItems()` and "Repaired your gear for %s."; if the player cannot
  afford it, "Repairing would cost %s; you have %s." once per visit.
- Options page "Bags" gains both checkboxes. Nothing happens in combat.

## 27. Vendor price in tooltips (`Tooltips.lua`)

- `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn)`
  when available (else `GameTooltip:HookScript("OnTooltipSetItem")`): when no
  merchant window is shown and the item's sell price is above 0, add
  "Sell price: %s each" (`SELL_PRICE` global when present) in grey. Option
  `db.tooltipPrice` (default on) on the Bags page.

## 28. Game settings additions

- `combinedBags` checkbox "One-bag view (all bags in one window)" in the
  Quests, map and screen group; the preset leaves it alone (Forever's
  Classic preset turns it off on purpose).

## 29. Saved variables

`vendor = { sellJunk = true, repair = true }`, `tooltipPrice = true`,
`seen.legacy = false`, `seen.innkeepers = {}` (session-only, not saved).

## 30. Checklist probes (needed before 25.2, 25.5, 25.6, 25.7)

```
/run for i=1,GetNumSkillLines() do local n,h,_,r,_,_,m=GetSkillLineInfo(i) print(i,h and "#" or "",n,r,m) end
```
```
/run for k in pairs(_G) do if type(k)=="string" and k:find("Legacy") then print(k) end end
```
```
/dump GetBindLocation(), GetSubZoneText(), GetZoneText()
```
With an innkeeper's gossip open: `/dump C_GossipInfo.GetOptions()`.

## 31. Tests

One test file per rule as in v2; `Vendor` tests drive `MERCHANT_SHOW` with a
stub merchant (`CanMerchantRepair`, `GetRepairAllCost`, `RepairAllItems`,
`UseContainerItem` removing the stack and recording), including "stops when
the merchant closes" and "cannot afford repair". Tooltip test records
`AddDoubleLine`. Weapon-skill, Legacy, mount and innkeeper rules carry an
"API absent → silent" test each.
