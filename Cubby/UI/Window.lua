-- Hauptfenster: Rahmen, Kopfzeile mit Buttons, Suchfeld, Fusszeile und Position.
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
title:SetText(COMBINED_BAG_TITLE or BACKPACK_TOOLTIP) -- derselbe Text wie in Blizzards Taschenfenster

---------------------------------------------------------------------------
-- Buttons oben rechts
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
-- Suche
---------------------------------------------------------------------------
local searchBox = CreateFrame("EditBox", "CubbySearchBox", frame, "SearchBoxTemplate")
searchBox:SetHeight(20)
searchBox:SetPoint("TOPLEFT", PAD + 6, -30)
searchBox:SetPoint("TOPRIGHT", -PAD, -30)
searchBox:SetAutoFocus(false)
searchBox:HookScript("OnTextChanged", function(self)
    local wasSearching = state.searchText ~= ""
    state.searchText = (self:GetText() or ""):lower()
    if wasSearching ~= (state.searchText ~= "") then
        Cubby.TagsChanged() -- eingeklappte Bereiche oeffnen bzw. wieder schliessen
    else
        Cubby.ApplySearch()
    end
end)

---------------------------------------------------------------------------
-- Inhalt und Fusszeile
---------------------------------------------------------------------------
local content = CreateFrame("Frame", nil, frame)
content:SetPoint("TOPLEFT", PAD, -Cubby.HEADER_H)
Cubby.content = content

local freeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
freeText:SetPoint("BOTTOMLEFT", PAD, 10)

local moneyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
moneyText:SetPoint("BOTTOMRIGHT", -PAD, 10)

function Cubby.UpdateFooter()
    local free, total = 0, 0
    for _, bag in ipairs(Cubby.MainBags()) do
        free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
        total = total + Cubby.NumSlots(bag)
    end
    freeText:SetFormattedText(L.FREE_SLOTS, free, total)
    moneyText:SetText(GetMoneyString(GetMoney(), true))
end

---------------------------------------------------------------------------
-- Position und Groesse
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

-- Immer unten rechts verankern, damit das Fenster wie die Standardtaschen nach oben/links waechst.
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
-- Oeffnen und Schliessen
---------------------------------------------------------------------------
-- Verstecken, wenn Blizzards Taschen schon zu sind: dann darf OnHide sie nicht noch einmal schliessen.
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
    -- Per X oder ESC geschlossen: Blizzard mitteilen, dass die Taschen zu sind.
    if not self.closingFromBlizzard and IsAnyBagOpen() then
        CloseAllBags()
    end
end)
