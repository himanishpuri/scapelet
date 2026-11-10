// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.plasma.workspace.dbus as DBus

// Session state from D-Bus: screen locked, running on battery, active power profile.
// A missing service leaves the defaults (not locked, not on battery, no profile).
Item {
    id: monitor
    visible: false

    property bool debug: false
    property bool locked: false
    property bool onBattery: false
    property string profile: ""

    onLockedChanged: report()
    onOnBatteryChanged: report()
    onProfileChanged: report()

    function report() {
        if (debug) {
            console.info("scapelet: power locked=" + locked + " battery=" + onBattery + " profile=" + profile);
        }
    }

    // Some replies and signal arguments arrive wrapped as { value: ... }.
    function unwrap(v) {
        return (v !== null && typeof v === "object" && "value" in v) ? v.value : v;
    }

    function ask(service, path, iface, member, apply) {
        const reply = DBus.SessionBus.asyncCall({ service: service, path: path, iface: iface, member: member });
        reply.finished.connect(() => {
            if (!reply.isError) {
                apply(monitor.unwrap(reply.value));
            }
            reply.destroy();
        });
    }

    function refresh() {
        ask("org.freedesktop.ScreenSaver", "/ScreenSaver", "org.freedesktop.ScreenSaver", "GetActive",
            v => monitor.locked = v === true);
        ask("org.freedesktop.PowerManagement", "/org/freedesktop/PowerManagement", "org.freedesktop.PowerManagement", "GetPowerSaveStatus",
            v => monitor.onBattery = v === true);
        ask("org.kde.Solid.PowerManagement", "/org/kde/Solid/PowerManagement/Actions/PowerProfile",
            "org.kde.Solid.PowerManagement.Actions.PowerProfile", "currentProfile",
            v => monitor.profile = String(v ?? ""));
    }

    Component.onCompleted: refresh()

    // Safety net for a missed signal.
    Timer { interval: 60000; repeat: true; running: true; onTriggered: monitor.refresh() }

    DBus.SignalWatcher {
        busType: DBus.BusType.Session
        service: "org.freedesktop.ScreenSaver"
        path: "/ScreenSaver"
        iface: "org.freedesktop.ScreenSaver"
        function dbusActiveChanged(active) {
            monitor.locked = monitor.unwrap(active) === true;
        }
    }

    DBus.SignalWatcher {
        busType: DBus.BusType.Session
        service: "org.freedesktop.PowerManagement"
        path: "/org/freedesktop/PowerManagement"
        iface: "org.freedesktop.PowerManagement"
        function dbusPowerSaveStatusChanged(on) {
            monitor.onBattery = monitor.unwrap(on) === true;
        }
    }

    DBus.SignalWatcher {
        busType: DBus.BusType.Session
        service: "org.kde.Solid.PowerManagement"
        path: "/org/kde/Solid/PowerManagement/Actions/PowerProfile"
        iface: "org.kde.Solid.PowerManagement.Actions.PowerProfile"
        function dbuscurrentProfileChanged(name) {
            monitor.profile = String(monitor.unwrap(name) ?? "");
        }
    }
}
