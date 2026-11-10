# SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
ID      := io.github.himanishpuri.archipelago
VERSION := 0.1.0
QSB     ?= qsb-qt6
PKG     := package
DEST    := $(HOME)/.local/share/plasma/wallpapers/$(ID)
SHADERS := $(wildcard $(PKG)/contents/shaders/*.frag $(PKG)/contents/themes/*/*.frag)
QSBS    := $(SHADERS:.frag=.frag.qsb)
DBUS    := qdbus-qt6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript

.PHONY: all shaders install uninstall reload apply restore debug-on debug-off harness snapshot scenario test lint dist clean

all: shaders

shaders: $(QSBS)

%.frag.qsb: %.frag
	$(QSB) --qt6 -o $@ $<

install: shaders
	@if [ -d "$(DEST)" ]; then \
		kpackagetool6 --type Plasma/Wallpaper --upgrade $(PKG); \
	else \
		kpackagetool6 --type Plasma/Wallpaper --install $(PKG); \
	fi

uninstall:
	kpackagetool6 --type Plasma/Wallpaper --remove $(ID)

reload:
	systemctl --user restart plasma-plasmashell.service

apply:
	$(DBUS) 'var ds = desktops(); for (var i = 0; i < ds.length; ++i) { ds[i].wallpaperPlugin = "$(ID)"; }'

restore:
	$(DBUS) 'var ds = desktops(); for (var i = 0; i < ds.length; ++i) { ds[i].wallpaperPlugin = "org.kde.image"; }'

debug-on:
	$(DBUS) 'var ds = desktops(); for (var i = 0; i < ds.length; ++i) { ds[i].currentConfigGroup = ["Wallpaper", "$(ID)", "General"]; ds[i].writeConfig("DebugLog", true); }'

debug-off:
	$(DBUS) 'var ds = desktops(); for (var i = 0; i < ds.length; ++i) { ds[i].currentConfigGroup = ["Wallpaper", "$(ID)", "General"]; ds[i].writeConfig("DebugLog", false); }'

harness: shaders
	qml-qt6 tests/harness/Harness.qml

snapshot: shaders
	mkdir -p build
	qml-qt6 tests/harness/Harness.qml -- --snapshot $(CURDIR)/build/harness.png

scenario: shaders
	QT_FORCE_STDERR_LOGGING=1 qml-qt6 tests/harness/Harness.qml -- --script events 2>&1 | grep -o 'event: .*' | diff - tests/harness/events.expected

test:
	QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -input tests/unit

lint:
	-qmllint-qt6 $(PKG)/contents/ui/*.qml $(PKG)/contents/engine/*.qml $(PKG)/contents/themes/*/*.qml tests/harness/*.qml tests/unit/*.qml

dist: shaders
	mkdir -p dist
	tar -czf dist/$(ID)-$(VERSION).tar.gz -C $(PKG) .

clean:
	rm -f $(QSBS)
	rm -rf build dist
