#version 440
// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float strength;   // 0..1 island growth
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
    float d = length(max(abs(p) - halfRect, 0.0));
    float land = bump(d, sigma) * strength;
    float shallow = bump(d, sigmaWide) * strength;
    // Alpha 0 with premultiplied blending makes blobs accumulate additively.
    fragColor = vec4(land, shallow, 0.0, 0.0) * qt_Opacity;
}
