-- Export and import of groups as text, to share them or to move them to another character.
-- The text is "CUBBY1:" followed by a compact JSON document:
--   { groups = { { name, r, g, b, noSell, section, collapsed, sortBy,
--                  rule = { match, conds }, items = { itemID, ... }, cats = { { c = category, n = name } } } } }
-- Importing never runs the text as code: it is parsed by the small decoder below and every value is
-- checked before it reaches CubbyDB. Imported groups are added to the existing ones; nothing the
-- player already has is changed.
local _, Cubby = ...
local L = Cubby.L

local PREFIX = "CUBBY1:"
local MAX_TEXT, MAX_GROUPS, MAX_TAGS, MAX_LIST, MAX_CONDS, MAX_DEPTH = 500000, 100, 300, 5000, 30, 8

---------------------------------------------------------------------------
-- Encoding
---------------------------------------------------------------------------
local function EncodeString(text)
    return '"' .. (text:gsub('[%c"\\]', function(c)
        if c == '"' then
            return '\\"'
        elseif c == "\\" then
            return "\\\\"
        elseif c == "\n" then
            return "\\n"
        elseif c == "\r" then
            return "\\r"
        elseif c == "\t" then
            return "\\t"
        end
        return ("\\u%04x"):format(c:byte())
    end)) .. '"'
end

