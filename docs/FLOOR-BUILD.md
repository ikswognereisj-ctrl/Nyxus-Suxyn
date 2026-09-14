# THE FLOOR — how we build it (same craft as MAGMA)

The lobby is not a video, not a photo of Cinemarcade, and not EmulationStation
with a wallpaper behind it. It is the same stack that made MAGMA: **compositor
layers + GPU shaders + empty masks + one sky**.

Look lock: `docs/FLOOR-LOOK.md`. Architecture spec: the Floor design draft.
This file is the **craft** — how it stays smooth.

## MAGMA already proved the method

| MAGMA | Floor |
|---|---|
| Headliner = stars (Background, opaque black gaps) | Same. Ceiling of the room. Never a photo starfield. |
| SkyForeground = lava planet (Bottom, transparent air) | Same. The far “window” at the aisle vanishing point. |
| LiveWall **off** for magma planet (two skies = two full-screen passes) | Same. One sky. Floor does not add a second starfield. |
| Swirl = Navier–Stokes dye, **strip** not full-screen, sleeps when idle | Ceiling neon = Swirl in a **top band**, not a second full-screen solver. |
| Pane.frag = one pass, premultiplied add-light rims | Kiosk / marquees = Pane + MagmaSlab. No CSS boxes. |
| `mask: Region {}` so wallpaper never eats clicks | Floor air is click-through. Only the kiosk / cabinets take input. |
| 1080p HDMI (4K made UI tiny) | Floor is authored at 1920×1080. No 4K UI. |
| Empty `Variants` model = nothing instantiated | Wings that you are not in do not exist. |

`shell.qml` already says it: two full-screen shaders for one visible result
is the cost we refused for Voyage vs Headliner. The Floor does not get a
third sky.

## Layer stack on the TV

```
Overlay     menus (off in arcade)
Top         FLOOR (transparent air + carpet shader + kiosk)
Bottom      SkyForeground lava plate
Background  Headliner stars
```

ES was an opaque X11 window on Top. That is why MAGMA vanished. Floor is a
**transparent** layer-shell surface. Stars and the planet stay the room.

## Smooth as butter (hard gates)

- **1080p @ 60.** Below 45 fps on the 780M, the technique is wrong — drop it,
  do not “optimize later.”
- **One floor shader, one pass.** Perspective carpet + ceiling squiggles in
  `shaders/floor.frag`. No CPU tile drawing.
- **Swirl only in the ceiling band** (~28% of height). Full-screen NS on 4K
  is how Voyage got expensive.
- **FrameAnimation off when idle** (same linger as Swirl). Hidden = not
  running.
- **Wings are Loaders.** Theater and arcade trees do not exist until you
  walk into them.
- **No ES** while Floor is up.
- **Integer 1× scale.** HDMI forced 1920×1080@60.

## Walk (2.5D, not a game engine)

There is no Qt Quick 3D in this tree. Walk is two uniforms:

- `uYaw`  −1 theater … 0 atrium … +1 arcade
- `uWalk`  0 atrium … 1 down the hall

The floor shader does perspective divide. Posters/cabinets are QML items
with `x`/`scale`/`z` bound to those two numbers (same idea as FlipPlate).
Gamepad later (`floor-io.py`); keys are enough to prove the camera.

## What we will not do

- Paste the reference photos as the room.
- One giant 3D mesh “to make it real.”
- A 2D icon grid with MAGMA as wallpaper.
- Extra full-screen raymarches “for atmosphere.”
