"""
Mobile Remote server - lets the companion Android app control this PC over Wi-Fi.

Protocol: newline-delimited JSON over TCP (port 48889 by default). A message may
carry an "id"; the reply echoes it so the client can match request/response.
Discovery: UDP broadcast on port 48888 ("PCREMOTE_DISCOVER_V1" -> "PCREMOTE_HERE_V1|<name>|<port>").
Screen stream: a second connection whose hello has "mode":"stream"; after auth the
server pushes JPEG frames as <4-byte big-endian length><bytes>.
"""

import base64
import glob
import json
import os
import random
import secrets
import socket
import struct
import subprocess
import sys
import threading
import time

from capture import make_capture
from inputs import make_backend
from platform_util import (FROZEN, IS_HYPRLAND, IS_LINUX, IS_MAC, IS_WAYLAND, IS_WIN, desktop_name,
                           is_locked, local_ips, mac_address, which)

try:
    import pyperclip
    HAVE_CLIP = True
except ImportError:  # pragma: no cover
    HAVE_CLIP = False

VERSION = "1.1.0"
DISCOVERY_PORT = 48888
DEFAULT_TCP_PORT = 48889

# Bundled resources (icon) live next to the script, or inside the PyInstaller bundle.
RES_DIR = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
# Config lives next to the script when run from source; in a per-user folder when
# packaged (the exe may sit somewhere read-only).
if FROZEN:
    CONFIG_DIR = os.path.join(os.environ.get("APPDATA") or os.path.expanduser("~/.config"), "Mobile Remote")
else:
    CONFIG_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(CONFIG_DIR, "config.json")

inp, INPUT_NOTE = make_backend()
cap, CAPTURE_NOTE = make_capture()

FEATURES = [f for f in ["apps", "system", "clipboard" if HAVE_CLIP else None, "files",
                        "screen" if cap else None, "wol", "lock_state"] if f]


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

def load_config():
    """Returns (config, first_run)."""
    first_run = not os.path.exists(CONFIG_PATH)
    cfg = {
        "pin": f"{random.randint(0, 9999):04d}",
        "port": DEFAULT_TCP_PORT,
        "name": socket.gethostname(),
        "downloads": os.path.join(os.path.expanduser("~"), "Downloads", "Mobile Remote"),
    }
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                cfg.update(json.load(f))
        except Exception as e:  # noqa: BLE001
            print(f"[config] could not read config.json ({e}); using defaults")
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)
    return cfg, first_run


# ---------------------------------------------------------------------------
# Apps & system
# ---------------------------------------------------------------------------

_apps_cache = {"at": 0, "apps": []}


def _parse_desktop(path):
    name, hidden = None, False
    try:
        with open(path, encoding="utf-8", errors="ignore") as f:
            in_main = False
            for line in f:
                line = line.strip()
                if line.startswith("["):
                    in_main = line == "[Desktop Entry]"
                    continue
                if not in_main:
                    continue
                if line.startswith("Name=") and name is None:
                    name = line[5:].strip()
                elif line in ("NoDisplay=true", "Hidden=true"):
                    hidden = True
    except OSError:
        return None, True
    return name, hidden


def list_apps():
    """Launchable apps: Start Menu shortcuts on Windows, .app bundles on macOS,
    .desktop entries on Linux."""
    if time.time() - _apps_cache["at"] < 60:
        return _apps_cache["apps"]
    found = {}
    if IS_WIN:
        roots = [
            os.path.join(os.environ.get("ProgramData", r"C:\ProgramData"), r"Microsoft\Windows\Start Menu\Programs"),
            os.path.join(os.environ.get("AppData", ""), r"Microsoft\Windows\Start Menu\Programs"),
        ]
        skip = ("uninstall", "help", "readme", "documentation", "website", "release notes")
        for root in roots:
            for path in glob.glob(os.path.join(root, "**", "*.lnk"), recursive=True):
                name = os.path.splitext(os.path.basename(path))[0]
                if any(s in name.lower() for s in skip):
                    continue
                found.setdefault(name, path)
    elif IS_MAC:
        for root in ("/Applications", "/System/Applications", os.path.expanduser("~/Applications")):
            for path in glob.glob(os.path.join(root, "*.app")):
                found.setdefault(os.path.splitext(os.path.basename(path))[0], path)
    else:
        roots = ["/usr/share/applications", "/usr/local/share/applications",
                 os.path.expanduser("~/.local/share/applications"),
                 "/var/lib/flatpak/exports/share/applications",
                 os.path.expanduser("~/.local/share/flatpak/exports/share/applications")]
        for root in roots:
            for path in glob.glob(os.path.join(root, "*.desktop")):
                name, hidden = _parse_desktop(path)
                if hidden or not name:
                    continue
                found.setdefault(name, path)
    apps = [{"name": n, "path": p} for n, p in sorted(found.items(), key=lambda kv: kv[0].lower())]
    _apps_cache.update(at=time.time(), apps=apps)
    return apps


