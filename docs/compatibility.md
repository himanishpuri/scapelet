<!--
    SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
    SPDX-License-Identifier: GPL-3.0-or-later
-->

# Compatibility

## Icon tracking across Plasma versions

Scapelet reads desktop icon positions from Plasma-internal QML objects. Plasma
has no public API for this, so every link of the chain is optional: when one is
missing, the wallpaper shows open water instead of failing.

| Plasma | Icon tracking | Icon identity | How it was checked |
|---|---|---|---|
| 6.3.0 | works | delegate `name` | source read |
| 6.4.0 | works | delegate `name` | source read |
| 6.5.0 | works | delegate `name` | source read |
| 6.6.0 | works | delegate `name` | source read |
| 6.7.0 | works | delegate `display` | source read |
| 6.8.2 | works | delegate `display` | run on Fedora 44 |
| master (`5706f1dd`) | works | delegate `display` | source read |

Chain used:

- Icons: `WallpaperItem.parent.folderViewLayer.view.view.contentItem.children[*]`,
  keeping delegates with `blank === false`; identity from `display` (6.7 and
  later) or `name` (earlier).
- Drag state: `WallpaperItem.parent.folderViewLayer.view.dragging`.
- Widgets: `WallpaperItem.parent.appletsLayout.children[*]` that have an
  `applet` property; identity from `applet.plasmoid.id`, with the rectangle as
  a fallback.

Icon names never leave memory: they are not logged, drawn or exported.

## What cannot be done

These limits come from Plasma or Wayland, not from Scapelet. Each one needs a
change in Plasma before a wallpaper plugin can work around it.

- **No public icon API.** Icon positions come from Plasma-internal objects (see
  above). A Plasma release can rename them; the wallpaper then shows open water
  until Scapelet is updated. `docs/upstream-request.md` asks for a public API.
- **Icons only with Folder View.** Icons exist only with the Folder View
  desktop layout (`org.kde.plasma.folder`). With the "Desktop" layout the
  wallpaper shows open water and still reacts to widgets.
- **No islands on the lock screen.** The lock screen greeter has no desktop
  icons, so it shows open sea with the kayak and seabirds.
- **No idle pause.** Wayland returns `NotSupported` for `GetSessionIdleTime`,
  and there is no QML idle-time module. The lock pause and the display
  power-off cover the same case.
- **No drag preview under the pointer.** Plasma reports no pointer position
  during an icon drag, so the lifted icon's island thins to a shoal and nothing
  follows the pointer.
- **No settings shared across screens.** Settings are stored per containment,
  which means per screen and per activity. This is Plasma's design.
- Folder View list mode needs `inPanel`, so it cannot occur on the desktop.
  Only icon mode is supported, which is the only mode a desktop can use.

## Test matrix

| Setup | Result |
|---|---|
| One display, scale 1 (Fedora 44, Plasma 6.8.2, Wayland) | works: icons, events, pause modes, lock pause, power saver, picture export |
| Harness with `QT_SCALE_FACTOR=1.5` | works: islands stay under the icons, palms on the merged island |
| Lock screen greeter (`kscreenlocker_greet --testing`) | works: open sea with kayak and seabirds, no QML errors |
| Desktop widgets (analog clock) | works: land grows around the widget, one `added` and one `removed` event |
| Several monitors | not run (one display available) |
| Display scale other than 1 on the real desktop | not run |

## Diagnosing a broken chain

1. `make debug-on`
2. `journalctl --user -u plasma-plasmashell.service -f | grep scapelet:`
3. A broken chain logs `scapelet: icons=0 available=false missing=<link>`,
   where `<link>` is the first missing link (`host`, `parent`,
   `folderViewLayer`, `view`, `view.view` or `contentItem`).
4. `make debug-off` when done.
