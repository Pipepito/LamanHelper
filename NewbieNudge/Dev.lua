-- Dev: developer mode. An account-wide log (saved variable NewbieNudgeDev)
-- of Lua errors, value dumps and state snapshots, so a problem seen in game
-- can be read later from WTF\Account\<account>\SavedVariables\NewbieNudge.lua
-- (the client writes it on logout or /reload), plus a copy window in game.
--
--   /nudge dev            show the log window (select all, copy)
--   /nudge dev on|off     record every Lua error (any addon) while on
--   /nudge dev snap       snapshot of client, addon, rules, bags and frames
--   /nudge dev clear      empty the log
--   /nudge dump <expr>    evaluate a Lua expression and log the result
local ADDON_NAME, NN = ...
local L = NN.L

local Dev = { MAX_ENTRIES = 100, MAX_DEPTH = 4, MAX_ITEMS = 40, MAX_STRING = 200 }
NN.Dev = Dev

-------------------------------------------------------------------------------
-- Saved variable
-------------------------------------------------------------------------------

local function ensureDB()
  if type(NewbieNudgeDev) ~= "table" then NewbieNudgeDev = {} end
  if NewbieNudgeDev.enabled == nil then NewbieNudgeDev.enabled = false end
  if type(NewbieNudgeDev.log) ~= "table" then NewbieNudgeDev.log = {} end
  Dev.db = NewbieNudgeDev
  return Dev.db
end

function Dev:IsEnabled()
  return self.db ~= nil and self.db.enabled == true
end

local function stamp()
  local ok, text = pcall(date, "%Y-%m-%d %H:%M:%S")
  return ok and text or ""
end

-- Appends one entry; the log keeps only the newest MAX_ENTRIES.
function Dev:Add(entry)
  local db = self.db or ensureDB()
  entry.time = entry.time or stamp()
  local log = db.log
  log[#log + 1] = entry
  while #log > self.MAX_ENTRIES do table.remove(log, 1) end
  return entry
end

function Dev:Clear()
  local db = self.db or ensureDB()
  wipe(db.log)
end

-------------------------------------------------------------------------------
-- Serializer: readable, bounded, never errors on game values
-------------------------------------------------------------------------------

local function quote(s)
  if #s > Dev.MAX_STRING then s = s:sub(1, Dev.MAX_STRING) .. "..." end
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r")
  return '"' .. s .. '"'
end

local function frameLabel(v)
  local ok, kind = pcall(v.GetObjectType, v)
  if not ok then return nil end
  local okName, name = pcall(v.GetName, v)
  return "<" .. tostring(kind) .. (okName and name and (" " .. tostring(name)) or "") .. ">"
end

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    if ta == "number" or ta == "string" then return a < b end
    return tostring(a) < tostring(b)
  end)
  return keys
end

