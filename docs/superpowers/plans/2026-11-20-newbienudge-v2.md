# NewbieNudge v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add map reveal, tips-as-reminders, quest planning, a bag-full helper, controller support, a new-player game-settings page and Icy Veins talent builds to NewbieNudge, all switchable, all offline-tested.

**Architecture:** Every new reminder is a rule file under `Rules/` using the v1 rule interface; the three non-rule features (map reveal, bag-full frame, talent build) are modules that hook or own one frame each. Static game data comes from two import scripts that write Lua tables under `NewbieNudge/Data/`. The camera CVar code is generalised into `CVarSection` and reused by Controller and Game settings. The options page becomes a parent category with subcategories.

**Tech Stack:** Lua 5.1 (WoW Forever client, Interface 16001), Blizzard Settings API, Python 3 + vendored `lupa` for the offline harness (`python tests/run.py`) and for the import scripts.

**Spec:** `docs/superpowers/specs/2026-11-20-newbienudge-v2-design.md` (sections 10–24), which extends `docs/superpowers/specs/2026-11-20-newbienudge-design.md` (v1; rule interface §3.1, core §3.2, panel §3.6, highlights §3.7).

## Global Constraints

- Lua 5.1 only (no `goto`, no integer division, no `table.unpack`).
- Every user-visible string is a key in `Locales/enUS.lua` and translated in `Locales/esES.lua` (tú form); `python tests/run.py` fails on key mismatch.
- API values pass through `NN.Plain(v, kind)`; any secret value makes a rule return `NN.UNKNOWN`.
- Rules never create frames and never print, except through `NN:Say` where the spec says so.
- No libraries. New files are listed in `NewbieNudge.toc`; data files load right after `Data_Buffs.lua`.
- Licence: GPL-3.0 (`LICENSE`, TOC `## X-License: GPL-3.0`); every generated data file header names source, commit/version, date and licence.
- The whole suite (`python tests/run.py`) is green at the end of every task; one commit per task minimum.
- Test files: `tests/test_<name>.lua` returning a table of functions; fixtures under `tests/fixtures/` are loaded after the TOC files through `WOW.extraFiles`, so a fixture may overwrite a data table.
- Fake-API additions go in `tests/wow_stub.lua`, state-driven through `WOW.state`, calls recorded with `record(name, ...)`. Every new state key gets a default in `DEFAULT_STATE` (empty table, `false` or `0`) so tests that do not set it still run.

## Review Focus

1. **Map art layer missing for `pin.layerIndex`** (spec §12.2 step 5): must fall back to layer 1, not error. Test in Task 3 (`layer_fallback_to_first`).
2. **Quest objective text in Spanish word order** ("Carne de jabalí: 3/10") and English ("3/10 Boar Meat"): both must yield the item name. Test in Task 5 (`objective_name_both_orders`).
3. **Bag-full with an item whose info is not cached yet** (`GetItemInfo` nil): skip the stack, refresh on `GET_ITEM_INFO_RECEIVED`, never list a nameless row. Test in Task 11 (`uncached_item_skipped_then_refreshed`).
4. **Talent link with more points on a talent than its `maxRank`** (a corrupted or hand-edited link): reject with a clear reason instead of suggesting an impossible pick. Test in Task 15 (`rejects_more_points_than_max_rank`).
5. **Controller hint CVar holding an unknown token** (`GamePadCursorLeftClick = "PADPADDLE9"`): the hint shows the raw token, no error. Test in Task 13 (`hint_falls_back_to_raw_token`).

---

## File map

| Path | Responsibility |
|---|---|
| `LICENSE` | GPL-3.0 text (new) |
| `tools/import_handbook.py` | Download + transform WoW Handbook tables → `Data/*.lua` (new) |
| `tools/import_icy_talents.py` | Download Icy Veins talent JSON → `Data/IcyTalents.lua` (new) |
| `NewbieNudge/Data/MapFog.lua`, `TrainerSpells.lua`, `Zones.lua`, `Dungeons.lua`, `IcyTalents.lua` | Generated data (new) |
| `NewbieNudge/CVarSection.lua` | Generic curated/discovered CVar section (new; Camera moves onto it) |
| `NewbieNudge/Camera.lua` | Becomes a thin `CVarSection` instance (modify) |
| `NewbieNudge/Controller.lua` | Controller CVars, presets, session flag, hints, bindings (new) |
| `NewbieNudge/GameSettings.lua` | New-player game settings + preset (new) |
| `NewbieNudge/MapReveal.lua` | Unexplored-tile overlay (new) |
| `NewbieNudge/BagFull.lua` | Cheapest-to-destroy frame (new) |
| `NewbieNudge/TalentBuild.lua` | Link parsing, storage, rule `talent_build` (new) |
| `NewbieNudge/Bindings.xml` | Four bindable actions (new) |
| `NewbieNudge/Options.lua` | Subcategories, `AddDropdown`, Map/Bags/Camera/Controller/Game settings/Talent build pages (modify) |
| `NewbieNudge/Core.lua` | PRIORITY, defaults, generation counter, slash `map`/`trash`/`build` (modify) |
| `NewbieNudge/Panel.lua` | Controller scale boost, pad hints, hidden flag, top-row actions (modify) |
| `NewbieNudge/Highlight.lua` | Table highlights with `key`, `bagslots`, `node` (modify) |
| `NewbieNudge/Rules/QuestPlan.lua` | `NN.QuestScan`, `quest_turnin`, `quest_soon`, `quest_grey` (new) |
| `NewbieNudge/Rules/QuestSlots.lua` | `quest_slots` (new) |
| `NewbieNudge/Rules/QuestItem.lua` | `quest_item` (new) |
| `NewbieNudge/Rules/MaterialsBag.lua` | `materials_bag` (new) |
| `NewbieNudge/Rules/TrainerSpells.lua` | `trainer_spells` (new) |
| `NewbieNudge/Rules/ProfessionRank.lua` | `profession_rank` (new) |
| `NewbieNudge/Rules/Dungeons.lua` | `dungeon_ready`, `zone_level` (new) |
| `tests/test_*.lua`, `tests/fixtures/*.lua`, `tests/wow_stub.lua`, `tests/test_import_*.py` | Tests (new/modify) |
| `README.md`, `docs/testing-checklist.md` | Docs (modify, per task) |

TOC load order after this plan (full list):

```
Locales\enUS.lua
Locales\esES.lua
Core.lua
Spellbook.lua
Highlight.lua
Panel.lua
Options.lua
CVarSection.lua
Camera.lua
Controller.lua
GameSettings.lua
Data_Buffs.lua
Data\MapFog.lua
Data\TrainerSpells.lua
Data\Zones.lua
Data\Dungeons.lua
Data\IcyTalents.lua
MapReveal.lua
BagFull.lua
TalentBuild.lua
Rules\Bags.lua
Rules\MaterialsBag.lua
Rules\Simple.lua
Rules\Talents.lua
Rules\Buffs.lua
Rules\SpellRanks.lua
Rules\Tracking.lua
Rules\Ammo.lua
Rules\Pet.lua
Rules\Professions.lua
Rules\ProfessionRank.lua
Rules\TrainerSpells.lua
Rules\Dungeons.lua
Rules\QuestPlan.lua
Rules\QuestSlots.lua
Rules\QuestItem.lua
Rules\Rested.lua
Rules\GearUpgrade.lua
```

Each task adds its own lines; the harness skips TOC lines whose file does not exist yet, so the full TOC can be written in Task 1.

---

### Task 1: Licence, Handbook import script, generated data

**Files:**
- Create: `LICENSE`, `tools/import_handbook.py`, `tests/test_import_handbook.py`, `tests/test_data_files.lua`, `NewbieNudge/Data/{MapFog,TrainerSpells,Zones,Dungeons}.lua` (generated)
- Modify: `NewbieNudge/NewbieNudge.toc`, `README.md`

**Interfaces:**
- Produces: `NN.MapFog[uiMapID] = { { w, h, x, y, fileID, ... }, ... }`; `NN.TrainerSpells[CLASS] = { { level=, id=, spell=, rank=, races={tokens}? }, ... }`; `NN.Zones[uiMapID] = { min=, max= }`; `NN.Dungeons = { { instanceID=, min=, max=, faction="alliance"|"horde"|nil, mapID=, nameEN=, quests={ids} }, ... }` sorted by `min`, then `nameEN`.
- Python: `import_handbook.transform(tables: dict[str, object]) -> dict[str, str]` where keys are `"MapFog"`, `"TrainerSpells"`, `"Zones"`, `"Dungeons"` and values are complete Lua file texts; `import_handbook.load_lua_table(src: str, field: str)` executes an upstream file in lupa and returns `ns.Data[field]` as nested Python dict/list; `import_handbook.main(argv)`.

- [ ] **Step 1: Write the failing Python test**

`tests/test_import_handbook.py`:

```python
import sys, os, unittest
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools")); sys.path.insert(0, os.path.join(ROOT, "tools", "pylib"))
import import_handbook as ih

SPELLS = '''local ADDON_NAME, ns = ...
ns.Data = ns.Data or {}
ns.Data.spells = { warrior = { { name = { enUS = "Heroic Strike" }, ranks = { { rank = "Rank 1", level = 1, id = 78 }, { rank = "Rank 2", level = 8, id = 284 } } },
  { name = { enUS = "Noid" }, ranks = { { rank = "", level = 4 } } } },
  paladin = { { name = { enUS = "Holy Light" }, races = { "Dwarf", "Human", "Undead", "Night Elf" }, ranks = { { rank = "Rank 1", level = 1, id = 635 } } } } }'''
ZONES = '''local ADDON_NAME, ns = ...
ns.Data = ns.Data or {}
ns.Data.zones = { [1440] = { slug = "ashenvale", kind = "zone", levels = { 19, 30 } }, [1453] = { slug = "stormwind", kind = "city" }, [1450] = { slug = "moonglade", kind = "zone" } }'''
DUNGEONS = '''local ADDON_NAME, ns = ...
ns.Data = ns.Data or {}
ns.Data.dungeons = { { slug = "the-deadmines", instanceID = 36, levels = { 16, 26 }, faction = "alliance", name = { enUS = "The Deadmines" }, entrance = { map = 1436, x = 1, y = 2 }, quests = { 166, 214 } },
  { slug = "sm", instanceID = 189, levels = { 30, 46 }, name = { enUS = "Scarlet Monastery" }, aggregateOnly = true, entrance = { map = 1420 }, quests = {} },
  { slug = "rfc", instanceID = 389, levels = { 13, 18 }, faction = "horde", name = { enUS = "Ragefire Chasm" }, entrance = { map = 1454 }, quests = { 5722 } } }'''
MAPS = '''local ADDON_NAME, ns = ...
ns.Data = ns.Data or {}
ns.Data.mapOverlays = { [1412] = { { 462, 210, 277, 448, 7938948, 7938949 }, { 171, 231, 262, 349, 7938946 } } }'''

class Transform(unittest.TestCase):
    def tables(self):
        return { "spells": ih.load_lua_table(SPELLS, "spells"), "zones": ih.load_lua_table(ZONES, "zones"),
                 "dungeons": ih.load_lua_table(DUNGEONS, "dungeons"), "mapOverlays": ih.load_lua_table(MAPS, "mapOverlays") }
    def test_trainer_spells_keep_ids_only_and_map_classes_and_races(self):
        out = ih.transform(self.tables(), source="x", commit="abc", date="2026-11-20")["TrainerSpells"]
        self.assertIn("NN.TrainerSpells", out); self.assertIn("WARRIOR", out); self.assertNotIn("warrior", out)
        self.assertIn("id = 284", out); self.assertNotIn("Noid", out)
        self.assertIn('"Scourge"', out); self.assertIn('"NightElf"', out)
        self.assertIn("spell = 1, rank = 2", out)
    def test_zones_only_zone_kind_with_levels(self):
        out = ih.transform(self.tables(), source="x", commit="abc", date="d")["Zones"]
        self.assertIn("[1440] = { min = 19, max = 30 }", out); self.assertNotIn("1453", out); self.assertNotIn("1450", out)
    def test_dungeons_skip_aggregate_and_sort_by_min(self):
        out = ih.transform(self.tables(), source="x", commit="abc", date="d")["Dungeons"]
        self.assertNotIn("Scarlet", out)
        self.assertLess(out.index("Ragefire"), out.index("Deadmines"))
        self.assertIn('faction = "horde"', out); self.assertIn("mapID = 1436", out); self.assertIn("quests = { 166, 214 }", out)
    def test_map_fog_verbatim_and_header(self):
        out = ih.transform(self.tables(), source="x", commit="abc", date="d")["MapFog"]
        self.assertIn("{ 462, 210, 277, 448, 7938948, 7938949 }", out)
        self.assertTrue(out.startswith("-- Generated by tools/import_handbook.py"))
        self.assertIn("GPL-3.0", out); self.assertIn("abc", out)
    def test_deterministic(self):
        a = ih.transform(self.tables(), source="x", commit="abc", date="d"); b = ih.transform(self.tables(), source="x", commit="abc", date="d")
        self.assertEqual(a, b)

if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python -m unittest tests/test_import_handbook.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'import_handbook'`

- [ ] **Step 3: Implement `tools/import_handbook.py`**

Functions: `load_lua_table(src, field)` (lupa runtime; `lua.execute` a wrapper that does `local ns = {}; local chunk = assert(loadstring(src)); chunk("WowHandbook", ns); return ns.Data[field]`, then convert lupa tables recursively to dict/list: a table whose keys are exactly 1..n becomes a list); `transform(tables, source, commit, date)`; `render(name, lua_body)` producing the header
```
-- Generated by tools/import_handbook.py on <date>. Do not edit by hand.
-- Source: <source> (<commit>), file WowHandbook/Data/<Upstream>.lua
-- Licence: GPL-3.0, see LICENSE. Data © the WoW Handbook authors (Arcaneology/ArcaneStudio).
local _, NN = ...
```
then `NN.<Name> = {...}`; `main(argv)` with `--ref` (default `main`), `--out` (default `NewbieNudge/Data`): resolve the commit with `https://api.github.com/repos/Arcaneology/WowHandbookAddon/commits/<ref>` (field `sha`), download the four raw files from `https://raw.githubusercontent.com/Arcaneology/WowHandbookAddon/<sha>/WowHandbook/Data/<File>.lua`, write outputs, print the sha. Race token map: `{"Night Elf": "NightElf", "Undead": "Scourge"}` else remove spaces. Class key: `upper()`. Sort keys numerically/alphabetically everywhere. Exact entry formats (one entry per line, two-space indent): TrainerSpells `{ level = 8, id = 284, spell = 1, rank = 2 }` with `, races = { "Dwarf", "Human" }` appended when present; Zones `[1440] = { min = 19, max = 30 },`; Dungeons `{ instanceID = 36, min = 16, max = 26, faction = "alliance", mapID = 1436, nameEN = "The Deadmines", quests = { 166, 214 } },` (omit `faction = ...` when nil); MapFog rows `{ 462, 210, 277, 448, 7938948, 7938949 },`.

- [ ] **Step 4: Run the Python tests to verify they pass**

Run: `python -m unittest tests/test_import_handbook.py -v`
Expected: 5 tests OK

- [ ] **Step 5: Write the failing Lua shape test**

`tests/test_data_files.lua`:

