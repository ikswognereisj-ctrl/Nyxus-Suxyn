# Installer branding (Calamares)

Calamares theme for the Nyxus Suxyn ISO: a void ground, ice type, and magma
reserved for the current step and the Install button.

## What this is — and is not

This tree is **branding only**: the slideshow (`show.qml`), the Qt stylesheet
(`stylesheet.qss`), the product descriptor (`branding.desc`), and the logo /
welcome art. It does **not** build an ISO and it does not install anything by
itself. It is applied to a target image that already ships
[Calamares](https://calamares.io/).

## Layout

| File | Purpose |
|---|---|
| `branding.desc` | Calamares branding descriptor: product strings, URLs, images, slideshow entry point. The three version strings carry a `${ISO_DATE}`-stamped token substituted at bake time — do not hand-pin a date here. |
| `show.qml` | The slideshow shown while the installer works. |
| `stylesheet.qss` | Qt stylesheet for the installer chrome. Every color is a named theme token, annotated inline. |
| `logo.png` / `welcome.png` | Product mark (256×256) and welcome banner (800×400). |

## Applying it

Copy the tree onto an ISO `airootfs` as:

```
etc/calamares/branding/nyxus/
```

This tree is not applied to a running system without root. The live stick
still uses `/etc/calamares` until the next bake.
