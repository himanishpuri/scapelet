// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick

// One icon's contribution to the land mask.
ShaderEffect {
    id: blob

    required property string key
    required property real bx
    required property real by
    required property real bw
    required property real bh
    required property bool present

    property bool animate: true
    property int appearDelay: 2000
    property int disappearDelay: 3000
    property int morphDuration: 1800

    signal expired(string key)

    // Shader uniforms.
    property real strength: 0
    property real sigma: 70
    property real sigmaWide: sigma * 2.5
    property vector2d halfRect: Qt.vector2d(bw * 0.25, bh * 0.25)
    property vector2d itemSize: Qt.vector2d(width, height)

    readonly property real reach: 2 * sigmaWide

    x: bx + bw / 2 - width / 2
    y: by + bh / 2 - height / 2
    width: 2 * (halfRect.x + reach)
    height: 2 * (halfRect.y + reach)
    visible: strength > 0.001
    fragmentShader: Qt.resolvedUrl("../shaders/blob.frag.qsb")

    function apply() {
        if (present) {
            shrink.stop();
            if (animate) {
                grow.restart();
            } else {
                strength = 1;
            }
        } else {
            grow.stop();
            if (animate) {
                shrink.restart();
            } else {
                strength = 0;
                expired(key);
            }
        }
    }

    onPresentChanged: apply()
    Component.onCompleted: apply()

    SequentialAnimation {
        id: grow
        PauseAnimation { duration: blob.appearDelay }
        NumberAnimation { target: blob; property: "strength"; to: 1; duration: blob.morphDuration; easing.type: Easing.InOutCubic }
    }

    SequentialAnimation {
        id: shrink
        PauseAnimation { duration: blob.disappearDelay }
        NumberAnimation { target: blob; property: "strength"; to: 0; duration: blob.morphDuration; easing.type: Easing.InOutCubic }
        ScriptAction { script: blob.expired(blob.key) }
    }
}
