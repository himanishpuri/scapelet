#!/bin/sh
# SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
# Share of one GPU render engine used by a process, from DRM fdinfo (i915, amdgpu, xe).
# Usage: gpu-usage.sh [pid] [seconds]   (default: plasmashell, 10 s)
pid=${1:-$(pgrep -x plasmashell)}
secs=${2:-10}
read_ns() {
    cat /proc/"$pid"/fdinfo/* 2>/dev/null | awk '
        /^drm-client-id:/ { id = $2 }
        /^drm-engine-render:/ { ns[id] = $2 }
        END { t = 0; for (i in ns) t += ns[i]; print t + 0 }'
}
a=$(read_ns)
sleep "$secs"
b=$(read_ns)
awk -v a="$a" -v b="$b" -v s="$secs" 'BEGIN { printf "gpu-render %.1f%%\n", (b - a) / (s * 1e9) * 100 }'
