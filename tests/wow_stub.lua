-- Fake WoW API for offline tests. Everything reads WOW.state or records into
-- WOW.calls; nothing here simulates game behaviour beyond returning the state
-- a test set. Lua 5.1 only.

WOW = { calls = {}, printed = {}, timers = {}, eventFrames = {}, settings = {}, extraFiles = nil, keepData = false }

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = deepcopy(v) end
  return out
end

local DEFAULT_STATE = {
  locale = "enUS", class = "MAGE", className = "Mage", level = 20, maxLevel = 60,
  time = 1000, epoch = 1700000000, inCombat = false, resting = false, mounted = false, dead = false,
  instanceType = "none", projectID = 18, shiftDown = false,
  bags = { [0] = { numSlots = 16, family = 0, items = {} } },
  inventory = {},
  itemInfo = {},
  itemCounts = {},
  auras = {},
  spellInfo = {},
  spellBook = { lines = {}, items = {} },
  actions = {},
  weaponEnchant = { main = false, off = false },
  talents = { configID = 1, treeID = 10, unspent = 0, nodes = {} },
  tracking = {},
  usesAmmo = false, ammoCount = 0,
  pet = { exists = false, hasUI = false, isHunterPet = false, happiness = 3, trainingTotal = 0, trainingSpent = 0 },
  professions = { prof1 = 1 },   -- quiet default: one profession so the rule stays silent
  skillLines = {},
  quests = { num = 5, max = 25 }, newMail = false,
  cursor = nil,
  gameMenuShown = false,
  explored = {}, mapLayers = {},
  questLog = nil, trivialRange = 5,
  containerFrames = {},
  raceName = "Human", raceToken = "Human",
  professionInfo = {},
  instance = { name = "", type = "none", instanceID = 0 }, zoneNames = {}, completedQuests = {},
  faction = "Alliance", mapID = nil, mapInfo = {},
  gamepad = { enabled = false, deviceID = 0 },
}

function WOW.Reset()
  WOW.state = deepcopy(DEFAULT_STATE)
  WOW.calls, WOW.printed, WOW.timers, WOW.eventFrames, WOW.settings = {}, {}, {}, {}, {}
  if WorldMapFrame then WorldMapFrame.pins = {}; WorldMapFrame.shown = false end
  if LootFrame then LootFrame.shown = false end
  PlayerSpellsFrame = nil
end
WOW.Reset()
local S = function() return WOW.state end

