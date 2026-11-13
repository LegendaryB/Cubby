-- Rule conditions: "what makes an item belong to a group".
-- A condition is a plain table { type, op, value, neg } that lives in CubbyDB (tag.rule.conds):
--   quality   op (">=", "<=", "=") and value 0..5
--   ilvl      op and value; only gear counts, other items have no meaningful item level
--   slot      value = equipment slot ("INVTYPE_HEAD", ...)
--   class     value = item class ID, label = its name        (e.g. all Consumables)
--   category  value = class * 1000 + subclass, label = name  (e.g. Trade Goods: Cloth)
--   bind      value = "boe", "bop", "bou" (when used), "quest" or "none"
--   minlevel  op and value: the level the item requires
--   name      value = text the item name contains (ignoring case)
--   price     op and value in copper: vendor value of one item
-- neg = true turns the result around ("NOT ...").
-- Evaluating returns true, false, or nil when the item data has not been loaded by the game yet.
local _, Cubby = ...
local L = Cubby.L

local QUALITIES = { 0, 1, 2, 3, 4, 5 }

-- Slots offered in the editor, and the ones that count as the same slot
local EQUIP_SLOTS = {
    "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK", "INVTYPE_CHEST", "INVTYPE_WRIST",
    "INVTYPE_HAND", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_FINGER", "INVTYPE_TRINKET",
    "INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_2HWEAPON", "INVTYPE_SHIELD",
    "INVTYPE_HOLDABLE", "INVTYPE_RANGED", "INVTYPE_THROWN", "INVTYPE_RELIC", "INVTYPE_AMMO", "INVTYPE_QUIVER",
    "INVTYPE_BAG", "INVTYPE_BODY", "INVTYPE_TABARD",
}
local SAME_SLOT = {
    INVTYPE_ROBE = "INVTYPE_CHEST",
    INVTYPE_RANGEDRIGHT = "INVTYPE_RANGED",
}

-- Binding kinds in the order the editor lists them, with the "bindType" Blizzard reports for each
local BIND_KINDS = {
    { "boe", 2, L.COND_BOE }, { "bop", 1, L.COND_BOP }, { "bou", 3, L.COND_BOU },
    { "quest", 4, L.COND_BIND_QUEST }, { "none", 0, L.COND_BIND_NONE },
}
local BIND_TYPES, BIND_TEXTS = {}, {}
for _, kind in ipairs(BIND_KINDS) do
    BIND_TYPES[kind[1]] = kind[2]
    BIND_TEXTS[kind[1]] = kind[3]
end

local function IsGear(equipLoc)
    return equipLoc ~= nil and equipLoc ~= "" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
        and equipLoc ~= "INVTYPE_BODY" and equipLoc ~= "INVTYPE_TABARD" and equipLoc ~= "INVTYPE_BAG"
end

local function Compare(op, actual, wanted)
    if type(actual) ~= "number" or type(wanted) ~= "number" then
        return false
    end
    if op == ">=" then
        return actual >= wanted
    elseif op == "<=" then
        return actual <= wanted
    end
    return actual == wanted
end

---------------------------------------------------------------------------
-- Evaluation, one function per type
---------------------------------------------------------------------------
local matchers = {}

function matchers.quality(cond, itemID)
    local quality = C_Item.GetItemQualityByID(itemID)
    if quality == nil then
        return nil
    end
    return Compare(cond.op, quality, cond.value)
end

function matchers.ilvl(cond, itemID)
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
    if equipLoc == nil then
        return nil
    end
    if not IsGear(equipLoc) then
        return false
    end
    local ilvl = select(4, C_Item.GetItemInfo(itemID))
    if ilvl == nil then
        return nil
    end
    return Compare(cond.op, ilvl, cond.value)
end

function matchers.slot(cond, itemID)
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
    if equipLoc == nil then
        return nil
    end
    return (SAME_SLOT[equipLoc] or equipLoc) == cond.value
end

function matchers.class(cond, itemID)
    local classID = select(6, C_Item.GetItemInfoInstant(itemID))
    if classID == nil then
        return nil
    end
    return classID == cond.value
