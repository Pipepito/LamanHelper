-- TalentBuild: an Icy Veins talent-calculator link carries the whole
-- leveling order (one character per talent point). This module parses and
-- stores it; the talent_build rule (below, Task 16) points at the next pick.
local _, NN = ...
local L = NN.L

local TalentBuild = {}
NN.TalentBuild = TalentBuild

local ERROR_KEYS = {
  no_link = "BUILD_ERR_NO_LINK", unknown_talent = "BUILD_ERR_UNKNOWN_TALENT",
  wrong_class = "BUILD_ERR_WRONG_CLASS", too_many_points = "BUILD_ERR_TOO_MANY_POINTS",
}

-- Accepts the full URL, "#tc-...", "tc-..." or "picks~version".
-- Returns { class, version, picks, warning } or nil, reason.
function TalentBuild.Parse(text, playerClass)
  text = NN.Plain(text, "string")
  if not text then return nil, "no_link" end
  text = strtrim(text)
  local class = text:match("(%a+)%-talent%-calculator")
  local picksText, version = text:match("tc%-(%w+)~([%w%-]+)")
  if not picksText then picksText = text:match("tc%-(%w+)") end
  if not picksText then picksText, version = text:match("^(%w+)~([%w%-]+)$") end
  if not picksText then return nil, "no_link" end
  class = class and class:upper() or playerClass
  if class ~= playerClass then return nil, "wrong_class" end
  local data = NN.IcyTalents and NN.IcyTalents[class]
  if not data then return nil, "unknown_talent" end
  local picks, counts = {}, {}
  for i = 1, #picksText do
    local id = picksText:sub(i, i)
    local entry = data[id]
    if not entry then return nil, "unknown_talent" end
    counts[id] = (counts[id] or 0) + 1
    if counts[id] > (entry.maxRank or 1) then return nil, "too_many_points" end
    picks[#picks + 1] = id
  end
  local warning
  if version and NN.IcyTalents.compatible and not NN.IcyTalents.compatible[version] then warning = "old_version" end
  return { class = class, version = version, picks = picks, warning = warning }
end

local function recheck()
  wipe(NN.appliesCache)
  NN:MarkDirty("talent_build")
  NN:Schedule()
end

function TalentBuild:Set(text)
  local build, why = self.Parse(text, NN.classFile)
  if not build then
    NN:Say(L[ERROR_KEYS[why] or "BUILD_ERR_NO_LINK"])
    return false
  end
  NN.db.build = { picks = build.picks, version = build.version, source = text, savedAt = time() }
  NN:Say(L.BUILD_SET:format(#build.picks))
  if build.warning == "old_version" then NN:Say(L.BUILD_WARN_OLD) end
  recheck()
  if self.UpdateBadges then self:UpdateBadges() end
  return true
end

function TalentBuild:Clear()
  NN.db.build = nil
  NN:Say(L.BUILD_CLEARED)
  recheck()
  if self.UpdateBadges then self:UpdateBadges() end
end

-------------------------------------------------------------------------------
-- Where the player is relative to the build
-------------------------------------------------------------------------------

-- Walks the build in order with a running count per talent; the first pick
-- whose count exceeds the purchased ranks on its node is the next one.
-- Returns index, urlId, entry; nil when every pick is satisfied.
function TalentBuild.NextPick(picks, ranksByNode, data)
  local count = {}
  for i, id in ipairs(picks) do
    local entry = data[id]
    if entry then
      count[id] = (count[id] or 0) + 1
      if count[id] > (ranksByNode[entry.node] or 0) then return i, id, entry end
    end
  end
  return nil
end

-- True when the player holds ranks on a node the build has not reached
-- before the next pick (they went off the build).
function TalentBuild.Differs(picks, nextIndex, ranksByNode, data)
  local reached = {}
  for i = 1, (nextIndex or (#picks + 1)) - 1 do
    local entry = data[picks[i]]
    if entry then reached[entry.node] = true end
  end
  for node, ranks in pairs(ranksByNode) do
    if ranks > 0 and not reached[node] then return true end
  end
  return false
end

-- { [nodeID] = purchased ranks } from the client, or nil on a secret value.
function TalentBuild:RanksByNode()
  local configID, treeID
  if NN.TalentTree then configID, treeID = NN.TalentTree() end
  if not configID or not treeID or not (C_Traits.GetTreeNodes and C_Traits.GetNodeInfo) then return {} end
  local ranks = {}
  for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID) or {}) do
    local info = C_Traits.GetNodeInfo(configID, nodeID)
    if info then
      local r = info.ranksPurchased
      if r == nil then r = info.activeRank end
      if issecretvalue and issecretvalue(r) then return nil end
      ranks[nodeID] = NN.Plain(r) or 0
    end
  end
  return ranks
end

function TalentBuild:SpentPoints()
  local total = 0
  for _, r in pairs(self:RanksByNode() or {}) do total = total + r end
  return total
end

local function talentName(entry)
  local configID
  if NN.TalentTree then configID = NN.TalentTree() end
  if configID and C_Traits.GetNodeInfo and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo then
    local info = C_Traits.GetNodeInfo(configID, entry.node)
    local entryID = info and info.entryIDs and info.entryIDs[1]
    local e = entryID and C_Traits.GetEntryInfo(configID, entryID)
    local def = e and e.definitionID and C_Traits.GetDefinitionInfo(e.definitionID)
    local spellID = def and NN.Plain(def.spellID)
    local name = spellID and C_Spell and C_Spell.GetSpellName and NN.Plain(C_Spell.GetSpellName(spellID), "string")
    if name then return name end
  end
  local name = C_Spell and C_Spell.GetSpellName and NN.Plain(C_Spell.GetSpellName(entry.spell), "string")
  return name or tostring(entry.spell)
end

function TalentBuild:Status()
  local build = NN.db and NN.db.build
  if not build then return L.BUILD_STATUS_NONE end
  return L.BUILD_STATUS:format((UnitClass("player")), #build.picks, self:SpentPoints())
end

-------------------------------------------------------------------------------
-- Rule
-------------------------------------------------------------------------------

local TALENT_ICON = 136116

NN:RegisterRule({
  name = "talent_build",
  title = L.BUILD_TITLE,
  help = L.BUILD_HELP,
  events = { "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_LEVEL_UP" },
  applies = function()
    return NN.db ~= nil and NN.db.build ~= nil and (NN.Plain(UnitLevel("player")) or 0) >= 10
  end,
  check = function()
    local build = NN.db.build
    local data = NN.IcyTalents and NN.IcyTalents[NN.classFile]
    if not build or not data then return nil end
    local unspent = NN.UnspentTalentPoints()
    if unspent == NN.UNKNOWN then return NN.UNKNOWN end
    local ranks = TalentBuild:RanksByNode()
    if ranks == nil then return NN.UNKNOWN end
    local idx, _, entry = TalentBuild.NextPick(build.picks, ranks, data)
    if not idx or (unspent or 0) <= 0 then return nil end
    local purchased = ranks[entry.node] or 0
    local results = {
      { text = L.BUILD_NEXT_ROW:format(talentName(entry), purchased + 1, entry.maxRank or 1), icon = TALENT_ICON,
        onClick = NN.OpenTalents, highlight = { key = "talents", node = entry.node } },
    }
    if TalentBuild.Differs(build.picks, idx, ranks, data) then
      results[#results + 1] = { text = L.BUILD_DIFFERS_ROW, icon = TALENT_ICON, onClick = NN.OpenTalents }
    end
    return results
  end,
  sample = function() return { { text = L.BUILD_NEXT_ROW:format("Spirit Tap", 1, 5), icon = TALENT_ICON } } end,
})

-------------------------------------------------------------------------------
-- Options page and paste popup
-------------------------------------------------------------------------------

-- The popup's edit box is `EditBox` on the current client and `editBox` on
-- older ones.
local function popupEditBox(dialog)
  return dialog and (dialog.EditBox or dialog.editBox)
end

if StaticPopupDialogs then
  StaticPopupDialogs["NEWBIENUDGE_BUILD"] = {
    text = L.BUILD_POPUP_TEXT, button1 = OKAY or "Okay", button2 = CANCEL or "Cancel",
    hasEditBox = true, editBoxWidth = 350, maxLetters = 0, timeout = 0, whileDead = true, hideOnEscape = true,
    OnAccept = function(self)
      local box = popupEditBox(self)
      if box then TalentBuild:Set(box:GetText()) end
    end,
    EditBoxOnEnterPressed = function(self)
      local parent = self:GetParent()
      local box = popupEditBox(parent) or self
      TalentBuild:Set(box:GetText())
      parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    OnShow = function(self)
      local box = popupEditBox(self)
      if box then
        box:SetText("")
        if box.SetFocus then box:SetFocus() end
      end
    end,
  }
end

-------------------------------------------------------------------------------
-- Button on the talent window
-------------------------------------------------------------------------------

local function talentFrame()
  return (PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame) or (ClassTalentFrame and ClassTalentFrame.TalentsTab)
end

-- Creates the "Icy Veins build" button once the talent window exists.
-- Left-click opens the paste popup, right-click clears the build.
function TalentBuild:EnsureButton()
  if self.button then return self.button end
  local parent = talentFrame()
  if not parent then return nil end
  local button = CreateFrame("Button", "NewbieNudgeBuildButton", parent, "UIPanelButtonTemplate")
  button:SetSize(130, 22)
  button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 8, 8)
  button:SetText(L.BUILD_BUTTON)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      if NN.db.build then TalentBuild:Clear() end
    elseif StaticPopup_Show then
      StaticPopup_Show("NEWBIENUDGE_BUILD")
    end
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.BUILD_BUTTON)
    GameTooltip:AddLine(TalentBuild:Status(), 1, 0.82, 0, true)
    GameTooltip:AddLine(L.BUILD_BUTTON_TT, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.button = button
  if parent.HookScript then parent:HookScript("OnShow", function() TalentBuild:UpdateBadges() end) end
  if not parent.IsShown or parent:IsShown() then self:UpdateBadges() end
  return button
end

-------------------------------------------------------------------------------
-- Badges on the talent window: bottom-right "taken/total" points, top-left
-- the level at which the build first takes a talent (until it is started).
-------------------------------------------------------------------------------

local COLOR_DONE, COLOR_PARTIAL, COLOR_NONE = { 0.3, 1, 0.3 }, { 1, 0.85, 0.2 }, { 1, 1, 1 }
local FIRST_TALENT_LEVEL = 10

-- { [node] = { total =, firstLevel = } } for the build's picks.
function TalentBuild.BuildSummary(picks, data)
  local summary = {}
  for i, id in ipairs(picks) do
    local entry = data[id]
    if entry then
      local s = summary[entry.node]
      if not s then s = { total = 0, firstLevel = FIRST_TALENT_LEVEL + i - 1 }; summary[entry.node] = s end
      s.total = s.total + 1
    end
  end
  return summary
end

local function ensureBadge(button)
  local badge = button.NewbieNudgeBadge
  if badge then return badge end
  badge = CreateFrame("Frame", nil, button)
  badge:SetAllPoints(button)
  badge:SetFrameLevel((button.GetFrameLevel and button:GetFrameLevel() or 1) + 5)
  badge.points = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  badge.points:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -1, 1)
  badge.level = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  badge.level:SetPoint("TOPLEFT", badge, "TOPLEFT", 1, -1)
  button.NewbieNudgeBadge = badge
  TalentBuild.badges = TalentBuild.badges or {}
  TalentBuild.badges[#TalentBuild.badges + 1] = badge
  return badge
end

function TalentBuild:HideBadges()
  for _, badge in ipairs(self.badges or {}) do badge:Hide() end
end

function TalentBuild:UpdateBadges()
  self:HideBadges()
  local frame = talentFrame()
  local build = NN.db and NN.db.build
  local data = NN.IcyTalents and NN.IcyTalents[NN.classFile]
  if not (frame and frame.GetTalentButtonByNodeID and build and data) then return end
  if NN.db.talentBadges == false then return end
  local ranks = self:RanksByNode() or {}
  for node, info in pairs(self.BuildSummary(build.picks, data)) do
    local button = frame:GetTalentButtonByNodeID(node)
    if button then
      local badge = ensureBadge(button)
      local taken = ranks[node] or 0
      local color = (taken >= info.total) and COLOR_DONE or (taken > 0 and COLOR_PARTIAL or COLOR_NONE)
      badge.points:SetText(taken .. "/" .. info.total)
      badge.points:SetTextColor(color[1], color[2], color[3])
      if taken == 0 then
        badge.level:SetText("L" .. info.firstLevel)
        badge.level:Show()
      else
        badge.level:Hide()
      end
      badge:Show()
    end
  end
end

local function talentFrameShown()
  local frame = talentFrame()
  return frame ~= nil and (not frame.IsShown or frame:IsShown())
end

NN:OnAnyEvent(function(event)
  if (event == "TRAIT_NODE_CHANGED" or event == "TRAIT_CONFIG_UPDATED") and talentFrameShown() then
    TalentBuild:UpdateBadges()
  end
end)

NN:AfterLogin(function() TalentBuild:EnsureButton() end)

-- The talent window can load on demand; try again when its addon arrives.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
  if name == "Blizzard_PlayerSpells" or name == "Blizzard_ClassTalentUI" or name == "Blizzard_TalentUI" then
    TalentBuild:EnsureButton()
  end
end)

NN.Options.RegisterPage("build", "OPT_BUILD", function(category, layout)
  local Options = NN.Options
  Options.AddHeader(layout, TalentBuild:Status())
  Options.AddButton(layout, L.OPT_BUILD_PASTE, L.OPT_BUTTON_DO, function()
    if StaticPopup_Show then StaticPopup_Show("NEWBIENUDGE_BUILD") end
  end, L.OPT_BUILD_PASTE_TT)
  Options.AddButton(layout, L.OPT_BUILD_CLEAR, L.OPT_BUTTON_DO, function() TalentBuild:Clear() end)
  Options.AddCheckbox(category, "NN_build_badges", L.OPT_BUILD_BADGES, L.OPT_BUILD_BADGES_TT,
    function() return NN.db.talentBadges ~= false end,
    function(value) NN.db.talentBadges = value and true or false; TalentBuild:UpdateBadges() end)
end)