```lua
return {
  map_fog_entries_have_geometry_and_ids = function()
    load_addon()
    assert_true(NewbieNudge.MapFog[1412], "Mulgore present")
    for mapID, entries in pairs(NewbieNudge.MapFog) do
      for _, e in ipairs(entries) do assert_true(#e >= 5, "map " .. mapID .. " entry too short") end
    end
  end,
  trainer_spells_have_level_and_id = function()
    load_addon()
    assert_true(NewbieNudge.TrainerSpells.WARRIOR and #NewbieNudge.TrainerSpells.WARRIOR > 10)
    for class, list in pairs(NewbieNudge.TrainerSpells) do
      for _, e in ipairs(list) do assert_true(type(e.level) == "number" and type(e.id) == "number" and e.spell and e.rank, class) end
    end
  end,
  zones_and_dungeons_shapes = function()
    load_addon()
    assert_eq(NewbieNudge.Zones[1440], { min = 19, max = 30 })
    assert_true(#NewbieNudge.Dungeons >= 10)
    for _, d in ipairs(NewbieNudge.Dungeons) do assert_true(d.instanceID and d.min and d.max and d.mapID and d.nameEN) end
    assert_true(NewbieNudge.Dungeons[1].min <= NewbieNudge.Dungeons[2].min)
  end,
}
```

- [ ] **Step 6: Run it to verify it fails**

Run: `python tests/run.py data_files`
Expected: 3 FAIL (`NewbieNudge.MapFog` is nil)

- [ ] **Step 7: Generate the data, add LICENSE, TOC, README**

Run: `python tools/import_handbook.py --ref main` (if the session refuses the network call, ask the user to run that exact command and commit the four files). Add `LICENSE` (GPL-3.0 full text from gnu.org). TOC: `## X-License: GPL-3.0` under `## Version`, and the full load order from the file map. README: a "Credits and licence" section (GPL-3.0; data from WoW Handbook, Questie/QuestieDB; Icy Veins identifiers) and a "Refreshing game data" section with the two import commands.

- [ ] **Step 8: Run the whole suite**

Run: `python tests/run.py`
Expected: all PASS (206+)

- [ ] **Step 9: Commit**

```bash
git add LICENSE tools/import_handbook.py tests/test_import_handbook.py tests/test_data_files.lua NewbieNudge/Data NewbieNudge/NewbieNudge.toc README.md
git commit -m "feat: GPL-3.0 licence and WoW Handbook data import (map fog, trainer spells, zones, dungeons)"
```

---

### Task 2: Options subcategories, dropdowns, and `CVarSection`

**Files:**
- Create: `NewbieNudge/CVarSection.lua`, `tests/test_cvarsection.lua`
- Modify: `NewbieNudge/Options.lua`, `NewbieNudge/Camera.lua`, `NewbieNudge/Locales/enUS.lua`, `esES.lua`, `tests/wow_stub.lua`, `tests/test_options.lua`

**Interfaces:**
- Produces: `Options.AddSubcategory(name) -> category, layout` (wraps `Settings.RegisterVerticalLayoutSubcategory(Options.category, name)`); `Options.AddDropdown(category, variable, name, tooltip, options, getter, setter)` where `options = { { value = "0", label = "Never" }, ... }`, values are strings, getter returns a string, setter receives a string; `Options:Build()` creates subcategories in this order via module hooks: `NN.Options.pages = {}` list of `{ key, title, build = function(category, layout) end }` registered with `Options.RegisterPage(key, titleKey, buildFn)` before login; pages are built in registration order after Reminders and after the Camera subcategory, which gives the final order Camera, Controller, Game settings, Map, Bags, Talent build (TOC load order); the spec's table order is not binding.
- Produces: `NN.CVarSection.New(spec) -> section` with `spec = { curated = { entry... }, exclude = { [cvar]=true }, match = function(name) -> bool, note = "LOCALE_KEY" or nil, otherHeader = "LOCALE_KEY" or nil, resetLabel = "LOCALE_KEY" }`; entry kinds: `{ cvar, kind="checkbox", label, help }`, `{ cvar, kind="slider", min, max, step, label, help }`, `{ cvar, kind="dropdown", options = { { "0", "LABEL_KEY" }, ... }, label, help }`, `{ header = "LOCALE_KEY" }`. Methods: `section:Get(cvar)` (number or nil), `section:GetString(cvar)`, `section:Set(cvar, value)`, `section:ResetCurated()`, `section:Discover()`, `section:AddControls(category, layout)`, `section:Apply(tbl) -> changedCount` (skips CVars with nil `GetCVarDefault`; a value equal to the current one does not count as changed). `section.CURATED`, `section.EXCLUDE` exposed.
- Camera keeps `NN.Camera.CURATED`, `NN.Camera:Get/Set/ResetCurated/Discover/AddToOptions(category, layout)`; existing `tests/test_camera.lua` must pass unchanged.

- [ ] **Step 1: Extend the stub**

In `tests/wow_stub.lua` add: `Settings.RegisterVerticalLayoutSubcategory(parent, name)` → `record("RegisterVerticalLayoutSubcategory", parent.name, name)`; returns `newCategory(name)` with `cat.parent = parent`. `Settings.CreateControlTextContainer()` → object with `Add(value, label)` and `GetData()` returning the list. `Settings.CreateDropdown(cat, setting, optionsFn, tooltip)` → `record("dropdown", setting.variable, optionsFn())`.

- [ ] **Step 2: Write the failing tests**

Append to `tests/test_options.lua`:

```lua
  camera_lives_in_its_own_subcategory = function()
    withRules()
    local subs = callsNamed("RegisterVerticalLayoutSubcategory")
    assert_true(#subs >= 1)
    assert_eq(subs[1][2], "NewbieNudge")
    local names = {}
    for _, c in ipairs(subs) do names[#names + 1] = c[3] end
    assert_true(tContains(names, NewbieNudge.L.OPT_CAMERA))
  end,
  dropdown_helper_registers_string_setting = function()
    withRules()
    local value = "1"
    NewbieNudge.Options.AddDropdown(NewbieNudge.Options.category, "NN_test_dd", "DD", "tt",
      { { value = "0", label = "Zero" }, { value = "1", label = "One" } },
      function() return value end, function(v) value = v end)
    local dd = callsNamed("dropdown")[1]
    assert_eq(dd[2], "NN_test_dd")
    assert_eq(dd[3], { { value = "0", label = "Zero" }, { value = "1", label = "One" } })
    assert_eq(WOW.settings["NN_test_dd"].type, "string")
    WOW.settings["NN_test_dd"].setter("0"); assert_eq(value, "0")
  end,
```

`tests/test_cvarsection.lua`:

```lua
local function cvars(list)
  WOW.state.cvars = {}
  for name, v in pairs(list) do WOW.state.cvars[name] = { value = v.value or v.default, default = v.default } end
end
local function callsNamed(name) local out = {} for _, c in ipairs(WOW.calls) do if c[1] == name then out[#out + 1] = c end end return out end
local function has(list, pred) for _, c in ipairs(list) do if pred(c) then return c end end end
local function section()
  return NewbieNudge.CVarSection.New({
    curated = { { header = "OPT_GENERAL" }, { cvar = "fooA", kind = "checkbox", label = "OPT_LOCK", help = "OPT_LOCK_TT" },
                { cvar = "fooB", kind = "dropdown", options = { { "0", "STATE_OFF" }, { "2", "STATE_ON" } }, label = "OPT_SCALE", help = "OPT_SCALE" } },
    exclude = { fooX = true }, match = function(name) return name:sub(1, 3) == "foo" end, otherHeader = "OPT_CAMERA_OTHER", resetLabel = "OPT_CAMERA_RESET",
  })
end
return {
  apply_counts_changes_and_skips_unknown = function()
    cvars({ fooA = { default = "0" }, fooB = { default = "1", value = "1" } })
    load_addon()
    local s = section()
    assert_eq(s:Apply({ fooA = 1, fooB = "1", nope = 1 }), 1)
    assert_eq(s:GetString("fooA"), "1")
    assert_nil(s:Get("nope"))
  end,
  discover_uses_match_and_exclude = function()
    cvars({ fooA = { default = "0" }, fooC = { default = "3" }, fooX = { default = "1" }, bar = { default = "1" } })
    WOW.state.consoleCommands = {}
    for _, n in ipairs({ "fooA", "fooC", "fooX", "bar" }) do WOW.state.consoleCommands[#WOW.state.consoleCommands + 1] = { command = n, help = "", commandType = 0 } end
    load_addon()
    local found = section():Discover()
    assert_eq(#found, 1); assert_eq(found[1].cvar, "fooC")
  end,
  dropdown_shows_raw_value_when_unknown = function()
    cvars({ fooA = { default = "0" }, fooB = { default = "1", value = "7" } })
    load_addon()
    local cat, layout = NewbieNudge.Options.AddSubcategory("X")
    section():AddControls(cat, layout)
    local dd = callsNamed("dropdown")[1]
    assert_eq(dd[2], "NN_cvar_fooB")
    assert_eq(dd[3][#dd[3]], { value = "7", label = "7" })
    local inits = callsNamed("initializer")
    assert_true(has(inits, function(c) return c[2] == "header" and c[3] == NewbieNudge.L.OPT_GENERAL end))
    assert_eq(inits[#inits][2], "button") -- the reset button comes last when nothing is discovered
  end,
  dropdown_setter_writes_string = function()
    cvars({ fooB = { default = "1" } })
    load_addon()
    local cat, layout = NewbieNudge.Options.AddSubcategory("X")
    section():AddControls(cat, layout)
    WOW.settings["NN_cvar_fooB"].setter("2")
    assert_eq(C_CVar.GetCVar("fooB"), "2")
    assert_eq(WOW.settings["NN_cvar_fooB"].getter(), "2")
  end,
}
```

- [ ] **Step 3: Run to verify they fail**

Run: `python tests/run.py options` then `python tests/run.py cvarsection`
Expected: the two new options tests FAIL (no subcategory call; `AddDropdown` nil); all cvarsection tests FAIL (`NewbieNudge.CVarSection` nil)

- [ ] **Step 4: Implement `CVarSection.lua`, `Options` changes, rewrite `Camera.lua` on top**

`CVarSection.lua` holds the shared `getCVar/getDefault/classify/addControl` logic currently in Camera.lua. `addControl` for `dropdown`: build options from `entry.options` with labels `L[key]`, append `{ value = current, label = current }` when the current string is not among the values; register via `Options.AddDropdown` with getter `section:GetString(cvar) or options[1].value`. `AddControls` order: curated entries in order (headers inline), then the reset button (`L[resetLabel]`), then discovered under `L[otherHeader]`. `Camera.lua`: `NN.Camera = NN.CVarSection.New({ curated = <existing CURATED>, exclude = <existing EXCLUDE>, match = function(name) return name:lower():find("camera", 1, true) ~= nil end, note = "OPT_CAMERA_NOTE", otherHeader = "OPT_CAMERA_OTHER", resetLabel = "OPT_CAMERA_RESET" })` and `function Camera:AddToOptions(category, layout) self:AddControls(category, layout) end`. `Options:Build()`: after Reminders, `local cat, layout = Options.AddSubcategory(L.OPT_CAMERA); NN.Camera:AddToOptions(cat, layout)`, then every registered page. Note: the camera header initializer `OPT_CAMERA` is no longer needed inside the page (the subcategory is titled), but `tests/test_camera.lua` asserts a header named `OPT_CAMERA` exists and comes after `OPT_REMINDERS`: keep emitting it as the page's first header so that test stays green.

- [ ] **Step 5: Run the suite**

Run: `python tests/run.py`
Expected: all PASS, including every test in `test_camera.lua`

- [ ] **Step 6: Commit**

```bash
git add NewbieNudge/CVarSection.lua NewbieNudge/Camera.lua NewbieNudge/Options.lua NewbieNudge/Locales tests/wow_stub.lua tests/test_options.lua tests/test_cvarsection.lua NewbieNudge/NewbieNudge.toc
git commit -m "refactor: options subcategories, dropdown control, generic CVarSection (camera moves onto it)"
```

---

### Task 3: Map reveal

**Files:**
- Create: `NewbieNudge/MapReveal.lua`, `tests/test_mapreveal.lua`
- Modify: `NewbieNudge/Core.lua` (defaults `map`, slash `map`), `NewbieNudge/Options.lua` (page "Map"), locales, `tests/wow_stub.lua`

**Interfaces:**
- Consumes: `NN.MapFog` (Task 1), `Options.RegisterPage`, `Options.AddCheckbox/AddSlider` (Task 2).
- Produces: `NN.MapReveal` with `MapReveal.TilesFor(entries, exploredKeys, tileW, tileH) -> { { fileID=, x=, y=, w=, h=, u=, v= }, ... }` (pure), `MapReveal.Key(w, h, x, y) -> "w:h:x:y"`, `MapReveal:HookPins()`, `MapReveal:OnRefresh(pin)`, `MapReveal:Refresh()` (re-run `OnRefresh` on the hooked pin when `WorldMapFrame:IsShown()`), `MapReveal.pools[pin]`. Defaults: `db.map = { reveal = true, brightness = 0.6, desaturate = true }`.

- [ ] **Step 1: Extend the stub**

Add to `tests/wow_stub.lua`: `C_Map = {}` with `C_Map.GetMapArtLayers(mapID)` returning `S().mapLayers[mapID] or { { tileWidth = 256, tileHeight = 256 } }`; `C_MapExplorationInfo = { GetExploredMapTextures = function(mapID) return S().explored[mapID] end }`; `CreateTexturePool(parent, layer, subLevel)` returning `{ Acquire=, Release=, ReleaseAll=, EnumerateActive=, GetNumActive= }` (Acquire reuses released textures else `parent:CreateTexture(nil, layer)`; sets `texture.subLevel = subLevel`); `WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)` hidden by default, with `WorldMapFrame.pins = {}`, `function WorldMapFrame:EnumeratePinsByTemplate(template) local i = 0 return function() i = i + 1 return self.pins[i] end end`; helper `function WOW.NewMapPin(mapID) local pin = CreateFrame("Frame"); pin.layerIndex = 1; pin.mapID = mapID; pin.map = { GetMapID = function() return pin.mapID end, AddMaskableTexture = function(_, t) record("AddMaskableTexture", t) end }; function pin:GetMap() return self.map end; function pin:RefreshOverlays(full) record("RefreshOverlays", full) end; WorldMapFrame.pins[#WorldMapFrame.pins + 1] = pin; return pin end`. State defaults: `explored = {}`, `mapLayers = {}`.

- [ ] **Step 2: Write the failing tests**

`tests/test_mapreveal.lua`:

