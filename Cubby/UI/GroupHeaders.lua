-- Header above every group section: clicking the name opens the group menu,
-- next to it collapse, move, sell protection and color.
local _, Cubby = ...
local state = Cubby.state
local L = Cubby.L
local CreateIconButton, SetButtonIcon, SetButtonEnabled = Cubby.CreateIconButton, Cubby.SetButtonIcon, Cubby.SetButtonEnabled
local IsCollapsed, TagLabel, TagForItem = Cubby.IsCollapsed, Cubby.TagLabel, Cubby.TagForItem

local groupHeaders = {}

-- The small buttons sit directly in the header; the header knows its group.
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

    local collapse = CreateIconButton(header, 16, L.COLLAPSE)
    collapse:SetPoint("LEFT", 0, 0)
    collapse:SetScript("OnClick", function(self)
        Cubby.ToggleCollapsed(HeaderTag(self))
    end)
    header.collapse = collapse

    header.hint = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header.hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 2, -5)
    header.hint:SetText(L.DRAG_ITEMS_HERE)

    local swatch = CreateFrame("Button", nil, header)
    swatch:SetSize(12, 12)
    swatch:SetPoint("RIGHT", -2, 0)
    swatch.color = swatch:CreateTexture(nil, "ARTWORK")
    swatch.color:SetAllPoints()
    swatch:SetScript("OnClick", function(self)
        Cubby.PickTagColor(HeaderTag(self))
    end)
    header.swatch = swatch

    local protect = CreateIconButton(header, 16, L.SELL_PROTECTION)
    protect:SetPoint("RIGHT", swatch, "LEFT", -6, 0)
    Cubby.SetButtonIconFile(protect, "Interface\\LFGFrame\\UI-LFG-ICON-LOCK")
    protect:SetScript("OnClick", function(self)
        Cubby.ToggleSellProtection(HeaderTag(self))
        Cubby.ShowIconTooltip(self) -- immediately shows the new state
    end)
    header.protect = protect

    local moveDown = CreateIconButton(header, 14, L.MOVE_DOWN)
    moveDown:SetPoint("RIGHT", protect, "LEFT", -6, 0)
    SetButtonIcon(moveDown, "minimal-scrollbar-arrow-bottom", "v")
    moveDown:SetScript("OnClick", function(self)
        Cubby.MoveArea(HeaderTag(self), 1)
    end)
    header.moveDown = moveDown

    local moveUp = CreateIconButton(header, 14, L.MOVE_UP)
    moveUp:SetPoint("RIGHT", moveDown, "LEFT", -2, 0)
    SetButtonIcon(moveUp, "minimal-scrollbar-arrow-top", "^")
    moveUp:SetScript("OnClick", function(self)
        Cubby.MoveArea(HeaderTag(self), -1)
    end)
    header.moveUp = moveUp

    -- Only visible at the vendor: sell everything in the section (see UpdateGroupCounts)
    local sell = CreateIconButton(header, 16, L.SELL_SECTION)
    sell:SetPoint("RIGHT", moveUp, "LEFT", -4, 0)
    SetButtonIcon(sell, "bags-junkcoin", "$")
    sell:SetScript("OnClick", function(self)
        Cubby.AskSellSection(HeaderTag(self))
    end)
    sell:Hide()
    header.sell = sell

    header.label = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.label:SetPoint("LEFT", collapse, "RIGHT", 2, 0)
    header.label:SetPoint("RIGHT", sell, "LEFT", -4, 0)
    header.label:SetJustifyH("LEFT")
    header.label:SetWordWrap(false)

    return header
end

-- Show header number index for a section; UpdateGroupCounts sets the label.
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
    header.collapse.tooltip = collapsed and L.EXPAND or L.COLLAPSE
    SetButtonEnabled(header.collapse, state.searchText == "")

    header.swatch.color:SetColorTexture(tag.r, tag.g, tag.b, 1)
    header.protect.icon:SetDesaturated(not tag.noSell)
    header.protect.icon:SetAlpha(tag.noSell and 1 or 0.35)
    header.protect.tooltip = tag.noSell and L.SELL_PROTECTION_ON or L.SELL_PROTECTION_OFF
    header:Show()
end

local function HideGroupHeaders()
    for _, header in ipairs(groupHeaders) do
        header:Hide()
    end
end

-- The top section cannot move higher, the bottom one not lower.
local function UpdateMoveButtons(count)
    for i = 1, count do
        SetButtonEnabled(groupHeaders[i].moveUp, i > 1)
        SetButtonEnabled(groupHeaders[i].moveDown, i < count)
    end
end

local function AddBagCounts(bag, counts, values, hasNew)
    for slot = 1, Cubby.NumSlots(bag) do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        local tag = info and TagForItem(info.itemID)
        if tag then
            counts[tag.id] = (counts[tag.id] or 0) + (info.stackCount or 1)
            values[tag.id] = (values[tag.id] or 0) + Cubby.SellValue(info)
            if C_NewItems.IsNewItem(bag, slot) then
                hasNew[tag.id] = true
            end
        end
    end
end

-- Separate pass instead of counting in the layout: at the vendor the layout rests, but the count must stay right.
local function UpdateGroupCounts()
    local counts, values, hasNew = {}, {}, {}
    for _, bag in ipairs(Cubby.TaggableBags()) do
        AddBagCounts(bag, counts, values, hasNew)
    end
    for _, header in ipairs(groupHeaders) do
        if header:IsShown() then
            local tag = header.tag
            -- Open sections do not need this: the item itself glows there.
            local newMark = (hasNew[tag.id] and IsCollapsed(tag)) and (" |cff66dd66%s|r"):format(L.NEW_ITEMS) or ""
            local value = values[tag.id] or 0
            local valueText = (Cubby.db.showValue and value > 0) and ("  " .. GetMoneyString(value, true)) or ""
            header.label:SetText(("%s |cff888888(%d)|r%s%s"):format(TagLabel(tag), counts[tag.id] or 0, newMark, valueText))
            header.sell:SetShown(state.merchantOpen and not tag.noSell and value > 0)
        end
    end
end

Cubby.ShowGroupHeader = ShowGroupHeader
Cubby.HideGroupHeaders = HideGroupHeaders
Cubby.UpdateMoveButtons = UpdateMoveButtons
Cubby.UpdateGroupCounts = UpdateGroupCounts
