# Hyperframes Composition Brief: Mobile Remote

## Objective
Create a short launch-style brag video for Mobile Remote — a phone app plus a
single-file Python server that turns an Android phone into a trackpad, keyboard,
media remote, app launcher, file drop and live view for a PC over Wi-Fi.

## Output
- Composition directory: `brag-output/composition/`
- Rendered video: `brag-output/brag.mp4`
- Format: landscape — 1920x1080, 30fps
- Duration: 20.19s

## Source Material
- Project root: `D:\Projects\Mobile_Remote`
- Primary files read: `README.md`, `app/lib/theme.dart` (design tokens),
  `app/lib/ui/connect_screen.dart`, `app/lib/ui/touchpad.dart`,
  `app/lib/ui/pad_screen.dart`, `app/lib/ui/screen_screen.dart`,
  `app/lib/ui/apps_screen.dart`, `app/lib/ui/share_screen.dart`,
  `app/lib/ui/gamepad_screen.dart`, `server/server.py`,
  `design/*.dc.html` (the design artboards for the five screens)
- Product name: Mobile Remote
- Tagline / strongest claim: "Control your PC from an Android phone over Wi‑Fi:
  trackpad, keyboard, media keys, app launcher, clipboard sync, file transfer and
  a live screen preview." (README, line 3)
- Key UI to recreate: the app's own screens in its own tokens — the **Connect**
  screen (eyebrow `MOBILE REMOTE`, headline `Pick a PC`, a discovery row, four PIN
  boxes, a cyan full-width connect bar) and the **Trackpad** screen (dot-grid
  surface with `TRACKPAD` / `2.5×` mono micro-labels and LEFT / MID / RIGHT
  buttons), then the **Screen** tab's live view in landscape.
- Copy that must appear verbatim (all grounded in the project):
  - `Pick a PC` — connect_screen.dart headline
  - `MOBILE REMOTE` — connect_screen.dart eyebrow / app name
  - `TRACKPAD` — touchpad.dart micro-label
  - `LIVE VIEW` — screen_screen.dart section label
  - `12 FPS · 1280p` — screen_screen.dart live readout format (measured value
    from the real session)
  - `Apps & macros`, `Clipboard & files`, `Volume & now playing`, `Gamepad` —
    the app's actual tabs/features
  - `github.com/Asif-Uchchas/pc-remote` — the real repo

## Creative Direction
- Tone preset: `app-store`
- Creative direction: quiet indie dev-tool launch — "the Bluetooth app kept
  dropping, so I built my own"
- Interpretation: clean feature-card structure, smooth slide/wipe transitions,
  generous holds on text. Writing stays plain and first-person; no superlatives,
  no invented metrics. Energy comes from motion and cuts, not adjectives.
- Angle: this wasn't built to be a product — it was built because a Bluetooth
  keyboard app kept dropping mid-use. The film opens on that exact frustration,
  then answers it: Wi-Fi instead of Bluetooth, and a remote that kept growing
  until the phone could drive the whole desktop.
- Hook: a mono status line cycling `connected` → `reconnecting…` → `disconnected`
  with the status dot dying to red, then the line "The Bluetooth app kept
  dropping."
- Outro / punchline: "One Python file on the PC." / "A 16 MB app on the phone."
  over the logo, with the repo URL.
- Avoid:
  - Generic SaaS language ("seamless", "streamline", "effortless")
  - Abstract filler visuals, particle fields, colour washes
  - Unrelated visual redesign — the app's own tokens are the identity
  - Any invented statistic

## Visual Identity
From `app/lib/theme.dart`, the app's real tokens.
- Background: `#0B0D10`
- Surface / panel: `#101418`; raised `#14181D`; inset `#0F1317`
- Border lines: `#1F252C` / `#262D35`
- Accent: `#5EE0FF`
- Text: `#E8ECF1`; secondary `#C9D1DA`; muted `#6B7684`; dim `#4A5461`
- Success / danger: `#7DFFB0` / `#FF6B6B`
- Display font: **Space Grotesk** — not a Hyperframes bundled family, so
  `@font-face` it from `assets/fonts/SpaceGrotesk.ttf`
  (copy from `app/assets/fonts/SpaceGrotesk.ttf`)
- Body / mono font: **JetBrains Mono** — bundled, resolves by name
- Visual references from the project:
  - Dot-grid trackpad surface (22px grid, dots `#1C2229`) — touchpad.dart
  - Mono micro-labels in `#4A5461`, 10px, 1.2px letter-spacing — theme.dart `T.label`
  - 12px-radius panels with 1px `#262D35` borders
  - The phone-plus-monitor logo mark — `app/assets/icon/icon_foreground.png`

## Privacy substitutions
The real app shows the developer's hostname, LAN address and pairing PIN. Use
fictional stand-ins everywhere: **STUDIO-PC**, **192.168.1.24**, PIN **4821**.

## Storyboard
Use the storyboard in `brag-output/brag-plan.md` as the creative contract.

Scene summary:
1. **The problem** — 2.46s — status line dies `connected → reconnecting… →
   disconnected`; hook line "The Bluetooth app kept dropping."
2. **Mobile Remote** — 3.28s — logo mark, wordmark, "Your phone is the trackpad
   now.", `Wi-Fi. No pairing.`
