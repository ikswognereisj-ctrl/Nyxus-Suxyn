pragma Singleton
// NYXUS Daily Driver — shared open/closed state for the shell surfaces.
//
// The taskbar, the Start menu and the quick-settings flyout are three separate
// PanelWindows that must never both be open at once and must be reachable both
// from a click on the bar and from a Hyprland keybind. Rather than have them
// call `qs ipc` back into their own process, they share this one singleton:
// the Bar flips a boolean, the panels bind their visibility to it, and the
// IpcHandler in shell.qml flips the same booleans for the keybinds. One source
// of truth, no round-trip through the CLI.
import Quickshell
import QtQuick

Singleton {
    id: bus

    property bool launcherOpen: false
    property bool flyoutOpen: false
    property bool powerOpen: false
    property bool taskViewOpen: false

    // HORIZON: the Line is one light source, but it is drawn in two windows —
    // the chrome (top layer) and the Spill that casts it up onto the wallpaper
    // (bottom layer). A ShaderEffectSource cannot cross windows, so the two
    // paint fields cannot share a texture; they share their INPUT instead.
    // Everything that feeds the seam emits this, and both fields answer.
    // `nx` is normalised screen x, which is also the hue axis.
    signal paint(real nx)

    // Written by Bar.qml's musicUp (same rise/fall hysteresis as the
    // spectrum FlipPlate). BarSeam binds this so the living paint stands
    // down while the analyser is the face, and comes back when it isn't.
    property bool barMusicUp: false

    // HORIZON §5.2 (the Tell): "launching an app" is a Tell trigger, not just
    // "launching an app from the Row." The Start menu used to close silently
    // on launch — same light as pressing Escape — so the one action a Start
    // menu exists to do left no mark on the seam it rose out of. The Bar
    // answers this the same way it answers every other Bus.*OpenChanged: at
    // the Sigil, the point the menu surfaced from and is returning light to.
    signal appLaunched()

    // Opening one surface always closes the others, so they never overlap.
    function toggleLauncher() {
        clockOpen = false
        usbDockOpen = false
        flyoutOpen = false
        powerOpen = false
        taskViewOpen = false
        emojiOpen = false
        launcherOpen = !launcherOpen
    }


    function toggleCondition() {
        clockOpen = false
        usbDockOpen = false
        launcherOpen = false
        flyoutOpen = false
        powerOpen = false
        taskViewOpen = false
        emojiOpen = false
        conditionOpen = !conditionOpen
    }
    function toggleFlyout() {
        clockOpen = false
        usbDockOpen = false
        launcherOpen = false
        powerOpen = false
        taskViewOpen = false
        emojiOpen = false
        flyoutSection = ""          // a bare toggle means "the whole thing"
        flyoutOpen = !flyoutOpen
    }

    // ── WIP-101 · a glyph opens ITS OWN subject ──────────────────────────
    // The owner: "when I go to click on the little single WiFi or Bluetooth
    // widget I want it to go to just that ... right now if I click on it it
    // brings up the whole notification flyout."
    //
    // Every glyph on the bar used to call toggleFlyout(), so clicking Wi-Fi
    // and clicking the battery did exactly the same thing and you then hunted
    // for your subject in a page of six sections. The click carried
    // information — WHICH subject you wanted — and the shell threw it away.
    //
    // `flyoutSection` carries it instead. Empty means the whole panel, as
    // before. A section name means: open, and put that section at the top,
    // where a person looks first. The surface that owns the layout owns the
    // mapping from name to position — the Flyout did until WIP-127 phase 2,
    // and it is SidePanel's sectionAliases now; the Bar only says what was
    // clicked, which is the one thing the Bar actually knows.
    property string flyoutSection: ""

    function openFlyoutAt(section) {
        clockOpen = false
        usbDockOpen = false
        launcherOpen = false
        powerOpen = false
        taskViewOpen = false
        emojiOpen = false
        // Clicking the SAME glyph again closes, the way a toggle should.
        // Clicking a different one re-aims an open panel rather than shutting
        // it — going Wi-Fi, then Bluetooth, should not need a click in between.
        if (flyoutOpen && flyoutSection === section) {
            flyoutOpen = false
            flyoutSection = ""
            return
        }
        flyoutSection = section
        flyoutOpen = true
        // Re-aim while already open: flyoutOpenChanged will not fire, so tell
        // the panel directly.
        flyoutRetarget(section)
    }

    // Emitted whenever a section is requested on an ALREADY-open panel.
    signal flyoutRetarget(string section)

    // ── the clock surface (WIP-103) ──────────────────────────────────────
    // Its own surface rather than a flyout section: the owner asked to click
    // the clock and "go to the clock", and it is the one readout on this
    // desktop that never hides, so it earns a subject of its own.
    property bool clockOpen: false
    property bool usbDockOpen: false
    function toggleUsbDock() {
        clockOpen = false
        launcherOpen = false
        flyoutOpen = false
        powerOpen = false
        taskViewOpen = false
        emojiOpen = false
        usbDockOpen = !usbDockOpen
    }
    function toggleClock() {
        launcherOpen = false
        flyoutOpen = false
        powerOpen = false
        taskViewOpen = false
        emojiOpen = false
        usbDockOpen = false
        clockOpen = !clockOpen
    }

    // The power menu closes the other two — it takes exclusive keyboard focus,
    // so leaving the launcher open behind it would trap input.
    function togglePower() {
        clockOpen = false
        usbDockOpen = false
        launcherOpen = false
        flyoutOpen = false
        taskViewOpen = false
        emojiOpen = false
        powerOpen = !powerOpen
    }

    function toggleTaskView() {
        clockOpen = false
        usbDockOpen = false
        launcherOpen = false
        flyoutOpen = false
        powerOpen = false
        emojiOpen = false
        taskViewOpen = !taskViewOpen
    }

    // ── the emoji & symbol picker (WIP-704) ──────────────────────────────
    // Super+. — the key Windows uses for the same thing, which is the whole
    // point of a build whose bar is "someone who has never used Linux can
    // boot it and use the machine all day".
    //
    // It joins the mutual exclusion for the same reason the power menu does:
    // it takes the keyboard to run a search field, and leaving the Start menu
    // open behind a surface that owns input is how you trap a keystroke with
    // nowhere to go.
    property bool emojiOpen: false
    signal emojiPicked(string glyph)
    // TRK-1804. Condition is the console half of Settings.
    property bool conditionOpen: false
    function toggleEmoji() {
        clockOpen = false
        usbDockOpen = false
        launcherOpen = false
        flyoutOpen = false
        powerOpen = false
        taskViewOpen = false
        emojiOpen = !emojiOpen
    }

    function closeAll() {
        clockOpen = false
        usbDockOpen = false
        launcherOpen = false
        flyoutOpen = false
        powerOpen = false
        taskViewOpen = false
        emojiOpen = false
    }

    // ── Master Settings (Settings.qml) ───────────────────────────────────
    // Deliberately NOT part of the mutual exclusion above, and not touched by
    // closeAll(). Everything else on this singleton is a layer-shell surface —
    // a transient thing that rises out of the Line and must never overlap its
    // siblings. Settings is a FloatingWindow: an ordinary application window
    // you move, resize, and leave open on one monitor while you change
    // something and watch the result on another. Closing it because someone
    // pressed Super would be the shell reaching into a window it does not own.
    // Session dock for the now-playing card (MediaCrest). Not a Prefs
    // key: a track starting raises the card; the chevron docks it into
    // the Gauge Crest (the same slot notices use). Click the Crest line
    // to raise it again. Cleared when the track goes away.
    property bool mediaCrestDocked: false

    property bool settingsOpen: false

    // Next Cut — glass Notes. Not in closeAll(): it is a FloatingWindow
    // app, same contract as Settings. GTK nyxus_notes.py is retired.
    property bool notesOpen: false
    function openNotes() { notesOpen = true; }
    function toggleNotes() { notesOpen = !notesOpen; }

    property bool calculatorOpen: false
    function openCalculator() { calculatorOpen = true; }
    function toggleCalculator() { calculatorOpen = !calculatorOpen; }

    property bool mediaOpen: false
    function openMedia() { mediaOpen = true; }
    function toggleMedia() { mediaOpen = !mediaOpen; }

    property bool filesOpen: false
    function openFiles() { filesOpen = true; }
    function toggleFiles() { filesOpen = !filesOpen; }

    property bool storeOpen: false
    function openStore() { storeOpen = true; }
    function toggleStore() { storeOpen = !storeOpen; }

    property bool readerOpen: false
    function openReader() { readerOpen = true; }
    function toggleReader() { readerOpen = !readerOpen; }

    property bool calendarOpen: false
    function openCalendar() { calendarOpen = true; }
    function toggleCalendar() { calendarOpen = !calendarOpen; }

    property bool viewerOpen: false
    function openViewer() { viewerOpen = true; }
    function toggleViewer() { viewerOpen = !viewerOpen; }

    property bool archiveOpen: false
    function openArchive() { archiveOpen = true; }
    function toggleArchive() { archiveOpen = !archiveOpen; }

    property bool weatherOpen: false
    function openWeather() { weatherOpen = true; }
    function toggleWeather() { weatherOpen = !weatherOpen; }

    property bool clockAppOpen: false
    function openClockApp() { clockAppOpen = true; }
    function toggleClockApp() { clockAppOpen = !clockAppOpen; }

    property bool screenshotOpen: false
    function openScreenshot() { screenshotOpen = true; }
    function toggleScreenshot() { screenshotOpen = !screenshotOpen; }

    property bool helpOpen: false
    function openHelp() { helpOpen = true; }
    function toggleHelp() { helpOpen = !helpOpen; }

    property bool hardwareOpen: false
    function openHardware() { hardwareOpen = true; }
    function toggleHardware() { hardwareOpen = !hardwareOpen; }

    property bool sysmonOpen: false
    function openSysmon() { sysmonOpen = true; }
    function toggleSysmon() { sysmonOpen = !sysmonOpen; }

    // Brain.qml binds `open` here and its IPC target writes here. This flag
    // was missing: the binding read undefined (the "Unable to assign
    // [undefined] to bool" warning) and the writes landed on a JS expando,
    // so Brain could never actually be opened through the bus.
    property bool brainOpen: false
    function openBrain() { brainOpen = true; }
    function toggleBrain() { brainOpen = !brainOpen; }

    // Which subject to show. Emitted rather than stored, because it is an
    // INSTRUCTION and not a state: storing it would mean the next plain
    // "open Settings" silently reopened whatever was last deep-linked.
    //
    // The key is the same one `nyxus-settings <key>` takes and the same one
    // `SettingsCatalog` files its pages under. Empty means Home.
    signal settingsRequested(string key)

    // ── OWNER RULING 2026-08-19: the click opens QML Settings.qml ──────────
    // 08-14 (WIP-599) routed every click through `nyxus-settings`. On tty1
    // that name resolves to host `~/.local/bin/nyxus-settings` (NYXUS Panel,
    // class `io.nyxus.settings`) because qs PATH starts with
    // `/home/cosmic/.local/bin` — not this window. Measured 17:08: the mapped
    // clients after a Settings click were that panel plus fullscreen
    // `app.nyxus.Screensaver` (stars / orbs). Owner 08-19 later: ONE glass
    // Settings. This function never execs python3, never PATH-launches
    // nyxus-settings, never opens a terminal.
    //
    // Do not set settingsOpen here. Settings.raiseWindow owns mapping.
    // USB 08-26: every Start ▸ Settings click set the flag true, then the
    // signal ran raiseWindow, which saw "already open" and unmapped the
    // window in the same frame — Hyprland logged
    // `focuswindow title:^(Settings)` / "No such window found" on every
    // click, and the owner saw pages that were there but opened nothing.
    function openSettings(key) {
        var k = (key === undefined || key === null) ? "" : String(key);
        settingsRequested(k);
    }

    function toggleSettings() {
        if (settingsOpen)
            settingsOpen = false;
        else
            openSettings("");
    }
}
