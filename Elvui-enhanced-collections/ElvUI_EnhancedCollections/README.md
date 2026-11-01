# ElvUI Enhanced Collections

A clean ElvUI skin for **Whitemane / Rebuffed's Collections window**. Browse your mounts, companions, toys, heirlooms and appearances with consistent typography, charcoal panels and subtle selection accents.

**Author:** Mora  
**Version:** 1.1.0  
**Client interface:** 30300 — Whitemane / Rebuffed

## Features

- Consistent Expressway typography, with configurable font, size and outline.
- Charcoal panels, thin borders and a separate title bar.
- Full-width navigation with an accent underline for the selected tab.
- Matching search fields, filters, buttons, counters and progress bars.
- Clear selection states and readable uncollected entries.
- Colours that follow your current ElvUI accent.

| Collection | Styling |
| --- | --- |
| Mounts | Mount list, selection, counter, model panel, descriptions and preview controls. |
| Companions | Companion list, selection, counter, model panel and summon controls. |
| Toys | Subtle item cards, flat icon borders, readable labels and matching paging controls. |
| Heirlooms | Item cards, category headings, class filter and dynamically generated pages. |
| Appearances | Model tiles, Items/Sets tabs, set list, details and filter menus. |

Collected and uncollected appearances use different neutral borders. Unusable collected appearances retain a red border, while the client's model dimming, favourites, cooldowns, new-item markers and transmog indicators remain intact.

## Requirements

- The **Whitemane / Rebuffed Wrath client** with its custom Collections interface.
- **ElvUI**, using a version compatible with that client.

**ElvUI Enhanced** and **ElvUI Project Zidras** are optional. This companion skin can run alongside them; neither is required or replaced.

This addon targets Whitemane / Rebuffed's custom interface. Compatibility with retail WoW, Blizzard Classic or other private-server clients has not been established.

## Installation

1. Close World of Warcraft.
2. Copy the `ElvUI_EnhancedCollections` folder into your client's `Interface\AddOns` directory.
3. Confirm that the folder structure looks like this:

   ```text
   Interface/
   └── AddOns/
       └── ElvUI_EnhancedCollections/
           ├── ElvUI_EnhancedCollections.toc
           ├── Core.lua
           ├── Skin.lua
           ├── Options.lua
           └── README.md
   ```

4. Launch the game and enable **ElvUI Enhanced Collections** in the AddOns list.
5. Open Collections through the micro menu or type `/collections`.

If you download the repository as a ZIP, locate the addon folder inside it. The `.toc` file must sit directly inside `Interface\AddOns\ElvUI_EnhancedCollections`, without an extra nested folder.

## Configuration

Open **ElvUI → Collections**, or type:

```text
/eccollections
```

| Setting | Description |
| --- | --- |
| Enable skin | Enable or disable the skin. Requires a UI reload. |
| Font | Choose a registered font. Defaults to Expressway. |
| Base font size | Adjust text size from 10 to 16. |
| Font outline | Choose no outline, outline or thick outline. |
| Panel opacity | Adjust panel opacity from 75% to 100%. |
| Uncollected icon brightness | Adjust how visible uncollected toy and heirloom icons appear. |
| Refresh skin | Reapply the current styling. |

Settings are saved per ElvUI profile. ElvUI's master **Blizzard Skins** toggle must be enabled when the addon starts.

## Scope and compatibility

This is a presentation addon. Collection data, model cameras, lighting, sorting, filters, summoning, toy use, heirloom creation and transmog actions remain controlled by the client.

The shared Appearances panel also receives the skin when the client moves it into the transmogrifier window. Styling the separate transmogrifier window's outer frame is outside this release's scope, and that NPC interface has not been tested live.

The skin adds no `OnUpdate` handler, repeating timer, inventory scan or collection-data fetch. It applies decoration through the client's existing UI refreshes. No FPS improvement is claimed.

## Validation

- All five Collections tabs were visually inspected in-game at **1920×1080**.
- Live checks included mount and companion previews, Toys and Heirlooms paging, appearance models, set selection, filter menus and tab sizing after clicks.
- **18 Lua 5.1 regression checks** passed, covering skin initialization, recycled controls, native action callbacks, cooldown and state preservation, menu restoration, settings and repeated refreshes.

Summoning, toy use, heirloom creation and paid transmog application were not executed on the live character during verification. Original action functions were exercised in the Lua test environment. Other resolutions and client revisions may require adjustments.

## Troubleshooting

**The addon does not appear in the AddOns list**  
Check the folder structure above, then restart the client.

**The Collections window is still unskinned**  
Confirm that ElvUI, its master Blizzard Skins toggle and this addon's **Enable skin** option are enabled. Reload the UI with `/reload`.

**A font or panel looks wrong after a client update**  
Try **Refresh skin** in the Collections settings. If the issue persists, report the affected tab, reproduction steps, your client and ElvUI versions, and any Lua error text. A screenshot helps with layout issues.

## Updating or removing

To update, close the game and replace only the `ElvUI_EnhancedCollections` addon folder with the new version.

To restore the original Collections appearance, disable **ElvUI Enhanced Collections** and reload the UI. ElvUI profile settings are retained.

## Changelog

### 1.1.0

- Refined panel contrast, text colours, button sizes and description wrapping.
- Added full-width navigation and accent underlines.
- Added subtle cards for Toys and Heirlooms.
- Replaced bright collected-appearance borders with quieter neutral borders.
- Removed remaining decorative panel overlays.
- Kept Items/Sets tab sizes consistent after native click handling.
- Matched filter-menu text to the skin and restored its original style when closed.

### 1.0.1

- Fixed the `Font not set` error that interrupted skin initialization.
- Initialized dropdown-arrow fonts before assigning text.
- Marked installation complete only after styling and hook registration succeeded.

## Credits

- **Mora** — addon author.
- **ElvUI contributors** — the UI framework and skinning helpers.
- **Whitemane / Rebuffed developers** — the custom Collections interface and its functionality.

---

Created by **Mora**.
