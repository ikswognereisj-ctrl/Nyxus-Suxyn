# THE FLOOR — look lock

Owner references in `docs/floor-refs/`. These are the place. Not a frontend
grid. Not Batocera. The building is an 80s/90s multiplex lobby: theater one
wing, arcade the other, you stand in the middle.

Copyrighted photos stay **references**. We build original Nyxus MAGMA
architecture that rhymes with them. We do not ship Cinemarcade / Regal /
Cinemark / Pizza Hut art.

## The plan (this is the main page)

Ref `02-lobby-theatres-concessions-games.png` is the floor plan:

```
        neon tube ceiling  (swirls / rings — MAGMA living paint)
   THEATRES 7–12          CONCESSIONS / INFO           GAMES
   left wing              CENTER LOBBY                 right wing
   (posters, now seating, (kiosk: pins, continue,      (cabinet aisles,
    continue watching)     scores, custom covers)       continue playing)
              \                 |                    /
               \                |                   /
                ---- you stand here, you walk -----
```

Left and right **meet at the center**. You do not pick a menu. You are in
the room.

## What each ref is for

| Ref | Use |
|---|---|
| 02 lobby split | **Master plan.** Theatres left, games right, concessions/info center. |
| 08 / 12 center kiosk | **Main page.** Island in the atrium with screens all around: pins, continue watch/play, top scores, custom covers. Walk around it. |
| 03 concessions | Close-up of the island: neon words, fat column, memphis tile, snack-bar chrome. |
| 04 neon rings | Ceiling over the atrium. Concentric tubes, dark hall, column. |
| 01 arcade aisle | **Arcade wing walk.** Cabinets left and right, vanishing point, squiggle neon on the ceiling, patterned carpet, a far “window” (our MAGMA world). |
| 10 star-ceiling aisle | Same wing, night: starfield ceiling (Headliner), cabinets receding. |
| 11 people at cabs | How it feels when family is there: stools, checker floor, neon wall, not a UI list. |
| 09 poster hall | **Theater wing walk.** Posters recede down a corridor. NOW SEATING. Checker wainscot. |
| 07 games / service | Two doors off the lobby: GAMES one side, service/info the other. Neon columns. |
| 05 memphis | Pattern language: lightning, triangles, rings — carpet, posters, chrome. |
| 06 mall nostalgia | Mood only: one trip, arcade + theater + hangout. Meet at the mall. |
| 13 arcade star rails | Arcade walk: Headliner ceiling, sparkle on the carpet, red/cyan rails on the cabinets. |
| 14 neon arches | Arcade walk: repeating pink arches receding — ceiling ribs, not a flat tunnel. |
| 15 plaza corridor | Atrium connector: cove neon, posters on the wall, benches, stairs as “continue.” |
| 16 theatre 5&6 | Theater walk: real multiplex carpet, numbered doors at the vanishing point. |
| 17 memphis escalator | Atrium floor pattern: diamond tile, fat column, pink/cyan bounce light. |
| 18 concessions arcs | Kiosk lighting: red/blue ceiling arcs over the snack island. |
| 19 mall escalator | **Up from the lobby.** Arcade sign left, radio/shows right, stairs as featured/continue. |
| 20 dense neon arcade | Arcade saturation cap — cabinets glow, floor is memphis circles. Do not flatten. |
| 21 checker blue hall | Theater/service hall: big checker, numbered doors, bounce light on the floor. |
| 22 mall fountain atrium | **Center page, wide.** Island/fountain in the middle, shops on both balconies, you stand in the court. |
| 23 hangout lounge | Living-room off the court: couches, a screen, color walls. Movie night is a *place to sit*, not a list. |
| 24 facing couches | Continue-watching pit: two sofas toward a wall of covers. Memphis circles on the floor. |
| 25 sunken lounge | Lower pit with glowing cubes — hangout below the bar/arcade. |
| 26 lobby pong + cabs | Games in the *court*, not only down the aisle. A table you walk up to. |
| 27 / 28 lava-lamp lounge | Hangout furniture + lava lamp (MAGMA in the room). VHS / pink / painted columns. |
| 29 theatre ring carpet | Theater hall floor: overlapping red/gold rings on dark. Posters along the wall, doors at the end. |
| 30 / 32 teal poster court | Theater wing as a **court**: lightbox posters, star wall, checker tile meeting carpet, blue columns. |
| 31 palace lobby | Scale/mood: you are in a grand room, not a UI chrome. Warm tile, deep vanishing point. |
| 33 poster lightbox row | Theater walk close: framed posters recede, checker wainscot, red cove. Custom covers go *in these frames*. |
| 34 neon disc column | Atrium ceiling: a ring of living swirls around the island column (Swirl in a disc, not a bar strip). |
| 35 atrium now-playing | Center at scale: diamond tile, escalator, NOW PLAYING neon, posters, two levels. The court is tall. |
| 36 deco concession marquee | The island as a **marquee**: art-deco neon, two boards (now playing / now serving). Pins and continue live on those boards, not in tiny cards. |
| 37 glossy pink checker | **Carpet lock.** Black mirror tiles, hot pink/red diamond inlays, blue coves. This is the Floor. |

