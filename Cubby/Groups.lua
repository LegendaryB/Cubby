-- Groups: the data model behind sections, sell protection and automatic sorting.
-- Internally a group is called "tag"; the game shows "group" everywhere.
--
-- In CubbyDB:
--   tags[id]         = { id, name, r, g, b, noSell, section, order, collapsed }
--   itemTags[itemID] = group ID, or false for "deliberately no group" (also beats rules)
--   rules[category]  = { tagID, name }: all items of this category belong to the group automatically.
--                      category is a number (item class) or "q0".."q5" (quality).
local _, Cubby = ...
local state = Cubby.state
local L = Cubby.L

-- Quality levels for rules: poor (gray) up to legendary
local QUALITIES = { 0, 1, 2, 3, 4, 5 }

local NEW_TAG_COLORS = {
    { 0.25, 0.65, 1 }, { 0.3, 0.85, 0.4 }, { 1, 0.8, 0.2 }, { 0.8, 0.45, 1 }, { 1, 0.55, 0.2 },
}

-- After every change to groups: re-arrange and check Blizzard's junk button.
local function TagsChanged()
    Cubby.RequestLayout()
    Cubby.UpdateBlizzardJunkButton()
end

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------
-- Category of an item as a number (class * 1000 + subclass) plus a readable name
local function ItemCategory(itemID)
    local _, itemType, itemSubType, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    if not classID then
        return nil
    end
    local label = itemType or "?"
    if itemSubType and itemSubType ~= "" and itemSubType ~= itemType then
        label = label .. ": " .. itemSubType
    end
    return classID * 1000 + (subClassID or 0), label
end

-- Group that a rule assigns the category to
local function RuleTag(category)
    local rule = Cubby.db.rules[category]
    return rule and Cubby.db.tags[rule.tagID] or nil
end

local function QualityKey(quality)
    return "q" .. quality
end

-- A category rule is more specific than a quality rule and therefore wins.
local function RuleTagForItem(itemID)
    local category = ItemCategory(itemID)
    local tag = category and RuleTag(category)
    if tag then
        return tag
    end
    local quality = C_Item.GetItemQualityByID(itemID)
    return quality and RuleTag(QualityKey(quality)) or nil
end

-- A manual assignment always takes precedence over a rule.
local function TagForItem(itemID)
    local db = Cubby.db
    if not db or not itemID then
        return nil
    end
    local tagID = db.itemTags[itemID]
    if tagID == false then
        return nil
    elseif tagID then
        return db.tags[tagID]
    end
    return RuleTagForItem(itemID)
end

-- Does the group come only from a rule, i.e. without a manual assignment?
local function IsAutoTagged(itemID)
    return Cubby.db.itemTags[itemID] == nil
end

local function IsSellProtected(itemID)
    local tag = TagForItem(itemID)
    return tag ~= nil and tag.noSell == true
end

-- Group name in the group color
local function TagLabel(tag)
    return ("|cff%02x%02x%02x%s|r"):format(
        math.floor(tag.r * 255 + 0.5), math.floor(tag.g * 255 + 0.5), math.floor(tag.b * 255 + 0.5), tag.name)
end