local function serialize(v, depth, seen)
  if issecretvalue and issecretvalue(v) then return "<secret>" end
  local t = type(v)
  if t == "string" then return quote(v) end
  if t ~= "table" then return t == "function" and "<function>" or (t == "userdata" and "<userdata>" or tostring(v)) end
  if type(v.GetObjectType) == "function" then
    local label = frameLabel(v)
    if label then return label end
  end
  if seen[v] then return "<cycle>" end
  if depth >= Dev.MAX_DEPTH then return "{...}" end
  seen[v] = true
  local keys = sortedKeys(v)
  local parts = {}
  local shown = math.min(#keys, Dev.MAX_ITEMS)
  for i = 1, shown do
    local k = keys[i]
    local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or ("[" .. serialize(k, Dev.MAX_DEPTH, seen) .. "]")
    parts[#parts + 1] = key .. " = " .. serialize(v[k], depth + 1, seen)
  end
  if #keys > shown then parts[#parts + 1] = ("(+%d more)"):format(#keys - shown) end
  seen[v] = nil
  if #parts == 0 then return "{}" end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

function Dev.Serialize(v)
  local ok, text = pcall(serialize, v, 0, {})
  return ok and text or ("<serialize failed: " .. tostring(text) .. ">")
end

local function serializeAll(n, ...)
  local parts = {}
  for i = 1, n do parts[i] = Dev.Serialize((select(i, ...))) end
  return table.concat(parts, ", ")
end

-------------------------------------------------------------------------------
-- Error capture
-------------------------------------------------------------------------------

-- Adds an entry unless it repeats the previous one, which is counted instead.
local function addOrCount(kind, text, stack)
  local db = Dev.db or ensureDB()
  local log = db.log
  local lastEntry = log[#log]
  if lastEntry and lastEntry.kind == kind and lastEntry.text == text then
    lastEntry.count = (lastEntry.count or 1) + 1
    lastEntry.time = stamp()
    return
  end
  Dev:Add({ kind = kind, text = text, stack = stack, count = 1 })
end

local function recordError(msg)
  addOrCount("error", tostring(msg), debugstack and debugstack(3, 12, 0) or nil)
end

-- ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN never reach the error
-- handler; they are the only trace a tainted call leaves.
local BLOCKED_EVENTS = { ADDON_ACTION_BLOCKED = "blocked", ADDON_ACTION_FORBIDDEN = "forbidden" }
local function recordBlocked(event, addon, func)
  addOrCount(BLOCKED_EVENTS[event], ("%s: %s"):format(tostring(addon), tostring(func)))
end

function Dev:InstallHandler()
  if self.handler then return end
  local previous = geterrorhandler and geterrorhandler() or nil
  self.previousHandler = previous
  self.handler = function(msg)
    pcall(recordError, msg)
    if previous then return previous(msg) end
  end
  if seterrorhandler then seterrorhandler(self.handler) end
  for event in pairs(BLOCKED_EVENTS) do self.loader:RegisterEvent(event) end
end

function Dev:RemoveHandler()
  if not self.handler then return end
  if seterrorhandler and geterrorhandler and geterrorhandler() == self.handler then
    seterrorhandler(self.previousHandler)
  end
  self.handler, self.previousHandler = nil, nil
  for event in pairs(BLOCKED_EVENTS) do self.loader:UnregisterEvent(event) end
end

function Dev:SetEnabled(on)
  local db = self.db or ensureDB()
  db.enabled = on and true or false
  if db.enabled then self:InstallHandler() else self:RemoveHandler() end
end

-------------------------------------------------------------------------------
-- Dump and snapshot
-------------------------------------------------------------------------------

-- nil in the middle of the returns must survive, so count them with select.
local function collectReturns(ok, ...)
  if not ok then return nil, (...) end
  return select("#", ...), { ... }
end

-- Evaluates a Lua expression (as /dump does) and logs the result; the chat
-- shows its beginning. Works with developer mode off.
function Dev:Dump(expr)
  if not expr or expr == "" then NN:Say(L.DEV_DUMP_USAGE); return nil end
  local text
  local chunk, compileErr = loadstring("return " .. expr, "=dump")
  if not chunk then
    text = "error: " .. tostring(compileErr)
  else
    local n, packed = collectReturns(pcall(chunk))
    if n then
      text = serializeAll(n, unpack(packed, 1, n))
    else
      text = "error: " .. tostring(packed)
    end
  end
  self:Add({ kind = "dump", expr = expr, text = text })
  local head = text
  if #head > 200 then head = head:sub(1, 200) .. "..." end
  NN:Say(L.DEV_DUMP_SAVED:format(expr, head))
  return text
end

-- Each section is one function; a failing one writes its error instead of
-- taking the snapshot down.
local SECTIONS = {
  { "client", function(out)
    local version, build, built, interface = GetBuildInfo()
    out[#out + 1] = ("client %s build %s (%s) interface %s"):format(tostring(version), tostring(build), tostring(built), tostring(interface))
    out[#out + 1] = ("locale %s project %s"):format(tostring(GetLocale and GetLocale()), tostring(WOW_PROJECT_ID))
    local meta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    out[#out + 1] = ("addon %s version %s"):format(ADDON_NAME, tostring(meta and meta(ADDON_NAME, "Version")))
    out[#out + 1] = ("player %s-%s %s %s level %s"):format(tostring(UnitName and UnitName("player")), tostring(GetRealmName and GetRealmName()),
      tostring(UnitRace and (UnitRace("player"))), tostring(NN.classFile), tostring(UnitLevel and UnitLevel("player")))
    out[#out + 1] = ("scriptErrors %s combinedBags %s"):format(tostring(GetCVar and GetCVar("scriptErrors")), tostring(GetCVar and GetCVar("combinedBags")))
  end },
  { "addons", function(out)
    local A = C_AddOns
    if not (A and A.GetNumAddOns) then out[#out + 1] = "no C_AddOns"; return end
    local loaded = {}
    for i = 1, A.GetNumAddOns() do
      local name = A.GetAddOnInfo(i)
      if A.IsAddOnLoaded(i) then loaded[#loaded + 1] = tostring(name) end
    end
    out[#out + 1] = "loaded: " .. table.concat(loaded, ", ")
  end },
  { "rules", function(out)
    for _, rule in ipairs(NN.rules) do
      local results = NN.results[rule.name] or {}
      local first = results[1] and results[1].text
      out[#out + 1] = ("%s: %s%s"):format(rule.name, tostring(NN:RuleStateText(rule)),
        #results > 0 and (" -> " .. #results .. " row(s): " .. tostring(first)) or "")
    end
    out[#out + 1] = "errors: " .. Dev.Serialize(NN.db and NN.db.errors)
    out[#out + 1] = "db: " .. Dev.Serialize(NN.db)
  end },
  { "bags", function(out)
    for bag = -1, 11 do
      local n = C_Container and C_Container.GetContainerNumSlots and NN.Plain(C_Container.GetContainerNumSlots(bag))
      if n and n > 0 then out[#out + 1] = ("bag %d: %d slots"):format(bag, n) end
    end
    for bag = 1, 5 do
      out[#out + 1] = ("inventory slot for bag %d: %s"):format(bag, tostring(NN.BagInventorySlot and NN.BagInventorySlot(bag)))
    end
    local frames = {}
    if type(ContainerFrameUtil_EnumerateContainerFrames) == "function" then
      local f, state, control = ContainerFrameUtil_EnumerateContainerFrames()
      while true do
        local a, b = f(state, control)
        if a == nil then break end
        control = a
        local frame = type(a) == "table" and a or b
        if type(frame) == "table" then
          local shown = frame.IsShown and frame:IsShown()
          local id = frame.GetBagID and frame:GetBagID() or (frame.GetID and frame:GetID())
          frames[#frames + 1] = ("%s(bag %s%s)"):format(tostring(frame.GetName and frame:GetName() or "?"), tostring(id), shown and ", shown" or "")
        end
      end
    end
    out[#out + 1] = "containers: " .. (#frames > 0 and table.concat(frames, " ") or "none")
    out[#out + 1] = ("combined bags frame: %s bank frame: %s"):format(
      Dev.Serialize(ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown()),
      Dev.Serialize(BankFrame and BankFrame:IsShown()))
    local H = NN.Highlight
    if H then
      local active, hooked = 0, 0
      for _ in pairs(H.active) do active = active + 1 end
      for _ in pairs(H.hookedBagFrames) do hooked = hooked + 1 end
      out[#out + 1] = ("highlights active %d, hooked bag frames %d"):format(active, hooked)
    end
  end },
  { "bank", function(out)
    local B = C_Bank
    if not (B and Enum and Enum.BankType) then out[#out + 1] = "no C_Bank"; return end
    local reasonName = {}
    for name, value in pairs(Enum.BankLockedReason or {}) do reasonName[value] = name end
    for _, typeName in ipairs(sortedKeys(Enum.BankType)) do
      local bankType = Enum.BankType[typeName]
      local locked = B.FetchBankLockedReason and B.FetchBankLockedReason(bankType)
      local tabs = B.FetchPurchasedBankTabData and B.FetchPurchasedBankTabData(bankType)
      out[#out + 1] = ("%s: viewable %s, locked %s, %d tab(s)"):format(typeName,
        tostring(B.CanViewBank and B.CanViewBank(bankType)),
        locked == nil and "nil" or tostring(reasonName[locked] or locked),
        type(tabs) == "table" and #tabs or 0)
    end
    out[#out + 1] = "any bank viewable: " .. tostring(B.AreAnyBankTypesViewable and B.AreAnyBankTypesViewable())
  end },
  -- v4 map marks: everything needed to debug a pin from one snapshot.
  { "services", function(out)
    local db = NN.db and NN.db.services
    if not db then out[#out + 1] = "no services settings"; return end
    out[#out + 1] = ("showAll %s kinds %s"):format(tostring(db.showAll), Dev.Serialize(db.kinds))
    for _, m in ipairs(NN.db.marks or {}) do
      local npcs = {}
      for _, id in ipairs(m.npcs or { m.npcID }) do npcs[#npcs + 1] = tostring(id) end
      out[#out + 1] = ("mark %s npc %s fromRow %s rule %s"):format(tostring(m.kind),
        table.concat(npcs, ","), tostring(m.fromRow), tostring(m.rule))
    end
  end },
  { "map", function(out)
    local W = WorldMapFrame
    if not W then out[#out + 1] = "no WorldMapFrame"; return end
    local child = W.ScrollContainer and W.ScrollContainer.Child
    out[#out + 1] = ("world map shown %s, map %s, strata %s level %s"):format(tostring(W:IsShown()),
      tostring(W.GetMapID and W:GetMapID()), tostring(W.GetFrameStrata and W:GetFrameStrata()), tostring(W.GetFrameLevel and W:GetFrameLevel()))
    if child then
      local scale = W.ScrollContainer.GetCanvasScale and W.ScrollContainer:GetCanvasScale()
      out[#out + 1] = ("canvas %sx%s scale %s level %s visible %s"):format(tostring(child:GetWidth()), tostring(child:GetHeight()),
        tostring(scale), tostring(child:GetFrameLevel()), tostring(child.IsVisible and child:IsVisible()))
    end
    for i, p in ipairs(NN.MapPins and NN.MapPins.pins or {}) do
      local point, rel, relPoint, x, y = p:GetPoint(1)
      out[#out + 1] = ("pin %d: npc %s kind %s marked %s shown %s visible %s alpha %s"):format(i, tostring(p.npcID), tostring(p.kind),
        tostring(p.marked), tostring(p:IsShown()), tostring(p.IsVisible and p:IsVisible()), tostring(p:GetAlpha()))
      out[#out + 1] = ("  size %sx%s scale %s effective %s strata %s level %s at %s %s %s,%s"):format(tostring(p:GetWidth()), tostring(p:GetHeight()),
        tostring(p.GetScale and p:GetScale()), tostring(p:GetEffectiveScale()), tostring(p:GetFrameStrata()), tostring(p:GetFrameLevel()),
        tostring(point), tostring(relPoint), tostring(x), tostring(y))
      local icon, ring = p.icon, p.ring
      out[#out + 1] = ("  texture %s icon shown %s alpha %s coords %s mask %s ring shown %s ring size %sx%s"):format(
        Dev.Serialize(icon:GetTexture()), tostring(icon:IsShown()), tostring(icon:GetAlpha()),
        Dev.Serialize(icon.GetTexCoord and { icon:GetTexCoord() }), tostring(icon.GetNumMaskTextures and icon:GetNumMaskTextures()),
        tostring(ring and ring:IsShown()), tostring(ring and ring:GetWidth()), tostring(ring and ring:GetHeight()))
    end
  end },
  { "player", function(out)
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local pos = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
    local x, y
    if pos then x, y = pos:GetXY() end
    out[#out + 1] = ("map %s at %s,%s level %s faction %s"):format(tostring(map),
      x and ("%.2f"):format(x) or "?", y and ("%.2f"):format(y) or "?",
      tostring(UnitLevel and UnitLevel("player")), tostring(UnitFactionGroup and UnitFactionGroup("player")))
    if NN.Services and NN.Services.PlayerWorldPos then
      local c, wx, wy = NN.Services:PlayerWorldPos()
      out[#out + 1] = ("continent %s world %s,%s"):format(tostring(c), tostring(wx), tostring(wy))
    end
  end },
  { "taxi", function(out)
    if not (C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap) then out[#out + 1] = "no C_TaxiMap"; return end
    for _, continent in ipairs({ 1414, 1415 }) do
      local nodes = C_TaxiMap.GetTaxiNodesForMap(continent) or {}
      out[#out + 1] = ("continent map %d: %d node(s)"):format(continent, #nodes)
      for _, n in ipairs(nodes) do
        local pos = n.position
        local px, py
        if type(pos) == "table" then
          if pos.GetXY then px, py = pos:GetXY() else px, py = pos.x, pos.y end
        end
        out[#out + 1] = ("  %s state %s at %s,%s"):format(tostring(n.name), tostring(n.state), tostring(px), tostring(py))
      end
    end
  end },
  { "professions", function(out)
    if not (GetProfessions and GetProfessionInfo) then out[#out + 1] = "no profession API"; return end
    for slot, index in pairs({ GetProfessions() }) do
      local name, icon, skill, max, _, _, line = GetProfessionInfo(index)
      out[#out + 1] = ("slot %s: %s skillLine %s icon %s %s/%s"):format(tostring(slot), tostring(name), tostring(line),
        tostring(icon), tostring(skill), tostring(max))
    end
  end },
  { "tracking", function(out)
    if not (C_Minimap and C_Minimap.GetNumTrackingTypes) then out[#out + 1] = "no tracking API"; return end
    for i = 1, C_Minimap.GetNumTrackingTypes() or 0 do
      local info = C_Minimap.GetTrackingInfo(i)
      if type(info) == "table" then
        out[#out + 1] = ("%s active %s"):format(tostring(info.name), tostring(info.active))
      else
        out[#out + 1] = Dev.Serialize({ C_Minimap.GetTrackingInfo(i) })
      end
    end
  end },
}

function Dev:Snapshot()
  local out = {}
  for _, section in ipairs(SECTIONS) do
    out[#out + 1] = "[" .. section[1] .. "]"
    local ok, err = pcall(section[2], out)
    if not ok then out[#out + 1] = "section failed: " .. tostring(err) end
  end
  local text = table.concat(out, "\n")
  self:Add({ kind = "snapshot", text = text })
  NN:Say(L.DEV_SNAPSHOT_SAVED)
  return text
end

-------------------------------------------------------------------------------
-- Copy window
-------------------------------------------------------------------------------

function Dev:LogText()
  local db = self.db or ensureDB()
  local out = {}
  for i, entry in ipairs(db.log) do
    local head = ("#%d %s %s"):format(i, tostring(entry.time), entry.kind)
    if entry.kind == "dump" then head = head .. " " .. tostring(entry.expr) end
    if (entry.count or 1) > 1 then head = head .. (" x%d"):format(entry.count) end
    out[#out + 1] = head
    out[#out + 1] = tostring(entry.text)
    if entry.stack then out[#out + 1] = tostring(entry.stack) end
    out[#out + 1] = ""
  end
  return table.concat(out, "\n")
end

local function buildFrame()
  local frame = CreateFrame("Frame", "NewbieNudgeDevLog", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  frame:SetSize(620, 420)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  frame.bg = frame:CreateTexture(nil, "BACKGROUND")
  frame.bg:SetAllPoints()
  frame.bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.title:SetPoint("TOP", frame, "TOP", 0, -8)
  frame.title:SetText(L.DEV_WINDOW_TITLE)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  close:SetScript("OnClick", function() frame:Hide() end)

  local scroll = CreateFrame("ScrollFrame", "NewbieNudgeDevLogScroll", frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 12)
  local editBox = CreateFrame("EditBox", nil, scroll)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  editBox:SetFontObject(ChatFontNormal or GameFontHighlightSmall or "GameFontHighlightSmall")
  editBox:SetWidth(560)
  editBox:SetMaxLetters(0)
  editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); frame:Hide() end)
  editBox:SetScript("OnTextChanged", function(self, userInput)
    -- the box is read-only in spirit: typing is harmless, nothing reads it
  end)
  scroll:SetScrollChild(editBox)
  frame.editBox = editBox
  frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  frame.hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 2)
  frame.hint:SetText(L.DEV_WINDOW_HINT)
  frame:Hide()
  if UISpecialFrames then tinsert(UISpecialFrames, "NewbieNudgeDevLog") end
  return frame
end

function Dev:Show()
  local db = self.db or ensureDB()
  if #db.log == 0 then NN:Say(L.DEV_LOG_EMPTY); return false end
  self.frame = self.frame or buildFrame()
  self.frame.editBox:SetText(self:LogText())
  self.frame:Show()
  self.frame.editBox:SetFocus()
  self.frame.editBox:HighlightText()
  self.frame.editBox:SetCursorPosition(0)
  return true
end

-------------------------------------------------------------------------------
-- Slash entry points, saved variable load, options page
-------------------------------------------------------------------------------

function Dev:HandleCommand(arg)
  if arg == "on" then
    self:SetEnabled(true)
    NN:Say(L.DEV_ON)
  elseif arg == "off" then
    self:SetEnabled(false)
    NN:Say(L.DEV_OFF)
  elseif arg == "snap" or arg == "snapshot" then
    self:Snapshot()
  elseif arg == "clear" then
    self:Clear()
    NN:Say(L.DEV_CLEARED)
  else
    self:Show()
  end
end

local loader = CreateFrame("Frame")
Dev.loader = loader
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, event, ...)
  if BLOCKED_EVENTS[event] then
    if Dev:IsEnabled() then pcall(recordBlocked, event, ...) end
    return
  end
  local name = ...
  if name ~= ADDON_NAME then return end
  ensureDB()
  if Dev:IsEnabled() then Dev:InstallHandler() end
end)

NN.Options.RegisterPage("dev", "OPT_DEV", function(category, layout)
  local Options = NN.Options
  Options.AddCheckbox(category, "NN_dev_enabled", L.OPT_DEV_ENABLED, L.OPT_DEV_ENABLED_TT,
    function() return Dev:IsEnabled() end,
    function(value) Dev:SetEnabled(value) end)
  Options.AddButton(layout, L.OPT_DEV_SNAPSHOT, L.OPT_BUTTON_DO, function() Dev:Snapshot() end, L.OPT_DEV_SNAPSHOT_TT)
  Options.AddButton(layout, L.OPT_DEV_SHOW, L.OPT_BUTTON_DO, function() Dev:Show() end, L.OPT_DEV_SHOW_TT)
  Options.AddButton(layout, L.OPT_DEV_CLEAR, L.OPT_BUTTON_DO, function() Dev:Clear(); NN:Say(L.DEV_CLEARED) end)
end)
