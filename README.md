# Mobile Remote

Control your PC from an Android phone over Wi‑Fi: trackpad, keyboard, media keys,
app launcher, clipboard sync, file transfer and a live screen preview.

```
server/   Python helper that runs on the PC (tray icon)
app/      Flutter Android app
design/   UI design sources (Claude Design canvas)
```

Branches: `main` (releases), `develop` (active work), `prototype_1` (frozen first prototype).

## PC side

```bash
cd server
pip install -r requirements.txt
python server.py          # or double-click run_server.bat
```

On first run it creates `config.json` with a random 4‑digit **PIN** and prints it.
Change the PIN / port / display name / download folder there if you like.

The server listens on TCP **48889** and answers discovery broadcasts on UDP **48888**.
Windows Firewall may ask to allow Python on private networks — say yes.

### Windows
`python server.py`, or the packaged `MobileRemote.exe` (tray icon, "Start with Windows" option).

### macOS
Grant Accessibility and Screen Recording permission when asked.

### Linux — Hyprland / Omarchy / Sway / GNOME / KDE (Wayland)
The server creates a virtual keyboard+mouse through `/dev/uinput`, so it works on
any compositor. One-time setup:

```bash
sudo pacman -S grim wl-clipboard          # screen preview + clipboard (Arch/Omarchy)
sudo usermod -aG input $USER              # allow /dev/uinput, then log out and back in
pip install -r requirements.txt           # includes python-evdev on Linux
python server.py
```

Optional: `wtype` lets the typing field send non-ASCII characters.
The app labels the modifier key **SUPER** and seeds Omarchy shortcuts (Super+Return terminal,
Super+Space launcher, Super+W close…) in the Apps tab — edit them to match your config.

### Locked PC
Operating systems block injected input on the lock screen, so the app shows a
"PC is locked" banner and you unlock at the PC. A PC that is *asleep* can be woken
from the connect screen (**WAKE**) if Wake-on-LAN is enabled in its BIOS/NIC settings.

## Phone side

Build & install (phone connected via USB), or grab the APK from `app/build/app/outputs/flutter-apk/`:

```bash
cd app
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Open **Mobile Remote** → it scans the network and lists your PC → tap it → enter the PIN → Connect.
If discovery doesn't find the PC (some routers block broadcasts), enter the IP the server prints.

Works on the same Wi‑Fi, or with the PC connected to the phone's hotspot.

## Tabs

| Tab | What it does |
|---|---|
| **Pad** | Trackpad, mouse buttons, shortcut keys, media keys |
| **Keys** | Same, with a live typing field (text goes to the PC as you type) |
| **Apps** | Lock / Sleep / Power, launch apps installed on the PC, run macros (key combos) |
| **Screen** | Live view of the PC screen with direct touch: finger = pointer, tap = click, hold = drag, 2 fingers = right‑click / scroll. Rotate the phone for fullscreen |
| **Share** | PC ↔ phone clipboard, send text, send photos/files to `Downloads\Mobile Remote` |

## Gestures

| Gesture | Action |
|---|---|
| 1 finger move | move mouse (with acceleration) |
| 1 finger tap | left click |
| 2 finger tap | right click |
| 3 finger tap | middle click |
| 2 finger drag | scroll |
| hold still ~0.35 s, then move | drag |
| hold the **Left** button | mouse button held (drag with other finger) |

Sticky **CTRL / ALT / SHIFT / SUPER** toggles above the key strip apply to the next key or typed
character (turn on SUPER, type `w` → Super+W).

Pointer/scroll speed, media keys and haptics are in ⚙ settings.

## Build size & battery

Release APK (arm64, R8-shrunk, obfuscated): **~16.6 MB**, of which 11 MB is the Flutter engine.
Build with `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols`.

The app batches trackpad moves (≤1 packet / 8 ms), pauses pings and the screen stream while it is
in the background, and only scans the network on the connect screen.

## Protocol

Newline-delimited JSON over TCP. First message must be
`{"t":"hello","pin":"1234","name":"phone"}` → `{"t":"ok","name":"PCNAME","features":[...],"os":"windows|macos|hyprland|linux-wayland|linux-x11","mac":"..","locked":false}`.
A message may carry `"id"`; the reply echoes it.

| Message | Meaning |
|---|---|
| `{"t":"mv","dx":5,"dy":-3}` | relative mouse move |
| `{"t":"click","b":"left\|right\|middle","n":1}` | click |
| `{"t":"down","b":"left"}` / `{"t":"up","b":"left"}` | press / release (drag) |
| `{"t":"scroll","dx":0,"dy":-1}` | wheel |
| `{"t":"text","s":"hello"}` | type text |
| `{"t":"key","k":"enter","mods":["ctrl"]}` | key press with modifiers |
| `{"t":"click_at","x":0.5,"y":0.5,"mon":1,"n":1}` | click at a fraction of a monitor |
| `{"t":"mv_abs","x":0.5,"y":0.5,"mon":1}` | move the pointer to a fraction of a monitor |
| `{"t":"key_down","k":"shift"}` / `key_up` | hold / release a key |
| `{"t":"apps"}` → `{"apps":[{name,path}]}` | list launchable apps |
| `{"t":"launch","path":"..."}` | open an app |
| `{"t":"system","action":"lock\|sleep\|shutdown\|restart"}` | power actions |
| `{"t":"monitors"}` | monitor list |
| `{"t":"clip_get"}` / `{"t":"clip_set","s":"..."}` | clipboard |
| `{"t":"file_begin","name","size"}` → `{"token"}`, then `file_chunk` (base64 `d`), `file_end` | file transfer |
| `{"t":"ping"}` | → `{"t":"pong","locked":false}` |

**Screen stream:** open a second connection whose hello has `"mode":"stream"` plus `fps`, `w`, `q`, `mon`.
After the `ok` line the server pushes JPEG frames as `<4-byte big-endian length><bytes>`. Send `{"t":"stream_stop"}` to end.

Key names: single characters, `enter backspace tab esc space delete home end pageup pagedown up down left right win f1..f12 play_pause next prev vol_up vol_down mute`.