local function SortedTags()
    local list = {}
    for _, tag in pairs(Cubby.db.tags) do
        list[#list + 1] = tag
    end
    table.sort(list, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    return list
end

-- Groups with their own section, in the order set by the player
local function AreaTagsInOrder()
    local list = {}
    for _, tag in pairs(Cubby.db.tags) do
        if tag.section then
            list[#list + 1] = tag
        end
    end
    table.sort(list, function(a, b)
        return a.order < b.order
    end)
    return list
end

local function NextTagOrder()
    local highest = 0
    for _, tag in pairs(Cubby.db.tags) do
        highest = math.max(highest, tag.order or 0)
    end
    return highest + 1
end

local function HasSectionTags()
    for _, tag in pairs(Cubby.db.tags) do
        if tag.section then
            return true
        end
    end
    return false
end

-- While searching all sections are open, otherwise matches in collapsed sections would stay invisible.
local function IsCollapsed(tag)
    return tag.collapsed == true and state.searchText == ""
end

-- Rule choices are the categories currently in the bags plus all that are already assigned.
local function RuleCategories()
    local seen, list = {}, {}
    local function Add(category, label)
        if not seen[category] then
            seen[category] = true
            list[#list + 1] = { category = category, label = label }
        end
    end
    for category, rule in pairs(Cubby.db.rules) do
        if type(category) == "number" then -- quality rules are listed in QualityRules
            Add(category, rule.name)
        end
    end
    for _, bag in ipairs(Cubby.TaggableBags()) do
        for slot = 1, Cubby.NumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID then
                local category, label = ItemCategory(itemID)
                if category then
                    Add(category, label)
                end
            end
        end
    end
    table.sort(list, function(a, b)
        return a.label:lower() < b.label:lower()
    end)
    return list
end

-- All quality levels as rule entries, name in quality color (names come from Blizzard)
local function QualityRules()
    local list = {}
    for _, quality in ipairs(QUALITIES) do
        local name = _G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality)
        local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if color then
            name = ("|cff%02x%02x%02x%s|r"):format(
                math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5), name)
        end
        list[#list + 1] = { category = QualityKey(quality), label = L.QUALITY_RULE:format(name) }
    end
    return list
end

---------------------------------------------------------------------------
-- Changes
---------------------------------------------------------------------------
local function SetItemTag(itemID, tagID)
    if tagID == nil and RuleTagForItem(itemID) then
        tagID = false -- otherwise the rule would sort the item right back
    end
    Cubby.db.itemTags[itemID] = tagID
    TagsChanged()
end

local function CreateTag(name)
    local db = Cubby.db
    local tagID = db.nextTagID
    db.nextTagID = tagID + 1
    local color = NEW_TAG_COLORS[(tagID - 1) % #NEW_TAG_COLORS + 1]
    local tag = {
        id = tagID, name = name, r = color[1], g = color[2], b = color[3],
        noSell = false, section = true, order = NextTagOrder(),
    }
    db.tags[tagID] = tag
    return tag
end

local function RenameTag(tag, name)
    tag.name = name
    TagsChanged()
end

local function DeleteTag(tag)
    local db = Cubby.db
    for itemID, tagID in pairs(db.itemTags) do
        if tagID == tag.id then
            db.itemTags[itemID] = nil
        end
    end
    for category, rule in pairs(db.rules) do
        if rule.tagID == tag.id then
            db.rules[category] = nil
        end
    end
    db.tags[tag.id] = nil
    TagsChanged()
end

local function ToggleSellProtection(tag)
    tag.noSell = not tag.noSell
    TagsChanged()
end

local function ToggleSection(tag)
    tag.section = not tag.section
    TagsChanged()
end

local function ToggleCollapsed(tag)
    tag.collapsed = not tag.collapsed
    TagsChanged()
end

-- A category belongs to one group only: ticking it for another group moves it.
local function ToggleRule(tag, category, label)
    if RuleTag(category) == tag then
        Cubby.db.rules[category] = nil
    else
        Cubby.db.rules[category] = { tagID = tag.id, name = label }
    end
    TagsChanged()
end

-- Move a section by delta places in the order (-1 = up)
local function MoveArea(tag, delta)
    local list = AreaTagsInOrder()
    for i, other in ipairs(list) do
        if other == tag then
            local neighbour = list[i + delta]
            if neighbour then
                tag.order, neighbour.order = neighbour.order, tag.order
                TagsChanged()
            end
            return
        end
    end
end

Cubby.TagsChanged = TagsChanged
Cubby.TagForItem = TagForItem
Cubby.IsAutoTagged = IsAutoTagged
Cubby.IsSellProtected = IsSellProtected
Cubby.TagLabel = TagLabel
Cubby.SortedTags = SortedTags
Cubby.AreaTagsInOrder = AreaTagsInOrder
Cubby.NextTagOrder = NextTagOrder
Cubby.HasSectionTags = HasSectionTags
Cubby.IsCollapsed = IsCollapsed
Cubby.RuleTag = RuleTag
Cubby.RuleCategories = RuleCategories
Cubby.QualityRules = QualityRules
Cubby.SetItemTag = SetItemTag
Cubby.CreateTag = CreateTag
Cubby.RenameTag = RenameTag
Cubby.DeleteTag = DeleteTag
Cubby.ToggleSellProtection = ToggleSellProtection
Cubby.ToggleSection = ToggleSection
Cubby.ToggleCollapsed = ToggleCollapsed
Cubby.ToggleRule = ToggleRule
Cubby.MoveArea = MoveArea
