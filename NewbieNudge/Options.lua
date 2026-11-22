-- Options: a page in Blizzard's Settings window (Escape > Options > AddOns).
-- Every control is a proxy straight onto NewbieNudgeDB, so there is no second
-- copy of the settings to keep in sync.
local _, NN = ...
local L = NN.L

local Options = { pages = {} }
NN.Options = Options

-- The Settings API refuses a variable registered twice; the second page to
-- ask for one gets the first page's setting back instead of an error.
Options.registered = {}

local function registerSetting(category, variable, vtype, name, default, getter, setter)
  local existing = Options.registered[variable]
  if existing then return existing end
  local setting
  if Settings.RegisterProxySetting then
    setting = Settings.RegisterProxySetting(category, variable, vtype, name, default, getter, setter)
    Options.registered[variable] = setting
    return setting
  end
  -- Older clients: proxy through a one-key table whose __index/__newindex call us.
  local proxy = setmetatable({}, {
    __index = function() return getter() end,
    __newindex = function(_, _, value) setter(value) end,
  })
  setting = Settings.RegisterAddOnSetting(category, variable, "value", proxy, vtype, name, default)
  Options.registered[variable] = setting
  return setting
end

function Options.AddHeader(layout, name)
  layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(name))
end

function Options.AddButton(layout, name, buttonText, onClick, tooltip)
  layout:AddInitializer(CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, true))
end

function Options.AddCheckbox(category, variable, name, tooltip, getter, setter)
  local setting = registerSetting(category, variable, Settings.VarType.Boolean, name, getter() and true or false, getter, setter)
  Settings.CreateCheckbox(category, setting, tooltip)
  return setting
end

function Options.AddSlider(category, variable, name, tooltip, min, max, step, getter, setter)
  local setting = registerSetting(category, variable, Settings.VarType.Number, name, getter(), getter, setter)
  local sliderOptions = Settings.CreateSliderOptions(min, max, step)
  if MinimalSliderWithSteppersMixin and sliderOptions.SetLabelFormatter then
    sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
  end
  Settings.CreateSlider(category, setting, sliderOptions, tooltip)
  return setting
end

function Options.AddDropdown(category, variable, name, tooltip, options, getter, setter)
  local setting = registerSetting(category, variable, Settings.VarType.String, name, getter(), getter, setter)
  local function optionsFn()
    local container = Settings.CreateControlTextContainer()
    for _, option in ipairs(options) do container:Add(option.value, option.label) end
    return container:GetData()
  end
  Settings.CreateDropdown(category, setting, optionsFn, tooltip)
  return setting
end

-- A subcategory under the addon's page (Map, Bags, Camera, ...).
function Options.AddSubcategory(name, key)
  local category, layout = Settings.RegisterVerticalLayoutSubcategory(Options.category, name)
  Options.subcategories = Options.subcategories or {}
  Options.subcategories[name] = category
  if key then Options.subcategoriesByKey[key] = category end
  return category, layout
end
Options.subcategoriesByKey = {}

-- Page order in the AddOns list. Registered pages whose key is not here
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

function Options:Build()
  if self.category or not Settings or not Settings.RegisterVerticalLayoutCategory then return end
  local category, layout = Settings.RegisterVerticalLayoutCategory(L.ADDON_TITLE)
  self.category, self.layout = category, layout
  local db = NN.db

  -- General
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

  if Settings.RegisterVerticalLayoutSubcategory then
    for _, page in ipairs(Options.OrderedPages()) do
      local title = L[page.titleKey]
      local pageCategory, pageLayout = Options.AddSubcategory(title, page.key)
      -- One broken page must not take the whole options window down.
      local ok, err = pcall(page.build, pageCategory, pageLayout)
      if not ok then
        db.errors["options:" .. title] = tostring(err)
        NN:Say(L.OPT_PAGE_ERROR:format(title, tostring(err)))
      end
    end
  end

  Settings.RegisterAddOnCategory(category)
  NN.optionsCategoryID = category:GetID()
end

function NN:OpenOptions()
  if not Options.category then Options:Build() end
  if NN.optionsCategoryID and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(NN.optionsCategoryID)
  end
end

NN:AfterLogin(function() Options:Build() end)
