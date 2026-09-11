.pragma library
// Nyxus Suxyn — the lyric PHRASE rules.                    TRK-3812 / TRK-3817
//
// Two questions, both pure arithmetic, both extracted here for one reason:
// A GATE HAS TO BE ABLE TO RUN THEM. `MediaSelect.js` set the precedent in
// this same lane — verify-profile gate 14b1 loads the shipped file under
// `qs` and executes its state table, because a gate that greps for
// `_phraseMaxWords` proves nothing and a gate that RUNS the grouping over a
// fixture is the regression test the rule deserves.
//
//   group(words, maxWords, maxChars)   words  → phrases      (MediaSource)
//   freeSpans(cuts, width, pad, gap)   chrome → the gaps     (BarSpectrum)
//   place(spans, wanted, w)            a gap  → an x         (BarSpectrum)
//
// Nothing here touches QML, the player, the clock or the network. Given the
// same inputs it returns the same answer, which is what makes it testable.

// ── 1 · WORDS INTO PHRASES ─────────────────────────────────────────────────
// `words` is the fetcher's schema-2 array: [start, end, text, exact, anchor].
// `anchor` is 1 when the word's START is a literal timestamp off the LRC —
// the first word of a line, or the first word after an A2 marker. It is NOT
// the same question as `exact`; see nyxus-lyrics' header.
//
// Three rules, in this order, and the order is why a phrase reads as language
// rather than as four words that happened to be adjacent:
//
//   1. A PHRASE NEVER CROSSES A LINE. A line is the run between two anchors.
//      The end of one lyric and the start of the next are different thoughts
//      and must not share a card. This is also what makes the FIRST phrase of
//      every line start on a real stamp instead of on arithmetic.
//   2. A LINE IS SPLIT EVENLY, NOT GREEDILY. A 7-word line at max 4 becomes
//      4+3, never 4+3-by-luck and never 4+4+... with an orphan. Greedy
//      chunking leaves a single word alone on screen at the end of every long
//      line, which is the strobe the owner complained about, once per line.
//   3. THE CHARACTER CAP CAN ONLY CUT A CHUNK SHORT. A phrase that will not
//      fit the bar gets drawn smaller or clipped, and both are worse than one
//      word fewer.
//
// A phrase's `exact` is true only when EVERY word in it was A2-timed: one
// estimated word makes the whole span an estimate. A phrase's `anchor` is its
// FIRST word's, because the start is the moment the eye sees.
function group(words, maxWords, maxChars) {
    var units = [];
    var n = words ? words.length : 0;
    var mw = Math.max(1, maxWords | 0);
    var mc = Math.max(1, maxChars | 0);
    var i = 0;
    while (i < n) {
        var j = i + 1;
        while (j < n && words[j][4] !== 1)
            j++;
        var L = j - i;
        var parts = Math.max(1, Math.ceil(L / mw));
        var size = Math.ceil(L / parts);
        var p = i;
        while (p < j) {
            var k = p, chars = 0;
            while (k < j && (k - p) < size) {
                var add = String(words[k][2]).length + (k > p ? 1 : 0);
                if (k > p && chars + add > mc)
                    break;
                chars += add;
                k++;
            }
            if (k === p)                 // a single word longer than the cap:
                k = p + 1;               // it still has to be shown
            var text = String(words[p][2]);
            var exact = words[p][3] === 1;
            for (var q = p + 1; q < k; q++) {
                text += " " + String(words[q][2]);
                exact = exact && words[q][3] === 1;
            }
            units.push([words[p][0], words[k - 1][1], text,
                        exact ? 1 : 0, words[p][4] === 1 ? 1 : 0]);
            p = k;
        }
        i = j;
    }
    return units;
}