local function record(name, ...)
  WOW.calls[#WOW.calls + 1] = { name, ... }
end
WOW.record = record

-------------------------------------------------------------------------------
-- Secrets
-------------------------------------------------------------------------------
local SECRET_MT = { __tostring = function() return "<secret>" end }
function WOW.secret(v) return setmetatable({ value = v }, SECRET_MT) end
function issecretvalue(v) return type(v) == "table" and getmetatable(v) == SECRET_MT end
function canaccessvalue(v) return not issecretvalue(v) end
function issecrettable() return false end
function canaccesstable() return true end

-------------------------------------------------------------------------------
-- Lua extras the game provides
-------------------------------------------------------------------------------
format = string.format
strlower = string.lower
strupper = string.upper
tinsert = table.insert
tremove = table.remove
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function strsplit(delim, s)
  local out = {}
  local pattern = "[^" .. delim:gsub("%p", "%%%0") .. "]+"
  for piece in s:gmatch(pattern) do out[#out + 1] = piece end
  return unpack(out)
end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function tContains(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
function CopyTable(t) return deepcopy(t) end
function Mixin(obj, ...) for i = 1, select("#", ...) do for k, v in pairs(select(i, ...)) do obj[k] = v end end return obj end
function hooksecurefunc(a, b, c)
  if type(a) == "table" then local orig = a[b]; a[b] = function(...) local r = { orig(...) }; c(...); return unpack(r) end
  else local orig = _G[a]; _G[a] = function(...) local r = { orig(...) }; b(...); return unpack(r) end end
end
function print(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
  WOW.printed[#WOW.printed + 1] = table.concat(parts, " ")
end
SlashCmdList = {}

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------
WOW_PROJECT_CAMELOT = 18
WOW_PROJECT_ID = 18
INVSLOT_AMMO, INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED = 0, 1, 17
CONTAINER_SLOTS = "%d|4Slot:Slots; %s"
ERR_INV_FULL = "Inventory is full."
ITEM_QUALITY0_DESC, ITEM_QUALITY1_DESC, ITEM_QUALITY2_DESC = "Poor", "Common", "Uncommon"
OKAY, CANCEL = "Okay", "Cancel"
TRADE_SKILLS = "Professions"
Enum = {
  BagIndex = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5 },
  ItemClass = { Consumable = 0, Container = 1, Weapon = 2, Armor = 4, Reagent = 5, Projectile = 6, Tradegoods = 7, Quiver = 11, Questitem = 12, Key = 13 },
  ItemArmorSubclass = { Generic = 0, Cloth = 1, Leather = 2, Mail = 3, Plate = 4 },
  SpellBookSpellBank = { Player = 0, Pet = 1 },
  SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 },
}

-------------------------------------------------------------------------------
-- Frames
-------------------------------------------------------------------------------
local Region = {}
Region.__index = Region
local function noop() end

function Region:Show() if not self.shown then self.shown = true; self:Fire("OnShow") end end
function Region:Hide() if self.shown then self.shown = false; self:Fire("OnHide") end end
function Region:SetShown(b) if b then self:Show() else self:Hide() end end
function Region:IsShown() return self.shown end
function Region:IsVisible() return self.shown and (self.parent == nil or self.parent:IsVisible()) end
function Region:SetPoint(point, rel, relPoint, x, y)
  if type(rel) == "number" then x, y, rel, relPoint = rel, relPoint, nil, nil end
  self.points[#self.points + 1] = { point = point, rel = rel, relPoint = relPoint, x = x or 0, y = y or 0 }
end
function Region:SetAllPoints() self.points[#self.points + 1] = { point = "ALL" } end
function Region:ClearAllPoints() self.points = {} end
function Region:GetPoint(i) local p = self.points[i or 1]; if p then return p.point, p.rel, p.relPoint, p.x, p.y end end
function Region:GetNumPoints() return #self.points end
function Region:SetSize(w, h) self.width, self.height = w, h end
function Region:SetWidth(w) self.width = w end
function Region:SetHeight(h) self.height = h end
function Region:GetWidth() return self.width or 0 end
function Region:GetHeight() return self.height or 0 end
function Region:GetSize() return self.width or 0, self.height or 0 end
function Region:SetAlpha(a) self.alpha = a end
function Region:GetAlpha() return self.alpha or 1 end
function Region:SetScale(s) self.scale = s end
function Region:GetScale() return self.scale or 1 end
function Region:GetEffectiveScale() return self.scale or 1 end
function Region:GetName() return self.name end
function Region:GetParent() return self.parent end
function Region:SetParent(p) self.parent = p end
function Region:GetObjectType() return self.kind end
function Region:IsObjectType(k) return self.kind == k end
function Region:SetDrawLayer(l) self.layer = l end
function Region:SetFrameStrata(s) self.strata = s end
function Region:GetFrameStrata() return self.strata or "MEDIUM" end
function Region:SetFrameLevel(l) self.level = l end
function Region:GetFrameLevel() return self.level or 1 end
function Region:SetToplevel() end
function Region:SetClampedToScreen() end
function Region:SetUserPlaced() end
function Region:SetMovable(b) self.movable = b end
function Region:IsMovable() return self.movable end
function Region:EnableMouse(b) self.mouse = b end
function Region:EnableMouseWheel() end
function Region:SetHitRectInsets() end
function Region:RegisterForDrag() end
function Region:RegisterForClicks() end
function Region:StartMoving() self.moving = true end
function Region:StopMovingOrSizing() self.moving = false end
function Region:IsMouseOver() return false end
function Region:SetID(id) self.id = id end
function Region:GetID() return self.id or 0 end
function Region:SetAttribute(k, v) self.attributes[k] = v end
function Region:GetAttribute(k) return self.attributes[k] end
function Region:SetBackdrop(b) self.backdrop = b end
function Region:SetBackdropColor(...) self.backdropColor = { ... } end
function Region:SetBackdropBorderColor(...) self.backdropBorderColor = { ... } end
function Region:SetHighlightTexture() end
function Region:SetNormalTexture() end
function Region:SetPushedTexture() end
function Region:SetText(t) self.textValue = t end
function Region:GetText() return self.textValue end
function Region:SetFormattedText(fmt, ...) self.textValue = string.format(fmt, ...) end
function Region:SetJustifyH(j) self.justifyH = j end
function Region:SetJustifyV(j) self.justifyV = j end
function Region:SetWordWrap(b) self.wordWrap = b end
function Region:SetNonSpaceWrap() end
function Region:SetMaxLines(n) self.maxLines = n end
function Region:GetUnboundedStringWidth() return (self.textValue and #self.textValue * 6) or 0 end
function Region:GetStringWidth() local w = self:GetUnboundedStringWidth(); if self.wordWrap and self.width and w > self.width then return self.width end return w end
function Region:GetStringHeight() return 12 end
function Region:GetNumLines() return 1 end
function Region:SetFont(f, s, fl) self.font = { f, s, fl } end
function Region:GetFont() local f = self.font or {}; return f[1] or "Fonts\\FRIZQT__.TTF", f[2] or 12, f[3] or "" end
function Region:SetFontObject(o) self.fontObject = o end
function Region:SetTextColor(...) self.textColor = { ... } end
function Region:SetShadowOffset() end
function Region:SetShadowColor() end
function Region:SetTexture(t) self.texture = t end
function Region:GetTexture() return self.texture end
function Region:SetAtlas(a) self.atlas = a end
function Region:SetColorTexture(...) self.color = { ... } end
function Region:SetVertexColor(...) self.vertexColor = { ... } end
function Region:SetTexCoord(...) self.texCoord = { ... } end
function Region:SetDesaturated(b) self.desaturated = b end
function Region:SetBlendMode(m) self.blendMode = m end
function Region:SetGradient() end
function Region:SetMinMaxValues(a, b) self.minValue, self.maxValue = a, b end
function Region:SetValue(v) self.value = v end
function Region:GetValue() return self.value end
function Region:SetValueStep(s) self.step = s end
function Region:SetObeyStepOnDrag() end
function Region:SetResizeBounds() end
function Region:GetChildren() return unpack(self.children) end
function Region:GetRegions() return unpack(self.regions) end
function Region:SetScript(handler, fn) self.scripts[handler] = fn end
function Region:GetScript(handler) return self.scripts[handler] end
function Region:HasScript() return true end
function Region:HookScript(handler, fn) local h = self.hooks[handler] or {}; h[#h + 1] = fn; self.hooks[handler] = h end
function Region:Fire(handler, ...)
  if self.scripts[handler] then self.scripts[handler](self, ...) end
  for _, fn in ipairs(self.hooks[handler] or {}) do fn(self, ...) end
end
WOW.unknownEvents = {}
function Region:RegisterEvent(event)
  if WOW.unknownEvents[event] then error("Attempt to register unknown event \"" .. tostring(event) .. "\"") end
  local list = WOW.eventFrames[event]
  if not list then list = {}; WOW.eventFrames[event] = list end
  for _, f in ipairs(list) do if f == self then return end end
  list[#list + 1] = self
  self.events[event] = true
end
function Region:RegisterUnitEvent(event) self:RegisterEvent(event) end
function Region:UnregisterEvent(event)
  local list = WOW.eventFrames[event] or {}
  for i, f in ipairs(list) do if f == self then table.remove(list, i); break end end
  self.events[event] = nil
end
function Region:UnregisterAllEvents() for e in pairs(self.events) do self:UnregisterEvent(e) end end
function Region:IsEventRegistered(e) return self.events[e] == true end

local function newRegion(kind, name, parent)
  local r = setmetatable({
    kind = kind, name = name, parent = parent, shown = true, points = {}, scripts = {}, hooks = {},
    events = {}, attributes = {}, children = {}, regions = {},
  }, Region)
  if parent and parent.children then
    if kind == "Texture" or kind == "FontString" then parent.regions[#parent.regions + 1] = r
    else parent.children[#parent.children + 1] = r end
  end
  if name then _G[name] = r end
  return r
end

function Region:CreateTexture(name, layer) local t = newRegion("Texture", name, self); t.layer = layer; return t end
function Region:CreateFontString(name, layer, template) local t = newRegion("FontString", name, self); t.layer = layer; t.fontObject = template; return t end
function Region:CreateMaskTexture(name) return newRegion("MaskTexture", name, self) end
function Region:CreateAnimationGroup() local g = newRegion("AnimationGroup", nil, self); g.Play = noop; g.Stop = noop; g.IsPlaying = function() return false end; g.SetLooping = noop; g.CreateAnimation = function() local a = newRegion("Animation", nil, g); a.SetDuration = noop; a.SetFromAlpha = noop; a.SetToAlpha = noop; a.SetOrder = noop; a.SetSmoothing = noop; return a end; return g end

function CreateFrame(kind, name, parent, template)
  local f = newRegion(kind or "Frame", name, parent)
  f.template = template
  return f
end

UIParent = CreateFrame("Frame", "UIParent")
WorldFrame = CreateFrame("Frame", "WorldFrame")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
GameTooltip.lines = {}
GameTooltip.shown = false
function GameTooltip:SetOwner(owner, anchor) self.owner = owner; self.anchor = anchor; self.lines = {} end
function GameTooltip:GetOwner() return self.owner end
function GameTooltip:ClearLines() self.lines = {} end
function GameTooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function GameTooltip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = l .. " | " .. tostring(r) end
function GameTooltip:SetText(text) self.lines = { text } end
GameMenuFrame = CreateFrame("Frame", "GameMenuFrame", UIParent)
LootFrame = CreateFrame("Frame", "LootFrame", UIParent)
LootFrame.shown = false
GameMenuFrame.shown = false
function WOW.ShowGameMenu(b) if b then GameMenuFrame:Show() else GameMenuFrame:Hide() end; S().gameMenuShown = b and true or false end

MainMenuBarBackpackButton = CreateFrame("Button", "MainMenuBarBackpackButton", UIParent)
PlayerSpellsMicroButton = CreateFrame("Button", "PlayerSpellsMicroButton", UIParent)
CharacterMicroButton = CreateFrame("Button", "CharacterMicroButton", UIParent)
QuestLogMicroButton = CreateFrame("Button", "QuestLogMicroButton", UIParent)
for i = 1, 12 do
  local b = CreateFrame("CheckButton", "ActionButton" .. i, UIParent)
  b.action = i
end

function WOW.Click(frame, button) frame:Fire("OnClick", button or "LeftButton", false) end
function WOW.Hover(frame) frame:Fire("OnEnter") end
function WOW.Unhover(frame) frame:Fire("OnLeave") end
function IsShiftKeyDown() return S().shiftDown end
function IsControlKeyDown() return false end
function IsAltKeyDown() return false end

-------------------------------------------------------------------------------
-- Events and timers
-------------------------------------------------------------------------------
function WOW.FireEvent(event, ...)
  local list = WOW.eventFrames[event]
  if not list then return end
  local snapshot = {}
  for i, f in ipairs(list) do snapshot[i] = f end
  for _, f in ipairs(snapshot) do
    if f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    for _, fn in ipairs(f.hooks.OnEvent or {}) do fn(f, event, ...) end
  end
end

function GetTime() return S().time end
function GetServerTime() return math.floor(S().time) end
function time() return math.floor(S().epoch) end
function date(fmt) return fmt or "" end

C_Timer = {}
function C_Timer.After(delay, fn)
  WOW.timers[#WOW.timers + 1] = { due = S().time + delay, fn = fn }
end
function C_Timer.NewTicker(delay, fn, iterations)
  local ticker = { cancelled = false, delay = delay, fn = fn, iterations = iterations }
  function ticker:Cancel() self.cancelled = true end
  function ticker:IsCancelled() return self.cancelled end
  ticker.due = S().time + delay
  WOW.timers[#WOW.timers + 1] = ticker
  return ticker
end
C_Timer.NewTimer = function(delay, fn) local t = C_Timer.NewTicker(delay, fn, 1); return t end
function WOW.AdvanceTime(seconds)
  local target = S().time + seconds
  while true do
    local best, bestIdx
    for i, t in ipairs(WOW.timers) do
      if not t.cancelled and t.due <= target and (not best or t.due < best.due) then best, bestIdx = t, i end
    end
    if not best then break end
    S().time = best.due
    if best.iterations then
      best.iterations = best.iterations - 1
      if best.iterations <= 0 then table.remove(WOW.timers, bestIdx) else best.due = best.due + best.delay end
      best.fn(best)
    elseif best.delay then
      best.due = best.due + best.delay
      best.fn(best)
    else
      table.remove(WOW.timers, bestIdx)
      best.fn()
    end
  end
  S().epoch = S().epoch + seconds
  S().time = target
end

-------------------------------------------------------------------------------
-- Player and world
-------------------------------------------------------------------------------
function GetLocale() return S().locale end
function GetBuildInfo() return "1.60.1", "70425", "Oct 7 2026", 16001 end
function UnitClass(unit) return S().className, S().class, 8 end
function UnitRace(unit) return S().raceName, S().raceToken end
function UnitLevel(unit) return S().level end
function GetMaxPlayerLevel() return S().maxLevel end
function GetMaxLevelForPlayerExpansion() return S().maxLevel end
function UnitName(unit) return unit == "pet" and "Pet" or "Tester", nil end
function UnitExists(unit) if unit == "pet" then return S().pet.exists end return unit == "player" end
function UnitIsDeadOrGhost(unit) return S().dead end
function UnitAffectingCombat() return S().inCombat end
function InCombatLockdown() return S().inCombat end
function IsResting() return S().resting end
function IsMounted() return S().mounted end
function IsInInstance() local t = S().instanceType; return t ~= "none", t end
function GetInstanceInfo() local i = S().instance; return i.name, i.type, 0, "", 5, 0, false, i.instanceID, 5, nil end
function GetRealZoneText(id) return S().zoneNames[id] end
function UnitFactionGroup(unit) return S().faction, S().faction end
function OpenWorldMap(mapID) record("OpenWorldMap", mapID) end
function ToggleWorldMap() record("ToggleWorldMap") end
function GetNumGroupMembers() return 0 end
function HasNewMail() return S().newMail end
function UnitUsesAmmo(unit) return S().usesAmmo end
function HasPetUI() return S().pet.hasUI, S().pet.isHunterPet end
function GetProfessions() local p = S().professions; return p.prof1, p.prof2, nil, nil, nil end
function GetProfessionInfo(index)
  local p = S().professionInfo[index]
  if p then return p.name, p.icon or 136240, p.skill, p.maxSkill, 0, 0, p.skillLine or 0 end
end
function GetSpellInfo(id) local i = S().spellInfo[id]; if i then return i.name, i.subtext, i.icon end end

-------------------------------------------------------------------------------
-- Containers, inventory, items
-------------------------------------------------------------------------------
C_Container = {}
local function bag(id) return S().bags[id] end
function C_Container.GetContainerNumSlots(id) local b = bag(id); return b and b.numSlots or 0 end
function C_Container.GetContainerNumFreeSlots(id)
  local b = bag(id); if not b then return 0, 0 end
  local used = 0
  for _ in pairs(b.items) do used = used + 1 end
  return b.numSlots - used, b.family or 0
end
function C_Container.GetContainerItemInfo(id, slot)
  local b = bag(id); local it = b and b.items[slot]
  if not it then return nil end
  local info = S().itemInfo[it.itemID] or {}
  return { itemID = it.itemID, hyperlink = it.link or info.link or ("item:" .. it.itemID), stackCount = it.count or 1,
           iconFileID = info.icon or 134400, quality = info.quality or 1, isLocked = it.locked or false,
           hasNoValue = (info.sellPrice or 0) == 0, isBound = it.bound or false }
end
function C_Container.GetContainerItemID(id, slot) local b = bag(id); local it = b and b.items[slot]; return it and it.itemID end
function C_Container.GetContainerItemLink(id, slot) local i = C_Container.GetContainerItemInfo(id, slot); return i and i.hyperlink end
function C_Container.ContainerIDToInventoryID(id) return (S().bagSlotBase or 19) + id end
function ContainerIDToInventoryID(id) return C_Container.ContainerIDToInventoryID(id) end
function C_Container.PickupContainerItem(id, slot)
  local b = bag(id)
  if b and b.items[slot] then S().cursor = { type = "item", bag = id, slot = slot } end
  record("PickupContainerItem", id, slot)
end
function CursorHasItem() local c = S().cursor; return c ~= nil and c.type == "item" end
function DeleteCursorItem()
  local c = S().cursor
  if c and c.type == "item" then
    S().bags[c.bag].items[c.slot] = nil
    record("DeleteCursorItem", c.bag, c.slot)
  end
  S().cursor = nil
end
C_CurrencyInfo = { GetCoinTextureString = function(n) return tostring(n) .. "c" end }
function GetMoneyString(n) return tostring(n) .. "c" end
function C_Container.GetContainerItemQuestInfo(id, slot)
  local b = bag(id); local it = b and b.items[slot]
  if not it then return { isQuestItem = false } end
  return { isQuestItem = it.isQuestItem or false, questID = it.questID, isActive = it.isActive or false }
end

-- Default bag UI: WOW.NewContainerFrame(bagID, numSlots) creates a shown
-- frame with one item button per slot, as ContainerFrameUtil_EnumerateContainerFrames yields.
function WOW.NewContainerFrame(bagID, numSlots)
  local f = CreateFrame("Frame")
  f.Items = {}
  for i = 1, numSlots do
    local b = CreateFrame("Button", nil, f)
    b.bagID = bagID
    function b:GetBagID() return self.bagID end
    b:SetID(i)
    f.Items[i] = b
  end
  function f:EnumerateValidItems()
    local i = 0
    return function() i = i + 1; return self.Items[i] end
  end
  S().containerFrames[#S().containerFrames + 1] = f
  return f
end
function ContainerFrameUtil_EnumerateContainerFrames()
  local list, i = S().containerFrames, 0
  return function() i = i + 1; return list[i] end
end

C_Item = {}
local function itemByLink(link)
  for id, info in pairs(S().itemInfo) do if info.link == link or ("item:" .. id) == link then return id, info end end
  local id = tonumber(tostring(link):match("item:(%d+)"))
  return id, S().itemInfo[id]
end
function C_Item.GetItemInfoInstant(idOrLink)
  local id, info = idOrLink, S().itemInfo[idOrLink]
  if type(idOrLink) ~= "number" then id, info = itemByLink(idOrLink) end
  if not info then return nil end
  return id, info.itemType, info.itemSubType, info.equipLoc, info.icon or 134400, info.classID or 0, info.subclassID or 0
end
function C_Item.GetItemInfo(idOrLink)
  local id, info = idOrLink, S().itemInfo[idOrLink]
  if type(idOrLink) ~= "number" then id, info = itemByLink(idOrLink) end
  if not info or info.uncached then return nil end
  return info.name or ("Item" .. id), info.link or ("item:" .. id), info.quality or 1, info.itemLevel or 1, info.reqLevel or 0,
         info.itemType, info.itemSubType, info.stackCount or 1, info.equipLoc, info.icon or 134400, info.sellPrice or 0,
         info.classID or 0, info.subclassID or 0
end
function C_Item.GetItemFamily(id) local info = S().itemInfo[id]; return info and info.family or 0 end
function C_Item.GetItemMaxStackSizeByID(id) local info = S().itemInfo[id]; return info and info.stackCount or 1 end
function C_Item.GetDetailedItemLevelInfo(link) local _, info = itemByLink(link); return info and info.itemLevel end
function C_Item.GetItemCount(id) return S().itemCounts[id] or 0 end
function GetItemCount(id) return S().itemCounts[id] or 0 end
function C_Item.IsItemDataCachedByID(id) local info = S().itemInfo[id]; return info ~= nil and not info.uncached end
function C_Item.RequestLoadItemDataByID() end
function GetInventoryItemID(unit, slot) local it = S().inventory[slot]; return it and it.itemID end
function GetInventoryItemLink(unit, slot) local it = S().inventory[slot]; if not it then return nil end local info = S().itemInfo[it.itemID]; return it.link or (info and info.link) or ("item:" .. it.itemID) end
function GetInventoryItemDurability(slot) local it = S().inventory[slot]; local d = it and it.durability; if d then return d[1], d[2] end end
function GetInventoryItemCount(unit, slot) if slot == 0 then return S().ammoCount end local it = S().inventory[slot]; return it and (it.count or 1) or 0 end
function GetWeaponEnchantInfo() local w = S().weaponEnchant; return w.main, 0, 0, 0, w.off, 0, 0, 0 end
function GetItemFamily(id) return C_Item.GetItemFamily(id) end

C_TooltipInfo = {}
function C_TooltipInfo.GetBagItem(id, slot)
  local b = bag(id); local it = b and b.items[slot]
  if not it then return nil end
  local info = S().itemInfo[it.itemID] or {}
  local lines = { { leftText = info.name or ("Item" .. it.itemID) } }
  if info.numSlots then lines[#lines + 1] = { leftText = string.format("%d Slot Bag", info.numSlots) } end
  return { lines = lines }
end

-------------------------------------------------------------------------------
-- Auras, spells, spellbook, action bar
-------------------------------------------------------------------------------
C_UnitAuras = {}
function C_UnitAuras.GetPlayerAuraBySpellID(id) if S().auras[id] then return { spellId = id, name = (S().spellInfo[id] or {}).name } end end
function C_UnitAuras.GetAuraDataBySpellName(unit, name, filter) if S().auras[name] then return { name = name } end end

C_Spell = {}
local function spell(id) return S().spellInfo[id] end
function C_Spell.GetSpellName(id) local s = spell(id); return s and s.name end
function C_Spell.GetSpellInfo(id) local s = spell(id); if s then return { name = s.name, iconID = s.icon or 134400, spellID = id } end end
function C_Spell.GetSpellSubtext(id) local s = spell(id); return s and s.subtext end
function C_Spell.GetSpellTexture(id) local s = spell(id); return s and s.icon or 134400 end
function C_Spell.PickupSpell(id) S().cursor = { type = "spell", id = id }; record("PickupSpell", id) end
function C_Spell.DoesSpellExist(id) return spell(id) ~= nil end
function C_Spell.RequestLoadSpellData() end

C_SpellBook = {}
local function bookItem(slot) return S().spellBook.items[slot] end
function C_SpellBook.GetNumSpellBookSkillLines() return #S().spellBook.lines end
function C_SpellBook.GetSpellBookSkillLineInfo(i)
  local l = S().spellBook.lines[i]
  if l then return { name = l.name, itemIndexOffset = l.offset, numSpellBookItems = l.num, offSpecID = l.offSpecID } end
end
function C_SpellBook.GetSpellBookItemType(slot, bank) local it = bookItem(slot); if not it then return 0 end return (it.type == nil or it.type == "SPELL") and 1 or 2, it.spellID end
function C_SpellBook.GetSpellBookItemInfo(slot, bank)
  local it = bookItem(slot); if not it then return nil end
  local s = spell(it.spellID) or {}
  return { spellID = it.spellID, name = s.name, isPassive = it.passive or false, itemType = 1, iconID = s.icon or 134400 }
end
function C_SpellBook.IsSpellBookItemPassive(slot) local it = bookItem(slot); return it and it.passive or false end
function C_SpellBook.IsSpellBookItemLowRank(slot) local it = bookItem(slot); return it and it.lowRank or false end
function C_SpellBook.FindSpellBookSlotForSpell(id)
  for slot, it in pairs(S().spellBook.items) do if it.spellID == id then return slot, 0 end end
end
function C_SpellBook.IsSpellKnown(id) return C_SpellBook.FindSpellBookSlotForSpell(id) ~= nil end
function IsSpellKnown(id) return C_SpellBook.IsSpellKnown(id) end
function IsPlayerSpell(id) return C_SpellBook.IsSpellKnown(id) end
function C_SpellBook.PickupSpellBookItem(slot) local it = bookItem(slot); if it then C_Spell.PickupSpell(it.spellID) end end

function GetActionInfo(slot) local a = S().actions[slot]; if a then return a.type, a.id, a.subType end end
function HasAction(slot) return S().actions[slot] ~= nil end
function PlaceAction(slot)
  local c = S().cursor
  record("PlaceAction", slot, c and c.id)
  if c then S().actions[slot] = { type = c.type, id = c.id }; S().cursor = nil end
end
function ClearCursor() S().cursor = nil; record("ClearCursor") end
function GetCursorInfo() local c = S().cursor; if c then return c.type, c.id end end

-------------------------------------------------------------------------------
-- Talents, tracking, pets, skills, quests
-------------------------------------------------------------------------------
C_ClassTalents = {}
function C_ClassTalents.GetActiveConfigID() return S().talents.configID end
C_Traits = {}
function C_Traits.GetConfigInfo(id) if id then return { ID = id, treeIDs = { S().talents.treeID } } end end
function C_Traits.GetTreeCurrencyInfo(configID, treeID) return { { quantity = S().talents.unspent, maxQuantity = 51, spent = 0 } } end
-- S().talents.nodes = { [nodeID] = { ranks =, maxRanks =, spellID = } }
function C_Traits.GetTreeNodes(treeID)
  local ids = {}
  for id in pairs(S().talents.nodes or {}) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end
function C_Traits.GetNodeInfo(configID, nodeID)
  local n = S().talents.nodes[nodeID]
  if not n then return nil end
  return { ID = nodeID, ranksPurchased = n.ranks or 0, activeRank = n.ranks or 0, maxRanks = n.maxRanks or 1, entryIDs = { nodeID * 10 } }
end
function C_Traits.GetEntryInfo(configID, entryID) return { definitionID = entryID } end
function C_Traits.GetDefinitionInfo(defID) local n = S().talents.nodes[defID / 10]; return { spellID = n and n.spellID } end
-- Blizzard's talent window: WOW.NewTalentFrame() creates PlayerSpellsFrame.TalentsFrame with a button per node.
function WOW.NewTalentFrame()
  local f = CreateFrame("Frame", "PlayerSpellsTalentsFrame", UIParent)
  f.buttons = {}
  for id in pairs(S().talents.nodes or {}) do f.buttons[id] = CreateFrame("Button", nil, f) end
  function f:GetTalentButtonByNodeID(id) return self.buttons[id] end
  PlayerSpellsFrame = { TalentsFrame = f }
  return f
end
StaticPopupDialogs = {}
function StaticPopup_Show(which, ...)
  record("StaticPopup_Show", which)
  local dialog = { editBox = CreateFrame("EditBox") }
  return dialog
end

C_Minimap = {}
function C_Minimap.GetNumTrackingTypes() return #S().tracking end
function C_Minimap.GetTrackingInfo(i) local t = S().tracking[i]; if t then return { name = t.name, texture = t.texture or 134400, active = t.active or false, spellID = t.spellID, type = t.type or "spell" } end end
function C_Minimap.SetTracking(i, on) local t = S().tracking[i]; if t then t.active = on and true or false end; record("SetTracking", i, on) end

C_PetInfo = {}
function C_PetInfo.GetPetHappiness() local p = S().pet; if p.exists then return p.happiness, 0, 0 end end
function C_PetInfo.GetPetTrainingPoints() local p = S().pet; if p.exists then return p.trainingTotal, p.trainingSpent end end

C_SkillInfo = {}
function C_SkillInfo.GetNumSkillLines() return #S().skillLines end
function C_SkillInfo.GetSkillLineInfo(i) local l = S().skillLines[i]; if l then return { skillName = l.name, isHeader = l.isHeader or false, skillRank = l.rank or 1 } end end

C_QuestLog = {}
-- WOW.Quest({ questID=, title=, level=, isHeader=, isComplete=, trivial=, objectives=, rewards=, choices= })
-- appends an entry to the fake quest log (creating it) and returns it.
function WOW.Quest(fields)
  S().questLog = S().questLog or {}
  local entry = fields
  S().questLog[#S().questLog + 1] = entry
  return entry
end
local function questByID(id)
  for _, q in ipairs(S().questLog or {}) do if q.questID == id then return q end end
end
function C_QuestLog.GetNumQuestLogEntries()
  local log = S().questLog
  if not log then return S().quests.num + 2, S().quests.num end
  local quests = 0
  for _, q in ipairs(log) do if not q.isHeader then quests = quests + 1 end end
  return #log, quests
end
function C_QuestLog.GetMaxNumQuestsCanAccept() return S().quests.max end
function C_QuestLog.IsQuestFlaggedCompleted(id) return S().completedQuests[id] == true end
function C_QuestLog.GetInfo(i)
  local q = S().questLog and S().questLog[i]
  if not q then return nil end
  return { questID = q.questID, title = q.title, level = q.level, isHeader = q.isHeader or false, isHidden = false,
           difficultyLevel = q.level, isComplete = q.isComplete or false }
end
function C_QuestLog.IsComplete(id) local q = questByID(id); return q and q.isComplete or false end
function C_QuestLog.IsQuestTrivial(id) local q = questByID(id); return q and q.trivial or false end
function C_QuestLog.GetQuestDifficultyLevel(id) local q = questByID(id); return q and q.level end
function C_QuestLog.GetQuestObjectives(id) local q = questByID(id); return q and q.objectives or {} end
function GetNumQuestLogRewards(id) local q = questByID(id); return q and #(q.rewards or {}) or 0 end
function GetNumQuestLogChoices(id) local q = questByID(id); return q and #(q.choices or {}) or 0 end
function UnitQuestTrivialLevelRange(unit) return S().trivialRange end

C_RestrictedActions = nil

-------------------------------------------------------------------------------
-- World map, exploration, texture pools
-------------------------------------------------------------------------------
C_Map = {}
function C_Map.GetBestMapForUnit(unit) return S().mapID end
function C_Map.GetMapInfo(mapID) local m = S().mapInfo[mapID]; if m then return { mapID = mapID, name = m.name, mapType = m.mapType, parentMapID = m.parentMapID } end end
Enum.UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 }
function C_Map.GetMapArtLayers(mapID) return S().mapLayers[mapID] or { { tileWidth = 256, tileHeight = 256 } } end
C_MapExplorationInfo = {}
function C_MapExplorationInfo.GetExploredMapTextures(mapID) return S().explored[mapID] end

function CreateTexturePool(parent, layer, subLevel)
  local pool = { active = {}, free = {} }
  function pool:Acquire()
    local t = table.remove(self.free)
    if not t then t = parent:CreateTexture(nil, layer) end
    t.subLevel = subLevel
    self.active[#self.active + 1] = t
    return t
  end
  function pool:ReleaseAll()
    for _, t in ipairs(self.active) do t:Hide(); t:ClearAllPoints(); self.free[#self.free + 1] = t end
    self.active = {}
  end
  function pool:EnumerateActive()
    local i = 0
    return function() i = i + 1; return self.active[i] end
  end
  function pool:GetNumActive() return #self.active end
  return pool
end

WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
WorldMapFrame.shown = false
WorldMapFrame.pins = {}
function WorldMapFrame:EnumeratePinsByTemplate(template)
  local i = 0
  return function() i = i + 1; return self.pins[i] end
end
function WOW.NewMapPin(mapID)
  local pin = CreateFrame("Frame")
  pin.layerIndex = 1
  pin.mapID = mapID
  pin.map = { GetMapID = function() return pin.mapID end, AddMaskableTexture = function(_, t) record("AddMaskableTexture", t) end }
  function pin:GetMap() return self.map end
  function pin:RefreshOverlays(full) record("RefreshOverlays", full) end
  WorldMapFrame.pins[#WorldMapFrame.pins + 1] = pin
  return pin
end

-------------------------------------------------------------------------------
-- UI actions (recorded)
-------------------------------------------------------------------------------
function ToggleAllBags() record("ToggleAllBags") end
function ToggleCharacter(tab) record("ToggleCharacter", tab) end
function ToggleQuestLog() record("ToggleQuestLog") end
function ToggleTalentFrame() record("ToggleTalentFrame") end
function ToggleSpellBook(tab) record("ToggleSpellBook", tab) end
function ActionButton_ShowOverlayGlow(frame) record("glow_show", frame) end
function ActionButton_HideOverlayGlow(frame) record("glow_hide", frame) end

-------------------------------------------------------------------------------
-- Settings API (recorded)
-------------------------------------------------------------------------------
Settings = { VarType = { Boolean = "boolean", Number = "number", String = "string" }, Default = { True = true, False = false } }
local function newCategory(name)
  local cat = { name = name }
  function cat:GetID() return name end
  function cat:GetName() return name end
  local layout = {}
  function layout:AddInitializer(init) record("initializer", init.kind, init.name) end
  return cat, layout
end
function Settings.RegisterVerticalLayoutCategory(name) record("RegisterVerticalLayoutCategory", name); return newCategory(name) end
function Settings.RegisterCanvasLayoutCategory(frame, name) record("RegisterCanvasLayoutCategory", name); return newCategory(name) end
function Settings.RegisterAddOnCategory(cat) record("RegisterAddOnCategory", cat.name) end
function Settings.RegisterVerticalLayoutSubcategory(parent, name)
  record("RegisterVerticalLayoutSubcategory", parent.name, name)
  local cat, layout = newCategory(name)
  cat.parent = parent
  return cat, layout
end
function Settings.CreateControlTextContainer()
  local c = { data = {} }
  function c:Add(value, label) self.data[#self.data + 1] = { value = value, label = label } end
  function c:GetData() return self.data end
  return c
end
function Settings.CreateDropdown(cat, setting, optionsFn, tooltip) record("dropdown", setting.variable, optionsFn(), tooltip) end
function Settings.RegisterProxySetting(cat, variable, vtype, name, default, getter, setter)
  WOW.settings[variable] = { getter = getter, setter = setter, name = name, default = default, type = vtype }
  record("RegisterProxySetting", variable)
  local setting = { variable = variable, name = name }
  function setting:GetVariable() return variable end
  function setting:GetValue() return getter() end
  function setting:SetValue(v) setter(v) end
  return setting
end
function Settings.RegisterAddOnSetting(cat, variable, key, tbl, vtype, name, default)
  return Settings.RegisterProxySetting(cat, variable, vtype, name, default, function() return tbl[key] end, function(v) tbl[key] = v end)
end
function Settings.CreateCheckbox(cat, setting, tooltip) record("checkbox", setting.variable, tooltip) end
function Settings.CreateSliderOptions(min, max, step) local o = { min = min, max = max, step = step }; function o:SetLabelFormatter() end; return o end
function Settings.CreateSlider(cat, setting, options, tooltip) record("slider", setting.variable, options.min, options.max, options.step) end
function Settings.OpenToCategory(id) record("OpenToCategory", id) end
function Settings.SetOnValueChangedCallback() end
function CreateSettingsButtonInitializer(name, text, fn, tooltip) return { kind = "button", name = name, text = text, fn = fn } end
function CreateSettingsListSectionHeaderInitializer(name) return { kind = "header", name = name } end
MinimapUtil = nil

-------------------------------------------------------------------------------
-- CVars and console (Task 19)
-------------------------------------------------------------------------------
Enum.ConsoleCommandType = { Cvar = 0, Command = 1, Macro = 2 }
Enum.ConsoleCategory = { Debug = 0, Graphics = 1, Console = 2, Combat = 3, Game = 4, Default = 5, Net = 6, Sound = 7, Gm = 8, Reveal = 9, None = 10 }
C_CVar = {}
function C_CVar.GetCVar(name) local c = S().cvars and S().cvars[name]; return c and tostring(c.value) end
function C_CVar.GetCVarDefault(name) local c = S().cvars and S().cvars[name]; return c and tostring(c.default) end
function C_CVar.SetCVar(name, value)
  record("SetCVar", name, value)
  S().cvars = S().cvars or {}
  local c = S().cvars[name]
  if c then c.value = tostring(value) else S().cvars[name] = { value = tostring(value), default = tostring(value) } end
  return true
end
function C_CVar.GetCVarBool(name) local v = C_CVar.GetCVar(name); return v == "1" end
function GetCVar(name) return C_CVar.GetCVar(name) end
function SetCVar(name, value) return C_CVar.SetCVar(name, value) end
function GetCVarDefault(name) return C_CVar.GetCVarDefault(name) end
C_Console = {}
function C_Console.GetAllCommands() return S().consoleCommands or {} end

-- Gamepad: the real client returns a font glyph from GetBindingText for pad
-- buttons, so the stub does the same and nothing may rely on it for labels.
C_GamePad = {}
function C_GamePad.IsEnabled() return S().gamepad.enabled end
function C_GamePad.GetActiveDeviceID() return S().gamepad.deviceID end
function GetBindingText(key) return "|" end
