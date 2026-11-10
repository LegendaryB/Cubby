-- Main window: frame, header with buttons, search box, footer and position.
local _, Cubby = ...
local state = Cubby.state
local L = Cubby.L
local PAD = Cubby.PAD
local CreateIconButton, SetButtonIcon = Cubby.CreateIconButton, Cubby.SetButtonIcon

local frame = Cubby.CreatePanel("CubbyFrame")
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
Cubby.frame = frame

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", PAD, -PAD)
title:SetText(COMBINED_BAG_TITLE or BACKPACK_TOOLTIP) -- the same text as in Blizzard's bag window

---------------------------------------------------------------------------
-- Buttons at the top right
---------------------------------------------------------------------------
local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", 2, 2)
closeButton:SetScript("OnClick", function() frame:Hide() end)

local sortButton = CreateFrame("Button", nil, frame)
sortButton:SetSize(24, 24)
sortButton:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
sortButton:SetNormalAtlas("bags-button-autosort-up")
sortButton:SetPushedAtlas("bags-button-autosort-down")
sortButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
sortButton:SetScript("OnClick", function()
    if SOUNDKIT.UI_BAG_SORTING_01 then
        PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
    end
    Cubby.SortBags()
end)
sortButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(L.SORT_BAGS)
    GameTooltip:Show()
end)
sortButton:SetScript("OnLeave", GameTooltip_Hide)

local groupsButton = CreateIconButton(frame, 20, L.GROUPS)
groupsButton:SetPoint("RIGHT", sortButton, "LEFT", -4, 0)
SetButtonIcon(groupsButton, "ui-questtrackerbutton-filter", "G")
groupsButton:SetScript("OnClick", function(self)
    Cubby.OpenGroupsMenu(self)
end)

local optionsButton = CreateIconButton(frame, 20, L.OPTIONS)
optionsButton:SetPoint("RIGHT", groupsButton, "LEFT", -4, 0)
SetButtonIcon(optionsButton, "questlog-icon-setting", "O")
optionsButton:SetScript("OnClick", function()
    Cubby.ToggleOptions()
end)

---------------------------------------------------------------------------
-- Search
---------------------------------------------------------------------------
local searchBox = CreateFrame("EditBox", "CubbySearchBox", frame, "SearchBoxTemplate")
searchBox:SetHeight(20)
searchBox:SetPoint("TOPLEFT", PAD + 6, -30)
searchBox:SetPoint("TOPRIGHT", -PAD, -30)
searchBox:SetAutoFocus(false)
Cubby.searchBox = searchBox
searchBox:HookScript("OnTextChanged", function(self)
    local wasSearching = state.searchText ~= ""
    state.searchText = (self:GetText() or ""):lower()
    -- The game's own item search (the one the default bags use) finds more than names, e.g. item
    -- type and tooltip text. Its result arrives as isFiltered on each slot, see MatchesSearch.
    if C_Container.SetItemSearch then
        C_Container.SetItemSearch(self:GetText() or "")
    end
    if wasSearching ~= (state.searchText ~= "") then
        Cubby.TagsChanged() -- open or re-close collapsed sections
    else
        Cubby.ApplySearch()
    end
end)

---------------------------------------------------------------------------
-- Content and footer
---------------------------------------------------------------------------
local content = CreateFrame("Frame", nil, frame)
content:SetPoint("TOPLEFT", PAD, -Cubby.HEADER_H)
Cubby.content = content

local freeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
freeText:SetPoint("BOTTOMLEFT", PAD, 10)

local moneyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
moneyText:SetPoint("BOTTOMRIGHT", -PAD, 10)

local valueText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
valueText:SetPoint("BOTTOM", 0, 10)
valueText:Hide()

-- Vendor value of all items in the bags
local function UpdateValue()
    if not Cubby.db.showValue then
        valueText:Hide()
        return
    end
    local total = 0
    for _, bag in ipairs(Cubby.TaggableBags()) do
        for slot = 1, Cubby.NumSlots(bag) do
            total = total + Cubby.SellValue(C_Container.GetContainerItemInfo(bag, slot))
        end
    end
    valueText:SetText(L.VENDOR_VALUE:format(GetMoneyString(total, true)))
    valueText:Show()
end

-- Little space in the bags: "Free" turns yellow, red when the bags are nearly full.
local FREE_WARNINGS = {
    { maxFree = 2, color = { 1, 0.25, 0.25 } },
    { maxFree = 5, color = { 1, 0.82, 0 } },
}
local NORMAL_COLOR = { 1, 1, 1 }
local shownWarning -- nil = normal color; the text is only recolored on a change

local function UpdateFreeWarning(free)
    local warning
    for _, w in ipairs(FREE_WARNINGS) do
        if free <= w.maxFree then
            warning = w
            break
        end
    end
    if warning ~= shownWarning then
        shownWarning = warning
        local c = warning and warning.color or NORMAL_COLOR
        freeText:SetTextColor(c[1], c[2], c[3])
    end
end

function Cubby.UpdateFooter()
    local free, total = 0, 0
    for _, bag in ipairs(Cubby.MainBags()) do
        free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
        total = total + Cubby.NumSlots(bag)
    end
    freeText:SetFormattedText(L.FREE_SLOTS, free, total)
    UpdateFreeWarning(free)
    UpdateValue()
    moneyText:SetText(GetMoneyString(GetMoney(), true))
end

---------------------------------------------------------------------------
-- Position and size
---------------------------------------------------------------------------
function Cubby.RestorePosition()
    frame:ClearAllPoints()
    local point = Cubby.db.point
    if point then
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", point[1], point[2])
    else
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 120)
    end
end

-- Always anchor at the bottom right so the window grows up/left like the default bags.
local function SavePosition()
    local ratio = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    local x = frame:GetRight() - UIParent:GetRight() * ratio
    local y = frame:GetBottom() - UIParent:GetBottom() * ratio
    Cubby.db.point = { x, y }
    Cubby.RestorePosition()
end

function Cubby.ResetPosition()
    Cubby.db.point = nil
    Cubby.RestorePosition()
end

function Cubby.SetWindowScale(scale)
    Cubby.db.scale = math.max(0.5, math.min(2, scale))
    frame:SetScale(Cubby.db.scale)
    Cubby.RestorePosition()
end

frame:SetScript("OnDragStart", function(self)
    if not Cubby.db.locked then
        self:StartMoving()
    end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
end)

---------------------------------------------------------------------------
-- Opening and closing
---------------------------------------------------------------------------
-- Hide quietly when Blizzard's bags are already closed: OnHide must not close them a second time.
function Cubby.HideWindowQuietly()
    frame.closingFromBlizzard = true
    frame:Hide()
    frame.closingFromBlizzard = nil
end

frame:SetScript("OnShow", function()
    PlaySound(SOUNDKIT.IG_BACKPACK_OPEN)
    state.needLayout = state.needLayout or state.softLayout
    Cubby.SafeRefresh()
end)

frame:SetScript("OnHide", function(self)
    PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE)
    if searchBox:GetText() ~= "" then
        searchBox:SetText("")
    end
    searchBox:ClearFocus()
    -- Closed with X or ESC: tell Blizzard that the bags are closed.
    if not self.closingFromBlizzard and IsAnyBagOpen() then
        CloseAllBags()
    end
end)
