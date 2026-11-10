-- Building blocks that several windows use: dark windows and icon buttons.
local _, Cubby = ...

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

-- Dark window, initially hidden; ESC closes it.
function Cubby.CreatePanel(name)
    local panel = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    panel:Hide()
    panel:SetFrameStrata("MEDIUM")
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetBackdrop(BACKDROP)
    panel:SetBackdropColor(0.05, 0.05, 0.06, 0.92)
    panel:SetBackdropBorderColor(0, 0, 0, 1)
    tinsert(UISpecialFrames, name)
    return panel
end

---------------------------------------------------------------------------
-- Icon buttons
---------------------------------------------------------------------------
-- All icons come from Blizzard's own UI. If the client lacks one, a text character is shown.
local function GetAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) or nil
end

function Cubby.ShowIconTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_TOP")
    GameTooltip:SetText(button.tooltip)
    GameTooltip:Show()
end

function Cubby.SetButtonIcon(button, atlas, fallback)
    local info = GetAtlas(atlas)
    button.icon:SetShown(info ~= nil)
    button.glow:SetShown(info ~= nil)
    button.text:SetText(info and "" or fallback)
    if info then
        -- keep the aspect ratio: not all icons are square
        local box = button:GetWidth()
        local fit = math.min(box / info.width, box / info.height)
        button.icon:SetSize(info.width * fit, info.height * fit)
        button.icon:SetAtlas(atlas)
        button.glow:SetAtlas(atlas)
    end
end

function Cubby.SetButtonIconFile(button, file)
    button.icon:SetTexture(file)
    button.icon:SetSize(button:GetWidth(), button:GetHeight())
    button.glow:SetTexture(file)
end

function Cubby.CreateIconButton(parent, size, tooltip)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("CENTER")
    button.glow = button:CreateTexture(nil, "HIGHLIGHT")
    button.glow:SetAllPoints(button.icon)
    button.glow:SetBlendMode("ADD")
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.text:SetPoint("CENTER")
    button.tooltip = tooltip
    button:SetScript("OnEnter", Cubby.ShowIconTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

-- Disabled buttons stay visible but pale.
function Cubby.SetButtonEnabled(button, enabled)
    button:SetEnabled(enabled)
    button:SetAlpha(enabled and 1 or 0.25)
end
