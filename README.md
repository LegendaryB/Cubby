# Cubby

Bag addon for **WoW Forever**: all your bags in one window, organized into your own sections.

## Features

- All bags in a single window, with search by item name and group name
- **Groups** with their own color, optionally shown as a separate section in the window
- **Auto-sort rules:** assign whole item categories (e.g. "Trade Goods: Cloth") to a group
- **Sell protection** per group: protected items can't be sold to vendors
- Sections can be collapsed and reordered, and their headers show how many items they hold
- Item level and BoE labels, plus a marker for new items
- Options window for columns, scale and display settings

The in-game interface is currently in German.

## Installation

Copy the `Cubby` folder to `World of Warcraft\_forever_\Interface\AddOns\` and start the game.

## Usage

| Action | Result |
|---|---|
| Bag key | Open or close the window |
| Funnel icon | Create and edit groups |
| Gear icon | Options |
| Click a section header | Settings for that group |
| Drag an item onto a section | Assign the item to that group |
| Drag an item onto the ungrouped section | Remove its group |
| Alt + left-click an item | Pick a group from a list |

## Project structure

- `Cubby/` – core logic: groups, sell protection, sorting, hooks into Blizzard's bags, events
- `Cubby/UI/` – window, layout, item buttons, section headers, menus, options

The load order is defined in `Cubby/Cubby.toc`.

## License

[MIT](LICENSE)
