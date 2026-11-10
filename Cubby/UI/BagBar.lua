-- Bag bar: one small icon per bag, right of the search box. Hovering an icon highlights that bag's
-- slots, dropping a bag on an icon equips it and dragging an icon picks the bag up, like Blizzard's
-- own bag bar does (it uses the same plain API calls, no protected frames are touched).
local _, Cubby = ...
local L = Cubby.L
local frame, PAD = Cubby.frame, Cubby.PAD

local ICON_SIZE, ICON_GAP = 22, 2
local BACKPACK_ICON = "Interface\\Icons\\INV_Misc_Bag_08"

local bar = CreateFrame("Frame", nil, frame)
bar:SetPoint("TOPRIGHT", -PAD, -29)
bar:Hide()

local buttons = {}

-- The search box gives up the room the bar needs.
local function AnchorSearchBox()
    local searchBox = Cubby.searchBox
    searchBox:ClearAllPoints()
    searchBox:SetPoint("TOPLEFT", PAD + 6, -30)
    if bar:IsShown() then
        searchBox:SetPoint("TOPRIGHT", bar, "TOPLEFT", -6, -1)
    else
        searchBox:SetPoint("TOPRIGHT", -PAD, -30)
    end
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
-- A bag or an item on the cursor is put into this bag slot (the backpack takes any item).
local function PutCursorItemIn(button)
    if not CursorHasItem() then
        return
    end
    if button.bagID == 0 then
        PutItemInBackpack()
    elseif button.inventoryID then
        PutItemInBag(button.inventoryID)
    end
end

local function ShowTooltip(button)
    local bagID = button.bagID
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    if bagID == 0 then
        GameTooltip:SetText(BACKPACK_TOOLTIP or L.BACKPACK)
    elseif not (button.inventoryID and GameTooltip:SetInventoryItem("player", button.inventoryID)) then
        if bagID == Cubby.REAGENT_BAG then
            GameTooltip:SetText(EQUIP_CONTAINER_REAGENT or L.EMPTY_REAGENT_SLOT)
        else
            GameTooltip:SetText(EQUIP_CONTAINER or L.EMPTY_BAG_SLOT)
        end
    end
    local total = Cubby.NumSlots(bagID)
    if total > 0 then
        GameTooltip:AddLine(L.FREE_SLOTS:format(C_Container.GetContainerNumFreeSlots(bagID) or 0, total))
    end
    GameTooltip:Show()
end

local function CreateBagButton(bagID, previous)
    local button = CreateFrame("Button", nil, bar)
    button:SetSize(ICON_SIZE, ICON_SIZE)
    button.bagID = bagID
    button.inventoryID = bagID ~= 0 and C_Container.ContainerIDToInventoryID(bagID) or nil
    if previous then
        button:SetPoint("LEFT", previous, "RIGHT", ICON_GAP, 0)
    else
        button:SetPoint("LEFT", bar, "LEFT", 0, 0)
    end

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetAtlas("bags-item-slot64")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.free = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.free:SetPoint("BOTTOMRIGHT", -1, 2)

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnEnter", function(self)
        ShowTooltip(self)
        Cubby.SetBagHighlight(self.bagID)
    end)
    button:SetScript("OnLeave", function()
        GameTooltip_Hide()
        Cubby.SetBagHighlight(nil)
    end)
    button:SetScript("OnClick", PutCursorItemIn)
    button:SetScript("OnReceiveDrag", PutCursorItemIn)
    button:SetScript("OnDragStart", function(self)
        if self.inventoryID then
            PickupBagFromSlot(self.inventoryID)
        end
    end)
    return button
end

do
    local bags = Cubby.MainBags()
    if Cubby.REAGENT_BAG then
        bags[#bags + 1] = Cubby.REAGENT_BAG
    end
    local previous
    for _, bagID in ipairs(bags) do
        previous = CreateBagButton(bagID, previous)
        buttons[#buttons + 1] = previous
    end
    bar:SetSize(#buttons * ICON_SIZE + (#buttons - 1) * ICON_GAP, ICON_SIZE)
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
-- Bag icon and the number of free slots of one bag
local function UpdateBagButton(button)
    local bagID = button.bagID
    local texture
    if bagID == 0 then
        texture = BACKPACK_ICON
    elseif button.inventoryID then
        texture = GetInventoryItemTexture("player", button.inventoryID)
    end
    button.icon:SetTexture(texture)
    button.icon:SetShown(texture ~= nil)

    if Cubby.NumSlots(bagID) > 0 then
        local free = C_Container.GetContainerNumFreeSlots(bagID) or 0
        button.free:SetText(free)
        if free == 0 then
            button.free:SetTextColor(1, 0.3, 0.3)
        else
            button.free:SetTextColor(1, 1, 1)
        end
    else
        button.free:SetText("")
    end
end

function Cubby.UpdateBagBar()
    local want = Cubby.db.showBagBar == true
    if bar:IsShown() ~= want then
        bar:SetShown(want)
        AnchorSearchBox()
    end
    if want then
        for _, button in ipairs(buttons) do
            UpdateBagButton(button)
        end
    end
end
