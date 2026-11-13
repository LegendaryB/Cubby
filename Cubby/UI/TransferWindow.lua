-- Window for exporting and importing groups: one text box, to copy from or paste into.
local _, Cubby = ...
local L = Cubby.L

local PAD, WIDTH, HEIGHT = 12, 440, 260
local SCROLL_STEP = 40

local window = Cubby.CreatePanel("CubbyTransfer")
window:SetSize(WIDTH, HEIGHT)
window:SetPoint("CENTER")
window:SetFrameStrata("DIALOG")

local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", PAD, -PAD)
title:SetPoint("TOPRIGHT", -30, -PAD)
title:SetJustifyH("LEFT")

local closeButton = CreateFrame("Button", nil, window, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", 2, 2)
closeButton:SetScript("OnClick", function()
    window:Hide()
end)

local hint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hint:SetPoint("TOPLEFT", PAD, -34)
hint:SetPoint("TOPRIGHT", -PAD, -34)
hint:SetJustifyH("LEFT")
hint:SetWordWrap(true)

-- Scrollable text box
local scroll = CreateFrame("ScrollFrame", nil, window)
scroll:SetPoint("TOPLEFT", PAD, -76)
scroll:SetPoint("BOTTOMRIGHT", -PAD, 44)
scroll:EnableMouse(true)
scroll:EnableMouseWheel(true)

local background = scroll:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints()
background:SetColorTexture(0, 0, 0, 0.5)

local edit = CreateFrame("EditBox", nil, scroll)
edit:SetMultiLine(true)
edit:SetAutoFocus(false)
edit:SetFontObject("ChatFontNormal")
edit:SetMaxLetters(0)
edit:SetWidth(WIDTH - PAD * 2 - 8)
edit:SetHeight(HEIGHT - 120)
scroll:SetScrollChild(edit)

scroll:SetScript("OnMouseDown", function()
    edit:SetFocus()
end)
scroll:SetScript("OnMouseWheel", function(self, delta)
    local offset = self:GetVerticalScroll() - delta * SCROLL_STEP
    self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), offset)))
end)
-- Keep the cursor in view while typing or pasting
edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
    y = -y
    local offset = scroll:GetVerticalScroll()
    if y < offset then
        scroll:SetVerticalScroll(y)
    elseif y + height > offset + scroll:GetHeight() then
        scroll:SetVerticalScroll(y + height - scroll:GetHeight())
    end
end)
edit:SetScript("OnEscapePressed", function()
    window:Hide()
end)

local status = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
status:SetPoint("BOTTOMLEFT", PAD, 14)
status:SetPoint("BOTTOMRIGHT", -140, 14)
status:SetJustifyH("LEFT")
status:SetTextColor(1, 0.25, 0.25)

local importButton = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
importButton:SetSize(120, 24)
importButton:SetPoint("BOTTOMRIGHT", -PAD, 10)
importButton:SetText(L.IMPORT_BUTTON)
importButton:SetScript("OnClick", function()
    local counts, message = Cubby.ImportGroups(edit:GetText())
    if not counts then
        status:SetText(message)
        return
    end
    window:Hide()
    Cubby.Print(L.IMPORT_DONE:format(counts.groups, counts.items))
    if counts.kept > 0 then
        Cubby.Print(L.IMPORT_KEPT:format(counts.kept))
    end
    if counts.dropped > 0 then
        Cubby.Print(L.IMPORT_UNREADABLE:format(counts.dropped))
    end
end)

window:SetScript("OnHide", function()
    edit:ClearFocus()
    edit:SetText("") -- the text can be long
    status:SetText("")
end)

-- mode: "export" shows text to copy, "import" waits for a pasted text
function Cubby.OpenTransfer(mode, text)
    local exporting = mode == "export"
    title:SetText(exporting and L.EXPORT_TITLE or L.IMPORT_TITLE)
    hint:SetText(exporting and L.EXPORT_HINT or L.IMPORT_HINT)
    importButton:SetShown(not exporting)
    status:SetText("")
    window:Show()
    edit:SetText(exporting and text or "")
    scroll:SetVerticalScroll(0)
    edit:SetFocus()
    if exporting then
        edit:HighlightText()
    end
end
