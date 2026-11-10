-- At the vendor: sell protection and selling whole sections.
-- Protected items can neither be sold there by right-click nor dragged onto the vendor window,
-- and Blizzard's "Sell junk" button waits while there are any.
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

-- Blizzard's "Sell junk" has no exceptions: disable it while protected junk is present.
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

-- Right-click on a protected item at the vendor: nothing is sold, we just say why.
local function OnItemMouseUp(button, mouseButton)
    if mouseButton == "RightButton" and button.cubbySellBlocked and button:IsMouseOver() then
        NotifySellProtected()
    end
end

-- A protected item on the cursor at the vendor could be dropped there: put it straight back.
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

-- At the vendor only the right-click sells; protected items do not get it there.
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

---------------------------------------------------------------------------
-- Selling a whole section
---------------------------------------------------------------------------
-- Slots with sellable items of this group; returns the list, the total count and the value.
local function SellableSlots(tag)
    local slots, count, value = {}, 0, 0
    for _, bag in ipairs(Cubby.TaggableBags()) do
        for slot = 1, Cubby.NumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local slotValue = Cubby.SellValue(info)
            if info and not info.isLocked and slotValue > 0 and Cubby.TagForItem(info.itemID) == tag
                and not IsSellProtected(info.itemID) then
                slots[#slots + 1] = { bag = bag, slot = slot, itemID = info.itemID }
                count = count + (info.stackCount or 1)
                value = value + slotValue
            end
        end
    end
    return slots, count, value
end

-- Sells directly in the click on "Yes", in case WoW only allows sales on a real mouse click.
local function SellSection(tag)
    if not state.merchantOpen or tag.noSell then
        return
    end
    for _, entry in ipairs((SellableSlots(tag))) do
        if C_Container.GetContainerItemID(entry.bag, entry.slot) == entry.itemID then
            C_Container.UseContainerItem(entry.bag, entry.slot)
        end
    end
end

Cubby.UpdateBlizzardJunkButton = UpdateBlizzardJunkButton
Cubby.OnItemMouseUp = OnItemMouseUp
Cubby.DropProtectedCursorItem = DropProtectedCursorItem
Cubby.UpdateSellProtection = UpdateSellProtection
Cubby.SellableSlots = SellableSlots
Cubby.SellSection = SellSection
