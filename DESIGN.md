---
name: Detox
description: A night-time commitment tool for macOS; every surface shows the blocked window as a stretch of night.
colors:
  night: "#051526"
  night-raised: "#0B2238"
  night-high: "#12304D"
  ivory: "#F7F4EC"
  ivory-secondary: "rgba(247, 244, 236, 0.72)"
  ivory-tertiary: "rgba(247, 244, 236, 0.5)"
  hairline: "rgba(247, 244, 236, 0.12)"
  gold: "#CFA046"
typography:
  display:
    fontFamily: "Georgia, serif"
    fontSize: "56px"
    fontWeight: 400
    fontFeature: "tnum"
  phrase:
    fontFamily: "Georgia, serif"
    fontSize: "34px"
    fontWeight: 400
    lineHeight: 1.25
  headline:
    fontFamily: "Georgia, serif"
    fontSize: "30px"
    fontWeight: 400
  title:
    fontFamily: "Georgia, serif"
    fontSize: "22px"
    fontWeight: 400
  title-row:
    fontFamily: "Georgia, serif"
    fontSize: "17px"
    fontWeight: 400
  subhead:
    fontFamily: "-apple-system, 'SF Pro Text', system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 400
  body:
    fontFamily: "-apple-system, 'SF Pro Text', system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
  callout:
    fontFamily: "-apple-system, 'SF Pro Text', system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 400
  label:
    fontFamily: "-apple-system, 'SF Pro Text', system-ui, sans-serif"
    fontSize: "10px"
    fontWeight: 600
  tick:
    fontFamily: "-apple-system, 'SF Pro Text', system-ui, sans-serif"
    fontSize: "10px"
    fontWeight: 400
    fontFeature: "tnum"
rounded:
  day: "7px"
  md: "8px"
  lg: "10px"
  full: "9999px"
spacing:
  xs: "6px"
  sm: "10px"
  md: "14px"
  lg: "18px"
  xl: "24px"
  page-top: "28px"
  page-x: "32px"
  stage: "48px"
components:
  button-primary:
    backgroundColor: "{colors.gold}"
    textColor: "{colors.night}"
    rounded: "{rounded.md}"
  phase-tag-active:
    backgroundColor: "{colors.gold}"
    textColor: "{colors.night}"
    typography: "{typography.label}"
    rounded: "{rounded.full}"
    padding: "2px 7px"
  phase-tag:
    backgroundColor: "{colors.night-high}"
    textColor: "{colors.ivory-secondary}"
    typography: "{typography.label}"
    rounded: "{rounded.full}"
    padding: "2px 7px"
  chip:
    backgroundColor: "{colors.night-high}"
    textColor: "{colors.ivory}"
    rounded: "{rounded.full}"
    padding: "4px 10px"
  day-chip-on:
    backgroundColor: "{colors.night-high}"
    textColor: "{colors.ivory}"
    rounded: "{rounded.day}"
    width: "34px"
    height: "28px"
  day-chip-off:
    backgroundColor: "transparent"
    textColor: "{colors.ivory-tertiary}"
    rounded: "{rounded.day}"
    width: "34px"
    height: "28px"
  panel:
    backgroundColor: "{colors.night-raised}"
    textColor: "{colors.ivory}"
    rounded: "{rounded.md}"
    padding: "12px"
  sidebar:
    backgroundColor: "{colors.night-raised}"
    textColor: "{colors.ivory}"
    width: "190px"
---

# Design System: Detox

## Overview

**Creative North Star: "Hora Azul"**

Detox is used at night, often with the lights off, at the exact moment the owner reaches for a distraction. The system is therefore a single dark world: an azul noche ground that never switches to light, ivory text in three quiet strengths, and one gold that draws lines, marks "now", and carries the active state. Nothing is loud. A blocked window is not a settings row; it is a stretch of night drawn between dusk (18:00) and late morning (12:00), and that band, the NightArc, recurs on every surface that talks about time.

Density is calm and native. The main window is a standard macOS split view with a sidebar; content sits left-aligned on generous page margins with Georgia headlines naming the span you are inside ("Gran silencio hasta las 6:00"). Controls are native AppKit/SwiftUI controls tinted gold, never re-skinned. The intercept screen is the one theatrical moment: chrome deleted, one thing owns the viewport, the breathing ring and a Georgia phrase centered on night.

Severity is spoken with gold hairlines and a lock glyph, never with red. Warnings, validation messages and the no-exit lock all use gold on night; the brand's binding palette has no alarm colour, and the product principle is friction with dignity.

**Key Characteristics:**
- Forced dark: every surface sits on azul noche; light mode is not offered.
- Three ivory strengths (full, 72%, 50%) carry all text hierarchy; colour is not used for hierarchy.
- Gold is the single accent: outlines, the "now" tick, the active tag, step progress, warnings.
- Georgia for titles and big numbers; the system font for controls and running text.
- The NightArc band (18:00 to 12:00) is the signature and appears in the menu bar, the main header, the schedule step and the intercept.
- Depth by tonal layering of three blues; no shadows.