end

function matchers.category(cond, itemID)
    local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    if classID == nil then
        return nil
    end
    return classID * 1000 + (subClassID or 0) == cond.value
end

function matchers.bind(cond, itemID)
    local bindType = select(14, C_Item.GetItemInfo(itemID))
    if bindType == nil then
        return nil
    end
    return bindType == BIND_TYPES[cond.value]
end

function matchers.minlevel(cond, itemID)
    local minLevel = select(5, C_Item.GetItemInfo(itemID))
    if minLevel == nil then
        return nil
    end
    return Compare(cond.op, minLevel, cond.value)
end

function matchers.name(cond, itemID)
    local name = C_Item.GetItemInfo(itemID)
    if name == nil then
        return nil
    end
    if type(cond.value) ~= "string" or cond.value == "" then
        return false
    end
    return name:lower():find(cond.value:lower(), 1, true) ~= nil
end

function matchers.price(cond, itemID)
    local sellPrice = select(11, C_Item.GetItemInfo(itemID))
    if sellPrice == nil then
        return nil
    end
    return Compare(cond.op, sellPrice, cond.value)
end

-- true / false / nil (unknown) for one condition, including "NOT"
local function MatchesCondition(cond, itemID)
    local matcher = matchers[cond.type]
    if not matcher then
        return false -- a type from a newer version: never matches
    end
    local result = matcher(cond, itemID)
    if result ~= nil and cond.neg then
        return not result
    end
    return result
end

-- All conditions of a rule ("all" = every one must hold, "any" = one is enough).
-- Unknown item data only decides the outcome when the known conditions leave it open.
local function MatchesRule(rule, itemID)
    if not rule or not rule.conds or #rule.conds == 0 then
        return false
    end
    local wantAll = rule.match ~= "any"
    local unknown = false
    for _, cond in ipairs(rule.conds) do
        local result = MatchesCondition(cond, itemID)
        if result == nil then
            unknown = true
        elseif wantAll and not result then
            return false
        elseif not wantAll and result then
            return true
        end
    end
    if unknown then
        return nil
    end
    return wantAll
end

---------------------------------------------------------------------------
-- Conditions from outside
---------------------------------------------------------------------------
local VALID_OPS = { [">="] = true, ["<="] = true, ["="] = true }
local VALID_SLOTS = {}
for _, slot in ipairs(EQUIP_SLOTS) do
    VALID_SLOTS[slot] = true
end
local NUMBER_LIMITS = { quality = 5, ilvl = 100000, minlevel = 1000, price = 2000000000 }

local function IsWhole(value, high)
    return type(value) == "number" and value == math.floor(value) and value >= 0 and value <= high
end

-- A clean copy of a condition read from an import, or nil if it is not a valid one. Only known
-- types and values are accepted; text is cleaned and shortened.
local function SanitizeCondition(raw)
    if type(raw) ~= "table" then
        return nil
    end
    local kind, value = raw.type, raw.value
    local cond = { type = kind }
    if NUMBER_LIMITS[kind] then
        if not VALID_OPS[raw.op] or not IsWhole(value, NUMBER_LIMITS[kind]) then
            return nil
        end
        cond.op, cond.value = raw.op, value
    elseif kind == "slot" then
        if not VALID_SLOTS[value] then
            return nil
        end
        cond.value = value
    elseif kind == "class" or kind == "category" then
        if not IsWhole(value, kind == "class" and 99 or 99999) then
            return nil
        end
        cond.value = value
        local label = Cubby.CleanText(raw.label, 60)
        cond.label = label ~= "" and label or nil
    elseif kind == "bind" then
        if BIND_TYPES[value] == nil then
            return nil
        end
        cond.value = value
    elseif kind == "name" then
        local text = Cubby.CleanText(value, 60)
        if text == "" then
            return nil
        end
        cond.value = text
    else
        return nil
    end
    cond.neg = raw.neg == true or nil
    return cond
end

