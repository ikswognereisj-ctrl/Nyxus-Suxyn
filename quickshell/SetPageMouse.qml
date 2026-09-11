pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Devices ▸ Mouse & touchpad.   MODULE 3.
//
// Backend: Hyprland's `input {}` and `input:touchpad {}`, through
// `HyprApply.qml` — every control here writes a key to `settings.json` and the
// applier pushes the whole set with one `hyprctl --batch`. Read that file's
// header for why the truth lives in the store rather than in a conf shard.
//
// One row per setting. Speed sliders stay sliders. The touchpad card hides
// itself when there is no touchpad. Polling rate is read, not written.
import Quickshell
import Quickshell.Io
import QtQuick

SetPage {
    id: page
    property var entry: null

    title: qsTr("Mouse & touchpad")
    blurb: qsTr("How the pointer moves, how it scrolls, and which buttons do what.")

    property var mice: []
    property var touchpads: []
    property bool probed: false
    property string pollText: ""

    readonly property bool follow: SettingsStore.numberValue("mouse_follow", 1) !== 0

    Process {
        id: devices
        running: false
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var d;
                try {
                    d = JSON.parse(String(this.text));
                } catch (e) {
                    console.warn("Mouse: hyprctl devices did not return JSON — " + e);
                    page.probed = true;
                    return;
                }
                var m = [], t = [];
                var all = d.mice || [];
                for (var i = 0; i < all.length; ++i) {
                    var name = String(all[i].name || "");
                    // libinput names a trackpad "…touchpad"; a few name it
                    // "…synaptics" or "…trackpad". Anything else is a mouse.
                    if (/touchpad|trackpad|synaptics|glidepoint/i.test(name))
                        t.push(all[i]);
                    else
                        m.push(all[i]);
                }
                page.mice = m;
                page.touchpads = t;
                page.probed = true;
            }
        }
    }

    Component.onCompleted: { devices.running = true; polling.running = true; }

    // ══ POINTER ════════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Pointer")
        tone: page.tone
        note: page.probed && page.mice.length === 0
              ? qsTr("No mouse is reported. These still apply — they are system-wide — but nothing is using them yet.")
              : ""

        SetRow {
            title: qsTr("Speed")
            sub: qsTr("How far the pointer travels for the same movement of your hand")

            SetSlider {
                key: "mouse_sensitivity"
                tone: page.tone
                from: -1; to: 1; snap: 0.05; defaultValue: 0
                format: function (v) {
                    if (Math.abs(v) < 0.001) return qsTr("Default");
                    return (v > 0 ? "+" : "") + Math.round(v * 100) + "%";
                }
            }
        }

        SetRow {
            title: qsTr("Acceleration")
            sub: qsTr("Adaptive travels further when you move quickly; Flat is one-to-one")

            SetChoice {
                key: "mouse_accel_profile"
                defaultValue: "adaptive"
                tone: page.tone
                options: [
                    { value: "adaptive", label: qsTr("Adaptive") },
                    { value: "flat",     label: qsTr("Flat") }
                ]
            }
        }

        SetRow {
            title: qsTr("Natural scrolling")
            sub: qsTr("Content follows your fingers instead of the wheel")
            SetSwitch { key: "mouse_natural_scroll"; defaultValue: false; tone: page.tone }
        }

        SetRow {
            title: qsTr("Scroll speed")
            sub: qsTr("Lines moved per notch of the wheel")

            SetSlider {
                key: "mouse_scroll_factor"
                tone: page.tone
                from: 0.2; to: 4.0; snap: 0.1; defaultValue: 1.0
                suffix: "×"
            }
        }

        SetRow {
            title: qsTr("Swap buttons")
            sub: qsTr("Left-handed layout — the right button becomes the primary one")
            SetSwitch { key: "mouse_left_handed"; defaultValue: false; tone: page.tone }
        }

        SetRow {
            title: qsTr("Focus follows pointer")
            sub: qsTr("Windows become active when the pointer moves over them, without a click")
            SetSwitch {
                tone: page.tone
                checked: page.follow
                onToggled: function (v) { SettingsStore.setValue("mouse_follow", v ? 1 : 0); }
            }
        }
    }

    // ══ TOUCHPAD ═══════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Touchpad")
        tone: page.tone
        visible: page.touchpads.length > 0
        note: page.touchpads.length > 0
              ? qsTr("Detected: %1").arg(page.touchpads[0].name) : ""

        SetRow {
            title: qsTr("Tap to click")
            sub: qsTr("A tap counts as a click, without pressing the pad down")
            SetSwitch { key: "touchpad_tap"; defaultValue: true; tone: page.tone }
        }

        SetRow {
            title: qsTr("Natural scrolling")
            sub: qsTr("Content follows your fingers")
            SetSwitch { key: "touchpad_natural_scroll"; defaultValue: true; tone: page.tone }
        }

        SetRow {
            title: qsTr("Ignore while typing")
            sub: qsTr("Stops the cursor jumping when your palm brushes the pad mid-sentence")
            SetSwitch { key: "touchpad_dwt"; defaultValue: true; tone: page.tone }
        }

        SetRow {
            title: qsTr("Scroll speed")
            sub: qsTr("Touchpad scroll speed")

            SetSlider {
                key: "touchpad_scroll_factor"
                tone: page.tone
                from: 0.2; to: 3.0; snap: 0.1; defaultValue: 1.0
                suffix: "×"
            }
        }
    }

    // ══ WHAT IS ATTACHED ═══════════════════════════════════════════════
    SetCard {
        heading: qsTr("Attached devices")
        tone: page.tone

        SetRow {
            visible: page.probed && page.mice.length === 0 && page.touchpads.length === 0
            title: qsTr("Pointer")
            sub: qsTr("No pointing device reported")
        }

        Repeater {
            model: page.mice.concat(page.touchpads)
            delegate: SetRow {
                required property var modelData
                title: String(modelData.name || qsTr("Pointing device"))
                sub: /touchpad|trackpad|synaptics|glidepoint/i.test(String(modelData.name || ""))
                     ? qsTr("Touchpad") : qsTr("Mouse")
                valueText: modelData.defaultSpeed !== undefined
                           ? qsTr("Default speed %1").arg(modelData.defaultSpeed) : ""
            }
        }

        // The directive asks for polling rate. It is genuinely readable — a
        // property of the device's own firmware, not a system setting: there
        // is no control here that changes it, so it is shown as a fact only.
        SetRow {
            title: qsTr("Polling rate")
            sub: page.pollText !== ""
                 ? qsTr("Reported by the device")
                 : qsTr("No USB pointing device is reporting a rate")
            valueText: page.pollText === "" ? "—" : page.pollText
        }
    }

    // bInterval is the poll interval in milliseconds; 1 ms is 1000 Hz. Read
    // from the USB device tree for interfaces the HID driver has claimed as a
    // mouse. Guarded end to end so a machine with no USB mouse — or no
    // /sys/bus/usb at all, in a VM — produces an empty string and not an error.
    Process {
        id: polling
        running: false
        command: ["sh", "-c",
            'out=""; '
          + 'for d in /sys/bus/usb/drivers/usbhid/*/; do '
          + '  [ -e "$d/bInterval" ] || continue; '
          + '  proto=$(cat "$d/bInterfaceProtocol" 2>/dev/null); '
          + '  [ "$proto" = "02" ] || continue; '
          + '  iv=$(cat "$d/bInterval" 2>/dev/null); '
          + '  case "$iv" in ""|*[!0-9]*) continue;; esac; '
          + '  [ "$iv" -gt 0 ] || continue; '
          + '  hz=$((1000 / iv)); '
          + '  out="${out}${hz} Hz "; '
          + 'done; '
          + 'printf "%s" "$out"']
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text).trim();
                page.pollText = t === "" ? "" : t.split(/\s+Hz\s*/).filter(function (x) {
                    return x !== "";
                }).map(function (x) { return x + " Hz"; }).join(" · ");
            }
        }
    }

    SetResetRow {
        what: qsTr("Mouse & touchpad")
        keys: ["mouse_sensitivity", "mouse_accel_profile", "mouse_natural_scroll",
               "mouse_scroll_factor", "mouse_left_handed", "mouse_follow",
               "touchpad_tap", "touchpad_natural_scroll", "touchpad_dwt",
               "touchpad_scroll_factor"]
    }
}
