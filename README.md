# Cubby

Bag addon for **WoW Forever**: all your bags in one window, organized into your own sections.

## Features

- All bags in a single window, with search that uses the game's own item search (the one the default bags use) and also finds group names
- **Groups** with their own color, optionally shown as a separate section in the window
- **Auto-sort rules:** assign whole item categories (e.g. "Trade Goods: Cloth") or qualities to a group
- **Rule editor** (group menu, "Edit rules..."): build conditions from quality, item level, required level, equipment slot, any item type, binding, name and vendor value, each optionally negated, combined with "all" or "any". If several groups match an item, the upper section wins; items you assign by hand always win
- **Rule from an item:** the item menu (Alt + left-click) can start a rule from the item you picked, and its tooltip shows the group it is in and why: assigned by hand, or which rule put it there
- **Item order inside a group:** per group, sort its items by quality, name, item level, type or vendor value. This only changes how the section shows them, nothing moves in your bags
- **Export and import:** copy one group or all of them (with their rules and assigned items) as text and paste it into another character or share it. Importing only adds: existing groups and assignments stay, a name clash gets a "(2)" suffix, and invalid entries are skipped
- **Sell protection** per group: protected items can't be sold to vendors
- **Sell section:** sell everything in a group at a vendor with one confirmation that shows the number of items and the total price
- Sections can be collapsed and reordered, and their headers show how many items they hold
- Item level and BoE labels, plus a marker for new items
- Optional vendor value per section and for all your bags, and the free-slot count turns yellow when your bags run low and red when they are nearly full
- Optionally, all empty slots are combined into a single slot with a counter instead of filling the window with empty squares
- **Bag bar** next to the search box: an icon per bag with its free slots; hovering one highlights that bag's slots, right-click excludes it from sorting (marked with a red cross)
- Options window for columns, scale and display settings

The interface follows the client language: German on German clients, English on all others.

## Installation

Download `Cubby-vX.Y.Z.zip` from the [latest release](https://github.com/LegendaryB/Cubby/releases/latest), extract it into `World of Warcraft\_forever_\Interface\AddOns\` and start the game.

## Releasing

1. Set `## Version` in `Cubby/Cubby.toc` to the new version and merge that into `main`.
2. Tag the commit and push the tag, e.g. `git tag v1.0.1 && git push origin v1.0.1`.

The [release workflow](.github/workflows/release.yml) checks that the tag matches the TOC version, builds the zip and publishes a GitHub release with the commit messages since the previous tag.

## Usage

| Action | Result |
|---|---|
| Bag key | Open or close the window |
| Funnel icon | Create and edit groups |
| Gear icon | Options |
| Click a section header | Settings for that group |
| Drag an item onto a section | Assign the item to that group |
| Drag an item onto the ungrouped section | Remove its group |
| Alt + left-click an item | Pick a group from a list, or start a rule from the item |
| Hover a bag icon | Highlight the slots of that bag |
| Drop a bag on a bag icon | Equip the bag in that slot |
| Drag a bag icon | Pick the bag up |

## Project structure

- `Cubby/` – core logic: groups, conditions, item order, export and import, sell protection, sorting, hooks into Blizzard's bags, events
- `Cubby/UI/` – window, layout, item buttons, section headers, menus, options, rule editor, export and import window

The load order is defined in `Cubby/Cubby.toc`.

## License

[MIT](LICENSE)
