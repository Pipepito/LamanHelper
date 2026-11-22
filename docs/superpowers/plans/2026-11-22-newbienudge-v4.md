# NewbieNudge v4 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a minimap button with a menu, an icons-only panel style, an info bar on top of the panel, a "materials bag in a normal slot" reminder, and reorganise the options window into smaller, grouped pages.

**Architecture:** Two new modules (`InfoBar.lua`, `Minimap.lua`) hang off the shared `NN` table like every other module; `Panel.lua` gains a layout pass that stacks title → info bar → list/strip. Options pages get an explicit order and the game-settings list gets a `page` key so each page shows its own slice. The materials-bag case is a new row of the existing `materials_bag` rule.

**Tech Stack:** Lua 5.1 (WoW Forever client, interface 16001); offline tests with LuaJIT via lupa (`python tests/run.py`) against `tests/wow_stub.lua`.

**Spec:** `docs/superpowers/specs/2026-11-22-newbienudge-v4-design.md`

## Global Constraints

- No external libraries; no `Libs/` folder.
- Every existing `NewbieNudgeDB` key keeps its meaning; new keys only through `NN.defaults` (applied by `NN.ApplyDefaults`).
- Existing settings variable names (`NN_lock`, `NN_scale`, `NN_snooze`, `NN_combatStrip`, `NN_rule_<name>`, `NN_cvar_<cvar>`, `NN_bagfull_*`, `NN_vendor_*`, `NN_tooltipPrice`, `NN_map_*`, `NN_build_badges`, `NN_dev_enabled`, `NN_controller_*`) do not change.
- Every value read from the game goes through `NN.Plain(value, "number"|"string")`; secret/nil shows as `?` in the info bar.
- Every new player-facing string goes into `Locales/enUS.lua` **and** `Locales/esES.lua` in the same section (the `locales::parity` test enforces it). Spanish is written by the implementer.
- New `.lua` files are added to `NewbieNudge/NewbieNudge.toc` (tests load files from the TOC).
- Work locally on branch `v4`. **Never push, never tag.** The owner tests in game first (`tools/deploy.ps1` links the folder; `/reload`).
- Full suite stays green after every task: `python tests/run.py` → `N passed, 0 failed`.

## Review Focus

1. **Info bar while the panel is hidden or empty** — key-binding/menu "Hide panel" hides the bar too; zero reminders with the bar on shows a bar-only panel, never an empty dark box. Tests in Task 3.
2. **Combat transitions in icons style** — entering combat with style "icons" and `combatStrip = false` hides the panel; leaving combat in icons style must not re-pulse every icon. Tests in Task 2.
3. **Existing saved variables from 0.3.x** — a DB without `panel.style`, `infobar`, `minimap` keys loads with defaults and nothing else changes. Test in Task 2 (style) and Task 4 (minimap).
4. **Moving a materials bag fails** — cursor still holding the bag after `PutItemInBag` must be cleared (`ClearCursor`), or the player ends up with a bag stuck on the cursor. Test in Task 1.
5. **Options built twice / page error** — a page whose builder errors still lets the remaining pages build (existing `pcall`), and the new explicit page order keeps unknown keys at the end. Test in Task 6.

---

### Task 1: Materials bag in a normal bag slot

**Files:**
- Modify: `NewbieNudge/Rules/MaterialsBag.lua`
- Modify: `NewbieNudge/Locales/enUS.lua`, `NewbieNudge/Locales/esES.lua` (materials bag section)
- Modify: `tests/wow_stub.lua` (bag move API)
- Test: `tests/test_rules_materialsbag.lua`

**Interfaces:**
- Consumes: `NN.IsReagentBag(itemID) -> bool`, `NN.BagInventorySlot(bag) -> invSlot` (existing).
- Produces: `NN.MoveBagToMaterialsSlot(fromInvSlot) -> bool` (true when the bag landed in the materials slot).

- [ ] **Step 1: Stub additions** in `tests/wow_stub.lua`, near `ClearCursor`: `PickupBagFromSlot(invSlot)` sets `S().cursor = { type = "item", itemID = S().inventory[invSlot].itemID, fromInv = invSlot }` and records `"PickupBagFromSlot", invSlot`; `PutItemInBag(invSlot)` records `"PutItemInBag", invSlot`, and unless `S().refuseBagMove` moves the inventory entry from `cursor.fromInv` to `invSlot` (only when `invSlot` is empty) and clears the cursor. Use inventory slots 31–34 for bags 1–4 and 35 for `Enum.BagIndex.ReagentBag` (5) as the existing stub numbering gives (`bagSlotBase` 30 + bag); set `Enum.BagIndex.ReagentBag = 5` in the stub if absent.

- [ ] **Step 2: Write failing tests** in `tests/test_rules_materialsbag.lua` (reuse `setup()`):

