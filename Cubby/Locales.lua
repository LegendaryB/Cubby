-- Texts shown in the game. Cubby follows the client language: German clients get German,
-- every other client gets English. Code reads texts as L.KEY (local L = Cubby.L).
local _, Cubby = ...

local enUS = {
    -- Main window
    SORT_BAGS = "Sort bags",
    GROUPS = "Groups",
    OPTIONS = "Options",
    FREE_SLOTS = "Free: %d / %d",

    -- Groups
    NEW_GROUP = "New group ...",
    NEW_GROUP_PROMPT = "Name for the new group:",
    RENAME_PROMPT = "New name:",
    DELETE_CONFIRM = "Delete group \"%s\"? All items lose this group and with it any sell protection.",
    NO_GROUP = "No group",
    CHOOSE_GROUP = "Choose group",
    SELL_PROTECTION = "Sell protection",
    SHOW_AS_SECTION = "Show as section",
    AUTO_SORT = "Sort automatically",
    NO_ITEMS_IN_BAGS = "No items in your bags",
    RULE_OWNER = " (in: %s)",
    QUALITY_RULE = "Quality: %s",
    CHANGE_COLOR = "Change color ...",
    RENAME = "Rename ...",
    DELETE = "Delete ...",

    -- Item tooltip and buttons
    TOOLTIP_GROUP = "Group: %s",
    TOOLTIP_SELL_PROTECTED = " (sell protection)",
    TOOLTIP_AUTOMATIC = " (automatic)",
    BOE = "BoE",
    SELL_PROTECTED_MESSAGE = "Cubby: This item is protected from selling.",

    -- Sections
    DROP_INTO = "Drop into: %s",
    COLLAPSE = "Collapse",
    EXPAND = "Expand",
    DRAG_ITEMS_HERE = "Drag items here",
    SELL_PROTECTION_ON = "Sell protection: on",
    SELL_PROTECTION_OFF = "Sell protection: off",
    MOVE_UP = "Move section up",
    MOVE_DOWN = "Move section down",
    SELL_SECTION = "Sell everything in this section",
    SELL_SECTION_CONFIRM = "Sell %d items from \"%s\" for %s?\nOnly the last 12 can be bought back from the vendor.",
    NEW_ITEMS = "new",
    REAGENTS = "Reagents",
    KEYRING = "Keyring",

    -- Options
    OPTIONS_TITLE = "Cubby options",
    COLUMNS = "Columns",
    SCALE = "Scale",
    SHOW_ITEM_LEVEL = "Show item level",
    MARK_BOE = "Mark BoE items",
    SHOW_KEYRING = "Show keyring",
    COMBINE_FREE_SLOTS = "Combine free slots",
    SHOW_VALUE = "Show vendor value",
    MARK_UPGRADES = "Mark upgrades",
    VENDOR_VALUE = "Value: %s",
    LOCK_WINDOW = "Lock window",
    RESET_POSITION = "Reset position",

    -- Errors
    FALLBACK_ERROR = "Error, switching back to the default bags:",
}

local deDE = {
    SORT_BAGS = "Taschen sortieren",
    GROUPS = "Gruppen",
    OPTIONS = "Optionen",
    FREE_SLOTS = "Frei: %d / %d",

    NEW_GROUP = "Neue Gruppe ...",
    NEW_GROUP_PROMPT = "Name für die neue Gruppe:",
    RENAME_PROMPT = "Neuer Name:",
    DELETE_CONFIRM = "Gruppe \"%s\" löschen? Alle Items verlieren diese Gruppe und damit auch einen Verkaufsschutz.",
    NO_GROUP = "Keine Gruppe",
    CHOOSE_GROUP = "Gruppe wählen",
    SELL_PROTECTION = "Verkaufsschutz",
    SHOW_AS_SECTION = "Als Bereich anzeigen",
    AUTO_SORT = "Automatisch einsortieren",
    NO_ITEMS_IN_BAGS = "Keine Items in den Taschen",
    RULE_OWNER = " (in: %s)",
    QUALITY_RULE = "Qualität: %s",
    CHANGE_COLOR = "Farbe ändern ...",
    RENAME = "Umbenennen ...",
    DELETE = "Löschen ...",

    TOOLTIP_GROUP = "Gruppe: %s",
    TOOLTIP_SELL_PROTECTED = " (Verkaufsschutz)",
    TOOLTIP_AUTOMATIC = " (automatisch)",
    BOE = "BoE",
    SELL_PROTECTED_MESSAGE = "Cubby: Dieses Item hat Verkaufsschutz.",

    DROP_INTO = "Ablegen in: %s",
    COLLAPSE = "Einklappen",
    EXPAND = "Aufklappen",
    DRAG_ITEMS_HERE = "Items hierher ziehen",
    SELL_PROTECTION_ON = "Verkaufsschutz: an",
    SELL_PROTECTION_OFF = "Verkaufsschutz: aus",
    MOVE_UP = "Bereich nach oben",
    MOVE_DOWN = "Bereich nach unten",
    SELL_SECTION = "Alles in diesem Bereich verkaufen",
    SELL_SECTION_CONFIRM = "%d Items aus \"%s\" für %s verkaufen?\nNur die letzten 12 lassen sich beim Händler zurückkaufen.",
    NEW_ITEMS = "neu",
    REAGENTS = "Reagenzien",
    KEYRING = "Schlüsselbund",

    OPTIONS_TITLE = "Cubby-Optionen",
    COLUMNS = "Spalten",
    SCALE = "Größe",
    SHOW_ITEM_LEVEL = "Itemlevel anzeigen",
    MARK_BOE = "BoE markieren",
    SHOW_KEYRING = "Schlüsselbund anzeigen",
    COMBINE_FREE_SLOTS = "Freie Plätze bündeln",
    SHOW_VALUE = "Händlerwert anzeigen",
    MARK_UPGRADES = "Upgrades markieren",
    VENDOR_VALUE = "Wert: %s",
    LOCK_WINDOW = "Fenster festsetzen",
    RESET_POSITION = "Position zurücksetzen",

    FALLBACK_ERROR = "Fehler, zurück zu den Standardtaschen:",
}

-- A missing German text falls back to English, a missing key shows its own name instead of breaking.
setmetatable(enUS, { __index = function(_, key) return key end })
setmetatable(deDE, { __index = enUS })

Cubby.L = GetLocale() == "deDE" and deDE or enUS