```lua
local function fog(mapID, entries) NewbieNudge.MapFog[mapID] = entries end
local function activeTextures(pin) local out = {} for t in NewbieNudge.MapReveal.pools[pin]:EnumerateActive() do out[#out + 1] = t end return out end
return {
  tiles_for_lays_out_grid_and_edge_texcoords = function()
    load_addon()
    local tiles = NewbieNudge.MapReveal.TilesFor({ { 300, 270, 10, 20, 1, 2, 3, 4 } }, {}, 256, 256)
    assert_eq(#tiles, 4)
    assert_eq(tiles[1], { fileID = 1, x = 10, y = 20, w = 256, h = 256, u = 1, v = 1 })
    assert_eq(tiles[2], { fileID = 2, x = 266, y = 20, w = 44, h = 256, u = 44 / 64, v = 1 })
    assert_eq(tiles[3], { fileID = 3, x = 10, y = 276, w = 256, h = 14, u = 1, v = 14 / 16 })
    assert_eq(tiles[4].fileID, 4)
  end,
  explored_entries_are_skipped = function()
    load_addon()
    local tiles = NewbieNudge.MapReveal.TilesFor({ { 100, 100, 0, 0, 7 }, { 100, 100, 100, 0, 8 } }, { ["100:100:0:0"] = true }, 256, 256)
    assert_eq(#tiles, 1); assert_eq(tiles[1].fileID, 8)
  end,
  refresh_draws_unexplored_tiles_dimmed = function()
    load_addon()
    fog(1412, { { 100, 100, 0, 0, 7 }, { 100, 100, 100, 0, 8 } })
    WOW.state.explored[1412] = { { textureWidth = 100, textureHeight = 100, offsetX = 0, offsetY = 0, fileDataIDs = { 7 } } }
    local pin = WOW.NewMapPin(1412)
    NewbieNudge.MapReveal:HookPins()
    pin:RefreshOverlays(true)
    local ts = activeTextures(pin)
    assert_eq(#ts, 1); assert_eq(ts[1].texture, 8)
    assert_eq(ts[1].vertexColor, { 0.6, 0.6, 0.6, 1 }); assert_eq(ts[1].desaturated, true); assert_eq(ts[1].subLevel, -1)
  end,
  option_off_draws_nothing = function()
    load_addon(); fog(1412, { { 100, 100, 0, 0, 7 } }); WOW.state.explored[1412] = {}
    NewbieNudge.db.map.reveal = false
    local pin = WOW.NewMapPin(1412); NewbieNudge.MapReveal:HookPins(); pin:RefreshOverlays()
    assert_eq(#activeTextures(pin), 0)
  end,
  secret_or_missing_explored_data_draws_nothing = function()
    load_addon(); fog(1412, { { 100, 100, 0, 0, 7 } })
    WOW.state.explored[1412] = { { textureWidth = WOW.secret(100), textureHeight = 100, offsetX = 0, offsetY = 0 } }
    local pin = WOW.NewMapPin(1412); NewbieNudge.MapReveal:HookPins(); pin:RefreshOverlays()
    assert_eq(#activeTextures(pin), 0)
    WOW.state.explored[1412] = nil; pin:RefreshOverlays()
    assert_eq(#activeTextures(pin), 0)
  end,
  unknown_map_draws_nothing = function()
    load_addon(); WOW.state.explored[999] = {}
    local pin = WOW.NewMapPin(999); NewbieNudge.MapReveal:HookPins(); pin:RefreshOverlays()
    assert_eq(#activeTextures(pin), 0)
  end,
  pool_released_each_refresh = function()
    load_addon(); fog(1412, { { 100, 100, 0, 0, 7 }, { 100, 100, 100, 0, 8 } }); WOW.state.explored[1412] = {}
    local pin = WOW.NewMapPin(1412); NewbieNudge.MapReveal:HookPins()
    for _ = 1, 3 do pin:RefreshOverlays() end
    assert_eq(NewbieNudge.MapReveal.pools[pin]:GetNumActive(), 2)
  end,
  layer_fallback_to_first = function()
    load_addon(); fog(1412, { { 100, 100, 0, 0, 7 } }); WOW.state.explored[1412] = {}
    WOW.state.mapLayers[1412] = { { tileWidth = 64, tileHeight = 64 } }
    local pin = WOW.NewMapPin(1412); pin.layerIndex = 3
    NewbieNudge.MapReveal:HookPins(); pin:RefreshOverlays()
    assert_eq(#activeTextures(pin), 4) -- 100x100 on 64px tiles = 2x2
  end,
  brightness_option_and_refresh = function()
    load_addon(); fog(1412, { { 100, 100, 0, 0, 7 } }); WOW.state.explored[1412] = {}
    local pin = WOW.NewMapPin(1412); NewbieNudge.MapReveal:HookPins(); WorldMapFrame:Show()
    WOW.settings["NN_map_brightness"].setter(40)
    assert_eq(NewbieNudge.db.map.brightness, 0.4)
    assert_eq(activeTextures(pin)[1].vertexColor, { 0.4, 0.4, 0.4, 1 })
  end,
  slash_map_toggles_option = function()
    load_addon()
    NewbieNudge:HandleSlash("map")
    assert_eq(NewbieNudge.db.map.reveal, false)
    assert_true(WOW.printed[#WOW.printed]:find(NewbieNudge.L.SLASH_MAP_OFF, 1, true))
  end,
  pins_found_on_first_map_show = function()
    load_addon() -- no pin yet at login
    NewbieNudge.MapReveal:HookPins()
    fog(1412, { { 100, 100, 0, 0, 7 } }); WOW.state.explored[1412] = {}
    local pin = WOW.NewMapPin(1412)
    WorldMapFrame:Show()
    pin:RefreshOverlays()
    assert_eq(#activeTextures(pin), 1)
  end,
}
```

- [ ] **Step 3: Run to verify they fail**

Run: `python tests/run.py mapreveal`
Expected: all FAIL (`NewbieNudge.MapReveal` nil)

- [ ] **Step 4: Implement `MapReveal.lua`, options page, defaults, slash**

`TilesFor`: per spec §12.2 step 6 — `numWide = ceil(w / tileW)`, `numTall = ceil(h / tileH)`; tile `(j,k)` width = `tileW` unless last column: `w % tileW` (or `tileW` when 0); file width = next power of two ≥ 16 covering that; `u = tileW_px / fileW`; same for height; `x = offsetX + tileW*(k-1)`, `y = offsetY + tileH*(j-1)`; `fileID = entry[4 + (j-1)*numWide + k]`; skip when fileID is nil. `OnRefresh(pin)`: release pool; return if `not db.map.reveal`; `mapID`, data, explored set (return on nil or any secret in `textureWidth/Height/offsetX/Y`); layers fallback; for each tile: `t = pool:Acquire(); t:SetTexture(fileID, nil, nil, "TRILINEAR"); t:SetSize(w, h); t:SetTexCoord(0, u, 0, v); t:SetPoint("TOPLEFT", pin, "TOPLEFT", x, -y); t:SetDesaturated(db.map.desaturate); t:SetVertexColor(b, b, b, 1); t:SetDrawLayer("ARTWORK", -1); if map.AddMaskableTexture then map:AddMaskableTexture(t) end; t:Show()`. `HookPins`: iterate `WorldMapFrame:EnumeratePinsByTemplate("MapExplorationPinTemplate")`, `hooksecurefunc(pin, "RefreshOverlays", function(p) MapReveal:OnRefresh(p) end)` once per pin (`self.hooked[pin] = true`); if none found, `WorldMapFrame:HookScript("OnShow", retry)` once. Called from `NN:AfterLogin` when `WorldMapFrame` exists, else on `ADDON_LOADED` for `Blizzard_WorldMap` (register through `NN:OnAnyEvent`). Options page "Map": checkbox `NN_map_reveal`, slider `NN_map_brightness` 10–100 step 5 (getter `brightness*100`, setter `/100` then `MapReveal:Refresh()`), checkbox `NN_map_desaturate`. Slash `map` toggles `db.map.reveal`, prints `SLASH_MAP_ON`/`SLASH_MAP_OFF`, calls `Refresh()`. Locale keys: `OPT_MAP`, `OPT_MAP_REVEAL`, `OPT_MAP_REVEAL_TT`, `OPT_MAP_BRIGHTNESS`, `OPT_MAP_DESATURATE`, `SLASH_MAP_ON`, `SLASH_MAP_OFF`; add `map` to `SLASH_HELP`.

- [ ] **Step 5: Run the suite**

Run: `python tests/run.py`
Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add NewbieNudge/MapReveal.lua NewbieNudge/Core.lua NewbieNudge/Options.lua NewbieNudge/Locales tests/wow_stub.lua tests/test_mapreveal.lua
git commit -m "feat: map reveal — unexplored zone tiles drawn dimmed on the world map"
```

---

### Task 4: Quest planning rules (`quest_turnin`, `quest_soon`, `quest_grey`)

**Files:**
- Create: `NewbieNudge/Rules/QuestPlan.lua`, `tests/test_rules_questplan.lua`
- Modify: `NewbieNudge/Core.lua` (generation counter, PRIORITY), locales, `tests/wow_stub.lua`

**Interfaces:**
- Produces: `NN.QuestScan() -> list | NN.UNKNOWN` of `{ questID, title, level, isComplete, isTrivial, turnsGreyIn }`, memoised per `NN.generation` (Core increments `self.generation` at the top of `RunChecks`). Rule names `quest_turnin`, `quest_soon`, `quest_grey`.

- [ ] **Step 1: Extend the stub**

State: `questLog = nil` (when set, a list of `{ questID, title, level, isHeader, isComplete, trivial, objectives, rewards, choices }`). `C_QuestLog.GetNumQuestLogEntries()` → if `questLog` then `#questLog, count of non-headers` else old behaviour. `C_QuestLog.GetInfo(i)` → entry fields `{ questID, title, level, isHeader, isHidden = false, difficultyLevel = level }`. `C_QuestLog.IsComplete(id)`, `C_QuestLog.IsQuestTrivial(id)` (absent when `S().noTrivialAPI`), `C_QuestLog.GetQuestDifficultyLevel(id)`, `UnitQuestTrivialLevelRange(unit)` → `S().trivialRange or 5`. Helper `WOW.Quest(fields)` appends to `questLog` (creating it) and returns the entry.

- [ ] **Step 2: Write the failing tests**

```lua
local L = function() return NewbieNudge.L end
local function run() WOW.FireEvent("QUEST_LOG_UPDATE"); run_checks() end
return {
  turnin_counts_complete_quests = function()
    WOW.Quest({ questID = 1, title = "A", level = 20, isComplete = true }); WOW.Quest({ questID = 2, title = "B", level = 20 })
    WOW.Quest({ title = "Header", isHeader = true })
    load_addon(); run()
    local r = results_of("quest_turnin")
    assert_eq(r[1].text, L().QUEST_TURNIN_ROW:format(1)); assert_eq(r[1].highlight, "quests")
    r[1].onClick(); assert_eq(WOW.calls[#WOW.calls][1], "ToggleQuestLog")
  end,
  turnin_hides_when_handed_in = function()
    local q = WOW.Quest({ questID = 1, title = "A", level = 20, isComplete = true })
    load_addon(); run(); assert_eq(#results_of("quest_turnin"), 1)
    WOW.state.questLog = {}; WOW.FireEvent("QUEST_TURNED_IN", 1); run_checks()
    assert_eq(#results_of("quest_turnin"), 0)
  end,
  soon_uses_trivial_range = function()
    WOW.state.level = 20; WOW.state.trivialRange = 5
    WOW.Quest({ questID = 1, title = "A", level = 14, trivial = true }) -- the client says grey; not soon
    WOW.Quest({ questID = 2, title = "B", level = 16 }) -- grey at 22 -> turnsGreyIn 2 -> soon
    WOW.Quest({ questID = 3, title = "C", level = 18 }) -- grey at 24 -> not soon
    load_addon(); run()
    assert_eq(results_of("quest_soon")[1].text, L().QUEST_SOON_ROW:format(1))
    assert_eq(results_of("quest_grey")[1].text, L().QUEST_GREY_ROW:format(1))
  end,
  grey_prefers_client_api_when_present = function()
    WOW.state.level = 20
    WOW.Quest({ questID = 1, title = "A", level = 19, trivial = true })
    load_addon(); run()
    assert_eq(results_of("quest_grey")[1].text, L().QUEST_GREY_ROW:format(1))
    assert_eq(#results_of("quest_soon"), 0, "trivial quests are not 'soon'")
  end,
  grey_fallback_without_api = function()
    WOW.state.level = 20; WOW.state.noTrivialAPI = true
    WOW.Quest({ questID = 1, title = "A", level = 10 })
    load_addon(); run()
    assert_eq(#results_of("quest_grey"), 1)
  end,
  complete_quests_are_neither_soon_nor_grey = function()
    WOW.state.level = 20
    WOW.Quest({ questID = 1, title = "A", level = 10, isComplete = true })
    load_addon(); run()
    assert_eq(#results_of("quest_grey"), 0); assert_eq(#results_of("quest_soon"), 0); assert_eq(#results_of("quest_turnin"), 1)
  end,
  scan_runs_once_per_check_cycle = function()
    WOW.Quest({ questID = 1, title = "A", level = 20 })
    load_addon()
    local calls = 0
    local orig = C_QuestLog.GetInfo
    C_QuestLog.GetInfo = function(...) calls = calls + 1; return orig(...) end
    run()
    C_QuestLog.GetInfo = orig
    assert_eq(calls, 1, "three rules share one scan")
  end,
  secret_level_keeps_previous = function()
    WOW.state.level = 20
    local q = WOW.Quest({ questID = 1, title = "A", level = 20, isComplete = true })
    load_addon(); run(); assert_eq(#results_of("quest_turnin"), 1)
    q.level = WOW.secret(20); run()
    assert_eq(#results_of("quest_turnin"), 1)
  end,
  priority_puts_turnin_after_quests = function()
    load_addon()
    local idx = {}
    for i, n in ipairs(NewbieNudge.PRIORITY) do idx[n] = i end
    assert_true(idx.quests < idx.quest_turnin and idx.quest_turnin < idx.quest_soon and idx.quest_soon < idx.quest_grey)
  end,
}
```

- [ ] **Step 3: Run to verify they fail**

Run: `python tests/run.py questplan`
Expected: all FAIL (`WOW.Quest` nil / rules missing)

- [ ] **Step 4: Implement**

Core: `self.generation = (self.generation or 0) + 1` first line of `RunChecks`; PRIORITY becomes `..., "quests", "quest_item", "quest_turnin", "quest_slots", "quest_soon", "quest_grey", "mail", "professions", "profession_rank", "trainer_spells", "dungeon_ready", "zone_level", "gear_upgrade", "rested"` (names for later tasks may be listed now). `QuestPlan.lua`: `NN.QuestScan` per spec §14 (memo keyed on `NN.generation`; `turnsGreyIn = (level + range) - playerLevel + 1`; `isTrivial` via API else `level + range < playerLevel`); three rules with events `QUEST_LOG_UPDATE, QUEST_ACCEPTED, QUEST_REMOVED, QUEST_TURNED_IN, PLAYER_LEVEL_UP`, icon 136797, texts `QUEST_TURNIN_ROW = "%d quest(s) complete: turn them in."`, `QUEST_SOON_ROW = "%d quest(s) stop giving full XP within 2 levels: finish them soon."`, `QUEST_GREY_ROW = "%d grey quest(s) give almost no XP: do them last or abandon them."`, plus `_TITLE`/`_HELP` keys; `quest_grey` has no highlight. Samples for `/nudge test`.

- [ ] **Step 5: Run the suite** — Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add NewbieNudge/Rules/QuestPlan.lua NewbieNudge/Core.lua NewbieNudge/Locales tests/wow_stub.lua tests/test_rules_questplan.lua NewbieNudge/NewbieNudge.toc
git commit -m "feat: quest planning rows — turn in, finish soon, grey"
```

---

### Task 5: `quest_slots`

**Files:** Create `NewbieNudge/Rules/QuestSlots.lua`, `tests/test_rules_questslots.lua`; modify stub, locales.

**Interfaces:**
- Produces: `NN.ObjectiveItemName(text) -> string|nil` (strips the `n/m` counter and surrounding `:`, `-`, `–`, spaces); `NN.QuestSlotsNeeded() -> number | NN.UNKNOWN`.
- Consumes: `NN.QuestScan` (Task 4), regular free-slot count as in `Rules/Bags.lua` (extract `NN.RegularFreeSlots()` into `Rules/Bags.lua` and reuse).

- [ ] **Step 1: Extend the stub**

`C_QuestLog.GetQuestObjectives(questID)` → entry `.objectives` (list of `{ type, text, numFulfilled, numRequired, finished }`); `GetNumQuestLogRewards(questID)` → `#(entry.rewards or {})`; `GetNumQuestLogChoices(questID)` → `#(entry.choices or {})`; `C_Item.GetItemMaxStackSizeByID(id)` → `itemInfo[id].stackCount or 1`.

