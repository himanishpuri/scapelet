// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// One entry per theme; the theme itself is themes/<id>/Main.qml.
// Setting types: "int" (min, max, step), "bool", "choice" (choices; the value is the index).
var list = [
    {
        id: "beach",
        name: "Beach",
        settings: [
            { key: "palette", type: "choice", label: "Palette:", choices: ["Tropical", "Sunset", "Night"], def: 0 },
            { key: "coastWarp", type: "int", label: "Coastline irregularity (px):", min: 0, max: 80, step: 5, def: 30 },
            { key: "palms", type: "bool", label: "Palm trees", def: true },
            { key: "kayak", type: "bool", label: "Kayak", def: true },
            { key: "birds", type: "bool", label: "Seabirds", def: true },
            { key: "timeOfDay", type: "bool", label: "Tint by time of day", def: false },
            { key: "strip", type: "choice", label: "Permanent beach:", choices: ["None", "Left", "Right", "Top", "Bottom"], def: 0 },
            { key: "stripWidth", type: "int", label: "Permanent beach width (px):", min: 60, max: 400, step: 20, def: 160 }
        ]
    },
    {
        id: "meadow",
        name: "Meadow",
        settings: [
            { key: "palette", type: "choice", label: "Palette:", choices: ["Spring", "Summer", "Dusk"], def: 0 },
            { key: "fluff", type: "int", label: "Cloud fluffiness (px):", min: 0, max: 40, step: 4, def: 20 },
            { key: "shadows", type: "bool", label: "Cloud shadows", def: true },
            { key: "altitude", type: "int", label: "Shadow distance (px):", min: 40, max: 240, step: 20, def: 140 },
            { key: "drift", type: "int", label: "Drifting clouds:", min: 0, max: 5, step: 1, def: 2 },
            { key: "butterflies", type: "bool", label: "Butterflies", def: true },
            { key: "timeOfDay", type: "bool", label: "Tint by time of day", def: false }
        ]
    },
    {
        id: "forest",
        name: "Forest",
        settings: [
            { key: "palette", type: "choice", label: "Palette:", choices: ["Summer", "Autumn", "Winter"], def: 0 },
            { key: "density", type: "int", label: "Tree density:", min: 1, max: 10, step: 1, def: 8 },
            { key: "sway", type: "bool", label: "Trees sway in the wind", def: true },
            { key: "sparrows", type: "bool", label: "Sparrows", def: true },
            { key: "timeOfDay", type: "bool", label: "Tint by time of day", def: false }
        ]
    },
    {
        id: "cosmos",
        name: "Cosmos",
        settings: [
            { key: "palette", type: "choice", label: "Palette:", choices: ["Violet", "Teal", "Ember"], def: 0 },
            { key: "density", type: "int", label: "Star density:", min: 1, max: 10, step: 1, def: 5 },
            { key: "lines", type: "bool", label: "Constellation lines", def: true },
            { key: "shooting", type: "bool", label: "Shooting stars", def: true },
            { key: "milkyWay", type: "bool", label: "Milky Way", def: true },
            { key: "drift", type: "bool", label: "Slow drift", def: true }
        ]
    },
    {
        id: "blueprint",
        name: "Blueprint",
        settings: [
            { key: "grid", type: "int", label: "Grid spacing (px):", min: 20, max: 120, step: 10, def: 40 }
        ]
    }
];

// Entry for id, or the first theme when id is unknown.
function find(id) {
    for (var i = 0; i < list.length; ++i) {
        if (list[i].id === id) {
            return list[i];
        }
    }
    return list[0];
}

function parse(json) {
    try {
        var o = JSON.parse(json || "{}");
        return (o !== null && typeof o === "object" && !Array.isArray(o)) ? o : {};
    } catch (e) {
        return {};
    }
}

function valid(spec, v) {
    if (spec.type === "bool") {
        return typeof v === "boolean";
    }
    if (typeof v !== "number" || Math.round(v) !== v) {
        return false;
    }
    return spec.type === "choice" ? (v >= 0 && v < spec.choices.length) : (v >= spec.min && v <= spec.max);
}

// { key: value } for theme id: the stored value when valid, else the default.
function resolve(id, json) {
    var entry = find(id), stored = parse(json)[entry.id] || {}, out = {};
    for (var i = 0; i < entry.settings.length; ++i) {
        var s = entry.settings[i];
        out[s.key] = valid(s, stored[s.key]) ? stored[s.key] : s.def;
    }
    return out;
}

// New JSON with theme id's key set to value.
function store(json, id, key, value) {
    var all = parse(json), own = all[id] || {};
    own[key] = value;
    all[id] = own;
    return JSON.stringify(all);
}
