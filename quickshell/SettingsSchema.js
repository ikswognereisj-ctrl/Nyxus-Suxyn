.pragma library
// Nyxus Suxyn — the settings SCHEMA: `schema_version` and the migration table
// for ~/.config/nyxus/settings.json.                              TRK-1260
//
// ── what this file is ────────────────────────────────────────────────────
// One table, read by two consumers:
//
//   SettingsStore.qml   runs `migrate()` on every successful load. If the
//                       document's `schema_version` is behind CURRENT (a
//                       missing key reads as 1 — every file written before
//                       this table existed), the store backs the file up to
//                       `settings.json.bak-<from>` FIRST, then writes the
//                       migrated document with `schema_version` = CURRENT.
//   Prefs.qml           calls `coerce(key, value)` on the keys that carry a
//                       rule, so a hand-edited value that arrives between
//                       migrations still reads as the shipped default rather
//                       than as a retired ramp or a negative gain. One table,
//                       two readers, zero ad-hoc comparisons in Prefs.
//
// `scripts/gen-settings-schema.py` parses the TABLE below (it is a JSON
// literal between the two marker comments — do not put comments inside it),
// runs a python twin of `applyRules()` over a fixture, and diffs the result
// against this file run under the `qml` runtime. Gate 13r80 calls that in
// --check mode. If you change a rule kind here, change the twin there in the
// same commit, or the gate says so.
//
// ── the rules, and why each one is a DROP rather than a rewrite ──────────
// A rule names a key, the values that are still legal, and the shipped
// default. A value outside the rule is REMOVED from the document, not
// overwritten with the default: `SettingsStore.clearValue()`'s header has the
// reason — a written default is a decision the user made, and a later change
// to the shipped default would never reach them. An absent key is the shipped
// default by construction (JsonAdapter / SettingsStore fallback), so dropping
// is the coercion that stays correct when the default moves.
//
// Every rule in 1→2 is a coercion Prefs.qml used to do inline at read time:
//   swirl_layer            rose|magma|violet retired, owner 2026-08-20 — one dye
//   pointer_trail_layer    same retirement; "match" follows that dye
//   softpress_material     a typo must not invent a sixth shader path
//   tod_preview            TRK-1054 debug hold; "" / "live" = follow the clock
//   material_preview       TRK-1055 debug pin;  "" = follow UPower + hwmon
//   softpress_gain         > 0 or the dent inverts
//   softpress_viscosity    > 0 or the dent never settles
//   hover_give_depth       >= 0 — a negative give lifts AWAY from the pointer
//   font_scale             GTK Accessibility's own range, 0.85–1.40
//
// Idempotent by construction: a document that has been through a migration
// satisfies every rule of it, so running it again changes nothing, and the
// store only writes when `needed` is true.
//
// ── adding a schema ──────────────────────────────────────────────────────
// Bump "current", append {"from": N, "to": N+1, "rules": [...]}. Never edit a
// migration that has shipped: a file at version N+1 will never see it again,
// and a file at N must get exactly what every other file at N got. Kinds:
//   {"key","kind":"enum","allowed":[...],"default":v}
//   {"key","kind":"number","min":m,"max":M,"minExclusive":bool,"default":v}
//       (min/max optional; minExclusive true means value must be > min)
//   {"key","kind":"rename","to":"new_key"}
//       (moves the value when the old key is present and the new one is not;
//        drops the old key either way)

