-- Cubby: alle Taschen in einem Fenster.
-- Ersetzt nur die Anzeige. Oeffnen/Schliessen laeuft weiter ueber Blizzards Taschenlogik
-- (Tasten, Briefkasten, Haendler usw. funktionieren also wie gewohnt).
--
-- Alle Dateien teilen sich ueber "..." den Namensraum Cubby. Die Reihenfolge in Cubby.toc ist die
-- Ladereihenfolge: Werte aus frueheren Dateien duerfen oben in einer Datei zwischengespeichert werden,
-- Funktionen aus spaeteren Dateien werden erst beim Aufruf ueber Cubby.<Name> geholt.
local _, Cubby = ...

Cubby.DEFAULTS = {
    columns = 12,
    scale = 1,
    showItemLevel = true,
    showBoE = true,
    showKeyring = true,
    combineFreeSlots = true,
    locked = false,
}

-- Masse in Pixeln
Cubby.SLOT, Cubby.GAP, Cubby.PAD = 37, 4, 10
Cubby.HEADER_H, Cubby.FOOTER_H, Cubby.SECTION_H = 58, 28, 18
Cubby.EMPTY_SECTION_H = 24

local BagIndex = Enum.BagIndex
local NUM_BAGS = Constants.InventoryConstants.NumBagSlots
local NUM_REAGENT_BAGS = Constants.InventoryConstants.NumReagentBagSlots or 0
Cubby.KEYRING_BAG = BagIndex.Keyring
Cubby.REAGENT_BAG = NUM_REAGENT_BAGS > 0 and BagIndex.ReagentBag or nil

-- Cubby.db: die gespeicherten Einstellungen (CubbyDB), gesetzt beim Einloggen in Events.lua.

-- Laufzeit-Zustand, den mehrere Dateien teilen
Cubby.state = {
    searchText = "",
    needLayout = true,     -- beim naechsten Aktualisieren auf jeden Fall neu anordnen
    softLayout = false,    -- Items haben sich geaendert: neu anordnen, sobald die Maus nicht mehr ueber den Items ist
    merchantOpen = false,
    failed = false,        -- nach einem Fehler laufen wieder Blizzards Taschen
}

-- Die gerade angezeigten Item-Buttons in Anzeigereihenfolge; das Layout fuellt die Liste.
Cubby.active = {}

function Cubby.Print(msg)
    print("|cff33ff99Cubby|r: " .. msg)
end

function Cubby.ErrorHandler(err)
    return tostring(err) .. "\n" .. (debugstack and debugstack(2, 12, 0) or "")
end

-- Der Schluesselbund hat eine eigene Groessenabfrage (so macht es auch Blizzards Code).
function Cubby.NumSlots(bag)
    if bag == Cubby.KEYRING_BAG and GetKeyRingSize then
        return GetKeyRingSize() or 0
    end
    return C_Container.GetContainerNumSlots(bag) or 0
end

-- Rucksack und die normalen Taschen
function Cubby.MainBags()
    local bags = {}
    for bag = BagIndex.Backpack, NUM_BAGS do
        bags[#bags + 1] = bag
    end
    return bags
end

-- Taschen, deren Items einer Gruppe angehoeren koennen: die normalen plus die Reagenzientasche
function Cubby.TaggableBags()
    local bags = Cubby.MainBags()
    if Cubby.REAGENT_BAG then
        bags[#bags + 1] = Cubby.REAGENT_BAG
    end
    return bags
end
