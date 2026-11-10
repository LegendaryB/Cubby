-- Sortieren-Button: Blizzard sortiert, Cubby ordnet dabei laufend neu an.
-- Blizzards Sortieren verschiebt die Items ueber mehrere Sekunden. Hier ist das Umordnen ausdruecklich
-- gewollt, auch unter der Maus und beim Haendler: sonst bleiben Items sichtbar im falschen Bereich stehen.
local _, Cubby = ...

local WATCH_STEP, WATCH_QUIET, WATCH_MAX = 0.2, 3, 30 -- Sekunden
local watchRun = 0

-- Inhalt aller Taschen als Text, um Aenderungen zu erkennen
local function BagContents()
    local ids = {}
    for _, bag in ipairs(Cubby.TaggableBags()) do
        for slot = 1, Cubby.NumSlots(bag) do
            ids[#ids + 1] = C_Container.GetContainerItemID(bag, slot) or 0
        end
    end
    return table.concat(ids, ",")
end

-- Beobachtet die Taschen, bis sich WATCH_QUIET Sekunden lang nichts mehr bewegt hat.
local function WatchSorting()
    watchRun = watchRun + 1
    local run = watchRun
    local contents = BagContents()
    local quiet, elapsed = 0, 0

    local function Step()
        if run ~= watchRun then
            return -- ein neuer Sortiervorgang hat uebernommen
        end
        elapsed = elapsed + WATCH_STEP
        local current = BagContents()
        if current ~= contents then
            contents = current
            quiet = 0
            Cubby.RequestLayout()
        else
            quiet = quiet + WATCH_STEP
        end
        if quiet < WATCH_QUIET and elapsed < WATCH_MAX then
            C_Timer.After(WATCH_STEP, Step)
        end
    end

    C_Timer.After(WATCH_STEP, Step)
end

function Cubby.SortBags()
    C_Container.SortBags()
    WatchSorting()
end
