pragma Singleton
// Nyxus Suxyn — the emoji table. WIP-704 / GAP-B7 / GAP-923.
//
// Data only. `EmojiPicker.qml` is the surface; this is the list it searches,
// kept in its own file so the picker reads as a picker and not as 400 lines
// of table.
//
// ── WHY THIS EXISTS AND rofi-emoji DOES NOT ─────────────────────────────────
// `rofi-emoji` is packaged in BOTH package tiers and referenced by absolutely
// nothing — the obvious wiring, and the wrong one. `WIP-557` is the row where
// the owner said of the right-click menu "the odd one that didn't belong and
// wasn't themed"; the root cause was that the only reachable implementation
// was a rofi front end, and the fix was to build the surface in the shell and
// leave rofi as a fallback nobody sees. Adding a SECOND rofi surface for
// emoji would re-open exactly that, on a keystroke the owner would press
// often. `GAP-923` says so in its own text. So the picker is Quickshell, in
// the build's own glass, like every other transient surface.
//
// ── WHY A TABLE AND NOT A FONT SCAN ─────────────────────────────────────────
// The tempting alternative is to enumerate what `noto-fonts-emoji` actually
// contains at runtime. Qt cannot do that without a font-table parser, and the
// result would be code points with no NAMES — and a picker without names is
// not searchable, which is most of what a picker is for. So the names and
// keywords are committed, and they are what `search()` matches.
//
// ── WHAT SHIPS IT, AND WHY EVERY GLYPH HERE RENDERS ─────────────────────────
// `noto-fonts-emoji` is in `packages.x86_64` AND `packages.x86_64.lean`, so
// the font is on every tier.
//
// EVERY ENTRY IS EXACTLY ONE CODE POINT — no ZWJ sequences, no skin-tone
// modifiers, no flags, no variation selectors. That is a deliberate floor,
// not laziness: a ZWJ family sequence on a font that lacks the composed form
// renders as three separate people, and a picker that shows a glyph which is
// not the glyph you get is worse than one that shows fewer. Gate 13q37
// counts the code points of all 274 entries and fails on any that is not 1.
//
// The Symbols group deliberately reaches past emoji into the punctuation and
// maths characters that are genuinely hard to type — `—`, `…`, `±`, `≈`, `→`,
// `©`. GAP-923 asks for an "Emoji / GIF / symbol picker"; those are the
// symbol half, they are one code point each like everything else, and several
// of them will render in the text style rather than the colour one, which is
// correct — they are text.
//
// NOT DONE, and named rather than left as a silent gap: the GIF third of
// GAP-923. A GIF picker is a network client with a search API, a cache and a
// content policy behind it; it is not a table, and pretending otherwise by
// shipping three built-in GIFs would be worse than shipping none.
import Quickshell
import QtQuick

