.pragma library

// Mounted cabinets from docs/FLOOR-LIBRARY.md. Logos are Blast art already
// on disk (quickshell/floor-art/). Game titles come from a local folder
// scan later — never Steam/IGDB. Sega 32X reuses genesis.png; Blast ships
// no 32X mark.

var SYSTEMS = [
    {
        id: "nes",
        name: "NES",
        family: "nintendo",
        folders: ["NES", "nes"],
        core: "nestopia",
        logo: "floor-art/nes.png"
    },
    {
        id: "snes",
        name: "SNES",
        family: "nintendo",
        folders: ["SNES", "snes"],
        core: "snes9x",
        logo: "floor-art/snes.png"
    },
    {
        id: "genesis",
        name: "Genesis",
        family: "sega",
        folders: ["Sega Genesis", "genesis", "megadrive", "Mega Drive"],
        core: "genesis_plus_gx",
        logo: "floor-art/genesis.png"
    },
    {
        id: "n64",
        name: "N64",
        family: "nintendo",
        folders: ["Nintendo 64", "N64", "n64"],
        core: "mupen64plus_next",
        logo: "floor-art/n64.png"
    },
    {
        id: "gb",
        name: "GB",
        family: "nintendo",
        folders: ["GB", "gb", "Game Boy"],
        core: "gambatte",
        logo: "floor-art/gb.png"
    },
    {
        id: "gbc",
        name: "GBC",
        family: "nintendo",
        folders: ["GBC", "gbc", "Game Boy Color"],
        core: "gambatte",
        logo: "floor-art/gbc.png"
    },
    {
        id: "gba",
        name: "GBA",
        family: "nintendo",
        folders: ["Game Boy Advance", "GBA", "gba"],
        core: "mgba",
        logo: "floor-art/gba.png"
    },
    {
        id: "mastersystem",
        name: "Master System",
        family: "sega",
        folders: ["Master System", "mastersystem", "sms"],
        core: "genesis_plus_gx",
        logo: "floor-art/mastersystem.png"
    },
    {
        id: "gamegear",
        name: "Game Gear",
        family: "sega",
        folders: ["Game Gear", "gamegear", "gg"],
        core: "genesis_plus_gx",
        logo: "floor-art/gamegear.png"
    },
    {
        id: "ps1",
        name: "PS1",
        family: "sony",
        folders: ["PlayStation", "PS1", "psx", "ps1"],
        core: "pcsx_rearmed",
        logo: "floor-art/psx.png"
    },
    {
        id: "ps2",
        name: "PS2",
        family: "sony",
        folders: ["PS2", "ps2", "PlayStation 2"],
        core: "pcsx2",
        logo: "floor-art/ps2.png"
    },
    {
        id: "arcade",
        name: "Arcade (MAME)",
        family: "arcade",
        folders: ["Arcade (MAME)", "Arcade", "MAME", "mame", "arcade"],
        core: "mame",
        logo: "floor-art/arcade.png"
    },
    {
        id: "atari2600",
        name: "Atari 2600",
        family: "arcade",
        folders: ["Atari 2600", "atari2600", "a2600"],
        core: "stella",
        logo: "floor-art/atari2600.png"
    },
    {
        id: "tg16",
        name: "TurboGrafx-16",
        family: "arcade",
        folders: ["TurboGrafx-16", "PC Engine", "pcengine", "tg16"],
        core: "mednafen_pce_fast",
        logo: "floor-art/pcengine.png"
    },
    {
        id: "32x",
        name: "Sega 32X",
        family: "sega",
        folders: ["32X", "Sega 32X", "32x"],
        core: "picodrive",
        logo: "floor-art/genesis.png"
    }
];

var GROUPS = [
    { id: "nintendo", name: "Nintendo", systems: ["nes", "snes", "n64", "gb", "gbc", "gba"] },
    { id: "sega", name: "Sega", systems: ["genesis", "mastersystem", "gamegear", "32x"] },
    { id: "sony", name: "Sony", systems: ["ps1", "ps2"] },
    { id: "arcade", name: "Arcade", systems: ["arcade", "atari2600", "tg16"] }
];

function systems() {
    return SYSTEMS;
}

function groups() {
    return GROUPS;
}

function systemById(id) {
    var key = String(id || "");
    for (var i = 0; i < SYSTEMS.length; i++) {
        if (SYSTEMS[i].id === key)
            return SYSTEMS[i];
    }
    return null;
}

function rows() {
    var byId = {};
    for (var i = 0; i < SYSTEMS.length; i++)
        byId[SYSTEMS[i].id] = SYSTEMS[i];
    var out = [];
    for (var g = 0; g < GROUPS.length; g++) {
        var sys = [];
        var ids = GROUPS[g].systems;
        for (var k = 0; k < ids.length; k++) {
            if (byId[ids[k]])
                sys.push(byId[ids[k]]);
        }
        out.push({ id: GROUPS[g].id, name: GROUPS[g].name, systems: sys });
    }
    return out;
}

function folderHit(sys, dirs) {
    if (!sys || !dirs || !dirs.length)
        return false;
    var want = {};
    var aliases = sys.folders || [];
    for (var i = 0; i < aliases.length; i++)
        want[String(aliases[i]).toLowerCase()] = true;
    want[String(sys.name || "").toLowerCase()] = true;
    for (var j = 0; j < dirs.length; j++) {
        if (want[String(dirs[j]).toLowerCase()])
            return true;
    }
    return false;
}
