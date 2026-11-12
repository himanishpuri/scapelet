<!--
    SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
    SPDX-License-Identifier: GPL-3.0-or-later
-->

# Writing a theme

Scapelet is an environment engine with interchangeable themes. The engine
tracks the icons and widgets on the desktop, groups them into clusters, renders
an influence field around them and emits four core events. A theme turns that
into pictures. Beach (islands in a tropical sea), Meadow (clouds over
wind-swept grass), Forest (a clearing in a forest), City (a square in an old
town), Cosmos (nebulae and constellations) and Blueprint (a technical plan, the
minimal reference) ship with the plugin.

## Files

A theme is one directory plus one registry entry:

```
package/contents/themes/<id>/Main.qml     root item, type ThemeBase
package/contents/themes/<id>/*.frag       shaders, compiled to *.frag.qsb by `make shaders`
package/contents/themes/<id>/*            any other assets (SVG, JS)
package/contents/code/themes.js           add one entry to `list`
```

Nothing else changes: the settings page, the engine and the build pick the
theme up from the registry.

## Registry entry

```js
{
    id: "forest",                 // directory name under themes/
    name: "Forest",               // shown in the Theme combo box
    settings: [
        { key: "mushrooms", type: "bool", label: "Mushrooms", def: true },
        { key: "density", type: "int", label: "Tree density:", min: 1, max: 10, step: 1, def: 5 },
        { key: "season", type: "choice", label: "Season:", choices: ["Spring", "Autumn"], def: 0 }
    ]
}
```

Setting types:

| Type | Fields | Value |
|---|---|---|
| `int` | `min`, `max`, `step`, `def` | integer in `[min, max]` |
| `bool` | `def` | `true` or `false` |
| `choice` | `choices`, `def` | index into `choices` |

Values are stored as JSON in the `ThemeSettings` config entry. Invalid or
missing values fall back to `def`. Labels are plain English strings; Scapelet
is not translated.

## ThemeBase

`engine/ThemeBase.qml` is the interface. The engine creates the theme full
size, sets `env` and `settings`, and reads `accentColor`.

| Member | Kind | Meaning |
|---|---|---|
| `env` | input | the engine; see the table below |
| `settings` | input | this theme's settings, keys as declared in the registry |
| `iconAdded(source)` | event | a source appeared |
| `iconRemoved(source)` | event | a source disappeared |
| `iconsMoved(moves)` | event | sources changed position |
| `iconsGrouped(cluster)` | event | a cluster formed or grew |
| `tapped(x, y)` | event | a left click on empty desktop, in theme coordinates; only while "React to clicks" is on |
| `accentColor` | output | colour offered to Plasma's "accent colour from wallpaper" |

`env` members:

| Member | Meaning |
|---|---|
| `time` | seconds, wraps at 3769.911184 (2π·600); stops while paused |
| `running` | animation on or off |
| `field` | texture: `r` = narrow sum, `g` = wide sum of the influence of all sources |
| `noise` | tileable noise texture: `r`, `g` 2-octave noise (12 cells), `b` 8 cells; one tile spans 2048 px |
| `sources` | `[{ id, kind, x, y, w, h, lifted }]`; `kind` is `"icon"` or `"widget"` |
| `clusters` | `[{ id, members, size, x, y, w, h, cx, cy }]` |
| `spots` | `[{ x, y, w: 0, h: 0, cluster, seed }]`: inland points between close neighbours |
| `influenceRadius` | px, the user's "Area around each icon" |
| `appearDelay`, `disappearDelay`, `morphDuration` | ms, the user's timing settings |
| `animateChanges` | false at start-up; changes then apply instantly and no events fire |
| `hour`, `dayTint` | local hour 0..24 and a matching light colour |
| `renderScale` | pixels drawn per screen pixel along each axis, the user's "Render scale"; 1 unless the user lowered it |

## Core events

| Event | Payload | Beach | Meadow | Forest | City | Cosmos |
|---|---|---|---|---|---|---|
| `iconAdded` | `{ id, kind, x, y, w, h, lifted }` | sand appears | cloud gathers | clearing opens | square opens | star flares up |
| `iconsGrouped` | `{ id, members, size, x, y, w, h, cx, cy }` | island expands | clouds merge | clearings join | squares join | constellation forms |
| `iconRemoved` | as `iconAdded` | water returns | cloud dissolves | trees grow back | houses return | star collapses |
| `iconsMoved` | `[{ id, from: { x, y, w, h }, to: { x, y, w, h } }]` | coastline changes | cloud follows | clearing follows | square follows | constellation shifts |

`tapped` is not one of the four core events: it carries no source. Answer it
with something short that ends by itself; `engine/Ring.qml` (a spreading ring)
and `engine/Burst.qml` (sprites flying apart) are ready to create with
`createObject`. The harness clicks with `--tap <x>,<y>`.

## Rules

- Read the steady state from `env` (`sources`, `clusters`, `spots`, `field`);
  use events only for transitions. No events fire for sources that exist at
  start-up.
- Derive all motion from `env.time`, so it stops when the engine pauses. Use
  rates that are whole cycles per wrap (multiples of 1/600 Hz) so nothing jumps
  when `time` wraps.
- Never log or draw `source.id`: it contains file names.
- Use `engine/Roster.qml` for things that appear and disappear: it keeps one
  delegate per rectangle and lets it animate out before it is destroyed.
- Use `engine/FrameClock.qml` for sprites that must move at the display rate:
  it follows `env.time` but advances every frame while `active`. Enable
  `layer.enabled` on the full-screen shader while the clock runs.
- A shader whose picture is mostly still should not draw all of it on every
  tick. Use `engine/StillCache.qml`: one pass draws the whole picture once
  and marks the pixels that move, the pass that draws the frames copies the
  rest. City does this; see the comments in `StillCache.qml` and `city.frag`.
  Check with `make same` that the picture stays the same at many times.
- Put shaders next to `Main.qml` as `*.frag` and load them as
  `Qt.resolvedUrl("<name>.frag.qsb")`. Do not name a sampler `noise`; it stays
  empty. Beach uses `noiseTex`.
- Start every file with the SPDX header used in the rest of the project.

## Trying a theme

```sh
make harness                                   # T cycles themes, A/D add/remove, drag icons
qml-qt6 tests/harness/Harness.qml -- --theme <id>
qml-qt6 tests/harness/Harness.qml -- --theme <id> --script events
qml-qt6 tests/harness/Harness.qml -- --theme <id> --settings '{"<id>":{"key":1}}'
```

Then `make install && make reload` and pick the theme in the wallpaper
settings.

## Minimal example

`themes/blueprint/Main.qml` uses every part of the interface in about 100
lines: a shader that reads `env.field`, repeaters over `env.sources` and
`env.clusters`, and a label for each core event.