```lua
profession_bag_in_regular_slot_with_empty_materials_slot = function()
  setup(); WOW.state.bagSlotBase = 30; WOW.state.inventory[32] = { itemID = MINING12 }
  load_addon(); load_bags(); run_checks()
  local r = results_of("materials_bag")
  assert_eq(#r, 1)
  assert_eq(r[1].text, L().MATERIALS_BAG_ROW_SLOT:format("Small Mining Pack"))
  assert_eq(r[1].highlight, "bags")
end,
no_slot_row_when_materials_slot_taken = function()
  setup(); WOW.state.bagSlotBase = 30
  WOW.state.inventory[32] = { itemID = MINING12 }; WOW.state.inventory[35] = { itemID = HERB }
  load_addon(); load_bags(); run_checks()
  for _, r in ipairs(results_of("materials_bag")) do assert_true(r.text ~= L().MATERIALS_BAG_ROW_SLOT:format("Small Mining Pack")) end
end,
no_slot_row_for_plain_bag_or_quiver = function()
  setup(); WOW.state.bagSlotBase = 30
  WOW.state.inventory[31] = { itemID = PLAIN }; WOW.state.inventory[32] = { itemID = QUIVER }
  load_addon(); load_bags(); run_checks()
  assert_eq(#results_of("materials_bag"), 0)
end,
click_moves_bag_to_materials_slot = function()
  setup(); WOW.state.bagSlotBase = 30; WOW.state.inventory[32] = { itemID = MINING12 }
  load_addon(); load_bags(); run_checks()
  results_of("materials_bag")[1].onClick()
  assert_eq(WOW.state.inventory[35].itemID, MINING12); assert_nil(WOW.state.inventory[32])
end,
failed_move_clears_cursor_and_opens_bags = function()
  setup(); WOW.state.bagSlotBase = 30; WOW.state.refuseBagMove = true; WOW.state.inventory[32] = { itemID = MINING12 }
  load_addon(); load_bags(); run_checks()
  results_of("materials_bag")[1].onClick()
  assert_nil(WOW.state.cursor)
  local names = {}; for _, c in ipairs(WOW.calls) do names[#names + 1] = c[1] end
  assert_true(tContains(names, "ClearCursor")); assert_true(tContains(names, "ToggleAllBags"))
  assert_true(WOW.printed[#WOW.printed]:find(L().MATERIALS_BAG_MOVE_FAILED, 1, true))
end,
click_refuses_in_combat = function()
  setup(); WOW.state.bagSlotBase = 30; WOW.state.inventory[32] = { itemID = MINING12 }
  load_addon(); load_bags(); run_checks()
  WOW.state.inCombat = true
  results_of("materials_bag")[1].onClick()
  assert_eq(WOW.state.inventory[32].itemID, MINING12)
  assert_true(WOW.printed[#WOW.printed]:find(L().MATERIALS_BAG_IN_COMBAT, 1, true))
end,
```

