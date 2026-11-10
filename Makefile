# SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
ID      := io.github.himanishpuri.archipelago
VERSION := 0.1.0
QSB     ?= qsb-qt6
PKG     := package
DEST    := $(HOME)/.local/share/plasma/wallpapers/$(ID)
SHADERS := $(wildcard $(PKG)/contents/shaders/*.frag $(PKG)/contents/themes/*/*.frag)
QSBS    := $(SHADERS:.frag=.frag.qsb)
DOMAIN   := plasma_wallpaper_$(ID)
I18N_SRC := $(wildcard $(PKG)/contents/ui/*.qml) $(PKG)/contents/code/themes.js
MOS      := $(patsubst po/%.po,$(PKG)/contents/locale/%/LC_MESSAGES/$(DOMAIN).mo,$(wildcard po/*.po))
DBUS    := qdbus-qt6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript

.PHONY: all shaders install uninstall reload apply restore debug-on debug-off harness snapshot scenario stats gpu test lint dist clean pot mo srctar rpm

all: shaders

shaders: $(QSBS)

%.frag.qsb: %.frag
	$(QSB) --qt6 -o $@ $<

install: shaders mo
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

pot:
	mkdir -p po
	xgettext --from-code=UTF-8 -L JavaScript -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -kN_:1 \
		--package-name=archipelago --package-version=$(VERSION) --msgid-bugs-address=himanishpuri2203@gmail.com \
		-o po/$(DOMAIN).pot $(I18N_SRC)

mo: $(MOS)

$(PKG)/contents/locale/%/LC_MESSAGES/$(DOMAIN).mo: po/%.po
	mkdir -p $(dir $@)
	msgfmt -o $@ $<

harness: shaders
	qml-qt6 tests/harness/Harness.qml

snapshot: shaders
	mkdir -p build
	qml-qt6 tests/harness/Harness.qml -- --snapshot $(CURDIR)/build/harness.png

scenario: shaders
	QT_FORCE_STDERR_LOGGING=1 qml-qt6 tests/harness/Harness.qml -- --script events 2>&1 | grep -o 'event: .*' | diff - tests/harness/events.expected

stats: shaders
	QT_FORCE_STDERR_LOGGING=1 QML_XHR_ALLOW_FILE_READ=1 qml-qt6 tests/harness/Harness.qml -- --stats --maximized $(ARGS) 2>&1 | grep --line-buffered 'stats:'

gpu:
	sh tools/gpu-usage.sh

test:
	QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -input tests/unit

lint:
	-qmllint-qt6 $(PKG)/contents/ui/*.qml $(PKG)/contents/engine/*.qml $(PKG)/contents/themes/*/*.qml tests/harness/*.qml tests/unit/*.qml

dist: shaders mo
	mkdir -p dist
	tar -czf dist/$(ID)-$(VERSION).tar.gz -C $(PKG) .

srctar:
	mkdir -p dist
	git archive --prefix=archipelago-$(VERSION)/ -o dist/archipelago-$(VERSION).tar.gz HEAD

rpm: srctar
	podman run --rm --security-opt label=disable -v $(CURDIR):/src -e QT_QPA_PLATFORM=offscreen registry.fedoraproject.org/fedora:44 sh -c \
		'dnf -y -q install rpm-build make gettext qt6-qtshadertools && rpmbuild -bb --define "_sourcedir /src/dist" --define "_rpmdir /src/dist/rpm" /src/packaging/plasma-wallpaper-archipelago.spec'

clean:
	rm -f $(QSBS)
	rm -rf build dist
	rm -rf $(PKG)/contents/locale