- [ ] **Step 2: Write the failing tests**

```lua
local L = function() return NewbieNudge.L end
local function item(id, name, stack) WOW.state.itemInfo[id] = { name = name, stackCount = stack or 20 } end
local function bagItem(slot, id, count) WOW.state.bags[0].items[slot] = { itemID = id, count = count } end
local function run() load_addon(); load_bags(); WOW.FireEvent("QUEST_LOG_UPDATE"); run_checks() end
return {
  objective_name_both_orders = function()
    load_addon()
    assert_eq(NewbieNudge.ObjectiveItemName("Boar Meat: 3/10"), "Boar Meat")
    assert_eq(NewbieNudge.ObjectiveItemName("3/10 Boar Meat"), "Boar Meat")
    assert_eq(NewbieNudge.ObjectiveItemName("Carne de jabalí: 0/10"), "Carne de jabalí")
    assert_nil(NewbieNudge.ObjectiveItemName("Kill Hogger: 0/1 (monster)")) -- callers pass item objectives only; a text with no counter returns nil
  end,
  unstarted_item_objective_needs_one_slot = function()
    WOW.state.bags[0].numSlots = 3; bagItem(1, 1); bagItem(2, 1); item(1, "Junk")
    WOW.Quest({ questID = 1, title = "A", level = 20, objectives = { { type = "item", text = "Boar Meat: 0/10", numFulfilled = 0, numRequired = 10 } } })
    run()
    assert_eq(#results_of("quest_slots"), 0, "1 free slot covers 1 needed: no row")
  end,
  row_when_free_below_needed = function()
    WOW.state.bags[0].numSlots = 2; bagItem(1, 1); bagItem(2, 1); item(1, "Junk")
    WOW.Quest({ questID = 1, title = "A", level = 20, objectives = {
      { type = "item", text = "Boar Meat: 0/10", numFulfilled = 0, numRequired = 10 },
      { type = "item", text = "Wolf Pelt: 0/5", numFulfilled = 0, numRequired = 5 },
      { type = "monster", text = "Hogger: 0/1", numFulfilled = 0, numRequired = 1 } } })
    run()
    assert_eq(results_of("quest_slots")[1].text, L().QUEST_SLOTS_ROW:format(2, 0))
    assert_eq(results_of("quest_slots")[1].highlight, "bags")
  end,
  started_stack_counts_remaining_stacks = function()
    WOW.state.bags[0].numSlots = 3; item(2, "Boar Meat", 5); bagItem(1, 2, 3); bagItem(2, 1); bagItem(3, 1); item(1, "Junk")
    WOW.Quest({ questID = 1, title = "A", level = 20, objectives = { { type = "item", text = "Boar Meat: 3/12", numFulfilled = 3, numRequired = 12 } } })
    run() -- 12 needed / stack 5 = 3 stacks, 1 held -> 2 more slots, 0 free
    assert_eq(results_of("quest_slots")[1].text, L().QUEST_SLOTS_ROW:format(2, 0))
  end,
  finished_objectives_and_rewards_of_complete_quests = function()
    WOW.state.bags[0].numSlots = 2; bagItem(1, 1); bagItem(2, 1); item(1, "Junk")
    WOW.Quest({ questID = 1, title = "A", level = 20, isComplete = true, rewards = { 10 }, choices = { 11, 12 },
      objectives = { { type = "item", text = "Boar Meat: 10/10", numFulfilled = 10, numRequired = 10, finished = true } } })
    run() -- 1 reward + 1 choice = 2
    assert_eq(results_of("quest_slots")[1].text, L().QUEST_SLOTS_ROW:format(2, 0))
  end,
  no_row_without_quests = function()
    WOW.state.questLog = {}; WOW.state.bags[0].numSlots = 1; bagItem(1, 1); item(1, "Junk")
    run(); assert_eq(#results_of("quest_slots"), 0)
  end,
}
```
- [ ] **Step 3: Run to verify they fail** — `python tests/run.py questslots` → FAIL (`ObjectiveItemName` nil)

- [ ] **Step 4: Implement** per spec §14.4; `QUEST_SLOTS_ROW = "Keep %d bag slots free for your quests (you have %d)."`; events `BAG_UPDATE_DELAYED, QUEST_LOG_UPDATE, QUEST_ACCEPTED, QUEST_REMOVED, QUEST_TURNED_IN`; icon 133634; onClick `ToggleAllBags`; highlight `bags`. `NN.RegularFreeSlots()` extracted from `bag_full`'s check (returns number or `NN.UNKNOWN`).

- [ ] **Step 5: Run the suite** — all PASS

- [ ] **Step 6: Commit** — `git commit -m "feat: quest_slots — bag slots the current quests will need"`

---

### Task 6: `quest_item` and bag-slot highlights

**Files:** Create `NewbieNudge/Rules/QuestItem.lua`, `tests/test_rules_questitem.lua`; modify `NewbieNudge/Highlight.lua`, `tests/test_highlight.lua`, stub, locales.

**Interfaces:**
- Produces: result highlight table form `{ key = "bags", bagslots = { { bag, slot }, ... } }` understood by `Highlight:Apply` alongside the existing `{ action = {...} }` and string forms; `Highlight:ButtonForBagSlot(bag, slot) -> button|nil`; `Highlight:InvalidateBagButtons()` on `BAG_OPEN`, `BAG_CLOSED`, `BAG_UPDATE_DELAYED`.

- [ ] **Step 1: Extend the stub**

`C_Container.GetContainerItemQuestInfo(bag, slot)` → `{ isQuestItem = it.isQuestItem or false, questID = it.questID, isActive = it.isActive or false }`; `WOW.NewContainerFrame(bagID, numSlots)`: creates a Frame with `Items` list of buttons (`b.bagID = bagID; b.slot = i; function b:GetBagID() return self.bagID end; b:SetID(i)`), `function f:EnumerateValidItems() local i = 0 return function() i = i + 1 return self.Items[i] end end`, appends to `S().containerFrames`; `ContainerFrameUtil_EnumerateContainerFrames()` iterates `S().containerFrames`.

- [ ] **Step 2: Write the failing tests**

```lua
-- tests/test_rules_questitem.lua
local L = function() return NewbieNudge.L end
return {
  item_that_starts_a_quest_gets_a_row_and_bag_highlight = function()
    WOW.state.itemInfo[9] = { name = "Gnarled Note" }
    WOW.state.bags[0].items[3] = { itemID = 9, questID = 500, isActive = false, isQuestItem = true }
    load_addon(); load_bags(); run_checks()
    local r = results_of("quest_item")
    assert_eq(r[1].text, L().QUEST_ITEM_ROW:format("Gnarled Note"))
    assert_eq(r[1].highlight, { key = "bags", bagslots = { { 0, 3 } } })
  end,
  active_quest_item_is_not_listed = function()
    WOW.state.itemInfo[9] = { name = "Note" }
    WOW.state.bags[0].items[3] = { itemID = 9, questID = 500, isActive = true, isQuestItem = true }
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("quest_item"), 0)
  end,
  disappears_once_accepted = function()
    WOW.state.itemInfo[9] = { name = "Note" }
    local it = { itemID = 9, questID = 500, isActive = false, isQuestItem = true }
    WOW.state.bags[0].items[3] = it
    load_addon(); load_bags(); run_checks(); assert_eq(#results_of("quest_item"), 1)
    it.isActive = true; WOW.FireEvent("QUEST_ACCEPTED", 500); run_checks()
    assert_eq(#results_of("quest_item"), 0)
  end,
}
```
Append to `tests/test_highlight.lua`:
```lua
  bagslot_highlight_glows_item_button_and_backpack = function()
    load_addon()
    local cf = WOW.NewContainerFrame(0, 16)
    local rows = { { rule = { name = "r" }, result = { text = "t", highlight = { key = "bags", bagslots = { { 0, 3 } } } }, stale = false } }
    NewbieNudge.Highlight:Apply(rows)
    local shown = {}
    for _, c in ipairs(WOW.calls) do if c[1] == "glow_show" then shown[c[2]] = true end end
    assert_true(shown[MainMenuBarBackpackButton]); assert_true(shown[cf.Items[3]])
    NewbieNudge.Highlight:Apply({})
    assert_eq(WOW.calls[#WOW.calls][1], "glow_hide")
  end,
  bagslot_without_open_bags_only_glows_backpack = function()
    load_addon()
    NewbieNudge.Highlight:Apply({ { rule = { name = "r" }, result = { text = "t", highlight = { key = "bags", bagslots = { { 0, 3 } } } }, stale = false } })
    local n = 0
    for _, c in ipairs(WOW.calls) do if c[1] == "glow_show" then n = n + 1 end end
    assert_eq(n, 1)
  end,
```

- [ ] **Step 3: Run to verify they fail** — `python tests/run.py questitem` and `python tests/run.py highlight` → new tests FAIL

- [ ] **Step 4: Implement**

Highlight: refactor the `wanted` collection into `Highlight:TargetsFor(h)` handling string, `h.key`, `h.action`, `h.bagslots` (via `ButtonForBagSlot`, which scans `ContainerFrameUtil_EnumerateContainerFrames()` when it exists, caching `{ [bag.."/"..slot] = button }` until invalidated), and later `h.node` (Task 16). Register `BAG_OPEN`/`BAG_CLOSED` through `NN:RegisterEvent` and invalidate + `ForgetActive` on them and on `BAG_UPDATE_DELAYED`. `QuestItem.lua` per spec §14.0: rows capped at 3, `QUEST_ITEM_ROW = "%s starts a quest. Right-click it in your bags."`, icon 134939, events `BAG_UPDATE_DELAYED, QUEST_ACCEPTED, QUEST_LOG_UPDATE`.

- [ ] **Step 5: Run the suite** — all PASS

- [ ] **Step 6: Commit** — `git commit -m "feat: quest_item — items in bags that start a quest, glowed in the bag"`

---

### Task 7: `materials_bag`

**Files:** Create `NewbieNudge/Rules/MaterialsBag.lua`, `tests/test_rules_materialsbag.lua`; modify `Rules/Bags.lua` (export `NN.ContainerSlots(bag, slot)` and `NN.BagInventorySlot(bag)`), locales, `docs/testing-checklist.md` (§0 dumps).

**Interfaces:**
- Produces: `NN.REAGENT_BAG_FAMILY = nil`, `NN.REAGENT_BAG_SUBCLASS = nil` (constants at the top of the file with the checklist note; until one is set, `applies()` returns false); `NN.IsReagentBag(itemID) -> bool`; rule `materials_bag` (combat).

- [ ] **Step 1: Write the failing tests**

```lua
local L = function() return NewbieNudge.L end
local MAT12, MAT16 = 7001, 7002
local function setup()
  WOW.state.itemInfo[MAT12] = { name = "Small Materials Bag", classID = 1, subclassID = 11, family = 2048, numSlots = 12 }
  WOW.state.itemInfo[MAT16] = { name = "Big Materials Bag", classID = 1, subclassID = 11, family = 2048, numSlots = 16 }
end
local function withConstants() NewbieNudge.REAGENT_BAG_FAMILY = 2048; wipe(NewbieNudge.appliesCache) end
return {
  silent_until_constants_are_known = function()
    setup(); WOW.state.bags[0].items[1] = { itemID = MAT12 }
    load_addon(); load_bags(); run_checks()
    assert_eq(#results_of("materials_bag"), 0)
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.materials_bag))
  end,
  empty_materials_slot_with_bag_in_inventory = function()
    setup(); WOW.state.bags[0].items[1] = { itemID = MAT12 }
    load_addon(); withConstants(); load_bags(); run_checks()
    local r = results_of("materials_bag")
    assert_eq(r[1].text, L().MATERIALS_BAG_ROW_EMPTY); assert_eq(r[1].highlight, "bags")
  end,
  bigger_materials_bag_than_equipped = function()
    setup(); WOW.state.bags[5] = { numSlots = 12, family = 2048, items = {} }; WOW.state.inventory[24] = { itemID = MAT12 }
    WOW.state.bags[0].items[1] = { itemID = MAT16 }
    load_addon(); withConstants(); load_bags(); run_checks()
    assert_eq(results_of("materials_bag")[1].text, L().MATERIALS_BAG_ROW_BIGGER)
  end,
  equal_or_smaller_is_fine_and_regular_rule_ignores_it = function()
    setup(); WOW.state.bags[5] = { numSlots = 16, family = 2048, items = {} }; WOW.state.inventory[24] = { itemID = MAT16 }
    WOW.state.bags[0].items[1] = { itemID = MAT12 }
    load_addon(); withConstants(); load_bags(); run_checks()
    assert_eq(#results_of("materials_bag"), 0); assert_eq(#results_of("bag_unequipped"), 0)
  end,
}
```

- [ ] **Step 2: Run to verify they fail** — FAIL (rule unknown)

- [ ] **Step 3: Implement** per spec §13.5; `applies = function() return (NN.REAGENT_BAG_FAMILY or NN.REAGENT_BAG_SUBCLASS) ~= nil and Enum.BagIndex and Enum.BagIndex.ReagentBag ~= nil end`; slot via `NN.BagInventorySlot(Enum.BagIndex.ReagentBag)`; texts `MATERIALS_BAG_ROW_EMPTY = "You have a materials bag in your inventory that isn't equipped."`, `MATERIALS_BAG_ROW_BIGGER = "A materials bag in your inventory is bigger than the one you're using."`. Checklist §0: the two `/dump` lines and "write the values into `Rules/MaterialsBag.lua`".

- [ ] **Step 4: Run the suite** — all PASS. **Step 5: Commit** — `git commit -m "feat: materials_bag rule (constants pending in-game confirmation)"`

---

### Task 8: `trainer_spells`

**Files:** Create `NewbieNudge/Rules/TrainerSpells.lua`, `tests/test_rules_trainerspells.lua`, `tests/fixtures/trainer_spells.lua`; modify stub (`UnitRace`), locales.

**Interfaces:**
- Consumes: `NN.TrainerSpells` (Task 1), `IsPlayerSpell`, `C_Spell.DoesSpellExist`.
- Produces: `NN.TrainableSpells() -> count, list` (pure given the data).

- [ ] **Step 1: Stub and fixture**

Stub: `UnitRace(unit)` → `S().raceName or "Human", S().raceToken or "Human"`. Fixture `tests/fixtures/trainer_spells.lua`:
```lua
local _, NN = ...
NN.TrainerSpells = NN.TrainerSpells or {}
NN.TrainerSpells.MAGE = {
  { level = 1,  id = 133, spell = 1, rank = 1 },  -- Fireball r1
  { level = 6,  id = 143, spell = 1, rank = 2 },  -- Fireball r2
  { level = 14, id = 145, spell = 1, rank = 3 },
  { level = 10, id = 5143, spell = 2, rank = 1 }, -- Arcane Missiles
  { level = 10, id = 99999, spell = 3, rank = 1 }, -- stale id, does not exist
  { level = 4,  id = 1180, spell = 4, rank = 1, races = { "Gnome" } }, -- race-locked
}
```

- [ ] **Step 2: Write the failing tests**

