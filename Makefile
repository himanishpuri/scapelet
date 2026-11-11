# SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
ID      := io.github.himanishpuri.scapelet
VERSION := 0.5.0
QSB     ?= qsb-qt6
PKG     := package
DEST    := $(HOME)/.local/share/plasma/wallpapers/$(ID)
SHADERS := $(wildcard $(PKG)/contents/shaders/*.frag $(PKG)/contents/themes/*/*.frag)
QSBS    := $(SHADERS:.frag=.frag.qsb)
# Container engine for `make rpm`: podman (default) or docker.
CONTAINER ?= podman
# Docker runs as root, so hand the RPMs back to the calling user. Rootless podman already maps root to this user.
CHOWN   := $(if $(filter docker,$(notdir $(CONTAINER))),&& chown -R $(shell id -u):$(shell id -g) /src/dist,)
DBUS    := qdbus-qt6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript

.PHONY: all shaders install uninstall reload apply restore debug-on debug-off harness snapshot scenario stats gpu test lint dist clean srctar rpm

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

stats: shaders
	QT_FORCE_STDERR_LOGGING=1 QML_XHR_ALLOW_FILE_READ=1 qml-qt6 tests/harness/Harness.qml -- --stats --maximized $(ARGS) 2>&1 | grep --line-buffered 'stats:'

gpu:
	sh tools/gpu-usage.sh

test:
	QT_QPA_PLATFORM=offscreen qmltestrunner-qt6 -input tests/unit

lint:
	qmllint-qt6 --max-warnings 0 $(PKG)/contents/ui/*.qml $(PKG)/contents/engine/*.qml $(PKG)/contents/themes/*/*.qml tests/harness/*.qml tests/unit/*.qml

dist: shaders
	mkdir -p dist
	tar -czf dist/$(ID)-$(VERSION).tar.gz -C $(PKG) .

srctar:
	mkdir -p dist
	git archive --prefix=scapelet-$(VERSION)/ -o dist/scapelet-$(VERSION).tar.gz HEAD

rpm: srctar
	$(CONTAINER) run --rm --security-opt label=disable -v $(CURDIR):/src -e QT_QPA_PLATFORM=offscreen registry.fedoraproject.org/fedora:44 sh -c \
		'dnf -y -q --setopt=install_weak_deps=False --disablerepo=fedora-cisco-openh264 install rpm-build make qt6-qtshadertools && rpmbuild -bb --define "_sourcedir /src/dist" --define "_rpmdir /src/dist/rpm" /src/packaging/plasma-wallpaper-scapelet.spec $(CHOWN)'

clean:
	rm -f $(QSBS)
	rm -rf build dist