## Colors

A three-step azul noche ramp, ivory at three opacities, and one gold: the user's personal brand palette applied to a night tool.

### Primary
- **Oro** (gold): the only accent. Strokes of active NightArc bands and day chips, the 2px "now" tick, the active phase tag fill, filled segments of the editor step progress, the breathing ring stroke, the no-exit lock glyph and outline, and warning / validation / rate-limit messages. Also the native control tint (`.tint` / `.accentColor`).

### Neutral
- **Azul Noche** (night): the ground of every window, sheet, popover, the intercept screen, and the darkest midpoint of the NightArc gradient.
- **Noche Alzada** (night-raised): first raised layer. Sidebar, notice and permission panels, the friend pairing card, inactive NightArc bands, the breathing ring's inner disc, the dawn end of the arc gradient.
- **Noche Alta** (night-high): second raised layer. Active NightArc band fill, inactive phase tags, removable chips, selected day chips, unfilled step-progress segments, the dusk ends of the arc gradient.
- **Marfil** (ivory): primary text, headlines, selected day letters.
- **Marfil Secundario** (ivory-secondary, 72%): supporting lines: schedule labels, header detail ("Faltan 6 h 46 min"), descriptions, the intercept block name and "hasta las" line.
- **Marfil Terciario** (ivory-tertiary, 50%): least important metadata: target lists, dates, "Noche 5 de 31" in rows, hour ticks on the arc, hints, unselected day letters and radio circles.
- **Hairline** (ivory 12%): 1px dividers, list separators, the NightArc track outline, the static outer breathing ring.

### Named Rules
**The One Gold Rule.** Gold is the only chromatic accent. It marks lines, "now", the active state and anything that cannot be undone; it never fills a large area and never appears on an ivory ground.

**The No Red Rule.** Errors, warnings and irreversible choices use gold text or a gold hairline plus the lock glyph. The palette has no red and no alarm hue.

**The Opacity Ladder Rule.** Text hierarchy is ivory at 100 / 72 / 50%. A finished block dims its whole row to 55% opacity rather than switching colour.

## Typography

**Display Font:** Georgia (with serif)
**Body Font:** System font, SF Pro (with system-ui); stands in for the brand's Arial on native controls.

**Character:** Georgia speaks in human sentences and big numbers, giving the night a literary calm; the system font keeps every control native and legible at small sizes.

### Hierarchy
- **Display** (Georgia 400, 56px, tabular figures): the remaining-time countdown on the intercept screen only.
- **Phrase** (Georgia 400, 34px, +4px line spacing, max 540px wide, centered): the motivational sentence on the intercept.
- **Headline** (Georgia 400, 30px): page headers in the main window ("Gran silencio hasta las 6:00", "Amigos").
- **Title** (Georgia 400, 22px): sheet titles (editor, unlock); 28px on onboarding, 19px in the menu bar popover, 20px for empty-state and confirm-step names.
- **Row title** (Georgia 400, 17px): block names in the list; 16px for friend names and the editor name field; 15px for settings section titles and the intercept block name.
- **Subhead** (system 15px, title3): header detail lines and the intercept "hasta las" line; tabular when numeric.
- **Body** (system 13px): running text, schedule labels. Bold section labels inside forms use the system headline (13px semibold).
- **Callout** (system 12px): metadata, hints, row right-column details.
- **Label** (system 10px semibold): phase tags.
- **Tick** (system 10px, tabular): NightArc hour labels.

### Named Rules
**The Serif Speaks Rule.** Georgia is for names, headlines, the intercept phrase and big numbers; every control, field label and line of metadata stays in the system font.

**The Tabular Time Rule.** Every number that counts or tells time (countdown, codes, "Noche 5 de 31", arc ticks) uses tabular figures.

## Layout

Native macOS structure. The main window is a NavigationSplitView: a 170 to 190px sidebar (Bloqueos, Amigos, Ajustes, each with an SF Symbol) and a detail pane, minimum window 760 x 520. Detail pages are left-aligned with 32px side margins and 28px top margin; the header stack (headline, detail line) is followed by 22px, the NightArc by 28px, then a plain list with hairline separators and transparent row backgrounds. Rows are two columns: name, schedule and targets on the left; lock, dates and progress right-aligned.

Sheets have fixed widths: editor 560 x 560 with 24px padding and hairline-divided header / scrolling body / footer; unlock 420px; onboarding 520px with 32px padding. The menu bar popover is 320px wide with 16px padding and 14px stack spacing. The intercept is full screen: 28px inset top bar, centered column with 40px between ring, phrase and countdown group, 48px outer padding, NightArc at 620px.

Spacing rhythm is 6 / 10 / 14 / 18 / 24, with 28 / 32 for page margins and 48 for the intercept stage.

## Elevation & Depth

Flat. There are no shadows anywhere in the build. Depth is tonal: night (ground), night-raised (sidebar, panels), night-high (tags, chips, active bands), separated by 1px ivory hairlines where an edge needs stating. The NightArc track adds the only gradient: a horizontal dusk-to-night-to-dawn wash across the three blues.

