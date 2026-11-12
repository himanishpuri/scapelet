#!/bin/sh
# SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
# Proves that a change to a theme leaves its picture as it was: draws one paused frame here and
# in a reference checkout with the same harness arguments and compares them pixel by pixel.
# Run from the repository root, with the shaders of both checkouts built.
# Usage: same.sh <reference checkout> [harness arguments, e.g. --theme city --time 20]
# Exit status 0: no pixel differs. With KEEP=<prefix> the two pictures of a mismatch are kept.
# MAXDIFF=1 also accepts pixels that differ by one step of 255 (two builds of a shader may round differently).
ref=${1:?usage: same.sh <reference checkout> [harness arguments]}
shift
a=$(mktemp --suffix=.png)
b=$(mktemp --suffix=.png)
n=0
# A picture taken while the session is busy can come out wrong, so a mismatch gets two more tries.
while [ $n -lt 3 ]; do
    n=$((n + 1))
    (cd "$ref" && qml-qt6 tests/harness/Harness.qml -- --paused --snapshot "$a" "$@" >/dev/null 2>&1)
    qml-qt6 tests/harness/Harness.qml -- --paused --snapshot "$b" "$@" >/dev/null 2>&1
    out=$(python3 - "$a" "$b" <<'PY'
import os, sys
from PIL import Image, ImageChops
a = Image.open(sys.argv[1]).convert("RGB")
b = Image.open(sys.argv[2]).convert("RGB")
if a.size != b.size:
    print("DIFFERENT SIZE %s %s" % (a.size, b.size)); sys.exit(1)
if a.getextrema() == ((0, 0), (0, 0), (0, 0)):
    print("EMPTY PICTURE (the platform draws nothing)"); sys.exit(1)
d = ImageChops.difference(a, b)
r, g, bl = d.split()
m = ImageChops.lighter(ImageChops.lighter(r, g), bl)
count = sum(m.histogram()[1:])
worst = m.getextrema()[1]
ok = worst <= int(os.environ.get("MAXDIFF", "0"))
print("%s pixels=%d max=%d size=%dx%d" % ("same" if count == 0 else ("near" if ok else "DIFF"), count, worst, a.size[0], a.size[1]))
sys.exit(0 if ok else 1)
PY
    )
    rc=$?
    [ $rc -eq 0 ] && break
done
echo "same: $out  ($*)"
if [ $rc -ne 0 ] && [ -n "$KEEP" ]; then cp "$a" "$KEEP-ref.png"; cp "$b" "$KEEP-new.png"; fi
rm -f "$a" "$b"
exit $rc