```lua
local L = function() return NewbieNudge.L end
local function known(...) for _, id in ipairs({ ... }) do WOW.state.spellBook.items[id] = { spellID = id } end end
local function exist(...) for _, id in ipairs({ ... }) do WOW.state.spellInfo[id] = WOW.state.spellInfo[id] or { name = "S" .. id } end end
local function setup() WOW.extraFiles = { TESTS_DIR .. "/fixtures/trainer_spells.lua" }; exist(133, 143, 145, 5143, 1180) end
local function run() load_addon(); WOW.FireEvent("SPELLS_CHANGED"); run_checks() end
return {
  counts_spells_not_ranks = function()
    setup(); WOW.state.level = 10; known(133)
    run() -- Fireball r2 (lvl 6) trainable, Arcane Missiles trainable; r3 needs 14; stale skipped; Gnome-only skipped
    local r = results_of("trainer_spells")
    assert_eq(r[1].text, L().TRAINER_SPELLS_ROW:format(2)); assert_eq(r[1].highlight, "spellbook")
  end,
  higher_rank_known_suppresses_lower = function()
    setup(); WOW.state.level = 10; known(145, 5143)
    run(); assert_eq(#results_of("trainer_spells"), 0)
  end,
  race_locked_spell_counts_for_that_race = function()
    setup(); WOW.state.level = 10; WOW.state.raceToken = "Gnome"; known(133, 143, 5143)
    run(); assert_eq(results_of("trainer_spells")[1].text, L().TRAINER_SPELLS_ROW:format(1))
  end,
  level_gates_and_level_up_rechecks = function()
    setup(); WOW.state.level = 5; known(133)
    run(); assert_eq(#results_of("trainer_spells"), 0)
    WOW.state.level = 6; WOW.FireEvent("PLAYER_LEVEL_UP", 6); run_checks()
    assert_eq(results_of("trainer_spells")[1].text, L().TRAINER_SPELLS_ROW:format(1))
  end,
  not_applicable_for_class_without_data = function()
    setup(); WOW.state.class = "WARRIOR"
    load_addon()
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.trainer_spells))
  end,
}
```

- [ ] **Step 3: Run to verify they fail** — FAIL

- [ ] **Step 4: Implement** per spec §13.1 (`TRAINER_SPELLS_ROW = "%d spells or ranks for your level you haven't learned. Visit your class trainer."`, help mentions quest-taught spells; icon 133741; events `PLAYER_LEVEL_UP, SPELLS_CHANGED, LEARNED_SPELL_IN_SKILL_LINE`; click opens spellbook as in `Rules/SpellRanks.lua`). Note: the fixture overrides the real `NN.TrainerSpells.MAGE` because fixtures load after data files; `applies` must read the table at call time, not at file load.

- [ ] **Step 5: Run the suite** — all PASS. **Step 6: Commit** — `git commit -m "feat: trainer_spells — spells for your level you have not learned"`

---

### Task 9: `profession_rank`

**Files:** Create `NewbieNudge/Rules/ProfessionRank.lua`, `tests/test_rules_professionrank.lua`; modify stub, locales, checklist.

**Interfaces:**
- Produces: `NN.ProfessionRankReady(skill, maxSkill, level) -> bool` with `RANKS = { [75] = 10, [150] = 20, [225] = 35 }`; when `maxSkill` is not a key of `RANKS` the function returns false (300 or unknown caps stay silent; checklist §0 confirms Forever reports 75/150/225).

- [ ] **Step 1: Stub** — `GetProfessionInfo(index)` → `local p = S().professionInfo[index]; if p then return p.name, p.icon or 136240, p.skill, p.maxSkill, 0, 0, p.skillLine or 0 end`.

- [ ] **Step 2: Failing tests**

```lua
local L = function() return NewbieNudge.L end
local function prof(idx, name, skill, max) WOW.state.professionInfo[idx] = { name = name, skill = skill, maxSkill = max } end
local function run() load_addon(); WOW.FireEvent("SKILL_LINES_CHANGED"); run_checks() end
return {
  ready_table = function()
    load_addon()
    local f = NewbieNudge.ProfessionRankReady
    assert_true(f(50, 75, 10)); assert_true(not f(49, 75, 10)); assert_true(not f(50, 75, 9))
    assert_true(f(125, 150, 20)); assert_true(f(200, 225, 35)); assert_true(not f(290, 300, 60)); assert_true(not f(70, 80, 60))
  end,
  row_per_ready_primary_with_client_name = function()
    WOW.state.level = 22; WOW.state.professions = { prof1 = 1, prof2 = 2 }
    prof(1, "Alchemy", 60, 75); prof(2, "Herbalism", 130, 150)
    run()
    local r = results_of("profession_rank")
    assert_eq(#r, 2)
    assert_eq(r[1].text, L().PROFESSION_RANK_ROW:format("Alchemy", 60, 75, "Alchemy"))
  end,
  secondary_professions_ignored = function()
    WOW.state.level = 22; WOW.state.professions = { prof1 = nil, prof2 = nil }
    prof(5, "Cooking", 70, 75)
    load_addon()
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.profession_rank))
  end,
  clears_when_cap_rises = function()
    WOW.state.level = 22; WOW.state.professions = { prof1 = 1 }; prof(1, "Alchemy", 60, 75)
    run(); assert_eq(#results_of("profession_rank"), 1)
    WOW.state.professionInfo[1].maxSkill = 150; WOW.FireEvent("SKILL_LINES_CHANGED"); run_checks()
    assert_eq(#results_of("profession_rank"), 0)
  end,
}
```

- [ ] **Step 3: Verify fail.** **Step 4: Implement** per spec §13.2 (`PROFESSION_RANK_ROW = "You can learn the next rank of %s (%d/%d). Visit a %s trainer."`, icon 136240, events `SKILL_LINES_CHANGED, CHAT_MSG_SKILL, PLAYER_LEVEL_UP`, no click/highlight, cap 2 rows). **Step 5: Suite green.** **Step 6: Commit** — `git commit -m "feat: profession_rank — next profession rank available"`

---

### Task 10: `dungeon_ready` and `zone_level`

**Files:** Create `NewbieNudge/Rules/Dungeons.lua`, `tests/test_rules_dungeons.lua`, `tests/fixtures/dungeons_zones.lua`; modify stub, Core defaults (`seen.dungeons = {}`), locales.

**Interfaces:**
- Consumes: `NN.Dungeons`, `NN.Zones` (Task 1).
- Produces: `NN.ZoneForMap(mapID) -> zoneMapID, {min,max} | nil` (walks parents); `NN.MarkDungeonSeen(instanceID)`.

- [ ] **Step 1: Stub and fixture**

Stub: `GetInstanceInfo()` → from `S().instance = { name="", type="none", instanceID=0 }` returns `name, type, 0, "", 5, 0, false, instanceID, 5, nil`; `GetRealZoneText(id)` → `S().zoneNames[id]`; `C_QuestLog.IsQuestFlaggedCompleted(id)` → `S().completedQuests[id] == true`; `UnitFactionGroup()` → `S().faction or "Alliance"`; `C_Map.GetBestMapForUnit()` → `S().mapID`; `C_Map.GetMapInfo(id)` → `S().mapInfo[id]` (`{ name, mapType, parentMapID }`); `Enum.UIMapType = { Cosmic=0, World=1, Continent=2, Zone=3, Dungeon=4, Micro=5, Orphan=6 }`; `OpenWorldMap(id)` records; `ToggleWorldMap()` records. Fixture sets `NN.Dungeons = { {instanceID=36,min=16,max=26,faction="alliance",mapID=1436,nameEN="The Deadmines",quests={166,214}}, {instanceID=389,min=13,max=18,faction="horde",mapID=1454,nameEN="Ragefire Chasm",quests={5722}}, {instanceID=43,min=17,max=24,mapID=1413,nameEN="Wailing Caverns",quests={}} }` and `NN.Zones = { [1440] = {min=19,max=30}, [1429] = {min=1,max=10} }`.

- [ ] **Step 2: Failing tests**

```lua
local L = function() return NewbieNudge.L end
local function setup() WOW.extraFiles = { TESTS_DIR .. "/fixtures/dungeons_zones.lua" }; WOW.state.zoneNames = { [36] = "Las Minas" } end
local function run() load_addon(); WOW.FireEvent("PLAYER_LEVEL_UP", WOW.state.level); run_checks() end
return {
  dungeons_in_range_for_faction_sorted_by_min = function()
    setup(); WOW.state.level = 18; WOW.state.faction = "Horde"
    run() -- RFC 13-18 (horde) and WC 17-24 (neutral); Deadmines is alliance
    local r = results_of("dungeon_ready")
    assert_eq(#r, 2)
    assert_eq(r[1].text, L().DUNGEON_ROW:format("Ragefire Chasm", 13, 18))
    r[1].onClick(); assert_eq(WOW.calls[#WOW.calls], { "OpenWorldMap", 1454 })
  end,
  client_name_preferred = function()
    setup(); WOW.state.level = 20; WOW.state.faction = "Alliance"
    run(); assert_eq(results_of("dungeon_ready")[1].text, L().DUNGEON_ROW:format("Las Minas", 16, 26))
  end,
  seen_after_entering_or_half_quests_done = function()
    setup(); WOW.state.level = 20; WOW.state.faction = "Alliance"
    run(); assert_eq(#results_of("dungeon_ready"), 2)
    WOW.state.completedQuests[166] = true; WOW.FireEvent("QUEST_TURNED_IN", 166); run_checks()
    assert_eq(#results_of("dungeon_ready"), 1, "half of Deadmines quests done")
    WOW.state.instance = { name = "Wailing Caverns", type = "party", instanceID = 43 }
    WOW.FireEvent("PLAYER_ENTERING_WORLD", false, true)
    WOW.state.instance = { name = "", type = "none", instanceID = 0 }; WOW.state.instanceType = "none"
    WOW.FireEvent("ZONE_CHANGED_NEW_AREA"); run_checks()
    assert_eq(#results_of("dungeon_ready"), 0)
    assert_eq(NewbieNudge.db.seen.dungeons[43], true)
  end,
  zone_below_and_above = function()
    setup(); WOW.state.mapInfo = { [1440] = { name = "Ashenvale", mapType = 3, parentMapID = 1414 }, [1414] = { name = "Kalimdor", mapType = 2 }, [7001] = { name = "Astranaar", mapType = 5, parentMapID = 1440 } }
    WOW.state.mapID = 7001; WOW.state.level = 33
    run(); assert_eq(results_of("zone_level")[1].text, L().ZONE_BELOW_ROW:format("Ashenvale", 19, 30))
    WOW.state.level = 16; WOW.FireEvent("ZONE_CHANGED_NEW_AREA"); run_checks()
    assert_eq(results_of("zone_level")[1].text, L().ZONE_ABOVE_ROW:format("Ashenvale", 19, 30))
    WOW.state.level = 25; WOW.FireEvent("ZONE_CHANGED_NEW_AREA"); run_checks()
    assert_eq(#results_of("zone_level"), 0)
  end,
  zone_rule_silent_in_instances_and_unknown_maps = function()
    setup(); WOW.state.mapInfo = { [1440] = { name = "Ashenvale", mapType = 3 } }; WOW.state.mapID = 1440; WOW.state.level = 40
    WOW.state.instanceType = "party"
    load_addon(); WOW.state.instanceType = "none"; WOW.state.mapID = 5555; WOW.FireEvent("ZONE_CHANGED_NEW_AREA"); run_checks()
    assert_eq(#results_of("zone_level"), 0)
  end,
}
```

- [ ] **Step 3: Verify fail.** **Step 4: Implement** per spec §13.3/§13.4: `DUNGEON_ROW = "%s (%d–%d) fits your level. Pick up its quests before you go."`, `ZONE_BELOW_ROW = "%s (%d–%d) is below your level. Quests here give less XP."`, `ZONE_ABOVE_ROW = "%s (%d–%d) is above your level. Be careful here."`; icons 136106 (dungeon), 134269 (zone); the seen-marking runs in an `NN:OnAnyEvent` hook on `PLAYER_ENTERING_WORLD`/`ZONE_CHANGED_NEW_AREA` (rules are frozen inside instances, so the hook — not `check` — records `GetInstanceInfo().instanceID`). **Step 5: Suite green.** **Step 6: Commit** — `git commit -m "feat: dungeon_ready and zone_level reminders"`

---

### Task 11: Bag-full helper

**Files:** Create `NewbieNudge/BagFull.lua`, `tests/test_bagfull.lua`; modify Core (defaults `bagfull`, slash `trash`), Options (page "Bags"), stub, locales.

**Interfaces:**
- Produces: `NN.BagFull` with `BagFull.frame` (`NewbieNudgeBagFull`), `BagFull.rows[i]` (`.icon`, `.name`, `.value`, `.button`, `.data`), `BagFull:Candidates() -> list of { bag, slot, itemID, name, quality, count, value, icon, link }`, `BagFull:Show(reason)` (`"error"|"loot"|"manual"`), `BagFull:Hide()`, `BagFull:Refresh()`, `BagFull:Destroy(row)`, `BagFull.reason`, `BagFull.MAX_ROWS = 6`. Defaults: `db.bagfull = { enabled = true, maxQuality = 2, onLoot = true, point = "LEFT", x = 40, y = 0 }`.

- [ ] **Step 1: Stub**

`ERR_INV_FULL = "Inventory is full."`; `LootFrame = CreateFrame("Frame", "LootFrame", UIParent)` hidden; `Enum.ItemClass` += `{ Consumable = 0, Reagent = 5, Projectile = 6, Questitem = 12, Quiver = 11, Key = 13, Tradegoods = 7 }`; `GetContainerItemInfo` adds `isLocked = it.locked or false, hasNoValue = (info.sellPrice or 0) == 0, isBound = it.bound or false`; `C_Container.PickupContainerItem(bag, slot)` sets `S().cursor = { type = "item", bag = bag, slot = slot }` and records; `CursorHasItem()`; `DeleteCursorItem()` removes `bags[bag].items[slot]` when the cursor holds an item, records `("DeleteCursorItem", bag, slot)`; `C_CurrencyInfo = { GetCoinTextureString = function(n) return tostring(n) .. "c" end }`; `UIPanelButtonTemplate` is just a template string (no-op); `GET_ITEM_INFO_RECEIVED` is an ordinary event.

- [ ] **Step 2: Failing tests**

