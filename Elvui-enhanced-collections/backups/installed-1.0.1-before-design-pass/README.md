# ElvUI Enhanced Collections 1.0.1

An independent ElvUI companion skin for Whitemane's Rebuffed Collections window.
It works alongside ElvUI Enhanced and Project Zidras; neither is replaced or
edited. ElvUI is required. This addon targets the inspected Rebuffed Collections
interface, not retail WoW's Collections addon.

## Appearance

- Charcoal panels with thin borders and ElvUI's current accent colour.
- Expressway text, including list rows that reset their fonts while scrolling.
- Matching action buttons, search fields, filters, tabs and progress bars.
- Mounts and companions: list, selection, counters, model pane and its controls.
- Toys and heirlooms: flat icon borders and readable uncollected labels/icons.
- Appearances: item-model tile borders, Items/Sets tabs, set list and details.
- Collected, uncollected and unusable appearances keep distinct border colours.
- Favourites, new-item indicators, cooldowns and pending-transmog indicators
  retain their client-controlled states.
- Collections filter menus receive the skin while open. Their original styling
  is restored when closed, so other users of the shared menu remain unaffected.

The existing models, lighting, camera movement, item ordering, filters, collection
counts and item actions stay controlled by Whitemane. The shared Appearances
pane also retains this skin when the client moves it to the transmogrifier.
The separate transmogrifier window's outer frame is outside this release's scope.

## Install or remove

1. Fully close WoW.
2. Extract the ZIP into your client's `Interface\AddOns` directory.
3. Verify the path is
   `Interface\AddOns\ElvUI_EnhancedCollections\ElvUI_EnhancedCollections.toc`.
4. Start the game and enable **ElvUI Enhanced Collections** in the AddOns list.
5. Open Collections normally with its micro-menu button or `/collections`.

To remove the skin, disable only **ElvUI Enhanced Collections** and reload or
restart. The original Collections interface returns. You do not need to remove
ElvUI Enhanced or Project Zidras.

No client files were modified during development. Install the new addon manually;
do not replace your ElvUI, ElvUI Enhanced, Project Zidras or client archives.

## Settings

Open **ElvUI > Collections**, or type `/eccollections`.

- Enable skin: changing this asks for a reload.
- Font, base font size and outline.
- Panel opacity.
- Uncollected icon brightness.
- Refresh skin.

Settings are saved inside the active ElvUI profile under `enhancedCollections`.
The skin follows ElvUI's accent colour. ElvUI's master Blizzard-skins toggle is
respected at startup.

## Validation and limits

Eighteen checks passed in Lua 5.1 using the client's actual Collections XML,
selected original collection/action functions, its shared menu implementation,
and the installed ElvUI button-skin function in a mocked WoW UI environment.
Checks cover all five areas, recycled rows, newly allocated heirloom controls,
collection actions, cooldown/state preservation, native tab changes, scoped menu
restoration, settings, combat-deferred installation and repeated refreshes.

The skin adds no OnUpdate handler, repeating timer, world-frame scan, inventory
scan or collection-data fetch. Decoration runs on opening/configuration and the
client's existing list/page refreshes.

**In-game rendering and interaction have not been validated.** The live client
was kept read-only, so this is a first release for manual installation and an
in-game check. Client patches that rename frames can require an updated skin.

Version 1.0.1 fixes the in-game "Font not set" failure that stopped the initial
skin pass at the first newly created dropdown arrow. New font strings now receive
a font before text is assigned. Installation is marked complete only after all
areas are styled and their refresh hooks have been registered.