---------------------------------------------------------------------------
-- Suggestions for an item
---------------------------------------------------------------------------
local BIND_BY_TYPE = {}
for _, kind in ipairs(BIND_KINDS) do
    BIND_BY_TYPE[kind[2]] = kind[1]
end

-- Conditions that describe this item, to turn one of them into a rule. Only what the game
-- already knows about the item is offered.
local function ConditionsForItem(itemID)
    local list = {}
    local _, itemType, subType, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    if not classID then
        return list
    end
    local label = itemType or "?"
    if subType and subType ~= "" and subType ~= itemType then
        label = label .. ": " .. subType
    end
    list[#list + 1] = { type = "category", value = classID * 1000 + (subClassID or 0), label = label }
    list[#list + 1] = { type = "class", value = classID, label = itemType or "?" }

    local quality = C_Item.GetItemQualityByID(itemID)
    if quality then
        list[#list + 1] = { type = "quality", op = ">=", value = quality }
        list[#list + 1] = { type = "quality", op = "=", value = quality }
    end
    if IsGear(equipLoc) then
        list[#list + 1] = { type = "slot", value = SAME_SLOT[equipLoc] or equipLoc }
        local ilvl = select(4, C_Item.GetItemInfo(itemID))
        if ilvl and ilvl > 0 then
            list[#list + 1] = { type = "ilvl", op = ">=", value = ilvl }
        end
    end
    local bind = BIND_BY_TYPE[select(14, C_Item.GetItemInfo(itemID))]
    if bind and bind ~= "none" then
        list[#list + 1] = { type = "bind", value = bind }
    end
    local name = C_Item.GetItemInfo(itemID)
    if name and name ~= "" then
        list[#list + 1] = { type = "name", value = name }
    end
    return list
end

---------------------------------------------------------------------------
-- Texts
---------------------------------------------------------------------------
local function OperatorText(op)
    if op == ">=" then
        return L.OP_AT_LEAST
    elseif op == "<=" then
        return L.OP_AT_MOST
    end
    return L.OP_EXACTLY
end

local function QualityText(quality)
    local name = _G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality)
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then
        name = ("|cff%02x%02x%02x%s|r"):format(
            math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5), name)
    end
    return name
end

local function SlotText(equipLoc)
    return _G[equipLoc] or equipLoc
end

-- Readable description, e.g. "Quality: at least Epic"
local function Describe(cond)
    local text
    local t = cond.type
    if t == "quality" then
        text = L.COND_QUALITY:format(OperatorText(cond.op), QualityText(cond.value or 0))
    elseif t == "ilvl" then
        text = L.COND_ILVL:format(OperatorText(cond.op), tostring(cond.value or 0))
    elseif t == "slot" then
        text = L.COND_SLOT:format(SlotText(tostring(cond.value)))
    elseif t == "class" or t == "category" then
        text = L.COND_TYPE:format(cond.label or tostring(cond.value))
    elseif t == "bind" then
        text = BIND_TEXTS[cond.value] or L.COND_BOP
    elseif t == "minlevel" then
        text = L.COND_REQLEVEL:format(OperatorText(cond.op), tostring(cond.value or 0))
    elseif t == "name" then
        text = L.COND_NAME:format(tostring(cond.value))
    elseif t == "price" then
        text = L.COND_PRICE:format(OperatorText(cond.op), GetMoneyString(cond.value or 0, true))
    else
        text = tostring(t)
    end
    if cond.neg then
        text = L.COND_NOT:format(text)
    end
    return text
end

Cubby.QUALITIES = QUALITIES
Cubby.EQUIP_SLOTS = EQUIP_SLOTS
Cubby.MatchesCondition = MatchesCondition
Cubby.ConditionsForItem = ConditionsForItem
Cubby.SanitizeCondition = SanitizeCondition
Cubby.BIND_KINDS = BIND_KINDS
Cubby.MatchesRule = MatchesRule
Cubby.DescribeCondition = Describe
Cubby.SlotText = SlotText
Cubby.QualityText = QualityText
