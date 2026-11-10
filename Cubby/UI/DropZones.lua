-- Ablageflaechen: liegen nur waehrend des Ziehens ueber den Bereichen. Ein Item dort abzulegen aendert
-- nur seine Gruppe, es bleibt physisch auf seinem Platz. Die Flaechen muessen die Item-Buttons
-- verdecken, sonst wuerde Blizzards Klickcode die Items stattdessen vertauschen.
local _, Cubby = ...
local TagForItem = Cubby.TagForItem

-- Flaeche des ungruppierten Bereichs: wird wie eine Gruppe gezeichnet, entfernt aber die Gruppe.
Cubby.NO_GROUP_ZONE = { name = "Keine Gruppe", r = 0.6, g = 0.6, b = 0.6, clearsGroup = true }

local dropZones = {}

local function PaintDropZone(zone, alpha)
    if zone.tag then -- kann fehlen, wenn der Bereich gerade unter der Maus verschwunden ist
        zone.fill:SetColorTexture(zone.tag.r, zone.tag.g, zone.tag.b, alpha)
    end
end

local function DropOnZone(zone)
    local cursorType, itemID = GetCursorInfo()
    if cursorType ~= "item" or not zone.tag then
        return
    end
    ClearCursor()
    local current = TagForItem(itemID)
    if zone.tag.clearsGroup then
        if current then
            Cubby.SetItemTag(itemID, nil)
        end
    elseif not current or current.id ~= zone.tag.id then
        Cubby.SetItemTag(itemID, zone.tag.id)
    end
end

local function GetDropZone(index)
    local zone = dropZones[index]
    if zone then
        return zone
    end
    zone = CreateFrame("Frame", nil, Cubby.content)
    zone:Hide()
    zone:EnableMouse(true)
    zone.fill = zone:CreateTexture(nil, "ARTWORK")
    zone.fill:SetAllPoints()
    zone.text = zone:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    zone.text:SetPoint("CENTER")
    zone:SetScript("OnReceiveDrag", DropOnZone)
    zone:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "LeftButton" then
            DropOnZone(self)
        end
    end)
    zone:SetScript("OnEnter", function(self)
        PaintDropZone(self, 0.5)
    end)
    zone:SetScript("OnLeave", function(self)
        PaintDropZone(self, 0.25)
    end)
    dropZones[index] = zone
    return zone
end

-- Flaeche Nummer index ueber einen Bereich legen (zoneTag: Gruppe oder NO_GROUP_ZONE)
local function PlaceDropZone(index, zoneTag, top, width, height)
    local zone = GetDropZone(index)
    zone.tag = zoneTag
    zone:ClearAllPoints()
    zone:SetPoint("TOPLEFT", Cubby.content, "TOPLEFT", 0, -top)
    zone:SetSize(width, height)
    zone.text:SetText("Ablegen in: " .. zoneTag.name)
    PaintDropZone(zone, 0.25)
end

-- Flaechen ab dieser Nummer gehoeren zu keinem Bereich mehr.
local function ReleaseDropZones(firstUnused)
    for i = firstUnused, #dropZones do
        dropZones[i].tag = nil
    end
end

local function CursorHasBagItem()
    if GetCursorInfo() ~= "item" then
        return false
    end
    local location = C_Cursor.GetCursorItem()
    return location ~= nil and location:GetBagAndSlot() ~= nil
end

-- Sichtbar nur, solange ein Taschen-Item am Mauszeiger haengt
local function UpdateDropZones()
    local show = CursorHasBagItem()
    local _, cursorItemID = GetCursorInfo()
    local hasGroup = show and TagForItem(cursorItemID) ~= nil
    local first = Cubby.active[1]
    local level = first and first:GetFrameLevel()
    for _, zone in ipairs(dropZones) do
        -- Ungruppierte Items sollen sich weiter normal zwischen den Plaetzen verschieben lassen.
        local visible = show and zone.tag ~= nil and (hasGroup or not zone.tag.clearsGroup)
        if visible and level then
            zone:SetFrameLevel(level + 5)
        end
        zone:SetShown(visible)
    end
end

Cubby.PlaceDropZone = PlaceDropZone
Cubby.ReleaseDropZones = ReleaseDropZones
Cubby.UpdateDropZones = UpdateDropZones
