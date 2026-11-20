-- MapReveal: draws the overlay tiles the player has NOT explored, dimmed,
-- under Blizzard's own explored tiles, so the whole zone shape is visible.
-- The tile list per map comes from Data/MapFog.lua (WoW Handbook, GPL-3.0);
-- the explored set comes from the client. Blizzard's exploration pin is
-- post-hooked; our tiles live in our own texture pool on that pin.
local _, NN = ...
local L = NN.L

local MapReveal = { pools = {}, hooked = {} }
NN.MapReveal = MapReveal

-- Smallest power of two, at least 16, that holds px pixels (texture files
-- for edge tiles are padded this way).
local function fileSize(px)
  local n = 16
  while n < px do n = n * 2 end
  return n
end

function MapReveal.Key(w, h, x, y)
  return w .. ":" .. h .. ":" .. x .. ":" .. y
end

-- entries: rows of { w, h, offsetX, offsetY, fileID, fileID, ... } in
-- row-major order; exploredKeys: set of Key() strings to skip.
-- Returns { { fileID, x, y, w, h, u, v }, ... } ready to place on the pin.
function MapReveal.TilesFor(entries, exploredKeys, tileW, tileH)
  local tiles = {}
  for _, e in ipairs(entries) do
    local w, h, x, y = e[1], e[2], e[3], e[4]
    if not exploredKeys[MapReveal.Key(w, h, x, y)] then
      local numWide, numTall = math.ceil(w / tileW), math.ceil(h / tileH)
      for j = 1, numTall do
        local th = (j < numTall) and tileH or (h % tileH)
        if th == 0 then th = tileH end
        local fh = (j < numTall) and tileH or fileSize(th)
        for k = 1, numWide do
          local tw = (k < numWide) and tileW or (w % tileW)
          if tw == 0 then tw = tileW end
          local fw = (k < numWide) and tileW or fileSize(tw)
          local fileID = e[4 + (j - 1) * numWide + k]
          if fileID then
            tiles[#tiles + 1] = {
              fileID = fileID, x = x + tileW * (k - 1), y = y + tileH * (j - 1),
              w = tw, h = th, u = tw / fw, v = th / fh,
            }
          end
        end
      end
    end
  end
  return tiles
end

function MapReveal:PoolFor(pin)
  local pool = self.pools[pin]
  if not pool then
    pool = CreateTexturePool(pin, "ARTWORK", -1)
    self.pools[pin] = pool
  end
  return pool
end

-- Runs after Blizzard's MapExplorationPinMixin:RefreshOverlays.
function MapReveal:OnRefresh(pin)
  local pool = self:PoolFor(pin)
  pool:ReleaseAll()
  local db = NN.db
  if not (db and db.map and db.map.reveal) then return end
  local map = pin.GetMap and pin:GetMap()
  local mapID = map and map.GetMapID and NN.Plain(map:GetMapID())
  if not mapID then return end
  local data = NN.MapFog and NN.MapFog[mapID]
  if not data then return end
  if not (C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures) then return end
  -- Nothing back means nothing explored (a zone never entered), not "unknown".
  local explored = C_MapExplorationInfo.GetExploredMapTextures(mapID) or {}
  if type(explored) ~= "table" then return end
  local keys = {}
  for _, info in ipairs(explored) do
    local w, h = NN.Plain(info.textureWidth), NN.Plain(info.textureHeight)
    local x, y = NN.Plain(info.offsetX), NN.Plain(info.offsetY)
    if not (w and h and x and y) then return end -- secret or odd value: draw nothing this time
    keys[self.Key(w, h, x, y)] = true
  end
  local layers = C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(mapID)
  local layer = layers and (layers[pin.layerIndex or 1] or layers[1])
  if not layer then return end
  local tileW, tileH = NN.Plain(layer.tileWidth) or 256, NN.Plain(layer.tileHeight) or 256
  local b = db.map.brightness or 0.6
  for _, t in ipairs(self.TilesFor(data, keys, tileW, tileH)) do
    local tex = pool:Acquire()
    tex:SetTexture(t.fileID, nil, nil, "TRILINEAR")
    tex:SetSize(t.w, t.h)
    tex:SetTexCoord(0, t.u, 0, t.v)
    tex:SetPoint("TOPLEFT", pin, "TOPLEFT", t.x, -t.y)
    tex:SetDesaturated(db.map.desaturate and true or false)
    tex:SetVertexColor(b, b, b, 1)
    tex:SetDrawLayer("ARTWORK", -1)
    if map.AddMaskableTexture then map:AddMaskableTexture(tex) end
    tex:Show()
  end
end

-- Finds Blizzard's exploration pin(s) and hooks RefreshOverlays once each.
-- With no pin yet (map never opened), retries when the map frame shows.
function MapReveal:HookPins()
  local found = false
  if WorldMapFrame and WorldMapFrame.EnumeratePinsByTemplate then
    for pin in WorldMapFrame:EnumeratePinsByTemplate("MapExplorationPinTemplate") do
      found = true
      if not self.hooked[pin] then
        self.hooked[pin] = true
        self.pin = pin
        hooksecurefunc(pin, "RefreshOverlays", function(p) MapReveal:OnRefresh(p) end)
        -- A pin found while the map is already open has drawn its view before
        -- our hook existed: draw ours now rather than after the next redraw.
        if WorldMapFrame:IsShown() then self:OnRefresh(pin) end
      end
    end
  end
  if not found and WorldMapFrame and WorldMapFrame.HookScript and not self.onShowHooked then
    self.onShowHooked = true
    WorldMapFrame:HookScript("OnShow", function() MapReveal:HookPins() end)
  end
  return found
end

-- Redraws our tiles after an option change while the map is open.
function MapReveal:Refresh()
  if self.pin and WorldMapFrame and WorldMapFrame:IsShown() then self:OnRefresh(self.pin) end
end

NN:AfterLogin(function()
  if WorldMapFrame then MapReveal:HookPins() end
end)

-- The world map UI can load on demand; hook it when it arrives.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
  if name == "Blizzard_WorldMap" and WorldMapFrame then MapReveal:HookPins() end
end)

-------------------------------------------------------------------------------
-- Options page
-------------------------------------------------------------------------------

NN.Options.RegisterPage("map", "OPT_MAP", function(category, layout)
  local Options = NN.Options
  Options.AddCheckbox(category, "NN_map_reveal", L.OPT_MAP_REVEAL, L.OPT_MAP_REVEAL_TT,
    function() return NN.db.map.reveal end,
    function(value) NN.db.map.reveal = value and true or false; MapReveal:Refresh() end)
  Options.AddSlider(category, "NN_map_brightness", L.OPT_MAP_BRIGHTNESS, nil, 10, 100, 5,
    function() return math.floor((NN.db.map.brightness or 0.6) * 100 + 0.5) end,
    function(value) NN.db.map.brightness = value / 100; MapReveal:Refresh() end)
  Options.AddCheckbox(category, "NN_map_desaturate", L.OPT_MAP_DESATURATE, nil,
    function() return NN.db.map.desaturate end,
    function(value) NN.db.map.desaturate = value and true or false; MapReveal:Refresh() end)
end)
