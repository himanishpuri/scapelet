#version 440
// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float grid;       // px
    vec2 resolution;  // px
};
layout(binding = 1) uniform sampler2D mask; // r = narrow sum, g = wide sum

void main() {
    vec2 px = qt_TexCoord0 * resolution;
    vec4 m = texture(mask, qt_TexCoord0);
    float land = clamp(m.r, 0.0, 1.0);

    vec3 col = vec3(0.04, 0.09, 0.20);
    vec2 g = abs(fract(px / grid - 0.5) - 0.5) * grid;                 // px to the nearest grid line
    col += vec3(0.05, 0.10, 0.18) * (1.0 - smoothstep(0.0, 1.0, min(g.x, g.y)));
    col += vec3(0.05, 0.25, 0.35) * clamp(m.g, 0.0, 1.0);              // wide influence glow
    col = mix(col, vec3(0.10, 0.30, 0.45), step(0.5, land) * 0.5);     // inside the 0.5 contour

    float f = land * 4.0 + time * 0.05;                                // slowly drifting contour lines
    float iso = abs(fract(f) - 0.5) / max(fwidth(f), 0.0001);
    col += vec3(0.2, 0.8, 1.0) * (1.0 - smoothstep(0.0, 1.5, iso)) * step(0.02, land) * 0.6;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
