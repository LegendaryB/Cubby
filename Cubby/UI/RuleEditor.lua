-- Rule editor: the conditions of one group (see Conditions.lua). Opened from the group menus.
-- Left of the main window. Every change goes through Cubby.AddCondition & co., which re-arrange
-- the bags and call Cubby.RefreshRuleEditor.
local _, Cubby = ...
local frame, PAD = Cubby.frame, Cubby.PAD
local L = Cubby.L

local WIDTH, ROW_H, LIST_TOP = 360, 24, -64

local editor = Cubby.CreatePanel("CubbyRuleEditor")
editor:SetWidth(WIDTH)
editor:SetPoint("TOPRIGHT", frame, "TOPLEFT", -4, 0)

local current -- the group being edited

local title = editor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", PAD, -PAD)
title:SetPoint("TOPRIGHT", -30, -PAD)
title:SetJustifyH("LEFT")
title:SetWordWrap(false)

local closeButton = CreateFrame("Button", nil, editor, "UIPanelCloseButton")
closeButton:SetPoint("TOPRIGHT", 2, 2)
closeButton:SetScript("OnClick", function() editor:Hide() end)

local matchButton = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
matchButton:SetSize(WIDTH - 2 * PAD, 22)
matchButton:SetPoint("TOP", 0, -34)
matchButton:SetScript("OnClick", function()
    if current then
        local match = current.rule and current.rule.match or "all"
        Cubby.SetRuleMatch(current, match == "all" and "any" or "all")
    end
end)

local emptyText = editor:CreateFontString(nil, "OVERLAY", "GameFontDisable")
emptyText:SetPoint("TOPLEFT", PAD + 4, LIST_TOP - 2)
emptyText:SetWidth(WIDTH - 2 * PAD - 8)
emptyText:SetJustifyH("LEFT")
emptyText:SetText(L.NO_CONDITIONS)

local addButton = CreateFrame("Button", nil, editor, "UIPanelButtonTemplate")
addButton:SetSize(170, 22)
addButton:SetText(L.ADD_CONDITION)

local countText = editor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
countText:SetWidth(WIDTH - 2 * PAD)
countText:SetJustifyH("LEFT")

local hintText = editor:CreateFontString(nil, "OVERLAY", "GameFontDisable")
hintText:SetWidth(WIDTH - 2 * PAD)
hintText:SetJustifyH("LEFT")
hintText:SetText(L.RULE_PRIORITY_HINT)

---------------------------------------------------------------------------
-- Adding conditions
---------------------------------------------------------------------------
local function Capitalized(text)
    return (text:gsub("^%l", string.upper))
end

local OPERATORS = { { ">=", "OP_AT_LEAST" }, { "<=", "OP_AT_MOST" } }

local function AddCondition(cond)
    if current then
        Cubby.AddCondition(current, cond)
    end
end

-- Text, number and gold values are typed into a small dialog.
local function ApplyValue(data, text)
    text = (text or ""):gsub("|", "")
    text = strtrim(text)
    if text == "" or not Cubby.db.tags[data.tag.id] then
        return
    end
    local cond
    if data.kind == "name" then
        cond = { type = "name", value = text }
    else
        local number = tonumber((text:gsub(",", ".")))
        if not number or number < 0 then
            return
        end
        if data.kind == "gold" then
            cond = { type = "price", op = data.op, value = math.floor(number * 10000 + 0.5) }
        else
            cond = { type = "ilvl", op = data.op, value = math.floor(number + 0.5) }
        end
    end
    Cubby.AddCondition(data.tag, cond)
end

StaticPopupDialogs.CUBBY_CONDITION_VALUE = {
    text = "%s",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    OnShow = function(dialog)
        local editBox = dialog:GetEditBox()
        editBox:SetMaxLetters(24)
        editBox:SetText("")
    end,
    OnAccept = function(dialog, data)
        ApplyValue(data, dialog:GetEditBox():GetText())
    end,
    EditBoxOnEnterPressed = function(editBox, data)
        ApplyValue(data, editBox:GetText())
        editBox:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
    hideOnEscape = 1,
    timeout = 0,
    whileDead = 1,
}

local function AskValue(prompt, kind, op)
    if current then
        StaticPopup_Show("CUBBY_CONDITION_VALUE", prompt, nil, { tag = current, kind = kind, op = op })
    end
end

local function AddQualityEntries(menu)
    for _, operator in ipairs(OPERATORS) do
        local op = operator[1]
        local submenu = menu:CreateButton(Capitalized(L[operator[2]]))
        for _, quality in ipairs(Cubby.QUALITIES) do
            submenu:CreateButton(Cubby.QualityText(quality), function()
                AddCondition({ type = "quality", op = op, value = quality })
            end)
        end
    end
end

local function AddValueEntries(menu, prompt, kind)
    for _, operator in ipairs(OPERATORS) do
        local op, opText = operator[1], L[operator[2]]
        menu:CreateButton(Capitalized(opText) .. "...", function()
            AskValue(prompt:format(opText), kind, op)
        end)
    end
end

local function AddSlotEntries(menu)
    for _, slot in ipairs(Cubby.EQUIP_SLOTS) do
        menu:CreateButton(Cubby.SlotText(slot), function()
            AddCondition({ type = "slot", value = slot })
        end)
    end
