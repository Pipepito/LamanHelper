-- Highlight: pulses the default UI button that fixes a reminder, or the
-- action-bar button holding a spell. Uses Blizzard's proc glow when the
-- client has it, else a simple alpha-pulsing border texture.
local _, NN = ...

local Highlight = { active = {}, buttonCache = nil }
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
  local wanted = {}
  for _, row in ipairs(rows) do
    local h = row.result and row.result.highlight
    if type(h) == "string" then
      local frame = self:FrameForKey(h)
      if frame then wanted[frame] = true end
    elseif type(h) == "table" and type(h.action) == "table" then
      for _, slot in ipairs(h.action) do
        local button = self:ButtonForSlot(slot)
        if button then wanted[button] = true end
      end
    end
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
  ACTIONBAR_PAGE_CHANGED = true, UPDATE_BONUS_ACTIONBAR = true,
}

function Highlight:ForgetActive()
  wipe(self.active)
end

NN:OnAnyEvent(function(event)
  if event == "ACTIONBAR_SLOT_CHANGED" or event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" then
    Highlight:InvalidateButtons()
  end
  if RESHOW_EVENTS[event] then Highlight:ForgetActive() end
end)
NN:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
NN:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
NN:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