// ── 1b · WORDS INTO WHOLE LINES ────────────────────────────────── TRK-3980
// The SAME array, split the SAME way, for a surface with a column instead of
// a strip. `group()` above answers "what four words are being sung"; this
// answers "what is the line", which is what a lyrics PANEL shows.
//
// ⚠ IT SPLITS ON `anchor`, AND SO DOES THE PYTHON. `nyxus_media.py`'s
// `lyric_lines()` (§ THE LYRIC BOOK) is the same loop in the other language,
// and it has to stay the same loop: the Music app's panel and the crest's
// panel show the same song at the same time on this machine, and two
// different ideas of where a line starts would be visible side by side.
//
// ⚠ AND `anchor` IS NOT EXACTLY "LINE". nyxus-lyrics sets it on the first
// word of an LRC line AND on the first word after an A2 `<mm:ss.xx>` marker,
// so on an Enhanced-LRC record this splits mid-line. That is a known,
// bounded inaccuracy: on the owner's cache A2 is absent from every lrclib
// record measured (Not Like Us: `exact` = 1 for ZERO of 905 words), so the
// two coincide for every track this build has actually seen. It is written
// down rather than guessed around, because the alternative — re-deriving
// line breaks from timing gaps — is a second, worse answer to a question the
// document already answers.
//
// Returns [[start, end, text], …]; empty in, empty out.
function lines(words) {
    var out = [];
    var n = words ? words.length : 0;
    var i = 0;
    while (i < n) {
        var j = i + 1;
        while (j < n && words[j][4] !== 1)
            j++;
        var text = String(words[i][2]);
        for (var q = i + 1; q < j; q++)
            text += " " + String(words[q][2]);
        text = text.replace(/^\s+|\s+$/g, "");
        if (text.length > 0)
            out.push([words[i][0], words[j - 1][1], text]);
        i = j;
    }
    return out;
}

// ⚠ WHICH LINE IS BEING SUNG, AND IT HOLDS. A phrase on the bar must VANISH
// between lines (MediaSource § the tick) because a held banner reads as a
// stuck bar. A panel is the opposite: the eye needs somewhere to rest, so
// the last line stays lit until the next one starts — up to `hold` seconds,
// after which a long instrumental lights nothing rather than pretending the
// final word of the verse is still going.
//
// Mirrors `LyricBook.index_at()` in nyxus_media.py, hold and all.
function lineAt(ls, pos, hold) {
    var n = ls ? ls.length : 0;
    var hit = -1;
    for (var i = 0; i < n; i++) {
        if (ls[i][0] > pos)
            break;
        hit = i;
    }
    if (hit >= 0 && pos > ls[hit][1] + hold)
        return -1;
    return hit;
}

// ── 2 · THE BAR'S CHROME INTO THE GAPS BETWEEN IT ──────────────────────────
// `cuts` are the keep-out spans, already in the caller's own x. `gap` is the
// clearance a phrase keeps from a control it stands beside — zero would be
// legal and would still read as crowding. Widest run first, because the
// caller shrinks to the widest before it places.
function freeSpans(cuts, width, pad, gap) {
    var norm = [];
    for (var i = 0; i < (cuts ? cuts.length : 0); i++) {
        var k = cuts[i];
        if (!k || k.length < 2)
            continue;
        var a = Math.max(pad, k[0] - gap);
        var b = Math.min(width - pad, k[1] + gap);
        if (b > a)
            norm.push([a, b]);
    }
    norm.sort(function (u, v) { return u[0] - v[0]; });
    var free = [];
    var x = pad;
    for (var m = 0; m < norm.length; m++) {
        if (norm[m][0] > x)
            free.push([x, norm[m][0]]);
        x = Math.max(x, norm[m][1]);
    }
    if (width - pad > x)
        free.push([x, width - pad]);
    free.sort(function (u, v) { return (v[1] - v[0]) - (u[1] - u[0]); });
    return free;
}

// ── 3 · WHERE A PHRASE `w` PX WIDE ACTUALLY GOES ───────────────────────────
// `wanted` is where the spread WOULD like the phrase centred — the hash that
// makes the line walk the bar. It is a preference, not the answer.
//
// Preference order: a run that fits and contains the wanted point; then the
// fitting run whose nearest legal centre is closest to it; then, when nothing
// fits even after the caller shrank the text, the widest run, centred — so
// the overhang is symmetric rather than all on one control.
//
// Returns the phrase's LEFT edge.
function place(spans, wanted, w) {
    var half = w / 2;
    var best = null, bestD = Infinity;
    for (var i = 0; i < (spans ? spans.length : 0); i++) {
        if (spans[i][1] - spans[i][0] < w)
            continue;
        var lo = spans[i][0] + half, hi = spans[i][1] - half;
        var at = Math.max(lo, Math.min(hi, wanted));
        var d = Math.abs(at - wanted);
        if (d < bestD) { bestD = d; best = at; }
    }
    if (best !== null)
        return best - half;
    if (spans && spans.length > 0)
        return spans[0][0] + (spans[0][1] - spans[0][0] - w) / 2;
    return 0;
}