def launch(path):
    if IS_WIN:
        os.startfile(path)  # noqa: S606 - user-initiated launch of a Start Menu shortcut
    elif IS_MAC:
        subprocess.Popen(["open", path])
    elif path.endswith(".desktop"):
        app_id = os.path.splitext(os.path.basename(path))[0]
        if which("gtk-launch"):
            subprocess.Popen(["gtk-launch", app_id])
        elif which("gio"):
            subprocess.Popen(["gio", "launch", path])
        else:
            subprocess.Popen(["xdg-open", path])
    else:
        subprocess.Popen(["xdg-open", path])


def system_action(action):
    if IS_WIN:
        cmds = {
            "lock": ["rundll32.exe", "user32.dll,LockWorkStation"],
            "sleep": ["rundll32.exe", "powrprof.dll,SetSuspendState", "0,1,0"],
            "shutdown": ["shutdown", "/s", "/t", "5"],
            "restart": ["shutdown", "/r", "/t", "5"],
        }
    elif IS_MAC:
        cmds = {
            "lock": ["pmset", "displaysleepnow"],
            "sleep": ["pmset", "sleepnow"],
            "shutdown": ["osascript", "-e", 'tell app "System Events" to shut down'],
            "restart": ["osascript", "-e", 'tell app "System Events" to restart'],
        }
    else:
        lock = ["hyprlock"] if IS_HYPRLAND and which("hyprlock") else ["loginctl", "lock-session"]
        cmds = {
            "lock": lock,
            "sleep": ["systemctl", "suspend"],
            "shutdown": ["systemctl", "poweroff"],
            "restart": ["systemctl", "reboot"],
        }
    if action not in cmds:
        raise ValueError(f"unknown system action {action!r}")
    subprocess.Popen(cmds[action], start_new_session=True)


# ---------------------------------------------------------------------------
# Screen
# ---------------------------------------------------------------------------

def _abs_point(fx, fy, mon):
    left, top, w, h = cap.monitor_rect(mon) if cap else (0, 0, 1920, 1080)
    return int(left + fx * w), int(top + fy * h)


def move_abs(fx, fy, mon):
    x, y = _abs_point(fx, fy, mon)
    inp.move_to(x, y)


def click_at(fx, fy, mon, button, n=1):
    move_abs(fx, fy, mon)
    time.sleep(0.02)
    inp.click(button, n)


def stream_frames(conn, params, stop):
    """Push JPEG frames until the client goes away or `stop` is set."""
    fps = max(1, min(int(params.get("fps", 12)), 30))
    width = max(320, min(int(params.get("w", 1280)), 1920))
    quality = max(20, min(int(params.get("q", 60)), 90))
    mon = int(params.get("mon", 1))
    for data in cap.frames(mon, width, quality, stop, 1.0 / fps):
        try:
            conn.sendall(struct.pack(">I", len(data)) + data)
        except OSError:
            return


# ---------------------------------------------------------------------------
# Clipboard & files
# ---------------------------------------------------------------------------

_transfers = {}


def safe_name(name):
    name = os.path.basename(name.replace("\\", "/")) or "file"
    return "".join(c for c in name if c not in '<>:"/\\|?*').strip() or "file"


