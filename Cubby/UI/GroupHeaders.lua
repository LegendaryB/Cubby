-- Kopfzeile ueber jedem Gruppenbereich: Klick auf den Namen oeffnet das Gruppenmenue,
-- daneben Einklappen, Verschieben, Verkaufsschutz und Farbe.
local _, Cubby = ...
local state = Cubby.state
local CreateIconButton, SetButtonIcon, SetButtonEnabled = Cubby.CreateIconButton, Cubby.SetButtonIcon, Cubby.SetButtonEnabled
local IsCollapsed, TagLabel, TagForItem = Cubby.IsCollapsed, Cubby.TagLabel, Cubby.TagForItem

local groupHeaders = {}

-- Die kleinen Buttons sitzen direkt in der Kopfzeile; diese kennt ihre Gruppe.
local function HeaderTag(button)
    return button:GetParent().tag
end

local function CreateGroupHeader()
    local header = CreateFrame("Button", nil, Cubby.content)
    header:SetHeight(Cubby.SECTION_H)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    header:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
    header:SetScript("OnClick", function(self)
        Cubby.OpenGroupMenu(self, self.tag)
    end)

    local collapse = CreateIconButton(header, 16, "Einklappen")
    collapse:SetPoint("LEFT", 0, 0)
    collapse:SetScript("OnClick", function(self)
        Cubby.ToggleCollapsed(HeaderTag(self))
    end)
    header.collapse = collapse

    header.hint = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header.hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 2, -5)
    header.hint:SetText("Items hierher ziehen")

    local swatch = CreateFrame("Button", nil, header)
    swatch:SetSize(12, 12)
    swatch:SetPoint("RIGHT", -2, 0)
    swatch.color = swatch:CreateTexture(nil, "ARTWORK")
    swatch.color:SetAllPoints()
    swatch:SetScript("OnClick", function(self)
        Cubby.PickTagColor(HeaderTag(self))
    end)
    header.swatch = swatch

    local protect = CreateIconButton(header, 16, "Verkaufsschutz")
    protect:SetPoint("RIGHT", swatch, "LEFT", -6, 0)
    Cubby.SetButtonIconFile(protect, "Interface\\LFGFrame\\UI-LFG-ICON-LOCK")
    protect:SetScript("OnClick", function(self)
        Cubby.ToggleSellProtection(HeaderTag(self))
        Cubby.ShowIconTooltip(self) -- zeigt gleich den neuen Zustand
    end)
    header.protect = protect

    local moveDown = CreateIconButton(header, 14, "Bereich nach unten")
    moveDown:SetPoint("RIGHT", protect, "LEFT", -6, 0)
    SetButtonIcon(moveDown, "minimal-scrollbar-arrow-bottom", "v")
    moveDown:SetScript("OnClick", function(self)
        Cubby.MoveArea(HeaderTag(self), 1)
    end)
    header.moveDown = moveDown

    local moveUp = CreateIconButton(header, 14, "Bereich nach oben")
    moveUp:SetPoint("RIGHT", moveDown, "LEFT", -2, 0)
    SetButtonIcon(moveUp, "minimal-scrollbar-arrow-top", "^")
    moveUp:SetScript("OnClick", function(self)
        Cubby.MoveArea(HeaderTag(self), -1)
    end)
    header.moveUp = moveUp

    header.label = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.label:SetPoint("LEFT", collapse, "RIGHT", 2, 0)
    header.label:SetPoint("RIGHT", moveUp, "LEFT", -6, 0)
    header.label:SetJustifyH("LEFT")
    header.label:SetWordWrap(false)

    return header
end

-- Kopfzeile Nummer index fuer einen Bereich zeigen; die Beschriftung setzt UpdateGroupCounts.
local function ShowGroupHeader(index, section, top, width)
    local header = groupHeaders[index]
    if not header then
        header = CreateGroupHeader()
        groupHeaders[index] = header
    end

    local tag = section.tag
    header.tag = tag
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", Cubby.content, "TOPLEFT", 0, -top)
    header:SetWidth(width)

    local collapsed = IsCollapsed(tag)
    header.hint:SetShown(#section.slots == 0 and not collapsed)
    SetButtonIcon(header.collapse,
        collapsed and "ui-questtrackerbutton-secondary-expand" or "ui-questtrackerbutton-secondary-collapse",
        collapsed and "+" or "-")
    header.collapse.tooltip = collapsed and "Aufklappen" or "Einklappen"
    SetButtonEnabled(header.collapse, state.searchText == "")

    header.swatch.color:SetColorTexture(tag.r, tag.g, tag.b, 1)
    header.protect.icon:SetDesaturated(not tag.noSell)
    header.protect.icon:SetAlpha(tag.noSell and 1 or 0.35)
    header.protect.tooltip = tag.noSell and "Verkaufsschutz: an" or "Verkaufsschutz: aus"
    header:Show()
end

local function HideGroupHeaders()
    for _, header in ipairs(groupHeaders) do
        header:Hide()
    end
end

-- Der oberste Bereich kann nicht hoeher, der unterste nicht tiefer.
local function UpdateMoveButtons(count)
    for i = 1, count do
        SetButtonEnabled(groupHeaders[i].moveUp, i > 1)
        SetButtonEnabled(groupHeaders[i].moveDown, i < count)
    end
end

local function AddBagCounts(bag, counts, hasNew)
    for slot = 1, Cubby.NumSlots(bag) do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        local tag = info and TagForItem(info.itemID)
        if tag then
            counts[tag.id] = (counts[tag.id] or 0) + (info.stackCount or 1)
            if C_NewItems.IsNewItem(bag, slot) then
                hasNew[tag.id] = true
            end
        end
    end
end

-- Eigener Durchlauf statt Zaehlen im Layout: beim Haendler ruht das Layout, die Zahl soll aber stimmen.
local function UpdateGroupCounts()
    local counts, hasNew = {}, {}
    for _, bag in ipairs(Cubby.TaggableBags()) do
        AddBagCounts(bag, counts, hasNew)
    end
    for _, header in ipairs(groupHeaders) do
        if header:IsShown() then
            local tag = header.tag
            -- Offene Bereiche brauchen das nicht: dort leuchtet das Item selbst.
            local newMark = (hasNew[tag.id] and IsCollapsed(tag)) and " |cff66dd66neu|r" or ""
            header.label:SetText(("%s |cff888888(%d)|r%s"):format(TagLabel(tag), counts[tag.id] or 0, newMark))
        end
    end
end

Cubby.ShowGroupHeader = ShowGroupHeader
Cubby.HideGroupHeaders = HideGroupHeaders
Cubby.UpdateMoveButtons = UpdateMoveButtons
Cubby.UpdateGroupCounts = UpdateGroupCounts
