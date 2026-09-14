pragma ComponentBehavior: Bound
// Vector app marks sampled by CrystalGem; no bitmap icon assets are required.
import QtQuick

Canvas {
    id: seal

    property string iconName: ""

    // Theme tokens, not literals (repo rule: Theme.qml owns colour), and the
    // bindings make the seal repaint when Settings ▸ Appearance ▸ Theme
    // flips — the glyph stays the readable near-white, the glow rides the
    // look (ice hot ↔ magma hot).
    property color glyphColor: Theme.text
    property color glowColor: Theme.lookHot

    implicitWidth: 128
    implicitHeight: 128
    renderTarget: Canvas.Image
    antialiasing: true

    onIconNameChanged: requestPaint()
    onGlyphColorChanged: requestPaint()
    onGlowColorChanged: requestPaint()

    function stroke(ctx, width) {
        ctx.lineWidth = width
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.strokeStyle = glyphColor
    }

    function roundedRect(ctx, x, y, w, h, r) {
        ctx.beginPath()
        ctx.moveTo(x + r, y)
        ctx.lineTo(x + w - r, y)
        ctx.quadraticCurveTo(x + w, y, x + w, y + r)
        ctx.lineTo(x + w, y + h - r)
        ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h)
        ctx.lineTo(x + r, y + h)
        ctx.quadraticCurveTo(x, y + h, x, y + h - r)
        ctx.lineTo(x, y + r)
        ctx.quadraticCurveTo(x, y, x + r, y)
        ctx.closePath()
    }

    onPaint: {
        const ctx = getContext("2d")
        const w = width
        const h = height
        const c = w / 2
        const s = w / 64
        const name = iconName.toLowerCase()

        ctx.clearRect(0, 0, w, h)
        ctx.save()
        ctx.scale(s, s)
        ctx.shadowColor = glowColor
        ctx.shadowBlur = 5
        stroke(ctx, 3.2)

        if (name.indexOf("files") >= 0 || name.indexOf("archive") >= 0) {
            ctx.beginPath()
            ctx.moveTo(12, 23); ctx.lineTo(27, 23); ctx.lineTo(31, 18)
            ctx.lineTo(52, 18); ctx.lineTo(52, 45); ctx.lineTo(12, 45)
            ctx.closePath(); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(12, 29); ctx.lineTo(52, 29); ctx.stroke()
        } else if (name.indexOf("terminal") >= 0 || name.indexOf("ghostty") >= 0) {
            ctx.beginPath(); ctx.moveTo(17, 18); ctx.lineTo(29, 31); ctx.lineTo(17, 44); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(35, 43); ctx.lineTo(48, 43); ctx.stroke()
        } else if (name.indexOf("media") >= 0 || name.indexOf("video") >= 0) {
            ctx.beginPath()
            ctx.moveTo(12, 34)
            for (let x = 12; x <= 52; x += 5)
                ctx.lineTo(x, 34 + Math.sin((x - 12) * 0.56) * 10)
            ctx.stroke()
        } else if (name.indexOf("settings") >= 0 || name.indexOf("control") >= 0) {
            ctx.beginPath()
            for (let i = 0; i < 16; i++) {
                const a = (i / 16) * Math.PI * 2
                const r = i % 2 ? 14 : 23
                const x = c / s + Math.cos(a) * r
                const y = c / s + Math.sin(a) * r
                i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
            }
            ctx.closePath(); ctx.stroke()
            ctx.beginPath(); ctx.arc(c / s, c / s, 8, 0, Math.PI * 2); ctx.stroke()
        } else if (name.indexOf("calendar") >= 0 || name.indexOf("clock") >= 0) {
            roundedRect(ctx, 15, 15, 34, 35, 4); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(15, 26); ctx.lineTo(49, 26); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(24, 12); ctx.lineTo(24, 20); ctx.moveTo(40, 12); ctx.lineTo(40, 20); ctx.stroke()
        } else if (name.indexOf("mail") >= 0 || name.indexOf("thunderbird") >= 0) {
            roundedRect(ctx, 12, 19, 40, 28, 4); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(13, 21); ctx.lineTo(32, 36); ctx.lineTo(51, 21); ctx.stroke()
        } else if (name.indexOf("brain") >= 0) {
            ctx.beginPath(); ctx.arc(32, 32, 17, 0, Math.PI * 2); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(22, 27); ctx.lineTo(28, 22); ctx.lineTo(35, 28); ctx.lineTo(42, 23)
            ctx.moveTo(22, 37); ctx.lineTo(28, 42); ctx.lineTo(35, 36); ctx.lineTo(42, 41); ctx.stroke()
        } else if (name.indexOf("weather") >= 0) {
            ctx.beginPath(); ctx.arc(25, 25, 8, 0, Math.PI * 2); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(11, 43); ctx.bezierCurveTo(15, 35, 26, 35, 30, 43)
            ctx.bezierCurveTo(35, 32, 50, 36, 50, 44); ctx.lineTo(11, 44); ctx.stroke()
        } else {
            ctx.beginPath()
            ctx.moveTo(32, 12); ctx.lineTo(38, 26); ctx.lineTo(53, 32)
            ctx.lineTo(38, 38); ctx.lineTo(32, 53); ctx.lineTo(26, 38)
            ctx.lineTo(11, 32); ctx.lineTo(26, 26); ctx.closePath()
            ctx.stroke()
            ctx.beginPath(); ctx.arc(32, 32, 5, 0, Math.PI * 2); ctx.stroke()
        }

        ctx.restore()
    }
}
