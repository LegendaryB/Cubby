-- Item buttons: Blizzard's own template plus Cubby's markers (item level, BoE, group border).
-- Using, dragging, selling and tooltips run through Blizzard's code.
local _, Cubby = ...
local state = Cubby.state
local L = Cubby.L
local TagForItem = Cubby.TagForItem
local UpdateSellProtection = Cubby.UpdateSellProtection

local buttons = {} -- buttons[bag][slot]
local holders = {} -- one parent frame per bag; its ID is the bag ID

local function GetHolder(bag)
    local holder = holders[bag]
    if not holder then
        holder = CreateFrame("Frame", nil, Cubby.content)
        holder:SetID(bag) -- Blizzard's item button reads the bag ID from its parent frame
        holder:SetAllPoints(Cubby.content)
        holders[bag] = holder
    end
    return holder
end

-- Alt+left-click: at worst a left-click picks an item up, but it never sells or uses it.
local function OnItemClick(button, mouseButton)
    if mouseButton ~= "LeftButton" or not IsAltKeyDown() then
        return
    end
    local bag, slot = button:GetBagID(), button:GetID()
    local cursorItem = C_Cursor.GetCursorItem()
    if cursorItem and cursorItem:IsEqualTo(ItemLocation:CreateFromBagAndSlot(bag, slot)) then
        ClearCursor()
    elseif GetCursorInfo() then
        return
    end
    local itemID = C_Container.GetContainerItemID(bag, slot)
    if itemID then
        Cubby.OpenItemMenu(button, itemID)
    end
end

