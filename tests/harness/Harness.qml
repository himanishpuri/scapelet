// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import "../../package/contents/engine" as Env
import "../../package/contents/code/themes.js" as Themes

// Standalone renderer harness with draggable fake icons.
//   qml-qt6 tests/harness/Harness.qml [-- --snapshot /abs/path.png | --export /abs/path.png] [--maximized] [--paused]
//       [--theme <id>] [--settings '<json>'] [--hour <0..24>] [--script events] [--stats]
// Keys: A add icon, D remove last icon, Space toggle animation, T next theme,
//       W toggle a fake widget, H cycle the hour (wall clock, 6, 12, 19, 0), P next palette.
Window {
    id: win

    width: Number(arg("--width", "1280"))
    height: Number(arg("--height", "800"))
    visible: true
    title: "Scapelet harness"
    color: "black"

    readonly property int cellW: 100
    readonly property int cellH: 110
    readonly property var args: Qt.application.arguments
    function arg(name, fallback) {
        const i = args.indexOf(name);
        return (i >= 0 && i + 1 < args.length) ? args[i + 1] : fallback;
    }
    readonly property string snapshotPath: arg("--snapshot", "")
    readonly property string exportPath: arg("--export", "")
    readonly property string script: arg("--script", "")
    readonly property bool stats: args.indexOf("--stats") >= 0
    property int nextName: 9
    property int liftedIndex: -1
    property var widgets: []
    readonly property bool snapshotMode: snapshotPath !== ""
    property int swaps: 0
    onFrameSwapped: swaps += 1

    ListModel {
        id: icons
        ListElement { col: 0; row: 0; name: "n1" }
        ListElement { col: 0; row: 1; name: "n2" }
        ListElement { col: 0; row: 2; name: "n3" }
        ListElement { col: 1; row: 0; name: "n4" }
        ListElement { col: 5; row: 3; name: "n5" }
        ListElement { col: 8; row: 2; name: "n6" }
        ListElement { col: 8; row: 4; name: "n7" }
        ListElement { col: 11; row: 6; name: "n8" }
    }

    function publish() {
        const out = [];
        for (let i = 0; i < icons.count; ++i) {
            if (i === liftedIndex) {
                continue;
            }
            const it = icons.get(i);
            out.push({ id: "icon:" + it.name, kind: "icon", x: it.col * cellW, y: it.row * cellH, w: cellW, h: cellH });
        }
        engine.input = out.concat(win.widgets);
    }

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    function occupied(col, row) {
        for (let i = 0; i < icons.count; ++i) {
            const it = icons.get(i);
            if (it.col === col && it.row === row) {
                return true;
            }
        }
        return false;
    }

    function addIcon() {
        const cols = Math.floor(width / cellW);
        const rows = Math.floor(height / cellH);
        for (let r = 0; r < rows; ++r) {
            for (let c = 0; c < cols; ++c) {
                if (!occupied(c, r)) {
                    icons.append({ col: c, row: r, name: "n" + win.nextName++ });
                    publish();
                    return;
                }
            }
        }
    }

    function removeLast() {
        if (icons.count > 0) {
            icons.remove(icons.count - 1);
            publish();
        }
    }

    Component.onCompleted: {
        if (args.indexOf("--maximized") >= 0) {
            win.visibility = Window.Maximized;
        }
        publish();
        if (snapshotMode || exportPath !== "") {
            snapshotTimer.start();
        } else {
            enableAnimation.start();
        }
    }

    Env.Engine {
        id: engine
        anchors.fill: parent
        animateChanges: false
        running: win.args.indexOf("--paused") < 0
        theme: win.arg("--theme", "beach")
        themeSettingsJson: win.arg("--settings", "{}")
        hourOverride: Number(win.arg("--hour", "-1"))
        fps: Number(win.arg("--fps", "30"))
    }

    Connections {
        target: engine.themeItem
        function onIconAdded(s) { console.info("event: added " + s.id) }
        function onIconRemoved(s) { console.info("event: removed " + s.id) }
        function onIconsMoved(moves) { for (const m of moves) console.info("event: moved " + m.id) }
        function onIconsGrouped(c) { console.info("event: grouped size=" + c.size) }
    }

    // --script events: add next to the top-left group, lift and drop an icon, remove the added one.
    Timer {
        property int stepIndex: 0
        interval: 500
        repeat: true
        running: win.script === "events"
        onTriggered: {
            stepIndex += 1;
            if (stepIndex === 1) {
                icons.append({ col: 2, row: 0, name: "n" + win.nextName++ });
                win.publish();
            } else if (stepIndex === 2) {
                win.liftedIndex = 4;
                engine.dragging = true;
                win.publish();
            } else if (stepIndex === 3) {
                icons.setProperty(4, "col", 5);
                icons.setProperty(4, "row", 6);
                win.liftedIndex = -1;
                win.publish();
                engine.dragging = false;
            } else if (stepIndex === 4) {
                win.removeLast();
            } else {
                Qt.quit();
            }
        }
    }

    // Initial islands are instant; later changes animate.
    Timer {
        id: enableAnimation
        interval: 300
        onTriggered: engine.animateChanges = true
    }

    Timer {
        id: snapshotTimer
        interval: 1500
        onTriggered: {
            console.info("accent: " + engine.accentColor);
            if (win.exportPath !== "") {
                engine.exportImage(win.exportPath, ok => {
                    console.info("export: " + ok);
                    Qt.quit();
                });
                return;
            }
            win.contentItem.grabToImage(result => {
                result.saveToFile(win.snapshotPath);
                Qt.quit();
            });
        }
    }

    Repeater {
        model: icons
        delegate: Rectangle {
            id: icon
            required property int index
            required property int col
            required property int row

            width: 48
            height: 48
            radius: 10
            color: "#cc2f7de1"
            border.color: "white"
            border.width: 1
            x: col * win.cellW + 26
            y: row * win.cellH + 16

            MouseArea {
                anchors.fill: parent
                drag.target: parent
                onPressed: {
                    win.liftedIndex = icon.index;
                    engine.dragging = true;
                    win.publish();
                }
                onReleased: {
                    const c = win.clamp(Math.round((icon.x - 26) / win.cellW), 0, Math.floor(win.width / win.cellW) - 1);
                    const r = win.clamp(Math.round((icon.y - 16) / win.cellH), 0, Math.floor(win.height / win.cellH) - 1);
                    icons.setProperty(icon.index, "col", c);
                    icons.setProperty(icon.index, "row", r);
                    icon.x = Qt.binding(() => icon.col * win.cellW + 26);
                    icon.y = Qt.binding(() => icon.row * win.cellH + 16);
                    win.liftedIndex = -1;
                    win.publish();
                    engine.dragging = false;
                }
            }
        }
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_A) {
                win.addIcon();
                event.accepted = true;
            } else if (event.key === Qt.Key_D) {
                win.removeLast();
                event.accepted = true;
            } else if (event.key === Qt.Key_Space) {
                engine.running = !engine.running;
                event.accepted = true;
            } else if (event.key === Qt.Key_T) {
                engine.theme = Themes.list[(Themes.list.findIndex(t => t.id === engine.themeId) + 1) % Themes.list.length].id;
                event.accepted = true;
            } else if (event.key === Qt.Key_W) {
                win.widgets = win.widgets.length ? [] : [{ id: "widget:1", kind: "widget", x: 640, y: 420, w: 320, h: 220 }];
                win.publish();
                event.accepted = true;
            } else if (event.key === Qt.Key_P) {
                const spec = Themes.find(engine.themeId).settings.find(s => s.key === "palette");
                if (spec) {
                    engine.themeSettingsJson = Themes.store(engine.themeSettingsJson, engine.themeId, "palette",
                                                            (engine.themeSettings.palette + 1) % spec.choices.length);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_H) {
                const hours = [-1, 6, 12, 19, 0];
                engine.hourOverride = hours[(hours.indexOf(engine.hourOverride) + 1) % hours.length];
                event.accepted = true;
            }
        }
    }

    Text {
        id: fpsText
        visible: !win.stats
        property int lastFrames: 0
        property int fps: 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        color: "white"
        style: Text.Outline
        styleColor: "#202020"
        font.pixelSize: 18
        text: "fps " + fps + (engine.running ? "" : " (paused)")

        Timer {
            interval: 1000
            repeat: true
            running: true
            onTriggered: {
                fpsText.fps = engine.frameCount - fpsText.lastFrames;
                fpsText.lastFrames = engine.frameCount;
            }
        }
    }

    // --stats: once a second print engine ticks, presented frames and this process's CPU share.
    Timer {
        property int lastSwaps: 0
        property int lastTicks: 0
        property real lastCpu: -1
        interval: 1000
        repeat: true
        running: win.stats
        onTriggered: {
            let cpu = "n/a";
            try {
                const xhr = new XMLHttpRequest();
                xhr.open("GET", "file:///proc/self/stat", false);   // needs QML_XHR_ALLOW_FILE_READ=1
                xhr.send();
                const f = xhr.responseText.split(") ")[1].split(" ");
                const used = Number(f[11]) + Number(f[12]);          // utime + stime, 1/100 s
                if (lastCpu >= 0) {
                    cpu = (used - lastCpu) + "%";
                }
                lastCpu = used;
            } catch (e) {
            }
            console.info("stats: ticks=" + (engine.frameCount - lastTicks) + " swaps=" + (win.swaps - lastSwaps) + " cpu=" + cpu);
            lastTicks = engine.frameCount;
            lastSwaps = win.swaps;
        }
    }
}
