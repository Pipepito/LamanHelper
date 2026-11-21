-- Highlight: pulses the default UI button that fixes a reminder, or the
-- action-bar button holding a spell. Uses Blizzard's proc glow when the
-- client has it, else a simple alpha-pulsing border texture.
local _, NN = ...

local Highlight = { active = {}, buttonCache = nil, bagTargets = {}, hookedBagFrames = {} }
NN.Highlight = Highlight

-- Key -> candidate frame paths, first that exists wins. Looked up lazily on
-- every Apply so frames created late by Blizzard code are still found.
local KEY_FRAMES = {
  bags      = { "MainMenuBarBackpackButton" },
  talents   = { "TalentMicroButton", "PlayerSpellsMicroButton" },
  spellbook = { "SpellbookMicroButton", "PlayerSpellsMicroButton" },
  character = { "CharacterMicroButton" },
  quests    = { "QuestLogMicroButton" },
  tracking  = { "MinimapCluster.Tracking.Button", "MinimapCluster.TrackingFrame.Button", "MiniMapTrackingButton", "MiniMapTracking" },
  mail      = { "MinimapCluster.IndicatorFrame.MailFrame", "MiniMapMailFrame" },
}

local BAR_PREFIXES = {
  "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
  "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}

local function resolvePath(path)
  local obj = _G
  for part in path:gmatch("[^.]+") do
    obj = obj[part]
    if type(obj) ~= "table" then return nil end
  end
  return obj
end

function Highlight:FrameForKey(key)
  for _, path in ipairs(KEY_FRAMES[key] or {}) do
    local frame = resolvePath(path)
    if frame and frame.GetObjectType then return frame end
  end
  return nil
end

function Highlight:ButtonForSlot(slot)
  if not self.buttonCache then
    self.buttonCache = {}
    for _, prefix in ipairs(BAR_PREFIXES) do
      for i = 1, 12 do
        local button = _G[prefix .. i]
        if button then
          local action = button.action
          if action == nil and button.GetAttribute then action = button:GetAttribute("action") end
          if type(action) == "number" and not self.buttonCache[action] then self.buttonCache[action] = button end
        end
      end
    end
  end
  return self.buttonCache[slot]
end

function Highlight:InvalidateButtons()
  self.buttonCache = nil
end

-- Collects the tables an iterator yields, whether it yields them directly
-- ("for frame in f()") or ipairs-style ("for i, frame in f()"), as the live
-- client's bag enumerators do.
local function collect(iterFn, ...)
  local out = {}
  if type(iterFn) ~= "function" then return out end
  local f, state, control = iterFn(...)
  if type(f) ~= "function" then return out end
  while true do
    local a, b = f(state, control)
    if a == nil then break end
    control = a
    local item = (type(a) == "table") and a or b
    if type(item) == "table" then out[#out + 1] = item end
  end
  return out
end

-- Only the player's own bags (0-4) carry glows; bank bag frames, which the
-- same enumerator yields while the bank is open, are left untouched. A frame
-- that cannot say which bag it shows is treated as a player bag.
local LAST_PLAYER_BAG = 4
local function isPlayerBagFrame(frame)
  if type(frame.GetBagID) ~= "function" then return true end
  local id = NN.Plain(frame:GetBagID())
  return id == nil or (id >= 0 and id <= LAST_PLAYER_BAG)
end

-- The default bag frames fire no addon-visible event when the player opens
-- them, so each is hooked once: showing it rescans its buttons and re-applies.
function Highlight:HookBagFrame(frame)
  if not frame or self.hookedBagFrames[frame] or not frame.HookScript then return end
  if not isPlayerBagFrame(frame) then return end
  self.hookedBagFrames[frame] = true
  frame:HookScript("OnShow", function()
    Highlight:InvalidateBagButtons()
    Highlight:ForgetBagTargets()
    Highlight:Reapply()
  end)
end

function Highlight:HookBagFrames()
  for _, frame in ipairs(collect(ContainerFrameUtil_EnumerateContainerFrames)) do self:HookBagFrame(frame) end
  if ContainerFrameCombinedBags then self:HookBagFrame(ContainerFrameCombinedBags) end
end

-- Item button of the default bag UI for (bag, slot), while the bags are open.
function Highlight:ButtonForBagSlot(bag, slot)
  if not self.bagButtonCache then
    self.bagButtonCache = {}
    for _, frame in ipairs(collect(ContainerFrameUtil_EnumerateContainerFrames)) do
      self:HookBagFrame(frame)
      if isPlayerBagFrame(frame) and frame.EnumerateValidItems and (not frame.IsShown or frame:IsShown()) then
        for _, button in ipairs(collect(frame.EnumerateValidItems, frame)) do
          local b = button.GetBagID and button:GetBagID()
          local id = button.GetID and button:GetID()
          if type(b) == "number" and type(id) == "number" then self.bagButtonCache[b .. "/" .. id] = button end
        end
      end
    end
  end
  return self.bagButtonCache[bag .. "/" .. slot]
end

function Highlight:InvalidateBagButtons()
  self.bagButtonCache = nil
end

-- Forget only the bag item buttons, so other glows are not replayed.
function Highlight:ForgetBagTargets()
  for frame in pairs(self.active) do
    if self.bagTargets[frame] then self.active[frame] = nil end
  end
  wipe(self.bagTargets)
end

-- Re-applies the rows from the last Apply (frames that just appeared).
function Highlight:Reapply()
  self:Apply(self.lastRows or NN:ActiveRows())
end

-- Blizzard's talent window, hooked once so glows come back when it opens.
function Highlight:TalentFrame()
  local f = (PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame) or (ClassTalentFrame and ClassTalentFrame.TalentsTab)
  if f and f ~= self.talentFrame then
    self.talentFrame = f
    if f.HookScript then
      f:HookScript("OnShow", function() Highlight:ForgetActive(); Highlight:Apply(NN:ActiveRows()) end)
    end
  end
  return f
end

function Highlight:ButtonForNode(nodeID)
  local f = self:TalentFrame()
  if f and f.GetTalentButtonByNodeID then return f:GetTalentButtonByNodeID(nodeID) end
  return nil
end

-- Frames a result's highlight asks for: a key string, or a table with any of
-- key (frame key), action (slots), bagslots ({bag, slot} pairs).
function Highlight:TargetsFor(h, wanted)
  if type(h) == "string" then
    local frame = self:FrameForKey(h)
    if frame then wanted[frame] = true end
  elseif type(h) == "table" then
    if type(h.key) == "string" then
      local frame = self:FrameForKey(h.key)
      if frame then wanted[frame] = true end
    end
    if type(h.action) == "table" then
      for _, slot in ipairs(h.action) do
        local button = self:ButtonForSlot(slot)
        if button then wanted[button] = true end
      end
    end
    if type(h.bagslots) == "table" then
      for _, pair in ipairs(h.bagslots) do
        local button = self:ButtonForBagSlot(pair[1], pair[2])
        if button then wanted[button] = true; self.bagTargets[button] = true end
      end
    end
    if h.node ~= nil then
      local button = self:ButtonForNode(h.node)
      if button then wanted[button] = true end
    end
  end
end

-------------------------------------------------------------------------------
-- Glow primitives
-------------------------------------------------------------------------------

local function ensureFallbackGlow(frame)
  local glow = frame.NewbieNudgeGlow
  if glow then return glow end
  glow = frame:CreateTexture(nil, "OVERLAY")
  glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  glow:SetBlendMode("ADD")
  glow:SetVertexColor(1, 0.85, 0.2)
  local w, h = frame:GetWidth(), frame:GetHeight()
  glow:SetSize((w > 0 and w or 32) * 1.6, (h > 0 and h or 32) * 1.6)
  glow:SetPoint("CENTER", frame, "CENTER", 0, 0)
  glow:Hide()
  frame.NewbieNudgeGlow = glow
  return glow
end

local function startPulse(glow)
  if glow.ticker then return end
  glow.phase = 0
  glow.ticker = C_Timer.NewTicker(0.05, function()
    glow.phase = (glow.phase + 0.05) % 1
    local t = glow.phase < 0.5 and glow.phase * 2 or (1 - glow.phase) * 2
    glow:SetAlpha(0.3 + 0.7 * t)
  end)
end

local function stopPulse(glow)
  if glow.ticker then glow.ticker:Cancel(); glow.ticker = nil end
end

function Highlight:Show(frame)
  if ActionButton_ShowOverlayGlow then
    ActionButton_ShowOverlayGlow(frame)
    return
  end
  local glow = ensureFallbackGlow(frame)
  glow:SetAlpha(1)
  glow:Show()
  startPulse(glow)
end

function Highlight:Hide(frame)
  if ActionButton_HideOverlayGlow then
    ActionButton_HideOverlayGlow(frame)
    return
  end
  local glow = frame.NewbieNudgeGlow
  if glow then stopPulse(glow); glow:Hide() end
end

-------------------------------------------------------------------------------
-- Apply
-------------------------------------------------------------------------------

-- rows: array of { rule, result, stale } from NN:ActiveRows().
function Highlight:Apply(rows)
  self.lastRows = rows
  local wanted = {}
  for _, row in ipairs(rows) do
    local h = row.result and row.result.highlight
    if h then self:TargetsFor(h, wanted) end
  end
  for frame in pairs(self.active) do
    if not wanted[frame] then
      self:Hide(frame)
      self.active[frame] = nil
    end
  end
  for frame in pairs(wanted) do
    if not self.active[frame] then
      self:Show(frame)
      self.active[frame] = true
    end
  end
end

function Highlight:ClearAll()
  for frame in pairs(self.active) do self:Hide(frame) end
  wipe(self.active)
end

-- Blizzard's own action-button update hides overlay glows on these events,
-- so forget what we showed and let the next Apply show it again.
local RESHOW_EVENTS = {
  PLAYER_ENTERING_WORLD = true, UPDATE_SHAPESHIFT_FORM = true, ACTIONBAR_SLOT_CHANGED = true,
  ACTIONBAR_PAGE_CHANGED = true, UPDATE_BONUS_ACTIONBAR = true, TRAIT_NODE_CHANGED = true,
}

function Highlight:ForgetActive()
  wipe(self.active)
end

local BAG_EVENTS = { BAG_OPEN = true, BAG_CLOSED = true, BAG_UPDATE_DELAYED = true }

NN:OnAnyEvent(function(event)
  if event == "ACTIONBAR_SLOT_CHANGED" or event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" then
    Highlight:InvalidateButtons()
  end
  if BAG_EVENTS[event] then Highlight:InvalidateBagButtons(); Highlight:ForgetBagTargets() end
  if RESHOW_EVENTS[event] then Highlight:ForgetActive() end
end)
NN:AfterLogin(function() Highlight:HookBagFrames() end)
NN:RegisterEvent("BAG_OPEN")
NN:RegisterEvent("BAG_CLOSED")
NN:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
NN:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
NN:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
