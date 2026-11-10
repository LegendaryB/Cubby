-- Blizzards Taschenfenster verstecken und Cubbys Fenster mit ihnen auf- und zugehen lassen.
-- Die Blizzard-Fenster bleiben "offen" (IsShown), sind aber unsichtbar. So bleibt Blizzards Logik
-- (Tasten, Briefkasten, Haendler) intakt.
local _, Cubby = ...
local state = Cubby.state
local L = Cubby.L
local frame = Cubby.frame

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

local function GetBlizzardBagFrames()
    local list = {}
    for i = 1, 20 do
        local f = _G["ContainerFrame" .. i]
        if f then
            list[#list + 1] = f
        end
    end
    if ContainerFrameCombinedBags then
        list[#list + 1] = ContainerFrameCombinedBags
    end
    return list
end

local function HideBlizzardBags()
    if state.failed then
        return
    end
    for _, f in ipairs(GetBlizzardBagFrames()) do
        if f:GetParent() ~= hiddenParent then
            f:SetParent(hiddenParent)
        end
    end
end

local function RestoreBlizzardBags()
    for _, f in ipairs(GetBlizzardBagFrames()) do
        f:SetParent(UIParent)
    end
    if UpdateContainerFrameAnchors then
        pcall(UpdateContainerFrameAnchors)
    end
end

-- Bei einem Fehler: Meldung im Chat, Fehler speichern, Blizzard-Taschen zurueckholen.
local function Fail(err)
    state.failed = true
    if Cubby.db then
        Cubby.db.lastError = err
    end
    Cubby.Print("|cffff4040" .. L.FALLBACK_ERROR .. "|r " .. tostring(err):match("^[^\n]*"))
    RestoreBlizzardBags()
    Cubby.HideWindowQuietly()
end

---------------------------------------------------------------------------
-- Sichtbarkeit
---------------------------------------------------------------------------
local syncPending = false
local function SyncVisibility()
    syncPending = false
    if state.failed then
        return
    end
    local open = IsAnyBagOpen()
    if open and not frame:IsShown() then
        frame:Show()
    elseif not open and frame:IsShown() then
        Cubby.HideWindowQuietly()
    end
end

-- Blizzard oeffnet und schliesst Taschen an vielen Stellen; nachgezogen wird einmal im naechsten Frame.
local function RequestSync()
    if syncPending then
        return
    end
    syncPending = true
    if RunNextFrame then
        RunNextFrame(SyncVisibility)
    else
        C_Timer.After(0, SyncVisibility)
    end
end

local function InstallHooks()
    for _, name in ipairs({ "OpenAllBags", "CloseAllBags", "ToggleAllBags", "ToggleBackpack",
        "OpenBackpack", "CloseBackpack", "ToggleBag", "OpenBag", "CloseBag" }) do
        if _G[name] then
            hooksecurefunc(name, RequestSync)
        end
    end

    for _, f in ipairs(GetBlizzardBagFrames()) do
        hooksecurefunc(f, "Show", RequestSync)
        hooksecurefunc(f, "Hide", RequestSync)
    end

    if MerchantFrame_Update then
        hooksecurefunc("MerchantFrame_Update", Cubby.UpdateBlizzardJunkButton)
    end

    -- Blizzard haengt die Taschen bei Vollbild-Fenstern um; danach wieder verstecken.
    if ContainerFrame_SetFullScreenFrame then
        hooksecurefunc("ContainerFrame_SetFullScreenFrame", function(fullscreenFrame)
            HideBlizzardBags()
            if fullscreenFrame then
                frame:SetParent(fullscreenFrame)
            end
        end)
    end
    if ContainerFrame_ClearFullScreenFrame then
        hooksecurefunc("ContainerFrame_ClearFullScreenFrame", function()
            HideBlizzardBags()
            frame:SetParent(UIParent)
        end)
    end
end

Cubby.HideBlizzardBags = HideBlizzardBags
Cubby.InstallHooks = InstallHooks
Cubby.Fail = Fail
