-- Item-Buttons: Blizzards eigene Vorlage plus Cubbys Markierungen (Itemlevel, BoE, Gruppenrahmen).
-- Benutzen, Ziehen, Verkaufen und Tooltips laufen ueber Blizzards Code.
local _, Cubby = ...
local state = Cubby.state
local TagForItem = Cubby.TagForItem
local UpdateSellProtection = Cubby.UpdateSellProtection

local buttons = {} -- buttons[bag][slot]
local holders = {} -- ein Elternframe pro Tasche; seine ID ist die Taschen-ID

local function GetHolder(bag)
    local holder = holders[bag]
    if not holder then
        holder = CreateFrame("Frame", nil, Cubby.content)
        holder:SetID(bag) -- Blizzards Item-Button liest die Taschen-ID vom Elternframe
        holder:SetAllPoints(Cubby.content)
        holders[bag] = holder
    end
    return holder
end

-- Alt+Linksklick: Linksklick nimmt ein Item schlimmstenfalls auf, verkauft oder benutzt es aber nie.
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

-- Farbiger Rahmen in Gruppenfarbe: oben, unten, links, rechts
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

    local letter = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    letter:SetPoint("TOPLEFT", 3, -3)
    letter:Hide()
    button.cubbyTagLetter = letter

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

-- Vorhandenen Button finden, ohne einen neuen anzulegen
local function FindButton(bag, slot)
    return slot and buttons[bag] and buttons[bag][slot] or nil
end

---------------------------------------------------------------------------
-- Anzeige
---------------------------------------------------------------------------
local function UpdateTagDisplay(button, tag)
    for _, edge in ipairs(button.cubbyTagEdges) do
        if tag then
            edge:SetColorTexture(tag.r, tag.g, tag.b, 1)
        end
        edge:SetShown(tag ~= nil)
    end
    if tag then
        -- erster Buchstabe des Gruppennamens (UTF-8-sicher)
        button.cubbyTagLetter:SetText(tag.name:match("^[%z\1-\127\194-\244][\128-\191]*"))
        button.cubbyTagLetter:SetTextColor(tag.r, tag.g, tag.b)
    end
    button.cubbyTagLetter:SetShown(tag ~= nil)
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

-- Gesucht wird im Itemnamen und im Gruppennamen.
local function MatchesSearch(link, itemID)
    local searchText = state.searchText
    if searchText == "" then
        return true
    end
    local name = link and link:match("%[(.-)%]")
    if name and name:lower():find(searchText, 1, true) then
        return true
    end
    local tag = TagForItem(itemID)
    return tag ~= nil and tag.name:lower():find(searchText, 1, true) ~= nil
end

local function SetSearchMatch(button, matches)
    if button.SetMatchesSearch then
        button:SetMatchesSearch(matches)
    else
        button:SetAlpha(matches and 1 or 0.25)
    end
end

-- Itemlevel und BoE-Text, nur fuer Ausruestung
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
        bindText = "BoE"
    end
    return levelText, bindText
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
    button:UpdateCooldown(texture) -- setzt auch "hat Item"

    local questInfo = texture and C_Container.GetContainerItemQuestInfo(bag, slot)
    button:UpdateQuestItem(questInfo and questInfo.isQuestItem, questInfo and questInfo.questID, questInfo and questInfo.isActive)
    button:UpdateNewItem(quality)

    -- Schrott-Muenze immer anzeigen (Standard: nur beim Haendler), ausser das Item hat Verkaufsschutz
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

    SetSearchMatch(button, MatchesSearch(link, itemID))
end

-- Nur die Suchtreffer neu bewerten, ohne die Buttons komplett zu aktualisieren
local function ApplySearch()
    for _, button in ipairs(Cubby.active) do
        local bag, slot = button:GetBagID(), button:GetID()
        SetSearchMatch(button, MatchesSearch(C_Container.GetContainerItemLink(bag, slot), C_Container.GetContainerItemID(bag, slot)))
    end
end

-- Gruppe im Item-Tooltip
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if tooltip ~= GameTooltip or not data or (issecretvalue and issecretvalue(data.id)) then
        return
    end
    local tag = TagForItem(data.id)
    if tag then
        local suffix = (tag.noSell and " (Verkaufsschutz)" or "") .. (Cubby.IsAutoTagged(data.id) and " (automatisch)" or "")
        tooltip:AddLine("Gruppe: " .. tag.name .. suffix, tag.r, tag.g, tag.b)
    end
end)

Cubby.GetButton = GetButton
Cubby.FindButton = FindButton
Cubby.UpdateButton = UpdateButton
Cubby.ApplySearch = ApplySearch