3. **It finds the PC, then drives it** — 3.55s — Connect screen (discovery row,
   PIN 4-8-2-1, connect bar), then the trackpad screen with a finger drag moving a
   desktop cursor in sync
4. **Rotate, and it's the whole desktop** — 3.82s — phone rotates to landscape,
   fills with the live desktop view, tap-to-click; line "Rotate → your whole
   desktop, in your hand."
5. **Everything else it grew into** — 3.27s — four cards one per beat: Apps &
   macros / Clipboard & files / Volume & now playing / Gamepad; full set held
6. **One Python file** — 3.81s — logo, "One Python file on the PC." / "A 16 MB
   app on the phone.", repo URL, music fades

## Audio
- Audio role: warm bed with motion-matched accents
- Audio arc: nearly incidental under the hook → lifts at the logo → tactile UI
  sounds through the connect/drag and rotate demos → light ticks through the four
  cards → fades out under the closing spec lines
- Music: `happy-beats-business-moves-vol-10-by-ende-dot-app.mp3` (bundled, 110 BPM,
  60s, beat grid from 0.27s)
- Music treatment: start at 0.00 at low level under Scene 1, lift at 2.46s,
  steady through the demos, fade 19.1 → 20.19s. No ducking (no voiceover).
- Music cue guidance: bundled preset at
  `<skill-dir>/assets/music/cues/happy-beats-business-moves-vol-10-by-ende-dot-app.music-cues.json`.
  Beat interval ≈0.546s. Scene cuts already sit on beat-grid times
  (2.46 / 5.74 / 9.29 / 13.11 / 16.38 / 20.19). Strong cues worth locking:
  **15.82s**, **18.01s**, **18.55s**. Sequential windows: cards at
  13.11 / 13.64 / 14.20 / 14.73; PIN digits at 6.28 / 6.55 / 6.82 / 7.09.
- Audio-reactive treatment: subtle — drive the cyan glow behind the logo mark
  (Scenes 2 and 6) from the music. No waveform bars, no equalizers, no strobing,
  nothing that moves text.
  > **As built:** per-frame RMS extraction was unavailable — the helper shipped
  > with the retired `hyperframes-creative` skill and has no replacement in the
  > current skill set. The glow instead breathes on the track's own beat grid
  > from the bundled cue preset, which is deterministic, seek-safe and still
  > musical. Noted here rather than silently skipped.
- Audio-coupled moments:
  - Scene 1, `disconnected` swap — one dry digital blip, low volume
  - Scene 2, logo mark lands — one soft impact
  - Scene 3, PIN digits — four keypress sounds, randomized across the set
  - Scene 3, CONNECT press — one clean click
  - Scene 3, finger touches the pad — one very soft rollover
  - Scene 4, rotate — one card-slide as an air movement; one mouse click on the tap
  - Scene 5, each card arrival — one soft warm impact, descending volume
  - Scene 6, logo settles — one quiet soft impact, then silence under the text
- SFX selection guidance (low HF risk preferred, these are suggestions —
  choose finals against the implemented animation):
  - `interface/glitch_002.ogg` (low) — the dropped connection
  - `impact/impactSoft_medium_000.ogg` (low) — logo land
  - `keyboard/keypress-0NN.wav` ×4, randomized — PIN digits
  - `interface/click_003.ogg` (low) — CONNECT press
  - `ui/rollover1.ogg` — first touch on the trackpad
  - `casino/card-slide-1.ogg` (medium, single use) — the rotate
  - `ui/mouseclick1.ogg` — tap on the live view
  - `impact/impactSoft_medium_003.ogg` (low) ×4 descending — the card sequence
  - `impact/impactSoft_medium_002.ogg` (low, quiet) — outro logo
  - Avoid `casino/card-place-*` for the 4× card sequence (high HF risk on repeats)
- SFX analysis guidance: `<skill-dir>/assets/sfx/sfx-analysis.md` — prefer the
  low-risk families for the repeated card sequence and the polished outro.
- Exact SFX choice: Hyperframes chooses filenames, timestamps, density and volume
  against the implemented animation.
- Audio files: copy the chosen music and SFX into
  `brag-output/composition/assets/`

## Hyperframes Instructions
Load the current Hyperframes domain skills — `hyperframes` (composition contract,
`data-*` timing, motion, look, sound) and `hyperframes-cli` (lint / check /
preview / render), plus `hyperframes-registry` before hand-building any named
visual. `/brag` is its own workflow: do not enter the `hyperframes` entry-point
intent interview and do not route into its generic promo / launch-video workflow.

> Note: this brief's original text named `hyperframes-core` / `-animation` /
> `-creative` / `-keyframes`. The current Hyperframes skill set replaces those
> four with the single `hyperframes` skill plus its `references/`.

Requirements:
- Show real UI from the project — the Connect and Trackpad screens are required.
- Keep all text readable: short labels ≥0.8s settled, sentences ≥0.3s/word.
- Total duration 20.19s (within 15-25s).
- Include the music and SFX layer described above.
- Treat `/brag` audio notes as guidance; choose SFX after the animation exists.
- Treat cue metadata as optional timing hints; readability wins over beats.
- Lock 1-3 major tweens to strong cues within ±0.15s; snap the card and PIN
  sequences to consecutive beats within ±0.10s. Mark both in comments.
- Use local assets only; no network fetches, no absolute paths.
- Run `npx hyperframes check` before render — brag's single gate.
- Keep creation and rendering local. No publishing.
