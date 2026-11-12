#!/bin/sh
# SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
# Intel GPUs with Mesa only. Shows how the driver compiled the fragment shaders of a theme.
# A shader with too many values alive at once does not fit the registers 16 pixels wide; the
# driver then runs it 8 pixels wide, at about half the speed, and says nothing. Each line is one
# shader the driver kept: SIMD16 is good, a large shader listed only as SIMD8 has that problem.
# Usage: simd.sh [harness arguments, e.g. --theme city]
MESA_SHADER_CACHE_DISABLE=true INTEL_DEBUG=fs timeout 10 qml-qt6 tests/harness/Harness.qml -- --paused "$@" 2>&1 \
    | grep -a 'instructions\. .* loops' | sed 's/ scheduled with.*//' | awk '$3 >= 200' | sort | uniq | sort -k3 -rn
