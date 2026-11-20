-- Tooltips: the vendor sell price on item tooltips when no merchant window
-- is open (the client only shows it at a vendor).
local _, NN = ...
local L = NN.L

local Tooltips = {}
NN.Tooltips = Tooltips

local function moneyText(value)
  if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then return C_CurrencyInfo.GetCoinTextureString(value) end
  if GetMoneyString then return GetMoneyString(value) end
  return tostring(value)
end

function Tooltips.AddSellPrice(tooltip)
  if not (NN.db and NN.db.tooltipPrice ~= false) then return end
  if MerchantFrame and MerchantFrame:IsShown() then return end
  if not tooltip.GetItem then return end
  local _, link = tooltip:GetItem()
  if not link then return end
  local _, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(link)
  sellPrice = NN.Plain(sellPrice)
  if not sellPrice or sellPrice <= 0 then return end
  tooltip:AddDoubleLine(SELL_PRICE or L.TOOLTIP_SELL_PRICE, L.TOOLTIP_SELL_EACH:format(moneyText(sellPrice)), 0.7, 0.7, 0.7, 0.9, 0.9, 0.9)
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
    if tooltip == GameTooltip or tooltip == ItemRefTooltip then Tooltips.AddSellPrice(tooltip) end
  end)
elseif GameTooltip and GameTooltip.HookScript then
  GameTooltip:HookScript("OnTooltipSetItem", function(tooltip) Tooltips.AddSellPrice(tooltip) end)
end

NN.Options.RegisterPage("tooltips", "OPT_TOOLTIPS", function(category, layout)
  NN.Options.AddCheckbox(category, "NN_tooltipPrice", L.OPT_TOOLTIP_PRICE, L.OPT_TOOLTIP_PRICE_TT,
    function() return NN.db.tooltipPrice ~= false end,
    function(value) NN.db.tooltipPrice = value and true or false end)
end)
