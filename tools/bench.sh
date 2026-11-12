#!/bin/sh
# SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
# GPU time of one full-screen frame of a theme, at full GPU speed.
# The share of the GPU a wallpaper uses says little, because the GPU clocks down under a light
# load. Here the theme is drawn <scale> x <scale> times larger than the screen, without vsync, so
# the GPU is saturated and runs at its top clock; the frames it then finishes in a second give
# the cost of the shaders alone. Run from the repository root, under X11 or XWayland.
# Usage: bench.sh <scale 1..8> [harness arguments, e.g. --theme city --time 20]
# Choose the scale so that fewer than 55 frames/s come out; otherwise the result is an upper bound.
scale=${1:?usage: bench.sh <scale> [harness arguments]}
shift
# Two runs must never share the GPU.
if command -v flock >/dev/null; then exec 9>"${TMPDIR:-/tmp}/scapelet-gpu.lock"; flock 9; fi
log=$(mktemp)
QT_QPA_PLATFORM=xcb vblank_mode=0 QT_FORCE_STDERR_LOGGING=1 QML_XHR_ALLOW_FILE_READ=1 \
    qml-qt6 tests/harness/Harness.qml -- --stats --maximized --fps 60 --scale "$scale" "$@" >"$log" 2>&1 &
pid=$!
sleep 13
kill $pid 2>/dev/null
wait $pid 2>/dev/null
freq=$(cat /sys/class/drm/card*/gt_act_freq_mhz 2>/dev/null | head -n 1)
# Seconds 5 to 12: start-up is over. A frame was drawn for each tick that was also presented.
awk -v sc="$scale" -v mhz="${freq:-?}" '
    /stats:/ { n++; if (n >= 5 && n <= 12) { split($0, a, "[= ]"); for (i = 1; i <= length(a); i++) { if (a[i] == "ticks") t += a[i + 1]; if (a[i] == "swaps") s += a[i + 1] } k++ } }
    END {
        if (k == 0 || t == 0) { print "bench: no frames; does the harness start under QT_QPA_PLATFORM=xcb?"; exit 1 }
        f = (s < t ? s : t) / k
        printf "bench: %s%.2f ms per frame  (%.1f frames/s at scale %d, GPU clock last read %s MHz)\n", (f > 55 ? "< " : ""), 1000 / (f * sc * sc), f, sc, mhz
    }' "$log"
rc=$?
rm -f "$log"
exit $rc
