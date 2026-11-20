-- Test helpers shared by every tests/test_*.lua file.

local function dump(v)
  if type(v) ~= "table" then return tostring(v) end
  local parts = {}
  for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. dump(x) end
  table.sort(parts)
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function same(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for k, v in pairs(a) do if not same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

function assert_eq(actual, expected, msg)
  if not same(actual, expected) then
    error((msg and (msg .. ": ") or "") .. "expected " .. dump(expected) .. " but got " .. dump(actual), 2)
  end
end

function assert_true(v, msg)
  if not v then error((msg and (msg .. ": ") or "") .. "expected a true value but got " .. dump(v), 2) end
end

function assert_nil(v, msg)
  if v ~= nil then error((msg and (msg .. ": ") or "") .. "expected nil but got " .. dump(v), 2) end
end

local function readable(path)
  local f = io.open(path, "r")
  if f then f:close(); return true end
  return false
end

-- Loads the addon the way the game would: each TOC-listed file gets
-- (ADDON_NAME, sharedTable). Files the TOC lists but that do not exist yet
-- are skipped so early tasks can run. Then fires the login events.
-- Does NOT fire BAG_UPDATE_DELAYED; call load_bags() for that.
function load_addon()
  local toc = io.open(ADDON_DIR .. "/NewbieNudge.toc", "r")
  if not toc then error("no TOC", 2) end
  local ns = {}
  local files = {}
  for line in toc:lines() do
    line = line:gsub("\r", "")
    if line:match("%S") and not line:match("^##") then files[#files + 1] = line end
  end
  toc:close()
  if not WOW.keepData then files[#files + 1] = TESTS_DIR .. "/fixtures/quiet_data.lua" end
  for _, extra in ipairs(WOW.extraFiles or {}) do files[#files + 1] = extra end
  for _, rel in ipairs(files) do
    local path = rel:match("^/") and rel or (ADDON_DIR .. "/" .. rel:gsub("\\", "/"))
    if rel:match("^[A-Za-z]:") then path = rel end
    if readable(path) then
      local chunk = assert(loadfile(path))
      chunk("NewbieNudge", ns)
    end
  end
  WOW.FireEvent("ADDON_LOADED", "NewbieNudge")
  WOW.FireEvent("PLAYER_LOGIN")
  WOW.FireEvent("PLAYER_ENTERING_WORLD", true, false)
  return ns
end

function load_bags()
  WOW.FireEvent("BAG_UPDATE_DELAYED")
end

function run_checks()
  WOW.AdvanceTime(0.5)
end

function results_of(ruleName)
  return (NewbieNudge and NewbieNudge.results and NewbieNudge.results[ruleName]) or {}
end

function row_texts()
  local out = {}
  if not (NewbieNudge and NewbieNudge.Panel) then return out end
  for _, row in ipairs(NewbieNudge.Panel.rows) do
    if row:IsShown() then out[#out + 1] = row.text:GetText() end
  end
  return out
end
