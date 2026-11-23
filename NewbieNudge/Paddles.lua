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

-- known by the player (any rank)
local function spellKnown(id)
  if IsPlayerSpell and IsPlayerSpell(id) then return true end
  return NN.Spellbook ~= nil and NN.Spellbook:Knows(id)
end

local function macroIndex(name)
  local i = GetMacroIndexByName and NN.Plain(GetMacroIndexByName(name)) or 0
  return (i and i > 0) and i or nil
end

-- An icon as the client gives it: a file ID, or on Forever often a path.
function Paddles.Icon(v)
  if issecretvalue and issecretvalue(v) then return nil end
  if type(v) == "number" or type(v) == "string" then return v end
  return nil
end
local icon = Paddles.Icon

-- name, icon, missing for an action; nil for no action.
function Paddles:Describe(action)
  if not action or not action.kind then return nil end
  local kind, value = action.kind, action.value
  if kind == "command" then
    local name = GetBindingName and NN.Plain(GetBindingName(value), "string")
    return name or tostring(value), 136243, false
  elseif kind == "spell" then
    local name = spellName(value)
    local tex = C_Spell and C_Spell.GetSpellTexture and icon(C_Spell.GetSpellTexture(value))
    return name or tostring(value), tex or 134400, name == nil or not spellKnown(value)
  elseif kind == "item" then
    local name = C_Item and C_Item.GetItemNameByID and NN.Plain(C_Item.GetItemNameByID(value), "string")
    local tex = C_Item and C_Item.GetItemIconByID and icon(C_Item.GetItemIconByID(value))
    return name or ("item:" .. tostring(value)), tex or 134400, false
  elseif kind == "macro" then
    local i = macroIndex(value)
    local tex = i and GetMacroInfo and select(2, GetMacroInfo(i))
    return tostring(value), icon(tex) or 134400, i == nil
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
    if not name or not spellKnown(value) then return false end
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
    -- both: the template acts on down or up per the game's key-down setting
    b:RegisterForClicks("AnyUp", "AnyDown")
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

-------------------------------------------------------------------------------
-- Layers: hold a paddle and the layer buttons do other actions
-------------------------------------------------------------------------------