def file_begin(cfg, name, size):
    os.makedirs(cfg["downloads"], exist_ok=True)
    name = safe_name(name)
    dest = os.path.join(cfg["downloads"], name)
    base, ext = os.path.splitext(dest)
    n = 1
    while os.path.exists(dest):
        dest = f"{base} ({n}){ext}"
        n += 1
    token = secrets.token_hex(8)
    _transfers[token] = {"f": open(dest + ".part", "wb"), "dest": dest, "size": int(size), "got": 0}
    print(f"[file] receiving {name} ({size} bytes)")
    return token


def file_chunk(token, b64):
    tr = _transfers[token]
    data = base64.b64decode(b64)
    tr["f"].write(data)
    tr["got"] += len(data)


def file_end(token):
    tr = _transfers.pop(token)
    tr["f"].close()
    os.replace(tr["dest"] + ".part", tr["dest"])
    print(f"[file] saved {tr['dest']}")
    return tr["dest"]


# ---------------------------------------------------------------------------
# Message handling
# ---------------------------------------------------------------------------

_lock_cache = {"at": 0.0, "locked": False}


def locked_state():
    if time.time() - _lock_cache["at"] > 1.0:
        try:
            _lock_cache["locked"] = is_locked()
        except Exception:  # noqa: BLE001
            _lock_cache["locked"] = False
        _lock_cache["at"] = time.time()
    return _lock_cache["locked"]


def handle(msg, cfg):
    t = msg.get("t")
    if t == "mv":
        inp.move(int(msg.get("dx", 0)), int(msg.get("dy", 0)))
    elif t == "mv_abs":
        move_abs(float(msg.get("x", 0.5)), float(msg.get("y", 0.5)), int(msg.get("mon", 1)))
    elif t == "click":
        inp.click(msg.get("b", "left"), int(msg.get("n", 1)))
    elif t == "down":
        inp.press(msg.get("b", "left"))
    elif t == "up":
        inp.release(msg.get("b", "left"))
    elif t == "scroll":
        inp.scroll(int(msg.get("dx", 0)), int(msg.get("dy", 0)))
    elif t == "text":
        inp.type_text(str(msg.get("s", "")))
    elif t == "key":
        inp.combo(msg.get("k", ""), msg.get("mods", []))
    elif t == "key_down":
        inp.key_down(msg.get("k", ""))
    elif t == "key_up":
        inp.key_up(msg.get("k", ""))
    elif t == "click_at":
        click_at(float(msg.get("x", 0.5)), float(msg.get("y", 0.5)), int(msg.get("mon", 1)),
                 msg.get("b", "left"), int(msg.get("n", 1)))
    elif t == "ping":
        return {"t": "pong", "locked": locked_state()}
    elif t == "apps":
        return {"t": "ok", "apps": list_apps()}
    elif t == "launch":
        launch(str(msg.get("path", "")))
        return {"t": "ok"}
    elif t == "system":
        system_action(str(msg.get("action", "")))
        return {"t": "ok"}
    elif t == "monitors":
        return {"t": "ok", "monitors": cap.monitors() if cap else []}
    elif t == "clip_get":
        if not HAVE_CLIP:
            return {"t": "err", "msg": "pyperclip not installed"}
        return {"t": "ok", "s": pyperclip.paste() or ""}
    elif t == "clip_set":
        if not HAVE_CLIP:
            return {"t": "err", "msg": "pyperclip not installed"}
        pyperclip.copy(str(msg.get("s", "")))
        return {"t": "ok"}
    elif t == "file_begin":
        return {"t": "ok", "token": file_begin(cfg, str(msg.get("name", "file")), int(msg.get("size", 0)))}
    elif t == "file_chunk":
        file_chunk(str(msg.get("token")), msg.get("d", ""))
    elif t == "file_end":
        return {"t": "ok", "path": file_end(str(msg.get("token")))}
    else:
        return {"t": "err", "msg": f"unknown type {t!r}"}
    return None


