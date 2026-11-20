-- Rule: tracking — the character knows Find Herbs or Find Minerals but the
-- minimap tracking is not set to it.
local _, NN = ...
local L = NN.L

local GATHERING = {
  { spellID = 2383, row = "TRACKING_ROW_HERBS" },    -- Find Herbs
  { spellID = 2580, row = "TRACKING_ROW_MINERALS" }, -- Find Minerals
}

local function trackingIndexFor(spellID)
  if not (C_Minimap and C_Minimap.GetNumTrackingTypes and C_Minimap.GetTrackingInfo) then return nil end
  local name = C_Spell.GetSpellName(spellID)
  for i = 1, NN.Plain(C_Minimap.GetNumTrackingTypes()) or 0 do
    local info = C_Minimap.GetTrackingInfo(i)
    if info and (info.spellID == spellID or (name and info.name == name)) then
      return i, info
    end
  end
  return nil
end

NN:RegisterRule({
  name = "tracking",
  title = L.TRACKING_TITLE,
  help = L.TRACKING_HELP,
  events = { "MINIMAP_UPDATE_TRACKING", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" },
  applies = function()
    for _, g in ipairs(GATHERING) do
      if NN.Spellbook:Knows(g.spellID) then return true end
    end
    return false
  end,
  check = function()
    local results = {}
    for _, g in ipairs(GATHERING) do
      if NN.Spellbook:Knows(g.spellID) then
        local index, info = trackingIndexFor(g.spellID)
        if index and not info.active then
          local displayName = info.name or C_Spell.GetSpellName(g.spellID)
          results[#results + 1] = {
            text = L[g.row]:format(displayName),
            icon = info.texture or C_Spell.GetSpellTexture(g.spellID),
            highlight = "tracking",
            onClick = function() C_Minimap.SetTracking(index, true) end,
          }
        end
      end
    end
    if #results == 0 then return nil end
    return results
  end,
  sample = function() return { { text = L.TRACKING_ROW_HERBS:format("Find Herbs"), icon = 133939 } } end,
})
