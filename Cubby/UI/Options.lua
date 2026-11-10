-- Einstellungsfenster (Zahnrad-Button): links neben dem Hauptfenster.
local _, Cubby = ...
local frame = Cubby.frame
local L = Cubby.L

local options = Cubby.CreatePanel("CubbyOptionsFrame")
options:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", -4, 0)

local optionsTitle = options:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optionsTitle:SetPoint("TOPLEFT", Cubby.PAD, -Cubby.PAD)
optionsTitle:SetText(L.OPTIONS_TITLE)

local optionsClose = CreateFrame("Button", nil, options, "UIPanelCloseButton")
optionsClose:SetPoint("TOPRIGHT", 2, 2)
optionsClose:SetScript("OnClick", function() options:Hide() end)

-- Jede Zeile meldet hier, wie sie ihren angezeigten Wert auffrischt.
local refreshers = {}
local nextRowY = -36
local ROW_H = 26

local function RefreshOptions()
    for _, refresh in ipairs(refreshers) do
        refresh()
    end
end

-- Zeile mit Beschriftung links und [-] Wert [+] rechts
local function AddStepper(label, getText, onStep)
    local text = options:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", 14, nextRowY - 4)
    text:SetText(label)

    local plus = CreateFrame("Button", nil, options, "UIPanelButtonTemplate")
    plus:SetSize(24, 22)
    plus:SetPoint("TOPRIGHT", -14, nextRowY)
    plus:SetText("+")

    local value = options:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    value:SetWidth(40)
    value:SetPoint("RIGHT", plus, "LEFT", -2, 0)

    local minus = CreateFrame("Button", nil, options, "UIPanelButtonTemplate")
    minus:SetSize(24, 22)
    minus:SetPoint("RIGHT", value, "LEFT", -2, 0)
    minus:SetText("-")

    local function Step(delta)
        onStep(delta)
        RefreshOptions()
    end
    plus:SetScript("OnClick", function() Step(1) end)
    minus:SetScript("OnClick", function() Step(-1) end)

    refreshers[#refreshers + 1] = function()
        value:SetText(getText())
    end
    nextRowY = nextRowY - ROW_H
end

-- Checkbox fuer eine Ja/Nein-Einstellung in CubbyDB
local function AddCheckbox(label, key)
    local check = CreateFrame("CheckButton", nil, options, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", 10, nextRowY)
    check:SetScript("OnClick", function(self)
        Cubby.db[key] = self:GetChecked() and true or false
        Cubby.RequestLayout()
    end)

    local text = options:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", check, "RIGHT", 4, 0)
    text:SetText(label)

    refreshers[#refreshers + 1] = function()
        check:SetChecked(Cubby.db[key])
    end
    nextRowY = nextRowY - ROW_H
end

AddStepper(L.COLUMNS, function() return Cubby.db.columns end, function(delta)
    Cubby.db.columns = math.max(8, math.min(30, Cubby.db.columns + delta))
    Cubby.RequestLayout()
end)
AddStepper(L.SCALE, function() return ("%.2f"):format(Cubby.db.scale) end, function(delta)
    -- in Schritten von 0,05
    Cubby.SetWindowScale(math.floor((Cubby.db.scale + delta * 0.05) * 20 + 0.5) / 20)
end)
AddCheckbox(L.SHOW_ITEM_LEVEL, "showItemLevel")
AddCheckbox(L.MARK_BOE, "showBoE")
AddCheckbox(L.SHOW_KEYRING, "showKeyring")
AddCheckbox(L.COMBINE_FREE_SLOTS, "combineFreeSlots")
AddCheckbox(L.SHOW_VALUE, "showValue")
AddCheckbox(L.LOCK_WINDOW, "locked")

local resetButton = CreateFrame("Button", nil, options, "UIPanelButtonTemplate")
resetButton:SetSize(190, 22)
resetButton:SetPoint("TOP", 0, nextRowY - 6)
resetButton:SetText(L.RESET_POSITION)
resetButton:SetScript("OnClick", function()
    Cubby.ResetPosition()
end)

options:SetSize(230, -nextRowY + 40)
options:SetScript("OnShow", RefreshOptions)
frame:HookScript("OnHide", function()
    options:Hide()
end)

function Cubby.ToggleOptions()
    options:SetShown(not options:IsShown())
end
