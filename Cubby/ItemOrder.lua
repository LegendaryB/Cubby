-- Order of the items inside a group section (tag.sortBy). Only the display is ordered: nothing is
-- moved in the bags, so it costs no server call and cannot get in the way of Blizzard's sorting.
-- Without a mode the items stay in bag order.
local _, Cubby = ...
local L = Cubby.L

-- Modes in the order the menu lists them. "bag" stands for no ordering.
local ORDER_MODES = {
    { "bag", L.ORDER_BAG },
    { "quality", L.ORDER_QUALITY },
    { "name", L.ORDER_NAME },
    { "ilvl", L.ORDER_ILVL },
    { "type", L.ORDER_TYPE },
    { "value", L.ORDER_VALUE },
}
local VALID = {}
for _, mode in ipairs(ORDER_MODES) do
    VALID[mode[1]] = true
end

-- A sell price the game has not loaded yet counts as 0 for now; the order is redone when it arrives.
local pending = false

-- What one slot is ordered by. Everything comes from the slot's own item info, so it works
-- before the game has loaded the full item data.
local function SortKey(bag, slot, mode)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    local key = { name = "", id = 0, quality = 0 }
    if not info then
        return key
    end
    key.id = info.itemID or 0
    key.quality = info.quality or 0
    key.name = (info.hyperlink and info.hyperlink:match("%[(.-)%]") or ""):lower()
    if mode == "ilvl" then
        local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
        key.ilvl = C_Item.DoesItemExist(location) and C_Item.GetCurrentItemLevel(location) or 0
    elseif mode == "type" then
        local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(key.id)
        key.class, key.subclass = classID or 0, subClassID or 0
    elseif mode == "value" then
        key.value = Cubby.SellValue(info)
        if not info.hasNoValue and select(11, C_Item.GetItemInfo(key.id)) == nil then
            pending = true
        end
    end
    return key
end

-- Better quality, level and value first; types and names from A to Z. Ties fall back to the name,
-- then the item and finally the position in the bags, so the order never jumps around.
local function Before(a, b, mode)
    local ka, kb = a.key, b.key
    if mode == "quality" then
        if ka.quality ~= kb.quality then
            return ka.quality > kb.quality
        end
    elseif mode == "ilvl" then
        if ka.ilvl ~= kb.ilvl then
            return ka.ilvl > kb.ilvl
        end
    elseif mode == "value" then
        if ka.value ~= kb.value then
            return ka.value > kb.value
        end
    elseif mode == "type" then
        if ka.class ~= kb.class then
            return ka.class < kb.class
        end
        if ka.subclass ~= kb.subclass then
            return ka.subclass < kb.subclass
        end
    end
    if ka.name ~= kb.name then
        return ka.name < kb.name
    end
    if ka.id ~= kb.id then
        return ka.id < kb.id
    end
    return a.index < b.index
end

-- Orders a list of { bag, slot } in place
local function OrderSlots(slots, mode)
    if not VALID[mode] or mode == "bag" or #slots < 2 then
        return
    end
    local list = {}
    for i, entry in ipairs(slots) do
        list[i] = { entry = entry, index = i, key = SortKey(entry[1], entry[2], mode) }
    end
    table.sort(list, function(a, b)
        return Before(a, b, mode)
    end)
    for i, wrapped in ipairs(list) do
        slots[i] = wrapped.entry
    end
end

-- Sell prices that were missing have arrived: the order may be different now. Returns whether any were.
local function OrderDataArrived()
    local was = pending
    pending = false
    return was
end

Cubby.ORDER_MODES = ORDER_MODES
Cubby.OrderSlots = OrderSlots
Cubby.OrderDataArrived = OrderDataArrived
