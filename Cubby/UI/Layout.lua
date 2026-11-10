-- Layout and refresh: distributes the bag slots over sections and keeps the display up to date.
local _, Cubby = ...
local state = Cubby.state
local L = Cubby.L
local frame, content, active = Cubby.frame, Cubby.content, Cubby.active
local NumSlots, TagForItem, IsCollapsed = Cubby.NumSlots, Cubby.TagForItem, Cubby.IsCollapsed

local sectionTitles = {}

---------------------------------------------------------------------------
-- Sections
---------------------------------------------------------------------------
-- Returns the bag slots as { bag, slot }. With tagSlots, items whose group has its own section
-- go to tagSlots[tagID] instead.
-- With combineFree empty slots are not returned one by one but as a single entry at the end:
-- a real free slot with freeCount = number of all free slots. An item dropped there
-- lands on exactly that slot thanks to Blizzard's button code.
local function CollectSlots(bags, tagSlots, combineFree)
    local slots = {}
    local freeCount, freeSlot, freeSlotIsSpecial = 0, nil, nil
    for _, bag in ipairs(bags) do
        local _, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        local isSpecial = bagFamily ~= nil and bagFamily ~= 0 -- special bags do not accept every item
        for slot = 1, NumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if combineFree and not itemID then
                freeCount = freeCount + 1
                if not freeSlot or (freeSlotIsSpecial and not isSpecial) then
                    freeSlot, freeSlotIsSpecial = { bag, slot }, isSpecial
                end
            else
                local tag = tagSlots and TagForItem(itemID)
                local target = slots
                if tag and tag.section then
                    tagSlots[tag.id] = tagSlots[tag.id] or {}
                    target = tagSlots[tag.id]
                end
                target[#target + 1] = { bag, slot }
            end
        end
    end
    if freeSlot then
        freeSlot.freeCount = freeCount
        slots[#slots + 1] = freeSlot
    end
    return slots
end

local function ShowKeyring()
    local keyring = Cubby.KEYRING_BAG
    return Cubby.db.showKeyring and keyring and C_ActionBar and C_ActionBar.ShouldShowKeyring
        and C_ActionBar.ShouldShowKeyring() and GetCVarBool("showKeyring") and NumSlots(keyring) > 0
end

-- Order: ungrouped items, group sections, reagents, keyring.
-- A section is { slots, tag } for groups, { slots, title } for fixed sections.
local function GetSections()
    local tagSlots = {}
    local combineFree = Cubby.db.combineFreeSlots
    local sections = { { slots = CollectSlots(Cubby.MainBags(), tagSlots, combineFree), zoneTag = Cubby.NO_GROUP_ZONE } }

    local reagentBag = Cubby.REAGENT_BAG
    local reagentSlots
    if reagentBag and NumSlots(reagentBag) > 0 then
        reagentSlots = CollectSlots({ reagentBag }, tagSlots, combineFree)
    end

    for _, tag in ipairs(Cubby.AreaTagsInOrder()) do -- show even when empty, so items can be dragged in
        sections[#sections + 1] = { slots = tagSlots[tag.id] or {}, tag = tag }
    end

    if reagentSlots and #reagentSlots > 0 then
        sections[#sections + 1] = { title = L.REAGENTS, slots = reagentSlots }
    end

    if ShowKeyring() then
        sections[#sections + 1] = { title = KEYRING or L.KEYRING, slots = CollectSlots({ Cubby.KEYRING_BAG }) }
    end

    return sections
end

local function ShowSectionTitle(index, text, top)
    local fontString = sectionTitles[index]
    if not fontString then
        fontString = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sectionTitles[index] = fontString
    end
    fontString:ClearAllPoints()
    fontString:SetPoint("TOPLEFT", 0, -(top + 4))
    fontString:SetText(text)
    fontString:Show()
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
local function Layout()
    local columns = Cubby.db.columns
    local step = Cubby.SLOT + Cubby.GAP
    local width = columns * step - Cubby.GAP
    local zoneIndex, headerIndex, titleIndex = 0, 0, 0

    for _, button in ipairs(active) do
        button:Hide()
    end
    wipe(active)
    for _, fontString in ipairs(sectionTitles) do
        fontString:Hide()
    end
    Cubby.HideGroupHeaders()

    local y = 0
    for _, section in ipairs(GetSections()) do
        local sectionTop = y
        if section.tag then
            headerIndex = headerIndex + 1
            Cubby.ShowGroupHeader(headerIndex, section, y, width)
            y = y + Cubby.SECTION_H
        elseif section.title then
            titleIndex = titleIndex + 1
            ShowSectionTitle(titleIndex, section.title, y)
            y = y + Cubby.SECTION_H
        end

        local collapsed = section.tag and IsCollapsed(section.tag)
        local index = 0
        for _, entry in ipairs(collapsed and {} or section.slots) do
            local button = Cubby.GetButton(entry[1], entry[2])
            button.cubbyFreeCount = entry.freeCount
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", content, "TOPLEFT",
                (index % columns) * step,
                -(y + math.floor(index / columns) * step))
            button:Show()
            active[#active + 1] = button
            index = index + 1
        end
        if collapsed then
            y = y + 2
        elseif index == 0 and section.tag then
            y = y + Cubby.EMPTY_SECTION_H + 2
        else
            y = y + math.max(1, math.ceil(index / columns)) * step + 2
        end

        local zoneTag = section.tag or section.zoneTag
        if zoneTag then
            zoneIndex = zoneIndex + 1
            Cubby.PlaceDropZone(zoneIndex, zoneTag, sectionTop, width, y - sectionTop - 2)
        end
    end

    Cubby.ReleaseDropZones(zoneIndex + 1)
    Cubby.UpdateMoveButtons(headerIndex)

    content:SetSize(width, y)
    frame:SetSize(width + Cubby.PAD * 2, Cubby.HEADER_H + y + Cubby.FOOTER_H)
    state.needLayout = false
    state.softLayout = false
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------
local SafeRefresh -- defined below

-- Nothing may slip away under the mouse, otherwise the next click would hit a different item.
local waitingForMouse = false
local function WaitForMouseLeave()
    if state.softLayout and frame:IsShown() and content:IsMouseOver() then
        C_Timer.After(0.25, WaitForMouseLeave)
        return
    end
    waitingForMouse = false
    if state.softLayout and frame:IsShown() then
        SafeRefresh()
    end
end

local function Refresh()
    -- Do not re-arrange at the vendor: during a sale everything stays put, it is tidied up afterwards.
    if state.needLayout or (state.softLayout and not state.merchantOpen and not content:IsMouseOver()) then
        Layout()
    end
    for _, button in ipairs(active) do
        Cubby.UpdateButton(button)
    end
    Cubby.UpdateFooter()
    Cubby.UpdateGroupCounts()
    Cubby.UpdateBlizzardJunkButton()
    Cubby.UpdateDropZones()
    if state.softLayout and not state.merchantOpen and not waitingForMouse then
        waitingForMouse = true
        C_Timer.After(0.25, WaitForMouseLeave)
    end
end

-- Any error while refreshing falls back to Blizzard's bags instead of leaving the window broken.
SafeRefresh = function()
    if state.failed then
        return
    end
    local ok, err = xpcall(Refresh, Cubby.ErrorHandler)
    if not ok then
        Cubby.Fail(err)
    end
end

-- Many events arrive in quick succession; they are merged into one refresh.
local refreshPending = false
local function ScheduleRefresh()
    if not frame:IsShown() or refreshPending then
        return -- on the next open everything is refreshed anyway
    end
    refreshPending = true
    C_Timer.After(0.05, function()
        refreshPending = false
        if frame:IsShown() then
            SafeRefresh()
        end
    end)
end

-- Re-arrange immediately (when the window is closed, on the next open)
local function RequestLayout()
    state.needLayout = true
    if frame:IsShown() then
        SafeRefresh()
    end
end

Cubby.SafeRefresh = SafeRefresh
Cubby.ScheduleRefresh = ScheduleRefresh
Cubby.RequestLayout = RequestLayout
