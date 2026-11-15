---
version: 1
slug: "sources-detoxappkit"
primary_target: "Sources/DetoxAppKit"
related_targets: []
---

# Surface brief: Detox macOS app (menu bar, main window, intercept screen)

Scope: native macOS app; mode Operate (menu bar + main window), with the intercept screen as the one Experience moment. Audience: the owner, at night, often in a dark room. Task: see what is blocked and until when; create or tighten blocks; unlock with password or friend code; be stopped calmly when reaching for a distraction.

## Direction contract

THESIS: The night is the unit. Every surface shows the blocked window as a stretch of night between dusk and dawn, never as a settings row; refuses the grey Screen Time list with toggles.

OWN-WORLD: Azul noche #051526 ground (dark is forced: used at night, lights off), marfil #F7F4EC text, oro #CFA046 only for lines, the "now" marker and the active accent. Tints of azul noche for raised surfaces (#0B2238, #12304D). State: active = oro, paused = marfil at 60%, scheduled = marfil 40%, finished = muted; destructive/no-exit uses oro hairline + lock glyph, never red. Georgia for titles and big numbers; system font for controls and body (native controls; Arial translated to SF on controls).

STORY: At a glance the user sees "Gran silencio hasta las 6:00" and how many nights are left; they trust it will hold; they create or tighten blocks rarely, deliberately.

FIRST VIEWPORT: Main window: sidebar (Bloqueos, Amigos, Ajustes) native NavigationSplitView. Detail: header in Georgia with the current state ("Activo · se abre a las 6:00"), below it the NightArc: a horizontal 24h band from 18:00 to 12:00 with each block's window as an oro-edged band, the gold "now" tick; then the list of blocks as rows (name, schedule label, dates, lock, progress "Noche 5 de 31"). Primary action "Nuevo bloqueo" in the toolbar.

FORM: Hora azul fused with the user's brand; grounded candidate 2 of my list chosen by the user over the assigned 5 (monastic hours). seed: 3fcff9f848b33a74. Raises kept from the round: header names the span you are inside (from the lexicon's guide words); chrome deleted on the intercept screen, one thing owns the viewport (from the full-bleed feed).

SIGNATURE: NightArc band (menu bar popover, main window header, intercept screen countdown). Motion: the intercept breathing ring expands 4 s, holds 4 s, contracts 6 s; reduced motion = static ring with text cues.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
