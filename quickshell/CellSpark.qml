// Nyxus Suxyn — a HISTORY as segmented cells. The vertical sibling of
// CellMeter, and the QML twin of `nyxus_cells.cell_field`.
//
// ⚠ ONE DEFINITION. Same rule as CellMeter and `nyxus_cells.py`: the cell is
// a material, and `nyxus_media.py`'s hand-rolled second glass recipe
// (TRK-3275/TRK-3371) is the recorded cost of letting a material exist in two
// places. Instantiate this; do not re-cut the geometry into a Canvas.
//
// ── WHAT THIS REPLACED, AND WHY IT WAS THE FLATTEST THING ON THE SCREEN ─
// `Widgets.qml`'s ChipSpark was a Canvas drawing a 1.4 px polyline in
// `glacier[5]` and nothing else. It is the exact object
// `DESIGN_DEPTH_2026-09-06` names twice:
//
//   rule 5  "A 1px line on a flat ground is the flattest thing on the screen."
//   rule 4  its colour never moved, so a processor at 8% and one at 96% drew
//           the same picture in the same cyan.
//
// It also repainted the whole Canvas on every samples change — a full
// software rasterisation of the strip, several times a minute, per chip.
// Retained Rectangles do that work once and then nothing.
//
// ── WHY THE HUE IS PER COLUMN AND NOT PER POSITION ────────────────────
// Measured out of the owner's reference image: hue is CONSTANT down each
// column and varies BETWEEN columns. It varies with x there because that
// image is a spectrum analyser and x is frequency. Here x is time, so the
// same variation is produced by driving hue from each column's own VALUE —
// which gives his multi-coloured field and makes every colour of it
// information. The full argument is in `nyxus_cells.py`'s header; it is
// stated once there and referenced here rather than restated, because two
// copies of a rationale drift the same way two copies of a recipe do.
import QtQuick

Item {
    id: spark

    property var samples: []
    // ⚠ THE SCALE DEFAULTS TO 100 AND THAT IS LOAD-BEARING, NOT A GUESS.
    // The first version defaulted to 0, meaning "scale to my own peak", and
    // the harness capture showed what that does: every field drew FULL and
    // entirely magma, because a self-scaled history's tallest column is by
    // definition 100% of itself. A memory history idling at 57% rendered as
    // a solid wall of "this matters". That is the very defect this whole
    // piece of work exists to remove — a colour that does not mean anything
    // — reintroduced by a normalisation.
    //
    // Every history this draws is a PERCENTAGE (`Sys.histCpu`, `histMem`,
    // `histDisk`, `histNet` are all `*Percent`), so 100 is the true scale.
    // `histTemp` is degrees Celsius and takes the same number for a
    // different reason that lands in the same place: 60 C is worth a glance
    // and 85 C is throttling, so the band EDGES are degrees while the
    // meaning — calm, busy, hot — is identical. One vocabulary, two scales,
    // exactly as `nyxus_sysmon_gtk.temp_color` puts it.
    //
    // Set it to 0 only for a series with no natural ceiling, and then set
    // `banded: false` too — banding a self-scaled series is meaningless.
    property real maxValue: 100
    // Rule 4 off. For a series whose magnitude is not a load: the standing
    // example is BATTERY, where the scale is inverted (95% is good, 8% is
    // the emergency) so banding by magnitude would paint a full battery
    // magma and a dying one glacier.
    property bool banded: true
    property color plainColor: Theme.paintLayers.glacier[5]

    implicitHeight: 16

    readonly property color calmColor: Theme.paintLayers.glacier[5]
    readonly property color busyColor: Theme.goldGlow
    readonly property color hotColor:  Theme.paintLayers.magma[5]

    // The reference's own density: 47 columns across 335 px, a 6 px pitch.
    // Below that there is nothing left to segment and a field becomes a
    // hairline smear — a defect found by capturing Monitor on the owner's
    // real screen, where a 120-sample history in 270 px drew 1.2 px columns.
    readonly property real minCol: 6.0
    readonly property int cols: Math.max(1, Math.floor(width / minCol))

    // AGGREGATED BY MAXIMUM, never by average. This is a monitor: the reason
    // to look at one is the spike, and an average of a bucket holding a 100%
    // spike reads about 40% and loses the event. A graph that quietly hides
    // the thing you opened it for is worse than no graph.
    readonly property var bins: {
        const s = spark.samples || [];
        const n = s.length;
        if (n === 0)
            return [];
        const k = Math.min(spark.cols, n);
        let out = [];
        for (let i = 0; i < k; ++i) {
            let a = Math.floor(i * n / k);
            let b = Math.max(a + 1, Math.floor((i + 1) * n / k));
            let m = 0;
            for (let j = a; j < b; ++j) {
                const v = Number(s[j]) || 0;
                if (v > m)
                    m = v;
            }
            out.push(m);
        }
        return out;
    }
    readonly property real peak: {
        if (spark.maxValue > 0)
            return spark.maxValue;
        let m = 1;
        for (let i = 0; i < spark.bins.length; ++i)
            if (spark.bins[i] > m)
                m = spark.bins[i];
        return m;
    }

    readonly property real colStep: bins.length > 0 ? width / bins.length : width
    readonly property real colW: Math.max(1, colStep - 1)
    // Same dot-zone rule as the Cairo side: a cell never lands near square,
    // or the field reads as a dot-matrix printout instead of as capsules.
    // At 16 px tall with ~5 px columns there is no room for a STACK of
    // upright cells, so these commit to the wide segment — a VU meter's own
    // idiom, and still counted.
    readonly property int cellsPer: Math.max(2, Math.min(6, Math.floor(height / 3.2)))
    readonly property real pitch: height / cellsPer
    readonly property real cellH: Math.max(1.5, pitch * 0.63)

    Repeater {
        model: spark.bins.length
        delegate: Item {
            id: col
            required property int index
            readonly property real frac: Math.max(0, Math.min(1,
                (Number(spark.bins[col.index]) || 0) / spark.peak))
            readonly property int lit: col.frac <= 0 ? 0
                                     : Math.max(1, Math.ceil(col.frac * spark.cellsPer))
            // ONE colour lookup per COLUMN, and it selects between three
            // properties evaluated once on the parent. Never per cell, and
            // never a new QColor — BarSpectrum.qml line ~124 records what
            // that costs when it is got wrong.
            //
            // ⚠ BANDS ON THE RAW VALUE, NOT ON `frac`. `frac` is the column's
            // height after normalisation, and normalising against a series'
            // own peak makes the tallest column read as 100 whatever it
            // actually is. The band must be asked of the READING.
            readonly property real raw: Number(spark.bins[col.index]) || 0
            readonly property color tone: !spark.banded ? spark.plainColor
                : (col.raw < 60 ? spark.calmColor
                : (col.raw < 85 ? spark.busyColor : spark.hotColor))

            x: col.index * spark.colStep
            width: spark.colW
            height: spark.height

            Repeater {
                model: col.lit
                delegate: Rectangle {
                    required property int index
                    width: col.width
                    height: spark.cellH
                    y: col.height - (index + 1) * spark.pitch
                       + (spark.pitch - spark.cellH) / 2
                    radius: Math.min(width, height) / 2
                    color: col.tone
                }
            }
        }
    }
}
