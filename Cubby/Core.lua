-- Cubby: all bags in one window.
-- Only replaces the display. Opening and closing still run through Blizzard's bag logic
-- (key bindings, mailbox, vendor etc. keep working as usual).
--
-- All files share the Cubby namespace through "...". The order in Cubby.toc is the
-- load order: values from earlier files may be cached at the top of a file,
-- functions from later files are only looked up via Cubby.<Name> when they are called.
local _, Cubby = ...

Cubby.DEFAULTS = {
    columns = 12,
    scale = 1,
    showItemLevel = true,
    showBoE = true,
    showKeyring = true,
    combineFreeSlots = true,
    showValue = true,
    locked = false,
}

-- Sizes in pixels
Cubby.SLOT, Cubby.GAP, Cubby.PAD = 37, 4, 10
Cubby.HEADER_H, Cubby.FOOTER_H, Cubby.SECTION_H = 58, 28, 18
Cubby.EMPTY_SECTION_H = 24

local BagIndex = Enum.BagIndex
local NUM_BAGS = Constants.InventoryConstants.NumBagSlots
local NUM_REAGENT_BAGS = Constants.InventoryConstants.NumReagentBagSlots or 0
Cubby.KEYRING_BAG = BagIndex.Keyring
Cubby.REAGENT_BAG = NUM_REAGENT_BAGS > 0 and BagIndex.ReagentBag or nil

-- Cubby.db: the saved settings (CubbyDB), set at login in Events.lua.

-- Runtime state shared by several files
Cubby.state = {
    searchText = "",
    needLayout = true,     -- always re-arrange on the next refresh
    softLayout = false,    -- items changed: re-arrange as soon as the mouse is no longer over the items
    merchantOpen = false,
    failed = false,        -- after an error Blizzard's bags are used again
}

-- The item buttons currently shown, in display order; the layout fills the list.
Cubby.active = {}

function Cubby.Print(msg)
    print("|cff33ff99Cubby|r: " .. msg)
end

function Cubby.ErrorHandler(err)
    return tostring(err) .. "\n" .. (debugstack and debugstack(2, 12, 0) or "")
end

-- The keyring has its own size query (Blizzard's code does the same).
function Cubby.NumSlots(bag)
    if bag == Cubby.KEYRING_BAG and GetKeyRingSize then
        return GetKeyRingSize() or 0
    end
    return C_Container.GetContainerNumSlots(bag) or 0
end

-- Vendor value of a bag slot in copper. Item data that is not loaded yet counts as 0 for now;
-- GET_ITEM_INFO_RECEIVED triggers a new calculation afterwards.
function Cubby.SellValue(info)
    if not info or info.hasNoValue then
        return 0
    end
    local sellPrice = select(11, C_Item.GetItemInfo(info.itemID))
    return (sellPrice or 0) * (info.stackCount or 1)
end

-- Backpack and the regular bags
function Cubby.MainBags()
    local bags = {}
    for bag = BagIndex.Backpack, NUM_BAGS do
        bags[#bags + 1] = bag
    end
    return bags
end

-- Bags whose items can belong to a group: the regular ones plus the reagent bag
function Cubby.TaggableBags()
    local bags = Cubby.MainBags()
    if Cubby.REAGENT_BAG then
        bags[#bags + 1] = Cubby.REAGENT_BAG
    end
    return bags
end
