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
| `make install` / `make reload` | install to `~/.local/share/plasma/wallpapers` and restart plasmashell |
| `make debug-on` / `make debug-off` | journal logging of icon tracking and power state |
| `make rpm` | build the RPM in a Fedora container (see below) |

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
