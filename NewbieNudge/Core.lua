-- Core: rule registry, saved variables, shared helpers.
-- Every other file receives the same `NN` table through the addon varargs.
local ADDON_NAME, NN = ...
_G.NewbieNudge = NN
local L = NN.L

NN.rules = {}
NN.ruleByName = {}
NN.results = {}      -- [name] = array of result tables (always an array)
NN.ruleState = {}    -- [name] = { disabled = bool, dirty = bool }
NN.appliesCache = {} -- [name] = bool
NN.rulesByEvent = {} -- [event] = { rule, ... }
NN.UNKNOWN = setmetatable({}, { __tostring = function() return "NewbieNudge.UNKNOWN" end })
NN.MAX_ROWS = 10
NN.CHECK_DELAY = 0.5
NN.TICK_SECONDS = 30
NN.PRIORITY = {
  "durability", "bag_unequipped", "materials_bag", "bag_full", "talents", "talent_build", "spell_ranks", "weapon_skill", "buffs", "ammo", "pet",
  "tracking", "hearthstone", "hearth_bind", "supplies", "quests", "quest_item", "quest_turnin", "quest_slots", "quest_soon", "quest_grey", "quest_group", "mail",
  "professions", "profession_rank", "trainer_spells", "mount", "legacy", "flight_path", "dungeon_ready", "zone_level", "gear_upgrade", "rested",
}
NN.testMode = false

NN.classFile = select(2, UnitClass("player"))
NN.isForever = (WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)

NN.defaults = {
  disabled = {},
  snoozed = {},
  panel = { point = "RIGHT", x = -40, y = 60, locked = true, scale = 1, hidden = false },
  combatStrip = true,
  snoozeMinutes = 60,
  errors = {},
  seen = { rules = {}, dungeons = {}, legacy = false },
  map = { reveal = true, brightness = 0.6, desaturate = true },
  bagfull = { enabled = true, maxQuality = 2, onLoot = true, point = "LEFT", x = 40, y = 0 },
  controller = { boost = true, scale = 1.25, hints = true },
  talentBadges = true,
  vendor = { sellJunk = true, repair = true },
  tooltipPrice = true,
}

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

-- Returns v when it is an ordinary value of the wanted type; nil for secret
-- values (combat restrictions) and for anything of another type.
function NN.Plain(v, kind)
  if issecretvalue and issecretvalue(v) then return nil end
  if type(v) ~= (kind or "number") then return nil end
  return v
end

function NN:Say(text)
  print(L.CHAT_PREFIX .. tostring(text))
end

-- Fills missing keys of tbl from defaults, recursively, without touching
-- values that already exist.
function NN.ApplyDefaults(tbl, defaults)
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      if type(tbl[key]) ~= "table" then tbl[key] = {} end
      NN.ApplyDefaults(tbl[key], value)
    elseif tbl[key] == nil then
      tbl[key] = value
    end
  end
  return tbl
end

-------------------------------------------------------------------------------
-- Rule registry
-------------------------------------------------------------------------------

local function invalid(rule, field)
  error(("NewbieNudge: invalid rule %s: %s"):format(tostring(rule and rule.name), field), 3)
end

