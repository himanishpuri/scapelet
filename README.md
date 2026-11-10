# Archipelago

Archipelago is a KDE Plasma 6 wallpaper plugin that paints a stylized top-down
ocean. Sandy islands grow around your desktop icons, merge when icons sit close
together, and sink back into the sea when icons are moved or removed. Water,
swash and foam are animated with GLSL shaders, capped at a configurable frame
rate, and paused while a maximized or full-screen window covers the desktop.

## Requirements

- KDE Plasma 6 (developed and verified on Plasma 6.8.2)
- `qsb-qt6` (Qt Shader Tools) to compile the shaders
- For development: `qt6-qtdeclarative-devel` (provides `qml-qt6`,
  `qmllint-qt6` and `qmltestrunner-qt6`)

## Usage

```sh
make install   # compile shaders and install to ~/.local/share/plasma/wallpapers
make apply     # set Archipelago as the wallpaper on every desktop
make reload    # restart plasmashell to load new QML
make restore   # switch back to the default image wallpaper
make harness   # run the renderer standalone with draggable fake icons
make test      # run the unit tests
```

Settings are available under right-click on the desktop → Desktop and
Wallpaper → Wallpaper type: Archipelago.

## Icon tracking

Icon positions are read from the Folder View desktop containment through
Plasma-internal QML property names (verified on Plasma 6.8.2). All access is
confined to `package/contents/ui/IconProbe.qml`. If those internals change,
the wallpaper falls back to plain animated ocean.

## License

GPL-3.0-or-later. See `LICENSE`.