def hello_reply(cfg):
    return {
        "t": "ok",
        "name": cfg["name"],
        "features": FEATURES,
        "os": desktop_name(),
        "mac": mac_address(),
        "version": VERSION,
        "locked": locked_state(),
        "notes": [n for n in (INPUT_NOTE, CAPTURE_NOTE) if n],
    }


def client_thread(conn, addr, cfg):
    peer = f"{addr[0]}:{addr[1]}"
    print(f"[tcp] connection from {peer}")
    conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    conn.settimeout(90)
    authed = False
    stream_stop = None
    buf = b""

    def send(obj):
        try:
            conn.sendall((json.dumps(obj) + "\n").encode("utf-8"))
        except OSError:
            pass

    try:
        while True:
            chunk = conn.recv(65536)
            if not chunk:
                break
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                if not line.strip():
                    continue
                try:
                    msg = json.loads(line)
                except json.JSONDecodeError:
                    send({"t": "err", "msg": "bad json"})
                    continue

                if not authed:
                    if msg.get("t") == "hello" and str(msg.get("pin", "")) == str(cfg["pin"]):
                        authed = True
                        print(f"[tcp] {peer} authenticated ({msg.get('name', 'unknown device')}, mode={msg.get('mode', 'control')})")
                        send(hello_reply(cfg))
                        if msg.get("mode") == "stream":
                            if not cap:
                                return
                            stream_stop = threading.Event()
                            conn.settimeout(None)
                            threading.Thread(target=stream_frames, args=(conn, msg, stream_stop), daemon=True).start()
                    else:
                        print(f"[tcp] {peer} rejected: wrong PIN")
                        send({"t": "err", "msg": "wrong pin"})
                        return
                    continue

                if stream_stop is not None:
                    if msg.get("t") == "stream_stop":
                        stream_stop.set()
                        return
                    continue

                try:
                    reply = handle(msg, cfg)
                except Exception as e:  # noqa: BLE001
                    reply = {"t": "err", "msg": str(e)}
                if reply is None and "id" in msg:
                    reply = {"t": "ok"}
                if reply:
                    if "id" in msg:
                        reply["id"] = msg["id"]
                    send(reply)
    except (socket.timeout, ConnectionResetError, OSError):
        pass
    finally:
        if stream_stop is not None:
            stream_stop.set()
        conn.close()
        print(f"[tcp] {peer} disconnected")


def tcp_server(cfg):
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", cfg["port"]))
    srv.listen(5)
    print(f"[tcp] listening on port {cfg['port']}")
    while True:
        conn, addr = srv.accept()
        threading.Thread(target=client_thread, args=(conn, addr, cfg), daemon=True).start()


def discovery_server(cfg):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("0.0.0.0", DISCOVERY_PORT))
    print(f"[udp] discovery listening on port {DISCOVERY_PORT}")
    reply = f"PCREMOTE_HERE_V1|{cfg['name']}|{cfg['port']}|{mac_address()}".encode("utf-8")
    while True:
        try:
            data, addr = sock.recvfrom(1024)
            if data.strip() == b"PCREMOTE_DISCOVER_V1":
                sock.sendto(reply, addr)
        except OSError:
            time.sleep(0.1)


# ---------------------------------------------------------------------------
# Info dialog, autostart, tray icon
# ---------------------------------------------------------------------------

def info_text(cfg):
    ips = ", ".join(local_ips()) or "unknown"
    lines = [
        f"Name:  {cfg['name']}",
        f"PIN:   {cfg['pin']}",
        f"IP:    {ips}",
        f"Port:  {cfg['port']}",
        "",
        "Open Mobile Remote on your phone, pick this PC and enter the PIN.",
        f"Settings file: {CONFIG_PATH}",
    ]
    for n in (INPUT_NOTE, CAPTURE_NOTE):
        if n:
            lines += ["", "Note: " + n]
    return "\n".join(lines)


def show_info(cfg):
    """Modal dialog with the connection details (used when there is no console)."""
    text = info_text(cfg)
    if IS_WIN:
        import ctypes
        threading.Thread(
            target=lambda: ctypes.windll.user32.MessageBoxW(None, text, "Mobile Remote", 0x40),
            daemon=True,
        ).start()
    elif IS_LINUX and which("notify-send"):
        subprocess.Popen(["notify-send", "-a", "Mobile Remote", "Mobile Remote", text])
    else:
        print(text)


