# Tien's Customizable Left Sidebar

Project Zomboid B42 mod (client only): reorder the left sidebar's buttons by drag and drop, hide them, set the spacing.
The live code is under `Contents/mods/TienCustomizableLeftSidebar/42/`. General engine findings (the sidebar's
internals, UI dispatch) go in `~/Zomboid/Workshop/ZomboidFixesB42/CLAUDE.md` ("UI building blocks learned for the
hotbar"); this file only holds the reasoning behind this mod.

The Lua source has no comments on purpose. Non-obvious reasoning lives here; update this file when it changes.

## Status

First implementation, not yet run in game. Only checked with luaparser (syntax and free globals). See "To verify".

## Files

- `client/TienCustomizableLeftSidebar_Core.lua`: settings and order maths.
  - File `Zomboid/Lua/TienCustomizableLeftSidebar.ini` (client, one layout for every save and server): `version=1`,
    `gap=15`, `editButton=full|small|hidden`, then one `button=<id>` per known button in order, then `hidden=<id>`.
    Ids of buttons not on the current sidebar stay in the list, so an SP layout and an MP layout (Admin, Safety...) share
    one order. Saved 500 ms after the last change (`MarkDirty` / `Tick`, ticked from the sidebar's prerender), and at
    once when the window closes.
  - `MoveTo(order, present, id, target)`: `target` is the 1-based slot among the **present** buttons; the id goes right
    before the present button now at that slot (after the last present one for the last slot), so absent ids keep their
    places in the full order.
  - `NAMES`: list names of the vanilla buttons (vanilla keys where one exists, ours for Map / Safety / User / Admin /
    War, which have no tooltip). `GAME_NOTES`: what to say when the game is hiding one.
- `client/TienCustomizableLeftSidebar_Sidebar.lua`: everything on `ISEquippedItem`.
  - Wrapped at `OnGameStart` (once), not at load, so the wrapper is the outermost one and runs after every other mod's
    `prerender` wrapper (the ZomboidFixesB42 admin hotbar moves its button and the war button there every frame).
    Wrapping a class method later still reaches the sidebar already built (Java looks methods up through the metatable).
  - Works on the sidebar that is `getPlayerData(n).equipped` and has `invBtn` (player 0 only; split screen players 1-3
    have only hands), not in the tutorial (vanilla moves Health there itself).
  - Discovery every frame after the inner prerender: every child that is an ISButton by metatable chain (subclasses
    count) except our own. A new button gets an id once: the field of the sidebar that holds it (smallest name if
    several), else `internal:<internal>`, else `button`, with `#2`... for duplicates; and `tclsNaturalY` = its y then
    (vanilla's positions on a new sidebar, since our layout has not run on it yet). A present id missing from the order
    is inserted after the nearest present button above it, else before the first present one: a mod's new button
    lands where its mod put it.
  - Layout (same frame, before the children draw): from the offhand slot's bottom, every button in `previewOrder or
    order` that the game shows (`isVisible()` after every other prerender) and the player did not hide is stacked with
    `gap`; anything else is **parked** at y = -100000 rather than hidden with `setVisible`, so the game's own visibility
    is never touched and is still readable next frame. Parked children are not drawn (outside the parent), never under
    the mouse, and never match vanilla's tooltip bounds. Buttons not in the order (mid-drag arrivals) go last. Then the
    Customize button, then `setHeight` to the last bottom.
  - Attachments moved with their button: `movableTooltip` (child, at the Furniture button's y), `radialIcon` (safety
    countdown), `movablePopup` / `mapPopup` (top level, placed by vanilla only at creation at the sidebar's absolute
    position + the button's).
  - The Customize button: created lazily in prerender (so a rebuilt sidebar gets one), sized like Inventory, icon
    `media/ui/Sidebar/<w>/TienCustomizableLeftSidebar_Off|On_<w>.png` (On while the window is open). Small = half
    height with `forceImageSize` at half scale; hidden = invisible and parked.
  - `render` wrapper: outline round the button the window's list hovers or drags (`Mod.highlightId`).
  - `onRightMouseUp`: context menu Hide <name> (button under the mouse), Show hidden buttons (if any), Customize
    sidebar... Vanilla's sidebar already swallowed right-clicks (ISUIElement's empty `onRightMouseUp` returns nil, which
    Java counts as consumed), so this takes nothing from the world menu.
  - `Reset`: present buttons by `tclsNaturalY`, nothing hidden, gap 15, full Customize button.
- `client/TienCustomizableLeftSidebar_Editor.lua`: the window (`ISCollapsableWindow`, not resizable, sized to its
  rows up to the screen height minus 300, then the list scrolls).
  - List: own `ISPanel` with `addScrollBars`, rows drawn in content coordinates (`getMouseY()` and the mouse handlers'
    y are content coordinates too), stencil while drawing. Row: grip, the button's live `image` with its
    `textureColor` (safety is tinted), name (Medium, shortened with ...), a note (Hidden / the game's reason), eye
    (`media/ui/foraging/eyeconOn|Off.png`).
  - Drag: press on a row, start past 5 px (`setCapture(true)`), snapshot of the rows and the order; each frame the
    target slot = rounded (mouse y - grab offset) / row height; `Mod.previewOrder` follows it so the sidebar moves live;
    auto-scroll within 24 px of the list's edges; drop commits `MoveTo`. Releasing outside the list (or the mouse button found up in
    any frame) also drops. Clicking the eye toggles hidden, no drag.
  - Below: Space between buttons (`ISSliderPanel` 0..40, its radio tooltip off), Customize button combo, a tip line,
    Show all / Reset (with an `ISModalDialog` confirm) / Close.
- `client/TienCustomizableLeftSidebar_Keys.lua`: vanilla key binding `TCLS Customize` in section `[Customizable
  Sidebar]`, unbound by default (same pattern as TienLastSeenWhere).
- Translations: `shared/Translate/EN/IG_UI.json` (`IGUI_TienCustomizableLeftSidebar_*`), `UI.json` (key binding labels).
- `scripts/make_art.py`: the Customize icon (three rows, the middle one pulled out as if dragged, and a pencil; drawn,
  not composed from vanilla icons, which would repeat the buttons right above it), icon, poster, preview.

## To verify in game

- Layout with every combination: SP, MP as player / admin, `-debug` (Debug + ARF buttons), PVP safety on/off, a war,
  sidebar size changes (rebuild), the tutorial untouched.
- The Furniture popup, Map popup and safety countdown follow their buttons; Health still shakes when hurt.
- ZomboidFixesB42's hotbar button and TienLastSeenWhere's button are picked up with their names and land in place.
- Drag feel (threshold, auto-scroll, drop outside), eye clicks, right-click menu, combo and slider, Reset.
- That the first discovery frame really sees vanilla positions (no flicker on game start).

## Decisions

- Its own mod (the user's choice), client only, no sandbox option: it changes nothing but the player's own screen.
- One layout per computer, not per server.
- Drag and drop in a window (the user's choice), with a live preview on the sidebar. The hand slots stay fixed:
  `getDraggedEquippableItems` decides main / off / both hands from their relative positions.
