-- Vendor: when a merchant window opens, sell every grey stack and repair,
-- each behind its own option, with one chat line per action. Selling runs
-- in small ticks because the client drops rapid sell requests.
local _, NN = ...
local L = NN.L

local Vendor = {}
NN.Vendor = Vendor

local PER_TICK, TICK = 10, 0.3

local moneyText = NN.MoneyText

local function merchantOpen()
  return MerchantFrame ~= nil and MerchantFrame:IsShown()
end

-- Grey stacks still in the bags: { { bag, slot, itemID, count, price }, ... }
local function greyStacks()
  local list = {}
  for bag = 0, 4 do
    for slot = 1, NN.Plain(C_Container.GetContainerNumSlots(bag)) or 0 do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      local itemID = info and NN.Plain(info.itemID)
      if itemID and NN.Plain(info.quality) == 0 and info.isLocked ~= true and info.hasNoValue ~= true then
        local _, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(NN.Plain(info.hyperlink, "string") or itemID)
        sellPrice = NN.Plain(sellPrice) or 0
        if sellPrice > 0 then
          list[#list + 1] = { bag = bag, slot = slot, itemID = itemID, count = NN.Plain(info.stackCount) or 1, price = sellPrice }
        end
      end
    end
  end
  return list
end

local function stopSelling()
  if Vendor.ticker then Vendor.ticker:Cancel(); Vendor.ticker = nil end
  Vendor.queue = nil
end

local function finishSelling()
  local sold, copper = Vendor.sold or 0, Vendor.copper or 0
  stopSelling()
  if sold > 0 then NN:Say(L.VENDOR_SOLD:format(sold, moneyText(copper))) end
  -- Repair once the sale proceeds are in, so junk money counts toward it.
  if merchantOpen() and Vendor.repairPending then
    Vendor.repairPending = nil
    Vendor:Repair()
  end
end

local function sellTick()
  if not merchantOpen() or not Vendor.queue then stopSelling(); return end
  local done = 0
  while done < PER_TICK and #Vendor.queue > 0 do
    local entry = table.remove(Vendor.queue, 1)
    -- the slot may have changed since the queue was built
    local info = C_Container.GetContainerItemInfo(entry.bag, entry.slot)
    if info and NN.Plain(info.itemID) == entry.itemID and NN.Plain(info.quality) == 0 and info.isLocked ~= true then
      C_Container.UseContainerItem(entry.bag, entry.slot)
      Vendor.sold = (Vendor.sold or 0) + 1
      Vendor.copper = (Vendor.copper or 0) + entry.price * entry.count
      done = done + 1
    end
  end
  if #Vendor.queue == 0 then finishSelling() end
end

-- Returns true when selling is still running on the ticker.
function Vendor:SellJunk()
  stopSelling()
  self.sold, self.copper = 0, 0
  self.queue = greyStacks()
  if #self.queue == 0 then self.queue = nil; return false end
  sellTick()
  if self.queue and #self.queue > 0 then
    self.ticker = C_Timer.NewTicker(TICK, sellTick)
    return true
  end
  return false
end

function Vendor:Repair()
  if not (CanMerchantRepair and CanMerchantRepair() == true and GetRepairAllCost and RepairAllItems) then return end
  local cost = NN.Plain((GetRepairAllCost()))
  if not cost or cost <= 0 then return end
  local money = NN.Plain(GetMoney and GetMoney()) or 0
  if cost > money then
    NN:Say(L.VENDOR_REPAIR_POOR:format(moneyText(cost), moneyText(money)))
    return
  end
  RepairAllItems()
  NN:Say(L.VENDOR_REPAIRED:format(moneyText(cost)))
end

function Vendor:OnMerchantShow()
  if InCombatLockdown and InCombatLockdown() then return end
  local db = NN.db and NN.db.vendor
  if not db then return end
  self.repairPending = db.repair and true or nil
  local selling = db.sellJunk and self:SellJunk()
  if not selling and self.repairPending then
    self.repairPending = nil
    self:Repair()
  end
end

function Vendor:OnMerchantClosed()
  self.repairPending = nil
  if self.queue then finishSelling() end
end

NN:RegisterEvent("MERCHANT_SHOW")
NN:RegisterEvent("MERCHANT_CLOSED")
NN:OnAnyEvent(function(event)
  if event == "MERCHANT_SHOW" then Vendor:OnMerchantShow()
  elseif event == "MERCHANT_CLOSED" then Vendor:OnMerchantClosed() end
end)

-- Options: two checkboxes in a "Vendors" section of the Bags page.
function Vendor.AddOptions(category, layout)
  local Options = NN.Options
  Options.AddHeader(layout, L.OPT_BAGS_VENDOR)
  Options.AddCheckbox(category, "NN_vendor_sellJunk", L.OPT_VENDOR_SELL, L.OPT_VENDOR_SELL_TT,
    function() return NN.db.vendor.sellJunk end,
    function(value) NN.db.vendor.sellJunk = value and true or false end)
  Options.AddCheckbox(category, "NN_vendor_repair", L.OPT_VENDOR_REPAIR, L.OPT_VENDOR_REPAIR_TT,
    function() return NN.db.vendor.repair end,
    function(value) NN.db.vendor.repair = value and true or false end)
end
