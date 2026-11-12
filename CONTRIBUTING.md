<!--
    SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
    SPDX-License-Identifier: GPL-3.0-or-later
-->

# Contributing

## Prerequisites

- KDE Plasma 6.3 or later
- `qt6-qtdeclarative-devel` (`qml-qt6`, `qmllint-qt6`, `qmltestrunner-qt6`)
- `qt6-qtshadertools` (`qsb-qt6`)
- `podman` or `docker`, only for `make rpm`

## Make targets

| Target | What it does |
|---|---|
| `make test` | unit tests (`tests/unit`) |
| `make scenario` | runs the four core events in the harness and compares them with `tests/harness/events.expected` |
| `make lint` | `qmllint` over all QML; fails on any warning. Plasma-internal names carry a `// qmllint disable` comment |
| `make snapshot` | renders the harness to `build/harness.png` |
| `make harness` | interactive harness with draggable fake icons |
| `make stats` | harness with ticks, presented frames and CPU share once a second (`ARGS=--paused` to check that a paused engine draws nothing) |
| `make gpu` | GPU render-engine share of plasmashell over 10 s |
| `make bench` | GPU time of one full-screen frame at full GPU speed: `make bench SCALE=3 ARGS="--theme city --time 20"`. Needs X11 or XWayland |
| `make same` | proves a change leaves the picture as it was: `make same REF=<other checkout> ARGS="--theme city --time 20"` compares one paused frame pixel by pixel |
| `make install` / `make reload` | install to `~/.local/share/plasma/wallpapers` and restart plasmashell |
| `make debug-on` / `make debug-off` | journal logging of icon tracking and power state |
| `make rpm` | build the RPM in a Fedora container (see below) |

## Measuring a theme

The share of the GPU a wallpaper uses (`make gpu`) says little about a shader:
the GPU clocks down under a light load, so a cheaper shader can show the same
share. `make bench` draws the theme several times larger than the screen
without vsync, which saturates the GPU, and prints the milliseconds one
full-screen frame costs at full speed. Choose `SCALE` so that fewer than 55
frames a second come out.

A change that is meant to save work must not change the picture. Keep a
checkout of the commit before the change, build its shaders, and run
`make same REF=<that checkout>` with several `--time` values and settings;
it must print `same pixels=0` each time.

On Intel GPUs with Mesa, `sh tools/simd.sh --theme <id>` shows how the driver
compiled the theme's shader. A shader with too many values alive at once is
run 8 pixels wide instead of 16, at about half the speed, without any
message. A large shader listed only as `SIMD8` has that problem.

## Building the RPM

`make rpm` packs `HEAD` with `git archive` and runs `rpmbuild` in a
`registry.fedoraproject.org/fedora:44` container, so commit your changes
first. The package lands in `dist/rpm/noarch/`.

With podman (the default):

```sh
make rpm
```

With Docker:

```sh
make rpm CONTAINER=docker
```

Both produce the same package. Docker runs the build as root, so the
recipe hands `dist/` back to your user when it is done.

## Code rules

- Every file starts with the SPDX header (`GPL-3.0-or-later`).
- Pure QML, JavaScript and GLSL; no C++ and no CMake ([why](docs/compatibility.md#why-there-is-no-c)).
- Use `console.info` for debug output: Fedora's logging rules drop
  `console.log`.
- Never log or draw icon names or other file names.
- Plasma-internal names are used only in `ui/IconProbe.qml`,
  `ui/WidgetProbe.qml` and the `onDesktop` check in `ui/main.qml`.

## Commits

Conventional prefixes: `feat:`, `fix:`, `perf:`, `refactor:`, `docs:`,
`chore:`; a scope is optional (`feat(beach): ...`).

## Themes

See [docs/themes.md](docs/themes.md).
