// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtTest
import "../../package/contents/engine" as Env

Item {
    id: root
    width: 400
    height: 300

    Env.Engine {
        id: engine
        anchors.fill: parent
        theme: "blueprint"
        animateChanges: false
    }

    SignalSpy {
        id: spy
        target: engine.themeItem
        signalName: "tapped"
    }

    TestCase {
        name: "Tap"
        when: windowShown

        function init() {
            engine.running = true;
            spy.clear();
        }

        function test_tap_reaches_theme() {
            verify(engine.themeItem !== null);
            engine.tap(120, 80);
            compare(spy.count, 1);
            compare(spy.signalArguments[0][0], 120);
            compare(spy.signalArguments[0][1], 80);
        }

        function test_no_tap_while_paused() {
            engine.running = false;
            engine.tap(120, 80);
            compare(spy.count, 0);
        }
    }
}
