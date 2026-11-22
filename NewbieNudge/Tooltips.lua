-- Tooltips: the vendor sell price on item tooltips when no merchant window
-- is open (the client only shows it at a vendor).
local _, NN = ...
local L = NN.L

local Tooltips = {}
NN.Tooltips = Tooltips

local moneyText = NN.MoneyText

-- data is the tooltip post-call payload (its id is the item ID); the
-- tooltip's own GetItem is the fallback.
function Tooltips.AddSellPrice(tooltip, data)
  if not (NN.db and NN.db.tooltipPrice ~= false) then return end
  if MerchantFrame and MerchantFrame:IsShown() then return end
  local item = data and NN.Plain(data.id)
  if not item and tooltip.GetItem then
    local _, link = tooltip:GetItem()
    item = link
  end
  if not item then return end
  local _, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(item)
  sellPrice = NN.Plain(sellPrice)
  if not sellPrice or sellPrice <= 0 then return end
  tooltip:AddDoubleLine(SELL_PRICE or L.TOOLTIP_SELL_PRICE, L.TOOLTIP_SELL_EACH:format(moneyText(sellPrice)), 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if tooltip == GameTooltip or tooltip == ItemRefTooltip then Tooltips.AddSellPrice(tooltip, data) end
  end)
elseif GameTooltip and GameTooltip.HookScript then
  GameTooltip:HookScript("OnTooltipSetItem", function(tooltip) Tooltips.AddSellPrice(tooltip) end)
end

-- Options: a "Tooltips" section of the Bags page.
function Tooltips.AddOptions(category, layout)
  NN.Options.AddHeader(layout, L.OPT_TOOLTIPS)
  NN.Options.AddCheckbox(category, "NN_tooltipPrice", L.OPT_TOOLTIP_PRICE, L.OPT_TOOLTIP_PRICE_TT,
    function() return NN.db.tooltipPrice ~= false end,
    function(value) NN.db.tooltipPrice = value and true or false end)
end
