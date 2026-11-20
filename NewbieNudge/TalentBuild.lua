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
  return true
end

function TalentBuild:Clear()
  NN.db.build = nil
  NN:Say(L.BUILD_CLEARED)
  recheck()
end

function TalentBuild:Status()
  local build = NN.db and NN.db.build
  if not build then return L.BUILD_STATUS_NONE end
  local taken = self.SpentPoints and self:SpentPoints() or 0
  return L.BUILD_STATUS:format((UnitClass("player")), #build.picks, taken)
end
