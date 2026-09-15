# PC Remote

Control your Windows PC (mouse, keyboard, media keys) from an Android phone over Wi‑Fi.

```
server/   Python helper that runs on the PC (tray icon)
app/      Flutter Android app
```

## PC side

```bash
cd server
pip install -r requirements.txt
python server.py          # or double-click run_server.bat
```

On first run it creates `config.json` with a random 4‑digit **PIN** and prints it.
Change the PIN / port / display name there if you like.

The server listens on TCP **48889** and answers discovery broadcasts on UDP **48888**.
Windows Firewall may ask to allow Python on private networks — say yes.

## Phone side

Build & install (phone connected via USB, or use the APK from `app/build/app/outputs/flutter-apk/`):

```bash
cd app
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Open **PC Remote** → it scans the network and lists your PC → tap it → enter the PIN → Connect.
If discovery doesn't find the PC (some routers block broadcasts), type the IP the server prints.

Works on the same Wi‑Fi, or with the PC connected to the phone's hotspot.

## Gestures

| Gesture | Action |
|---|---|
| 1 finger move | move mouse |
| 1 finger tap | left click |
| 2 finger tap | right click |
| 3 finger tap | middle click |
| 2 finger drag | scroll |
| tap, then press & hold | drag |

Bottom bar: mouse buttons, special keys / shortcuts (scrollable), media keys, and a
live keyboard field (toggle with the keyboard icon). Pointer/scroll speed are in ⚙ settings.

## Protocol

Newline-delimited JSON over TCP. First message must be
`{"t":"hello","pin":"1234","name":"phone"}` → `{"t":"ok","name":"PCNAME"}`.

| Message | Meaning |
|---|---|
| `{"t":"mv","dx":5,"dy":-3}` | relative mouse move |
| `{"t":"click","b":"left\|right\|middle","n":1}` | click |
| `{"t":"down","b":"left"}` / `{"t":"up","b":"left"}` | press / release (drag) |
| `{"t":"scroll","dx":0,"dy":-1}` | wheel |
| `{"t":"text","s":"hello"}` | type text |
| `{"t":"key","k":"enter","mods":["ctrl"]}` | key press with modifiers |
| `{"t":"ping"}` | → `{"t":"pong"}` |

Key names: single characters, `enter backspace tab esc space delete home end pageup pagedown up down left right win f1..f12 play_pause next prev vol_up vol_down mute`.
