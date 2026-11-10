<!--
    SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
    SPDX-License-Identifier: GPL-3.0-or-later
-->

# Feature request draft: public API for wallpaper plugins to read desktop icon geometry

Product: plasma-desktop (Folder View containment) and libplasma (`WallpaperItem`).

## Use case

Wallpaper plugins can react to the desktop they decorate. Archipelago
(<https://github.com/himanishpuri/archipelago>) grows islands around desktop
icons, merges them when icons sit together and lets them sink when an icon is
moved or deleted. Other ideas in the same spirit: light that pools around
icons, a grid that avoids them, or a wallpaper that keeps its focal point clear
of icons.

## What a wallpaper has to do today

There is no public way to learn where the icons are. Archipelago walks
Plasma-internal QML objects:

- `WallpaperItem.parent.folderViewLayer.view.view.contentItem.children[*]`
  (the Folder View `GridView` delegates), filtered with the delegate property
  `blank`;
- the delegate property `display` (`name` before Plasma 6.7) to tell icons
  apart across moves;
- `folderViewLayer.view.dragging` to recognise a drag;
- `WallpaperItem.parent.appletsLayout.children[*].applet` for widgets.

All of these are implementation details. They have been stable from 6.3 to
master, but any refactoring can break every wallpaper that uses them.

## Proposal

`WallpaperItem` (or `ContainmentItem`) exposes a read-only list of the items
on the desktop, in wallpaper coordinates, plus a change signal:

```qml
// One entry per icon or widget.
readonly property list<var> desktopItems   // [{ rect, isDir, isWidget, dragging }]
signal desktopItemsChanged()
```

- `rect`: the item's geometry in the wallpaper's coordinates.
- `isDir` / `isWidget`: enough to vary the look without exposing file names.
- `dragging`: true while the item is being dragged.
- A stable opaque id per item would allow move animations; file names or URLs
  are not needed, which keeps the API privacy-neutral.

## Offer

I am happy to prepare a merge request for this if the maintainers agree on the
shape of the API.