AUTOSTART_KEY = r"Software\Microsoft\Windows\CurrentVersion\Run"


def autostart_enabled():
    if not (IS_WIN and FROZEN):
        return False
    import winreg
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, AUTOSTART_KEY) as k:
            return winreg.QueryValueEx(k, "Mobile Remote")[0] == f'"{sys.executable}"'
    except OSError:
        return False


def set_autostart(enabled):
    import winreg
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, AUTOSTART_KEY, 0, winreg.KEY_SET_VALUE) as k:
        if enabled:
            winreg.SetValueEx(k, "Mobile Remote", 0, winreg.REG_SZ, f'"{sys.executable}"')
        else:
            try:
                winreg.DeleteValue(k, "Mobile Remote")
            except OSError:
                pass


def run_tray(cfg):
    try:
        import pystray
        from PIL import Image as PILImage, ImageDraw
    except ImportError:
        print("[tray] pystray/Pillow not installed - running without tray icon (Ctrl+C to quit)")
        while True:
            time.sleep(3600)

    icon_path = os.path.join(RES_DIR, "icon.png")
    if os.path.exists(icon_path):
        img = PILImage.open(icon_path)
    else:
        img = PILImage.new("RGB", (64, 64), (9, 13, 31))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle((14, 20, 50, 44), radius=4, fill=(94, 224, 255))
        d.rectangle((26, 44, 38, 50), fill=(94, 224, 255))

    def quit_app(icon, _item):
        icon.stop()
        os._exit(0)

    def open_downloads(_icon, _item):
        os.makedirs(cfg["downloads"], exist_ok=True)
        launch(cfg["downloads"])

    def toggle_autostart(_icon, _item):
        set_autostart(not autostart_enabled())

    items = [
        pystray.MenuItem(f"Mobile Remote — PIN {cfg['pin']}", None, enabled=False),
        pystray.MenuItem("Connection info…", lambda _i, _m: show_info(cfg), default=True),
        pystray.MenuItem("Open received files", open_downloads),
    ]
    if IS_WIN and FROZEN:
        items.append(pystray.MenuItem("Start with Windows", toggle_autostart, checked=lambda _i: autostart_enabled()))
    items.append(pystray.MenuItem("Quit", quit_app))
    menu = pystray.Menu(*items)
    try:
        pystray.Icon("mobileremote", img, "Mobile Remote", menu).run()
    except Exception as ex:  # noqa: BLE001 - no tray on this desktop (some Wayland setups)
        print(f"[tray] unavailable ({ex}); running headless (Ctrl+C to quit)")
        while True:
            time.sleep(3600)


def main():
    cfg, first_run = load_config()
    print("=" * 52)
    print("  Mobile Remote server v" + VERSION)
    print(f"  Name     : {cfg['name']}")
    print(f"  PIN      : {cfg['pin']}   (change it in config.json)")
    print(f"  IPs      : {', '.join(local_ips()) or 'unknown'}")
    print(f"  MAC      : {mac_address()}")
    print(f"  Port     : {cfg['port']}")
    print(f"  Desktop  : {desktop_name()}  (input: {inp.name}, capture: {cap.name if cap else 'none'})")
    print(f"  Features : {', '.join(FEATURES)}")
    print(f"  Files to : {cfg['downloads']}")
    for n in (INPUT_NOTE, CAPTURE_NOTE):
        if n:
            print(f"  NOTE     : {n}")
    print("=" * 52)
    if sys.stdout is not None:
        sys.stdout.flush()
    threading.Thread(target=tcp_server, args=(cfg,), daemon=True).start()
    threading.Thread(target=discovery_server, args=(cfg,), daemon=True).start()
    # No console (packaged exe): show the PIN in a dialog on first run.
    if first_run and sys.stdout is None:
        show_info(cfg)
    try:
        run_tray(cfg)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
