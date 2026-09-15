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
import io
import json
import os
import platform
import random
import secrets
import socket
import struct
import subprocess
import sys
import threading
import time

from pynput.keyboard import Controller as KeyboardController, Key
from pynput.mouse import Button, Controller as MouseController

try:
    import mss
    from PIL import Image
    HAVE_SCREEN = True
except ImportError:  # pragma: no cover
    HAVE_SCREEN = False

try:
    import pyperclip
    HAVE_CLIP = True
except ImportError:  # pragma: no cover
    HAVE_CLIP = False

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(BASE_DIR, "config.json")
DISCOVERY_PORT = 48888
DEFAULT_TCP_PORT = 48889
IS_WIN = platform.system() == "Windows"
IS_MAC = platform.system() == "Darwin"

mouse = MouseController()
keyboard = KeyboardController()

FEATURES = ["apps", "system", "clipboard" if HAVE_CLIP else None, "files", "screen" if HAVE_SCREEN else None]
FEATURES = [f for f in FEATURES if f]


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

def load_config():
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
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)
    return cfg


# ---------------------------------------------------------------------------
# Key mapping
# ---------------------------------------------------------------------------

SPECIAL_KEYS = {
    "enter": Key.enter, "backspace": Key.backspace, "tab": Key.tab, "esc": Key.esc,
    "space": Key.space, "delete": Key.delete, "insert": Key.insert,
    "home": Key.home, "end": Key.end, "pageup": Key.page_up, "pagedown": Key.page_down,
    "up": Key.up, "down": Key.down, "left": Key.left, "right": Key.right,
    "shift": Key.shift, "ctrl": Key.ctrl, "alt": Key.alt, "win": Key.cmd, "cmd": Key.cmd,
    "capslock": Key.caps_lock, "printscreen": Key.print_screen,
    "f1": Key.f1, "f2": Key.f2, "f3": Key.f3, "f4": Key.f4, "f5": Key.f5, "f6": Key.f6,
    "f7": Key.f7, "f8": Key.f8, "f9": Key.f9, "f10": Key.f10, "f11": Key.f11, "f12": Key.f12,
    "play_pause": Key.media_play_pause, "next": Key.media_next, "prev": Key.media_previous,
    "vol_up": Key.media_volume_up, "vol_down": Key.media_volume_down, "mute": Key.media_volume_mute,
}

MODIFIERS = {"ctrl": Key.ctrl, "shift": Key.shift, "alt": Key.alt, "win": Key.cmd, "cmd": Key.cmd}
BUTTONS = {"left": Button.left, "right": Button.right, "middle": Button.middle}


def resolve_key(name):
    name = str(name)
    if name.lower() in SPECIAL_KEYS:
        return SPECIAL_KEYS[name.lower()]
    if len(name) == 1:
        return name
    raise ValueError(f"unknown key: {name}")


def press_combo(key_name, mods):
    key = resolve_key(key_name)
    mod_keys = [MODIFIERS[m] for m in mods if m in MODIFIERS]
    for m in mod_keys:
        keyboard.press(m)
    try:
        keyboard.press(key)
        keyboard.release(key)
    finally:
        for m in reversed(mod_keys):
            keyboard.release(m)


# ---------------------------------------------------------------------------
# Apps & system
# ---------------------------------------------------------------------------

_apps_cache = {"at": 0, "apps": []}


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
        for root in ("/usr/share/applications", os.path.expanduser("~/.local/share/applications")):
            for path in glob.glob(os.path.join(root, "*.desktop")):
                name = os.path.splitext(os.path.basename(path))[0]
                try:
                    with open(path, encoding="utf-8", errors="ignore") as f:
                        for line in f:
                            if line.startswith("Name="):
                                name = line[5:].strip()
                                break
                except OSError:
                    pass
                found.setdefault(name, path)
    apps = [{"name": n, "path": p} for n, p in sorted(found.items(), key=lambda kv: kv[0].lower())]
    _apps_cache.update(at=time.time(), apps=apps)
    return apps


def launch(path):
    if IS_WIN:
        os.startfile(path)  # noqa: S606 - user-initiated launch of a Start Menu shortcut
    elif IS_MAC:
        subprocess.Popen(["open", path])
    else:
        if path.endswith(".desktop"):
            subprocess.Popen(["gio", "launch", path])
        else:
            subprocess.Popen(["xdg-open", path])


def system_action(action):
    cmds = {
        "lock": (["rundll32.exe", "user32.dll,LockWorkStation"] if IS_WIN else
                 ["pmset", "displaysleepnow"] if IS_MAC else ["loginctl", "lock-session"]),
        "sleep": (["rundll32.exe", "powrprof.dll,SetSuspendState", "0,1,0"] if IS_WIN else
                  ["pmset", "sleepnow"] if IS_MAC else ["systemctl", "suspend"]),
        "shutdown": (["shutdown", "/s", "/t", "5"] if IS_WIN else
                     ["osascript", "-e", 'tell app "System Events" to shut down'] if IS_MAC else
                     ["systemctl", "poweroff"]),
        "restart": (["shutdown", "/r", "/t", "5"] if IS_WIN else
                    ["osascript", "-e", 'tell app "System Events" to restart'] if IS_MAC else
                    ["systemctl", "reboot"]),
    }
    if action not in cmds:
        raise ValueError(f"unknown system action {action!r}")
    subprocess.Popen(cmds[action])


# ---------------------------------------------------------------------------
# Screen
# ---------------------------------------------------------------------------

