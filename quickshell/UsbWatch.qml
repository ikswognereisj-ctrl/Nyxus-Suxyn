pragma Singleton
// Nyxus Suxyn — the USB watch.   MODULE 3.
//
// ── why this is a shell singleton and not part of the Settings page ─────
// The owner's requirement is a toast when a stick goes in. A settings page is
// alive only while it is open, so a watcher living inside one would notify you
// about a device exactly when you were already looking at the device list. The
// watch belongs in the shell, next to the notification server.
//
// This is also the capability `HANDOFF.md` uses as its own worked example:
// *"a capability needs a package AND something that starts it AND a UI
// surface … `udiskie` installed and never launched"*. `udisks2` is packaged;
// nothing started a watcher and nothing surfaced it. This file is the second
// and third of those three, and `SetPageUsb.qml` is the surface.
//
// ── the backend ─────────────────────────────────────────────────────────
//   `udevadm monitor --udev --subsystem-match=block`   the event stream
//   `lsblk -J`                                          what is there now
//   `udisksctl mount/unmount/power-off`                 acting on it
//
// **Events trigger a read; nothing polls.** `udevadm monitor` is a blocking
// stream that costs nothing while idle, and `lsblk` runs only when the kernel
// says something changed. That is the shape `HANDOFF.md`'s hyprlock rule
// demands — the two labels that spawned a subprocess every 50 ms starved the
// event loop and cost a hard reset.
//
// ── why the toast is not raised straight from the udev line ─────────────
// A single stick generates a burst: the disk, then each partition, then the
// filesystem. Toasting per line means four toasts for one action. And the udev
// line carries a kernel name (`sdb1`), not "SanDisk Ultra 32G" — the name a
// person recognises is in `lsblk`. So an event only marks the list dirty; a
// short settle window later the list is re-read and the DIFFERENCE is what
// gets announced, once, in words.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: watch

    // ── settings, read live ─────────────────────────────────────────────
    // Written by `SetPageUsb.qml` through `SettingsStore`. Read here rather
    // than passed in, so turning the toasts off takes effect immediately in a
    // running shell with no restart and no IPC.
    readonly property bool notify: SettingsStore.boolValue("usb_notify", true)
    readonly property bool automount: SettingsStore.boolValue("usb_automount", true)
    readonly property string afterPlug: SettingsStore.stringValue("usb_action", "nothing")
    property string pendingOpen: ""

    // Every removable block device present, newest read. One entry per
    // FILESYSTEM (a partition you can actually open), plus whole disks that
    // carry a filesystem directly — which is how a great many USB sticks are
    // formatted, and leaving them out is why some sticks "do not appear".
    property var devices: []

    // True between the first read completing and any later one, so the page can
    // tell "nothing is plugged in" from "we have not looked yet".
    property bool scanned: false

    signal deviceAdded(string label, string path)
    signal deviceRemoved(string label)

    // ── the monitor ─────────────────────────────────────────────────────
    // Runs while either feature that needs it is on. With both off there is no
    // subprocess at all — a feature that costs something forever ships switched
    // off, and one switched off should cost nothing.
    //
    // `stdbuf -oL` matters: udevadm block-buffers when its stdout is a pipe, so
    // without it the first event arrives when 4 KB of events have accumulated,
    // which on a desktop is never.
    Process {
        id: monitor
        running: watch.notify || watch.automount
        command: ["stdbuf", "-oL", "udevadm", "monitor", "--udev",
                  "--subsystem-match=block"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) {
                // UDEV  [12345.678] add      /devices/…/sdb1 (block)
                var m = /^UDEV\s+\[[\d.]+\]\s+(add|remove|change)\s+(\S+)/.exec(line);
                if (!m)
                    return;
                watch._dirty = true;
                settle.restart();
            }
        }

        stderr: SplitParser {
            splitMarker: "\n"
            onRead: function (line) {
                if (String(line).trim() !== "")
                    console.warn("UsbWatch: udevadm — " + line);
            }
        }
    }

    property bool _dirty: false

    // The settle window. Long enough that one stick is one read — a disk plus
    // three partitions plus the filesystem probe land inside 400 ms on every
    // machine this was tried on — and short enough that the toast still feels
    // like a response to the action.
    Timer {
        id: settle
        interval: 700
        repeat: false
        onTriggered: watch.refresh()
    }

    function refresh() { if (!lister.running) lister.running = true; }

    // ── the read ────────────────────────────────────────────────────────
    // `lsblk -J` is JSON, so there is no column parsing to get wrong. `-o` is
    // explicit because lsblk's default column set differs between versions and
    // a page built on the default breaks on somebody else's machine.
    Process {
        id: lister
        running: false
        command: ["lsblk", "-J", "-b", "-o",
                  "NAME,PATH,SIZE,TYPE,RM,HOTPLUG,TRAN,FSTYPE,LABEL,MOUNTPOINT,VENDOR,MODEL"]

        stdout: StdioCollector {
            onStreamFinished: {
                var parsed;
                try {
                    parsed = JSON.parse(String(this.text));
                } catch (e) {
                    console.warn("UsbWatch: lsblk did not return JSON (" + e
                                 + ") — leaving the device list as it was.");
                    return;
                }
                watch._absorb(parsed.blockdevices || []);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (String(this.text).trim() !== "")
                    console.warn("UsbWatch: lsblk — " + String(this.text).trim());
            }
        }
    }

    function _human(bytes) {
        var b = Number(bytes);
        if (!isFinite(b) || b <= 0)
            return "";
        var u = ["B", "KB", "MB", "GB", "TB"];
        var i = 0;
        while (b >= 1024 && i < u.length - 1) { b /= 1024; ++i; }
        return (b >= 10 || i === 0 ? Math.round(b) : b.toFixed(1)) + " " + u[i];
    }

    // The name a person recognises, in the order they would recognise it:
    // the volume label they gave it, then the make and model on the casing,
    // and only then the kernel name.
    function _name(d, parent) {
        if (d.label)
            return String(d.label);
        var src = parent || d;
        var vm = [src.vendor, src.model].filter(function (x) {
            return x && String(x).trim() !== "";
        }).map(function (x) { return String(x).trim(); }).join(" ");
        if (vm !== "")
            return vm;
        return String(d.name);
    }

    // Removable in the sense a person means it: you can pull it out. `rm` is
    // the removable-media bit (card readers, some sticks); `hotplug` covers
    // USB and Thunderbolt attachment, which is what most modern sticks report
    // instead. Either one qualifies; internal NVMe reports neither and is
    // correctly absent from this page.
    function _isRemovable(d) {
        return d.rm === true || d.hotplug === true
               || d.tran === "usb" || d.tran === "mmc";
    }

    function _absorb(tree) {
        var found = [];

        function visit(d, parent) {
            var removable = watch._isRemovable(d)
                            || (parent && watch._isRemovable(parent));
            var kids = d.children || [];

            // A device is offerable when it holds a filesystem. A whole disk
            // with partitions is a container, not a thing you open — but a
            // whole disk formatted directly IS, and that case is common enough
            // on USB sticks that skipping it looks like a bug.
            if (removable && d.fstype && String(d.fstype) !== ""
                    && String(d.fstype) !== "swap") {
                found.push({
                    name: watch._name(d, parent),
                    path: String(d.path),
                    kernel: String(d.name),
                    size: watch._human(d.size),
                    fstype: String(d.fstype),
                    mount: d.mountpoint ? String(d.mountpoint) : "",
                    bus: d.tran ? String(d.tran)
                                : (parent && parent.tran ? String(parent.tran) : "")
                });
            }
            for (var i = 0; i < kids.length; ++i)
                visit(kids[i], d);
        }

        for (var i = 0; i < tree.length; ++i)
            visit(tree[i], null);

        // ── the difference, which is the only thing worth announcing ────
        var before = {};
        for (var b = 0; b < watch.devices.length; ++b)
            before[watch.devices[b].path] = watch.devices[b];

        var after = {};
        for (var a = 0; a < found.length; ++a)
            after[found[a].path] = found[a];

        var first = !watch.scanned;
        watch.devices = found;
        watch.scanned = true;
        watch._dirty = false;

        // The first read is what is ALREADY plugged in. Announcing those would
        // greet every login with a stack of toasts for things the user has not
        // touched, which is precisely the notification behaviour people turn
        // off and never turn back on.
        if (first)
            return;

        for (var k in after) {
            if (before[k])
                continue;
            var dev = after[k];
            if (watch.notify) {
                // TRK-3191: one door. Quiet/DND is Sys.announce's job.
                Sys.announce(dev.name,
                             dev.mount !== ""
                             ? "Connected · ready at " + dev.mount
                             : "Connected · " + dev.size + " " + dev.fstype,
                             "Removable drive",
                             "device-added");
            }
            watch.deviceAdded(dev.name, dev.path);
            if (watch.automount && dev.mount === "")
                watch.mount(dev.path);
            if (watch.afterPlug === "files") {
                if (dev.mount !== "")
                    watch._openFiles(dev.mount);
                else
                    watch.pendingOpen = dev.path;
            }
        }

        if (watch.pendingOpen !== "") {
            var opened = after[watch.pendingOpen];
            if (!opened)
                watch.pendingOpen = "";
            else if (opened.mount !== "") {
                watch._openFiles(opened.mount);
                watch.pendingOpen = "";
            }
        }

        for (var j in before) {
            if (after[j])
                continue;
            if (watch.notify) {
                Sys.announce(before[j].name, "Safely removed",
                             "Removable drive", "device-removed");
            }
            watch.deviceRemoved(before[j].name);
        }
    }

    // ── acting on a device ──────────────────────────────────────────────
    // `udisksctl` rather than `mount`: it goes through the udisks2 daemon over
    // D-Bus, which mounts under `/run/media/$USER` with the right ownership and
    // needs no sudo and no fstab line. `mount(8)` from a desktop shell would
    // need root and is how a settings app ends up wanting a password.
    //
    // One process, reused. A queue is not worth building for an action a person
    // takes one at a time, but the busy flag has to be honest, so the last
    // requested path is remembered for the message.
    property string busyPath: ""
    property string lastError: ""

    Process {
        id: actor
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                var msg = String(this.text).trim();
                watch.lastError = msg;
                if (msg !== "")
                    console.warn("UsbWatch: " + msg);
            }
        }
        onRunningChanged: {
            if (actor.running)
                return;
            watch.busyPath = "";
            // The kernel will emit its own event for a successful mount, but
            // not always for a failure, and the page must not be left showing
            // a stale state either way.
            watch.refresh();
        }
    }

    function _openFiles(mount) {
        if (watch.afterPlug !== "files" || !mount)
            return;
        Quickshell.execDetached(["xdg-open", String(mount)]);
    }

    function mount(path) {
        if (actor.running)
            return;
        watch.lastError = "";
        watch.busyPath = path;
        actor.command = ["udisksctl", "mount", "--no-user-interaction", "-b", path];
        actor.running = true;
    }

    function unmount(path) {
        if (actor.running)
            return;
        watch.lastError = "";
        watch.busyPath = path;
        actor.command = ["udisksctl", "unmount", "--no-user-interaction", "-b", path];
        actor.running = true;
    }

    // Unmount, then cut power to the whole drive — the "safely remove" a person
    // means. Chained in one shell because the second only makes sense if the
    // first succeeded, and the parent disk is what powers down, not the
    // partition: `/dev/sdb1` powered off is not a thing.
    function eject(path) {
        if (actor.running)
            return;
        watch.lastError = "";
        watch.busyPath = path;
        if (watch.notify) {
            Sys.announce("Ejecting",
                         "Wait until it disappears, then unplug.",
                         "Removable drive",
                         "notification");
        }
        actor.command = ["sh", "-c",
            'p="$1"; '
          + 'udisksctl unmount --no-user-interaction -b "$p" 2>/dev/null; '
          + 'disk=$(lsblk -no PKNAME "$p" 2>/dev/null); '
          + '[ -n "$disk" ] && p="/dev/$disk"; '
          + 'exec udisksctl power-off --no-user-interaction -b "$p"',
            "sh", path];
        actor.running = true;
    }

    // Read once at startup so the list is populated before anyone opens the
    // page, and so the first plug-in has something to be a difference FROM.
    Component.onCompleted: watch.refresh()

    // Desktop Recents/USB pane calls these. Every function returns a STRING:
    // `qs ipc call` exits 0 even when the target is missing.
    IpcHandler {
        target: "usb"
        function listDevices(): string {
            return JSON.stringify(watch.devices);
        }
        function ejectDev(path: string): string {
            var p = String(path || "");
            if (!p.length)
                return "missing";
            watch.eject(p);
            return "ejecting";
        }
        function unmountDev(path: string): string {
            var p = String(path || "");
            if (!p.length)
                return "missing";
            watch.unmount(p);
            return "unmounting";
        }
        function ready(): string { return "ready"; }
    }
}
