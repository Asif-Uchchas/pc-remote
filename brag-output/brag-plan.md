# Brag Plan: Mobile Remote

## What is this app?
Mobile Remote turns an Android phone into a trackpad, keyboard, media remote, app
launcher, file drop and live view of your PC — over plain Wi‑Fi, with a single
Python file running on the computer and no Bluetooth pairing anywhere.

## The angle
This wasn't built to be a product. It was built because a Bluetooth keyboard app
kept dropping mid-use — connected, reconnecting, dead, repeat. The film opens on
that exact frustration, then answers it: Wi-Fi instead of Bluetooth, and a remote
that kept growing until the phone could drive the whole desktop. The specificity
is the point — this is one person's annoyance, fixed properly.

## Hook (first 2-3 seconds)
A single mono status line on near-black, cycling the way the old app actually
behaved: `connected` → `reconnecting…` → `disconnected`. The cyan status dot
flickers out to red on the last word. Then one line lands: **"The Bluetooth app
kept dropping."** No logo yet, no product — just the problem, stated flat.

## Key moments (the middle)
- The app finding the PC by itself: a discovery row resolving on the network, PIN
  digits filling one by one, CONNECT — the real connect screen, not a diagram.
- A finger dragging across the dot-grid trackpad while, beside it, the desktop
  cursor moves in step. The core claim, shown rather than captioned.
- The phone rotating to landscape and filling with the live desktop — tap-to-click
  with the finger as the pointer. This is the "wait, it does that?" beat.
- A fast set of four cards for everything else it grew into: apps & macros,
  clipboard + file drop, volume + now playing, gamepad.

## Outro / punchline
Logo and wordmark settle, then the honest spec — the thing that makes it land:
**"One Python file on the PC."** / **"A 16 MB app on the phone."** Repo URL under
it. No pricing, no waitlist, no call to action beyond the source.

## User flow worth showing
Entry → key action → result:
1. **Entry** — open the app; it scans the network and lists the PC; type the PIN.
2. **Key action** — drag a finger across the trackpad; tap the live view.
3. **Result** — the desktop cursor moves; the desktop itself is mirrored in your
   hand after a rotate.

Scenes 3 and 4 are this flow. Scene 5 is the only feature-card frame around it.

## Tone
- Preset: `app-store`
- Creative direction: quiet indie dev-tool launch — "the Bluetooth app kept
  dropping, so I built my own"
- Interpretation: clean feature-card structure and smooth slide transitions, but
  the writing stays plain and first-person. Restraint over hype: no superlatives,
  no "seamless", no invented metrics. Energy comes from motion and cuts, not from
  adjectives.

## Format: landscape — 1920x1080
## Duration: 20.2s target