end

-- Item classes and categories that are in the bags right now (or already used by a rule)
local function AddTypeEntries(menu)
    local categories = Cubby.RuleCategories()
    if #categories == 0 then
        menu:CreateTitle(L.NO_ITEMS_IN_BAGS)
        return
    end
    local classes, classList = {}, {}
    for _, entry in ipairs(categories) do
        local classID = math.floor(entry.category / 1000)
        if not classes[classID] then
            local name = GetItemClassInfo and GetItemClassInfo(classID) or entry.label:match("^(.-): ") or entry.label
            classes[classID] = name
            classList[#classList + 1] = { classID = classID, name = name }
        end
    end
    table.sort(classList, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    for _, class in ipairs(classList) do
        menu:CreateButton(L.ALL_OF_TYPE:format(class.name), function()
            AddCondition({ type = "class", value = class.classID, label = class.name })
        end)
    end
    menu:CreateDivider()
    for _, entry in ipairs(categories) do
        menu:CreateButton(entry.label, function()
            AddCondition({ type = "category", value = entry.category, label = entry.label })
        end)
    end
end

local function OpenAddMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        AddQualityEntries(root:CreateButton(L.COND_MENU_QUALITY))
        AddValueEntries(root:CreateButton(L.COND_MENU_ILVL), L.PROMPT_ILVL, "ilvl")
        AddSlotEntries(root:CreateButton(L.COND_MENU_SLOT))
        AddTypeEntries(root:CreateButton(L.COND_MENU_TYPE))
        local bind = root:CreateButton(L.COND_MENU_BIND)
        bind:CreateButton(L.COND_BOE, function()
            AddCondition({ type = "bind", value = "boe" })
        end)
        bind:CreateButton(L.COND_BOP, function()
            AddCondition({ type = "bind", value = "bop" })
        end)
        root:CreateButton(L.COND_MENU_NAME, function()
            AskValue(L.PROMPT_NAME, "name")
        end)
        AddValueEntries(root:CreateButton(L.COND_MENU_PRICE), L.PROMPT_PRICE, "gold")
    end)
end

addButton:SetScript("OnClick", function(self)
    OpenAddMenu(self)
end)

---------------------------------------------------------------------------
-- Rows and refresh
---------------------------------------------------------------------------
local rows = {}

local function SmallButton(parent, width, tooltip)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 20)
    button.tooltip = tooltip
    button:SetScript("OnEnter", Cubby.ShowIconTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, editor)
    row:SetSize(WIDTH - 2 * PAD, ROW_H)
    row:SetPoint("TOPLEFT", PAD, LIST_TOP - (index - 1) * ROW_H)

    row.notButton = SmallButton(row, 50, L.NOT_TIP)
    row.notButton:SetPoint("LEFT", 0, 0)
    row.notButton:SetScript("OnClick", function()
        if current then
            Cubby.ToggleConditionNegated(current, index)
        end
    end)

    row.removeButton = SmallButton(row, 20, L.REMOVE_TIP)
    row.removeButton:SetPoint("RIGHT", 0, 0)
    row.removeButton:SetText("x")
    row.removeButton:SetScript("OnClick", function()
        if current then
            Cubby.RemoveCondition(current, index)
        end
    end)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("LEFT", row.notButton, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", row.removeButton, "LEFT", -6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    return row
end

local function Refresh()
    if not editor:IsShown() or not current then
        return
    end
    if Cubby.db.tags[current.id] ~= current then
        editor:Hide() -- the group was deleted
        return
    end
    title:SetText(L.RULE_EDITOR_TITLE:format(Cubby.TagLabel(current)))

    local rule = current.rule
    local conds = rule and rule.conds or {}
    matchButton:SetText((rule and rule.match == "any") and L.MATCH_ANY or L.MATCH_ALL)

    for index, cond in ipairs(conds) do
        rows[index] = rows[index] or CreateRow(index)
        local row = rows[index]
        row.text:SetText(Cubby.DescribeCondition(cond))
        row.notButton:SetText(cond.neg and ("|cffff4040" .. L.NOT_SHORT .. "|r") or L.NOT_SHORT)
        row.notButton:SetAlpha(cond.neg and 1 or 0.55)
        row:Show()
    end
    for index = #conds + 1, #rows do
        rows[index]:Hide()
    end

    local y = LIST_TOP - math.max(#conds, 1) * ROW_H
    emptyText:SetShown(#conds == 0)
    addButton:ClearAllPoints()
    addButton:SetPoint("TOPLEFT", PAD, y - 6)
    countText:ClearAllPoints()
    countText:SetPoint("TOPLEFT", PAD, y - 38)
    countText:SetText(#conds > 0 and L.RULE_MATCHES:format(Cubby.RuleMatchCount(current)) or "")
    hintText:ClearAllPoints()
    hintText:SetPoint("TOPLEFT", PAD, y - 58)
    editor:SetHeight(-(y - 58) + 48)
end

function Cubby.RefreshRuleEditor()
    Refresh()
end

function Cubby.OpenRuleEditor(tag)
    current = tag
    editor:Show()
    Refresh()
end

editor:SetScript("OnShow", Refresh)
frame:HookScript("OnHide", function()
    editor:Hide()
end)