/* SETTINGS-SCHEMA-TABLE-BEGIN */
var TABLE = {
  "current": 4,
  "migrations": [
    {
      "from": 1,
      "to": 2,
      "note": "the coercions Prefs.qml did inline at read time, moved into the file",
      "rules": [
        { "key": "swirl_layer", "kind": "enum", "allowed": ["glacier"], "default": "glacier",
          "why": "rose|magma|violet retired (owner 2026-08-20): one dye, ice + wallpaper purple" },
        { "key": "pointer_trail_layer", "kind": "enum", "allowed": ["match", "glacier"], "default": "match",
          "why": "retired layer names follow the one dye" },
        { "key": "softpress_material", "kind": "enum", "allowed": ["glass", "smoke", "foam", "rubber", "jelly"], "default": "glass",
          "why": "a typo must not invent a sixth shader path (TRK-1084)" },
        { "key": "tod_preview", "kind": "enum", "allowed": ["day", "dusk", "night"], "default": "",
          "why": "TRK-1054 debug hold; anything else follows the clock" },
        { "key": "material_preview", "kind": "enum", "allowed": ["tired", "charge", "hot"], "default": "",
          "why": "TRK-1055 debug pin; anything else follows UPower + hwmon" },
        { "key": "softpress_gain", "kind": "number", "min": 0, "minExclusive": true, "default": 1.1,
          "why": "gain <= 0 inverts the dent" },
        { "key": "softpress_viscosity", "kind": "number", "min": 0, "minExclusive": true, "default": 1.0,
          "why": "viscosity <= 0 never settles" },
        { "key": "hover_give_depth", "kind": "number", "min": 0, "default": 0.025,
          "why": "a negative give lifts away from the pointer" },
        { "key": "font_scale", "kind": "number", "min": 0.85, "max": 1.40, "default": 1.0,
          "why": "GTK Settings > Accessibility writes 0.85-1.40; outside that the type blows up or vanishes" }
      ]
    },
    {
      "from": 2,
      "to": 3,
      "note": "the control paint gets its own speed (TRK-3361)",
      "rules": [
        { "key": "swirl_control_speed", "kind": "number", "min": 0.15, "max": 1.0, "default": 0.55,
          "why": "0 freezes a control mid-fold, which is the frozen-frame defect TRK-2989 fixed; above 1.0 a 132px pill is faster than the 2304px bar it is quoting" }
      ]
    },
    {
      "from": 3,
      "to": 4,
      "note": "ui_font_scale folds into font_scale (TRK-3463/TRK-3436) — a pre-fix Fonts choice carries instead of silently orphaning",
      "rules": [
        { "key": "ui_font_scale", "kind": "rename", "to": "font_scale",
          "why": "TRK-3463 unified the two spellings of one fact; the value a person set on Fonts must reach the surviving key" },
        { "key": "font_scale", "kind": "number", "min": 0.85, "max": 1.40, "default": 1.0,
          "why": "the 1->2 range, re-stated AFTER the rename so a carried value from Fonts' old 0.8-2.0 slider is judged by the same rule as everything else — out of range drops to the shipped default, never a silent clamp" }
      ]
    }
  ]
};
/* SETTINGS-SCHEMA-TABLE-END */

var CURRENT = TABLE.current;
var VERSION_KEY = "schema_version";

// The version a document claims. A missing or unusable key is 1: every file
// written before this table existed is a version-1 file.
function versionOf(doc) {
    if (!doc || typeof doc !== "object")
        return 1;
    var v = Number(doc[VERSION_KEY]);
    return (v === v && v >= 1) ? Math.floor(v) : 1;
}

function _isNumber(v) {
    return typeof v === "number" && v === v;
}

// Does `value` satisfy `rule`? Absent keys are never judged: the caller only
// asks about keys that exist, and an absent key is the default already.
function ruleAccepts(rule, value) {
    if (rule.kind === "enum") {
        for (var i = 0; i < rule.allowed.length; ++i)
            if (rule.allowed[i] === value)
                return true;
        return false;
    }
    if (rule.kind === "number") {
        if (!_isNumber(value))
            return false;
        if (rule.min !== undefined) {
            if (rule.minExclusive ? !(value > rule.min) : !(value >= rule.min))
                return false;
        }
        if (rule.max !== undefined) {
            if (rule.maxExclusive ? !(value < rule.max) : !(value <= rule.max))
                return false;
        }
        return true;
    }
    // A rename accepts nothing: the old key is always removed.
    return false;
}

