-- Sort button: Blizzard sorts, Cubby keeps re-arranging while it does.
-- Blizzard's sorting moves items over several seconds. Re-arranging is explicitly wanted here,
-- even under the mouse and at the vendor: otherwise items visibly stay in the wrong section.
local _, Cubby = ...

local WATCH_STEP, WATCH_QUIET, WATCH_MAX = 0.2, 3, 30 -- seconds
local watchRun = 0

-- Contents of all bags as text, to detect changes
local function BagContents()
    local ids = {}
    for _, bag in ipairs(Cubby.TaggableBags()) do
        for slot = 1, Cubby.NumSlots(bag) do
            ids[#ids + 1] = C_Container.GetContainerItemID(bag, slot) or 0
        end
    end
    return table.concat(ids, ",")
end

-- Watches the bags until nothing has moved for WATCH_QUIET seconds.
local function WatchSorting()
    watchRun = watchRun + 1
    local run = watchRun
    local contents = BagContents()
    local quiet, elapsed = 0, 0

    local function Step()
        if run ~= watchRun then
            return -- a new sort run has taken over
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
