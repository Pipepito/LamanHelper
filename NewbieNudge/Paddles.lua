-- Paddles: the controller's back paddles (Steam Deck L4/R4/L5/R5 and the like),
-- learned as whatever key they send, each doing a game command, a spell, an
-- item, a macro, or a layer of extra actions while held.
--
-- Everything goes through override bindings on NewbieNudge's own owner frame
-- and NewbieNudge's own secure buttons. The game's controller settings and
-- bars are never touched: writing those tainted Forever's controller
-- interface (2026-11-23). Bindings change only out of combat.
local _, NN = ...

local Paddles = {}
NN.Paddles = Paddles

Paddles.MAX = 4

local owner = CreateFrame("Frame", "NewbieNudgePaddleOwner")
Paddles.owner = owner
local buttons = {}
local pending = false

local function db()
  NN.db.paddles = NN.db.paddles or { enabled = true }
  return NN.db.paddles
end

function Paddles:Get(n)
  local d = db()
  d[n] = d[n] or {}
  return d[n]
end

local function spellName(id)
  local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
  if name == nil and GetSpellInfo then name = GetSpellInfo(id) end
  return NN.Plain(name, "string")
end

local function macroIndex(name)
  local i = GetMacroIndexByName and NN.Plain(GetMacroIndexByName(name)) or 0
  return (i and i > 0) and i or nil
end

-- name, icon, missing for an action; nil for no action.
function Paddles:Describe(action)
  if not action or not action.kind then return nil end
  local kind, value = action.kind, action.value
  if kind == "command" then
    local name = GetBindingName and NN.Plain(GetBindingName(value), "string")
    return name or tostring(value), 136243, false
  elseif kind == "spell" then
    local name = spellName(value)
    local icon = C_Spell and C_Spell.GetSpellTexture and NN.Plain(C_Spell.GetSpellTexture(value))
    return name or tostring(value), icon or 134400, name == nil
  elseif kind == "item" then
    local name = C_Item and C_Item.GetItemNameByID and NN.Plain(C_Item.GetItemNameByID(value), "string")
    local icon = C_Item and C_Item.GetItemIconByID and NN.Plain(C_Item.GetItemIconByID(value))
    return name or ("item:" .. tostring(value)), icon or 134400, false
  elseif kind == "macro" then
    local i = macroIndex(value)
    local icon = i and GetMacroInfo and select(2, GetMacroInfo(i))
    return tostring(value), NN.Plain(icon) or 134400, i == nil
  elseif kind == "layer" then
    return nil, 134400, false
  end
  return nil
end

-- Sets a secure action button up for an action; false when it can't be used
-- (unknown spell, missing macro).
function Paddles.SetupButton(button, action)
  local kind, value = action.kind, action.value
  button:SetAttribute("type", nil)
  button:SetAttribute("spell", nil); button:SetAttribute("item", nil); button:SetAttribute("macro", nil)
  if kind == "spell" then
    local name = spellName(value)
    if not name then return false end
    button:SetAttribute("type", "spell"); button:SetAttribute("spell", name)
  elseif kind == "item" then
    button:SetAttribute("type", "item"); button:SetAttribute("item", "item:" .. tostring(value))
  elseif kind == "macro" then
    if not macroIndex(value) then return false end
    button:SetAttribute("type", "macro"); button:SetAttribute("macro", value)
  else
    return false
  end
  return true
end

local function actionButton(name)
  if not buttons[name] then
    local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyDown")
    b:Hide()
    buttons[name] = b
  end
  return buttons[name]
end
Paddles.ActionButton = actionButton

-- Binds one paddle; layer paddles are handled by Paddles.BindLayer (Layer part).
local function bindPaddle(n, entry)
  local action = entry.action
  if not (entry.key and action and action.kind) then return end
  if action.kind == "command" then
    SetOverrideBinding(owner, true, entry.key, action.value)
  elseif action.kind == "layer" then
    if Paddles.BindLayer then Paddles:BindLayer(n, entry) end
  else
    local name = "NewbieNudgePaddle" .. n
    if Paddles.SetupButton(actionButton(name), action) then
      SetOverrideBindingClick(owner, true, entry.key, name)
    end
  end
end

function Paddles:Apply()
  if not NN.db then return end
  if InCombatLockdown and InCombatLockdown() then pending = true; return end
  pending = false
  ClearOverrideBindings(owner)
  if self.ClearLayers then self:ClearLayers() end
  if not db().enabled then return end
  for n = 1, self.MAX do bindPaddle(n, self:Get(n)) end
end

function Paddles:SetAction(n, action)
  self:Get(n).action = action
  self:Apply()
end

-- A key already learned by another paddle moves to this one.
function Paddles:SetKey(n, key)
  if key then
    for i = 1, self.MAX do
      if i ~= n and self:Get(i).key == key then self:Get(i).key = nil end
    end
  end
  self:Get(n).key = key
  self:Apply()
end

function Paddles:SetEnabled(on)
  db().enabled = on and true or false
  self:Apply()
end

function Paddles:IsEnabled() return db().enabled ~= false end

NN:OnAnyEvent(function(event)
  if event == "PLAYER_REGEN_ENABLED" and pending then Paddles:Apply() end
end)

NN:AfterLogin(function() Paddles:Apply() end)