// Apply one migration's rules to a COPY of `doc`. Returns
// { doc, changes: [ {key, action, from, to?, reason?} ] }. Pure — nothing
// here touches a file, which is what makes it runnable under `qml` and
// mirrorable in python.
function applyRules(doc, rules) {
    var next = {};
    for (var k in doc)
        next[k] = doc[k];
    var changes = [];
    for (var r = 0; r < rules.length; ++r) {
        var rule = rules[r];
        if (!(rule.key in next))
            continue;
        var value = next[rule.key];
        if (rule.kind === "rename") {
            if (!(rule.to in next)) {
                next[rule.to] = value;
                changes.push({ key: rule.key, action: "rename", from: value, to: rule.to });
            } else {
                changes.push({ key: rule.key, action: "drop", from: value,
                               reason: "renamed target " + rule.to + " already present" });
            }
            delete next[rule.key];
            continue;
        }
        if (!ruleAccepts(rule, value)) {
            delete next[rule.key];
            changes.push({ key: rule.key, action: "drop", from: value,
                           reason: "outside " + rule.kind + " rule; shipped default "
                                   + JSON.stringify(rule["default"]) + " applies" });
        }
    }
    return { doc: next, changes: changes };
}

// Walk the ordered table from the document's version to CURRENT. Returns
// { doc, from, to, changes, needed } — `needed` is true when the store owes
// the file a write (version behind, or a rule dropped something). A document
// already at CURRENT comes back untouched with needed=false, which is the
// idempotence the store relies on to not loop on its own write.
function migrate(doc) {
    var from = versionOf(doc);
    var cur = {};
    for (var k in doc)
        cur[k] = doc[k];
    var changes = [];
    var at = from;
    for (var i = 0; i < TABLE.migrations.length; ++i) {
        var m = TABLE.migrations[i];
        if (m.from !== at)
            continue;
        var res = applyRules(cur, m.rules);
        cur = res.doc;
        for (var c = 0; c < res.changes.length; ++c) {
            res.changes[c].step = m.from + "->" + m.to;
            changes.push(res.changes[c]);
        }
        at = m.to;
    }
    var needed = (at !== from) || changes.length > 0
                 || Number(cur[VERSION_KEY]) !== at;
    if (needed && Number(cur[VERSION_KEY]) !== at) {
        changes.push({ key: VERSION_KEY, action: "set",
                       from: doc[VERSION_KEY], to: at });
        cur[VERSION_KEY] = at;
    }
    return { doc: cur, from: from, to: at, changes: changes, needed: needed };
}

// Same walk, nothing returned but the words. For the console and for
// `SettingsStore.migrationDryRun()`; the log lines are also the format the
// python twin prints, so a human can diff the two by eye.
function dryRun(doc, log) {
    var say = log || function (s) { console.info(s); };
    var res = migrate(doc);
    say("settings schema: version " + res.from + " -> " + res.to
        + (res.needed ? "" : " (nothing to do)"));
    for (var i = 0; i < res.changes.length; ++i) {
        var c = res.changes[i];
        say("  " + (c.step ? c.step + " " : "") + c.action + " " + c.key
            + (c.from !== undefined ? " from " + JSON.stringify(c.from) : "")
            + (c.to !== undefined ? " to " + JSON.stringify(c.to) : "")
            + (c.reason ? " (" + c.reason + ")" : ""));
    }
    return res;
}

// The rule that governs `key` at CURRENT — the last rule in table order, so a
// later schema may tighten an earlier one. Null for a key with no rule.
function ruleFor(key) {
    var found = null;
    for (var i = 0; i < TABLE.migrations.length; ++i) {
        var rules = TABLE.migrations[i].rules;
        for (var r = 0; r < rules.length; ++r)
            if (rules[r].key === key && rules[r].kind !== "rename")
                found = rules[r];
    }
    return found;
}

// Read-time coercion for Prefs.qml: the rule's default for anything the rule
// would drop, the value itself otherwise. A key with no rule passes through.
function coerce(key, value) {
    var rule = ruleFor(key);
    if (!rule)
        return value;
    return ruleAccepts(rule, value) ? value : rule["default"];
}

// Every key that has a rule, for the doc generator and the reset page.
function ruledKeys() {
    var out = [];
    for (var i = 0; i < TABLE.migrations.length; ++i) {
        var rules = TABLE.migrations[i].rules;
        for (var r = 0; r < rules.length; ++r)
            if (out.indexOf(rules[r].key) < 0)
                out.push(rules[r].key);
    }
    return out;
}
