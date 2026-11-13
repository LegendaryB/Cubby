-- Drop zones: they only lie over the sections while dragging. Dropping an item there only changes
-- its group, it physically stays in its slot. The zones must cover the item buttons,
-- otherwise Blizzard's click code would swap the items instead.
local _, Cubby = ...
local TagForItem = Cubby.TagForItem
local L = Cubby.L

-- Zone of the ungrouped section: drawn like a group, but removes the group.
Cubby.NO_GROUP_ZONE = { name = L.NO_GROUP, r = 0.6, g = 0.6, b = 0.6, clearsGroup = true }

local dropZones = {}

local function PaintDropZone(zone, alpha)
    if zone.tag then -- can be missing if the section just vanished under the mouse
        zone.fill:SetColorTexture(zone.tag.r, zone.tag.g, zone.tag.b, alpha)
    end
end

-- Is the item on the cursor from one of the bags this window shows? An item from the bank or
-- anywhere else must not be caught here: it has to go through Blizzard's own slot code, which moves
-- it into the bags. A zone would only clear the cursor and leave the item where it was.
local function CursorHasBagItem()
    if GetCursorInfo() ~= "item" then
        return false
    end
    local location = C_Cursor.GetCursorItem()
    local bag = location and location:GetBagAndSlot()
    if bag == nil then
        return false
    end
    if bag == Cubby.KEYRING_BAG or bag == Cubby.REAGENT_BAG then
        return true
    end
    for _, mainBag in ipairs(Cubby.MainBags()) do
        if bag == mainBag then
            return true
        end
    end
    return false
end

local function DropOnZone(zone)
    local cursorType, itemID = GetCursorInfo()
    if cursorType ~= "item" or not zone.tag or not CursorHasBagItem() then
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

-- Place zone number index over a section (zoneTag: group or NO_GROUP_ZONE)
local function PlaceDropZone(index, zoneTag, top, width, height)
    local zone = GetDropZone(index)
    zone.tag = zoneTag
    zone:ClearAllPoints()
    zone:SetPoint("TOPLEFT", Cubby.content, "TOPLEFT", 0, -top)
    zone:SetSize(width, height)
    zone.text:SetText(L.DROP_INTO:format(zoneTag.name))
    PaintDropZone(zone, 0.25)
end

-- Zones from this number on belong to no section any more.
local function ReleaseDropZones(firstUnused)
    for i = firstUnused, #dropZones do
        dropZones[i].tag = nil
    end
end

-- Visible only while an item from the bags is on the cursor
local function UpdateDropZones()
    local show = CursorHasBagItem()
    local _, cursorItemID = GetCursorInfo()
    local hasGroup = show and TagForItem(cursorItemID) ~= nil
    local first = Cubby.active[1]
    local level = first and first:GetFrameLevel()
    for _, zone in ipairs(dropZones) do
        -- Ungrouped items should still move normally between slots.
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