```lua
local L = function() return NewbieNudge.L end
local function item(id, f) local t = { name = f.name or ("I" .. id), quality = f.quality or 1, sellPrice = f.price or 10, classID = f.class or 0, equipLoc = f.equip or "", family = f.family or 0, stackCount = 20 }; WOW.state.itemInfo[id] = t; return t end
local function put(slot, id, extra) local it = { itemID = id }; for k, v in pairs(extra or {}) do it[k] = v end; WOW.state.bags[0].items[slot] = it; return it end
local function names() local out = {} for _, c in ipairs(NewbieNudge.BagFull:Candidates()) do out[#out + 1] = c.name end return out end
return {
  order_grey_first_then_value = function()
    item(1, { name = "Grey", quality = 0, price = 500 }); item(2, { name = "Cheap", price = 1 }); item(3, { name = "Dear", price = 100 })
    put(1, 3); put(2, 2); put(3, 1)
    load_addon(); load_bags()
    assert_eq(names(), { "Grey", "Cheap", "Dear" })
  end,
  exclusions = function()
    item(1, { name = "Quest", class = 12 }); item(2, { name = "Starter" }); item(3, { name = "Bag", class = 1 }); item(4, { name = "Hearth" })
    item(5, { name = "Locked" }); item(6, { name = "Blue", quality = 3 }); item(7, { name = "Arrow", class = 6 }); item(8, { name = "Pick", equip = "INVTYPE_WEAPON" })
    item(9, { name = "GreySword", quality = 0, equip = "INVTYPE_WEAPON" }); item(10, { name = "Water", price = 0 }); item(11, { name = "GreyNoValue", quality = 0, price = 0 })
    item(12, { name = "Objective" }); item(13, { name = "Fine" })
    put(1, 1); put(2, 2, { questID = 5, isActive = false }); put(3, 3); put(4, 6948); WOW.state.itemInfo[6948] = { name = "Hearthstone" }
    put(5, 5, { locked = true }); put(6, 6); put(7, 7); put(8, 8); put(9, 9); put(10, 10); put(11, 11); put(12, 12); put(13, 13)
    WOW.state.bags[1] = { numSlots = 6, family = 4, items = { [1] = { itemID = 13 } } } -- soul bag contents skipped
    WOW.Quest({ questID = 1, title = "A", level = 20, objectives = { { type = "item", text = "Objective: 0/5", numFulfilled = 0, numRequired = 5 } } })
    load_addon(); load_bags()
    assert_eq(names(), { "GreyNoValue", "GreySword", "Fine" })
  end,
  shows_on_inventory_full_error_and_hides_when_slot_frees = function()
    item(1, { name = "Junk" }); WOW.state.bags[0].numSlots = 1; put(1, 1)
    load_addon(); load_bags()
    WOW.FireEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL)
    assert_true(NewbieNudgeBagFull:IsShown()); assert_eq(NewbieNudge.BagFull.rows[1].name:GetText():find("Junk", 1, true) ~= nil, true)
    WOW.state.bags[0].items[1] = nil; WOW.FireEvent("BAG_UPDATE_DELAYED")
    assert_true(not NewbieNudgeBagFull:IsShown())
  end,
  stays_while_loot_open_then_hides_on_close = function()
    item(1, { name = "Junk" }); WOW.state.bags[0].numSlots = 1; put(1, 1)
    load_addon(); load_bags(); LootFrame:Show()
    WOW.FireEvent("LOOT_OPENED", false)
    assert_true(NewbieNudgeBagFull:IsShown())
    WOW.state.bags[0].items[1] = nil; WOW.FireEvent("BAG_UPDATE_DELAYED")
    assert_true(NewbieNudgeBagFull:IsShown(), "still looting")
    LootFrame:Hide(); WOW.FireEvent("LOOT_CLOSED")
    assert_true(not NewbieNudgeBagFull:IsShown())
  end,
  loot_trigger_respects_option = function()
    item(1, { name = "Junk" }); WOW.state.bags[0].numSlots = 1; put(1, 1)
    load_addon(); load_bags(); NewbieNudge.db.bagfull.onLoot = false; LootFrame:Show()
    WOW.FireEvent("LOOT_OPENED", false)
    assert_true(not NewbieNudgeBagFull:IsShown())
  end,
  destroy_grey_one_click_and_green_asks_sure = function()
    item(1, { name = "Grey", quality = 0 }); item(2, { name = "Green", quality = 2 }); put(1, 1); put(2, 2)
    load_addon(); load_bags(); NewbieNudge.BagFull:Show("manual")
    local rows = NewbieNudge.BagFull.rows
    WOW.Click(rows[1].button)
    assert_eq(WOW.calls[#WOW.calls], { "DeleteCursorItem", 0, 1 })
    WOW.FireEvent("BAG_UPDATE_DELAYED")
    assert_eq(rows[1].data.name, "Green")
    WOW.Click(rows[1].button)
    assert_eq(rows[1].button:GetText(), L().BAGFULL_SURE); assert_true(WOW.state.bags[0].items[2] ~= nil)
    WOW.Click(rows[1].button)
    assert_true(WOW.state.bags[0].items[2] == nil)
  end,
  sure_expires_after_three_seconds = function()
    item(2, { name = "Green", quality = 2 }); put(1, 2)
    load_addon(); load_bags(); NewbieNudge.BagFull:Show("manual")
    WOW.Click(NewbieNudge.BagFull.rows[1].button); WOW.AdvanceTime(3.1)
    assert_eq(NewbieNudge.BagFull.rows[1].button:GetText(), L().BAGFULL_DESTROY)
  end,
  mismatch_refreshes_instead_of_destroying = function()
    item(1, { name = "Grey", quality = 0 }); item(3, { name = "Other", quality = 0 }); put(1, 1)
    load_addon(); load_bags(); NewbieNudge.BagFull:Show("manual")
    WOW.state.bags[0].items[1] = { itemID = 3 }
    WOW.Click(NewbieNudge.BagFull.rows[1].button)
    assert_true(WOW.state.bags[0].items[1] ~= nil); assert_eq(NewbieNudge.BagFull.rows[1].data.name, "Other")
  end,
  manual_open_ignores_auto_hide = function()
    item(1, { name = "Junk" }); put(1, 1)
    load_addon(); load_bags(); NewbieNudge:HandleSlash("trash")
    assert_true(NewbieNudgeBagFull:IsShown())
    WOW.FireEvent("BAG_UPDATE_DELAYED"); WOW.AdvanceTime(100)
    assert_true(NewbieNudgeBagFull:IsShown())
    NewbieNudge.BagFull:Hide(); assert_true(not NewbieNudgeBagFull:IsShown())
  end,
  auto_hides_after_ninety_seconds = function()
    item(1, { name = "Junk" }); WOW.state.bags[0].numSlots = 1; put(1, 1)
    load_addon(); load_bags(); WOW.FireEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL)
    WOW.AdvanceTime(91); assert_true(not NewbieNudgeBagFull:IsShown())
  end,
  uncached_item_skipped_then_refreshed = function()
    item(1, { name = "Junk" }); WOW.state.itemInfo[2] = { uncached = true }; put(1, 1); put(2, 2)
    load_addon(); load_bags(); NewbieNudge.BagFull:Show("manual")
    assert_eq(#NewbieNudge.BagFull:Candidates(), 1)
    WOW.state.itemInfo[2] = { name = "Late", quality = 0, sellPrice = 1 }
    WOW.FireEvent("GET_ITEM_INFO_RECEIVED", 2, true)
    assert_eq(NewbieNudge.BagFull.rows[1].data.name, "Late")
  end,
  secret_price_skips_stack = function()
    item(1, { name = "Junk" }); WOW.state.itemInfo[1].sellPrice = WOW.secret(5); put(1, 1)
    load_addon(); load_bags(); assert_eq(#NewbieNudge.BagFull:Candidates(), 0)
  end,
  disabled_option_never_shows = function()
    item(1, { name = "Junk" }); WOW.state.bags[0].numSlots = 1; put(1, 1)
    load_addon(); load_bags(); NewbieNudge.db.bagfull.enabled = false
    WOW.FireEvent("UI_ERROR_MESSAGE", 1, ERR_INV_FULL); assert_true(not NewbieNudgeBagFull:IsShown())
  end,
  max_quality_option = function()
    item(1, { name = "White" }); item(2, { name = "Green", quality = 2 }); put(1, 1); put(2, 2)
    load_addon(); load_bags(); NewbieNudge.db.bagfull.maxQuality = 1
    assert_eq(names(), { "White" })
  end,
}
```

- [ ] **Step 3: Verify fail.** **Step 4: Implement** per spec §15 and §15.3 as amended. Frame: title `BAGFULL_TITLE = "Bags full — cheapest to destroy"`, footer `BAGFULL_FOOT = "Quest items and bags are never listed."`, button texts `BAGFULL_DESTROY = "Destroy"`, `BAGFULL_SURE = "Sure?"`; rows anchored under the title; anchor to `LootFrame` right side when `LootFrame:IsShown()`, else saved position; draggable title. Events via `NN:RegisterEvent` + `NN:OnAnyEvent`: `UI_ERROR_MESSAGE` (second arg `== ERR_INV_FULL`), `LOOT_OPENED`, `LOOT_CLOSED`, `BAG_UPDATE_DELAYED`, `GET_ITEM_INFO_RECEIVED` (refresh when shown). Options page "Bags": `NN_bagfull_enabled`, dropdown `NN_bagfull_quality` (values "0","1","2" labelled with `ITEM_QUALITY0_DESC`…; stub those globals as "Poor","Common","Uncommon"), `NN_bagfull_onLoot`. Slash `trash` → `BagFull:Show("manual")`. **Step 5: Suite green.** **Step 6: Commit** — `git commit -m "feat: bag-full helper — cheapest stacks to destroy, next to the loot window"`

---

### Task 12: Controller CVar section and presets

**Files:** Create `NewbieNudge/Controller.lua`, `tests/test_controller.lua`; modify Options (page "Controller"), stub, locales, checklist (preset confirmation lines).

**Interfaces:**
- Produces: `NN.Controller = NN.CVarSection.New{...}` with the curated list of spec §17.1 (kinds checkbox/slider/dropdown; `padbutton` entries are declared as `kind = "padbutton"` and expanded to dropdowns by `Controller:PadOptions()` before `AddControls`); `Controller.PAD_BUTTONS` (list from spec), `Controller.PRESETS = { deck = {...}, pad = {...} }` (values from spec §17.1 table), `Controller:ApplyPreset(name) -> changed` (prints `L.CONTROLLER_PRESET_DONE:format(changed)`), `Controller:PadLabel(token) -> string` from `Controller.PAD_NAMES` (own table, Xbox-style: `PADRTRIGGER = "RT"`, `PADLTRIGGER = "LT"`, `PADRSHOULDER = "RB"`, `PADLSHOULDER = "LB"`, `PAD1 = "A"`, `PAD2 = "B"`, `PAD3 = "X"`, `PAD4 = "Y"`, `PAD5 = "Pad 5"`, `PAD6 = "Pad 6"`, `PADLSTICK = "LS"`, `PADRSTICK = "RS"`, `PADBACK = "Back"`, `PADFORWARD = "Start"`, `PADSYSTEM = "Guide"`, `PADSOCIAL = "Share"`, `PADPADDLE1..4 = "Paddle 1..4"`, `PADDUP/DDOWN/DLEFT/DRIGHT = "D-pad up/down/left/right"`), falling back to the raw token; `"none"` → `L.PAD_NONE`. In-game check 2026-11-20: `GetBindingText("PADRTRIGGER")` returns a font glyph ("|"), unusable as a label, so the client's own names are not used.

- [ ] **Step 1: Stub** — `C_GamePad = { IsEnabled = function() return S().gamepad.enabled end, GetActiveDeviceID = function() return S().gamepad.deviceID end }` with state `gamepad = { enabled = false, deviceID = 0 }`; `GetBindingText(key)` → `"|"` (the glyph the real client returns; the stub mirrors it so no code relies on it).

- [ ] **Step 2: Failing tests**

```lua
local L = function() return NewbieNudge.L end
local function cvars(list) WOW.state.cvars = {} for n, v in pairs(list) do WOW.state.cvars[n] = { value = v.value or v.default, default = v.default } end end
local function callsNamed(name) local out = {} for _, c in ipairs(WOW.calls) do if c[1] == name then out[#out + 1] = c end end return out end
local function has(list, pred) for _, c in ipairs(list) do if pred(c) then return c end end end
return {
  curated_starts_with_enable_and_has_expected_kinds = function()
    load_addon()
    local c = NewbieNudge.Controller.CURATED
    assert_eq(c[1].cvar, "GamePadEnable"); assert_eq(c[1].kind, "checkbox")
    assert_true(has(c, function(e) return e.cvar == "GamePadCursorLeftClick" and e.kind == "padbutton" end))
    assert_true(has(c, function(e) return e.cvar == "SoftTargetInteract" and e.kind == "dropdown" and #e.options == 4 end))
  end,
  padbutton_becomes_dropdown_with_binding_labels_and_raw_current = function()
    cvars({ GamePadEnable = { default = "0" }, GamePadCursorLeftClick = { default = "PADRTRIGGER", value = "PADPADDLE9" } })
    load_addon()
    local dd = has(callsNamed("dropdown"), function(c) return c[2] == "NN_cvar_GamePadCursorLeftClick" end)
    assert_true(dd)
    assert_eq(dd[3][1], { value = "none", label = L().PAD_NONE })
    assert_true(has(dd[3], function(o) return o.value == "PADRTRIGGER" and o.label == "RT" end)) -- from PAD_NAMES, not GetBindingText
    assert_eq(dd[3][#dd[3]], { value = "PADPADDLE9", label = "PADPADDLE9" })
  end,
  preset_applies_table_and_says_once = function()
    cvars({ GamePadEnable = { default = "0" }, GamePadFaceMovementMaxAngle = { default = "0" }, GamePadTurnWithCamera = { default = "1" }, SoftTargetInteract = { default = "1" } })
    load_addon()
    local printed = #WOW.printed
    local n = NewbieNudge.Controller:ApplyPreset("deck")
    assert_true(n >= 3)
    assert_eq(C_CVar.GetCVar("GamePadFaceMovementMaxAngle"), "115"); assert_eq(C_CVar.GetCVar("GamePadTurnWithCamera"), "2")
    assert_eq(#WOW.printed, printed + 1)
    assert_true(WOW.printed[#WOW.printed]:find(L().CONTROLLER_PRESET_DONE:format(n), 1, true))
  end,
  presets_never_touch_modifier_buttons = function()
    load_addon()
    for _, p in pairs(NewbieNudge.Controller.PRESETS) do
      for _, cv in ipairs({ "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt", "GamePadCursorLeftClick", "GamePadCursorRightClick" }) do assert_nil(p[cv]) end
    end
  end,
  reset_writes_defaults_for_curated = function()
    cvars({ GamePadEnable = { default = "0", value = "1" }, GamePadCameraYawSpeed = { default = "1", value = "3" } })
    load_addon(); NewbieNudge.Controller:ResetCurated()
    assert_eq(C_CVar.GetCVar("GamePadEnable"), "0"); assert_eq(C_CVar.GetCVar("GamePadCameraYawSpeed"), "1")
  end,
  discovery_prefix = function()
    cvars({ GamePadEnable = { default = "0" }, GamePadFoo = { default = "0" }, SoftTargetBar = { default = "2" }, cameraX = { default = "1" } })
    WOW.state.consoleCommands = {}
    for _, n in ipairs({ "GamePadEnable", "GamePadFoo", "SoftTargetBar", "cameraX" }) do WOW.state.consoleCommands[#WOW.state.consoleCommands + 1] = { command = n, help = "", commandType = 0 } end
    load_addon()
    local names = {} for _, d in ipairs(NewbieNudge.Controller:Discover()) do names[#names + 1] = d.cvar end
    assert_eq(names, { "GamePadFoo", "SoftTargetBar" })
  end,
  section_absent_without_gamepad_api = function()
    _G.C_GamePad = nil
    load_addon()
    assert_nil(has(callsNamed("RegisterVerticalLayoutSubcategory"), function(c) return c[3] == L().OPT_CONTROLLER end))
  end,
}
```

- [ ] **Step 3: Verify fail.** **Step 4: Implement** `Controller.lua` (curated table verbatim from spec §17.1 with locale keys `CTRL_<NAME>` / `CTRL_<NAME>_TT`, dropdown option labels as keys `CTRL_OPT_*`), presets, buttons (`OPT_CONTROLLER_PRESET_DECK`, `OPT_CONTROLLER_PRESET_PAD`, `OPT_CONTROLLER_RESET`), page registration guarded by `C_GamePad ~= nil`. Checklist §0: "apply each preset on the Deck and on an Xbox pad; note anything to change in `Controller.PRESETS`". **Step 5: Suite green.** **Step 6: Commit** — `git commit -m "feat: controller settings page with Steam Deck and controller presets"`

---

### Task 13: Controller-aware addon (scale, hints, bindings, hidden panel)

**Files:** Create `NewbieNudge/Bindings.xml`; modify `Controller.lua`, `Panel.lua`, `Core.lua` (defaults `controller`, `panel.hidden`), Options (controller page top), locales, `tests/test_controller.lua`, `tests/test_panel.lua`.

