// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Index = City setting "palette". accent is exported as the wallpaper accent colour.
// lit: share of windows with a light on.
var palettes = [
    { paveLight: "#f3e6c2", paveMid: "#ead8ac", paveDeep: "#e0c896", grassLight: "#c6d08a", grassMid: "#a6bd6c", ink: "#5c4a36", shadow: "#a89c84",
      wall0: "#f2e4c6", wall1: "#e6b96a", wall2: "#d98f72", wall3: "#a8c4cc", wall4: "#bccba4",
      roof0: "#b4553e", roof1: "#8c4c3c", roof2: "#5e6e80", glass: "#4b5c6c", lamp: "#ffd98a", door: "#6b4a3a",
      leaf: "#6f9a5a", trunk: "#8a6a58", smoke: "#f6f3ec", lit: 0.0, accent: "#b4553e" },   // Day
    { paveLight: "#f0cfa2", paveMid: "#e4b98a", paveDeep: "#d6a678", grassLight: "#c2b672", grassMid: "#a39a58", ink: "#5a3e34", shadow: "#a08478",
      wall0: "#f0cfa0", wall1: "#e09a54", wall2: "#cf6f5a", wall3: "#a890a8", wall4: "#b8a878",
      roof0: "#8f3f36", roof1: "#6c3a38", roof2: "#4c4a66", glass: "#4a3f52", lamp: "#ffd27a", door: "#5a3a32",
      leaf: "#7a8a4a", trunk: "#7a5a50", smoke: "#f4dcc8", lit: 0.45, accent: "#cf6f5a" },   // Dusk
    { paveLight: "#3f4862", paveMid: "#333b54", paveDeep: "#2b3249", grassLight: "#2c4850", grassMid: "#243c46", ink: "#12172a", shadow: "#6a7088",
      wall0: "#56607c", wall1: "#5a5674", wall2: "#6a5068", wall3: "#3f5a74", wall4: "#4a6468",
      roof0: "#3a2f44", roof1: "#2c2a3c", roof2: "#28384c", glass: "#1a2030", lamp: "#ffd98a", door: "#201c28",
      leaf: "#2f4a48", trunk: "#2a2630", smoke: "#8a90a8", lit: 0.6, accent: "#56607c" }     // Night
];
