-- Core: rule registry, saved variables, shared helpers.
-- Every other file receives the same `NN` table through the addon varargs.
local ADDON_NAME, NN = ...
_G.NewbieNudge = NN
local L = NN.L

NN.rules = {}
NN.ruleByName = {}
NN.results = {}

NN.classFile = select(2, UnitClass("player"))
NN.isForever = (WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)

NN.defaults = {
  disabled = {},
  snoozed = {},
  panel = { point = "RIGHT", x = -40, y = 60, locked = true, scale = 1 },
  combatStrip = true,
  snoozeMinutes = 60,
  errors = {},
  seen = { rules = {} },
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
  return rule
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

NN.events = CreateFrame("Frame")
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
NN.events:RegisterEvent("PLAYER_LOGIN")

function NN:RegisterEvent(event)
  self.events:RegisterEvent(event)
end

-- Filled in by the scheduler.
function NN:OnEvent(event, ...) end
