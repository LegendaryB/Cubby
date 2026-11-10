-- Verkaufsschutz beim Haendler: geschuetzte Items lassen sich dort weder per Rechtsklick verkaufen
-- noch auf das Haendlerfenster ziehen, und Blizzards "Schrott verkaufen" wartet, solange welche da sind.
local _, Cubby = ...
local state = Cubby.state
local L = Cubby.L
local IsSellProtected = Cubby.IsSellProtected

local function HasProtectedJunk()
    for _, bag in ipairs(Cubby.MainBags()) do
        for slot = 1, Cubby.NumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue and IsSellProtected(info.itemID) then
                return true
            end
        end
    end
    return false
end

-- Blizzards "Schrott verkaufen" kennt keine Ausnahmen: sperren, solange geschuetzter Schrott da ist.
local function UpdateBlizzardJunkButton()
    local button = MerchantSellAllJunkButton
    if not button or not state.merchantOpen or not C_MerchantFrame or not C_MerchantFrame.GetNumJunkItems then
        return
    end
    local canSell = C_MerchantFrame.GetNumJunkItems() > 0 and not HasProtectedJunk()
    button:SetEnabled(canSell)
    if button.Icon then
        button.Icon:SetDesaturated(not canSell)
    end
end

local function NotifySellProtected()
    UIErrorsFrame:AddMessage(L.SELL_PROTECTED_MESSAGE, 1, 0.3, 0.3)
end

-- Rechtsklick auf ein geschuetztes Item beim Haendler: verkauft wird nicht, wir sagen nur warum.
local function OnItemMouseUp(button, mouseButton)
    if mouseButton == "RightButton" and button.cubbySellBlocked and button:IsMouseOver() then
        NotifySellProtected()
    end
end

-- Liegt ein geschuetztes Item beim Haendler auf dem Mauszeiger, koennte man es dort ablegen: sofort zuruecklegen.
local function DropProtectedCursorItem()
    if not state.merchantOpen then
        return
    end
    local cursorType, itemID = GetCursorInfo()
    if cursorType == "item" and IsSellProtected(itemID) then
        ClearCursor()
        NotifySellProtected()
    end
end

-- Beim Haendler verkauft nur der Rechtsklick; geschuetzte Items bekommen ihn dort nicht.
local function UpdateSellProtection(button, tag)
    local blocked = state.merchantOpen and tag ~= nil and tag.noSell == true
    if button.cubbySellBlocked ~= blocked then
        button.cubbySellBlocked = blocked
        if blocked then
            button:RegisterForClicks("LeftButtonUp")
        else
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        end
    end
end

Cubby.UpdateBlizzardJunkButton = UpdateBlizzardJunkButton
Cubby.OnItemMouseUp = OnItemMouseUp
Cubby.DropProtectedCursorItem = DropProtectedCursorItem
Cubby.UpdateSellProtection = UpdateSellProtection