-- Colored border in group color: top, bottom, left, right
local TAG_EDGES = {
    { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
    { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" },
}

local function CreateItemButton(bag, slot)
    local button = CreateFrame("ItemButton", "CubbyItem" .. bag .. "_" .. slot, GetHolder(bag), "ContainerFrameItemButtonTemplate")
    button:SetID(slot)
    button:SetSize(Cubby.SLOT, Cubby.SLOT)

    local bg = button:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetAllPoints()
    bg:SetAtlas("bags-item-slot64")

    local level = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    level:SetPoint("BOTTOMLEFT", 2, 2)
    button.cubbyLevel = level

    local bind = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    bind:SetPoint("TOPRIGHT", -1, -2)
    bind:SetTextColor(0.4, 0.8, 1)
    button.cubbyBind = bind

    -- Number of free slots, if this empty slot stands for all of them
    local free = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    free:SetPoint("CENTER")
    free:Hide()
    button.cubbyFree = free

    -- Dark veil while another bag is hovered in the bag bar
    local dim = button:CreateTexture(nil, "OVERLAY", nil, 5)
    dim:SetAllPoints()
    dim:SetColorTexture(0, 0, 0, 0.65)
    dim:Hide()
    button.cubbyDim = dim

    local edges = {}
    for i, side in ipairs(TAG_EDGES) do
        local edge = button:CreateTexture(nil, "OVERLAY", nil, 7)
        edge:SetPoint(side[1])
        edge:SetPoint(side[2])
        if i <= 2 then
            edge:SetHeight(2)
        else
            edge:SetWidth(2)
        end
        edge:Hide()
        edges[i] = edge
    end
    button.cubbyTagEdges = edges

    button:HookScript("OnClick", OnItemClick)
    button:HookScript("OnMouseUp", Cubby.OnItemMouseUp)
    return button
end

local function GetButton(bag, slot)
    buttons[bag] = buttons[bag] or {}
    local button = buttons[bag][slot]
    if not button then
        button = CreateItemButton(bag, slot)
        buttons[bag][slot] = button
    end
    return button
end

-- Find an existing button without creating a new one
local function FindButton(bag, slot)
    return slot and buttons[bag] and buttons[bag][slot] or nil
end

---------------------------------------------------------------------------
-- Display
---------------------------------------------------------------------------
-- Border in group color
local function UpdateTagDisplay(button, tag)
    for _, edge in ipairs(button.cubbyTagEdges) do
        if tag then
            edge:SetColorTexture(tag.r, tag.g, tag.b, 1)
        end
        edge:SetShown(tag ~= nil)
    end
end

local function IsGear(classID, equipLoc)
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP_IGNORE"
        or equipLoc == "INVTYPE_BODY" or equipLoc == "INVTYPE_TABARD" then
        return false
    end
    return classID == Enum.ItemClass.Weapon
        or classID == Enum.ItemClass.Armor
        or (Enum.ItemClass.Profession ~= nil and classID == Enum.ItemClass.Profession)
end

local function QualityColor(quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

-- A slot matches the search if the game's own item search finds it (it looks beyond the name,
-- see Window.lua), or the item name or the group name contains the text. info.isFiltered is true
-- for items the game's search does not find. It only counts if we could hand the text to the game's
-- search at all: without that it stays false for every item.
local function MatchesSearch(info)
    local searchText = state.searchText
    if searchText == "" then
        return true
    end
    if not info then
        return false
    end
    if C_Container.SetItemSearch and info.isFiltered == false then
        return true
    end
    local name = info.hyperlink and info.hyperlink:match("%[(.-)%]")
    if name and name:lower():find(searchText, 1, true) then
        return true
    end
    local tag = TagForItem(info.itemID)
    return tag ~= nil and tag.name:lower():find(searchText, 1, true) ~= nil
end

local function SetSearchMatch(button, matches)
    if button.SetMatchesSearch then
        button:SetMatchesSearch(matches)
    else
        button:SetAlpha(matches and 1 or 0.25)
    end
end

-- Item level and BoE text, only for gear
local function GearTexts(info, bag, slot)
    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(info.itemID)
    if not IsGear(classID, equipLoc) then
        return nil, nil
    end
    local levelText, bindText
    if Cubby.db.showItemLevel then
        local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
        local itemLevel = C_Item.DoesItemExist(location) and C_Item.GetCurrentItemLevel(location)
        if itemLevel and itemLevel > 1 then
            levelText = itemLevel
        end
    end
    if Cubby.db.showBoE and not info.isBound then
        bindText = L.BOE
    end
    return levelText, bindText
end

-- A combined free slot stands for the free slots of every bag of its own kind (reagent or regular).
local function StandsForBag(button, bag)
    local reagent = Cubby.REAGENT_BAG
    return (bag == reagent) == (button:GetBagID() == reagent)
end

-- While a bag is hovered in the bag bar, the slots of all other bags get a dark veil.
local function ApplyBagHighlight(button)
    local hovered = state.highlightBag
    local dim = false
    if hovered ~= nil then
        if button.cubbyFreeCount then
            dim = not (StandsForBag(button, hovered) and (C_Container.GetContainerNumFreeSlots(hovered) or 0) > 0)
        else
            dim = button:GetBagID() ~= hovered
        end
    end
    button.cubbyDim:SetShown(dim)
end

-- nil removes the highlight
local function SetBagHighlight(bag)
    state.highlightBag = bag
    for _, button in ipairs(Cubby.active) do
        ApplyBagHighlight(button)
    end
end

local function UpdateButton(button)
    local bag, slot = button:GetBagID(), button:GetID()
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local texture = info and info.iconFileID
    local link = info and info.hyperlink
    local quality = info and info.quality
    local itemID = info and info.itemID
    local tag = TagForItem(itemID)

    SetItemButtonTexture(button, texture)
    SetItemButtonCount(button, info and info.stackCount or 0)
    SetItemButtonDesaturated(button, info and info.isLocked)
    SetItemButtonQuality(button, quality, link, false, info and info.isBound)
    button:SetReadable(info and info.isReadable)
    button:UpdateCooldown(texture) -- also sets "has item"

    local questInfo = texture and C_Container.GetContainerItemQuestInfo(bag, slot)
    button:UpdateQuestItem(questInfo and questInfo.isQuestItem, questInfo and questInfo.questID, questInfo and questInfo.isActive)
    button:UpdateNewItem(quality)

    -- Always show the junk coin (default: only at the vendor), unless the item has sell protection
    button.JunkIcon:SetShown(texture ~= nil and quality == Enum.ItemQuality.Poor and not info.hasNoValue
        and not (tag and tag.noSell))
    UpdateTagDisplay(button, tag)
    UpdateSellProtection(button, tag)

    local levelText, bindText
    if texture and itemID then
        levelText, bindText = GearTexts(info, bag, slot)
    end

    if levelText then
        button.cubbyLevel:SetText(levelText)
        button.cubbyLevel:SetTextColor(QualityColor(quality))
        button.cubbyLevel:Show()
    else
        button.cubbyLevel:Hide()
    end

    if bindText then
        button.cubbyBind:SetText(bindText)
        button.cubbyBind:Show()
    else
        button.cubbyBind:Hide()
    end

    -- If an item has meanwhile landed on the slot, show no number until the next re-arrange
    if button.cubbyFreeCount and not texture then
        button.cubbyFree:SetText(button.cubbyFreeCount)
        button.cubbyFree:Show()
    else
        button.cubbyFree:Hide()
    end

    ApplyBagHighlight(button)
    SetSearchMatch(button, MatchesSearch(info))
end

-- Only re-evaluate the search matches, without fully updating the buttons
local function ApplySearch()
    for _, button in ipairs(Cubby.active) do
        SetSearchMatch(button, MatchesSearch(C_Container.GetContainerItemInfo(button:GetBagID(), button:GetID())))
    end
end

-- Group in the item tooltip
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if tooltip ~= GameTooltip or not data or (issecretvalue and issecretvalue(data.id)) then
        return
    end
    local tag = TagForItem(data.id)
    if tag then
        local suffix = (tag.noSell and L.TOOLTIP_SELL_PROTECTED or "") .. (Cubby.IsAutoTagged(data.id) and L.TOOLTIP_AUTOMATIC or "")
        tooltip:AddLine(L.TOOLTIP_GROUP:format(tag.name) .. suffix, tag.r, tag.g, tag.b)
    end
end)

Cubby.GetButton = GetButton
Cubby.FindButton = FindButton
Cubby.UpdateButton = UpdateButton
Cubby.ApplySearch = ApplySearch
Cubby.SetBagHighlight = SetBagHighlight
