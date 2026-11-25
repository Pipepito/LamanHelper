-- Options: every NewbieNudge setting, described as plain data for
-- NewbieNudge's own settings window (SettingsWindow.lua; Esc menu >
-- NewbieNudge). Nothing is registered in the game's Settings window: its
-- commit tainted Forever's controller interface, and its AddOns list needs a
-- mouse. Every control reads and writes NewbieNudgeDB (or a game CVar)
-- through its getter and setter, so there is no second copy to keep in sync.
--
-- Pages are functions that call the Add* helpers below; Options.Model runs
-- them and collects what they add. The (category, layout) arguments are kept
-- so page code reads the same as before; they are always nil.
local _, NN = ...
local L = NN.L

local Options = { pages = {} }
NN.Options = Options

local function record(entry)
  local list = Options.recorder
  if list then list[#list + 1] = entry end
end

function Options.AddHeader(_, name)
  record({ kind = "header", label = name })
end

function Options.AddButton(_, name, buttonText, onClick, tooltip)
  record({ kind = "button", label = name, buttonText = buttonText, onClick = onClick, tooltip = tooltip })
end

function Options.AddCheckbox(_, variable, name, tooltip, getter, setter)
  record({ kind = "checkbox", var = variable, label = name, tooltip = tooltip, get = getter, set = setter })
end

function Options.AddSlider(_, variable, name, tooltip, min, max, step, getter, setter)
  record({ kind = "slider", var = variable, label = name, tooltip = tooltip, min = min, max = max, step = step,
    get = getter, set = setter })
end

function Options.AddDropdown(_, variable, name, tooltip, options, getter, setter)
  record({ kind = "dropdown", var = variable, label = name, tooltip = tooltip, options = options,
    get = getter, set = setter })
end

-- Page order in the settings window. Registered pages whose key is not here
-- follow, in registration order.
Options.PAGE_ORDER = { "reminders", "bags", "map", "gs_combat", "gs_names", "gs_interface", "camera", "controller", "build", "dev" }

-- A game-settings header inside a page that mixes addon and game options.
function Options.AddGameSettingsHeader(layout)
  Options.AddHeader(layout, L.OPT_GS_HEADER)
end

-- Modules register their page before login; pages are built in order after
-- the Reminders section and the Camera page.
function Options.RegisterPage(key, titleKey, build)
  Options.pages[#Options.pages + 1] = { key = key, titleKey = titleKey, build = build }
end

-- The Reminders page: one checkbox per rule under its group's header,
-- groups in NN.RULE_GROUPS order, rules by NN.PRIORITY inside a group.
function Options.BuildReminders(category, layout)
  local db = NN.db
  local priority = {}
  for i, name in ipairs(NN.PRIORITY) do priority[name] = i end
  local byGroup = {}
  for i, rule in ipairs(NN.rules) do
    local list = byGroup[rule.group] or {}
    byGroup[rule.group] = list
    list[#list + 1] = { rule = rule, order = priority[rule.name] or (1000 + i) }
  end
  for _, group in ipairs(NN.RULE_GROUPS) do
    local list = byGroup[group]
    if list then
      table.sort(list, function(a, b) return a.order < b.order end)
      Options.AddHeader(layout, L["OPT_GROUP_" .. group:upper()])
      for _, entry in ipairs(list) do
        local rule = entry.rule
        local name = rule.name
        local tooltip = rule.help
        if not NN:Applies(rule) then tooltip = tooltip .. "\n\n|cff999999" .. L.OPT_NOT_RELEVANT .. "|r" end
        Options.AddCheckbox(category, "NN_rule_" .. name, rule.title, tooltip,
          function() return not db.disabled[name] end,
          function(value) NN:SetRuleEnabled(name, value and true or false) end)
        if rule.options then rule.options(category, layout) end
      end
    end
  end
end

-- Registered pages (plus Reminders and Camera) in PAGE_ORDER, then the rest.
function Options.OrderedPages()
  local byKey, used, out = {}, {}, {}
  byKey.reminders = { key = "reminders", titleKey = "OPT_REMINDERS", build = Options.BuildReminders }
  if NN.Camera and NN.Camera.AddToOptions then
    byKey.camera = { key = "camera", titleKey = "OPT_CAMERA", build = function(c, l) NN.Camera:AddToOptions(c, l) end }
  end
  for _, page in ipairs(Options.pages) do byKey[page.key] = byKey[page.key] or page end
  for _, key in ipairs(Options.PAGE_ORDER) do
    if byKey[key] then out[#out + 1] = byKey[key]; used[key] = true end
  end
  for _, page in ipairs(Options.pages) do
    if not used[page.key] then out[#out + 1] = page; used[page.key] = true end
  end
  return out
end

-- The top page: panel, info bar, minimap button, new player setup.
function Options.BuildGeneral(category, layout)
  local db = NN.db
  Options.AddHeader(layout, L.OPT_GENERAL)
  Options.AddCheckbox(category, "NN_lock", L.OPT_LOCK, L.OPT_LOCK_TT,
    function() return db.panel.locked end,
    function(value) db.panel.locked = value and true or false; if NN.Panel then NN.Panel:SetLocked(db.panel.locked) end end)
  Options.AddDropdown(category, "NN_panel_style", L.OPT_STYLE, L.OPT_STYLE_TT,
    { { value = "list", label = L.OPT_STYLE_LIST }, { value = "icons", label = L.OPT_STYLE_ICONS } },
    function() return db.panel.style or "list" end,
    function(value) if NN.Panel then NN.Panel:SetStyle(value) else db.panel.style = value end end)
  Options.AddSlider(category, "NN_scale", L.OPT_SCALE, nil, 0.8, 1.5, 0.1,
    function() return db.panel.scale end,
    function(value) db.panel.scale = value; if NN.Panel then NN.Panel:ApplyScale() end end)
  Options.AddSlider(category, "NN_snooze", L.OPT_SNOOZE, nil, 15, 240, 15,
    function() return db.snoozeMinutes end,
    function(value) db.snoozeMinutes = value end)
  Options.AddCheckbox(category, "NN_combatStrip", L.OPT_COMBAT_STRIP, L.OPT_COMBAT_STRIP_TT,
    function() return db.combatStrip end,
    function(value) db.combatStrip = value and true or false; if NN.Panel then NN.Panel:Refresh(NN:ActiveRows()) end end)
  local function relayout() if NN.Panel then NN.Panel:Refresh(NN:ActiveRows()) end end
  Options.AddSlider(category, "NN_panel_iconsPerLine", L.OPT_ICONS_PER_LINE, nil, 1, 12, 1,
    function() return db.panel.iconsPerLine end, function(value) db.panel.iconsPerLine = value; relayout() end)
  Options.AddDropdown(category, "NN_panel_iconFlow", L.OPT_ICON_FLOW, L.OPT_ICON_FLOW_TT,
    { { value = "rows", label = L.OPT_ICON_FLOW_ROWS }, { value = "columns", label = L.OPT_ICON_FLOW_COLUMNS } },
    function() return db.panel.iconFlow or "rows" end, function(value) db.panel.iconFlow = value; relayout() end)
  Options.AddSlider(category, "NN_panel_iconSize", L.OPT_ICON_SIZE, nil, 16, 40, 2,
    function() return db.panel.iconSize end, function(value) db.panel.iconSize = value; relayout() end)
  Options.AddSlider(category, "NN_panel_iconGap", L.OPT_ICON_GAP, nil, 0, 12, 1,
    function() return db.panel.iconGap end, function(value) db.panel.iconGap = value; relayout() end)
  Options.AddButton(layout, L.OPT_RESET_SNOOZE, L.OPT_BUTTON_DO, function() NN:ClearSnoozes() end)
  Options.AddButton(layout, L.OPT_RESET_POS, L.OPT_BUTTON_DO, function() if NN.Panel then NN.Panel:ResetPosition() end end)

  -- Info bar
  Options.AddHeader(layout, L.OPT_INFOBAR_HEADER)
  local function barBox(key, label, tooltip)
    Options.AddCheckbox(category, "NN_infobar_" .. key, label, tooltip,
      function() return db.infobar[key] end,
      function(value) db.infobar[key] = value and true or false; if NN.Panel then NN.Panel:Refresh(NN:ActiveRows()) end end)
  end
  barBox("enabled", L.OPT_INFOBAR, L.OPT_INFOBAR_TT)
  barBox("bags", L.OPT_INFOBAR_BAGS)
  barBox("gold", L.OPT_INFOBAR_GOLD)
  barBox("gear", L.OPT_INFOBAR_GEAR)

  -- Minimap button
  Options.AddHeader(layout, L.OPT_MINIMAP_HEADER)
  Options.AddCheckbox(category, "NN_minimap_show", L.OPT_MINIMAP, L.OPT_MINIMAP_TT,
    function() return not db.minimap.hide end,
    function(value)
      if NN.MinimapButton then NN.MinimapButton:SetShown(value and true or false) else db.minimap.hide = not value end
    end)

  -- New player setup: the game's recommended settings, all pages at once
  if NN.GameSettings then
    Options.AddHeader(layout, L.OPT_SETUP)
    Options.AddButton(layout, L.OPT_GS_PRESET, L.OPT_BUTTON_DO, function() NN.GameSettings:ApplyPreset() end, L.OPT_GS_PRESET_TT)
    Options.AddButton(layout, L.OPT_GS_RESET, L.OPT_BUTTON_DO, function() NN.GameSettings:Reset() end)
  end
end

-- Every page as plain data, for NewbieNudge's own settings window:
-- { { title, key, entries = { {kind = "header"|"checkbox"|"slider"|"dropdown"|"button", ...} } } }
-- Built fresh on each call so labels that change (build status) are current.
-- One broken page must not take the others down; it is reported once.
Options.reported = {}

function Options.Model()
  local pages = {}
  local function add(key, title, build)
    local entries = {}
    Options.recorder = entries
    local ok, err = pcall(build, nil, nil)
    Options.recorder = nil
    if not ok then
      if NN.db then NN.db.errors["options:" .. tostring(title)] = tostring(err) end
      if not Options.reported[title] then
        Options.reported[title] = true
        NN:Say(L.OPT_PAGE_ERROR:format(tostring(title), tostring(err)))
      end
    end
    if #entries > 0 then pages[#pages + 1] = { key = key, title = title, entries = entries } end
  end
  add("general", L.OPT_GENERAL, Options.BuildGeneral)
  for _, page in ipairs(Options.OrderedPages()) do add(page.key, L[page.titleKey] or page.key, page.build) end
  return pages
end

-- Opens NewbieNudge's settings window, on the page with that title if given.
function NN:OpenOptions(pageTitle)
  if NN.SettingsWindow then NN.SettingsWindow:Show(pageTitle) end
end
