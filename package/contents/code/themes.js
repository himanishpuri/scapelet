// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library

// Marks a string for xgettext. It is translated with i18n() where it is shown.
function N_(s) {
    return s;
}

// One entry per theme; the theme itself is themes/<id>/Main.qml.
// Setting types: "int" (min, max, step), "bool", "choice" (choices; the value is the index).
var list = [
    {
        id: "beach",
        name: N_("Beach"),
        settings: [
            { key: "palette", type: "choice", label: N_("Palette:"), choices: [N_("Tropical"), N_("Sunset"), N_("Night")], def: 0 },
            { key: "coastWarp", type: "int", label: N_("Coastline irregularity (px):"), min: 0, max: 80, step: 5, def: 30 },
            { key: "palms", type: "bool", label: N_("Palm trees"), def: true },
            { key: "kayak", type: "bool", label: N_("Kayak"), def: true },
            { key: "birds", type: "bool", label: N_("Seabirds"), def: true },
            { key: "timeOfDay", type: "bool", label: N_("Tint by time of day"), def: false },
            { key: "strip", type: "choice", label: N_("Permanent beach:"), choices: [N_("None"), N_("Left"), N_("Right"), N_("Top"), N_("Bottom")], def: 0 },
            { key: "stripWidth", type: "int", label: N_("Permanent beach width (px):"), min: 60, max: 400, step: 20, def: 160 }
        ]
    },
    {
        id: "blueprint",
        name: N_("Blueprint"),
        settings: [
            { key: "grid", type: "int", label: N_("Grid spacing (px):"), min: 20, max: 120, step: 10, def: 40 }
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
