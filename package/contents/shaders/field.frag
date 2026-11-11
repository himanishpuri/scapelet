#version 440
// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float strength;   // amplitude: 1 at rest, 0.5 while the icon is lifted
    float growth;     // 0..1 size: the blob grows outward from its centre
    float sigma;      // px, narrow (land) falloff
    float sigmaWide;  // px, wide (shallow water) falloff
    vec2 itemSize;    // px, size of this quad
    vec2 halfRect;    // px, half size of the solid core rectangle
};

const float E0 = 0.0183156; // exp(-4): bump() is exactly 0 at d = 2 * s

float bump(float d, float s) {
    float g = exp(-(d * d) / (s * s));
    return max(0.0, (g - E0) / (1.0 - E0));
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * itemSize;
    float k = max(growth, 0.001);
    // Distances are divided by the growth, so every contour is `growth` times its final size.
    float d = length(max(abs(p) - halfRect * k, 0.0)) / k;
    // The first 15 % of the growth also fades the amplitude in, so a blob never starts as a hard dot.
    float a = strength * smoothstep(0.0, 0.15, growth);
    // Alpha 0 with premultiplied blending makes blobs accumulate additively.
    fragColor = vec4(bump(d, sigma) * a, bump(d, sigmaWide) * a, 0.0, 0.0) * qt_Opacity;
}