### Named Rules
**The Tonal Layer Rule.** Raise a surface by stepping one blue lighter, never with a shadow or a glow.

## Shapes

Soft, small corners and capsules. Panels, notices and the irreversible lock option use an 8px radius; the friend pairing card 10px; day chips 7px. Tags, removable chips, NightArc bands and step-progress segments are full capsules; the arc track rounds to half its height. Borders are 1px (hairline or gold at 45 to 70% opacity), 1.5px gold for selected or active states. Circles appear only in the breathing ring.

## Components

### Buttons
- **Native and gold-tinted.** All buttons are system buttons; the window accent is gold, so the default (prominent) action takes the gold tint. Primary actions are bound to Return, cancel actions to Escape. Large control size for the empty-state primary ("Crear el primero") and the intercept "Cerrar".
- **Toolbar:** "Nuevo bloqueo" is a toolbar primary action with a plus symbol.
- **Plain:** the menu bar "Abrir Detox" row and lock options use plain button style.
- Note: the captures are offscreen and inactive, so default buttons and the sidebar selection render system grey there; the gold tint and night toolbar are set in code but unverified on screen.

### Chips
- **Removable chip** (domains, apps): night-high capsule, ivory text, 4 x 10px padding, trailing xmark when removable, 6px flow gap.
- **Phase tag:** capsule, 10px semibold. Active is gold fill with night text; every other phase is night-high with ivory-secondary text.
- **Day chip:** 34 x 28px minimum, 7px radius. Selected: night-high fill, ivory letter, 1.5px gold border. Unselected: clear fill, ivory-tertiary letter, 1px ivory 25% border. A committed day adds an 8px lock glyph instead of looking disabled.

### Cards / Containers
- **Corner Style:** 8px (10px for the pairing card).
- **Background:** night-raised.
- **Shadow Strategy:** none; see Elevation & Depth.
- **Border:** none by default; the service-down notice and the no-exit option carry a gold hairline (50 to 70%).
- **Internal Padding:** 12px (notices, permission rows), 14px (commitment box), 18px (pairing card).

### Inputs / Fields
- **Style:** native rounded-border text fields, secure fields, field-style date pickers, steppers, checkboxes and radio groups, all inheriting the gold tint. The block name field uses Georgia 16px; code fields use title-size tabular figures.
- **Error:** the message appears below or beside in gold text, never red.

### Navigation
- **Sidebar:** native source list on night-raised with SF Symbols (moon.stars, person.2, gearshape), tinted gold.
- **Editor steps:** five capsule segments, 3px tall, 6px gap; completed and current are gold, remaining night-high; the step name sits under them in callout ivory-secondary.

### NightArc (signature)
A horizontal band from 18:00 to 12:00 the next day. The track is a capsule with a dusk-night-dawn gradient (night-high, night, night-high, night-raised) and a hairline outline. Each block gets its own lane (8px tall, 3px gap; 5px in compact): active bands are night-high with a 1.5px solid gold outline, others night-raised with a 1px gold outline at 45%. A 2px gold tick, 8px taller than the track, marks now. The full size shows seven tabular hour ticks in ivory-tertiary; the compact menu bar version omits them. It is one accessibility element read as a list of windows.

### Breathing Ring (intercept)
A 220px circle: a static hairline outer ring, and a gold 2px stroke over a night-raised disc that scales 0.6 to 1.0. Inhale 4s, hold 4s, exhale 6s on a cosine ease, with the cue word ("Inspira", "Mantén", "Suelta") in Georgia 20px ivory-secondary. With Reduce Motion the ring stays still and reads "Inspira 4 · mantén 4 · suelta 6" at 14px.

### Lock options
A radio list of plain buttons: gold filled radio when selected, ivory-tertiary circle otherwise, semibold title and callout description. The irreversible "Sin salida" option alone is boxed with a 1px gold outline at 70%, 8px radius, 12px padding, and carries the lock glyph.

## Do's and Don'ts

### Do:
- **Do** put every surface on azul noche (#051526) and force the dark scheme.
- **Do** show any time window on the NightArc rather than as a text-only setting.
- **Do** mark irreversible or no-exit states with a gold hairline and the lock glyph.
- **Do** set titles, names and big numbers in Georgia and keep controls native in the system font.
- **Do** use tabular figures for every countdown, code and progress count.
- **Do** step one blue lighter (night-raised, then night-high) to raise a surface.
- **Do** honour Reduce Motion with a still state that keeps the cue in words.

### Don't:
- **Don't** use red or any alarm hue for errors, warnings or destructive choices; gold carries severity.
- **Don't** fill large areas with gold or place gold text on an ivory ground (brand guide).
- **Don't** add shadows or glows; depth is tonal.
- **Don't** custom-draw standard buttons, fields or pickers; tint the native ones gold. Custom controls are reserved for night-specific choices (day chips, lock options, the NightArc).
- **Don't** recolour, stretch or add effects to the Pais Solutions seal if it is used (brand guide).
