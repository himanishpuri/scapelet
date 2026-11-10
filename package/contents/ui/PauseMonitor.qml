// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import org.kde.taskmanager as TaskManager
import org.kde.kwindowsystem

// covered === true while a non-minimized maximized or full-screen window is on
// this screen, current virtual desktop and current activity, and the desktop
// is not revealed with "Show Desktop" (which hides windows without minimizing them).
Item {
    id: monitor
    visible: false

    property rect screenGeometry
    property bool covered: windowCovers && !KWindowSystem.showingDesktop
    property bool windowCovers: false

    function evaluate() {
        let hit = false;
        for (let i = 0; i < tasks.count && !hit; ++i) {
            const idx = tasks.index(i, 0);
            if (tasks.data(idx, TaskManager.AbstractTasksModel.IsMinimized) === true) {
                continue;
            }
            hit = tasks.data(idx, TaskManager.AbstractTasksModel.IsMaximized) === true
                || tasks.data(idx, TaskManager.AbstractTasksModel.IsFullScreen) === true;
        }
        windowCovers = hit;
    }

    TaskManager.VirtualDesktopInfo { id: desktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortDisabled
        filterByVirtualDesktop: true
        filterByActivity: true
        filterByScreen: true
        virtualDesktop: desktopInfo.currentDesktop
        activity: activityInfo.currentActivity
        screenGeometry: monitor.screenGeometry
    }

    Timer { id: recheck; interval: 100; onTriggered: monitor.evaluate() }

    Connections {
        target: tasks
        function onDataChanged() { recheck.restart() }
        function onRowsInserted() { recheck.restart() }
        function onRowsRemoved() { recheck.restart() }
        function onModelReset() { recheck.restart() }
        function onCountChanged() { recheck.restart() }
    }

    Component.onCompleted: recheck.restart()
}