**Interfaces:**
- Produces: `Controller.session` (bool), `Controller:Boost() -> bool` (`session and db.controller.boost`), `Controller:HintButtons() -> left, right, shift` (labels via `PadLabel`, from CVars `GamePadCursorLeftClick`, `GamePadCursorRightClick`, `GamePadEmulateShift`; nil when `not session or not db.controller.hints`); `Panel.STRIP_ICON()` (24 or 32); `Panel:ToggleHidden()`, `Panel:OpenTop()`, `Panel:SnoozeTop()`; globals `BINDING_HEADER_NEWBIENUDGE`, `BINDING_NAME_NEWBIENUDGE_TOGGLE`, `_OPEN_TOP`, `_SNOOZE_TOP`, `_OPTIONS`. Defaults: `controller = { boost = true, scale = 1.25, hints = true }`, `panel.hidden = false`.

- [ ] **Step 1: Failing tests** (append to `test_controller.lua`)

```lua
  session_set_by_active_event_and_sticky = function()
    load_addon(); assert_eq(NewbieNudge.Controller.session, false)
    WOW.FireEvent("GAME_PAD_ACTIVE_CHANGED", true); assert_eq(NewbieNudge.Controller.session, true)
    WOW.FireEvent("GAME_PAD_ACTIVE_CHANGED", false); assert_eq(NewbieNudge.Controller.session, true)
  end,
  session_detected_at_login = function()
    WOW.state.gamepad = { enabled = true, deviceID = 3 }; WOW.state.cvars = { GamePadEnable = { value = "1", default = "0" } }
    load_addon(); assert_eq(NewbieNudge.Controller.session, true)
  end,
  panel_scale_boosted_in_session = function()
    load_addon(); NewbieNudge.db.panel.scale = 1.2
    NewbieNudge.Panel:ApplyScale(); assert_eq(NewbieNudgePanel:GetScale(), 1.2)
    WOW.FireEvent("GAME_PAD_ACTIVE_CHANGED", true)
    assert_eq(NewbieNudgePanel:GetScale(), 1.5)
    NewbieNudge.db.controller.boost = false; NewbieNudge.Panel:ApplyScale(); assert_eq(NewbieNudgePanel:GetScale(), 1.2)
    assert_eq(NewbieNudge.Panel.STRIP_ICON(), 24)
    NewbieNudge.db.controller.boost = true; assert_eq(NewbieNudge.Panel.STRIP_ICON(), 32)
  end,
  tooltip_hints_use_pad_buttons = function()
    WOW.state.cvars = { GamePadCursorLeftClick = { value = "PADRTRIGGER", default = "PADRTRIGGER" }, GamePadCursorRightClick = { value = "PADRSHOULDER", default = "PADRSHOULDER" }, GamePadEmulateShift = { value = "PADLTRIGGER", default = "PADLTRIGGER" } }
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/two_rules.lua" }
    load_addon(); WOW.FireEvent("TEST_EVENT"); run_checks(); WOW.FireEvent("GAME_PAD_ACTIVE_CHANGED", true)
    WOW.Hover(NewbieNudge.Panel.rows[1])
    local text = table.concat(GameTooltip.lines, "\n")
    assert_true(text:find(NewbieNudge.L.ROW_HINT_CLICK_PAD:format("RT"), 1, true), text)
    assert_true(text:find(NewbieNudge.L.ROW_HINT_SNOOZE_PAD:format("RB", "LT", "RB"), 1, true), text)
  end,
  hint_falls_back_to_raw_token = function()
    WOW.state.cvars = { GamePadCursorLeftClick = { value = "PADPADDLE9", default = "PADRTRIGGER" } }
    load_addon(); WOW.FireEvent("GAME_PAD_ACTIVE_CHANGED", true)
    local left = NewbieNudge.Controller:HintButtons()
    assert_eq(left, "PADPADDLE9")
  end,
  bindings_act_on_top_row_and_toggle_hidden = function()
    WOW.extraFiles = { TESTS_DIR .. "/fixtures/two_rules.lua" }
    load_addon(); WOW.FireEvent("TEST_EVENT"); run_checks()
    assert_true(NewbieNudgePanel:IsShown())
    NewbieNudge.Panel:ToggleHidden(); assert_true(not NewbieNudgePanel:IsShown()); assert_eq(NewbieNudge.db.panel.hidden, true)
    NewbieNudge.Panel:Refresh(NewbieNudge:ActiveRows()); assert_true(not NewbieNudgePanel:IsShown(), "stays hidden through refresh")
    NewbieNudge.Panel:ToggleHidden(); assert_true(NewbieNudgePanel:IsShown())
    NewbieNudge.Panel:SnoozeTop(); assert_true(NewbieNudge.db.snoozed.first_rule ~= nil)
    assert_eq(type(BINDING_NAME_NEWBIENUDGE_TOGGLE), "string"); assert_eq(type(BINDING_HEADER_NEWBIENUDGE), "string")
  end,
```
(`two_rules.lua` fixture: check it gives `first_rule` a result with `onClick`; if not, extend the fixture rather than the test.)

- [ ] **Step 2: Verify fail.** **Step 3: Implement** per spec §17.2: events `GAME_PAD_ACTIVE_CHANGED`, `GAME_PAD_CONNECTED` registered via `NN:RegisterEvent` and handled in `NN:OnAnyEvent`; `Panel:ApplyScale()` multiplies by `db.controller.scale` when `Controller:Boost()`; `showTooltip` uses `Controller:HintButtons()`; `Panel:Refresh` early-returns hidden when `db.panel.hidden`; `/nudge` with no args prints `SLASH_PANEL_HIDDEN` when hidden before opening options. `Bindings.xml`:
```xml
<Bindings>
  <Binding name="NEWBIENUDGE_TOGGLE" header="NEWBIENUDGE" category="ADDONS">NewbieNudge.Panel:ToggleHidden()</Binding>
  <Binding name="NEWBIENUDGE_OPEN_TOP" category="ADDONS">NewbieNudge.Panel:OpenTop()</Binding>
  <Binding name="NEWBIENUDGE_SNOOZE_TOP" category="ADDONS">NewbieNudge.Panel:SnoozeTop()</Binding>
  <Binding name="NEWBIENUDGE_OPTIONS" category="ADDONS">NewbieNudge:OpenOptions()</Binding>
</Bindings>
```
Locale keys: `ROW_HINT_CLICK_PAD = "%s: open."`, `ROW_HINT_SNOOZE_PAD = "%s: snooze. %s+%s: snooze until next login."`, `OPT_CONTROLLER_BOOST`, `OPT_CONTROLLER_SCALE`, `OPT_CONTROLLER_HINTS`, `BINDING_HEADER`, `BINDING_TOGGLE`, `BINDING_OPEN_TOP`, `BINDING_SNOOZE_TOP`, `BINDING_OPTIONS`, `SLASH_PANEL_HIDDEN`, `PAD_NONE`. **Step 4: Suite green.** **Step 5: Commit** — `git commit -m "feat: controller-aware panel — scale boost, pad hints, bindable actions"`

---

### Task 14: Game settings page

**Files:** Create `NewbieNudge/GameSettings.lua`, `tests/test_gamesettings.lua`; modify Options, stub (`ITEM_QUALITY*_DESC` if not yet), locales.

**Interfaces:**
- Produces: `NN.GameSettings = NN.CVarSection.New{ curated = <spec §23.1 rows with `{ header = ... }` entries between groups> }`, `GameSettings.PRESET` (CVar → value from the Preset column), `GameSettings:ApplyPreset() -> changed | nil` (nil and `L.GS_IN_COMBAT` message when `InCombatLockdown()`), `GameSettings:Reset()`.

- [ ] **Step 1: Failing tests**

```lua
local L = function() return NewbieNudge.L end
local function cvars(list) WOW.state.cvars = {} for n, v in pairs(list) do WOW.state.cvars[n] = { value = v.value or v.default, default = v.default } end end
return {
  preset_writes_its_table_and_skips_unknown = function()
    cvars({ autoLootDefault = { default = "0" }, statusTextDisplay = { default = "NONE" }, nameplateShowAll = { default = "0", value = "1" } })
    load_addon()
    local n = NewbieNudge.GameSettings:ApplyPreset()
    assert_eq(n, 2) -- autoLootDefault 0->1, statusTextDisplay NONE->BOTH; nameplateShowAll already 1; everything else unknown to this client
    assert_eq(C_CVar.GetCVar("autoLootDefault"), "1"); assert_eq(C_CVar.GetCVar("statusTextDisplay"), "BOTH")
    assert_nil(C_CVar.GetCVar("lootUnderMouse"))
  end,
  preset_refuses_in_combat = function()
    cvars({ autoLootDefault = { default = "0" } }); load_addon(); WOW.state.inCombat = true
    assert_nil(NewbieNudge.GameSettings:ApplyPreset())
    assert_true(WOW.printed[#WOW.printed]:find(L().GS_IN_COMBAT, 1, true)); assert_eq(C_CVar.GetCVar("autoLootDefault"), "0")
  end,
  page_has_groups_and_buttons = function()
    cvars({ autoLootDefault = { default = "0" } }); load_addon()
    local inits = {} for _, c in ipairs(WOW.calls) do if c[1] == "initializer" then inits[#inits + 1] = c end end
    local names = {} for _, c in ipairs(inits) do names[#names + 1] = c[2] .. ":" .. c[3] end
    for _, k in ipairs({ "GS_GROUP_LOOT", "GS_GROUP_NAMES", "GS_GROUP_COMBAT", "GS_GROUP_MOVE", "GS_GROUP_QUESTS" }) do assert_true(tContains(names, "header:" .. L()[k]), k) end
    assert_true(tContains(names, "button:" .. L().OPT_GS_PRESET)); assert_true(tContains(names, "button:" .. L().OPT_GS_RESET))
  end,
  dropdown_string_round_trip = function()
    cvars({ statusTextDisplay = { default = "NONE" } }); load_addon()
    WOW.settings["NN_cvar_statusTextDisplay"].setter("PERCENT")
    assert_eq(C_CVar.GetCVar("statusTextDisplay"), "PERCENT"); assert_eq(WOW.settings["NN_cvar_statusTextDisplay"].getter(), "PERCENT")
  end,
  no_discovery_section = function()
    cvars({ autoLootDefault = { default = "0" } }); load_addon()
    assert_eq(NewbieNudge.GameSettings:Discover(), {})
  end,
}
```

- [ ] **Step 2: Verify fail.** **Step 3: Implement** with the §23.1 table transcribed (labels as keys `GS_<CVAR>` / `GS_<CVAR>_TT`, group headers `GS_GROUP_LOOT/NAMES/COMBAT/MOVE/QUESTS`), `match = function() return false end` (no discovery), buttons `OPT_GS_PRESET = "Recommended for new players"`, `OPT_GS_RESET = "Reset these to game defaults"`, `GS_PRESET_DONE = "%d game settings changed."`, `GS_IN_COMBAT = "Can't change game settings in combat. Try again after the fight."`. Page title `OPT_GAME_SETTINGS = "Game settings"`. **Step 4: Suite green.** **Step 5: Commit** — `git commit -m "feat: game settings page with a new-player preset"`

---

### Task 15: Icy Veins import and talent-link parsing

**Files:** Create `tools/import_icy_talents.py`, `tests/test_import_icy_talents.py`, `NewbieNudge/Data/IcyTalents.lua` (generated), `NewbieNudge/TalentBuild.lua`, `tests/test_talentbuild.lua`, `tests/fixtures/icy_talents.lua`; modify TOC (already listed), Core defaults (`build = nil` is implicit), README (refresh command), locales.

**Interfaces:**
- Python: `import_icy_talents.compatible_versions(index: dict) -> list[str]` (sorted newest first by `created`; include every version up to and including the newest with `layoutChanged` true); `import_icy_talents.transform(index, class_jsons: dict[str, dict], date) -> str` (Lua text); `main(argv)` (`--out NewbieNudge/Data/IcyTalents.lua`), downloads `index.json` and `<latest>/<slug>.json` for the nine Forever classes (`warrior paladin hunter rogue priest shaman mage warlock druid`).
- Lua: `NN.IcyTalents = { version=, compatible = { [v]=true }, CLASS = { [urlId] = { node=, spell=, maxRank= } } }`; `NN.TalentBuild.Parse(text, playerClass) -> build | nil, reason` with `build = { class=, version=, picks = { urlId, ... }, warning = nil|"old_version" }` and reasons `"no_link"`, `"unknown_talent"`, `"wrong_class"`, `"too_many_points"`; `NN.TalentBuild:Set(text)` (stores `db.build`, says `BUILD_SET:format(#picks)` or the reason text), `NN.TalentBuild:Clear()`, `NN.TalentBuild:Status() -> string`.

- [ ] **Step 1: Python failing test**

```python
import sys, os, unittest, json
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))); sys.path.insert(0, os.path.join(ROOT, "tools"))
import import_icy_talents as it
INDEX = { "product": "wowf", "latest": "3-c", "versions": [
  { "version": "1-a", "created": "2026-11-01", "layoutChanged": True }, { "version": "2-b", "created": "2026-11-10", "layoutChanged": True },
  { "version": "3-c", "created": "2026-11-17", "layoutChanged": False } ] }
PRIEST = { "class": "Priest", "slug": "priest", "classId": 5, "talentGroups": [
  { "name": "Discipline", "slug": "discipline", "talents": [ { "name": "Power in Light", "nodeId": 101, "urlId": "0", "maxRank": 5, "ranks": [ { "id": 1309969 }, { "id": 1309970 } ] }, None ] },
  { "name": "Shadow", "slug": "shadow", "talents": [ { "name": "Spirit Tap", "nodeId": 301, "urlId": "B", "maxRank": 5, "ranks": [ { "id": 15270 } ] } ] } ] }
class T(unittest.TestCase):
    def test_compatible_versions_back_to_last_layout_change(self):
        self.assertEqual(it.compatible_versions(INDEX), ["3-c", "2-b"])
    def test_transform_lua(self):
        lua = it.transform(INDEX, { "priest": PRIEST }, date="d")
        self.assertIn('version = "3-c"', lua); self.assertIn('["2-b"] = true', lua); self.assertNotIn('["1-a"]', lua)
        self.assertIn('PRIEST = {', lua); self.assertIn('["0"] = { node = 101, spell = 1309969, maxRank = 5 }', lua); self.assertIn('["B"] = { node = 301, spell = 15270, maxRank = 5 }', lua)
        self.assertTrue(lua.startswith("-- Generated by tools/import_icy_talents.py")); self.assertIn("icy-veins.com", lua)
    def test_deterministic(self):
        self.assertEqual(it.transform(INDEX, { "priest": PRIEST }, date="d"), it.transform(INDEX, { "priest": PRIEST }, date="d"))
if __name__ == "__main__": unittest.main()
```
Run: `python -m unittest tests/test_import_icy_talents.py -v` → FAIL (module missing). Implement with `urllib.request`, `json`; header: generated-by, source URLs, version, date, "Identifiers only; talent data © Icy Veins (Vedatis S.A.S.)". Then run `python tools/import_icy_talents.py` to generate the data file (ask the user to run it if the session refuses network access). Re-run the Python test → OK.

- [ ] **Step 2: Lua fixture and failing tests**

