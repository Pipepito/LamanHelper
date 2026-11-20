# NewbieNudge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A World of Warcraft Forever addon that shows new players a self-hiding checklist of things to fix (unspent talents, missing buffs, unused bags, and twelve more) and glows the default UI button that fixes each one.

**Architecture:** `Core.lua` owns the rule registry, event-to-rule dirty marking, a half-second check scheduler with combat gating, saved variables and the slash command. Each reminder is one rule table in `Rules/*.lua` that reads game state and returns zero or more result rows; it never touches frames. `Panel.lua` draws rows (or a compact icon strip in combat), `Highlight.lua` glows default UI buttons and action-bar slots, `Options.lua` builds a native Settings page, and `Locales/*.lua` hold every string.

**Tech Stack:** WoW Lua 5.1 (Forever client, TOC interface 16001), no libraries. Offline tests run in Python 3.12 through `lupa` (LuaJIT) against `tests/wow_stub.lua`. Git for history. PowerShell junction script for deploying into the game's AddOns folder.

**Spec:** `docs/superpowers/specs/2026-11-20-newbienudge-design.md`

## Global Constraints

- TOC header: `## Interface: 16001`, `## AllowLoadGameType: forever`, `## ExcludeLoadGameType: standard, classic`, `## SavedVariablesPerCharacter: NewbieNudgeDB`.
- Every file receives `local ADDON_NAME, NN = ...`; the shared table `NN` is also exposed as `_G.NewbieNudge`.
- No literal user-facing English in any file except `Locales/enUS.lua`; all text goes through `NN.L.KEY`. `Locales/esES.lua` must define exactly the same keys.
- Spanish uses the informal "tú" form.
- Any value for which `issecretvalue(v)` is true is "unknown": a rule keeps its previous result. Use `NN.Plain(v, kind)` for every number or string read from the API.
- Rules never create frames, never print (except `rested` through `NN:Say`), never error on a missing API: guard every optional global with `if not X then return nil end`.
- Rules with `combat = true` must only read bags, inventory, item counts, pet existence, pet happiness and mail; nothing else is reliable in combat.
- Every row text, title and help string is a key in both locale files.
- Lua 5.1 only: no `goto`, no integer division, `table.unpack` is `unpack`.
- Commit after every task with the message given in the task.

## Review Focus

Inputs the spec implies but no single rule obviously covers; each has a test added to the owning task:

1. **Login before bags are loaded**: `BAG_UPDATE_DELAYED` has not fired yet and `C_Container.GetContainerItemInfo` returns nil for every slot; `hearthstone` and `bag_unequipped` must say nothing rather than claim "no Hearthstone". Test in Task 9 and Task 8.
2. **An API that exists but returns a secret value in combat** for a combat-enabled rule (durability in a dungeon): the rule's previous result must survive and the row must not vanish. Test in Task 3 (scheduler) with a stub secret.
3. **A rule that errors once** must not take the panel down and must not error again that session. Test in Task 3.
4. **Snoozed rule becomes relevant again after the snooze expires** without any new game event: the scheduler's periodic pass must re-show it. Test in Task 3.
5. **Spanish client with a missing key**: the English text must show, never `nil` or an error. Test in Task 2.

---

## File structure

```
NewbieNudge/                      the addon, deployed as-is into Interface\AddOns
  NewbieNudge.toc
  Locales/enUS.lua                NN.L with every key; fallback metatable
  Locales/esES.lua                overwrites keys when GetLocale() == "esES"
  Core.lua                        registry, scheduler, gating, saved vars, slash, NN.Plain, NN:Say
  Spellbook.lua                   cached name -> top-rank spellID map shared by three rules
  Highlight.lua                   NN.Highlight: glow default buttons and action slots
  Panel.lua                       NN.Panel: rows, combat strip, tooltip, snooze clicks, drag
  Options.lua                     Settings page
  Data_Buffs.lua                  NN.BuffData[class] = { groups }
  Rules/Bags.lua                  bag_unequipped, bag_full
  Rules/Simple.lua                durability, hearthstone, mail, quests
  Rules/Talents.lua
  Rules/Buffs.lua
  Rules/SpellRanks.lua
  Rules/Tracking.lua
  Rules/Ammo.lua
  Rules/Pet.lua
  Rules/Professions.lua
  Rules/Rested.lua
  Rules/GearUpgrade.lua
tests/
  run.py                          runner (lupa); also locale key parity
  wow_stub.lua                    fake WoW API driven by the WOW.state table
  helpers.lua                     assert_eq, load_addon, results_of
  test_*.lua                      one file per task
tools/
  deploy.ps1                      junction NewbieNudge/ into the Forever AddOns folder
  requirements.txt                lupa
docs/testing-checklist.md         in-game checks, one block per rule
```

Rule file load order in the TOC: Locales, Core, Spellbook, Highlight, Panel, Options, Data_Buffs, then Rules in the order listed above.

---

### Task 1: Offline test harness, repo and deploy script

**Files:**
- Create: `.gitignore`, `tools/requirements.txt`, `tools/deploy.ps1`, `tests/run.py`, `tests/wow_stub.lua`, `tests/helpers.lua`, `tests/test_harness.lua`

