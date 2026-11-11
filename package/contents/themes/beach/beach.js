// SPDX-FileCopyrightText: 2026 himanishpuri <himanishpuri2203@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
.pragma library
.import "../../code/world.js" as World

// Index = Beach setting "palette". accent is exported as the wallpaper accent colour.
var palettes = [
    { deep: "#0b5d7a", mid: "#1899a8", shallow: "#4fd0c7", shoal: "#a8ecdf", foam: "#ffffff",
      sandWet: "#cdb07a", sandDry: "#e6cf9c", sandHigh: "#edd9ab", accent: "#1899a8" },   // Tropical
    { deep: "#3b2a5c", mid: "#8a4a78", shallow: "#e0806a", shoal: "#f6b98a", foam: "#fff1dc",
      sandWet: "#b98a62", sandDry: "#e0b07e", sandHigh: "#eec497", accent: "#e0806a" },   // Sunset
    { deep: "#071a2e", mid: "#0e3350", shallow: "#1d5d78", shoal: "#3f8a9a", foam: "#cfe6f2",
      sandWet: "#5d6470", sandDry: "#7d8490", sandHigh: "#9299a3", accent: "#1d5d78" }    // Night
];

// Palm positions: for every cluster of 3 or more, up to floor(size / 2) spots (5 at most),
// highest seed first, 24 in total.
function palmSpots(spots, clusters) {
    var quota = {}, out = [];
    for (var i = 0; i < clusters.length; ++i) {
        if (clusters[i].size >= 3) {
            quota[clusters[i].id] = Math.min(5, Math.floor(clusters[i].size / 2));
        }
    }
    var sorted = spots.slice().sort(function (a, b) { return b.seed - a.seed; });
    for (var j = 0; j < sorted.length && out.length < 24; ++j) {
        if (quota[sorted[j].cluster] > 0) {
            quota[sorted[j].cluster] -= 1;
            out.push(sorted[j]);
        }
    }
    return out;
}

// Ships: name is the picture (<name>.svg and <name>-shadow.svg, bow to the right), w x h its size in px.
var oldShips = [{ name: "sloop", w: 96, h: 36 }, { name: "galleon", w: 128, h: 44 }];
var modernShips = [{ name: "yacht", w: 104, h: 34 }, { name: "trawler", w: 100, h: 36 }];
var corsair = { name: "corsair", w: 128, h: 44 };

// The ship of crossing n for the Beach setting "ships" (0 none, 1 old sail, 2 modern, 3 mixed),
// or null. Among old ships, about one crossing in seven is the black-sailed corsair.
function ship(setting, n) {
    if (setting < 1 || setting > 3) {
        return null;
    }
    if (setting !== 2 && World.hash01(n + 0.13, 31) < 0.15) {
        return corsair;
    }
    var pool = setting === 1 ? oldShips : (setting === 2 ? modernShips : oldShips.concat(modernShips));
    return pool[Math.min(pool.length - 1, Math.floor(World.hash01(n + 0.13, 29) * pool.length))];
}