(Adjust the stub's `bagSlotBase` default if the existing tests rely on 19; the tests above set it explicitly.)

- [ ] **Step 3: Run** `python tests/run.py materialsbag` → the new tests FAIL (`MATERIALS_BAG_ROW_SLOT` nil / no row).

- [ ] **Step 4: Implement.** Locale keys (enUS):
  - `MATERIALS_BAG_ROW_SLOT = "Your %s is in a normal bag slot. Click to move it to the materials slot and free that slot for a normal bag."`
  - `MATERIALS_BAG_GENERIC = "materials bag"`
  - `MATERIALS_BAG_MOVE_FAILED = "Couldn't move it for you: drag the bag from its slot onto the materials slot next to your bags."`
  - `MATERIALS_BAG_IN_COMBAT = "Bags can't be moved in combat."`

  In `check()`, before the inventory scan: when the materials slot is empty, loop bags 1–4, `id = GetInventoryItemID("player", NN.BagInventorySlot(bag))`; first one with `NN.IsReagentBag(id)` returns `{ text = L.MATERIALS_BAG_ROW_SLOT:format(name or L.MATERIALS_BAG_GENERIC), icon = BAG_ICON, highlight = "bags", onClick = function() NN.MoveBagToMaterialsSlot(fromSlot) end }` (name from `C_Item.GetItemInfo(id)` through `NN.Plain(..., "string")`). `NN.MoveBagToMaterialsSlot(fromSlot)`: in combat → `NN:Say(L.MATERIALS_BAG_IN_COMBAT)`, return false; else `PickupBagFromSlot(fromSlot)`, `PutItemInBag(materialsSlot)`; if `CursorHasItem()` afterwards → `ClearCursor()`, `ToggleAllBags()`, `NN:Say(L.MATERIALS_BAG_MOVE_FAILED)`, return false; return true. Guard each API with `if not PickupBagFromSlot then … fallback path`.

- [ ] **Step 5: Run** `python tests/run.py` → all pass.

- [ ] **Step 6: Commit (local only)**

```bash
git add NewbieNudge/Rules/MaterialsBag.lua NewbieNudge/Locales/*.lua tests/wow_stub.lua tests/test_rules_materialsbag.lua
git commit -m "feat: materials_bag offers to move a profession bag out of a normal bag slot"
```

---

### Task 2: Icons-only panel style

**Files:**
- Modify: `NewbieNudge/Core.lua` (`NN.defaults.panel.style = "list"`)
- Modify: `NewbieNudge/Panel.lua`
- Modify: `NewbieNudge/Options.lua` (dropdown in General)
- Modify: locales
- Test: `tests/test_panel.lua`, `tests/test_options.lua`

**Interfaces:**
- Produces: `NN.Panel:UsesStrip() -> bool` (combat or style "icons"); `NN.Panel:SetStyle(style: "list"|"icons")` (saves, refreshes); `Panel.STRIP_PER_LINE = 8`; strip tooltips anchor `"ANCHOR_TOP"`, list rows `"ANCHOR_LEFT"`.

- [ ] **Step 1: Failing tests** in `tests/test_panel.lua`:
  - `default_style_is_list`: after `load_addon()`, `NewbieNudge.db.panel.style == "list"`.
  - `icons_style_uses_strip_out_of_combat`: `SetStyle("icons")`, show 3 results → `visibleStripIcons() == 3`, `#row_texts() == 0`.
  - `strip_wraps_after_eight`: icons style, 10 results → icon 9's point is `TOPLEFT` with y = `-(STRIP_ICON + 4)` relative to the strip and frame height = `2 * 24 + 4 + 12` (two lines, gap 4, PAD 6×2).
  - `strip_tooltip_above_icon`: icons style, `WOW.Hover(Panel.stripIcons[1])` → `GameTooltip.anchor == "ANCHOR_TOP"` and `GameTooltip.lines[2] == "one"`; list style row hover → `"ANCHOR_LEFT"`.
  - `icons_style_combat_strip_off_hides_in_combat`: icons style, `db.combatStrip = false`, fire `PLAYER_REGEN_DISABLED` → panel hidden; `PLAYER_REGEN_ENABLED` → shown again.
  - `leaving_combat_in_icons_style_does_not_repulse`: icons style, 2 rows; enter and leave combat; `stripIcons[1].pulseTicker == nil`.
  In `tests/test_options.lua`: `style_dropdown_round_trips`: `WOW.settings["NN_panel_style"].setter("icons")` → `db.panel.style == "icons"`.

- [ ] **Step 2: Run** `python tests/run.py panel` → FAIL.

- [ ] **Step 3: Implement.** `Panel:Refresh` uses the strip when `self:UsesStrip()`; the `combatStrip == false` hide applies only when `self.combat`. `RefreshStrip` positions icon `i` at column `(i-1) % 8`, line `floor((i-1)/8)`, `TOPLEFT` offsets `(col * (size+4), -line * (size+4))`; strip/frame width uses `min(#rows, 8)` columns, height uses line count. `showTooltip(owner, data, anchor)` gets an anchor argument; strip buttons pass `"ANCHOR_TOP"`. `SetCombatMode(false)` resets `stripSeen` only when style is `"list"`. Options General: `Options.AddDropdown(category, "NN_panel_style", L.OPT_STYLE, L.OPT_STYLE_TT, { {value="list", label=L.OPT_STYLE_LIST}, {value="icons", label=L.OPT_STYLE_ICONS} }, getter, function(v) NN.Panel:SetStyle(v) end)` right after `NN_lock`.
  Locale (enUS): `OPT_STYLE = "Panel style"`, `OPT_STYLE_TT = "Icons only keeps the panel small. Point at an icon to read the reminder."`, `OPT_STYLE_LIST = "Full list"`, `OPT_STYLE_ICONS = "Icons only"`.

- [ ] **Step 4: Run** `python tests/run.py` → all pass (update `general_controls_are_registered` only if dropdown order broke it — it checks checkboxes/sliders, so it should not).

- [ ] **Step 5: Commit (local only)** `feat: icons-only panel style with wrapping strip and tooltips above icons`

---

### Task 3: Info bar

**Files:**
- Create: `NewbieNudge/InfoBar.lua` (TOC: after `Panel.lua`)
- Modify: `NewbieNudge/Core.lua` (defaults `infobar = { enabled = true, bags = true, gold = true, gear = true }`)
- Modify: `NewbieNudge/Panel.lua` (layout: title → bar → content; bar-only panel)
- Modify: `NewbieNudge/Options.lua` (Info bar header + 4 checkboxes on the main page)
- Modify: locales
- Test: create `tests/test_infobar.lua`

**Interfaces:**
- Consumes: `NN.Panel.frame`, `NN.MoneyText`, `NN.Panel:UsesStrip()`.
- Produces: `NN.InfoBar` with `HEIGHT = 18`; `InfoBar.BagCounts() -> used, total, free` (numbers) or `nil`; `InfoBar.GearStatus() -> { percent = number|nil, lowestName = string|nil, lowestPercent = number|nil, anyLow = bool }` or `nil` when unreadable; `InfoBar:IsActive() -> bool` (`db.infobar.enabled`, ≥1 segment on, not `Panel.combat`, panel not hidden); `InfoBar:Refresh()` (updates texts, returns its width); `InfoBar.frame`.
- Panel uses: `InfoBar:IsActive()`, `InfoBar:Refresh()`; `Panel:Refresh` shows the frame when rows > 0 **or** `InfoBar:IsActive()`.

- [ ] **Step 1: Failing tests** in `tests/test_infobar.lua` (bags: regular bags 0–4 family 0; inventory items with `durability = {cur, max}`):
  - `bag_counts_regular_bags_only`: bag 0 16 slots 4 used, bag 1 a quiver (family 1) 6 slots → `BagCounts()` returns `4, 16, 12`.
  - `bag_text_format`: bar bags text == `L.INFOBAR_BAGS:format(4, 16, 12)`; `INFOBAR_BAGS = "%d/%d (%d free)"`.
  - `bag_text_colour`: 2 free → text colour red `(1, 0.2, 0.2)`; 5 free → orange `(1, 0.6, 0)`; 6+ → white.
  - `gear_percent_sum_over_max`: two items 50/100 and 100/100 → `percent == 75`, `anyLow == false`; one at 10/100 → `anyLow == true` and text colour red; overall 40% with none below 20 → yellow `(1, 0.82, 0)`.
  - `gear_dash_when_no_durability`: nothing with durability → gear text `"—"`.
  - `secret_values_show_question_mark`: `GetMoney` returns `WOW.secret(5)` → gold text `L.INFOBAR_UNKNOWN` (`"?"`).
  - `bar_only_panel_when_no_rows`: no rules showing, bar enabled → `NewbieNudgePanel:IsShown()`, `#row_texts() == 0`.
  - `panel_hidden_when_no_rows_and_bar_off`: `db.infobar.enabled = false` → panel hidden.
  - `bar_hidden_in_combat`: fire `PLAYER_REGEN_DISABLED` → `InfoBar.frame:IsShown() == false`.
  - `hide_panel_hides_bar`: `Panel:ToggleHidden()` → panel and bar hidden.
  - `segment_toggles`: `db.infobar.gold = false`, refresh → gold segment hidden, other two shown.
  - `updates_on_money_event`: change `WOW.state.money`, fire `PLAYER_MONEY`, `run_checks()` → gold text updated.
  - `clicks`: bags segment click records `ToggleAllBags`; gear click records `ToggleCharacter "PaperDollFrame"`.
  - `segment_tooltips`: hover bags → a line per bag `L.INFOBAR_BAG_LINE`; hover gear → `L.INFOBAR_GEAR_LOWEST:format(name, pct)`.
  Options: `infobar_checkboxes_registered`: `NN_infobar_enabled`, `NN_infobar_bags`, `NN_infobar_gold`, `NN_infobar_gear` exist and round-trip to `db.infobar.*`.

- [ ] **Step 2: Run** `python tests/run.py infobar` → FAIL.

- [ ] **Step 3: Implement.** Bar is a frame child of `Panel.frame`, three `Button` segments (icon 12×12 + `GameFontHighlightSmall` text), laid left to right with 8 px gaps. Icons: bags 133634, gold `"Interface\\MoneyFrame\\UI-GoldIcon"`, gear 136241. Event updates: `NN:RegisterEvent` + `NN:OnAnyEvent` for `BAG_UPDATE_DELAYED`, `PLAYER_MONEY`, `UPDATE_INVENTORY_DURABILITY`, `PLAYER_EQUIPMENT_CHANGED`, `PLAYER_ENTERING_WORLD` → `NN.Panel:Refresh(NN.Panel.currentRows)`. `Panel` gets a single `Panel:Layout(contentWidth, contentHeight)` that stacks title (when unlocked) → bar (when active) → content and sets frame size; frame width in list style stays 260; in strip mode `max(stripWidth, barWidth) + PAD*2`. If the gold text makes the bar wider than 260 − 2·PAD in list style, pass `NN.MoneyText(money - money % 100)` (drop copper) when `money >= 10000`.
  Options main page, after the Panel controls: `Options.AddHeader(layout, L.OPT_INFOBAR_HEADER)` and four checkboxes; setters call `NN.Panel:Refresh(NN:ActiveRows())`.
  Locale (enUS): `OPT_INFOBAR_HEADER = "Info bar"`, `OPT_INFOBAR = "Show the info bar on top of the panel"`, `OPT_INFOBAR_TT = "Bag space, gold and gear condition at a glance. Hidden in combat."`, `OPT_INFOBAR_BAGS = "Bag space"`, `OPT_INFOBAR_GOLD = "Gold"`, `OPT_INFOBAR_GEAR = "Gear condition"`, `INFOBAR_BAGS = "%d/%d (%d free)"`, `INFOBAR_UNKNOWN = "?"`, `INFOBAR_BAGS_TITLE = "Bags"`, `INFOBAR_BAG_LINE = "%s: %d of %d free"`, `INFOBAR_GEAR_TITLE = "Gear condition"`, `INFOBAR_GEAR_LOWEST = "Most worn: %s (%d%%)"`, `INFOBAR_CLICK_BAGS = "Click: open your bags"`, `INFOBAR_CLICK_GEAR = "Click: open your character"`.

- [ ] **Step 4: Run** `python tests/run.py` → all pass (existing `hidden_when_no_rows` in `test_panel.lua` now needs `db.infobar.enabled = false` first — update it).

- [ ] **Step 5: Commit (local only)** `feat: info bar with bag space, gold and gear condition on top of the panel`

---

### Task 4: Minimap button, menu and slash commands

**Files:**
- Create: `NewbieNudge/Minimap.lua` (TOC: after `InfoBar.lua`)
- Modify: `NewbieNudge/Core.lua` (defaults `minimap = { hide = false, angle = 225 }`; `NN:SnoozeShowing(minutes) -> count`; slash `minimap`, `style`, `bar`)
- Modify: `NewbieNudge/NewbieNudge.toc` (no compartment TOC fields; registration is in code)
- Modify: `NewbieNudge/Options.lua` (Minimap header + `NN_minimap_show` checkbox on the main page)
- Modify: `tests/wow_stub.lua`: `Minimap` frame (width/height 140, `GetEffectiveScale` 1, `GetCenter` → 1000, 700), `GetCursorPosition()` → `S().cursorX, S().cursorY`, `MenuUtil.CreateContextMenu(owner, generator)` that runs `generator(owner, rootDescription)` against a recording description (`CreateTitle`, `CreateButton`, `CreateCheckbox`, `CreateRadio`, `CreateDivider`) and stores it in `WOW.lastMenu`, `AddonCompartmentFrame = { RegisterAddon = function(self, info) record("RegisterAddon", info.text) ; WOW.compartment = info end }`.
- Modify: locales
- Test: create `tests/test_minimap.lua`; extend `tests/test_slash.lua`

**Interfaces:**
- Consumes: `NN.Panel:SetStyle`, `NN.Panel:ToggleHidden`, `NN.Panel:SetLocked`, `NN.ClearSnoozes`, `NN:OpenOptions`, `NN.InfoBar`.
- Produces: `NN.MinimapButton` with `button`, `MenuEntries() -> { { kind = "title"|"button"|"checkbox"|"radio"|"divider", label = string, checked = bool|nil, onClick = function|nil } , ... }`, `OpenMenu(owner)`, `SetAngle(degrees)` (saves + repositions), `PositionForAngle(degrees) -> x, y` (offset from minimap centre), `SetShown(bool)` (saves `db.minimap.hide`), `Toggle()`; `NN:SnoozeShowing(minutes) -> number`.

- [ ] **Step 1: Failing tests** in `tests/test_minimap.lua`:
  - `button_created_and_positioned`: after load, `NewbieNudgeMinimapButton` exists, parent `Minimap`; `PositionForAngle(0)` ≈ `(80, 0)`; `PositionForAngle(90)` ≈ `(0, 80)` (radius 140/2 + 10).
  - `square_minimap_clamps`: `GetMinimapShape = function() return "SQUARE" end` → `PositionForAngle(45)` gives `|x| <= 80` and `|y| <= 80` with one coordinate == 80.
  - `drag_saves_angle`: cursor at `(1000, 780)` (straight up), fire `OnDragStart`, `OnUpdate`, `OnDragStop` → `db.minimap.angle == 90`.
  - `menu_entries_locked`: `db.panel.locked = true` → entries include button `L.MENU_UNLOCK`; unlocked → `L.MENU_LOCK`; clicking it flips `db.panel.locked`.
  - `menu_style_radios`: two radios `L.MENU_STYLE_LIST` / `L.MENU_STYLE_ICONS`, `checked` follows `db.panel.style`; clicking icons sets `"icons"`.
  - `menu_snooze_everything_only_when_rows`: no rows → no `MENU_SNOOZE_ALL` entry; two rule rows showing, `snoozeMinutes = 60` → label `L.MENU_SNOOZE_ALL:format(L.MENU_DURATION_HOURS:format(1))`; click snoozes exactly those two rules (`db.snoozed` has both, a third non-showing rule absent) and prints `L.SNOOZE_ALL_DONE:format(2, 60)`. `snoozeMinutes = 45` → label uses `L.MENU_DURATION_MINUTES:format(45)`.
  - `menu_infobar_checkbox`: checkbox `L.MENU_INFOBAR`, `checked == db.infobar.enabled`; click flips it and the panel refreshes.
  - `menu_wake_all_only_when_snoozed`: entry `L.MENU_WAKE_ALL` present only when `next(db.snoozed)`; click empties `db.snoozed`.
  - `menu_hide_show_and_settings`: `L.MENU_HIDE` → `db.panel.hidden == true`, then entry reads `L.MENU_SHOW`; `L.MENU_SETTINGS` click records `OpenToCategory`.
  - `click_opens_menu`: `WOW.Click(button, "LeftButton")` → `WOW.lastMenu` has a title `L.ADDON_TITLE`; right button the same.
  - `tooltip_counts_rows`: hover with 3 rows → line `L.MINIMAP_TT_COUNT:format(3)`; with 0 → `L.MINIMAP_TT_NONE`.
  - `hide_setting_and_default`: a DB without `minimap` loads with `hide == false, angle == 225`; `SetShown(false)` hides the button and saves `hide = true`.
  - `compartment_registered_when_present`: `WOW.compartment.text == "NewbieNudge"`; calling `WOW.compartment.func()` builds `WOW.lastMenu` even when the button is hidden.
  - `fallback_without_menuutil`: `MenuUtil = nil` before load, `EasyMenu` stub recording → click calls `EasyMenu` with a list whose first item has `isTitle = true`.
  In `tests/test_slash.lua`: `/nudge minimap` toggles `db.minimap.hide`; `/nudge style` toggles list↔icons; `/nudge bar` toggles `db.infobar.enabled`; each prints its on/off line.

- [ ] **Step 2: Run** `python tests/run.py minimap` → FAIL.

- [ ] **Step 3: Implement.** Button 31×31, `SetFrameStrata("MEDIUM")`, `SetFrameLevel(8)`, overlay `Interface\\Minimap\\MiniMap-TrackingBorder` (53×53, TOPLEFT), background `Interface\\Minimap\\UI-Minimap-Background`, icon `Interface\\AddOns\\NewbieNudge\\Media\\icon` 20×20 centred, highlight `Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight`. `RegisterForClicks("AnyUp")`, `RegisterForDrag("LeftButton")`; drag sets an `OnUpdate` that computes `atan2(cy - my, cx - mx)` from the cursor (divided by `Minimap:GetEffectiveScale()`) and the minimap centre, in degrees, then `SetAngle`. Square clamp: compute `x, y = cos·r, sin·r` then if square, scale by `r / max(|x|, |y|)` so the larger coordinate equals `r` (matches the test). Menu labels from `MenuEntries()`; `OpenMenu` turns them into `MenuUtil.CreateContextMenu` calls, or into `EasyMenu(list, dropdownFrame, "cursor", 0, 0, "MENU")` when `MenuUtil` is absent. `SnoozeShowing`: unique rule names from `NN:ActiveRows()` → `NN:Snooze(name, minutes)` each; return count. Compartment: `if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then AddonCompartmentFrame:RegisterAddon({ text = L.ADDON_TITLE, icon = "Interface\\AddOns\\NewbieNudge\\Media\\icon", notCheckable = true, func = function() MinimapButton:OpenMenu(...) end, funcOnEnter = …tooltip… }) end` in an `AfterLogin` hook.
  Locale (enUS): `MINIMAP_TT_COUNT = "%d reminder(s) showing"`, `MINIMAP_TT_NONE = "Nothing to fix right now"`, `MINIMAP_TT_CLICK = "Click: menu"`, `MINIMAP_TT_DRAG = "Drag: move this button"`, `MENU_LOCK = "Lock panel"`, `MENU_UNLOCK = "Unlock panel (to move it)"`, `MENU_STYLE = "Panel style"`, `MENU_STYLE_LIST = "Full list"`, `MENU_STYLE_ICONS = "Icons only"`, `MENU_INFOBAR = "Show info bar"`, `MENU_SNOOZE_ALL = "Snooze everything (%s)"`, `MENU_DURATION_HOURS = "%d h"`, `MENU_DURATION_MINUTES = "%d min"`, `MENU_WAKE_ALL = "Wake all reminders"`, `MENU_HIDE = "Hide panel"`, `MENU_SHOW = "Show panel"`, `MENU_SETTINGS = "Settings…"`, `SNOOZE_ALL_DONE = "Snoozed %d reminder(s) for %d minutes."`, `OPT_MINIMAP_HEADER = "Minimap"`, `OPT_MINIMAP = "Show minimap button"`, `OPT_MINIMAP_TT = "A button on the edge of the minimap with a quick menu. Drag it to move it."`, `SLASH_MINIMAP_ON/OFF = "Minimap button shown." / "Minimap button hidden. /nudge minimap brings it back."`, `SLASH_STYLE_LIST/ICONS = "Panel shows the full list." / "Panel shows icons only."`, `SLASH_BAR_ON/OFF = "Info bar on." / "Info bar off."`; `SLASH_HELP` gains `/nudge minimap, /nudge style, /nudge bar`. Hours label used when `snoozeMinutes % 60 == 0`.

- [ ] **Step 4: Run** `python tests/run.py` → all pass.

- [ ] **Step 5: Commit (local only)** `feat: minimap button with a quick menu, AddOns compartment entry, /nudge minimap|style|bar`

---

### Task 5: Reminders page with groups

**Files:**
- Modify: `NewbieNudge/Core.lua` (`RegisterRule` normalises `rule.group`)
- Modify: every `NewbieNudge/Rules/*.lua` and `NewbieNudge/TalentBuild.lua` (add `group = "…"` to each `RegisterRule` table)
- Modify: `NewbieNudge/Options.lua` (Reminders moves to its own subcategory, built first among subpages)
- Modify: locales
- Test: `tests/test_options.lua`, `tests/test_core_registry.lua`

**Interfaces:**
- Produces: `NN.RULE_GROUPS = { "gear", "spells", "quests", "professions", "travel", "other" }`; `rule.group` always one of these after registration; `Options.BuildReminders(category, layout)`.

Group assignment (exact):
- `gear`: bag_unequipped, materials_bag, bag_full, durability, gear_upgrade, ammo, supplies
- `spells`: talents, talent_build, spell_ranks, trainer_spells, buffs, tracking, weapon_skill, pet, demon
- `quests`: quests, quest_item, quest_turnin, quest_slots, quest_soon, quest_grey, quest_group
- `professions`: professions, profession_rank
- `travel`: hearthstone, hearth_bind, flight_path, mount, dungeon_ready, zone_level, rested, legacy, mail

- [ ] **Step 1: Failing tests.**
  - `test_core_registry.lua`: `missing_or_bad_group_becomes_other` (register `group = nil` and `group = "nope"` → `"other"`).
  - `test_options.lua`: `every_real_rule_has_a_group` (load without fixtures; every `NN.rules[i].group ~= "other"`); `reminders_page_is_a_subcategory` (`RegisterVerticalLayoutSubcategory` call with `L.OPT_REMINDERS`); `rule_checkboxes_not_on_main_page` (no `NN_rule_*` checkbox recorded before the Reminders subcategory call); `group_headers_in_order` (headers on the Reminders page appear in `RULE_GROUPS` order, skipping empty groups; fixtures land under `L.OPT_GROUP_OTHER`); `rules_in_priority_order_within_group` (durability's checkbox comes before bag_unequipped's). Update `one_checkbox_per_rule_in_order` to drop its "rules come after general" assertion only if it now fails for the right reason.

- [ ] **Step 2: Run** `python tests/run.py options` → FAIL.

- [ ] **Step 3: Implement** the normalisation, the `group` fields, and `Options.BuildReminders`: per group, collect rules, sort by `NN.PRIORITY` index (unknown after, registration order), header `L["OPT_GROUP_" .. group:upper()]`, then the same checkbox code as today (variable `NN_rule_<name>` unchanged). README "Adding a reminder" snippet gains `group = "gear", -- gear | spells | quests | professions | travel`.
  Locale (enUS): `OPT_GROUP_GEAR = "Bags and gear"`, `OPT_GROUP_SPELLS = "Spells and talents"`, `OPT_GROUP_QUESTS = "Quests"`, `OPT_GROUP_PROFESSIONS = "Professions"`, `OPT_GROUP_TRAVEL = "Travel and levelling"`, `OPT_GROUP_OTHER = "Other"`.

- [ ] **Step 4: Run** `python tests/run.py` → all pass.

- [ ] **Step 5: Commit (local only)** `feat: reminders get their own options page, grouped`

---

### Task 6: Options pages reorganised; game settings split per page

**Files:**
- Modify: `NewbieNudge/Options.lua` (explicit page order; main page sections)
- Modify: `NewbieNudge/GameSettings.lua` (`page` per entry; `AddPageControls`; three pure game-settings pages; preset buttons move to main page)
- Modify: `NewbieNudge/BagFull.lua`, `NewbieNudge/Vendor.lua`, `NewbieNudge/Tooltips.lua` (one "bags" page)
- Modify: `NewbieNudge/MapReveal.lua` (game settings on the Map page; `OpenSettings` by key)
- Modify: locales
- Test: `tests/test_options.lua`, `tests/test_gamesettings.lua`, `tests/test_mapreveal.lua`, `tests/test_vendor.lua`, `tests/test_tooltips.lua` (adjust page-title expectations)

**Interfaces:**
- Consumes: `Options.BuildReminders` (Task 5); `NN_panel_style`, info bar, minimap controls (Tasks 2–4).
- Produces: `Options.PAGE_ORDER = { "reminders", "bags", "map", "gs_combat", "gs_names", "gs_interface", "camera", "controller", "build", "dev" }`; `Options.subcategoriesByKey[key] -> category`; `GameSettings:AddPageControls(category, layout, page: "bags"|"map"|"combat"|"names"|"interface")`; `Options.AddGameSettingsHeader(layout)` (adds `L.OPT_GS_HEADER`).

CVar → page (exact):
- `bags`: autoLootDefault, lootUnderMouse, expandBagBar, combinedBags
- `map`: mapFade, rotateMinimap, questPOI
- `combat`: every entry of today's `GS_GROUP_COMBAT` block (ActionButtonUseKeyDown … secureAbilityToggle)
- `names`: every entry of today's `GS_GROUP_NAMES` block (nameplateShowEnemies … UnitNameOwn)
- `interface`: interactOnLeftClick, autoDismount, autoClearAFK, autoInteract, autoQuestWatch, autoQuestProgress, showQuestObjectivesInLog, ShowQuestUnitCircles, showTutorials, showNPETutorials, screenEdgeFlash, doNotFlashLowHealthWarning, statusText, statusTextDisplay, Outline, findYourselfMode, chatBubbles, guildMemberNotify, Sound_EnableErrorSpeech — with headers `GS_GROUP_MOVE` before interactOnLeftClick and `GS_GROUP_QUESTS` before autoQuestWatch.

- [ ] **Step 1: Failing tests.**
  - `test_gamesettings.lua`: `every_curated_entry_has_a_valid_page`; `each_cvar_on_exactly_one_page` (build all pages, each `NN_cvar_<cvar>` registered once — the stub errors on a second registration anyway, and each page's recorded checkboxes match the table above for `bags` and `map`); `preset_buttons_on_main_page` (buttons `L.OPT_GS_PRESET`/`L.OPT_GS_RESET` recorded before the first `RegisterVerticalLayoutSubcategory`); replace `page_has_groups_and_buttons` with `game_pages_exist` (subcategories `L.OPT_GS_COMBAT`, `L.OPT_GS_NAMES`, `L.OPT_GS_INTERFACE`) and `game_pages_start_with_intro_header` (`L.OPT_GS_PAGE_INTRO`).
  - `test_options.lua`: `subpage_order` (subcategory names in order: OPT_REMINDERS, OPT_BAGS, OPT_MAP, OPT_GS_COMBAT, OPT_GS_NAMES, OPT_GS_INTERFACE, OPT_CAMERA, OPT_CONTROLLER (when `C_GamePad`), OPT_BUILD, OPT_DEV); `unknown_page_key_goes_last` (fixture `failing_page.lua`'s page comes after OPT_DEV and its error doesn't stop later pages); `main_page_sections` (headers OPT_PANEL, OPT_INFOBAR_HEADER, OPT_MINIMAP_HEADER, OPT_SETUP in that order); `bags_page_holds_vendor_and_tooltip_controls` (`NN_vendor_sellJunk`, `NN_vendor_repair`, `NN_tooltipPrice`, `NN_bagfull_enabled` all registered under the OPT_BAGS subcategory, followed by header `L.OPT_GS_HEADER` and `NN_cvar_autoLootDefault`); `no_vendors_or_tooltips_pages` (no subcategory named OPT_BAGS_VENDOR / OPT_TOOLTIPS).
  - `test_mapreveal.lua`: `open_settings_uses_page_key` (`MapReveal:OpenSettings()` records `OpenToCategory` with the Map subcategory's ID).

- [ ] **Step 2: Run** `python tests/run.py` → the new tests FAIL.

- [ ] **Step 3: Implement.**
  - `Options.RegisterPage` unchanged in signature; `Options:Build` builds the main page (headers `OPT_PANEL`: lock, style, scale, combat strip, snooze length, reset snoozes, reset position; `OPT_INFOBAR_HEADER`; `OPT_MINIMAP_HEADER`; `OPT_SETUP`: `L.OPT_GS_PRESET` and `L.OPT_GS_RESET` buttons calling `NN.GameSettings`), then subpages in `PAGE_ORDER`, then any registered page whose key isn't in the list, in registration order. Camera becomes a registered page with key `"camera"` (move the special case out of `Build`). Store `subcategoriesByKey[key]`.
  - `BagFull.lua` keeps `RegisterPage("bags", "OPT_BAGS", …)`; its builder adds header `OPT_BAGFULL_HEADER`, its own controls, then `NN.Vendor.AddOptions(category, layout)` (header `OPT_BAGS_VENDOR`), `NN.Tooltips.AddOptions(category, layout)` (header `OPT_TOOLTIPS`), then `Options.AddGameSettingsHeader(layout)` and `NN.GameSettings:AddPageControls(category, layout, "bags")`. `Vendor.lua`/`Tooltips.lua` stop calling `RegisterPage` and expose `AddOptions` instead.
  - `MapReveal` page: existing controls, then the game-settings header and `AddPageControls(…, "map")`; `OpenSettings` uses `Options.subcategoriesByKey.map`.
  - `GameSettings.lua`: each curated entry gets `page = …` (header entries too); `AddPageControls` filters and calls `CVarSection.AddControls(self, category, layout, filtered)`. Register pages `gs_combat` (`OPT_GS_COMBAT`), `gs_names` (`OPT_GS_NAMES`), `gs_interface` (`OPT_GS_INTERFACE`), each starting with header `OPT_GS_PAGE_INTRO`. Drop the `OPT_GAME_SETTINGS` page. `GS_GROUP_LOOT`, `GS_GROUP_NAMES`, `GS_GROUP_COMBAT` header entries are removed (their page title says it).
  Locale (enUS): `OPT_PANEL = "Panel"`, `OPT_SETUP = "New player setup"`, `OPT_BAGS = "Bags and vendors"` (changed value), `OPT_BAGFULL_HEADER = "When your bags are full"`, `OPT_MAP = "Map and minimap"` (changed value), `OPT_GS_HEADER = "Game settings"`, `OPT_GS_PAGE_INTRO = "These are the game's own settings, gathered here with plain labels."`, `OPT_GS_COMBAT = "Combat and action bars"`, `OPT_GS_NAMES = "Names and health bars"`, `OPT_GS_INTERFACE = "Quests and interface"`, `OPT_GS_PRESET = "Apply recommended game settings"` (changed value), `OPT_GS_RESET = "Reset these game settings to defaults"` (changed value). Remove now-unused keys (`OPT_GAME_SETTINGS`, `GS_GROUP_LOOT`, `GS_GROUP_NAMES`, `GS_GROUP_COMBAT`) from both locale files only if nothing references them (`grep`).

- [ ] **Step 4: Run** `python tests/run.py` and `python -m unittest discover -s tests -p "test_*.py"` → all pass.

- [ ] **Step 5: Commit (local only)** `feat: options regrouped — smaller main page, game settings next to the features they belong to`

---

### Task 7: Docs, version and in-game checklist

**Files:**
- Modify: `README.md` (commands table: `/nudge minimap`, `/nudge style`, `/nudge bar`; new short sections "Minimap button" and "Info bar"; the icons style sentence in the intro; the materials-bag reminder in the Reminders list; `group` in "Adding a reminder")
- Modify: `docs/testing-checklist.md` (new "v4" section — see below)
- Modify: `CHANGELOG.md` (`## 0.4.0 - unreleased` at the top, player-facing bullets for the five features)
- Modify: `NewbieNudge/NewbieNudge.toc` (`## Version: 0.4.0`)

- [ ] **Step 1: Checklist probes** added to section 0 of `docs/testing-checklist.md`:

| In chat | Feature | Expected |
|---|---|---|
| `/dump type(MenuUtil), type(MenuUtil and MenuUtil.CreateContextMenu), type(EasyMenu)` | minimap menu | `table function …` (if `nil`, the EasyMenu fallback is used) |
| `/dump type(AddonCompartmentFrame), type(GetMinimapShape)` | compartment, square minimap | `table`/`nil`, `function`/`nil` |
| `/dump type(PickupBagFromSlot), type(PutItemInBag)` | materials bag move | `function function` |

  And a v4 section: drag the minimap button around (square and round minimap); each menu entry; icons style in and out of combat with combat strip on/off; info bar with bags full / near full, broken gear, after buying something; profession bag in bag slot 2 with an empty materials slot → click moves it (and with items inside it); every options page opens and nothing is on two pages.

- [ ] **Step 2: Run** `python tests/run.py`, `python -m unittest discover -s tests -p "test_*.py"` and `python tools/locales.py check` → all pass; `python tools/release.py check v0.4.0` is expected to refuse while the changelog says "unreleased" (that's the guard; the date goes in at release time).

- [ ] **Step 3: Commit (local only)** `docs: v0.4.0 README, changelog and in-game checklist`

- [ ] **Step 4: Hand over for in-game testing.** Tell the owner to run `powershell -File tools/deploy.ps1` (once) and `/reload`; walk the v4 checklist. No push, no tag.