function NN:RegisterRule(rule)
  if type(rule) ~= "table" then invalid(rule, "table") end
  if type(rule.name) ~= "string" or not rule.name:match("^[a-z_]+$") or self.ruleByName[rule.name] then
    invalid(rule, "name")
  end
  if type(rule.title) ~= "string" then invalid(rule, "title") end
  if type(rule.help) ~= "string" then invalid(rule, "help") end
  if type(rule.events) ~= "table" then invalid(rule, "events") end
  if type(rule.applies) ~= "function" then invalid(rule, "applies") end
  if type(rule.check) ~= "function" then invalid(rule, "check") end
  if rule.default == nil then rule.default = true end
  if rule.combat == nil then rule.combat = false end
  self.rules[#self.rules + 1] = rule
  self.ruleByName[rule.name] = rule
  self.ruleState[rule.name] = { disabled = false, dirty = true }
  self.results[rule.name] = {}
  self:RegisterRuleEvents(rule)
  if self.loggedIn then self:NoteRuleSeen(rule) end
  return rule
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

NN.events = CreateFrame("Frame")

local ALWAYS = {
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
}
local RECHECK_ALL = { PLAYER_ENTERING_WORLD = true, PLAYER_REGEN_ENABLED = true, PLAYER_LEVEL_UP = true }
local RESET_APPLIES = { PLAYER_LEVEL_UP = true, SPELLS_CHANGED = true, PLAYER_SPECIALIZATION_CHANGED = true, PLAYER_EQUIPMENT_CHANGED = true }

-- Registers one event name, or "EVENT:unit" through RegisterUnitEvent.
-- Unknown event names raise in the client; a bad name must not take the
-- whole rule file down, so registration is protected and simply skipped.
function NN:RegisterEvent(spec)
  local event, unit = spec:match("^([^:]+):(.+)$")
  local ok
  if event then
    if self.events.RegisterUnitEvent then
      ok = pcall(self.events.RegisterUnitEvent, self.events, event, unit)
    else
      ok = pcall(self.events.RegisterEvent, self.events, event)
    end
  else
    event = spec
    ok = pcall(self.events.RegisterEvent, self.events, event)
  end
  if not ok and self.db then self.db.errors["event:" .. event] = "unknown event" end
  return event
end

function NN:RegisterRuleEvents(rule)
  for _, spec in ipairs(rule.events) do
    local event = self:RegisterEvent(spec)
    local list = self.rulesByEvent[event]
    if not list then list = {}; self.rulesByEvent[event] = list end
    list[#list + 1] = rule
  end
end

function NN:NoteRuleSeen(rule)
  local seen = self.db.seen.rules
  if not seen[rule.name] then
    seen[rule.name] = true
    if rule.default == false then self.db.disabled[rule.name] = true end
  end
end

NN.events:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... == ADDON_NAME then
      NewbieNudgeDB = NN.ApplyDefaults(NewbieNudgeDB or {}, NN.defaults)
      NN.db = NewbieNudgeDB
    end
    return
  end
  NN:OnEvent(event, ...)
end)
NN.events:RegisterEvent("ADDON_LOADED")
for _, event in ipairs(ALWAYS) do NN.events:RegisterEvent(event) end

-------------------------------------------------------------------------------
-- Scheduler
-------------------------------------------------------------------------------

function NN:MarkDirty(name)
  local state = self.ruleState[name]
  if state then state.dirty = true end
end

function NN:MarkAllDirty()
  for _, rule in ipairs(self.rules) do self.ruleState[rule.name].dirty = true end
end

function NN:OnLogin()
  self.loggedIn = true
  for name, expiry in pairs(self.db.snoozed) do
    if expiry == 0 then self.db.snoozed[name] = nil end
  end
  for _, rule in ipairs(self.rules) do self:NoteRuleSeen(rule) end
  if not self.ticker then
    self.ticker = C_Timer.NewTicker(self.TICK_SECONDS, function() NN:MarkAllDirty(); NN:Schedule() end)
  end
  -- Each module's login hook runs on its own: one failing module must not
  -- stop the others (the options window is built by one of these).
  if self.OnLoginHooks then
    for i, fn in ipairs(self.OnLoginHooks) do
      local ok, err = pcall(fn)
      if not ok then
        self.db.errors["login:" .. i] = tostring(err)
        self:Say(L.LOGIN_HOOK_ERROR:format(tostring(err)))
      end
    end
  end
end

-- Modules register functions to run once at PLAYER_LOGIN (after saved
-- variables and rules exist).
function NN:AfterLogin(fn)
  if self.loggedIn then fn(); return end
  self.OnLoginHooks = self.OnLoginHooks or {}
  self.OnLoginHooks[#self.OnLoginHooks + 1] = fn
end

function NN:OnEvent(event, ...)
  if event == "PLAYER_LOGIN" then self:OnLogin() end
  if event == "PLAYER_REGEN_DISABLED" and self.Panel then self.Panel:SetCombatMode(true) end
  if event == "PLAYER_REGEN_ENABLED" and self.Panel then self.Panel:SetCombatMode(false) end
  if RESET_APPLIES[event] then wipe(self.appliesCache) end
  if event == "BAG_UPDATE_DELAYED" then self.bagsLoaded = true end
  if self.OnEventHooks then
    for _, fn in ipairs(self.OnEventHooks) do fn(event, ...) end
  end
  if RECHECK_ALL[event] then
    self:MarkAllDirty()
  else
    for _, rule in ipairs(self.rulesByEvent[event] or {}) do self.ruleState[rule.name].dirty = true end
  end
  self:Schedule()
end

-- Modules that need raw events (cache invalidation) register here.
function NN:OnAnyEvent(fn)
  self.OnEventHooks = self.OnEventHooks or {}
  self.OnEventHooks[#self.OnEventHooks + 1] = fn
end

function NN:Schedule()
  if self.pendingCheck then return end
  self.pendingCheck = true
  C_Timer.After(self.CHECK_DELAY, function()
    NN.pendingCheck = false
    NN:RunChecks()
  end)
end

function NN:IsRestricted()
  if InCombatLockdown() then return true end
  local _, instanceType = IsInInstance()
  if instanceType == "party" or instanceType == "raid" or instanceType == "pvp" or instanceType == "arena" then
    return true
  end
  local RA = C_RestrictedActions
  if RA then
    for _, fname in ipairs({ "IsCombatRestricted", "IsEncounterRestricted", "IsMapRestricted" }) do
      local f = RA[fname]
      if f and f() == true then return true end
    end
  end
  return false
end

function NN:Applies(rule)
  local cached = self.appliesCache[rule.name]
  if cached == nil then
    local ok, result = pcall(rule.applies)
    cached = ok and result == true
    self.appliesCache[rule.name] = cached
  end
  return cached
end

function NN:IsSnoozed(name)
  local expiry = self.db.snoozed[name]
  if expiry == nil then return false end
  if expiry == 0 then return true end
  if expiry <= time() then
    self.db.snoozed[name] = nil
    return false
  end
  return true
end

function NN:IsRuleActive(rule)
  if self.db.disabled[rule.name] then return false end
  if self.ruleState[rule.name].disabled then return false end
  if not self:Applies(rule) then return false end
  if self:IsSnoozed(rule.name) then return false end
  return true
end

function NN:Snooze(name, minutes)
  if not self.ruleByName[name] then return end
  -- wall-clock seconds (time()), never GetTime(): the latter is uptime and is saved across sessions
  self.db.snoozed[name] = (minutes == 0) and 0 or (time() + minutes * 60)
  self:MarkDirty(name)
  self:Schedule()
end

function NN:ClearSnoozes()
  wipe(self.db.snoozed)
  self:MarkAllDirty()
  self:Schedule()
end

function NN:SetRuleEnabled(name, enabled)
  if not self.ruleByName[name] then return end
  self.db.disabled[name] = (not enabled) and true or nil
  self:MarkDirty(name)
  self:Schedule()
end

-- True when any string or number inside the result is a secret value.
function NN.HasSecret(result)
  if issecretvalue and issecretvalue(result) then return true end
  if type(result) ~= "table" then return false end
  for _, v in pairs(result) do
    if issecretvalue and issecretvalue(v) then return true end
    if type(v) == "table" and v ~= NN.UNKNOWN and NN.HasSecret(v) then return true end
  end
  return false
end

local function normalise(res)
  if res == nil then return {} end
  if res.text ~= nil then return { res } end
  return res
end

function NN:DisableRuleForSession(rule, message)
  self.ruleState[rule.name].disabled = true
  self.results[rule.name] = {}
  self.db.errors[rule.name] = tostring(message)
  self:Say(L.RULE_ERROR:format(rule.name, tostring(message)))
end

function NN:RunChecks()
  self.generation = (self.generation or 0) + 1 -- lets helpers memoise for one pass
  local restricted = self:IsRestricted()
  for _, rule in ipairs(self.rules) do
    local state = self.ruleState[rule.name]
    if state.dirty and not state.disabled then
      if not self:IsRuleActive(rule) then
        self.results[rule.name] = {}
        state.dirty = false
      elseif self.testMode then
        self.results[rule.name] = rule.sample and rule.sample() or { { text = rule.title, icon = 134400 } }
        state.dirty = false
      elseif restricted and not rule.combat then
        -- frozen: keep previous results, stay dirty for the next unrestricted pass
      else
        local ok, res = pcall(rule.check)
        if not ok then
          self:DisableRuleForSession(rule, res)
        elseif self.HasSecret(res) or res == self.UNKNOWN then
          -- unreadable right now: keep previous results
        else
          self.results[rule.name] = normalise(res)
        end
        state.dirty = false
      end
    end
  end
  local rows = self:ActiveRows()
  if self.Panel then self.Panel:Refresh(rows) end
  if self.Highlight then self.Highlight:Apply(rows) end
end

local priorityIndex
function NN:ActiveRows()
  if not priorityIndex then
    priorityIndex = {}
    for i, name in ipairs(self.PRIORITY) do priorityIndex[name] = i end
  end
  local restricted = self:IsRestricted()
  local ordered = {}
  for i, rule in ipairs(self.rules) do
    ordered[#ordered + 1] = { rule = rule, order = priorityIndex[rule.name] or (1000 + i) }
  end
  table.sort(ordered, function(a, b) return a.order < b.order end)
  local rows = {}
  for _, entry in ipairs(ordered) do
    local rule = entry.rule
    if self:IsRuleActive(rule) then
      for _, result in ipairs(self.results[rule.name] or {}) do
        rows[#rows + 1] = { rule = rule, result = result, stale = restricted and not rule.combat }
      end
    end
  end
  return rows
end

-------------------------------------------------------------------------------
-- Slash command
-------------------------------------------------------------------------------

function NN:RuleStateText(rule)
  if self.db.disabled[rule.name] or self.ruleState[rule.name].disabled then return L.STATE_OFF end
  if not self:Applies(rule) then return L.STATE_NA end
  if self:IsSnoozed(rule.name) then return L.STATE_SNOOZED end
  return L.STATE_ON
end

function NN:HandleSlash(msg)
  msg = strtrim(msg or "")
  local command, arg = msg:match("^(%S+)%s*(.-)$")
  command = command and command:lower() or ""
  local rawArg = arg and strtrim(arg) or "" -- links are case-sensitive
  arg = rawArg:lower()

  if command == "" then
    if self.db.panel.hidden then self:Say(L.SLASH_PANEL_HIDDEN) end
    if self.OpenOptions then self:OpenOptions() else self:Say(L.SLASH_HELP) end
  elseif command == "show" then
    if self.db.panel.hidden and self.Panel then self.Panel:ToggleHidden() end
  elseif command == "lock" then
    self.db.panel.locked = not self.db.panel.locked
    if self.Panel then self.Panel:SetLocked(self.db.panel.locked) end
    self:Say(self.db.panel.locked and L.SLASH_LOCKED or L.SLASH_UNLOCKED)
  elseif command == "list" then
    self:Say(L.SLASH_LIST_HEADER)
    for _, rule in ipairs(self.rules) do
      print(L.SLASH_LIST_LINE:format(rule.title, rule.name, self:RuleStateText(rule)))
    end
  elseif command == "on" or command == "off" then
    local rule = self.ruleByName[arg]
    if not rule then
      self:Say(L.SLASH_UNKNOWN_RULE:format(arg))
    else
      self:SetRuleEnabled(arg, command == "on")
      self:Say(L.SLASH_RULE_SET:format(rule.title, command == "on" and L.STATE_ON or L.STATE_OFF))
    end
  elseif command == "reset" then
    self.testMode = false
    self:ClearSnoozes()
    self:Say(L.SLASH_RESET_DONE)
  elseif command == "test" then
    self.testMode = true
    self:MarkAllDirty()
    self:Schedule()
    self:Say(L.SLASH_TEST_ON)
  elseif command == "build" then
    if not self.TalentBuild then return end
    if arg == "clear" then
      self.TalentBuild:Clear()
    elseif arg == "" then
      self:Say(self.TalentBuild:Status())
    else
      self.TalentBuild:Set(rawArg)
    end
  elseif command == "trash" then
    if self.BagFull then self.BagFull:Show("manual") end
  elseif command == "map" then
    if self.MapReveal then
      self.MapReveal:Toggle()
    else
      self.db.map.reveal = not self.db.map.reveal
      self:Say(self.db.map.reveal and L.SLASH_MAP_ON or L.SLASH_MAP_OFF)
    end
  else
    self:Say(L.SLASH_HELP)
  end
end

SLASH_NEWBIENUDGE1 = "/nudge"
SlashCmdList.NEWBIENUDGE = function(msg) NN:HandleSlash(msg) end
