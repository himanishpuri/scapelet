// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Window
import "../../package/contents/ui" as Archipelago

// Standalone renderer harness with draggable fake icons.
//   qml-qt6 tests/harness/Harness.qml [-- --snapshot /abs/path.png] [-- --maximized]
// Keys: A add icon, D remove last icon, Space toggle water animation.
Window {
    id: win

    width: 1280
    height: 800
    visible: true
    title: "Archipelago harness"
    color: "black"

    readonly property int cellW: 100
    readonly property int cellH: 110
    readonly property var args: Qt.application.arguments
    readonly property string snapshotPath: {
        const i = args.indexOf("--snapshot");
        return (i >= 0 && i + 1 < args.length) ? args[i + 1] : "";
    }
    readonly property bool snapshotMode: snapshotPath !== ""

    ListModel {
        id: icons
        ListElement { col: 0; row: 0 }
        ListElement { col: 0; row: 1 }
        ListElement { col: 0; row: 2 }
        ListElement { col: 1; row: 0 }
        ListElement { col: 5; row: 3 }
        ListElement { col: 8; row: 2 }
        ListElement { col: 8; row: 4 }
        ListElement { col: 11; row: 6 }
    }

    function publish() {
        const out = [];
        for (let i = 0; i < icons.count; ++i) {
            const it = icons.get(i);
            out.push({ x: it.col * cellW, y: it.row * cellH, w: cellW, h: cellH });
        }
        scene.iconRects = out;
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
                    icons.append({ col: c, row: r });
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
        if (snapshotMode) {
            snapshotTimer.start();
        } else {
            enableAnimation.start();
        }
    }

    Archipelago.Scene {
        id: scene
        anchors.fill: parent
        animateChanges: false
    }

    // Initial islands are instant; later changes animate.
    Timer {
        id: enableAnimation
        interval: 300
        onTriggered: scene.animateChanges = true
    }

    Timer {
        id: snapshotTimer
        interval: 1500
        onTriggered: win.contentItem.grabToImage(result => {
            result.saveToFile(win.snapshotPath);
            Qt.quit();
        })
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
                onReleased: {
                    const c = win.clamp(Math.round((icon.x - 26) / win.cellW), 0, Math.floor(win.width / win.cellW) - 1);
                    const r = win.clamp(Math.round((icon.y - 16) / win.cellH), 0, Math.floor(win.height / win.cellH) - 1);
                    icons.setProperty(icon.index, "col", c);
                    icons.setProperty(icon.index, "row", r);
                    icon.x = Qt.binding(() => icon.col * win.cellW + 26);
                    icon.y = Qt.binding(() => icon.row * win.cellH + 16);
                    win.publish();
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
                scene.running = !scene.running;
                event.accepted = true;
            }
        }
    }

    Text {
        id: fpsText
        property int lastFrames: 0
        property int fps: 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        color: "white"
        style: Text.Outline
        styleColor: "#202020"
        font.pixelSize: 18
        text: "fps " + fps + (scene.running ? "" : " (paused)")

        Timer {
            interval: 1000
            repeat: true
            running: true
            onTriggered: {
                fpsText.fps = scene.frameCount - fpsText.lastFrames;
                fpsText.lastFrames = scene.frameCount;
            }
        }
    }
}