-- The buttons a layer can take over while its paddle is held.
Paddles.LAYER_SLOTS = { "PAD1", "PAD2", "PAD3", "PAD4", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT" }
local isSlot = {}
for _, slot in ipairs(Paddles.LAYER_SLOTS) do isSlot[slot] = true end

local handlers = {}

local function layerHandler(n)
  if not handlers[n] then
    local h = CreateFrame("Button", "NewbieNudgePaddleLayer" .. n, UIParent,
      "SecureActionButtonTemplate, SecureHandlerBaseTemplate")
    h:RegisterForClicks("AnyDown", "AnyUp")
    h:Hide()
    handlers[n] = h
  end
  return handlers[n]
end

-- false when the slot or the action can't go on a layer
function Paddles:SetLayerAction(n, slot, action)
  if not isSlot[slot] then return false end
  if action and action.kind == "layer" then return false end
  local entry = self:Get(n)
  entry.layer = entry.layer or {}
  entry.layer[slot] = action
  self:Apply()
  return true
end

-- The wrapped OnClick: on press, bind every filled slot; on release, let go.
function Paddles:BindLayer(n, entry)
  local lines = {}
  for _, slot in ipairs(self.LAYER_SLOTS) do
    local action = entry.layer and entry.layer[slot]
    if action and action.kind == "command" then
      lines[#lines + 1] = ('self:SetBinding(true, "%s", "%s")'):format(slot, action.value)
    elseif action and action.kind then
      local name = "NewbieNudgeLayer" .. n .. slot
      if Paddles.SetupButton(actionButton(name), action) then
        lines[#lines + 1] = ('self:SetBindingClick(true, "%s", "%s")'):format(slot, name)
      end
    end
  end
  local h = layerHandler(n)
  local snippet = "if down then " .. table.concat(lines, " ") .. " else self:ClearBindings() end"
  h:WrapScript(h, "OnClick", snippet)
  SetOverrideBindingClick(owner, true, entry.key, h:GetName())
end

-- Drops every layer's wrap and any binding a held layer still has.
function Paddles:ClearLayers()
  for _, h in pairs(handlers) do
    h:UnwrapScript(h, "OnClick")
    h:Execute("self:ClearBindings()")
  end
end

-------------------------------------------------------------------------------
-- Learning: press the paddle and its key is remembered
-------------------------------------------------------------------------------

-- Keys a paddle may not take: the game's own controller buttons (its bars use
-- them) and the keys that close windows or open chat.
Paddles.REFUSED = {
  ENTER = true,
  PAD1 = true, PAD2 = true, PAD3 = true, PAD4 = true, PAD5 = true, PAD6 = true,
  PADDUP = true, PADDDOWN = true, PADDLEFT = true, PADDRIGHT = true,
  PADLSHOULDER = true, PADRSHOULDER = true, PADLTRIGGER = true, PADRTRIGGER = true,
  PADLSTICK = true, PADRSTICK = true, PADFORWARD = true, PADBACK = true, PADSYSTEM = true, PADSOCIAL = true,
}

local listener
local learning -- { n = paddle, done = callback }

local function stopListening()
  if not listener then return end
  -- a frame with a pad script takes the pad buttons (seen live, 2026-11-23):
  -- scripts exist only while learning
  listener:SetScript("OnKeyDown", nil)
  listener:SetScript("OnGamePadButtonDown", nil)
  listener:EnableKeyboard(false)
  if listener.EnableGamePadButton then listener:EnableGamePadButton(false) end
end

local function finish(key, reason)
  local current = learning
  learning = nil
  stopListening()
  if current and key then Paddles:SetKey(current.n, key) end
  if current and current.done then current.done(key, reason) end
end

local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
  LMETA = true, RMETA = true }

-- "ALT-CTRL-SHIFT-F1", the order the game writes bindings in
local function withModifiers(key)
  local prefix = ""
  if IsAltKeyDown and IsAltKeyDown() then prefix = prefix .. "ALT-" end
  if IsControlKeyDown and IsControlKeyDown() then prefix = prefix .. "CTRL-" end
  if IsShiftKeyDown and IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
  return prefix .. key
end

local function onPress(_, key)
  if not learning then return end
  key = NN.Plain(key, "string")
  -- a Steam chord (Ctrl+F1) arrives as the modifier first: keep listening
  if key and MODIFIERS[key] then return end
  if key and key ~= "ESCAPE" and not Paddles.REFUSED[key] then key = withModifiers(key) end
  if key == "ESCAPE" then finish(nil, "cancel")
  elseif not key or Paddles.REFUSED[key] then finish(nil, "refused")
  else finish(key) end
end

-- false (and done(nil, "combat")) when it can't start
function Paddles:StartLearning(n, done)
  if InCombatLockdown and InCombatLockdown() then
    if done then done(nil, "combat") end
    return false
  end
  if learning then finish(nil, "cancel") end
  if not listener then
    listener = CreateFrame("Frame", "NewbieNudgePaddleListener", UIParent)
    listener:SetPropagateKeyboardInput(true)
    if listener.SetPropagateGamePadInput then listener:SetPropagateGamePadInput(true) end
  end
  learning = { n = n, done = done }
  listener:SetScript("OnKeyDown", onPress)
  listener:SetScript("OnGamePadButtonDown", onPress)
  listener:EnableKeyboard(true)
  if listener.EnableGamePadButton then listener:EnableGamePadButton(true) end
  return true
end

function Paddles:StopLearning() if learning then finish(nil, "cancel") end end
function Paddles:IsLearning() return learning ~= nil end

NN:OnAnyEvent(function(event)
  if event == "PLAYER_REGEN_ENABLED" and pending then Paddles:Apply() end
  -- a paddle held through a loading screen never sends its release
  if event == "PLAYER_ENTERING_WORLD" and NN.db and not (InCombatLockdown and InCombatLockdown()) then
    Paddles:ClearLayers()
  end
  if event == "SPELLS_CHANGED" and NN.db then Paddles:Apply() end
  if event == "PLAYER_REGEN_DISABLED" and learning then finish(nil, "combat") end
end)

NN:AfterLogin(function() Paddles:Apply() end)