local Encode
Encode = function(value)
    local kind = type(value)
    if kind == "string" then
        return EncodeString(value)
    elseif kind == "boolean" then
        return tostring(value)
    elseif kind == "number" then
        if value == math.floor(value) then
            return ("%d"):format(value)
        end
        return (("%.3f"):format(value):gsub("0+$", ""))
    elseif kind == "table" then
        local parts = {}
        if next(value) == nil or value[1] ~= nil then
            for i, item in ipairs(value) do
                parts[i] = Encode(item)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for key in pairs(value) do
            keys[#keys + 1] = key
        end
        table.sort(keys)
        for _, key in ipairs(keys) do
            parts[#parts + 1] = EncodeString(key) .. ":" .. Encode(value[key])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    error("cannot encode a " .. kind)
end

---------------------------------------------------------------------------
-- Decoding
---------------------------------------------------------------------------
local ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", n = "\n", r = "\r", t = "\t" }

-- Returns the decoded value; any damage raises an error (the caller catches it with pcall).
local function Decode(text)
    local pos = 1
    local function Fail()
        error("damaged", 0)
    end
    local function SkipSpace()
        pos = text:find("%S", pos) or #text + 1
    end

    local function String()
        pos = pos + 1
        local out = {}
        while true do
            local stop = text:find('["\\]', pos)
            if not stop then
                Fail()
            end
            out[#out + 1] = text:sub(pos, stop - 1)
            if text:sub(stop, stop) == '"' then
                pos = stop + 1
                return table.concat(out)
            end
            local escape = text:sub(stop + 1, stop + 1)
            if ESCAPES[escape] then
                out[#out + 1] = ESCAPES[escape]
                pos = stop + 2
            elseif escape == "u" then
                local hex = text:match("^%x%x%x%x", stop + 2)
                local code = hex and tonumber(hex, 16)
                if not code or code > 127 then
                    Fail()
                end
                out[#out + 1] = string.char(code)
                pos = stop + 6
            else
                Fail()
            end
        end
    end

    local function Number()
        local literal = text:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
        local number = tonumber(literal)
        if not number or number ~= number or number == math.huge or number == -math.huge then
            Fail()
        end
        pos = pos + #literal
        return number
    end

    local Value
    Value = function(depth)
        if depth > MAX_DEPTH then
            Fail()
        end
        SkipSpace()
        local c = text:sub(pos, pos)
        if c == "{" then
            pos = pos + 1
            local object = {}
            SkipSpace()
            if text:sub(pos, pos) == "}" then
                pos = pos + 1
                return object
            end
            while true do
                SkipSpace()
                if text:sub(pos, pos) ~= '"' then
                    Fail()
                end
                local key = String()
                SkipSpace()
                if text:sub(pos, pos) ~= ":" then
                    Fail()
                end
                pos = pos + 1
                object[key] = Value(depth + 1)
                SkipSpace()
                local separator = text:sub(pos, pos)
                pos = pos + 1
                if separator == "}" then
                    return object
                elseif separator ~= "," then
                    Fail()
                end
            end
        elseif c == "[" then
            pos = pos + 1
            local list = {}
            SkipSpace()
            if text:sub(pos, pos) == "]" then
                pos = pos + 1
                return list
            end
            while true do
                list[#list + 1] = Value(depth + 1)
                SkipSpace()
                local separator = text:sub(pos, pos)
                pos = pos + 1
                if separator == "]" then
                    return list
                elseif separator ~= "," then
                    Fail()
                end
            end
        elseif c == '"' then
            return String()
        elseif text:sub(pos, pos + 3) == "true" then
            pos = pos + 4
            return true
        elseif text:sub(pos, pos + 4) == "false" then
            pos = pos + 5
            return false
        elseif c ~= "" and c:match("[-%d]") then
            return Number()
        end
        Fail()
    end

    local result = Value(1)
    SkipSpace()
    if pos <= #text then
        Fail()
    end
    return result
end

---------------------------------------------------------------------------
-- Export
---------------------------------------------------------------------------
local function Round(number)
    return math.floor(number * 1000 + 0.5) / 1000
end

-- Groups with a section in their order, then the others by name
local function AllTagsInOrder()
    local list, seen = {}, {}
    for _, tag in ipairs(Cubby.AreaTagsInOrder()) do
        list[#list + 1] = tag
        seen[tag] = true
    end
    for _, tag in ipairs(Cubby.SortedTags()) do
        if not seen[tag] then
            list[#list + 1] = tag
        end
    end
    return list
end

local function ExportGroup(tag)
    local db = Cubby.db
    local group = { name = tag.name, r = Round(tag.r), g = Round(tag.g), b = Round(tag.b) }
    if tag.noSell then
        group.noSell = true
    end
    if not tag.section then
        group.section = false
    end
    if tag.collapsed then
        group.collapsed = true
    end
    if tag.sortBy then
        group.sortBy = tag.sortBy
    end
    if tag.rule and tag.rule.conds and #tag.rule.conds > 0 then
        group.rule = { match = tag.rule.match == "any" and "any" or "all", conds = {} }
        for i, cond in ipairs(tag.rule.conds) do
            group.rule.conds[i] = cond
        end
    end
    local items = {}
    for itemID, tagID in pairs(db.itemTags) do
        if tagID == tag.id then
            items[#items + 1] = itemID
        end
    end
    if #items > 0 then
        table.sort(items)
        group.items = items
    end
    local cats = {}
    for category, rule in pairs(db.rules) do
        if rule.tagID == tag.id then
            cats[#cats + 1] = { c = category, n = rule.name }
        end
    end
    if #cats > 0 then
        table.sort(cats, function(a, b)
            return tostring(a.c) < tostring(b.c)
        end)
        group.cats = cats
    end
    return group
end

-- tags: the groups to export, all of them if left out
function Cubby.ExportGroups(tags)
    local groups = {}
    for _, tag in ipairs(tags or AllTagsInOrder()) do
        groups[#groups + 1] = ExportGroup(tag)
    end
    return PREFIX .. Encode({ groups = groups })
end

---------------------------------------------------------------------------
-- Import
---------------------------------------------------------------------------
local function Channel(value)
    if type(value) ~= "number" or value ~= value then
        return 0.5
    end
    return math.max(0, math.min(1, value))
end

local function IsWhole(value, low, high)
    return type(value) == "number" and value == math.floor(value) and value >= low and value <= high
end

-- A clean copy of one group, or nil. Things that cannot be read are left out and counted.
local function CleanGroup(raw, counts)
    if type(raw) ~= "table" then
        return nil
    end
    local name = Cubby.CleanText(raw.name, 24)
    if name == "" then
        return nil
    end
    local group = {
        name = name, r = Channel(raw.r), g = Channel(raw.g), b = Channel(raw.b),
        noSell = raw.noSell == true, section = raw.section ~= false, collapsed = raw.collapsed == true,
        conds = {}, items = {}, cats = {},
    }
    for _, mode in ipairs(Cubby.ORDER_MODES) do
        if mode[1] ~= "bag" and mode[1] == raw.sortBy then
            group.sortBy = raw.sortBy
        end
    end

    local rule = raw.rule
    if type(rule) == "table" and type(rule.conds) == "table" then
        group.match = rule.match == "any" and "any" or "all"
        for i = 1, #rule.conds do
            local cond = i <= MAX_CONDS and Cubby.SanitizeCondition(rule.conds[i])
            if cond then
                group.conds[#group.conds + 1] = cond
            else
                counts.dropped = counts.dropped + 1
            end
        end
    end

    if type(raw.items) == "table" then
        for i = 1, #raw.items do
            local itemID = raw.items[i]
            if i <= MAX_LIST and IsWhole(itemID, 1, 4294967295) then
                group.items[#group.items + 1] = itemID
            else
                counts.dropped = counts.dropped + 1
            end
        end
    end

    if type(raw.cats) == "table" then
        for i = 1, #raw.cats do
            local entry = raw.cats[i]
            local category = type(entry) == "table" and entry.c
            local valid = IsWhole(category, 0, 99999) or (type(category) == "string" and category:match("^q[0-5]$") ~= nil)
            if i <= MAX_LIST and valid then
                local label = Cubby.CleanText(entry.n, 60)
                group.cats[#group.cats + 1] = { category = category, name = label ~= "" and label or tostring(category) }
            else
                counts.dropped = counts.dropped + 1
            end
        end
    end
    return group
end

local function UniqueName(name, taken)
    local candidate, number = name, 1
    while taken[candidate:lower()] do
        number = number + 1
        candidate = ("%s (%d)"):format(name, number)
    end
    taken[candidate:lower()] = true
    return candidate
end

-- Adds the groups of an export. Returns { groups, items, kept, dropped }, or nil and a message.
-- items: item assignments made; kept: assignments skipped because the item already had one.
function Cubby.ImportGroups(text)
    text = tostring(text or "")
    if #text > MAX_TEXT then
        return nil, L.IMPORT_BROKEN
    end
    text = text:match("^%s*(.-)%s*$")
    if text:sub(1, #PREFIX) ~= PREFIX then
        return nil, L.IMPORT_BAD
    end
    local ok, root = pcall(Decode, text:sub(#PREFIX + 1))
    if not ok or type(root) ~= "table" or type(root.groups) ~= "table" then
        return nil, L.IMPORT_BROKEN
    end
    if #root.groups == 0 then
        return nil, L.IMPORT_NOTHING
    end

    local db = Cubby.db
    local existing = 0
    local taken = {}
    for _, tag in pairs(db.tags) do
        existing = existing + 1
        taken[tag.name:lower()] = true
    end
    if #root.groups > MAX_GROUPS or existing + #root.groups > MAX_TAGS then
        return nil, L.IMPORT_TOO_MANY
    end

    -- Check everything first, change CubbyDB afterwards
    local counts = { groups = 0, items = 0, kept = 0, dropped = 0 }
    local clean = {}
    for _, raw in ipairs(root.groups) do
        local group = CleanGroup(raw, counts)
        if group then
            clean[#clean + 1] = group
        else
            counts.dropped = counts.dropped + 1
        end
    end
    if #clean == 0 then
        return nil, L.IMPORT_NOTHING
    end

    for _, group in ipairs(clean) do
        local tag = Cubby.CreateTag(UniqueName(group.name, taken))
        tag.r, tag.g, tag.b = group.r, group.g, group.b
        tag.noSell, tag.section, tag.collapsed = group.noSell, group.section, group.collapsed or nil
        tag.sortBy = group.sortBy
        if #group.conds > 0 then
            tag.rule = { match = group.match, conds = group.conds }
        end
        for _, itemID in ipairs(group.items) do
            if db.itemTags[itemID] == nil then
                db.itemTags[itemID] = tag.id
                counts.items = counts.items + 1
            else
                counts.kept = counts.kept + 1
            end
        end
        for _, entry in ipairs(group.cats) do
            if db.rules[entry.category] == nil then
                db.rules[entry.category] = { tagID = tag.id, name = entry.name }
            else
                counts.kept = counts.kept + 1
            end
        end
        counts.groups = counts.groups + 1
    end
    Cubby.TagsChanged()
    return counts
end