def monitors():
    if not HAVE_SCREEN:
        return []
    with mss.MSS() as sct:
        # index 0 is the virtual "all monitors" rectangle
        return [{"index": i, "w": m["width"], "h": m["height"], "x": m["left"], "y": m["top"]}
                for i, m in enumerate(sct.monitors) if i > 0]


def click_at(fx, fy, mon, button):
    with mss.MSS() as sct:
        m = sct.monitors[max(1, min(mon, len(sct.monitors) - 1))]
    x = int(m["left"] + fx * m["width"])
    y = int(m["top"] + fy * m["height"])
    mouse.position = (x, y)
    time.sleep(0.02)
    mouse.click(BUTTONS.get(button, Button.left), 1)


def stream_frames(conn, params, stop):
    """Push JPEG frames until the client goes away or `stop` is set."""
    fps = max(1, min(int(params.get("fps", 12)), 30))
    width = max(320, min(int(params.get("w", 1280)), 1920))
    quality = max(20, min(int(params.get("q", 60)), 90))
    mon = int(params.get("mon", 1))
    interval = 1.0 / fps
    with mss.MSS() as sct:
        m = sct.monitors[max(1, min(mon, len(sct.monitors) - 1))]
        scale = min(1.0, width / m["width"])
        size = (int(m["width"] * scale), int(m["height"] * scale))
        while not stop.is_set():
            t0 = time.time()
            shot = sct.grab(m)
            img = Image.frombytes("RGB", shot.size, shot.bgra, "raw", "BGRX")
            if scale < 1.0:
                img = img.resize(size, Image.BILINEAR)
            buf = io.BytesIO()
            img.save(buf, "JPEG", quality=quality, optimize=False)
            data = buf.getvalue()
            try:
                conn.sendall(struct.pack(">I", len(data)) + data)
            except OSError:
                return
            dt = time.time() - t0
            if dt < interval:
                time.sleep(interval - dt)


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

def handle(msg, cfg):
    t = msg.get("t")
    if t == "mv":
        mouse.move(int(msg.get("dx", 0)), int(msg.get("dy", 0)))
    elif t == "click":
        mouse.click(BUTTONS.get(msg.get("b", "left"), Button.left), int(msg.get("n", 1)))
    elif t == "down":
        mouse.press(BUTTONS.get(msg.get("b", "left"), Button.left))
    elif t == "up":
        mouse.release(BUTTONS.get(msg.get("b", "left"), Button.left))
    elif t == "scroll":
        mouse.scroll(int(msg.get("dx", 0)), int(msg.get("dy", 0)))
    elif t == "text":
        keyboard.type(str(msg.get("s", "")))
    elif t == "key":
        press_combo(msg.get("k", ""), msg.get("mods", []))
    elif t == "click_at":
        click_at(float(msg.get("x", 0.5)), float(msg.get("y", 0.5)), int(msg.get("mon", 1)), msg.get("b", "left"))
    elif t == "ping":
        return {"t": "pong"}
    elif t == "apps":
        return {"t": "ok", "apps": list_apps()}
    elif t == "launch":
        launch(str(msg.get("path", "")))
        return {"t": "ok"}
    elif t == "system":
        system_action(str(msg.get("action", "")))
        return {"t": "ok"}
    elif t == "monitors":
        return {"t": "ok", "monitors": monitors()}
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
                        send({"t": "ok", "name": cfg["name"], "features": FEATURES, "os": platform.system()})
                        if msg.get("mode") == "stream":
                            if not HAVE_SCREEN:
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
                    # Streaming connection only understands "stop".
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
    reply = f"PCREMOTE_HERE_V1|{cfg['name']}|{cfg['port']}".encode("utf-8")
    while True:
        try:
            data, addr = sock.recvfrom(1024)
            if data.strip() == b"PCREMOTE_DISCOVER_V1":
                sock.sendto(reply, addr)
        except OSError:
            time.sleep(0.1)


def local_ips():
    ips = set()
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            ips.add(info[4][0])
    except socket.gaierror:
        pass
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ips.add(s.getsockname()[0])
        s.close()
    except OSError:
        pass
    return sorted(ip for ip in ips if not ip.startswith("127."))


# ---------------------------------------------------------------------------
# Optional tray icon
# ---------------------------------------------------------------------------

def run_tray(cfg):
    try:
        import pystray
        from PIL import Image as PILImage, ImageDraw
    except ImportError:
        print("[tray] pystray/Pillow not installed - running without tray icon (Ctrl+C to quit)")
        while True:
            time.sleep(3600)

    icon_path = os.path.join(BASE_DIR, "icon.png")
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

    menu = pystray.Menu(
        pystray.MenuItem(f"Mobile Remote — PIN {cfg['pin']}", None, enabled=False),
        pystray.MenuItem(f"Port {cfg['port']}", None, enabled=False),
        pystray.MenuItem("Open received files", open_downloads),
        pystray.MenuItem("Quit", quit_app),
    )
    pystray.Icon("mobileremote", img, "Mobile Remote", menu).run()


def main():
    cfg = load_config()
    print("=" * 52)
    print("  Mobile Remote server")
    print(f"  Name     : {cfg['name']}")
    print(f"  PIN      : {cfg['pin']}   (change it in config.json)")
    print(f"  IPs      : {', '.join(local_ips()) or 'unknown'}")
    print(f"  Port     : {cfg['port']}")
    print(f"  Features : {', '.join(FEATURES)}")
    print(f"  Files to : {cfg['downloads']}")
    print("=" * 52)
    sys.stdout.flush()
    threading.Thread(target=tcp_server, args=(cfg,), daemon=True).start()
    threading.Thread(target=discovery_server, args=(cfg,), daemon=True).start()
    try:
        run_tray(cfg)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
