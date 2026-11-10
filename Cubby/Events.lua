-- Einstellungen laden und auf Spiel-Events reagieren. Wird als letzte Datei geladen.
local _, Cubby = ...
local state = Cubby.state
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
    db.tags = db.tags or {}
    db.nextTagID = db.nextTagID or 1
    db.itemTags = db.itemTags or {}
    db.rules = db.rules or {}
    for _, tag in ipairs(Cubby.SortedTags()) do -- aeltere Gruppen behalten ihre bisherige (alphabetische) Reihenfolge
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
        SafeRefresh() -- setzt auch den Verkaufsschutz auf den Buttons
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

-- Items haben sich bewegt. Neu anordnen muss nur, wer Bereiche hat oder freie Plaetze buendelt:
-- sonst steht jeder Platz fest an seiner Stelle.
function events.BAG_UPDATE_DELAYED()
    state.softLayout = state.softLayout or Cubby.HasSectionTags() or Cubby.db.combineFreeSlots
    ScheduleRefresh()
end

function events.PLAYER_MONEY()
    if frame:IsShown() then
        Cubby.UpdateFooter()
    end
end

events.MERCHANT_SHOW = OnMerchantChanged
events.MERCHANT_CLOSED = OnMerchantChanged

function events.CURSOR_CHANGED()
    -- Das Event feuert mitten im Aufnehmen; erst im naechsten Frame eingreifen.
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

-- Questitems und neue Items aendern nur die Anzeige der Buttons.
local function RefreshSoon()
    ScheduleRefresh()
end
events.QUEST_ACCEPTED = RefreshSoon
events.QUEST_REMOVED = RefreshSoon
events.BAG_NEW_ITEMS_UPDATED = RefreshSoon
events.GET_ITEM_INFO_RECEIVED = RefreshSoon -- Itemdaten fuer den Haendlerwert sind nachgeladen
events.PLAYER_EQUIPMENT_CHANGED = RefreshSoon -- Upgrade-Pfeile neu bewerten
events.PLAYER_LEVEL_UP = RefreshSoon

frame:SetScript("OnEvent", function(_, event, ...)
    if not Cubby.db and event ~= "PLAYER_LOGIN" then
        return -- vor dem Einloggen gibt es noch keine Einstellungen
    end
    events[event](event, ...)
end)

for event in pairs(events) do
    pcall(frame.RegisterEvent, frame, event) -- unbekannte Events still ignorieren
end