`tests/fixtures/icy_talents.lua`:
```lua
local _, NN = ...
NN.IcyTalents = { version = "3-c", compatible = { ["3-c"] = true, ["2-b"] = true },
  MAGE = { ["1"] = { node = 11, spell = 1001, maxRank = 2 }, ["B"] = { node = 12, spell = 1002, maxRank = 5 }, ["z"] = { node = 13, spell = 1003, maxRank = 1 } } }
```
`tests/test_talentbuild.lua`:
```lua
local function setup() WOW.extraFiles = { TESTS_DIR .. "/fixtures/icy_talents.lua" } end
local P = function(t, c) return NewbieNudge.TalentBuild.Parse(t, c or "MAGE") end
return {
  parses_full_url_fragment_and_bare = function()
    setup(); load_addon()
    local url = "https://www.icy-veins.com/wow-forever/mage-talent-calculator#tc-11BBz~3-c"
    local b = P(url)
    assert_eq(b.class, "MAGE"); assert_eq(b.version, "3-c"); assert_eq(b.picks, { "1", "1", "B", "B", "z" }); assert_nil(b.warning)
    assert_eq(P("#tc-11BBz~3-c").picks, b.picks); assert_eq(P("tc-11BBz~3-c").picks, b.picks); assert_eq(P("11BBz~3-c").picks, b.picks)
  end,
  rejects_unknown_talent_wrong_class_and_no_link = function()
    setup(); load_addon()
    local b, why = P("#tc-11Q~3-c"); assert_nil(b); assert_eq(why, "unknown_talent")
    b, why = P("https://www.icy-veins.com/wow-forever/priest-talent-calculator#tc-11~3-c"); assert_nil(b); assert_eq(why, "wrong_class")
    b, why = P("hello"); assert_nil(b); assert_eq(why, "no_link")
  end,
  rejects_more_points_than_max_rank = function()
    setup(); load_addon()
    local b, why = P("#tc-111~3-c"); assert_nil(b); assert_eq(why, "too_many_points")
  end,
  old_version_warns_but_loads = function()
    setup(); load_addon()
    local b = P("#tc-1B~1-a"); assert_eq(b.warning, "old_version"); assert_eq(#b.picks, 2)
  end,
  set_and_clear_store_in_db_and_say = function()
    setup(); load_addon()
    NewbieNudge.TalentBuild:Set("#tc-11B~3-c")
    assert_eq(NewbieNudge.db.build.picks, { "1", "1", "B" }); assert_eq(NewbieNudge.db.build.version, "3-c")
    assert_true(WOW.printed[#WOW.printed]:find(NewbieNudge.L.BUILD_SET:format(3), 1, true))
    NewbieNudge.TalentBuild:Set("#tc-Q~3-c")
    assert_eq(#NewbieNudge.db.build.picks, 3, "a bad link does not clear the good one")
    assert_true(WOW.printed[#WOW.printed]:find(NewbieNudge.L.BUILD_ERR_UNKNOWN_TALENT, 1, true))
    NewbieNudge:HandleSlash("build clear"); assert_nil(NewbieNudge.db.build)
    NewbieNudge:HandleSlash("build #tc-1~3-c"); assert_eq(#NewbieNudge.db.build.picks, 1)
  end,
}
```
Run: `python tests/run.py talentbuild` → FAIL.

- [ ] **Step 3: Implement `TalentBuild.lua` (parsing, storage, slash) — the rule comes in Task 16.** Parsing: find `tc%-([%w]+)` after optional `#`, else if the whole trimmed text matches `^[%w]+~` treat it as bare; class from `(%a+)%-talent%-calculator`; version from `~([%w%-]+)$` (strip trailing `-[0-9a-f]+` is NOT done: the full `70938-3ee47080` is the version string). Locale keys: `BUILD_SET = "Talent build set: %d points. The panel will show the next talent."`, `BUILD_CLEARED`, `BUILD_ERR_NO_LINK`, `BUILD_ERR_UNKNOWN_TALENT`, `BUILD_ERR_WRONG_CLASS`, `BUILD_ERR_TOO_MANY`, `BUILD_WARN_OLD`, `BUILD_STATUS_NONE`, `BUILD_STATUS = "%s build, %d points, %d taken."`. Slash `build <text>` / `build clear`; add to `SLASH_HELP`.

- [ ] **Step 4: Suite green.** **Step 5: Commit** — `git commit -m "feat: Icy Veins talent data import and talent-link parsing"`

---

### Task 16: `talent_build` rule, node highlight, options page

**Files:** Modify `NewbieNudge/TalentBuild.lua`, `Highlight.lua`, `Options.lua` (page "Talent build" with StaticPopup), stub, locales, `tests/test_talentbuild.lua`, `tests/test_highlight.lua`.

**Interfaces:**
- Produces: `NN.TalentBuild.NextPick(picks, ranksByNode, data) -> index|nil, urlId, entry` (pure), `NN.TalentBuild.Differs(picks, nextIndex, ranksByNode, data) -> bool`; rule `talent_build`; highlight form `{ key = "talents", node = nodeID }`; `Highlight:ButtonForNode(nodeID)`; `StaticPopupDialogs.NEWBIENUDGE_BUILD`.

- [ ] **Step 1: Stub**

`C_Traits.GetTreeNodes(treeID)` → sorted keys of `S().talents.nodes` (`{ [nodeID] = { ranks = 0, maxRanks = 5, spellID = , name = } }`); `C_Traits.GetNodeInfo(configID, nodeID)` → `{ ID = nodeID, ranksPurchased = n.ranks, activeRank = n.ranks, maxRanks = n.maxRanks, entryIDs = { nodeID * 10 } }`; `C_Traits.GetEntryInfo(configID, entryID)` → `{ definitionID = entryID }`; `C_Traits.GetDefinitionInfo(defID)` → `{ spellID = nodes[defID / 10].spellID }`; `WOW.NewTalentFrame()` creates `PlayerSpellsFrame = { TalentsFrame = frame }` with `frame.buttons = {}` and `function frame:GetTalentButtonByNodeID(id) return self.buttons[id] end`, adding a button per node in state; `StaticPopupDialogs = {}`; `StaticPopup_Show(which)` records and returns `{ editBox = CreateFrame("EditBox") }`; `OKAY, CANCEL = "Okay", "Cancel"`.

- [ ] **Step 2: Failing tests** (append to `test_talentbuild.lua`)

```lua
  next_pick_walks_build_order = function()
    setup(); load_addon()
    local data = NewbieNudge.IcyTalents.MAGE
    local picks = { "1", "1", "B", "B", "z" }
    local idx, url = NewbieNudge.TalentBuild.NextPick(picks, {}, data); assert_eq(idx, 1); assert_eq(url, "1")
    idx, url = NewbieNudge.TalentBuild.NextPick(picks, { [11] = 2, [12] = 1 }, data); assert_eq(idx, 4); assert_eq(url, "B")
    idx = NewbieNudge.TalentBuild.NextPick(picks, { [11] = 2, [12] = 2, [13] = 1 }, data); assert_nil(idx)
    idx, url = NewbieNudge.TalentBuild.NextPick(picks, { [12] = 2, [13] = 1 }, data); assert_eq(idx, 1, "skipped talent comes back first")
  end,
  rule_row_with_name_rank_and_node_highlight = function()
    setup(); WOW.state.level = 12; WOW.state.talents = { configID = 1, treeID = 10, unspent = 1, nodes = { [11] = { ranks = 1, maxRanks = 2, spellID = 1001 }, [12] = { ranks = 0, maxRanks = 5, spellID = 1002 }, [13] = { ranks = 0, maxRanks = 1, spellID = 1003 } } }
    WOW.state.spellInfo[1001] = { name = "Arcane Subtlety" }
    load_addon(); NewbieNudge.TalentBuild:Set("#tc-11BBz~3-c"); WOW.FireEvent("TRAIT_CONFIG_UPDATED"); run_checks()
    local r = results_of("talent_build")
    assert_eq(r[1].text, NewbieNudge.L.BUILD_NEXT_ROW:format("Arcane Subtlety", 2, 2))
    assert_eq(r[1].highlight, { key = "talents", node = 11 })
    assert_eq(#r, 1)
  end,
  no_row_without_unspent_points_or_when_done = function()
    setup(); WOW.state.level = 12; WOW.state.talents = { configID = 1, treeID = 10, unspent = 0, nodes = { [11] = { ranks = 0, maxRanks = 2, spellID = 1001 } } }
    load_addon(); NewbieNudge.TalentBuild:Set("#tc-1~3-c"); WOW.FireEvent("TRAIT_CONFIG_UPDATED"); run_checks()
    assert_eq(#results_of("talent_build"), 0)
    WOW.state.talents.unspent = 1; WOW.state.talents.nodes[11].ranks = 1; WOW.FireEvent("TRAIT_NODE_CHANGED"); run_checks()
    assert_eq(#results_of("talent_build"), 0, "build complete")
  end,
  differs_row_when_player_went_off_build = function()
    setup(); WOW.state.level = 12; WOW.state.talents = { configID = 1, treeID = 10, unspent = 1, nodes = { [11] = { ranks = 0, maxRanks = 2, spellID = 1001 }, [13] = { ranks = 1, maxRanks = 1, spellID = 1003 } } }
    WOW.state.spellInfo[1001] = { name = "A" }
    load_addon(); NewbieNudge.TalentBuild:Set("#tc-11~3-c"); WOW.FireEvent("TRAIT_CONFIG_UPDATED"); run_checks()
    local r = results_of("talent_build"); assert_eq(#r, 2); assert_eq(r[2].text, NewbieNudge.L.BUILD_DIFFERS_ROW)
  end,
  not_applicable_without_build_or_below_ten = function()
    setup(); WOW.state.level = 12; load_addon()
    assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.talent_build))
    NewbieNudge.TalentBuild:Set("#tc-1~3-c"); wipe(NewbieNudge.appliesCache)
    assert_true(NewbieNudge:Applies(NewbieNudge.ruleByName.talent_build))
    WOW.state.level = 9; wipe(NewbieNudge.appliesCache); assert_true(not NewbieNudge:Applies(NewbieNudge.ruleByName.talent_build))
  end,
  options_popup_sets_build = function()
    setup(); load_addon()
    local inits = {} for _, c in ipairs(WOW.calls) do if c[1] == "initializer" and c[2] == "button" and c[3] == NewbieNudge.L.OPT_BUILD_PASTE then inits[#inits + 1] = c end end
    assert_eq(#inits, 1)
    local dialog = StaticPopupDialogs.NEWBIENUDGE_BUILD
    assert_true(dialog and dialog.hasEditBox)
    local fake = { editBox = CreateFrame("EditBox") }; fake.editBox:SetText("#tc-1B~3-c")
    dialog.OnAccept(fake)
    assert_eq(#NewbieNudge.db.build.picks, 2)
  end,
```
Append to `test_highlight.lua`:
```lua
  node_highlight_glows_talent_button_when_frame_exists = function()
    WOW.state.talents.nodes = { [11] = { ranks = 0, maxRanks = 2, spellID = 1 } }
    load_addon(); WOW.NewTalentFrame()
    NewbieNudge.Highlight:Apply({ { rule = { name = "r" }, result = { text = "t", highlight = { key = "talents", node = 11 } }, stale = false } })
    local shown = {} for _, c in ipairs(WOW.calls) do if c[1] == "glow_show" then shown[c[2]] = true end end
    assert_true(shown[PlayerSpellsMicroButton]); assert_true(shown[PlayerSpellsFrame.TalentsFrame.buttons[11]])
  end,
```

- [ ] **Step 3: Verify fail.** **Step 4: Implement** per spec §24.4–24.5: rule events `TRAIT_TREE_CURRENCY_INFO_UPDATED, TRAIT_CONFIG_UPDATED, TRAIT_NODE_CHANGED, PLAYER_TALENT_UPDATE, PLAYER_LEVEL_UP`; unspent via the same currency lookup as `Rules/Talents.lua` (extract `NN.UnspentTalentPoints()` there and reuse); `BUILD_NEXT_ROW = "Next talent: %s (%d/%d)."`, `BUILD_DIFFERS_ROW = "Your talents differ from the build; the suggestion follows the build's order."`; icon 136116; onClick opens talents. Options page "Talent build": header initializer with `TalentBuild:Status()`, buttons `OPT_BUILD_PASTE = "Paste an Icy Veins talent calculator link"` (→ `StaticPopup_Show("NEWBIENUDGE_BUILD")`) and `OPT_BUILD_CLEAR`, with `OPT_BUILD_HELP` text ("open the guide, pick a build, click Open in Calculator, copy the address") as the paste button's tooltip. Highlight: `node` kind resolved through `PlayerSpellsFrame.TalentsFrame` or `ClassTalentFrame.TalentsTab` (`GetTalentButtonByNodeID`), cache cleared on `TRAIT_NODE_CHANGED` and on the frame's `OnShow` (hook once when first seen). **Step 5: Suite green.** **Step 6: Commit** — `git commit -m "feat: talent_build — next talent from an Icy Veins build, glowed in the talent window"`

---

### Task 17: Docs, version, checklist, final run

**Files:** Modify `README.md`, `docs/testing-checklist.md`, `NewbieNudge/NewbieNudge.toc` (`## Version: 0.2.0`), `NewbieNudge/Locales/esES.lua` (final parity sweep).

- [ ] **Step 1: README** — Features list (v1 + the seven v2 items in one line each), Commands table (`map`, `trash`, `build <link>`, `build clear`), "Playing with a controller" paragraph (presets, bindings, hints), "Talent builds from Icy Veins" paragraph (the one-sentence instruction), "Refreshing game data" (both commands), "Credits and licence".
- [ ] **Step 2: Checklist** — mark as confirmed on 2026-11-20 (warrior, enUS): `GetProfessionInfo` caps per rank (`Blacksmithing 22 75`); `GetQuestObjectives` entries `{ type="item", text="0/4 Venomtail Poison Sac", numFulfilled, numRequired, finished }`; `UnitQuestTrivialLevelRange("player") = 5` and `C_QuestLog.IsQuestTrivial` present; `GetRealZoneText(36) = "Deadmines"`; `C_GamePad.IsEnabled() = true`; bag inventory slots 31–34, materials slot 35 (`ContainerIDToInventoryID`). §0 adds a block per feature listing the `/dump` lines from spec §20 and §13.5/§24.4, and a "presets" block; §2 adds appear/disappear lines for each new rule; §1 adds the bag-full frame, the map toggle and the build popup.
- [ ] **Step 3: Full suite and a grep for untranslated keys**

Run: `python tests/run.py` → all PASS. Run: `grep -c '= "' NewbieNudge/Locales/enUS.lua NewbieNudge/Locales/esES.lua` → equal counts (parity test already enforces the key set).
- [ ] **Step 4: Commit** — `git commit -m "docs: v0.2.0 — README, checklist, version bump"`

---

## Self-review notes

- Spec coverage: §11 → T1; §12 → T3; §13.1 → T8; §13.2 → T9; §13.3/13.4 → T10; §13.5 → T7; §14.0 → T6; §14.1–14.3 → T4; §14.4 → T5; §15 → T11; §16 → T2 (+ each page in its task); §17.1 → T12; §17.2 → T13; §18 → defaults added per task; §19 → every task's locale step; §20 → tests per task + T17 checklist; §23 → T14; §24 → T15–T16.
- Names used across tasks: `Options.RegisterPage`, `Options.AddSubcategory`, `Options.AddDropdown`, `NN.CVarSection.New`, `section:AddControls/Apply/Discover/ResetCurated/Get/GetString/Set`, `NN.QuestScan`, `NN.RegularFreeSlots`, `NN.BagInventorySlot`, `NN.ContainerSlots`, `NN.UnspentTalentPoints`, `Highlight:TargetsFor`, `Controller:PadLabel/HintButtons/Boost/ApplyPreset`, `Panel.STRIP_ICON/ToggleHidden/OpenTop/SnoozeTop`, `TalentBuild.Parse/NextPick/Differs/Set/Clear/Status` — each defined in exactly one task and consumed later by that name.
- Review Focus tests are pinned: T3 `layer_fallback_to_first`, T5 `objective_name_both_orders`, T11 `uncached_item_skipped_then_refreshed`, T15 `rejects_more_points_than_max_rank`, T13 `hint_falls_back_to_raw_token`.
