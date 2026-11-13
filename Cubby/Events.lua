-- Load settings and react to game events. Loaded as the last file.
local _, Cubby = ...
local state = Cubby.state
local L = Cubby.L
local frame = Cubby.frame
local ScheduleRefresh, SafeRefresh = Cubby.ScheduleRefresh, Cubby.SafeRefresh

local function LoadSettings()
    CubbyDB = CubbyDB or {}
    local db = CubbyDB
    Cubby.db = db
    for key, value in pairs(Cubby.DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end
    db.lastError = nil
    db.lastReparent = nil
    db.lastBlocked = nil
    db.tags = db.tags or {}
    db.nextTagID = db.nextTagID or 1
    db.itemTags = db.itemTags or {}
    db.rules = db.rules or {}
    for _, tag in ipairs(Cubby.SortedTags()) do -- older groups keep their previous (alphabetical) order
        tag.order = tag.order or Cubby.NextTagOrder()
    end
end

local function OnCursorChanged()
    Cubby.DropProtectedCursorItem()
    if frame:IsShown() then
        Cubby.UpdateDropZones()
    end
end

local function OnMerchantChanged(event)
    state.merchantOpen = event == "MERCHANT_SHOW"
    Cubby.DropProtectedCursorItem()
    Cubby.UpdateBlizzardJunkButton()
    if frame:IsShown() then
        SafeRefresh() -- also sets the sell protection on the buttons
    end
end

local events = {}

function events.PLAYER_LOGIN()
    LoadSettings()
    local ok, err = xpcall(function()
        frame:SetScale(Cubby.db.scale)
        Cubby.RestorePosition()
        Cubby.HideBlizzardBags()
        Cubby.InstallHooks()
    end, Cubby.ErrorHandler)
    if not ok then
        Cubby.Fail(err)
    end
end

function events.BAG_CONTAINER_UPDATE()
    if state.merchantOpen then
        state.softLayout = true
    else
        state.needLayout = true
    end
    ScheduleRefresh()
end

-- Items moved. Only whoever has sections or combines free slots needs to re-arrange:
-- otherwise every slot stays fixed in its place.
function events.BAG_UPDATE_DELAYED()
    state.softLayout = state.softLayout or Cubby.HasSectionTags() or Cubby.db.combineFreeSlots
    ScheduleRefresh()
end

-- A bag's "ignore when sorting" setting changed (also by Blizzard's own menu)
function events.BAG_SLOT_FLAGS_UPDATED()
    if frame:IsShown() then
        Cubby.UpdateBagBar()
    end
end

function events.PLAYER_MONEY()
    if frame:IsShown() then
        Cubby.UpdateFooter()
    end
end

events.MERCHANT_SHOW = OnMerchantChanged
events.MERCHANT_CLOSED = OnMerchantChanged

function events.CURSOR_CHANGED()
    -- The event fires in the middle of picking up; only step in on the next frame.
    if state.merchantOpen or frame:IsShown() then
        C_Timer.After(0, OnCursorChanged)
    end
end

function events.ITEM_LOCK_CHANGED(_, bag, slot)
    local button = Cubby.FindButton(bag, slot)
    if button and button:IsShown() and frame:IsShown() then
        Cubby.UpdateButton(button)
    end
end

function events.BAG_UPDATE_COOLDOWN()
    if frame:IsShown() then
        for _, button in ipairs(Cubby.active) do
            button:UpdateCooldown(button:HasItem())
        end
    end
end

-- Quest items and new items only change how the buttons look.
local function RefreshSoon()
    ScheduleRefresh()
end
events.QUEST_ACCEPTED = RefreshSoon
events.QUEST_REMOVED = RefreshSoon
events.BAG_NEW_ITEMS_UPDATED = RefreshSoon
-- Item data has been loaded: needed for the vendor value, and rules may have been waiting for it
function events.GET_ITEM_INFO_RECEIVED()
    local rulesWaited = Cubby.ItemDataArrived()
    local orderWaited = Cubby.OrderDataArrived()
    if rulesWaited or orderWaited then
        state.softLayout = true
    end
    ScheduleRefresh()
end

-- The game finished (or updated) its own item search: pick up which slots it found.
function events.INVENTORY_SEARCH_UPDATE()
    if frame:IsShown() and state.searchText ~= "" then
        Cubby.ApplySearch()
    end
end

-- WoW blocked something Cubby (or code tainted by Cubby) tried to do: say which function, and keep
-- the call stack in db.lastBlocked so the cause can be found.
local function OnActionBlocked(_, addon, func)
    if addon ~= "Cubby" then
        return
    end
    Cubby.Print("|cffff4040" .. L.BLOCKED_ACTION .. "|r " .. tostring(func))
    Cubby.db.lastBlocked = tostring(func) .. " | " .. tostring(debugstack(2, 8, 0))
end
events.ADDON_ACTION_FORBIDDEN = OnActionBlocked
events.ADDON_ACTION_BLOCKED = OnActionBlocked

frame:SetScript("OnEvent", function(_, event, ...)
    if not Cubby.db and event ~= "PLAYER_LOGIN" then
        return -- there are no settings before login
    end
    events[event](event, ...)
end)

for event in pairs(events) do
    pcall(frame.RegisterEvent, frame, event) -- ignore unknown events silently
end