## Visual identity (from the project)
Taken from `app/lib/theme.dart` (the app's real design tokens).
- Background: `#0B0D10`
- Surface / panel: `#101418`, raised `#14181D`, inset `#0F1317`
- Border lines: `#1F252C`, `#262D35`
- Accent: `#5EE0FF`
- Text: `#E8ECF1`, secondary `#C9D1DA`, muted `#6B7684`, dim `#4A5461`
- Success / danger: `#7DFFB0` / `#FF6B6B`
- Display font: Space Grotesk (bundled at `app/assets/fonts/SpaceGrotesk.ttf`)
- Body / mono font: JetBrains Mono
- Strongest visual element: the dot-grid trackpad surface with its mono
  micro-labels, and the phone-plus-monitor logo mark from
  `app/assets/icon/icon_foreground.png`

## Privacy substitutions
The real app shows the developer's own hostname, LAN address and pairing PIN.
These are replaced throughout with fictional stand-ins: **STUDIO-PC**,
**192.168.1.24**, PIN **4821**. Nothing real is on screen.

## Share copy (draft)
My Bluetooth keyboard app kept dropping, so I built my own: Mobile Remote — trackpad, keyboard, gamepad, clipboard sync and a live view of my desktop, over Wi-Fi, from my phone.

## Audio direction
- Role: warm bed with motion-matched accents
- Music: `happy-beats-business-moves-vol-10-by-ende-dot-app.mp3` — bundled, 110 BPM,
  beat grid starts at 0.27s so it carries momentum from frame one
- Music treatment: start at 0.00 under the hook at low level, lift slightly at the
  logo reveal (2.46s), sit under the demo scenes, fade out 19.1→20.19s
- Music cue guidance: preset cue file read (see below)
- Audio-reactive treatment: subtle — the cyan accent glow on the logo and the live
  view may breathe with music energy; no waveform bars, no visible meters
- SFX posture: sparse to moderate, motion-matched. Real UI sounds only where the
  picture shows an action: PIN key taps, one connect confirm, a soft tick on
  trackpad tap, a whoosh on the rotate, four soft card snaps, one quiet outro
  confirm
- Audio-coupled moments: the hook status line changing state; PIN digits filling
  one by one; the rotate; the four-card sequence
- Restraint rule: no stingers, no riser into the outro, no sound on text that only
  fades in. If a sound has no visible cause, it does not belong.

## Music cue guidance
- Track: `happy-beats-business-moves-vol-10-by-ende-dot-app.mp3`, 109.96 BPM,
  beat interval ≈0.546s, bar ≈2.18s.
- Scene cuts are placed on beat-grid times so every transition lands musically:
  2.46 / 5.74 / 9.29 / 13.11 / 16.38 / 20.19.
- Strong cues to target for major moments: **15.82s** (last feature card settles),
  **18.01s** (repo line lands), **18.55s** (final hold begins).
- Beat-grid window for the sequential card reveal in Scene 5:
  13.11 / 13.64 / 14.20 / 14.73, then the full set holds to 16.38.
- Beat-grid window for the PIN digits in Scene 3: 6.28 / 6.55 / 6.82 / 7.09.
- Cue metadata is timing guidance only. Readability wins over beat alignment
  wherever the two disagree.

## Storyboard

### Scene 1 — The problem — 2.46s
Near-black frame, empty. Centre-left, a single JetBrains Mono line in muted grey
reads `bluetooth keyboard · connected` with a small cyan dot. At 0.82s it swaps to
`reconnecting…` and the dot dims to amber; at 1.37s it swaps to `disconnected` and
the dot goes `#FF6B6B`. At 1.64s the Space Grotesk hook line slams in beneath it:
**"The Bluetooth app kept dropping."** and holds to the cut. No logo, no UI yet.
Sequential/interaction: yes — the status line changes state three times on beats
(0.27 / 0.82 / 1.37), each state fully legible before it swaps.
Audio intent: music low and almost incidental; the picture should feel like a
problem, not a product.
Audio-coupled idea: a dry, quiet interface blip on the `disconnected` swap only.
Music: warm bed, held back.
Transition mood: clean → Scene 2

### Scene 2 — Mobile Remote — 3.28s
Hard cut to black. The phone-plus-monitor logo mark draws in centre at 2.46s with
its Wi-Fi arcs arriving last. At 3.01s the wordmark **MOBILE REMOTE** sets beneath
in Space Grotesk, letter-spaced. At 3.55s one line in cyan mono:
**"Your phone is the trackpad now."** Beneath, smaller and muted:
`Wi-Fi. No pairing.` Everything holds to 5.74s.
Sequential/interaction: yes — mark, then wordmark, then tagline, each on a beat.
Audio intent: the lift. Music steps up here; this is the answer to Scene 1.
Audio-coupled idea: one soft confirm on the mark landing; nothing on the text.
Music: warm bed, lifted.
Transition mood: smooth wipe → Scene 3

### Scene 3 — It finds the PC, then drives it — 3.55s
Split frame. Left: a portrait phone showing the real connect screen —
`MOBILE REMOTE` eyebrow, **Pick a PC**, then a discovery row resolving to
**STUDIO-PC · 192.168.1.24** with a cyan check; four PIN boxes fill `4` `8` `2` `1`
one digit per beat (6.28 / 6.55 / 6.82 / 7.09); the cyan **CONNECT TO STUDIO-PC**
bar presses at 7.09. At 7.35 the phone screen slides to the trackpad view — dot
grid, `TRACKPAD` and `2.5×` micro-labels, LEFT / MID / RIGHT buttons. Right: a
simplified desktop with a cursor. From 7.6s a soft finger dot drags across the dot
grid and the desktop cursor moves in step, ending on a window title bar.
Label, bottom-left, small mono: `trackpad · keyboard · media keys`.
Sequential/interaction: yes — simulated PIN entry digit by digit, a button press,
then a simulated finger drag driving the desktop cursor in sync.
Audio intent: tactile and precise; the sound should make the input feel physical.
Audio-coupled idea: four light key taps on the PIN digits, one confirm on CONNECT,
one soft tick when the finger first touches the pad.
Music: steady under.
Transition mood: slide → Scene 4

### Scene 4 — Rotate, and it's the whole desktop — 3.82s
The phone from Scene 3 rotates 90° to landscape at 9.29s and scales up to fill
most of the frame, its screen becoming the live desktop view — the real Screen tab,
with its `LIVE VIEW` micro-label and a small `12 FPS · 1280p` readout in the
corner. The desktop image settles at 10.38s. From 10.9s a finger dot taps a window
on the mirrored desktop and the cursor jumps there; a second drag moves a window.
Line across the lower third: **"Rotate → your whole desktop, in your hand."**
in from 10.38s, held to the cut.
Sequential/interaction: yes — a physical rotate, then a simulated tap-to-click and
a window drag on the mirrored desktop.
Audio intent: the reveal. One clean movement of air, then back to the bed.
Audio-coupled idea: a soft whoosh on the rotate; one quiet tick on the tap.
Music: bed continues, slight presence lift as the desktop settles.
Transition mood: smooth wipe → Scene 5

### Scene 5 — Everything else it grew into — 3.27s
Four cards in a row on the dark ground, each with a small cyan line-icon, a
two-word Space Grotesk label and one muted mono sub-line. They arrive one per beat
at 13.11 / 13.64 / 14.20 / 14.73, then the complete set holds to 16.38s:
1. **Apps & macros** — `launch anything on the PC`
2. **Clipboard & files** — `phone ↔ PC, both ways`
3. **Volume & now playing** — `real PC volume, live`
4. **Gamepad** — `virtual Xbox controller`
Sequential/interaction: yes — four cards appear one by one, full set held 1.65s
after the last arrival so every label is readable.
Audio intent: rhythmic and light; four small arrivals, nothing heavy.
Audio-coupled idea: one soft card snap per arrival, same sound, descending volume.
Music: bed, riding the beat.
Transition mood: smooth wipe → Scene 6

### Scene 6 — One Python file — 3.81s
Back to black. The logo mark and **MOBILE REMOTE** settle small and centred at
16.38s. At 16.93s, two plain lines in Space Grotesk:
**"One Python file on the PC."** / **"A 16 MB app on the phone."**
At 18.01s, in cyan mono beneath: `github.com/Asif-Uchchas/pc-remote`.
Everything holds; the cyan accent dims slightly from 19.1s as the music fades out
to 20.19s.
Sequential/interaction: yes — logo, then the two spec lines, then the repo line,
each on a beat.
Audio intent: settle and close. No stinger — the music simply finishes.
Audio-coupled idea: one quiet confirm as the logo settles; silence under the text.
Music: warm bed fading 19.1 → 20.19s.
Transition mood: clean fade → end

**Music mood for this video:** upbeat
**Audio summary:** A warm 110 BPM bed starts almost unnoticed under the dropped-connection hook, lifts at the logo, carries tactile UI sounds through the connect-and-drag and rotate demos, ticks lightly through the four feature cards, and fades out under the closing spec lines — every effect tied to something visibly moving.
