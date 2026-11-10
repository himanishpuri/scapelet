#version 440
// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};

// Value noise whose lattice repeats every `period` cells, so the texture tiles.
float hashp(vec2 i, float period) {
    i = mod(i, period);
    return fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoisep(vec2 p, float period) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hashp(i, period);
    float b = hashp(i + vec2(1.0, 0.0), period);
    float c = hashp(i + vec2(0.0, 1.0), period);
    float d = hashp(i + vec2(1.0, 1.0), period);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbmp(vec2 p, float period) {
    return 0.667 * vnoisep(p, period) + 0.333 * vnoisep(p * 2.0 + 17.0, period * 2.0);
}

void main() {
    vec2 p = qt_TexCoord0;
    fragColor = vec4(fbmp(p * 12.0 + 3.1, 12.0), fbmp(p * 12.0 + 41.7, 12.0), vnoisep(p * 8.0 + 9.0, 8.0), 1.0);
}