## Architecture we actually draw (Nyxus)

Hyprland + Quickshell. MAGMA sky stays the glass. No opaque EmulationStation
window over it.

- **Ceiling:** living swirls as the squiggle/ring neon (`Swirl` / BarSeam
  recipe, but overhead — refs 01 and 04). Headliner stars in the arcade
  aisle (ref 10). Not a photo starfield pasted on.
- **Far wall / window:** MAGMA lava world at the vanishing point of the
  arcade aisle (ref 01’s blue window). SkyForeground keep-out, not a flat
  composite.
- **Floor:** **LOCKED** — glossy black checker with pink/blue neon diamond
  inlays (`shaders/floor_tex.frag` on the 3D plane). Ref
  `37-glossy-pink-checker.png`. Do not flatten back to grey glass or MAGMA
  ember.
- **View:** **LOCKED** — real Qt Quick 3D (`Floor3D.qml`), 360° orbit around
  the island. Movies left, counter center, arcade right. MAGMA stays on the
  laptop; HDMI is the multiplex. Refs 38–40 Rocket Lobby.
- **Center island:** 90s multiplex kiosk (refs 08, 12). Faces of the kiosk
  are the main page: Continue, Pins, Top plays, Top watches, Top scores,
  custom covers. Gamepad walks you around it.
- **Left corridor:** poster hall (ref 09) → theater doors. Continue watching
  lives here as lit posters, not a row of file names.
- **Right corridor:** cabinet aisle (refs 01, 10, 11). Systems are cabinets
  you walk between. A enters the focused cabinet (RetroArch). B walks you
  back to the island.
- **Columns / marquees:** neon tubes, fat painted columns (refs 03, 04, 07).
  Nyxus glacier rims on MAGMA chrome — already a house token.

## Camera (how “walk through” works)

2.5D, 1080p, 60 fps, couch distance on the 65".

- Spawn facing the island (center).
- Stick left → theater depth (posters grow, island slides right).
- Stick right → arcade depth (cabinets grow, island slides left).
- Stick forward → into the focused wing.
- B / back → atrium.
- This is parallax + focus scale on layered Quickshell surfaces, same family
  as Headliner / SkyForeground / Swirl. Not a Unity scene. Qt Quick 3D is
  not in this tree; do not add it for v1.

## Audio

Attract-mode bed while you stand in the lobby. Duck when a game or show
starts, resume when you walk back. Original beds under `sounds/`. No ripped
cabinet ROM audio as the OS soundtrack.

## Not the look

- Grey EmulationStation carousel.
- A 2D icon grid with a wallpaper behind it.
- Shipping anyone else’s photos as the room.
- Fire Stick / Pi Zero as this UI.
- Pirate ROM or show packs.

## Next build slices (on this look)

1. Atrium: MAGMA ceiling + island kiosk on HDMI, no ES.
2. Walk left (poster hall) / walk right (cabinet aisle).
3. Arcade launch + return to the island.
4. Theater continue-watch posters (official / owned libraries only).
5. Pins, scores, custom covers on the kiosk faces.
6. Attract music.
7. Gamepad / lid / HDMI audio.
8. Mounted library scan (MSI stays put).
9. ISO.