Singleton {
    id: data

    // Group order is the order the picker draws them in: the things people
    // reach for most, first.
    readonly property var groups: [
        "Smileys", "People", "Nature", "Food", "Travel",
        "Activity", "Objects", "Symbols"
    ]

    // { e: the glyph · n: its name · k: extra search words (space separated) }
    // `n` is matched too, so `k` only carries what the name does not say.
    readonly property var items: [
        // ── Smileys ──────────────────────────────────────────────────────
        { g: "Smileys", e: "😀", n: "grinning face",            k: "happy smile" },
        { g: "Smileys", e: "😃", n: "grinning face big eyes",   k: "happy smile" },
        { g: "Smileys", e: "😄", n: "grinning face smiling eyes", k: "happy" },
        { g: "Smileys", e: "😁", n: "beaming face",             k: "grin happy" },
        { g: "Smileys", e: "😆", n: "grinning squinting face",  k: "laugh haha" },
        { g: "Smileys", e: "😅", n: "grinning face with sweat", k: "relief phew" },
        { g: "Smileys", e: "😂", n: "face with tears of joy",   k: "lol laugh cry" },
        { g: "Smileys", e: "🙂", n: "slightly smiling face",    k: "smile" },
        { g: "Smileys", e: "🙃", n: "upside down face",         k: "sarcasm irony" },
        { g: "Smileys", e: "😉", n: "winking face",             k: "wink flirt" },
        { g: "Smileys", e: "😊", n: "smiling face smiling eyes", k: "blush happy" },
        { g: "Smileys", e: "😇", n: "smiling face with halo",   k: "angel innocent" },
        { g: "Smileys", e: "😍", n: "smiling face heart eyes",  k: "love crush" },
        { g: "Smileys", e: "😘", n: "face blowing a kiss",      k: "kiss love" },
        { g: "Smileys", e: "😗", n: "kissing face",             k: "kiss" },
        { g: "Smileys", e: "😜", n: "winking face tongue",      k: "silly joke" },
        { g: "Smileys", e: "🤔", n: "thinking face",            k: "hmm consider" },
        { g: "Smileys", e: "🤨", n: "face with raised eyebrow", k: "skeptic doubt" },
        { g: "Smileys", e: "😐", n: "neutral face",             k: "meh blank" },
        { g: "Smileys", e: "😑", n: "expressionless face",      k: "blank" },
        { g: "Smileys", e: "🙄", n: "face with rolling eyes",   k: "eyeroll annoyed" },
        { g: "Smileys", e: "😏", n: "smirking face",            k: "smug" },
        { g: "Smileys", e: "😒", n: "unamused face",            k: "annoyed" },
        { g: "Smileys", e: "😔", n: "pensive face",             k: "sad down" },
        { g: "Smileys", e: "😴", n: "sleeping face",            k: "sleep zzz tired" },
        { g: "Smileys", e: "😪", n: "sleepy face",              k: "tired" },
        { g: "Smileys", e: "😷", n: "face with medical mask",   k: "sick mask" },
        { g: "Smileys", e: "🤒", n: "face with thermometer",    k: "sick ill fever" },
        { g: "Smileys", e: "🤯", n: "exploding head",           k: "mind blown shock" },
        { g: "Smileys", e: "😎", n: "smiling face with sunglasses", k: "cool" },
        { g: "Smileys", e: "🤓", n: "nerd face",                k: "geek glasses" },
        { g: "Smileys", e: "😕", n: "confused face",            k: "unsure" },
        { g: "Smileys", e: "😟", n: "worried face",             k: "concern" },
        { g: "Smileys", e: "😢", n: "crying face",              k: "sad tear" },
        { g: "Smileys", e: "😭", n: "loudly crying face",       k: "sob sad" },
        { g: "Smileys", e: "😤", n: "face with steam from nose", k: "triumph angry" },
        { g: "Smileys", e: "😠", n: "angry face",               k: "mad" },
        { g: "Smileys", e: "😡", n: "pouting face",             k: "rage angry red" },
        { g: "Smileys", e: "😱", n: "face screaming in fear",   k: "scream shock" },
        { g: "Smileys", e: "😳", n: "flushed face",             k: "embarrassed blush" },
        { g: "Smileys", e: "🥺", n: "pleading face",            k: "puppy eyes beg" },
        { g: "Smileys", e: "😬", n: "grimacing face",           k: "awkward eek" },
        { g: "Smileys", e: "🤐", n: "zipper mouth face",        k: "quiet secret" },
        { g: "Smileys", e: "🤗", n: "hugging face",             k: "hug" },
        { g: "Smileys", e: "🤢", n: "nauseated face",           k: "sick gross" },
        { g: "Smileys", e: "🥳", n: "partying face",            k: "celebrate party" },
        { g: "Smileys", e: "🤠", n: "cowboy hat face",          k: "cowboy" },
        { g: "Smileys", e: "👻", n: "ghost",                    k: "boo halloween spooky" },
        { g: "Smileys", e: "💀", n: "skull",                    k: "dead death" },
        { g: "Smileys", e: "👽", n: "alien",                    k: "ufo space" },
        { g: "Smileys", e: "🤖", n: "robot",                    k: "bot ai machine" },
        { g: "Smileys", e: "😺", n: "grinning cat",             k: "cat" },
        { g: "Smileys", e: "🙈", n: "see no evil monkey",       k: "monkey hide" },
        { g: "Smileys", e: "🙉", n: "hear no evil monkey",      k: "monkey" },
        { g: "Smileys", e: "🙊", n: "speak no evil monkey",     k: "monkey quiet" },
        { g: "Smileys", e: "💩", n: "pile of poo",              k: "poop" },

        // ── People ───────────────────────────────────────────────────────
        { g: "People", e: "👋", n: "waving hand",               k: "hello bye wave" },
        { g: "People", e: "👌", n: "ok hand",                   k: "okay perfect" },
        { g: "People", e: "✌", n: "victory hand",              k: "peace two" },
        { g: "People", e: "🤞", n: "crossed fingers",           k: "luck hope" },
        { g: "People", e: "👍", n: "thumbs up",                 k: "yes good approve like" },
        { g: "People", e: "👎", n: "thumbs down",               k: "no bad dislike" },
        { g: "People", e: "👊", n: "oncoming fist",             k: "punch bump" },
        { g: "People", e: "👏", n: "clapping hands",            k: "applause bravo" },
        { g: "People", e: "🙌", n: "raising hands",             k: "celebrate praise" },
        { g: "People", e: "🙏", n: "folded hands",              k: "please thanks pray" },
        { g: "People", e: "💪", n: "flexed biceps",             k: "strong muscle" },
        { g: "People", e: "🤝", n: "handshake",                 k: "deal agree" },
        { g: "People", e: "👀", n: "eyes",                      k: "look watch see" },
        { g: "People", e: "🧠", n: "brain",                     k: "smart think" },
        { g: "People", e: "👶", n: "baby",                      k: "infant" },
        { g: "People", e: "👩", n: "woman",                     k: "person female" },
        { g: "People", e: "👨", n: "man",                       k: "person male" },
        { g: "People", e: "🧑", n: "person",                    k: "adult" },
        { g: "People", e: "👴", n: "old man",                   k: "elder grandpa" },
        { g: "People", e: "👵", n: "old woman",                 k: "elder grandma" },
        { g: "People", e: "🕵", n: "detective",                k: "spy investigate" },
        { g: "People", e: "💃", n: "woman dancing",             k: "dance party" },
        { g: "People", e: "🕺", n: "man dancing",               k: "dance party" },
        { g: "People", e: "🚶", n: "person walking",            k: "walk" },
        { g: "People", e: "🏃", n: "person running",            k: "run" },

        // ── Nature ───────────────────────────────────────────────────────
        { g: "Nature", e: "🐶", n: "dog face",                  k: "puppy pet" },
        { g: "Nature", e: "🐱", n: "cat face",                  k: "kitten pet" },
        { g: "Nature", e: "🐭", n: "mouse face",                k: "rodent" },
        { g: "Nature", e: "🐹", n: "hamster",                   k: "pet" },
        { g: "Nature", e: "🐰", n: "rabbit face",               k: "bunny" },
        { g: "Nature", e: "🦊", n: "fox",                       k: "" },
        { g: "Nature", e: "🐻", n: "bear",                      k: "" },
        { g: "Nature", e: "🐼", n: "panda",                     k: "bear" },
        { g: "Nature", e: "🐨", n: "koala",                     k: "" },
        { g: "Nature", e: "🐯", n: "tiger face",                k: "cat" },
        { g: "Nature", e: "🦁", n: "lion",                      k: "" },
        { g: "Nature", e: "🐮", n: "cow face",                  k: "" },
        { g: "Nature", e: "🐷", n: "pig face",                  k: "" },
        { g: "Nature", e: "🐸", n: "frog",                      k: "" },
        { g: "Nature", e: "🐵", n: "monkey face",               k: "" },
        { g: "Nature", e: "🐔", n: "chicken",                   k: "hen" },
        { g: "Nature", e: "🐧", n: "penguin",                   k: "linux" },
        { g: "Nature", e: "🐦", n: "bird",                      k: "" },
        { g: "Nature", e: "🦆", n: "duck",                      k: "" },
        { g: "Nature", e: "🦉", n: "owl",                       k: "night" },
        { g: "Nature", e: "🐝", n: "honeybee",                  k: "bee" },
        { g: "Nature", e: "🦋", n: "butterfly",                 k: "" },
        { g: "Nature", e: "🐢", n: "turtle",                    k: "slow" },
        { g: "Nature", e: "🐍", n: "snake",                     k: "python" },
        { g: "Nature", e: "🐙", n: "octopus",                   k: "" },
        { g: "Nature", e: "🐳", n: "spouting whale",            k: "whale sea" },
        { g: "Nature", e: "🐬", n: "dolphin",                   k: "sea" },
        { g: "Nature", e: "🐟", n: "fish",                      k: "sea" },
        { g: "Nature", e: "🌸", n: "cherry blossom",            k: "flower spring" },
        { g: "Nature", e: "🌹", n: "rose",                      k: "flower love" },
        { g: "Nature", e: "🌻", n: "sunflower",                 k: "flower" },
        { g: "Nature", e: "🌲", n: "evergreen tree",            k: "pine forest" },
        { g: "Nature", e: "🌴", n: "palm tree",                 k: "beach" },
        { g: "Nature", e: "🍀", n: "four leaf clover",          k: "luck" },
        { g: "Nature", e: "🍁", n: "maple leaf",                k: "autumn fall" },
        { g: "Nature", e: "🌊", n: "water wave",                k: "sea ocean" },
        { g: "Nature", e: "🔥", n: "fire",                      k: "hot flame lit" },
        { g: "Nature", e: "✨", n: "sparkles",                  k: "shine magic" },
        { g: "Nature", e: "⭐", n: "star",                      k: "favourite" },
        { g: "Nature", e: "🌙", n: "crescent moon",             k: "night" },
        { g: "Nature", e: "☀", n: "sun",                       k: "sunny day" },
        { g: "Nature", e: "☁", n: "cloud",                     k: "weather" },
        { g: "Nature", e: "⛈", n: "cloud with lightning and rain", k: "storm" },
        { g: "Nature", e: "❄", n: "snowflake",                 k: "cold winter snow" },
        { g: "Nature", e: "🌈", n: "rainbow",                   k: "pride colour" },

        // ── Food ─────────────────────────────────────────────────────────
        { g: "Food", e: "🍎", n: "red apple",                   k: "fruit" },
        { g: "Food", e: "🍌", n: "banana",                      k: "fruit" },
        { g: "Food", e: "🍇", n: "grapes",                      k: "fruit" },
        { g: "Food", e: "🍓", n: "strawberry",                  k: "fruit berry" },
        { g: "Food", e: "🍉", n: "watermelon",                  k: "fruit" },
        { g: "Food", e: "🍑", n: "peach",                       k: "fruit" },
        { g: "Food", e: "🥑", n: "avocado",                     k: "" },
        { g: "Food", e: "🍞", n: "bread",                       k: "loaf" },
        { g: "Food", e: "🧀", n: "cheese wedge",                k: "" },
        { g: "Food", e: "🍕", n: "pizza",                       k: "slice" },
        { g: "Food", e: "🍔", n: "hamburger",                   k: "burger" },
        { g: "Food", e: "🌮", n: "taco",                        k: "" },
        { g: "Food", e: "🍜", n: "steaming bowl",               k: "ramen noodles" },
        { g: "Food", e: "🍣", n: "sushi",                       k: "" },
        { g: "Food", e: "🍿", n: "popcorn",                     k: "movie" },
        { g: "Food", e: "🎂", n: "birthday cake",               k: "cake party" },
        { g: "Food", e: "🍪", n: "cookie",                      k: "biscuit" },
        { g: "Food", e: "🍫", n: "chocolate bar",               k: "" },
        { g: "Food", e: "☕", n: "hot beverage",                k: "coffee tea" },
        { g: "Food", e: "🍺", n: "beer mug",                    k: "pint drink" },
        { g: "Food", e: "🍷", n: "wine glass",                  k: "drink" },
        { g: "Food", e: "🥂", n: "clinking glasses",            k: "cheers toast" },

        // ── Travel ───────────────────────────────────────────────────────
        { g: "Travel", e: "🚗", n: "automobile",                k: "car drive" },
        { g: "Travel", e: "🚕", n: "taxi",                      k: "cab" },
        { g: "Travel", e: "🚌", n: "bus",                       k: "" },
        { g: "Travel", e: "🚲", n: "bicycle",                   k: "bike" },
        { g: "Travel", e: "🛵", n: "motor scooter",             k: "" },
        { g: "Travel", e: "✈", n: "airplane",                  k: "flight travel" },
        { g: "Travel", e: "🚀", n: "rocket",                    k: "launch ship space" },
        { g: "Travel", e: "🛰", n: "satellite",                k: "space orbit" },
        { g: "Travel", e: "🚂", n: "locomotive",                k: "train" },
        { g: "Travel", e: "⛵", n: "sailboat",                  k: "boat sea" },
        { g: "Travel", e: "🏠", n: "house",                     k: "home" },
        { g: "Travel", e: "🏢", n: "office building",           k: "work" },
        { g: "Travel", e: "🗺", n: "world map",                k: "travel" },
        { g: "Travel", e: "🗻", n: "mount fuji",                k: "mountain" },
        { g: "Travel", e: "🏝", n: "desert island",            k: "beach holiday" },
        { g: "Travel", e: "🌍", n: "globe europe africa",       k: "earth world" },
        { g: "Travel", e: "🌎", n: "globe americas",            k: "earth world" },
        { g: "Travel", e: "🌏", n: "globe asia australia",      k: "earth world" },

        // ── Activity ─────────────────────────────────────────────────────
        { g: "Activity", e: "⚽", n: "soccer ball",             k: "football sport" },
        { g: "Activity", e: "🏀", n: "basketball",              k: "sport" },
        { g: "Activity", e: "🏈", n: "american football",       k: "sport" },
        { g: "Activity", e: "🎾", n: "tennis",                  k: "sport" },
        { g: "Activity", e: "🎱", n: "pool 8 ball",             k: "billiards" },
        { g: "Activity", e: "🏆", n: "trophy",                  k: "win award" },
        { g: "Activity", e: "🥇", n: "1st place medal",         k: "gold win first" },
        { g: "Activity", e: "🎮", n: "video game",              k: "controller gaming" },
        { g: "Activity", e: "🕹", n: "joystick",               k: "arcade retro" },
        { g: "Activity", e: "🎲", n: "game die",                k: "dice random" },
        { g: "Activity", e: "🎯", n: "bullseye",                k: "target dart aim" },
        { g: "Activity", e: "🎸", n: "guitar",                  k: "music rock" },
        { g: "Activity", e: "🎹", n: "musical keyboard",        k: "piano music" },
        { g: "Activity", e: "🎧", n: "headphone",               k: "music listen audio" },
        { g: "Activity", e: "🎤", n: "microphone",              k: "sing record" },
        { g: "Activity", e: "🎬", n: "clapper board",           k: "film movie" },
        { g: "Activity", e: "🎨", n: "artist palette",          k: "paint art colour" },
        { g: "Activity", e: "🎉", n: "party popper",            k: "celebrate congrats" },
        { g: "Activity", e: "🎁", n: "wrapped gift",            k: "present" },

        // ── Objects ──────────────────────────────────────────────────────
        { g: "Objects", e: "💻", n: "laptop",                   k: "computer pc" },
        { g: "Objects", e: "🖥", n: "desktop computer",        k: "pc monitor" },
        { g: "Objects", e: "⌨", n: "keyboard",                 k: "type" },
        { g: "Objects", e: "🖱", n: "computer mouse",          k: "pointer" },
        { g: "Objects", e: "🖨", n: "printer",                 k: "print" },
        { g: "Objects", e: "💾", n: "floppy disk",              k: "save disk" },
        { g: "Objects", e: "💿", n: "optical disk",             k: "cd dvd iso" },
        { g: "Objects", e: "📱", n: "mobile phone",             k: "smartphone" },
        { g: "Objects", e: "📷", n: "camera",                   k: "photo" },
        { g: "Objects", e: "🔋", n: "battery",                  k: "power charge" },
        { g: "Objects", e: "🔌", n: "electric plug",            k: "power mains" },
        { g: "Objects", e: "💡", n: "light bulb",               k: "idea" },
        { g: "Objects", e: "🔦", n: "flashlight",               k: "torch" },
        { g: "Objects", e: "🔒", n: "locked",                   k: "lock secure private" },
        { g: "Objects", e: "🔓", n: "unlocked",                 k: "open" },
        { g: "Objects", e: "🔑", n: "key",                      k: "password" },
        { g: "Objects", e: "🔧", n: "wrench",                   k: "tool fix spanner" },
        { g: "Objects", e: "🔨", n: "hammer",                   k: "tool build" },
        { g: "Objects", e: "⚙", n: "gear",                     k: "settings cog config" },
        { g: "Objects", e: "🧲", n: "magnet",                   k: "attract" },
        { g: "Objects", e: "🧪", n: "test tube",                k: "science lab experiment" },
        { g: "Objects", e: "🔬", n: "microscope",               k: "science" },
        { g: "Objects", e: "🔭", n: "telescope",                k: "space astronomy" },
        { g: "Objects", e: "📎", n: "paperclip",                k: "attach" },
        { g: "Objects", e: "📌", n: "pushpin",                  k: "pin" },
        { g: "Objects", e: "📅", n: "calendar",                 k: "date schedule" },
        { g: "Objects", e: "📖", n: "open book",                k: "read docs help" },
        { g: "Objects", e: "📝", n: "memo",                     k: "note write" },
        { g: "Objects", e: "✏", n: "pencil",                   k: "write edit" },
        { g: "Objects", e: "📦", n: "package",                  k: "box parcel archive" },
        { g: "Objects", e: "📬", n: "open mailbox",             k: "mail post" },
        { g: "Objects", e: "🗑", n: "wastebasket",             k: "trash delete bin" },
        { g: "Objects", e: "💰", n: "money bag",                k: "cash rich" },
        { g: "Objects", e: "💳", n: "credit card",              k: "pay" },
        { g: "Objects", e: "⏰", n: "alarm clock",              k: "time wake" },
        { g: "Objects", e: "⌛", n: "hourglass done",           k: "time wait" },
        { g: "Objects", e: "🧭", n: "compass",                  k: "direction navigate" },

        // ── Symbols ──────────────────────────────────────────────────────
        { g: "Symbols", e: "❤", n: "red heart",                k: "love" },
        { g: "Symbols", e: "🧡", n: "orange heart",             k: "love" },
        { g: "Symbols", e: "💛", n: "yellow heart",             k: "love" },
        { g: "Symbols", e: "💚", n: "green heart",              k: "love" },
        { g: "Symbols", e: "💙", n: "blue heart",               k: "love" },
        { g: "Symbols", e: "💜", n: "purple heart",             k: "love" },
        { g: "Symbols", e: "🖤", n: "black heart",              k: "love" },
        { g: "Symbols", e: "💔", n: "broken heart",             k: "sad breakup" },
        { g: "Symbols", e: "💯", n: "hundred points",           k: "100 perfect" },
        { g: "Symbols", e: "✅", n: "check mark button",        k: "yes done tick ok" },
        { g: "Symbols", e: "❌", n: "cross mark",               k: "no wrong fail x" },
        { g: "Symbols", e: "⚠", n: "warning",                  k: "caution alert" },
        { g: "Symbols", e: "⛔", n: "no entry",                 k: "stop forbidden" },
        { g: "Symbols", e: "❓", n: "question mark",            k: "help ask" },
        { g: "Symbols", e: "❗", n: "exclamation mark",         k: "important" },
        { g: "Symbols", e: "🔔", n: "bell",                     k: "notification alert" },
        { g: "Symbols", e: "🔕", n: "bell with slash",          k: "mute silent dnd" },
        { g: "Symbols", e: "🔍", n: "magnifying glass",         k: "search find zoom" },
        { g: "Symbols", e: "🔗", n: "link",                     k: "url chain" },
        { g: "Symbols", e: "♻", n: "recycling symbol",         k: "recycle green" },
        { g: "Symbols", e: "⚡", n: "high voltage",             k: "lightning power fast" },
        { g: "Symbols", e: "☢", n: "radioactive",              k: "danger nuclear" },
        { g: "Symbols", e: "⬆", n: "up arrow",                 k: "north" },
        { g: "Symbols", e: "⬇", n: "down arrow",               k: "south" },
        { g: "Symbols", e: "⬅", n: "left arrow",               k: "west back" },
        { g: "Symbols", e: "➡", n: "right arrow",              k: "east forward" },
        { g: "Symbols", e: "🔁", n: "repeat button",            k: "loop" },
        { g: "Symbols", e: "▶", n: "play button",              k: "start" },
        { g: "Symbols", e: "⏸", n: "pause button",             k: "" },
        { g: "Symbols", e: "⏹", n: "stop button",              k: "" },
        { g: "Symbols", e: "🆕", n: "new button",               k: "" },
        { g: "Symbols", e: "🆗", n: "ok button",                k: "" },
        { g: "Symbols", e: "🈶", n: "japanese not free of charge button", k: "" },
        { g: "Symbols", e: "©", n: "copyright",                 k: "legal" },
        { g: "Symbols", e: "®", n: "registered",                k: "trademark legal" },
        { g: "Symbols", e: "™", n: "trade mark",                k: "legal" },
        { g: "Symbols", e: "°", n: "degree sign",               k: "temperature angle" },
        { g: "Symbols", e: "€", n: "euro sign",                 k: "currency money" },
        { g: "Symbols", e: "£", n: "pound sign",                k: "currency money" },
        { g: "Symbols", e: "¥", n: "yen sign",                  k: "currency money" },
        { g: "Symbols", e: "±", n: "plus minus sign",           k: "maths tolerance" },
        { g: "Symbols", e: "×", n: "multiplication sign",       k: "maths times" },
        { g: "Symbols", e: "÷", n: "division sign",             k: "maths divide" },
        { g: "Symbols", e: "≈", n: "almost equal to",           k: "maths approx" },
        { g: "Symbols", e: "≠", n: "not equal to",              k: "maths" },
        { g: "Symbols", e: "→", n: "rightwards arrow",          k: "arrow text" },
        { g: "Symbols", e: "←", n: "leftwards arrow",           k: "arrow text" },
        { g: "Symbols", e: "…", n: "horizontal ellipsis",       k: "dots" },
        { g: "Symbols", e: "—", n: "em dash",                   k: "punctuation" },
        { g: "Symbols", e: "·", n: "middle dot",                k: "punctuation separator" },
        { g: "Symbols", e: "✓", n: "check mark",                k: "tick done text" },
        { g: "Symbols", e: "✗", n: "ballot x",                  k: "cross text" }
    ]

    // ── search ──────────────────────────────────────────────────────────
    // Substring, case-folded, over name + keywords. Deliberately not fuzzy:
    // a picker of 250 entries returns a screenful on almost any two letters,
    // and fuzzy matching in that regime mostly returns things you did not
    // mean. Word-start matches sort first so typing "he" puts "heart" above
    // "wastebasket".
    function search(q) {
        const needle = (q || "").trim().toLowerCase();
        if (needle.length === 0) return data.items;
        var lead = [], rest = [];
        for (var i = 0; i < data.items.length; i++) {
            const it = data.items[i];
            const hay = (it.n + " " + it.k).toLowerCase();
            const at = hay.indexOf(needle);
            if (at < 0) continue;
            if (at === 0 || hay.charAt(at - 1) === " ") lead.push(it);
            else rest.push(it);
        }
        return lead.concat(rest);
    }

    // Deliberately no `byGroup()`. The table is STORED in `groups` order and
    // the picker draws it in table order, so a group filter would be a second
    // way to say the same thing — and an unused function is a promise nobody
    // is keeping. Gate 13q37 checks that every declared group has rows and
    // that no row sits in an undeclared one, which is what `groups` is
    // actually for.
    function find(glyph) {
        for (var i = 0; i < data.items.length; i++)
            if (data.items[i].e === glyph) return data.items[i];
        return null;
    }
}
