-- Menues und Dialoge rund um Gruppen: Gruppen-Button, Kopfzeilen-Menue und Alt+Linksklick auf ein Item.
local _, Cubby = ...
local TagLabel, SortedTags, TagsChanged = Cubby.TagLabel, Cubby.SortedTags, Cubby.TagsChanged

local function PickTagColor(tag)
    ColorPickerFrame:SetupColorPickerAndShow({
        r = tag.r,
        g = tag.g,
        b = tag.b,
        hasOpacity = false,
        swatchFunc = function()
            tag.r, tag.g, tag.b = ColorPickerFrame:GetColorRGB()
            TagsChanged()
        end,
        cancelFunc = function(previous)
            tag.r, tag.g, tag.b = previous.r, previous.g, previous.b
            TagsChanged()
        end,
    })
end

---------------------------------------------------------------------------
-- Dialoge
---------------------------------------------------------------------------
-- data.tag: diese Gruppe umbenennen. Sonst neue Gruppe anlegen, mit data.itemID gleich fuer dieses Item.
local function ApplyTagName(data, text)
    local name = (text or ""):gsub("|", "")
    name = strtrim(name)
    if name == "" then
        return
    end
    if data.tag then
        Cubby.RenameTag(data.tag, name)
        return
    end
    local tag = Cubby.CreateTag(name)
    if data.itemID then
        Cubby.SetItemTag(data.itemID, tag.id)
    else
        TagsChanged()
    end
    PickTagColor(tag)
end

StaticPopupDialogs.CUBBY_TAG_NAME = {
    text = "%s",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    OnShow = function(dialog, data)
        local editBox = dialog:GetEditBox()
        editBox:SetMaxLetters(24)
        editBox:SetText(data.tag and data.tag.name or "")
        editBox:HighlightText()
    end,
    OnAccept = function(dialog, data)
        ApplyTagName(data, dialog:GetEditBox():GetText())
    end,
    EditBoxOnEnterPressed = function(editBox, data)
        ApplyTagName(data, editBox:GetText())
        editBox:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = StaticPopup_StandardEditBoxOnEscapePressed,
    hideOnEscape = 1,
    timeout = 0,
    whileDead = 1,
}

StaticPopupDialogs.CUBBY_TAG_DELETE = {
    text = "Gruppe \"%s\" löschen? Alle Items verlieren diese Gruppe und damit auch einen Verkaufsschutz.",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, tag)
        Cubby.DeleteTag(tag)
    end,
    hideOnEscape = 1,
    timeout = 0,
    whileDead = 1,
}

-- itemID ist optional: die neue Gruppe bekommt dieses Item gleich zugewiesen.
local function AskNewGroupName(itemID)
    StaticPopup_Show("CUBBY_TAG_NAME", "Name für die neue Gruppe:", nil, { itemID = itemID })
end

---------------------------------------------------------------------------
-- Menues
---------------------------------------------------------------------------
-- Untermenue "Automatisch einsortieren": eine Checkbox pro Item-Kategorie
local function AddRuleEntries(description, tag)
    local categories = Cubby.RuleCategories()
    if #categories == 0 then
        description:CreateTitle("Keine Items in den Taschen")
    end
    for _, entry in ipairs(categories) do
        local category, label = entry.category, entry.label
        local owner = Cubby.RuleTag(category)
        local text = label
        if owner and owner ~= tag then
            text = text .. " (in: " .. owner.name .. ")"
        end
        description:CreateCheckbox(text, function()
            return Cubby.RuleTag(category) == tag
        end, function()
            Cubby.ToggleRule(tag, category, label)
        end)
    end
end

-- Einstellungen einer Gruppe; dieselben Eintraege im Gruppen-Button und im Kopfzeilen-Menue
local function AddTagEditEntries(description, tag)
    description:CreateCheckbox("Verkaufsschutz", function()
        return tag.noSell
    end, function()
        Cubby.ToggleSellProtection(tag)
    end)
    description:CreateCheckbox("Als Bereich anzeigen", function()
        return tag.section
    end, function()
        Cubby.ToggleSection(tag)
    end)
    AddRuleEntries(description:CreateButton("Automatisch einsortieren"), tag)
    description:CreateButton("Farbe ändern ...", function()
        PickTagColor(tag)
    end)
    description:CreateButton("Umbenennen ...", function()
        StaticPopup_Show("CUBBY_TAG_NAME", "Neuer Name:", nil, { tag = tag })
    end)
    description:CreateButton("Löschen ...", function()
        StaticPopup_Show("CUBBY_TAG_DELETE", tag.name, nil, tag)
    end)
end

-- Klick auf die Kopfzeile eines Bereichs
local function OpenGroupMenu(owner, tag)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(tag.name)
        AddTagEditEntries(root, tag)
    end)
end

-- Gruppen-Button: neue Gruppe anlegen und alle Gruppen bearbeiten, auch solche ohne Bereich
local function OpenGroupsMenu(owner)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateButton("Neue Gruppe ...", function()
            AskNewGroupName()
        end)
        root:CreateDivider()
        for _, tag in ipairs(SortedTags()) do
            AddTagEditEntries(root:CreateButton(TagLabel(tag)), tag)
        end
    end)
end

-- Alt+Linksklick auf ein Item: Gruppe zuweisen
local function OpenItemMenu(owner, itemID)
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(C_Item.GetItemInfo(itemID) or "Gruppe wählen")

        local function IsSelected(tagID)
            local tag = Cubby.TagForItem(itemID)
            return (tag and tag.id) == tagID
        end
        local function Select(tagID)
            Cubby.SetItemTag(itemID, tagID)
        end

        for _, tag in ipairs(SortedTags()) do
            root:CreateRadio(TagLabel(tag), IsSelected, Select, tag.id)
        end
        root:CreateRadio("Keine Gruppe", IsSelected, Select, nil)

        root:CreateDivider()
        root:CreateButton("Neue Gruppe ...", function()
            AskNewGroupName(itemID)
        end)
    end)
end

Cubby.PickTagColor = PickTagColor
Cubby.OpenGroupMenu = OpenGroupMenu
Cubby.OpenGroupsMenu = OpenGroupsMenu
Cubby.OpenItemMenu = OpenItemMenu
