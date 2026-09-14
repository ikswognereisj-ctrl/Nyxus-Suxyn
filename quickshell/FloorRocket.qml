pragma ComponentBehavior: Bound
import QtQuick

// Neon rocket from the Rocket Lobby mockup — big, hot pink / cyan / gold fire.
Item {
    width: 512
    height: 640

    Canvas {
        anchors.fill: parent
        onPaint: {
            const c = getContext("2d")
            const w = width, h = height
            c.clearRect(0, 0, w, h)
            c.lineJoin = "round"
            c.lineCap = "round"

            // Exhaust
            c.strokeStyle = "#ffea00"
            c.fillStyle = "#ff6b2b"
            c.lineWidth = 10
            c.beginPath()
            c.moveTo(w * 0.42, h * 0.62)
            c.lineTo(w * 0.32, h * 0.92)
            c.lineTo(w * 0.50, h * 0.72)
            c.lineTo(w * 0.68, h * 0.92)
            c.lineTo(w * 0.58, h * 0.62)
            c.closePath()
            c.fill()
            c.strokeStyle = "#00e5ff"
            c.stroke()

            // Body
            c.fillStyle = "#ff2bd6"
            c.strokeStyle = "#00e5ff"
            c.lineWidth = 14
            c.beginPath()
            c.moveTo(w * 0.50, h * 0.08)
            c.lineTo(w * 0.68, h * 0.42)
            c.lineTo(w * 0.62, h * 0.64)
            c.lineTo(w * 0.38, h * 0.64)
            c.lineTo(w * 0.32, h * 0.42)
            c.closePath()
            c.fill()
            c.stroke()

            // Window
            c.fillStyle = "#00e5ff"
            c.beginPath()
            c.arc(w * 0.50, h * 0.34, w * 0.07, 0, Math.PI * 2)
            c.fill()

            // Fins
            c.fillStyle = "#ffea00"
            c.strokeStyle = "#ff2bd6"
            c.lineWidth = 8
            c.beginPath()
            c.moveTo(w * 0.32, h * 0.48)
            c.lineTo(w * 0.12, h * 0.70)
            c.lineTo(w * 0.38, h * 0.62)
            c.closePath()
            c.fill()
            c.stroke()
            c.beginPath()
            c.moveTo(w * 0.68, h * 0.48)
            c.lineTo(w * 0.88, h * 0.70)
            c.lineTo(w * 0.62, h * 0.62)
            c.closePath()
            c.fill()
            c.stroke()
        }
        Component.onCompleted: requestPaint()
    }
}