**Interfaces:**
- Produces: `python tests/run.py [pattern]` exits 0 when every test passes, prints `PASS <file>::<name>` / `FAIL <file>::<name>: <message>` lines and a summary line `N passed, M failed`.
- Produces: Lua global `WOW` in every test with `WOW.state` (table below), `WOW.FireEvent(event, ...)`, `WOW.AdvanceTime(seconds)`, `WOW.secret(value)` (returns an opaque marker that `issecretvalue` recognises), `WOW.calls` (list of `{name, ...args}` for every UI action the stub records), `WOW.printed` (list of strings passed to `print`), `WOW.Reset()`.
- Produces: `helpers.lua` with `assert_eq(actual, expected, msg)`, `assert_true(v, msg)`, `assert_nil(v, msg)`, `load_addon()` (loads TOC-listed files in order with `("NewbieNudge", ns)` and fires `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`; it does **not** fire `BAG_UPDATE_DELAYED`; after the TOC files it also loads every path in the optional list `WOW.extraFiles`, so a test can register rules before `PLAYER_LOGIN` fires), `load_bags()` (fires `BAG_UPDATE_DELAYED` once), `run_checks()` (`WOW.AdvanceTime(0.5)`), `results_of(ruleName)` (returns `NewbieNudge.results[ruleName]` or `{}`), `row_texts()` (texts of the panel's visible rows in order).
- Produces: test file convention: a test file returns a table `{ name = function() ... end, ... }`; the runner creates a fresh Lua runtime, loads `wow_stub.lua` then `helpers.lua`, then the test file, and calls each function in sorted name order.

`WOW.state` default shape (the stub reads only this table; tests mutate it before calling `load_addon()` or firing events):

```lua
WOW.state = {
  locale = "enUS", class = "MAGE", className = "Mage", level = 20, maxLevel = 60,
  time = 1000, inCombat = false, resting = false, mounted = false, dead = false,
  instanceType = "none", projectID = 18,
  bags = { [0] = { numSlots = 16, family = 0, items = {} } }, -- items[slot] = { itemID=, count=, link= }
  inventory = {},            -- [invSlot] = { itemID=, link=, durability = {cur, max} }
  itemInfo = {},             -- [itemID] = { name, link, quality, itemLevel, reqLevel, itemType, itemSubType, equipLoc, icon, classID, subclassID, family, numSlots }
  itemCounts = {},           -- [itemID] = n
  auras = {},                -- [spellID] = true and/or [name] = true
  spellInfo = {},            -- [spellID] = { name=, subtext=, icon= }
  spellBook = { lines = {}, items = {} }, -- lines[i] = { name, offset, num, offSpecID }; items[slot] = { spellID, passive, lowRank, type = "SPELL" }
  actions = {},              -- [slot] = { type = "spell", id = spellID }
  weaponEnchant = { main = false, off = false },
  talents = { configID = 1, treeID = 10, unspent = 0 },
  tracking = {},             -- [i] = { name=, spellID=, active=false }
  usesAmmo = false, ammoCount = 0,
  pet = { exists = false, hasUI = false, isHunterPet = false, happiness = 3, trainingTotal = 0, trainingSpent = 0 },
  professions = {},          -- { prof1 = 1 or nil, prof2 = 2 or nil }
  skillLines = {},           -- [i] = { name=, isHeader=false }
  quests = { num = 5, max = 25 }, newMail = false,
  cursor = nil,              -- nil or { type = "spell", id = }
  gameMenuShown = false,
}
```

Globals the stub must provide (everything else the addon calls is added by the task that needs it, always as a reader of `WOW.state` or a recorder into `WOW.calls`): `CreateFrame` (frames with `SetScript/GetScript/HookScript/RegisterEvent/UnregisterEvent/RegisterUnitEvent/UnregisterAllEvents/Show/Hide/IsShown/SetShown/SetPoint/ClearAllPoints/GetPoint/SetSize/SetWidth/SetHeight/GetWidth/GetHeight/SetAlpha/GetAlpha/SetScale/GetScale/SetMovable/EnableMouse/RegisterForDrag/RegisterForClicks/StartMoving/StopMovingOrSizing/SetClampedToScreen/SetUserPlaced/SetFrameStrata/SetFrameLevel/GetFrameLevel/CreateTexture/CreateFontString/GetName/GetParent/SetParent/SetID/GetID/SetAttribute/GetAttribute/SetBackdrop/SetBackdropColor/SetBackdropBorderColor/IsMouseOver/GetObjectType/SetHighlightTexture/SetNormalTexture/SetPushedTexture/SetText/GetText/SetMinMaxValues/SetValue/GetValue/SetValueStep/SetObeyStepOnDrag`; textures and font strings with `SetTexture/SetAtlas/SetColorTexture/SetVertexColor/SetAllPoints/SetPoint/SetSize/SetWidth/SetHeight/Show/Hide/IsShown/SetAlpha/SetText/GetText/SetJustifyH/SetJustifyV/SetWordWrap/GetStringWidth/GetStringHeight/SetFont/GetFont/SetTextColor/SetDrawLayer/SetTexCoord/SetDesaturated/SetBlendMode`), `UIParent`, `GameTooltip` (`SetOwner/SetText/AddLine/AddDoubleLine/Show/Hide/ClearLines/IsShown/GetOwner`), `GameMenuFrame` (shows when `WOW.state.gameMenuShown` is set through `WOW.ShowGameMenu(bool)`, which also runs its `OnShow`/`OnHide` scripts and hooks), `C_Timer.After`, `C_Timer.NewTicker`, `GetTime`, `GetLocale`, `UnitClass`, `UnitLevel`, `GetMaxPlayerLevel`, `InCombatLockdown`, `IsResting`, `IsMounted`, `UnitIsDeadOrGhost`, `IsInInstance`, `UnitExists`, `UnitName`, `GetBuildInfo`, `issecretvalue`, `canaccessvalue`, `print`, `format`, `strsplit`, `strtrim`, `strlower`, `wipe`, `tinsert`, `tremove`, `tContains`, `CopyTable`, `Mixin`, `hooksecurefunc`, `SlashCmdList`, `ClearCursor`, `GetCursorInfo`, `WOW_PROJECT_ID`, `WOW_PROJECT_CAMELOT = 18`, `Enum.BagIndex` (`Backpack=0, Bag_1=1, Bag_2=2, Bag_3=3, Bag_4=4, ReagentBag=5`), `Enum.ItemClass.Container = 1`, `Enum.ItemClass.Armor = 4`, `Enum.ItemClass.Weapon = 2`, `Enum.ItemArmorSubclass` (`Cloth=1, Leather=2, Mail=3, Plate=4`), `Enum.SpellBookSpellBank` (`Player=0, Pet=1`), `Enum.SpellBookItemType.Spell = 1`, `INVSLOT_AMMO = 0`, `INVSLOT_FIRST_EQUIPPED = 1`, `INVSLOT_LAST_EQUIPPED = 17`, `CONTAINER_SLOTS = "%d|4Slot:Slots; %s"`, `TRADE_SKILLS = "Professions"`.

`issecretvalue(v)` is true exactly for markers returned by `WOW.secret()`. `canaccessvalue(v)` is its negation. Frames registered for an event receive `OnEvent` via `WOW.FireEvent`. `C_Timer.After(d, fn)` stores `{due = state.time + d, fn}`; `WOW.AdvanceTime(s)` advances `state.time` and runs due timers in order (tickers re-arm). `print(...)` joins args with spaces into `WOW.printed`.

- [ ] **Step 1: Initialise git and ignore files**

```bash
git init
printf '.venv/\n__pycache__/\n*.pyc\n' > .gitignore
```

- [ ] **Step 2: Create the Python environment and install lupa**

```bash
printf 'lupa>=2.0\n' > tools/requirements.txt
python -m venv .venv && .venv/Scripts/python -m pip install -r tools/requirements.txt
```

Expected: `Successfully installed lupa-2.x`.

- [ ] **Step 3: Write `tests/test_harness.lua`**

```lua
return {
  stub_fires_events_to_registered_frames = function()
    local got
    local f = CreateFrame("Frame")
    f:RegisterEvent("BAG_UPDATE_DELAYED")
    f:SetScript("OnEvent", function(_, e, a) got = e .. ":" .. tostring(a) end)
    WOW.FireEvent("BAG_UPDATE_DELAYED", 7)
    assert_eq(got, "BAG_UPDATE_DELAYED:7")
  end,
  timers_fire_when_time_advances = function()
    local n = 0
    C_Timer.After(0.5, function() n = n + 1 end)
    WOW.AdvanceTime(0.4); assert_eq(n, 0)
    WOW.AdvanceTime(0.2); assert_eq(n, 1)
  end,
  secret_marker_is_detected = function()
    assert_true(issecretvalue(WOW.secret(5)))
    assert_true(not issecretvalue(5))
  end,
  print_is_captured = function()
    print("hello", 3)
    assert_eq(WOW.printed[#WOW.printed], "hello 3")
  end,
  lua_is_51_semantics = function()
    assert_eq(_VERSION, "Lua 5.1")
    assert_eq(string.format("%d", 3), "3")
  end,
}
```

- [ ] **Step 4: Run it to verify it fails**

Run: `.venv/Scripts/python tests/run.py`
Expected: FAIL (run.py does not exist yet).

- [ ] **Step 5: Write `tests/run.py`**

Signature: `main(argv) -> int`. Behaviour: find `tests/test_*.lua` (filtered by an optional substring argument); for each test function create a new `LuaRuntime` (`lupa.luajit21`, fall back to `lupa.lua51`; abort with a clear message if neither exists), `require`-free: execute `wow_stub.lua` then `helpers.lua` via `loadfile`, set the Lua global `ADDON_DIR` to the absolute path of `NewbieNudge/` and `TESTS_DIR` to `tests/`, load the test file, call the function inside `pcall`, print PASS/FAIL. Also run the locale parity check: parse `NewbieNudge/Locales/enUS.lua` and `esES.lua` for keys matching `^%s*([A-Z0-9_]+)%s*=` and report any key present in one file and not the other as a FAIL named `locales::parity` (skip silently while neither file exists). Exit code 1 on any FAIL.

- [ ] **Step 6: Write `tests/wow_stub.lua` and `tests/helpers.lua`**

Stub: one `newFrame(kind, name, parent)` factory producing a table with the methods listed above (setters store, getters read, `Show/Hide` flip `shown`, `SetScript` stores into `scripts[handler]`, `HookScript` appends). `_G[name] = frame` when a name is given. `load_addon()` in helpers reads `ADDON_DIR .. "/NewbieNudge.toc"`, takes each non-blank non-`##` line as a relative path (backslashes to slashes), `loadfile`s it and calls it with `("NewbieNudge", ns)` where `ns` is one shared table; then fires `ADDON_LOADED` with `"NewbieNudge"`, `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`. Before the TOC exists, `load_addon()` errors with `"no TOC"` so Task 1's tests do not call it.

- [ ] **Step 7: Run tests to verify they pass**

Run: `.venv/Scripts/python tests/run.py`
Expected: `5 passed, 0 failed`.

- [ ] **Step 8: Write `tools/deploy.ps1`**

Behaviour: `$target = "G:\Games\World of Warcraft\_forever_\Interface\AddOns\NewbieNudge"`; if `$target` exists and is a junction, remove it; if it exists and is a real folder, stop with a message asking to move it away; then `cmd /c mklink /J "$target" "<repo>\NewbieNudge"`. Accept `-Target <path>` to override. Print the junction path on success.

- [ ] **Step 9: Commit**

```bash
git add -A && git commit -m "chore: offline Lua test harness, deploy script"
```

---

### Task 2: TOC, locales and Core skeleton

**Files:**
- Create: `NewbieNudge/NewbieNudge.toc`, `NewbieNudge/Locales/enUS.lua`, `NewbieNudge/Locales/esES.lua`, `NewbieNudge/Core.lua`
- Test: `tests/test_core_registry.lua`, `tests/test_locales.lua`

**Interfaces:**
- Produces: `NN.L` (string table with `__index = function(_, k) return k end`).
- Produces: `NN:RegisterRule(rule)` — validates `name` (string, unique, `^[a-z_]+$`), `title`, `help`, `events` (table), `applies` and `check` (functions); fills `default = true` and `combat = false` when absent; stores in `NN.rules` (array, registration order) and `NN.ruleByName[name]`. Errors with `"NewbieNudge: invalid rule <name>: <field>"` on a bad field.
- Produces: `NN.Plain(v, kind)` → `v` when `not issecretvalue(v) and type(v) == (kind or "number")`, else `nil`.
- Produces: `NN:Say(text)` → `print(NN.L.CHAT_PREFIX .. text)`.
- Produces: `NN.db` (the saved-variables table, created on `ADDON_LOADED` for this addon with defaults filled in: `disabled = {}`, `snoozed = {}`, `panel = { point = "RIGHT", x = -40, y = 60, locked = true, scale = 1 }`, `combatStrip = true`, `snoozeMinutes = 60`, `errors = {}`, `seen = { rules = {} }`).
- Produces: `NN.classFile` (`select(2, UnitClass("player"))`), `NN.isForever` (`WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`).
- Produces: `NN.events` — a frame; `NN:RegisterEvent(event)` registers once and dispatches through `NN:OnEvent(event, ...)` (filled in Task 3; in this task it is an empty function).
- Produces: locale keys. `enUS.lua` defines, with these exact English values:

```
CHAT_PREFIX = "|cff7fd5ffNewbieNudge|r: "
PANEL_TITLE = "Reminders"
ROW_HINT_CLICK = "Left-click to go there."
ROW_HINT_SNOOZE = "Right-click: snooze %d minutes. Shift+right-click: snooze until next login."
ROW_STALE = "Not updated during combat."
MORE_ROWS = "…and %d more"
SLASH_HELP = "Commands: /nudge (options), /nudge lock, /nudge list, /nudge on <name>, /nudge off <name>, /nudge reset, /nudge test"
SLASH_LIST_HEADER = "Reminders for this character:"
SLASH_LIST_LINE = "  %s (%s): %s"
STATE_ON = "on"
STATE_OFF = "off"
STATE_SNOOZED = "snoozed"
STATE_NA = "not relevant for this character"
SLASH_UNKNOWN_RULE = "No reminder called '%s'. Use /nudge list."
SLASH_RULE_SET = "%s is now %s."
SLASH_RESET_DONE = "Snoozes cleared."
SLASH_LOCKED = "Panel locked."
SLASH_UNLOCKED = "Panel unlocked: drag the title bar to move it. /nudge lock when done."
SLASH_TEST_ON = "Test mode: showing every reminder with sample text. /nudge reset to leave."
RULE_ERROR = "The reminder '%s' hit an error and is off until next login. Please report: %s"
OPT_GENERAL = "General"
OPT_REMINDERS = "Reminders"
OPT_LOCK = "Lock panel position"
OPT_LOCK_TT = "When unlocked, drag the title bar to move the panel."
OPT_SCALE = "Panel scale"
OPT_SNOOZE = "Snooze length (minutes)"
OPT_COMBAT_STRIP = "Show compact strip in combat"
OPT_COMBAT_STRIP_TT = "In combat the panel shrinks to a row of icons. Turn this off to hide it in combat."
OPT_RESET_SNOOZE = "Reset snoozes"
OPT_RESET_POS = "Reset position"
OPT_BUTTON_DO = "Reset"
OPT_NOT_RELEVANT = "Not relevant for this character"
```

  Spanish for the same keys (`esES.lua`):

```
CHAT_PREFIX = "|cff7fd5ffNewbieNudge|r: "
PANEL_TITLE = "Recordatorios"
ROW_HINT_CLICK = "Clic izquierdo para ir allí."
ROW_HINT_SNOOZE = "Clic derecho: posponer %d minutos. Mayús+clic derecho: posponer hasta la próxima conexión."
ROW_STALE = "No se actualiza durante el combate."
MORE_ROWS = "…y %d más"
SLASH_HELP = "Comandos: /nudge (opciones), /nudge lock, /nudge list, /nudge on <nombre>, /nudge off <nombre>, /nudge reset, /nudge test"
SLASH_LIST_HEADER = "Recordatorios de este personaje:"
SLASH_LIST_LINE = "  %s (%s): %s"
STATE_ON = "activado"
STATE_OFF = "desactivado"
STATE_SNOOZED = "pospuesto"
STATE_NA = "no aplica a este personaje"
SLASH_UNKNOWN_RULE = "No hay ningún recordatorio llamado '%s'. Usa /nudge list."
SLASH_RULE_SET = "%s ahora está %s."
SLASH_RESET_DONE = "Posposiciones borradas."
SLASH_LOCKED = "Panel bloqueado."
SLASH_UNLOCKED = "Panel desbloqueado: arrastra la barra de título para moverlo. /nudge lock al terminar."
SLASH_TEST_ON = "Modo de prueba: se muestran todos los recordatorios con texto de ejemplo. /nudge reset para salir."
RULE_ERROR = "El recordatorio '%s' ha dado un error y queda desactivado hasta la próxima conexión. Por favor, infórmalo: %s"
OPT_GENERAL = "General"
OPT_REMINDERS = "Recordatorios"
OPT_LOCK = "Bloquear la posición del panel"
OPT_LOCK_TT = "Si está desbloqueado, arrastra la barra de título para mover el panel."
OPT_SCALE = "Escala del panel"
OPT_SNOOZE = "Duración de la posposición (minutos)"
OPT_COMBAT_STRIP = "Mostrar tira compacta en combate"
OPT_COMBAT_STRIP_TT = "En combate el panel se reduce a una fila de iconos. Desactívalo para ocultarlo en combate."
OPT_RESET_SNOOZE = "Borrar posposiciones"
OPT_RESET_POS = "Restablecer posición"
OPT_BUTTON_DO = "Restablecer"
OPT_NOT_RELEVANT = "No aplica a este personaje"
```

- [ ] **Step 1: Write `tests/test_locales.lua` and `tests/test_core_registry.lua`**

```lua
-- test_locales.lua
return {
  english_loads_by_default = function()
    load_addon(); assert_eq(NewbieNudge.L.PANEL_TITLE, "Reminders")
  end,
  spanish_loads_for_esES = function()
    WOW.state.locale = "esES"; load_addon(); assert_eq(NewbieNudge.L.PANEL_TITLE, "Recordatorios")
  end,
  esMX_gets_english = function()
    WOW.state.locale = "esMX"; load_addon(); assert_eq(NewbieNudge.L.PANEL_TITLE, "Reminders")
  end,
  missing_key_returns_key = function()
    WOW.state.locale = "esES"; load_addon(); assert_eq(NewbieNudge.L.NOT_A_KEY, "NOT_A_KEY")
  end,
}
-- test_core_registry.lua
local function rule(over) local r = { name="demo", title="T", help="H", events={}, applies=function() return true end, check=function() return nil end }; for k,v in pairs(over or {}) do r[k]=v end; return r end
return {
  register_stores_rule_with_defaults = function()
    load_addon(); NewbieNudge:RegisterRule(rule())
    local r = NewbieNudge.ruleByName.demo
    assert_true(r.default); assert_eq(r.combat, false); assert_eq(NewbieNudge.rules[#NewbieNudge.rules], r)
  end,
  register_rejects_duplicate_name = function()
    load_addon(); NewbieNudge:RegisterRule(rule())
    local ok, err = pcall(NewbieNudge.RegisterRule, NewbieNudge, rule())
    assert_true(not ok); assert_true(err:find("invalid rule demo: name"))
  end,
  register_rejects_bad_name = function()
    load_addon(); local ok = pcall(NewbieNudge.RegisterRule, NewbieNudge, rule({ name = "Bad Name" })); assert_true(not ok)
  end,
  plain_filters_secrets_and_types = function()
    load_addon()
    assert_eq(NewbieNudge.Plain(3), 3); assert_nil(NewbieNudge.Plain(WOW.secret(3))); assert_nil(NewbieNudge.Plain("x")); assert_eq(NewbieNudge.Plain("x", "string"), "x")
  end,
  db_gets_defaults_without_clobbering = function()
    _G.NewbieNudgeDB = { snoozeMinutes = 30 }; load_addon()
    assert_eq(NewbieNudge.db.snoozeMinutes, 30); assert_eq(NewbieNudge.db.panel.locked, true); assert_eq(NewbieNudge.db.combatStrip, true)
  end,
  say_uses_prefix = function()
    load_addon(); NewbieNudge:Say("hi"); assert_eq(WOW.printed[#WOW.printed], "|cff7fd5ffNewbieNudge|r: hi")
  end,
}
```

- [ ] **Step 2: Run to verify failure**

Run: `.venv/Scripts/python tests/run.py core_registry`
Expected: FAIL with `no TOC`.

- [ ] **Step 3: Write the TOC**

Header lines from Global Constraints plus `## Title: NewbieNudge`, `## Title-esES: NewbieNudge`, `## Notes: Reminders and highlights for new players: unspent talents, missing buffs, unused bags and more.`, `## Notes-esES: Recordatorios y avisos para jugadores nuevos: talentos sin gastar, buffs que faltan, bolsas sin usar y más.`, `## Version: 0.1.0`, `## IconTexture: Interface\Icons\INV_Misc_Note_01`, then file lines in the order from "File structure". List every file now, including ones later tasks create; `load_addon()` must skip a listed file that does not exist yet (helpers: `if not io.open(path) then skip`).

- [ ] **Step 4: Write both locale files and `Core.lua` to the interfaces above**

`enUS.lua`: `local _, NN = ...; NN.L = setmetatable({ ... }, { __index = function(_, k) return k end })`. `esES.lua`: `if GetLocale() ~= "esES" then return end` then `for k, v in pairs({...}) do NN.L[k] = v end`. `Core.lua`: creates `NN.rules`, `NN.ruleByName`, `NN.results = {}`, `NN.events = CreateFrame("Frame")`, registers `ADDON_LOADED` and `PLAYER_LOGIN`, builds `NN.db` with a recursive default fill (`NN.ApplyDefaults(tbl, defaults)`), sets `_G.NewbieNudge = NN`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `.venv/Scripts/python tests/run.py`
Expected: all pass, including `locales::parity`.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: TOC, locales and core registry"
```

---

### Task 3: Scheduler, gating, snoozes and error isolation

**Files:**
- Modify: `NewbieNudge/Core.lua`
- Test: `tests/test_core_scheduler.lua`

**Interfaces:**
- Consumes: Task 2 registry.
- Produces: on `PLAYER_LOGIN`, Core registers every event named by any rule's `events` (an entry of the form `"UNIT_AURA:player"` is registered with `RegisterUnitEvent(frame, "UNIT_AURA", "player")` and matched to rules by the part before the colon), and for every rule not yet in `db.seen.rules` sets `db.seen.rules[name] = true` and, when `rule.default == false`, `db.disabled[name] = true`.
- Produces: `NN:OnEvent(event, ...)` marks every rule listing `event` dirty and calls `NN:Schedule()`. `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_ENABLED` and `PLAYER_LEVEL_UP` mark all rules dirty; `PLAYER_LEVEL_UP`, `SPELLS_CHANGED` and `PLAYER_SPECIALIZATION_CHANGED` also clear `NN.appliesCache`. `NN:MarkDirty(name)` and `NN:MarkAllDirty()` set the dirty flags without scheduling.
- Produces: `NN.UNKNOWN` — a unique sentinel table. A `check()` that returns it means "could not read the game state"; the scheduler keeps the rule's previous results and clears the dirty flag. Rules return it whenever `NN.Plain` turns a needed value into nil.
- Produces: `NN:Schedule()` arms a single `C_Timer.After(0.5, NN.RunChecks)` if none is pending. `NN:RunChecks()` runs `check()` for every dirty, active rule allowed by gating, stores `NN.results[name]` (always an array: nil → `{}`, single result → `{result}`), clears dirty flags, then calls `NN.Panel:Refresh(NN:ActiveRows())` and `NN.Highlight:Apply(NN:ActiveRows())` when those modules exist.
- Produces: `NN:IsRestricted()` → `InCombatLockdown()` or `select(2, IsInInstance())` in `{"party","raid","pvp","arena"}` or (`C_RestrictedActions` exists and any of its `IsCombatRestricted/IsEncounterRestricted/IsMapRestricted` functions that exist return true).
- Produces: `NN:IsRuleActive(rule)` → not `db.disabled[name]`, `NN:Applies(rule)` (cached per rule in `NN.appliesCache`), and not snoozed (`db.snoozed[name]` is nil, or `> 0` and `<= GetTime()` in which case it is cleared).
- Produces: `NN:Snooze(name, minutes)` → `db.snoozed[name] = minutes == 0 and 0 or GetTime() + minutes*60`; `NN:ClearSnoozes()`; `NN:SetRuleEnabled(name, bool)`; all three mark the rule dirty and schedule.
- Produces: `NN:ActiveRows()` → array of `{ rule = rule, result = result, stale = bool }` for every active rule's results, ordered by `NN.PRIORITY = { "durability", "bag_unequipped", "bag_full", "talents", "spell_ranks", "buffs", "ammo", "pet", "tracking", "hearthstone", "quests", "mail", "professions", "gear_upgrade", "rested" }` then registration order for names not listed. `stale` is true when `NN:IsRestricted()` and `rule.combat` is false.
- Produces: `NN.ruleState[name] = { disabled = bool, dirty = bool, frozen = bool }`. A `check()` that errors sets `disabled`, stores `db.errors[name] = message`, removes results, and prints `RULE_ERROR` once. A `check()` whose result contains any secret value (`NN.HasSecret(result)` walks text/icon) is discarded and the previous results stay.
- Produces: a periodic ticker `C_Timer.NewTicker(30, function() NN:MarkAllDirty(); NN:Schedule() end)` so expired snoozes and time-based conditions resurface.
- Produces: `NN.testMode` (bool). While true, `RunChecks` fills `NN.results[name]` from `rule.sample()` if present, else `{ { text = rule.title, icon = 134400 } }`.

- [ ] **Step 1: Write `tests/test_core_scheduler.lua`**

Use a helper `fakeRule(name, opts)` registering a rule with a counter `calls`, `events = {"TEST_EVENT"}`, and a `check` that returns `opts.result` (a table or function). Tests:

```lua
event_marks_dirty_and_runs_after_half_second: register; FireEvent("TEST_EVENT"); assert calls==0; AdvanceTime(0.5); assert calls==1; results_of("a")[1].text == "x"
two_events_coalesce_into_one_run: fire twice; AdvanceTime(0.5); calls == 1
nil_result_gives_empty_array: check returns nil; after run #results_of("a") == 0
single_result_is_wrapped: check returns {text="x"}; #results_of("a") == 1
non_combat_rule_frozen_in_combat: result "x"; run; state.inCombat=true; result changes to "y"; fire; advance; results_of("a")[1].text == "x"; ActiveRows()[1].stale == true
combat_rule_updates_in_combat: combat=true; same scenario → text "y", stale false
regen_enabled_rechecks_everything: after combat, FireEvent("PLAYER_REGEN_ENABLED"); advance; text "y"
secret_in_result_keeps_previous: result "x"; run; then result { text = WOW.secret("y") }; fire; advance; text still "x"
unknown_sentinel_keeps_previous: result "x"; run; then check returns NewbieNudge.UNKNOWN; fire; advance; text still "x"; ruleState.a.dirty == false
default_false_rule_is_disabled_on_first_login: register rule with default=false before PLAYER_LOGIN (register inside a test-only file loaded by load_addon via a `WOW.extraFiles` list); after load db.disabled.a == true and db.seen.rules.a == true; set NewbieNudgeDB = { seen = { rules = { a = true } } } and load again → db.disabled.a == nil
erroring_rule_is_disabled_once: check errors; fire; advance; #results==0; ruleState.a.disabled; WOW.printed last contains "hit an error"; db.errors.a contains the message; fire again; advance; calls did not increase; #WOW.printed unchanged
snooze_hides_then_expires: Snooze("a", 60); advance 0.5; #ActiveRows()==0; state.time += 3601; AdvanceTime(30); #ActiveRows()==1
snooze_until_login_clears_on_login: Snooze("a", 0); load_addon() again (fresh runtime in test: set NewbieNudgeDB.snoozed.a = 0 before load); after load db.snoozed.a == nil
disabled_rule_not_checked: SetRuleEnabled("a", false); fire; advance; calls == 0
applies_false_rule_not_checked_until_level_up: applies returns state.level >= 10 with level 5; fire; advance; calls==0; state.level=10; FireEvent("PLAYER_LEVEL_UP"); advance; calls==1
priority_orders_rows: register "mail" then "durability" each with a result; ActiveRows()[1].rule.name == "durability"
test_mode_uses_sample: rule with sample() returning {{text="S"}}; NewbieNudge.testMode=true; MarkAllDirty; Schedule; advance; results_of("a")[1].text=="S"
```

- [ ] **Step 2: Run to verify failure** — `.venv/Scripts/python tests/run.py core_scheduler` → FAIL (`OnEvent` does nothing).

- [ ] **Step 3: Implement the interfaces above in `Core.lua`**

`RunChecks` loop: for each rule in `NN.rules`: skip if not dirty, or `ruleState.disabled`, or not `IsRuleActive`; if `IsRestricted()` and not `rule.combat` then leave dirty and continue; `local ok, res = pcall(rule.check)`; handle error, secret, normalise; clear dirty.

- [ ] **Step 4: Run tests** — `.venv/Scripts/python tests/run.py` → all pass.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: check scheduler with combat gating, snoozes and error isolation"`

---

### Task 4: Slash command

**Files:**
- Modify: `NewbieNudge/Core.lua`
- Test: `tests/test_slash.lua`

**Interfaces:**
- Consumes: Task 3 (`Snooze`, `ClearSnoozes`, `SetRuleEnabled`, `testMode`, `IsRuleActive`, `Applies`).
- Produces: `SLASH_NEWBIENUDGE1 = "/nudge"`, `SlashCmdList.NEWBIENUDGE = function(msg) NN:HandleSlash(msg) end`. `NN:HandleSlash(msg)`: trims and lowercases the first word; `""` → `NN:OpenOptions()` (defined in Task 7; until then a no-op field check `if NN.OpenOptions`); `lock` → toggles `db.panel.locked`, prints `SLASH_LOCKED`/`SLASH_UNLOCKED`, calls `NN.Panel:SetLocked(locked)` if the panel exists; `list` → prints header then one `SLASH_LIST_LINE` per rule with title, name and state (`STATE_OFF` if disabled, `STATE_NA` if not applies, `STATE_SNOOZED` if snoozed, else `STATE_ON`); `on <name>`/`off <name>` → `SLASH_UNKNOWN_RULE` or `SetRuleEnabled` + `SLASH_RULE_SET` with title and `STATE_ON/OFF`; `reset` → `ClearSnoozes()`, `testMode = false`, `MarkAllDirty`, `Schedule`, prints `SLASH_RESET_DONE`; `test` → `testMode = true`, mark all dirty, schedule, print `SLASH_TEST_ON`; anything else → `SLASH_HELP`.

- [ ] **Step 1: Write `tests/test_slash.lua`** with one test per branch above, each asserting on `WOW.printed` and on the state change (for example `off_disables_rule` asserts `db.disabled.a == true` and the printed line equals `string.format(L.SLASH_RULE_SET, "T", L.STATE_OFF)`), plus `list_shows_na_for_non_applying_rule`.

- [ ] **Step 2: Run to verify failure.** **Step 3: Implement.** **Step 4: Run tests, all pass.**

- [ ] **Step 5: Commit** — `git commit -am "feat: /nudge slash command"`

---

### Task 5: Spellbook cache

**Files:**
- Create: `NewbieNudge/Spellbook.lua`
- Test: `tests/test_spellbook.lua`

**Interfaces:**
- Produces: `NN.Spellbook` with `Refresh()` (rebuilds from `C_SpellBook.GetNumSpellBookSkillLines`, `GetSpellBookSkillLineInfo(i)` → `{name, itemIndexOffset, numSpellBookItems, offSpecID}`, `GetSpellBookItemType(slot, Enum.SpellBookSpellBank.Player)`, `IsSpellBookItemPassive`, `IsSpellBookItemLowRank`, `GetSpellBookItemInfo(slot, bank)` → `{spellID, name}`), `TopRankByName(name)` → spellID or nil, `Knows(spellID)` → true when `C_Spell.GetSpellName(spellID)` is a key in the map, `KnowsAny(ids)`, `IsLowRank(spellID)` → `C_SpellBook.IsSpellBookItemLowRank(C_SpellBook.FindSpellBookSlotForSpell(spellID))` guarded, `ActionSlotsForName(name)` → array of action slots 1–180 whose `GetActionInfo` is a `"spell"` with that name (any rank), `Invalidate()`. The map rebuilds lazily on first use after `Invalidate()`; Core calls `Invalidate()` on `SPELLS_CHANGED`, `LEARNED_SPELL_IN_SKILL_LINE`, `PLAYER_ENTERING_WORLD`.
- Stub additions: `C_SpellBook.*` listed above reading `state.spellBook`; `C_Spell.GetSpellName(id)`, `C_Spell.GetSpellInfo(id)` (`{name, iconID, spellID}`), `C_Spell.GetSpellSubtext(id)`, `C_Spell.GetSpellTexture(id)` reading `state.spellInfo`; `C_SpellBook.FindSpellBookSlotForSpell(id)` returns the slot whose `spellID` matches and `0`; `GetActionInfo(slot)` returns `state.actions[slot].type, state.actions[slot].id` or nil.

- [ ] **Step 1: Tests**: `top_rank_by_name_skips_low_ranks_and_passives` (two Fireball items, slot 1 lowRank, slot 2 not → TopRankByName("Fireball") == id of slot 2), `knows_by_name_matches_other_rank` (spellInfo[133] = Fireball rank 1 not in book, slot has 143 Fireball → Knows(133) true), `offspec_lines_ignored`, `invalidate_rebuilds_after_spells_changed` (add a spell, no change until `FireEvent("SPELLS_CHANGED")`), `is_low_rank_guarded_when_spell_not_in_book` (returns false), `action_slots_for_name_finds_every_rank` (actions 2 and 14 hold 133 and 143 → `{2, 14}`).
- [ ] **Step 2: Run, fail.** **Step 3: Implement.** **Step 4: Run, pass.**
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: spellbook name cache"`

---

### Task 6: Highlight module

**Files:**
- Create: `NewbieNudge/Highlight.lua`
- Test: `tests/test_highlight.lua`

**Interfaces:**
- Produces: `NN.Highlight:Apply(rows)` computes the set of wanted targets from each `row.result.highlight` (string key, or `{ action = {slots} }`); stale rows count the same as fresh ones, so glows freeze in combat along with their rows; shows a glow on newly wanted targets and hides it on targets no longer wanted. `NN.Highlight:ClearAll()`.
- Key → frame resolution (lazy, each attempt re-tried every `Apply` until found): `bags → MainMenuBarBackpackButton`; `talents → TalentMicroButton or PlayerSpellsMicroButton`; `spellbook → SpellbookMicroButton or PlayerSpellsMicroButton`; `character → CharacterMicroButton`; `quests → QuestLogMicroButton`; `tracking → MinimapCluster.Tracking.Button or MinimapCluster.TrackingFrame.Button or MiniMapTrackingButton`; `mail → MinimapCluster.IndicatorFrame.MailFrame or MiniMapMailFrame`.
- Action slot → button: `NN.Highlight:ButtonForSlot(slot)` walks `ActionButton1..12`, `MultiBarBottomLeftButton1..12`, `MultiBarBottomRightButton1..12`, `MultiBarRightButton1..12`, `MultiBarLeftButton1..12`, `MultiBar5Button1..12`, `MultiBar6Button1..12`, `MultiBar7Button1..12` and returns the first whose `button.action == slot`; cache cleared on `ACTIONBAR_SLOT_CHANGED`, `ACTIONBAR_PAGE_CHANGED`, `UPDATE_BONUS_ACTIONBAR`.
- Glow: `NN.Highlight:Show(frame)` uses `ActionButton_ShowOverlayGlow(frame)` when that global exists, else creates once `frame.NewbieNudgeGlow` (a texture `Interface\Buttons\UI-ActionButton-Border`, blend `ADD`, vertex colour 1, 0.85, 0.2, sized 1.6× the frame, centred) with an alpha pulse driven by `C_Timer.NewTicker(0.05)` between 0.3 and 1.0 over a 1 s cycle. `Hide(frame)` mirrors it.
- Stub additions: `ActionButton_ShowOverlayGlow`/`HideOverlayGlow` recorders writing `{"glow_show", frame}` / `{"glow_hide", frame}` into `WOW.calls`; globals `MainMenuBarBackpackButton`, `PlayerSpellsMicroButton`, `CharacterMicroButton`, `QuestLogMicroButton` as frames; `ActionButton1..12` frames with `.action = slot`.

- [ ] **Step 1: Tests**: `key_target_glows_and_clears` (Apply with bags row → calls contain glow_show on backpack; Apply with {} → glow_hide), `missing_frame_is_ignored` (key tracking with no frame → no error, no call), `talents_falls_back_to_player_spells_button`, `action_slot_resolves_to_button` (slot 3 → glow_show ActionButton3), `stale_rows_keep_their_glow`, `fallback_pulse_when_no_blizzard_glow` (`_G.ActionButton_ShowOverlayGlow = nil` → frame.NewbieNudgeGlow exists and is shown).
- [ ] **Step 2: Run, fail.** **Step 3: Implement.** **Step 4: Run, pass.**
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: highlight glows for default buttons and action slots"`

---

### Task 7: Panel and combat strip

**Files:**
- Create: `NewbieNudge/Panel.lua`
- Modify: `NewbieNudge/Core.lua` (call `NN.Panel:SetCombatMode(true/false)` on `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED`)
- Test: `tests/test_panel.lua`

**Interfaces:**
- Consumes: `NN:ActiveRows()`, `NN:Snooze`, `NN.db.panel`, `NN.db.combatStrip`, `NN.db.snoozeMinutes`, `NN.L`.
- Produces: `NN.Panel` with frame `NewbieNudgePanel` (named, so `/framestack` finds it), `Refresh(rows)`, `SetCombatMode(bool)`, `SetLocked(bool)`, `ApplyScale()`, `ResetPosition()`, `SavePosition()`, `rows` (array of row frames, pooled), `strip` (child frame with pooled 24 px icon buttons).
- Behaviour: width 260; title bar 18 px tall visible only when unlocked; one row per entry up to `NN.MAX_ROWS = 10`, then a final text-only row `MORE_ROWS` with the overflow count; row = 20 px icon + font string `GameFontHighlightSmall` wrapping to 2 lines, height 24 or 36; panel height = sum + 8; `Hide()` when `#rows == 0` and not in test mode; `Show()` otherwise. Row `OnEnter` tooltip: title line = `row.rule.title`, then `row.rule.help`, then `ROW_HINT_CLICK` if `result.onClick`, then `ROW_HINT_SNOOZE` formatted with `db.snoozeMinutes`, then `ROW_STALE` in grey if `row.stale`. Row `OnClick`: `LeftButton` → `pcall(result.onClick)` if present; `RightButton` with `IsShiftKeyDown()` → `NN:Snooze(name, 0)`, else `NN:Snooze(name, db.snoozeMinutes)`. Stale rows have alpha 0.5.
- Combat mode: `SetCombatMode(true)` hides the row list and shows `strip` (one icon per row, same order, stale icons at 0.5 alpha, tooltip as above) unless `db.combatStrip == false` in which case the whole panel hides; icons newly present since the last strip refresh pulse (alpha 1→0.3→1 three times over 1.5 s via `C_Timer.NewTicker`). `SetCombatMode(false)` restores the list and calls `Refresh(NN:ActiveRows())`.
- Position: `db.panel.point/x/y` applied on load relative to `UIParent`; `OnDragStop` saves them. `ApplyScale()` sets `db.panel.scale`.
- Stub additions: `IsShiftKeyDown()` reading `state.shiftDown`; frames must support `GetScript("OnClick")(frame, "RightButton")` being called by tests; `WOW.Click(frame, button)` helper.

- [ ] **Step 1: Tests**: `hidden_when_no_rows`, `shows_one_row_per_result_in_order` (row_texts() equals the result texts), `overflow_row_after_ten`, `left_click_runs_onclick` (calls recorder), `right_click_snoozes_for_db_minutes` (db.snoozed.a ≈ time + 3600), `shift_right_click_snoozes_until_login` (== 0), `stale_rows_are_half_alpha`, `combat_mode_shows_strip_with_same_count`, `combat_mode_hides_when_strip_disabled`, `leaving_combat_restores_rows`, `drag_stop_saves_position`, `locked_hides_title_bar`.
- [ ] **Step 2: Run, fail.** **Step 3: Implement.** **Step 4: Run, pass.**
- [ ] **Step 5: Deferred in-game check** (added to `docs/testing-checklist.md` in Task 18): `/nudge test` shows rows; `/nudge lock` twice; drag; `/reload` keeps position; `/console addonCombatRestrictionsForced 1` then `/nudge test` shows the strip.
- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat: reminder panel with compact combat strip"`

---

### Task 8: Options window

**Files:**
- Create: `NewbieNudge/Options.lua`
- Test: `tests/test_options.lua`

**Interfaces:**
- Consumes: `NN.rules`, `NN.db`, `NN:SetRuleEnabled`, `NN:ClearSnoozes`, `NN.Panel:SetLocked/ApplyScale/ResetPosition`, `NN:Applies`.
- Produces: `NN:OpenOptions()` → `Settings.OpenToCategory(NN.optionsCategoryID)`. Built on `PLAYER_LOGIN` after all rules registered: `local category, layout = Settings.RegisterVerticalLayoutCategory(L.ADDON_TITLE)`; header `OPT_GENERAL`; checkbox `OPT_LOCK` bound to `db.panel.locked` (on change → `Panel:SetLocked`); slider `OPT_SCALE` 0.8–1.5 step 0.1 bound to `db.panel.scale` (→ `ApplyScale`); slider `OPT_SNOOZE` 15–240 step 15 bound to `db.snoozeMinutes`; checkbox `OPT_COMBAT_STRIP` bound to `db.combatStrip`; two buttons via `CreateSettingsButtonInitializer(OPT_RESET_SNOOZE, OPT_BUTTON_DO, fn)` and `(OPT_RESET_POS, OPT_BUTTON_DO, fn)`; header `OPT_REMINDERS`; one checkbox per rule in `NN.rules` order, name `rule.title`, tooltip `rule.help` (plus `OPT_NOT_RELEVANT` on a second line when `not NN:Applies(rule)`), bound to a proxy so that reading gives `not db.disabled[name]` and writing calls `SetRuleEnabled`. Settings created with `Settings.RegisterProxySetting(category, "NN_" .. key, type, name, default, getter, setter)` when that function exists, else `Settings.RegisterAddOnSetting(category, "NN_" .. key, key, proxyTable, type, name, default)`; then `Settings.CreateCheckbox(category, setting, tooltip)` / `Settings.CreateSlider(category, setting, Settings.CreateSliderOptions(min, max, step), tooltip)`; finally `Settings.RegisterAddOnCategory(category)` and `NN.optionsCategoryID = category:GetID()`.
- Locale additions (both files): `ADDON_TITLE = "NewbieNudge"` (same in Spanish).
- Stub additions: a `Settings` table that records every call into `WOW.calls` and returns `category` objects with `GetID()`, and whose `RegisterProxySetting` stores getter/setter so tests can call them through `WOW.settings[variable]`.

- [ ] **Step 1: Tests**: `registers_category_and_addon_category`, `one_checkbox_per_rule_in_order`, `rule_checkbox_setter_disables_rule` (call stored setter(false) → db.disabled.a), `scale_slider_range_is_0_8_to_1_5`, `open_options_calls_open_to_category`.
- [ ] **Step 2: Run, fail.** **Step 3: Implement.** **Step 4: Run, pass.**
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: settings panel"`

---

### Task 9: Bag rules

**Files:**
- Create: `NewbieNudge/Rules/Bags.lua`
- Test: `tests/test_rules_bags.lua`

**Interfaces:**
- Consumes: `NN:RegisterRule`, `NN.Plain`, `NN.L`.
- Produces rules `bag_unequipped` (combat) and `bag_full` (combat).
- Locale keys, English / Spanish:
  `BAG_UNEQUIPPED_TITLE = "Unused bag" / "Bolsa sin usar"`, `BAG_UNEQUIPPED_HELP = "Bags give you more room for loot. Open your bags and drag the bag onto an empty bag slot next to your backpack." / "Las bolsas te dan más espacio para el botín. Abre tus bolsas y arrastra la bolsa a un hueco vacío junto a tu mochila."`, `BAG_UNEQUIPPED_ROW_EMPTY = "You have a bag in your inventory that isn't equipped." / "Tienes una bolsa en el inventario que no está equipada."`, `BAG_UNEQUIPPED_ROW_BIGGER = "A bag in your inventory is bigger than one you're using." / "Una bolsa de tu inventario es más grande que una de las que usas."`, `BAG_FULL_TITLE = "Bags nearly full" / "Bolsas casi llenas"`, `BAG_FULL_HELP = "Sell grey items to any vendor, or get bigger bags." / "Vende los objetos grises a cualquier vendedor o consigue bolsas más grandes."`, `BAG_FULL_ROW = "Your bags are almost full (%d slots left)." / "Tus bolsas están casi llenas (quedan %d huecos)."`.
- Shared helper in the file: `local function ContainerSlots(bag, slot, itemID)` → number of slots of a bag item: `C_TooltipInfo.GetBagItem(bag, slot)` lines matched against a pattern built from `CONTAINER_SLOTS` (take the text before the first `|4`, escape it, replace `%d` with `(%d+)`); nil when the tooltip API is missing or no line matches.
- `bag_unequipped.check`: if `C_Container.GetContainerItemInfo(0, 1)` style probing shows bags not loaded (`NN.bagsLoaded` flag set by Core on first `BAG_UPDATE_DELAYED`), return nil. Walk bags 0–4; for each item whose `C_Item.GetItemInfoInstant(itemID)` classID == `Enum.ItemClass.Container` and whose `C_Item.GetItemFamily(itemID)` is 0 (or non-zero only when `UnitUsesAmmo and UnitUsesAmmo("player")`): if any of inventory slots 20–23 has `GetInventoryItemID("player", slot) == nil` → `ROW_EMPTY`; else if `ContainerSlots(...)` > min over bags 1–4 of `C_Container.GetContainerNumSlots(bag)` → `ROW_BIGGER`. One result at most, icon 133634, `onClick = ToggleAllBags`, `highlight = "bags"`.
- `bag_full.check`: `free = sum over bags 0–4 of (C_Container.GetContainerNumFreeSlots(bag))` counting only bags whose second return (family) is 0; result when `free < 3`: `BAG_FULL_ROW:format(free)`, icon 133634, `onClick = ToggleAllBags`, `highlight = "bags"`.
- `applies` for both: always true. `events`: `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`.
- Core addition: `NN.bagsLoaded = true` on first `BAG_UPDATE_DELAYED`.
- Stub additions: `C_Container.GetContainerNumSlots`, `GetContainerNumFreeSlots` (returns free, family), `GetContainerItemInfo` (`{itemID, hyperlink, stackCount}`), `GetContainerItemID`, `ContainerIDToInventoryID(bag) = 19 + bag`; `C_Item.GetItemInfoInstant`, `C_Item.GetItemFamily`, `GetInventoryItemID`; `C_TooltipInfo.GetBagItem` producing `{ lines = { { leftText = string.format("%d Slot Bag", numSlots) } } }` from `itemInfo.numSlots`; `ToggleAllBags` recorder; `UnitUsesAmmo` reading `state.usesAmmo`.

- [ ] **Step 1: Tests**: `nothing_before_bags_loaded` (Review Focus 1: no `BAG_UPDATE_DELAYED` fired → `results_of("bag_unequipped")` empty even with a bag in inventory; helper `load_addon()` must therefore not fire it by default — add a `WOW.LoadBags()` helper that fires it), `bag_in_inventory_with_empty_slot`, `bigger_bag_than_smallest_equipped` (equipped 6-slot, inventory 10-slot → ROW_BIGGER), `smaller_bag_is_fine`, `quiver_ignored_for_non_ammo_user`, `bag_full_below_three_free` (free 2 → text "(2 slots left)"), `bag_full_ignores_quiver_family`, `bag_full_ok_at_three`.
- [ ] **Step 2: Run, fail.** **Step 3: Implement.** **Step 4: Run, pass.**
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: bag rules"`

---

### Task 10: Simple rules — durability, hearthstone, mail, quests

**Files:**
- Create: `NewbieNudge/Rules/Simple.lua`
- Test: `tests/test_rules_simple.lua`

**Interfaces:**
- Locale keys (English / Spanish):
  `DURABILITY_TITLE = "Damaged gear" / "Equipo dañado"`, `DURABILITY_HELP = "Damaged gear is weaker and broken gear does nothing. Any vendor with an anvil icon repairs it." / "El equipo dañado es más débil y el roto no sirve. Cualquier vendedor con un icono de yunque lo repara."`, `DURABILITY_ROW_LOW = "Some of your gear is below 20% durability." / "Parte de tu equipo tiene menos del 20% de durabilidad."`, `DURABILITY_ROW_BROKEN = "You have broken gear; repair it at a vendor." / "Tienes equipo roto; repáralo en un vendedor."`,
  `HEARTHSTONE_TITLE = "Hearthstone" / "Piedra de hogar"`, `HEARTHSTONE_HELP = "Your Hearthstone teleports you to the inn you set as home. If you lost it, talk to any innkeeper." / "La Piedra de hogar te teletransporta a la posada que fijaste como hogar. Si la perdiste, habla con cualquier posadero."`, `HEARTHSTONE_ROW = "You have no Hearthstone. Any innkeeper gives you one for free." / "No tienes Piedra de hogar. Cualquier posadero te da una gratis."`,
  `MAIL_TITLE = "Mail" / "Correo"`, `MAIL_HELP = "Mail can hold items and gold. Mailboxes are near inns and banks." / "El correo puede contener objetos y oro. Los buzones están cerca de posadas y bancos."`, `MAIL_ROW = "You have new mail waiting at a mailbox." / "Tienes correo nuevo esperando en un buzón."`,
  `QUESTS_TITLE = "Quest log" / "Registro de misiones"`, `QUESTS_HELP = "You can only hold a limited number of quests. Finish or abandon some before taking more." / "Solo puedes llevar un número limitado de misiones. Termina o abandona algunas antes de aceptar más."`, `QUESTS_ROW = "Your quest log is almost full (%d of %d)." / "Tu registro de misiones está casi lleno (%d de %d)."`.
- `durability` (combat): slots 1–17 via `GetInventoryItemDurability(slot)`; each of `cur`, `max` goes through `NN.Plain`; a slot that returns values that are not plain numbers (secret) makes the rule return `NN.UNKNOWN`; broken if any `cur == 0` with `max > 0`; low if any `cur/max < 0.20`; one result, broken text wins; icon 136241; `onClick = function() ToggleCharacter("PaperDollFrame") end`; highlight `character`; events `UPDATE_INVENTORY_DURABILITY`, `PLAYER_EQUIPMENT_CHANGED`.
- `hearthstone` (combat): nil until `NN.bagsLoaded`; result when `C_Item.GetItemCount(6948) == 0` (fallback global `GetItemCount`); icon 134414; no click, no highlight; events `BAG_UPDATE_DELAYED`.
- `mail` (combat): `HasNewMail()`; icon 133469; highlight `mail`; events `UPDATE_PENDING_MAIL`, `MAIL_INBOX_UPDATE`, `MAIL_CLOSED`, `PLAYER_ENTERING_WORLD`.
- `quests`: `local _, num = C_QuestLog.GetNumQuestLogEntries()`; `max = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept() or 25`; result when `num >= max - 3`; icon 136797; `onClick = ToggleQuestLog`; highlight `quests`; events `QUEST_LOG_UPDATE`, `QUEST_ACCEPTED`, `QUEST_REMOVED`.
- Stub additions: `GetInventoryItemDurability`, `C_Item.GetItemCount` (`state.itemCounts`), `HasNewMail`, `C_QuestLog.GetNumQuestLogEntries` (returns `num + 2, num`), `C_QuestLog.GetMaxNumQuestsCanAccept`, `ToggleCharacter`, `ToggleQuestLog` recorders.

- [ ] **Step 1: Tests**: `durability_low_at_19_percent`, `durability_ok_at_20_percent`, `durability_broken_wins_over_low`, `durability_secret_value_keeps_previous` (Review Focus 2: first run low → then `durability = {WOW.secret(1), 100}` and `state.inCombat = true` → previous row stays, and `WOW.printed` gained no error line), `hearthstone_silent_before_bags_loaded` (Review Focus 1), `hearthstone_missing_after_bags_loaded`, `hearthstone_present_is_fine`, `mail_row_when_new_mail`, `quests_row_at_22_of_25`, `quests_ok_at_21`, `quests_uses_max_from_api` (max 20 → row at 17).
- [ ] **Step 2: Run, fail.** **Step 3: Implement.** **Step 4: Run, pass.**
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: durability, hearthstone, mail and quest log rules"`

---

### Task 11: Talents rule

**Files:**
- Create: `NewbieNudge/Rules/Talents.lua`
- Test: `tests/test_rules_talents.lua`

**Interfaces:**
- Locale keys: `TALENTS_TITLE = "Unspent talents" / "Talentos sin gastar"`, `TALENTS_HELP = "Talent points make your character stronger. Open the talent window and spend them." / "Los puntos de talento hacen más fuerte a tu personaje. Abre la ventana de talentos y gástalos."`, `TALENTS_ROW_ONE = "You have 1 unspent talent point." / "Tienes 1 punto de talento sin gastar."`, `TALENTS_ROW_MANY = "You have %d unspent talent points." / "Tienes %d puntos de talento sin gastar."`.
- `applies`: `UnitLevel("player") >= 10`. `check`: `configID = C_ClassTalents.GetActiveConfigID()`; `info = C_Traits.GetConfigInfo(configID)`; `treeID = info.treeIDs[1]`; `currency = C_Traits.GetTreeCurrencyInfo(configID, treeID, false)[1]`; `n = NN.Plain(currency.quantity)`; result when `n > 0` with `ROW_ONE` or `ROW_MANY`, icon 136116, `onClick = function() if ToggleTalentFrame then ToggleTalentFrame() elseif PlayerSpellsUtil then PlayerSpellsUtil.ToggleClassTalentFrame() end end`, highlight `talents`; any nil along the chain → nil. Events: `TRAIT_TREE_CURRENCY_INFO_UPDATED`, `TRAIT_CONFIG_UPDATED`, `PLAYER_TALENT_UPDATE`, `PLAYER_LEVEL_UP`.
- Stub additions: `C_ClassTalents.GetActiveConfigID`, `C_Traits.GetConfigInfo` (`{ treeIDs = { state.talents.treeID } }`), `C_Traits.GetTreeCurrencyInfo` (`{ { quantity = state.talents.unspent } }`), `ToggleTalentFrame` recorder.

- [ ] **Step 1: Tests**: `not_applicable_below_10`, `one_point_text`, `many_points_text`, `zero_points_nothing`, `missing_config_is_silent` (`GetActiveConfigID` returns nil).
- [ ] **Step 2: Run, fail.** **Step 3: Implement.** **Step 4: Run, pass.**
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: unspent talents rule"`

---

### Task 12: Buff data and buffs rule

**Files:**
- Create: `NewbieNudge/Data_Buffs.lua`, `NewbieNudge/Rules/Buffs.lua`
- Test: `tests/test_rules_buffs.lua`

**Interfaces:**
- Produces `NN.BuffData` keyed by class file. A group is `{ ids = { ... }, weapon = bool }`. Exact contents:

```lua
MAGE    = { { ids = { 1459 } },                                   -- Arcane Intellect
            { ids = { 168, 7302, 6117 } } },                      -- Frost Armor / Ice Armor / Mage Armor
PRIEST  = { { ids = { 1243 } }, { ids = { 588 } }, { ids = { 14752 } } }, -- PW:Fortitude, Inner Fire, Divine Spirit
DRUID   = { { ids = { 1126 } }, { ids = { 467 } }, { ids = { 16864 } } }, -- Mark of the Wild, Thorns, Omen of Clarity
WARLOCK = { { ids = { 687, 706 } } },                             -- Demon Skin / Demon Armor
SHAMAN  = { { ids = { 324, 24398 } },                             -- Lightning Shield / Water Shield
            { ids = { 8017, 8024, 8033, 8232 }, weapon = true } }, -- Rockbiter / Flametongue / Frostbrand / Windfury
PALADIN = { { ids = { 19740, 19742, 20217, 20911, 19977, 1038 } }, -- Blessings on self
            { ids = { 465, 7294, 19746, 19876, 19888, 19891, 20218 } } }, -- Auras
HUNTER  = { { ids = { 13163, 13165, 5118, 13161, 13159, 20043 } }, -- Aspects
            { ids = { 19506 } } },                                 -- Trueshot Aura
ROGUE   = { { ids = { 8679, 2823, 3408, 5761, 13219 }, weapon = true } }, -- Poisons
```

- Locale keys: `BUFFS_TITLE = "Missing buffs" / "Buffs que faltan"`, `BUFFS_HELP = "These buffs last a long time and make a real difference. Recast them when they fall off; the glowing button on your bar is the one to press." / "Estos buffs duran mucho y marcan la diferencia. Vuelve a lanzarlos cuando se acaben; el botón que brilla en tu barra es el que debes pulsar."`, `BUFFS_ROW = "Buff missing: %s" / "Falta el buff: %s"`, `BUFFS_ROW_NOT_ON_BAR = "Buff missing: %s (not on your action bar)" / "Falta el buff: %s (no está en tu barra de acción)"`, `BUFFS_ROW_WEAPON = "Weapon enhancement missing: %s" / "Falta la mejora de arma: %s"`.
- `applies`: `NN.BuffData[NN.classFile] ~= nil`. `check`: for each group, `known = NN.Spellbook:KnowsAny(group.ids)`; skip unknown groups. Satisfied when, for a normal group, any id has `C_UnitAuras.GetPlayerAuraBySpellID(id)` non-nil or `C_UnitAuras.GetAuraDataBySpellName("player", C_Spell.GetSpellName(id), "HELPFUL")` non-nil; for a weapon group, `NN.MainHandEnchanted()` (helper in this file: `local f = C_Item and C_Item.GetWeaponEnchantInfo or GetWeaponEnchantInfo; local r = f(); if type(r) == "table" then return r.hasMainHandEnchant end; return r`). For each unsatisfied group build a result: display name = `C_Spell.GetSpellName(NN.Spellbook:TopRankByName(name of first known id) or first known id)`; slots = `NN.Spellbook:ActionSlotsForName(name)`; if `#slots > 0` → `BUFFS_ROW`, `highlight = { action = slots }`, no `onClick`; else → `BUFFS_ROW_NOT_ON_BAR`, `highlight = "spellbook"`, `onClick = function() if ToggleSpellBook then ToggleSpellBook("spell") elseif PlayerSpellsUtil then PlayerSpellsUtil.ToggleSpellBookFrame() end end`; weapon groups use `BUFFS_ROW_WEAPON`. Icon = `C_Spell.GetSpellTexture(id)`. Cap: first 3 results, then one result `MORE_ROWS:format(n - 3)` with icon 134400. Events: `"UNIT_AURA:player"`, `SPELLS_CHANGED`, `PLAYER_ENTERING_WORLD`, `ACTIONBAR_SLOT_CHANGED`.
- `sample()`: `{ { text = L.BUFFS_ROW:format("Arcane Intellect"), icon = 135932 } }`.
- Stub additions: `C_UnitAuras.GetPlayerAuraBySpellID` (`state.auras[id]`), `GetAuraDataBySpellName` (`state.auras[name]`), `GetWeaponEnchantInfo` global returning `state.weaponEnchant.main, 0, 0, 0, state.weaponEnchant.off`, `ToggleSpellBook` recorder, `RegisterUnitEvent` on frames (treated as `RegisterEvent`).

- [ ] **Step 1: Tests** (class MAGE, spellbook knows Arcane Intellect 1459 named "Arcane Intellect" and Frost Armor 168): `missing_buff_row_with_action_glow` (actions[5] = spell 1459, no aura → text "Buff missing: Arcane Intellect", highlight.action == {5}), `missing_buff_not_on_bar_uses_spellbook_highlight`, `aura_by_higher_rank_name_satisfies` (auras["Arcane Intellect"] = true), `unknown_group_skipped` (spellbook without Frost Armor → only one row), `armor_group_any_of` (aura 7302 satisfies the armor group), `weapon_group_uses_enchant` (class SHAMAN, knows 8017, main=false → row BUFFS_ROW_WEAPON; main=true → none), `warrior_not_applicable`, `more_than_three_collapses` (in the test set `NewbieNudge.BuffData.MAGE` to four groups with one known, inactive spell each → 3 rows plus a fourth whose text is `MORE_ROWS:format(1)`).
- [ ] **Step 2: Run, fail.** **Step 3: Implement.** **Step 4: Run, pass.**
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: missing self-buff rule with action bar glow"`

---

### Task 13: Spell ranks rule

**Files:**
- Create: `NewbieNudge/Rules/SpellRanks.lua`
- Test: `tests/test_rules_spellranks.lua`

**Interfaces:**
- Locale keys: `SPELL_RANKS_TITLE = "Old spell ranks on your bars" / "Rangos antiguos en tus barras"`, `SPELL_RANKS_HELP = "You learned a stronger rank of this spell, but your bar still has the old one. Click this line to swap it." / "Has aprendido un rango más fuerte de este hechizo, pero tu barra aún tiene el antiguo. Haz clic en esta línea para cambiarlo."`, `SPELL_RANKS_ROW = "%s on your action bar is %s; you know %s." / "%s en tu barra de acción es %s; conoces %s."`, `SPELL_RANKS_ROW_NORANK = "%s on your action bar is an old rank." / "%s en tu barra de acción es un rango antiguo."`.
- `check`: for slot 1–180, `kind, id = GetActionInfo(slot)`; when `kind == "spell"` and `NN.Spellbook:IsLowRank(id)`: group by `name = C_Spell.GetSpellName(id)` collecting slots and `lowID`; `topID = NN.Spellbook:TopRankByName(name)`; skip when `topID == nil or topID == lowID`; text `SPELL_RANKS_ROW:format(name, C_Spell.GetSpellSubtext(lowID), C_Spell.GetSpellSubtext(topID))` or `_NORANK` when either subtext is nil; icon `C_Spell.GetSpellTexture(topID)`; `highlight = { action = slots }`; `onClick`: if `InCombatLockdown()` or `GetCursorInfo()` return; for each slot `C_Spell.PickupSpell(topID); PlaceAction(slot)`; then `ClearCursor()`; then `NN:MarkDirty("spell_ranks"); NN:Schedule()`. Cap 3 + `MORE_ROWS`. Events: `ACTIONBAR_SLOT_CHANGED`, `LEARNED_SPELL_IN_SKILL_LINE`, `SPELLS_CHANGED`, `PLAYER_ENTERING_WORLD`.
- Stub additions: `C_Spell.PickupSpell` (sets `state.cursor = {type="spell", id=}`), `PlaceAction(slot)` (moves cursor into `state.actions[slot]`, records call), `ClearCursor`, `GetCursorInfo`.

- [ ] **Step 1: Tests**: `low_rank_on_bar_is_reported_with_ranks` (Fireball 133 "Rank 1" in slot 2, book has 143 "Rank 2" top → text "Fireball on your action bar is Rank 1; you know Rank 2."), `top_rank_on_bar_is_fine`, `two_slots_same_spell_one_row_both_glow`, `click_swaps_every_slot_and_clears_cursor` (after onClick, actions[2].id == 143 and cursor nil), `click_refuses_in_combat`, `macros_ignored`.
- [ ] **Step 2: Run, fail.** **Step 3: Implement.** **Step 4: Run, pass.**
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: old spell rank rule with one-click swap"`

---

### Task 14: Tracking rule

**Files:**
- Create: `NewbieNudge/Rules/Tracking.lua`
- Test: `tests/test_rules_tracking.lua`

**Interfaces:**
- Locale keys: `TRACKING_TITLE = "Gathering tracking" / "Rastreo de recolección"`, `TRACKING_HELP = "Tracking shows herbs or ore on your minimap. Click the magnifying glass by the minimap, or click this line." / "El rastreo muestra hierbas o vetas en tu minimapa. Haz clic en la lupa junto al minimapa, o en esta línea."`, `TRACKING_ROW_HERBS = "Turn on %s on the minimap to spot herbs." / "Activa %s en el minimapa para ver las hierbas."`, `TRACKING_ROW_MINERALS = "Turn on %s on the minimap to spot ore veins." / "Activa %s en el minimapa para ver las vetas."`.
- Constants: `FIND_HERBS = 2383`, `FIND_MINERALS = 2580`. `applies`: `NN.Spellbook:Knows(2383) or NN.Spellbook:Knows(2580)`. `check`: for each known tracking spell, find index `i` in `1..C_Minimap.GetNumTrackingTypes()` whose `C_Minimap.GetTrackingInfo(i)` has `spellID == id` or `name == C_Spell.GetSpellName(id)`; when found and not `active` → result with `TRACKING_ROW_HERBS`/`_MINERALS` formatted with the name, icon = `info.texture`, `onClick = function() C_Minimap.SetTracking(i, true) end`, highlight `tracking`. If both are known and both off, two results. Events: `MINIMAP_UPDATE_TRACKING`, `SPELLS_CHANGED`, `PLAYER_ENTERING_WORLD`.
- Stub additions: `C_Minimap.GetNumTrackingTypes`, `GetTrackingInfo(i)` (`{name, texture, active, spellID}`), `SetTracking(i, on)` (sets `state.tracking[i].active`).

- [ ] **Step 1: Tests**: `not_applicable_without_gathering`, `herbs_known_and_off_gives_row`, `herbs_active_gives_nothing`, `click_enables_tracking`, `both_known_both_off_two_rows`, `match_by_name_when_no_spellid`.
- [ ] **Step 2: Run, fail.** **Step 3: Implement.** **Step 4: Run, pass.**
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: gathering tracking rule"`

---

### Task 15: Ammo and pet rules

**Files:**
- Create: `NewbieNudge/Rules/Ammo.lua`, `NewbieNudge/Rules/Pet.lua`
- Test: `tests/test_rules_ammo_pet.lua`

**Interfaces:**
- Locale keys: `AMMO_TITLE = "Ammo" / "Munición"`, `AMMO_HELP = "Bows, guns and crossbows need arrows or bullets in your ammo slot. Vendors near weapon trainers sell them." / "Los arcos, armas de fuego y ballestas necesitan flechas o balas en tu hueco de munición. Los vendedores cerca de los maestros de armas las venden."`, `AMMO_ROW_NONE = "You're out of ammo." / "Te has quedado sin munición."`, `AMMO_ROW_LOW = "Ammo is running low (%d left)." / "Queda poca munición (%d)."`, `PET_TITLE = "Hunter pet" / "Mascota de cazador"`, `PET_HELP = "Your pet does a big share of your damage and keeps enemies off you. Keep it summoned, fed and trained." / "Tu mascota hace gran parte de tu daño y mantiene a los enemigos lejos de ti. Mantenla invocada, alimentada y entrenada."`, `PET_ROW_MISSING = "Your pet isn't summoned." / "Tu mascota no está invocada."`, `PET_ROW_UNHAPPY = "Your pet is unhappy; feed it." / "Tu mascota está descontenta; dale de comer."`, `PET_ROW_TRAINING = "Your pet has %d unspent training points." / "Tu mascota tiene %d puntos de entrenamiento sin gastar."`.
- `ammo` (combat): `applies`: `UnitUsesAmmo ~= nil and UnitUsesAmmo("player") == true`. `check`: `n = NN.Plain(GetInventoryItemCount("player", INVSLOT_AMMO))`; nil → `NN.UNKNOWN`; `0` → `AMMO_ROW_NONE`; `< 50` → `AMMO_ROW_LOW:format(n)`; icon 132382; `onClick` opens the paper doll; highlight `character`. Events: `UNIT_INVENTORY_CHANGED`, `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`.
- `pet` (combat): `applies`: `NN.classFile == "HUNTER" and UnitLevel("player") >= 10`. Core addition: `NN.db.seen.pet = true` whenever `UnitExists("pet")` and `select(2, HasPetUI())` on `UNIT_PET`/`PLAYER_ENTERING_WORLD`. `check` results: missing when `db.seen.pet and not UnitExists("pet") and not IsMounted() and not IsResting() and not UnitIsDeadOrGhost("player")` (icon 132161); unhappy when pet exists and `NN.PetHappiness()` is 1 or 2 (helper handling `C_PetInfo.GetPetHappiness` returning a number first or a table with `.happiness`; nil when the API is missing) (icon 132214, highlight none); training when `NN.PetUnspentTraining()` > 0 (helper: `C_PetInfo.GetPetTrainingPoints` returning `total, spent` or a table `{totalPoints, spent}`; unspent = total - spent) (icon 132835). Events: `UNIT_PET`, `UNIT_HAPPINESS`, `UNIT_PET_TRAINING_POINTS`, `PET_UI_UPDATE`, `PLAYER_LEVEL_UP`, `PLAYER_UPDATE_RESTING`, `PLAYER_ENTERING_WORLD`.
- Stub additions: `GetInventoryItemCount("player", 0)` → `state.ammoCount`; `HasPetUI` → `state.pet.hasUI, state.pet.isHunterPet`; `C_PetInfo.GetPetHappiness` → `state.pet.happiness`; `C_PetInfo.GetPetTrainingPoints` → `total, spent`; `UnitExists("pet")` → `state.pet.exists`.

- [ ] **Step 1: Tests**: `ammo_not_applicable_when_api_missing` (`_G.UnitUsesAmmo = nil`), `ammo_none`, `ammo_low_49`, `ammo_fine_50`, `pet_not_applicable_for_mage`, `pet_missing_only_after_seen` (hunter 10, pet never seen → nothing; fire UNIT_PET with exists → then exists=false → row), `pet_missing_suppressed_when_resting`, `pet_unhappy_row`, `pet_training_points_row`, `pet_table_return_shapes_handled`.
- [ ] **Step 2: Run, fail.** **Step 3: Implement.** **Step 4: Run, pass.**
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: ammo and hunter pet rules"`

---

### Task 16: Professions and rested rules

**Files:**
- Create: `NewbieNudge/Rules/Professions.lua`, `NewbieNudge/Rules/Rested.lua`
- Test: `tests/test_rules_prof_rested.lua`

**Interfaces:**
- Locale keys: `PROFESSIONS_TITLE = "No profession" / "Sin profesión"`, `PROFESSIONS_HELP = "Professions are learned from trainers in any capital city. You can have two." / "Las profesiones se aprenden de los maestros en cualquier capital. Puedes tener dos."`, `PROFESSIONS_ROW = "You have no profession yet. Gathering (Herbalism, Mining, Skinning) makes gold while you level." / "Aún no tienes profesión. Las de recolección (Herboristería, Minería, Desuello) dan oro mientras subes de nivel."`, `RESTED_TITLE = "Rested XP" / "Experiencia de descanso"`, `RESTED_HELP = "Logging out in an inn or a city builds rested XP, which doubles the experience you get from kills for a while." / "Desconectar en una posada o ciudad acumula experiencia de descanso, que duplica la experiencia por matar enemigos durante un tiempo."`, `RESTED_ROW = "You're not in an inn or city. Log out there to earn rested XP." / "No estás en una posada ni en una ciudad. Desconecta allí para ganar experiencia de descanso."`.
- `professions`: `applies`: level ≥ 10. `check`: `NN.PrimaryProfessionCount()` helper in the file: if `GetProfessions` exists → count of non-nil among its first two returns; else if `C_SkillInfo` exists → walk `1..C_SkillInfo.GetNumSkillLines()`, `C_SkillInfo.GetSkillLineInfo(i)` (accept a table with `skillName/isHeader`, or a tuple `name, isHeader`), count non-header lines whose most recent header name equals `TRADE_SKILLS`; else nil. Result when count == 0: `PROFESSIONS_ROW`, icon 136240, `onClick = function() ToggleCharacter("SkillFrame") end` only when `SkillFrame` or `ToggleCharacter` exists, highlight `character`. Events: `SKILL_LINES_CHANGED`, `PLAYER_LEVEL_UP`, `PLAYER_ENTERING_WORLD`.
- `rested`: `applies`: `UnitLevel("player") < GetMaxPlayerLevel()`. Not event driven: on load, `GameMenuFrame:HookScript("OnShow", function() NN.restedPrompt = not IsResting(); if NN.restedPrompt and not NN.restedSaid then NN.restedSaid = true; NN:Say(L.RESTED_ROW) end; NN:MarkDirty("rested"); NN:Schedule() end)` and `HookScript("OnHide", function() NN.restedPrompt = false; mark; schedule end)`. `check`: result `RESTED_ROW` (icon 136081) when `NN.restedPrompt` and `not IsResting()`. Events: `PLAYER_UPDATE_RESTING`.
- Stub additions: `GetProfessions` (from `state.professions.prof1/prof2`; set `_G.GetProfessions = nil` in a test to exercise the `C_SkillInfo` path), `C_SkillInfo.GetNumSkillLines/GetSkillLineInfo` from `state.skillLines`, `WOW.ShowGameMenu(bool)`.

- [ ] **Step 1: Tests**: `professions_row_when_none`, `professions_fine_with_one`, `professions_skillinfo_path_counts_under_header`, `professions_silent_when_no_api`, `rested_row_when_menu_opens_unrested` (also `WOW.printed` last == prefix .. RESTED_ROW), `rested_says_once_per_session`, `rested_nothing_when_resting`, `rested_row_clears_on_menu_hide`, `rested_not_applicable_at_max_level`.
- [ ] **Step 2: Run, fail.** **Step 3: Implement.** **Step 4: Run, pass.**
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: profession and rested XP rules"`

---

### Task 17: Gear upgrade rule (off by default)

**Files:**
- Create: `NewbieNudge/Rules/GearUpgrade.lua`
- Test: `tests/test_rules_gear.lua`

**Interfaces:**
- Locale keys: `GEAR_UPGRADE_TITLE = "Gear upgrade in bags" / "Mejora de equipo en las bolsas"`, `GEAR_UPGRADE_HELP = "This compares item levels only, so treat it as a hint. Open your bags and read the item's tooltip." / "Esto compara solo el nivel de objeto, así que tómalo como una pista. Abre tus bolsas y lee la descripción del objeto."`, `GEAR_UPGRADE_ROW = "An item in your bags looks like an upgrade: %s" / "Un objeto de tus bolsas parece una mejora: %s"`.
- `default = false`. `applies`: always. Tables in the file: `SLOT_FOR_EQUIPLOC` (`INVTYPE_HEAD=1, NECK=2, SHOULDER=3, CHEST=5, ROBE=5, WAIST=6, LEGS=7, FEET=8, WRIST=9, HAND=10, FINGER={11,12}, TRINKET={13,14}, CLOAK=15`) and `ARMOR_FOR_CLASS` (`MAGE/PRIEST/WARLOCK = {Cloth}`, `DRUID/ROGUE = {Cloth, Leather}`, `HUNTER/SHAMAN = {Cloth, Leather, Mail}`, `WARRIOR/PALADIN = {Cloth, Leather, Mail, Plate}` using `Enum.ItemArmorSubclass`). `check`: nil until `NN.bagsLoaded`; for each bag item: `classID, subclassID, equipLoc, reqLevel, ilvl` via `C_Item.GetItemInfoInstant` and `C_Item.GetItemInfo` (skip when `GetItemInfo` returns nil, data not cached); require `classID == Enum.ItemClass.Armor`, subclass allowed for `NN.classFile` (necks, cloaks, rings, trinkets have subclass Misc 0 and are always allowed), `reqLevel <= UnitLevel("player")`, slot(s) from the table; equipped ilvl = `C_Item.GetDetailedItemLevelInfo(GetInventoryItemLink("player", slot))` or 0 when empty; for pairs use the lower of the two; upgrade when `bagIlvl >= equippedIlvl + 5` or slot empty. One result per item up to 3 then `MORE_ROWS`; text `GEAR_UPGRADE_ROW:format(link)`, icon from the item, `onClick = ToggleAllBags`, highlight `bags`. Events: `BAG_UPDATE_DELAYED`, `PLAYER_EQUIPMENT_CHANGED`.
- Stub additions: `C_Item.GetItemInfo` (name, link, quality, itemLevel, reqLevel, itemType, itemSubType, stackCount, equipLoc, icon, sellPrice, classID, subclassID), `C_Item.GetDetailedItemLevelInfo(link)` (look up by link in `state.itemInfo`), `GetInventoryItemLink`.

- [ ] **Step 1: Tests**: `disabled_by_default` (after `load_addon()` with a clear upgrade in bags, `results_of("gear_upgrade")` is empty; after `NewbieNudge:HandleSlash("on gear_upgrade")` and `run_checks()` it has one row), `cloth_chest_five_ilvl_higher_is_upgrade`, `four_ilvl_higher_is_not`, `empty_slot_counts_as_upgrade`, `plate_ignored_for_mage`, `ring_compares_to_lower_of_two`, `too_high_required_level_ignored`, `weapons_ignored`.
- [ ] **Step 2: Run, fail.** **Step 3: Implement** (the `default == false` handling already lives in Core from Task 3). **Step 4: Run, pass.**
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: gear upgrade hint rule (off by default)"`

---

### Task 18: Testing checklist, README, deploy and first in-game pass

**Files:**
- Create: `docs/testing-checklist.md`, `README.md`
- Modify: whatever the in-game pass reveals (each fix gets its own test where the harness can express it)

**Interfaces:**
- Consumes: everything.

- [ ] **Step 1: Write `docs/testing-checklist.md`**: one block per rule with "Make it appear" and "Make it disappear" instructions in game, plus the panel, strip (`/console addonCombatRestrictionsForced 1` then `0`), options page, `/nudge` commands and the Spanish client check. Also the API-shape checks to run first with `/dump`: `UnitUsesAmmo("player")`, `C_PetInfo.GetPetHappiness()`, `C_PetInfo.GetPetTrainingPoints()`, `GetProfessions()`, `C_SkillInfo.GetSkillLineInfo(1)`, `C_Item.GetWeaponEnchantInfo()`, `C_Minimap.GetTrackingInfo(1)`, `C_TooltipInfo.GetBagItem(0,1)`, `TalentMicroButton`, `SpellbookMicroButton`, `MinimapCluster.Tracking`, `ToggleTalentFrame`.
- [ ] **Step 2: Write `README.md`**: what it does (one paragraph), install (drop `NewbieNudge` into `World of Warcraft\_forever_\Interface\AddOns`), commands, how to add a rule (the rule table from the spec's 3.1), how to run tests, how to deploy for development (`tools/deploy.ps1`).
- [ ] **Step 3: Deploy** — `powershell -File tools/deploy.ps1` → prints the junction path. Confirm with `ls "G:\Games\World of Warcraft\_forever_\Interface\AddOns\NewbieNudge"`.
- [ ] **Step 4: In-game pass (needs the user logged in)**: `/console scriptErrors 1`, `/reload`, then the `/dump` list from Step 1, then every block of the checklist. Record each API whose shape differs from the stub, fix the rule and the stub together, add a test for the real shape, rerun `tests/run.py`.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "docs: README and in-game testing checklist; fixes from first in-game pass"`
