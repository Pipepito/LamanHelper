-- CVarSection: a page section of console variables (CVars) the game exposes
-- but Blizzard's own settings window does not show. One instance per page
-- (Camera, Controller, Game settings). Values live in the game's config,
-- not in the addon's saved variables.
--
-- spec = {
--   curated = { { header = "LOCALE_KEY" },
--               { cvar =, kind = "checkbox"|"slider"|"dropdown", label = "KEY", help = "KEY",
--                 min =, max =, step =,                  -- slider
--                 options = { { "value", "LABEL_KEY" } } -- dropdown
--               }, ... },
--   exclude = { [cvar] = true },          -- never offered by discovery
--   match = function(name) -> bool,       -- discovery filter
--   note = "KEY" or nil,                  -- appended to every curated tooltip
--   otherHeader = "KEY" or nil,           -- header for discovered variables
--   resetLabel = "KEY" or nil,            -- the "reset to defaults" button
-- }
local _, NN = ...
local L = NN.L

local CVarSection = {}
CVarSection.__index = CVarSection
NN.CVarSection = CVarSection

local function getCVar(name)
  if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
  if GetCVar then return GetCVar(name) end
  return nil
end

local function getDefault(name)
  if C_CVar and C_CVar.GetCVarDefault then return C_CVar.GetCVarDefault(name) end
  if GetCVarDefault then return GetCVarDefault(name) end
  return nil
end

-- "2" rather than "2.0", and no float noise.
local function toText(value)
  if type(value) == "number" then
    return (string.format("%.4f", value):gsub("0+$", ""):gsub("%.$", ""))
  end
  return tostring(value)
end

function CVarSection.New(spec)
  local self = setmetatable({}, CVarSection)
  self.CURATED = spec.curated or {}
  self.EXCLUDE = spec.exclude or {}
  self.match = spec.match or function() return false end
  self.note, self.otherHeader, self.resetLabel = spec.note, spec.otherHeader, spec.resetLabel
  self.curatedSet = {}
  for _, entry in ipairs(self.CURATED) do
    if entry.cvar then self.curatedSet[entry.cvar] = true end
  end
  return self
end

function CVarSection:GetString(cvar)
  return NN.Plain(getCVar(cvar), "string")
end

function CVarSection:Get(cvar)
  local raw = self:GetString(cvar)
  if raw == nil then return nil end
  return tonumber(raw)
end

-- Secure CVars cannot be written in combat; refuse every write then.
local function inCombat()
  return InCombatLockdown and InCombatLockdown() == true
end

function CVarSection:Set(cvar, value)
  if inCombat() then NN:Say(L.CVAR_IN_COMBAT); return false end
  local text = toText(value)
  if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar(cvar, text) elseif SetCVar then SetCVar(cvar, text) end
  return true
end

function CVarSection:ResetCurated()
  for _, entry in ipairs(self.CURATED) do
    if entry.cvar then
      local default = getDefault(entry.cvar)
      if default ~= nil then self:Set(entry.cvar, default) end
    end
  end
end

-- Writes every value of tbl whose CVar the client knows; returns how many
-- actually changed.
function CVarSection:Apply(tbl)
  if inCombat() then NN:Say(L.CVAR_IN_COMBAT); return 0 end
  local changed = 0
  local names = {}
  for cvar in pairs(tbl) do names[#names + 1] = cvar end
  table.sort(names)
  for _, cvar in ipairs(names) do
    if getDefault(cvar) ~= nil then
      local text = toText(tbl[cvar])
      if self:GetString(cvar) ~= text then
        self:Set(cvar, text)
        changed = changed + 1
      end
    end
  end
  return changed
end

-------------------------------------------------------------------------------
-- Discovery
-------------------------------------------------------------------------------

local function classify(self, cvar, help)
  local default = NN.Plain(getDefault(cvar), "string")
  local current = self:Get(cvar)
  local defaultNumber = tonumber(default)
  if defaultNumber == nil then return nil end
  if default == "0" or default == "1" then
    return { cvar = cvar, help = help, default = defaultNumber, current = current, kind = "checkbox" }
  end
  local max = math.max(1, defaultNumber * 2, current or 0)
  local step = default:find("%.") and 0.1 or 1
  return { cvar = cvar, help = help, default = defaultNumber, current = current, kind = "slider", min = 0, max = max, step = step }
end

function CVarSection:Discover()
  local found = {}
  if not (C_Console and C_Console.GetAllCommands) then return found end
  local cvarType = Enum and Enum.ConsoleCommandType and Enum.ConsoleCommandType.Cvar or 0
  for _, cmd in ipairs(C_Console.GetAllCommands() or {}) do
    local name = NN.Plain(cmd.command, "string")
    if name and cmd.commandType == cvarType and self.match(name)
      and not self.curatedSet[name] and not self.EXCLUDE[name] then
      local entry = classify(self, name, NN.Plain(cmd.help, "string") or "")
      if entry then found[#found + 1] = entry end
    end
  end
  table.sort(found, function(a, b) return a.cvar < b.cvar end)
  return found
end

-------------------------------------------------------------------------------
-- Controls
-------------------------------------------------------------------------------

function CVarSection:AddControl(category, entry, label, tooltip)
  local variable = "NN_cvar_" .. entry.cvar
  local cvar = entry.cvar
  if entry.kind == "checkbox" then
    NN.Options.AddCheckbox(category, variable, label, tooltip,
      function() return self:Get(cvar) == 1 end,
      function(value) self:Set(cvar, value and 1 or 0) end)
  elseif entry.kind == "dropdown" then
    local options, known = {}, {}
    for _, pair in ipairs(entry.options or {}) do
      local value, labelKey = tostring(pair[1]), pair[2]
      options[#options + 1] = { value = value, label = (pair.rawLabel and labelKey) or L[labelKey] or labelKey }
      known[value] = true
    end
    local current = self:GetString(cvar)
    if current and not known[current] then options[#options + 1] = { value = current, label = current } end
    NN.Options.AddDropdown(category, variable, label, tooltip, options,
      function() return self:GetString(cvar) or (options[1] and options[1].value) or "" end,
      function(value) self:Set(cvar, tostring(value)) end)
  else
    NN.Options.AddSlider(category, variable, label, tooltip, entry.min, entry.max, entry.step,
      function() return self:Get(cvar) or entry.min end,
      function(value) self:Set(cvar, value) end)
  end
end

-- entries defaults to the curated list; a caller may pass a transformed copy.
function CVarSection:AddControls(category, layout, entries)
  local note = self.note and ("\n\n|cff999999" .. L[self.note] .. "|r") or ""
  for _, entry in ipairs(entries or self.CURATED) do
    if entry.header then
      NN.Options.AddHeader(layout, L[entry.header])
    else
      self:AddControl(category, entry, L[entry.label], L[entry.help] .. note)
    end
  end
  if self.resetLabel then
    NN.Options.AddButton(layout, L[self.resetLabel], L.OPT_BUTTON_DO, function() self:ResetCurated() end)
  end
  local discovered = self:Discover()
  if #discovered > 0 then
    if self.otherHeader then NN.Options.AddHeader(layout, L[self.otherHeader]) end
    for _, entry in ipairs(discovered) do
      self:AddControl(category, entry, entry.cvar, entry.help ~= "" and entry.help or entry.cvar)
    end
  end
end
