-- Options: a page in Blizzard's Settings window (Escape > Options > AddOns).
-- Every control is a proxy straight onto NewbieNudgeDB, so there is no second
-- copy of the settings to keep in sync.
local _, NN = ...
local L = NN.L

local Options = { pages = {} }
NN.Options = Options

local function registerSetting(category, variable, vtype, name, default, getter, setter)
  if Settings.RegisterProxySetting then
    return Settings.RegisterProxySetting(category, variable, vtype, name, default, getter, setter)
  end
  -- Older clients: proxy through a one-key table whose __index/__newindex call us.
  local proxy = setmetatable({}, {
    __index = function() return getter() end,
    __newindex = function(_, _, value) setter(value) end,
  })
  return Settings.RegisterAddOnSetting(category, variable, "value", proxy, vtype, name, default)
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
function Options.AddSubcategory(name)
  local category, layout = Settings.RegisterVerticalLayoutSubcategory(Options.category, name)
  Options.subcategories = Options.subcategories or {}
  Options.subcategories[name] = category
  return category, layout
end

-- Modules register their page before login; pages are built in order after
-- the Reminders section and the Camera page.
function Options.RegisterPage(key, titleKey, build)
  Options.pages[#Options.pages + 1] = { key = key, titleKey = titleKey, build = build }
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
  Options.AddSlider(category, "NN_scale", L.OPT_SCALE, nil, 0.8, 1.5, 0.1,
    function() return db.panel.scale end,
    function(value) db.panel.scale = value; if NN.Panel then NN.Panel:ApplyScale() end end)
  Options.AddSlider(category, "NN_snooze", L.OPT_SNOOZE, nil, 15, 240, 15,
    function() return db.snoozeMinutes end,
    function(value) db.snoozeMinutes = value end)
  Options.AddCheckbox(category, "NN_combatStrip", L.OPT_COMBAT_STRIP, L.OPT_COMBAT_STRIP_TT,
    function() return db.combatStrip end,
    function(value) db.combatStrip = value and true or false; if NN.Panel then NN.Panel:Refresh(NN:ActiveRows()) end end)
  Options.AddButton(layout, L.OPT_RESET_SNOOZE, L.OPT_BUTTON_DO, function() NN:ClearSnoozes() end)
  Options.AddButton(layout, L.OPT_RESET_POS, L.OPT_BUTTON_DO, function() if NN.Panel then NN.Panel:ResetPosition() end end)

  -- Reminders
  Options.AddHeader(layout, L.OPT_REMINDERS)
  for _, rule in ipairs(NN.rules) do
    local name = rule.name
    local tooltip = rule.help
    if not NN:Applies(rule) then tooltip = tooltip .. "\n\n|cff999999" .. L.OPT_NOT_RELEVANT .. "|r" end
    Options.AddCheckbox(category, "NN_rule_" .. name, rule.title, tooltip,
      function() return not db.disabled[name] end,
      function(value) NN:SetRuleEnabled(name, value and true or false) end)
  end

  if NN.Camera and NN.Camera.AddToOptions and Settings.RegisterVerticalLayoutSubcategory then
    local cameraCategory, cameraLayout = Options.AddSubcategory(L.OPT_CAMERA)
    NN.Camera:AddToOptions(cameraCategory, cameraLayout)
  end
  if Settings.RegisterVerticalLayoutSubcategory then
    for _, page in ipairs(Options.pages) do
      local pageCategory, pageLayout = Options.AddSubcategory(L[page.titleKey])
      page.build(pageCategory, pageLayout)
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
