pragma Singleton
// Nyxus Suxyn — the settings CATALOG.
//
// Owner 2026-08-19: ONE glass Settings. Hub is six tiles; every row in
// this list has a QML page. Keys stay the same ids the shell already
// deep-links (`datetime`, `dock`, `network`, `compositor`, …). GTK
// nyxus-settings is letter C and is not launched from this window.
//
// A non-empty `page` is a QML file in this directory, loaded by URL.
import Quickshell
import QtQuick

Singleton {
    id: catalog

    readonly property var categories: [
        { id: "system",   title: qsTr("System"),
          blurb: qsTr("Display, sound, notifications, power, and what the machine is"),
          glyph: "" },
        { id: "personal", title: qsTr("Personalization"),
          blurb: qsTr("How it looks, and where your things sit"),
          glyph: "" },
        { id: "devices",  title: qsTr("Devices & network"),
          blurb: qsTr("Wi-Fi, Bluetooth, and what you plug in"),
          glyph: "" },
        { id: "privacy",  title: qsTr("Privacy & security"),
          blurb: qsTr("Sign in, lock, and what may reach this machine"),
          glyph: "" },
        { id: "accounts", title: qsTr("Account & time"),
          blurb: qsTr("Who you are on this machine, and what the clock says"),
          glyph: "" },
        { id: "access",   title: qsTr("Accessibility"),
          blurb: qsTr("Motion, text size, magnifier, and keeping the screen awake"),
          glyph: "" }
    ]

    // TRK-2300 -- THE CONSOLE, split out of the hub. Owner ruling 2026-08-22,
    // recorded in `design/mockups-0822/README.md`: split the *console*, keep
    // the *config*. The test is not "is it about security" but "does it change
    // WITHOUT me". Updates, Health and Backup change without you, so they are
    // Condition's boards now and they do not get a hub tile or a rail seat.
    //
    // They are NOT deleted. Condition deep-links straight into these pages
    // (`shell/Condition.qml` carries the keys `updates`, `backup`, `health`),
    // so `find()` must keep resolving them and `search()` must keep finding
    // them -- a search word that lands on a page which does not contain the
    // thing is the launcher-honesty defect (TRK-1608), and so is one that
    // lands on nothing at all. This category is therefore REACHABLE but not
    // BROWSABLE: `category()` resolves it so the breadcrumb has a title, and
    // `categories` omits it so the hub stays at six tiles.
    readonly property var consoleCategories: [
        { id: "condition", title: qsTr("Condition"),
          blurb: qsTr("What is happening to the machine, rather than what you set"),
          glyph: "" }
    ]

    readonly property var pages: [
        // TRK-3426: the living-desktop words moved to `wallpaper` with the
        // cards (TRK-1608 — a search word lands on the page that CONTAINS
        // the thing).
        { key: "display", title: qsTr("Display"),
          blurb: qsTr("Resolution, refresh, brightness, Night Light"),
          glyph: "", cat: "system", module: 1, page: "SetPageDisplay.qml",
          keywords: "display,monitor,screen,resolution,refresh,hz,scale,dpi,"
                  + "night light,brightness,rotation,orientation,vrr,gsync,"
                  + "adaptive sync,wifi,bluetooth,sound,printers" },
        { key: "sound", title: qsTr("Sound"),
          blurb: qsTr("Default output without a terminal, input, per-app volume"),
          glyph: "", cat: "system", module: 5, page: "SetPageSound.qml",
          keywords: "sound,audio,volume,speaker,headphones,microphone,mic,"
                  + "input,output,pipewire,pulse,wireplumber,mixer,balance,"
                  + "per app volume,streams,routing,sample rate,"
                  + "default output,no terminal,wifi,bluetooth,display,printers" },
        { key: "notifications", title: qsTr("Notifications"),
          blurb: qsTr("What may interrupt you, Do Not Disturb, toast placement"),
          glyph: "", cat: "system", module: 3, page: "SetPageNotifications.qml",
          keywords: "notification,notifications,toast,alert,banner,dnd,"
                  + "do not disturb,Do Not Disturb,quiet hours,focus,popup,usb alert,"
                  + "how many,stack,corner,top left,top right,bottom left,"
                  + "bottom right,actions,buttons,reply,snooze,time left,progress" },
        { key: "apps", title: qsTr("Apps & defaults"),
          blurb: qsTr("Browser, photos, mail, files — which app opens what"),
          glyph: "", cat: "system", module: 6, page: "SetPageApps.qml",
          keywords: "apps,applications,programs,default,handler,mime,"
                  + "browser,mail,photos,pictures,startup,autostart" },
        { key: "app-notes", title: qsTr("Notes"),
          blurb: qsTr("Notebook type size, sidebar, autosave"),
          glyph: "", cat: "system", module: 6, page: "SetPageNotes.qml",
          group: "Nyxus apps",
          keywords: "notes,notepad,markdown,autosave,sidebar,notebook" },
        { key: "app-calculator", title: qsTr("Calculator"),
          blurb: qsTr("Degrees, grouping, precision, copy on equals"),
          glyph: "", cat: "system", module: 6, page: "SetPageCalculator.qml",
          group: "Nyxus apps",
          keywords: "calculator,degrees,radians,precision,tape" },
        { key: "app-store", title: qsTr("Store"),
          blurb: qsTr("AUR, Flatpak, landing shelf, confirm install"),
          glyph: "", cat: "system", module: 6, page: "SetPageStore.qml",
          group: "Nyxus apps",
          keywords: "store,aur,flatpak,pacman,install" },
        { key: "app-media", title: qsTr("Media"),
          blurb: qsTr("Waveform, resume, repeat — not the bar crest"),
          glyph: "", cat: "system", module: 6, page: "SetPageMedia.qml",
          group: "Nyxus apps",
          keywords: "media,music,waveform,repeat,resume,library" },
        { key: "app-weather", title: qsTr("Weather"),
          blurb: qsTr("Units and the live sky — writes weather.json"),
          glyph: "", cat: "system", module: 6, page: "SetPageWeather.qml",
          group: "Nyxus apps",
          keywords: "weather,fahrenheit,celsius,units,forecast,open-meteo" },
        { key: "app-control", title: qsTr("Hardware"),
          blurb: qsTr("Poll, temperature unit, warn point, landing tab"),
          glyph: "", cat: "system", module: 6, page: "SetPageControl.qml",
          group: "Nyxus apps",
          keywords: "hardware app,control,fan,thermal,rgb,profiles,poll" },
        { key: "app-monitor", title: qsTr("Monitor"),
          blurb: qsTr("Refresh, graph span, per-core, network units"),
          glyph: "", cat: "system", module: 6, page: "SetPageMonitor.qml",
          group: "Nyxus apps",
          keywords: "system monitor,sysmon,cpu,memory,processes,graph" },
        { key: "power", title: qsTr("Power"),
          blurb: qsTr("Saver, Balanced, Performance, and the battery"),
          glyph: "", cat: "system", module: 6, page: "SetPagePower.qml",
          keywords: "power,battery,sleep,suspend,hibernate,lid,timeout,"
                  + "performance,balanced,power saver,ppd,charge,thermal" },
        { key: "storage", title: qsTr("Storage"),
          blurb: qsTr("Disks, free space, and what is mounted"),
          glyph: "", cat: "system", module: 3, page: "SetPageStorage.qml",
          keywords: "storage,disk,drive,ssd,hdd,space,free space,mount,"
                  + "unmount,eject,usb stick,udisks,filesystem,partition,luks,"
                  + "trash,empty trash,recycle,put back" },
        { key: "updates", title: qsTr("Updates"),
          blurb: qsTr("What is waiting. Background check is every 6 hours."),
          glyph: "", cat: "condition", module: 6, page: "SetPageUpdates.qml",
          keywords: "update,updates,upgrade,pacman,packages,firmware,fwupd,"
                  // TRK-1608: `self check`, `verdict`, `roll back this update`
                  // and `boot critical` are deliberately NOT here. They are
                  // Condition's words now (the owner's split-the-console
                  // ruling), and a search word that lands on a page which
                  // does not contain the thing is the launcher-honesty defect.
                  + "snapshot,snapper,reload,restart shell,version" },
        { key: "health", title: qsTr("Health"),
          blurb: qsTr("nyxus doctor and nyxus status as a page — checks, units, a report bundle"),
          glyph: "", cat: "condition", module: 0, page: "SetPageHealth.qml",
          keywords: "health,doctor,status,diagnose,diagnostics,check,checks,"
                  + "daemon,daemons,service,services,unit,units,timer,watcher,"
                  + "portal,portals,keyring,polkit,cliphist,pipewire,wireplumber,"
                  + "networkmanager,greetd,snapper,ntp,time sync,disk space,"
                  + "report,bug report,log,logs,journal,crash,restart,cpu,memory" },
        { key: "about", title: qsTr("About this system"),
          blurb: qsTr("Nyxus Suxyn — edition, kernel, hardware, Horizon glass, ice accent"),
          glyph: "", cat: "system", module: 0, page: "SetPageAbout.qml",
          keywords: "about,system,version,edition,kernel,cpu,memory,ram,"
                  + "hostname,uptime,hardware,gpu,session,compositor,"
                  + "quickshell,specs,info,device" },
        { key: "compositor", title: qsTr("Windowing"),
          blurb: qsTr("Hyprland — floating by default, reload the compositor"),
          glyph: "", cat: "system", module: 2, page: "SetPageCompositor.qml",
          // "blur" and "unfocused" earn their place: the owner has asked for
          // this effect by description rather than by name more than once, so
          // the words he used are the ones that have to find the page.
          keywords: "compositor,hyprland,tiling,floating,workspace,window,"
                  + "reload,hyprctl,blur,frost,unfocused,inactive,"
                  + "background windows,readable,privacy" },
        // TRK-1261 — resets settings.json only (one page's keys, or all of
        // it after a backup). Not a factory reset, not snapper, not packages;
        // the keywords do not say otherwise.
        { key: "reset", title: qsTr("Reset"),
          blurb: qsTr("Shipped defaults — one page's settings, or every setting, after a backup"),
          glyph: "", cat: "system", module: 0, page: "SetPageReset.qml",
          keywords: "reset,defaults,default settings,restore defaults,reset all,"
                  + "start over,settings file,settings.json,schema,schema version,"
                  + "migration,backup,dry run" },

        // TRK-1703 — THE ROOMS. Keys are read from the Hyprland shard and
        // shown, never rebound here (gate 16dup); the keywords say so.
        { key: "station", title: qsTr("Rooms"),
          blurb: qsTr("Workspaces as a grid you walk through — carry, the map, per-room shelves"),
          glyph: "", cat: "system", module: 2, page: "SetPageStation.qml",
          keywords: "rooms,room,workspaces,grid,walk,carry,shelf,shelves,"
                  + "map,wallpaper per room,wrap,arrival,nameplate,"
                  + "ctrl alt arrows,super g,house,home" },
        { key: "network", title: qsTr("Wi-Fi"),
          blurb: qsTr("Wireless networks — scan, join, forget"),
          glyph: "", cat: "devices", module: 3, page: "SetPageNetwork.qml",
          group: "Connect",
          keywords: "wifi,wi-fi,wireless,network,ethernet,wired,connect,"
                  + "password,forget,known networks,hotspot,tether,proxy,"
                  + "networkmanager,nmcli,airplane mode,dns,ip address,ssid,"
                  + "bluetooth,sound,display,printers,captive portal,hotel wifi,"
                  + "sign in to this network" },
        { key: "bluetooth", title: qsTr("Bluetooth"),
          blurb: qsTr("Pair, connect, forget devices and see battery where reported"),
          glyph: "", cat: "devices", module: 3, page: "SetPageBluetooth.qml",
          group: "Connect",
          keywords: "bluetooth,bt,pair,pairing,connect,headset,earbuds,"
                  + "speaker,mouse,keyboard,bluez,discoverable,trust,"
                  + "wifi,sound,display,printers" },
        { key: "usb", title: qsTr("USB & removable devices"),
          blurb: qsTr("What is plugged in, mount and eject, plug-in notifications"),
          glyph: "", cat: "devices", module: 3, page: "SetPageUsb.qml",
          group: "Plug in",
          keywords: "usb,removable,stick,thumb drive,flash,sd card,mount,"
                  + "unmount,eject,safely remove,udev,udisks,udiskie,"
                  + "notification,toast,autoplay,autorun,external drive" },
        { key: "printers", title: qsTr("Printers & scanners"),
          blurb: qsTr("Discover printers, watch the queue, check ink and paper"),
          glyph: "", cat: "devices", module: 4, page: "SetPagePrinters.qml",
          group: "Plug in",
          keywords: "printer,printers,print,printing,queue,job,jobs,cups,"
                  + "ipp,driverless,scanner,scan,sane,ink,toner,paper,"
                  + "cancel job,clear queue,default printer,duplex,"
                  + "wifi,bluetooth,sound,display" },
        { key: "mouse", title: qsTr("Mouse & touchpad"),
          blurb: qsTr("Pointer speed, acceleration profile, scrolling, polling rate"),
          glyph: "", cat: "devices", module: 3, page: "SetPageMouse.qml",
          group: "Input",
          keywords: "mouse,pointer,cursor speed,acceleration,accel,flat,"
                  + "adaptive,sensitivity,dpi,polling rate,touchpad,trackpad,"
                  + "tap to click,natural scrolling,precision,left handed" },
        { key: "keyboard", title: qsTr("Keyboard"),
          blurb: qsTr("Layout, repeat rate and delay, shortcuts, numlock at login"),
          glyph: "", cat: "devices", module: 3, page: "SetPageKeyboard.qml",
          group: "Input",
          keywords: "keyboard,layout,repeat,delay,rate,shortcut,keybind,"
                  + "numlock,capslock,compose,polling,xkb,variant" },

        { key: "shortcuts", title: qsTr("Keyboard shortcuts"),
          blurb: qsTr("Search the keys this machine already uses"),
          glyph: "", cat: "devices", module: 3, page: "SetPageShortcuts.qml",
          group: "Input",
          keywords: "shortcut,hotkey,keybind,super,print,lock,start,screenshot,"
                  + "task view,rooms,keyboard shortcuts,what does super do" },

        // TRK-3693 — THE HARDWARE PAGE. Owner's question, 2026-09-01:
        // "how would we know what a machine will have to whoever downloads
        // it theres alot of machines out there". The page answers it by
        // reading /sys at runtime rather than by shipping a model table,
        // so the keywords have to cover the words people use for hardware
        // that MIGHT NOT BE THERE — somebody searching "fan control" on a
        // machine with no writable pwm must still land on the page that
        // tells them so. A search word that lands on nothing is the
        // launcher-honesty defect (TRK-1608) in its worst form here,
        // because "no result" reads as "this desktop cannot do it".
        { key: "hardware", title: qsTr("This machine's hardware"),
          blurb: qsTr("Fans, heat, brightness, performance mode, charge limit — what this laptop actually exposes"),
          glyph: "", cat: "devices", module: 3, page: "SetPageHardware.qml",
          group: "This machine",
          keywords: "hardware,fan,fans,fan control,fan speed,rpm,cooling,"
                  + "temperature,temp,heat,thermal,sensors,hwmon,pwm,"
                  + "rgb,keyboard light,keyboard backlight,led,leds,"
                  + "performance mode,platform profile,epp,governor,cpufreq,"
                  + "energy preference,turbo,battery limit,charge limit,"
                  + "charge threshold,stop charging at 80,battery health,"
                  + "brightness,backlight,vendor keys,hotkeys,msi,dell,asus,"
                  + "thinkpad,hp,lenovo,acer,laptop,capabilities,what can this "
                  + "machine do" },

        // TRK-3426: this page hosts the Living-desktop and deep-space cards
        // now (moved from Display), so their words live here.
        { key: "wallpaper", title: qsTr("Background"),
          blurb: qsTr("The stills, the sky, and the living desktop"),
          glyph: "", cat: "personal", module: 1, page: "SetPageBackground.qml",
          keywords: "wallpaper,background,desktop picture,image,photo,"
                  + "slideshow,rotation,fit,fill,stretch,live wallpaper,"
                  + "livewall,shader,galaxy,starlight,voyage,magma,glacier,"
                  + "violet,aurora,triad,stills,3d,parallax,mouse tracking,"
                  + "wallpaper effects,shooting stars,nebula,star density" },
        { key: "fonts", title: qsTr("Fonts & text size"),
          blurb: qsTr("System font family, interface text size, weight and rendering"),
          glyph: "", cat: "personal", module: 2, page: "SetPageFonts.qml",
          keywords: "font,fonts,typeface,family,text size,scale,bigger text,"
                  + "smaller,dpi,hinting,antialiasing,subpixel,rgba,"
                  + "inter,jetbrains,monospace,readability" },
        { key: "cursor", title: qsTr("Mouse pointer"),
          blurb: qsTr("Cursor theme, cursor size, and visibility aids"),
          glyph: "", cat: "personal", module: 2, page: "SetPageCursor.qml",
          keywords: "cursor,pointer,mouse pointer,theme,size,big cursor,"
                  + "xcursor,hyprcursor,visibility,arrow,shape" },
        // TRK-3424/3425: blurb and keywords trimmed with the pickers — the
        // sky is picked on Background and the Start style on Taskbar now
        // (this page links to both), and a search word must land on the page
        // that CONTAINS the thing (TRK-1608).
        { key: "appearance", title: qsTr("Appearance"),
          blurb: qsTr("Bar swirls, hover, the music visualizer, lyrics, and the player card"),
          glyph: "", cat: "personal", module: 2, page: "SetPageAppearance.qml",
          keywords: "appearance,theme,look,glass,accent,colour,color,paint,"
                  + "swirl,swirls,animation,motion,transparency,dark,"
                  + "density,shadow,black shadow,"
                  + "swirl mode,media bar,now playing,"
                  + "bar,hover,on hover,lyrics,visualizer,visualiser,"
                  + "music visualizer,music visualiser,bar swirls" },
        { key: "dock", title: qsTr("Taskbar"),
          blurb: qsTr("The Line — Start style, and pinning from a running app"),
          glyph: "", cat: "personal", module: 2, page: "SetPageDock.qml",
          keywords: "taskbar,dock,shelf,bar,pinned,pin,icon size,tray,"
                  // TRK-3424: this page owns `launcher_style` now, so the
                  // Start-menu words land here.
                  + "system tray,clock,autohide,position,line,start,"
                  + "start menu,launcher style,daily,classic,atrium" },
        { key: "widgets", title: qsTr("Desktop widgets"),
          blurb: qsTr("Six chips on the wallpaper — none of them is the bar clock"),
          glyph: "", cat: "personal", module: 2, page: "SetPageWidgets.qml",
          keywords: "widget,widgets,desktop,chip,clock widget,vitals,"
                  + "sticky,note,calendar peek,weather chip,now playing,"
                  + "nowplaying" },

        { key: "account", title: qsTr("Your account"),
          blurb: qsTr("Who is signed in, and this machine's name"),
          glyph: "", cat: "accounts", module: 6, page: "SetPageAccount.qml",
          keywords: "account,user,profile,name,avatar,picture,password,"
                  + "change password,fingerprint,biometric,face,login" },
        { key: "backup", title: qsTr("Backup & rollback"),
          blurb: qsTr("Snapshots on this disk, and the backup that lives off it"),
          glyph: "", cat: "condition", module: 6, page: "SetPageBackup.qml",
          keywords: "backup,snapshot,snapper,btrfs,restore,rollback,"
                  + "recover,timeshift,history,undo update,"
                  // TRK-1601: the off-disk half. These are the words a person
                  // uses for it, and none of them found this page before.
                  + "usb,usb stick,external drive,off disk,destination,"
                  + "target,copy my files,daily backup,schedule,rsync,"
                  + "bring files back,nyxus-backup" },

        { key: "datetime", title: qsTr("Date & time"),
          blurb: qsTr("Clock format on the Line, and following the system zone"),
          glyph: "", cat: "accounts", module: 2, page: "SetPageDatetime.qml",
          keywords: "date,time,clock,timezone,time zone,24 hour,12 hour,"
                  + "am pm,seconds,ntp,network time,calendar,week start,"
                  + "automatic time zone,location,autotz" },

        { key: "access", title: qsTr("Accessibility"),
          blurb: qsTr("Reduce motion, text size, contrast, screen reader, on-screen keyboard, magnifier"),
          glyph: "", cat: "access", module: 6, page: "SetPageAccess.qml",
          keywords: "accessibility,ease of access,a11y,reduce motion,reduced motion,"
                  + "animations,still,large text,text size,font scale,bigger text,"
                  + "contrast,screen reader,orca,speech,read aloud,on-screen keyboard,"
                  + "squeekboard,touch keyboard,magnifier,zoom,lens,keyboard only,"
                  + "assistive,feel" },

        { key: "idle", title: qsTr("Keep awake"),
          blurb: qsTr("When the screensaver and the lock take over"),
          glyph: "", cat: "access", module: 6, page: "SetPageIdle.qml",
          keywords: "idle,away,dim,blank,screen off,inhibit,keep awake,"
                  + "caffeine,presentation mode,timeout,screensaver" },

        { key: "security", title: qsTr("Security"),
          blurb: qsTr("Lock now, sign-in facts, encryption, and what may reach the machine"),
          glyph: "", cat: "privacy", module: 6, page: "SetPageSecurity.qml",
          group: "Sign-in",
          keywords: "security,hemera,firewall,apparmor,scan,clamav,quarantine,"
                  + "lock,lock now,sudo,polkit,encryption,luks,hardening,virus,"
                  + "fingerprint,face,howdy,sign in,password,tpm,secure boot" },
        { key: "screenlock", title: qsTr("Lock screen"),
          blurb: qsTr("What shows while locked, and whether media keys work"),
          glyph: "", cat: "privacy", module: 2, page: "SetPageScreenlock.qml",
          group: "Sign-in",
          keywords: "lock,lock screen,hyprlock,screensaver,idle,timeout,"
                  + "blank,password,clock on lock,media on lock,earth,moon" },
        { key: "privacy", title: qsTr("Privacy"),
          blurb: qsTr("Clipboard history and what shows while locked"),
          glyph: "", cat: "privacy", module: 6, page: "SetPagePrivacy.qml",
          group: "What leaves",
          keywords: "privacy,history,recent files,telemetry,tracking,"
                  + "clear,clipboard history,search history,location,cliphist" },
        { key: "firewall", title: qsTr("Firewall"),
          blurb: qsTr("Unsolicited inbound stays out unless you opt out"),
          glyph: "", cat: "privacy", module: 6, page: "SetPageFirewall.qml",
          group: "What reaches",
          keywords: "firewall,ufw,iptables,nftables,incoming,outgoing,"
                  + "port,allow,deny,rule,open ports,block,firewalld" },
        { key: "secboot", title: qsTr("Secure Boot"),
          blurb: qsTr("Firmware report — on, off, or not UEFI. Not a switch."),
          glyph: "", cat: "privacy", module: 6, page: "SetPageSecboot.qml",
          group: "Firmware",
          keywords: "secure boot,secureboot,uefi,firmware,keys,mok,"
                  + "shim,tpm,measured boot,bios,report" }
    ]

    function find(key) {
        for (var i = 0; i < catalog.pages.length; ++i)
            if (catalog.pages[i].key === key)
                return catalog.pages[i];
        return null;
    }

    function category(id) {
        for (var i = 0; i < catalog.categories.length; ++i)
            if (catalog.categories[i].id === id)
                return catalog.categories[i];
        // Console categories resolve too -- see consoleCategories. A deep
        // link from Condition sets currentCategory to one of these, and a
        // null here is a breadcrumb dereferencing null on the way in.
        for (var k = 0; k < catalog.consoleCategories.length; ++k)
            if (catalog.consoleCategories[k].id === id)
                return catalog.consoleCategories[k];
        return null;
    }

    // Is this category one of the six the hub draws? Derived from the array,
    // never a list of names -- adding a seventh hub tile must not need an
    // edit here as well.
    function isHubCategory(id) {
        for (var i = 0; i < catalog.categories.length; ++i)
            if (catalog.categories[i].id === id)
                return true;
        return false;
    }

    function inCategory(id) {
        var out = [];
        for (var i = 0; i < catalog.pages.length; ++i)
            if (catalog.pages[i].cat === id)
                out.push(catalog.pages[i]);
        return out;
    }

    // Sidebar only. Hub tiles stay a flat page list. A `group` change
    // inserts a non-clickable heading so Privacy is Sign-in / What leaves
    // rather than a filename dump.
    function railInCategory(id) {
        var pages = catalog.inCategory(id);
        var out = [];
        var last = "";
        for (var i = 0; i < pages.length; ++i) {
            var g = pages[i].group || "";
            if (g !== "" && g !== last) {
                out.push({ _sep: true, title: g, key: "", page: "", glyph: "" });
                last = g;
            }
            out.push(pages[i]);
        }
        return out;
    }

    function countIn(id) { return catalog.inCategory(id).length; }

    // TRK-3567 -- the best CONTROL on one page for one term, or null.
    // `SettingsIndex` is generated from the pages themselves
    // (scripts/gen-settings-index.py), so this reaches the real rows and
    // never a hand-typed copy of them.
    //
    // A control's own name outranks its caption by a lot: "MOUSE POINTER"
    // as the name of a stone is the thing you were looking for; the same
    // words buried in a sentence under some other stone are a coincidence.
    // Both stay below a page-title hit (60) and above a page-blurb hit (10),
    // which is the honest ordering -- the page called Sound is still the
    // best answer for "sound", but a page with a row called FOLLOW MUSIC
    // beats a page that merely says "music" in its description.
    function _controlHit(key, term) {
        var controls = SettingsIndex.forKey(key);
        var best = null;
        var bestScore = 0;
        for (var i = 0; i < controls.length; ++i) {
            var c = controls[i];
            var label = String(c.label).toLowerCase();
            var sub = String(c.sub || "").toLowerCase();
            var v = 0;
            if (label.indexOf(term) === 0)     v = 55;
            else if (label.indexOf(term) >= 0) v = 40;
            else if (sub.indexOf(term) >= 0)   v = 15;
            if (v > bestScore) { bestScore = v; best = c; }
        }
        return bestScore > 0 ? { s: bestScore, c: best } : null;
    }

    // Returns catalogue rows, each COPIED and carrying an extra `hit`: the
    // control that earned the match, or null when the page metadata alone
    // matched. The copy matters -- `pages` is readonly and shared, and a
    // search must not leave a `hit` stuck on it for the next one.
    function search(q) {
        var terms = String(q).toLowerCase().split(/\s+/).filter(function (t) {
            return t.length > 0;
        });
        if (terms.length === 0)
            return [];

        var scored = [];
        for (var i = 0; i < catalog.pages.length; ++i) {
            var p = catalog.pages[i];
            var title = p.title.toLowerCase();
            var blurb = p.blurb.toLowerCase();
            var words = (p.keywords + "," + p.key).toLowerCase();
            var score = 0;
            var missed = false;
            var hit = null;
            var hitScore = 0;

            for (var t = 0; t < terms.length; ++t) {
                var term = terms[t];
                if (title.indexOf(term) === 0)        score += 100;
                else if (title.indexOf(term) >= 0)    score += 60;
                else if (words.indexOf(term) >= 0)    score += 25;
                else {
                    // The page said nothing. Ask the rows ON the page --
                    // this is the whole of TRK-3567: "music" and "beat"
                    // are not in any keyword string and never will be,
                    // but FOLLOW MUSIC is a stone on Appearance.
                    var ch = catalog._controlHit(p.key, term);
                    if (ch !== null) {
                        score += ch.s;
                        if (ch.s > hitScore) { hitScore = ch.s; hit = ch.c; }
                    }
                    else if (blurb.indexOf(term) >= 0) score += 10;
                    else { missed = true; break; }
                }
            }
            if (missed)
                continue;
            if (p.page !== "")
                score += 5;
            scored.push({ p: p, s: score, hit: hit });
        }

        scored.sort(function (a, b) { return b.s - a.s; });
        var out = [];
        for (var j = 0; j < scored.length; ++j) {
            var row = Object.assign({}, scored[j].p);
            row.hit = scored[j].hit;
            out.push(row);
        }
        return out;
    }

    readonly property int builtCount: {
        var n = 0;
        for (var i = 0; i < catalog.pages.length; ++i)
            if (catalog.pages[i].page !== "")
                ++n;
        return n;
    }
    readonly property int totalCount: catalog.pages.length

    // TRK-2300 -- what the hub actually holds, as against every page that
    // exists. `totalCount` still counts the console pages because search
    // still reaches them and the "searched N pages" line must not lie.
    readonly property int hubPageCount: {
        var n = 0;
        for (var i = 0; i < catalog.pages.length; ++i)
            if (catalog.isHubCategory(catalog.pages[i].cat))
                ++n;
        return n;
    }
    readonly property int hubCategoryCount: catalog.categories.length
}
