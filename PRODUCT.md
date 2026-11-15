# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

(Native macOS app; not one of the schema's enumerated values. SwiftUI + AppKit, menu bar app.)

## Stack

Swift + SwiftUI/AppKit via SwiftPM, decided in the design spec (`docs/superpowers/specs/2026-11-15-detox-mac-design.md`).

## Users

One person: the owner of this Mac, using it for their own dopamine detox, mostly at night (e.g. 22:30–6:00). Personal tool, not distributed.

## Product Purpose

Detox lets the user commit to blocking websites and apps (Instagram, YouTube, WhatsApp…) on a schedule between two dates, and makes the commitment hold. Success: the user keeps the commitment and doesn't open the blocked things during their window.

## Positioning

Commitments can only get stricter once started, each block has its own lock (no exit, own password, or a friend's phone code), and an access attempt is met with the user's own motivational video or a calm pause screen, not a browser error.

## Operating Context

- Lives in the menu bar; the main window is opened occasionally to create or tighten blocks.
- The intercept screen appears at night, often in a dark room, right when the user is reaching for a distraction.
- A friend is involved once (scanning a QR) and then by phone when an unlock is needed.

## Capabilities and Constraints

- Blocks: targets (services, domains, apps), daily window, weekdays, start/end dates, lock, pause length.
- Phases: Programado, En marcha, Activo, En pausa, Terminado.
- UI copy in Spanish.
- The daemon is the authority; the app only shows state and sends requests.

## Brand Commitments

Name: Detox. Tone confirmed in the spec: sober and calm, consistent with a detox.

User's personal brand (iCloud Drive › Marca Personal › 01_Guia/Guia_de_marca.md) is binding for this app, confirmed 2026-11-15:
- Colours: azul noche #051526 (text and grounds), marfil #F7F4EC (light grounds), oro #CFA046 (lines and accents only, never small text on light).
- Type: Georgia for titles; Arial for text (on native controls the system font stands in; see surface brief).
- Pais Solutions is the seal for tools: its circular icon (02_Logos/Pais_Solutions/icono-circular.png) may be used unmodified; never recolour, stretch or add effects.
- Voice: direct, close, concrete; one main idea per piece. Motto Virtute et Honore (not required in the app).

## Evidence on Hand

No logos, imagery or testimonials exist. Motivational videos are the user's own files in `~/Movies/Detox`; the app ships none. Motivational phrases are original text written for the app.

## Product Principles

1. The commitment is the product: never offer a path to soften it outside its lock.
2. Friction with dignity: stop the user calmly, never shame or alarm.
3. Quiet by default: the app stays out of the way until it matters.
4. Honest limits: say plainly what the app can't prevent.
