"""
PC Remote server - lets the companion Android app control this PC over Wi-Fi.

Protocol: newline-delimited JSON over TCP (port 48889 by default).
Discovery: UDP broadcast on port 48888 ("PCREMOTE_DISCOVER_V1" -> "PCREMOTE_HERE_V1|<name>|<port>").
"""

import json
import os
import random
import socket
import threading
import time

from pynput.keyboard import Controller as KeyboardController, Key
from pynput.mouse import Button, Controller as MouseController

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(BASE_DIR, "config.json")
DISCOVERY_PORT = 48888
DEFAULT_TCP_PORT = 48889

mouse = MouseController()
keyboard = KeyboardController()

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

def load_config():
    cfg = {"pin": f"{random.randint(0, 9999):04d}", "port": DEFAULT_TCP_PORT, "name": socket.gethostname()}
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

MODIFIERS = {"ctrl": Key.ctrl, "shift": Key.shift, "alt": Key.alt, "win": Key.cmd}
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
# Message handling
# ---------------------------------------------------------------------------

def handle(msg):
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
    elif t == "ping":
        return {"t": "pong"}
    else:
        return {"t": "err", "msg": f"unknown type {t!r}"}
    return None


def client_thread(conn, addr, cfg):
    peer = f"{addr[0]}:{addr[1]}"
    print(f"[tcp] connection from {peer}")
    conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    conn.settimeout(60)
    authed = False
    buf = b""

    def send(obj):
        try:
            conn.sendall((json.dumps(obj) + "\n").encode("utf-8"))
        except OSError:
            pass

    try:
        while True:
            chunk = conn.recv(4096)
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
                        print(f"[tcp] {peer} authenticated ({msg.get('name', 'unknown device')})")
                        send({"t": "ok", "name": cfg["name"]})
                    else:
                        print(f"[tcp] {peer} rejected: wrong PIN")
                        send({"t": "err", "msg": "wrong pin"})
                        return
                    continue

                try:
                    reply = handle(msg)
                except Exception as e:  # noqa: BLE001
                    reply = {"t": "err", "msg": str(e)}
                if reply:
                    send(reply)
    except (socket.timeout, ConnectionResetError, OSError):
        pass
    finally:
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
        from PIL import Image, ImageDraw
    except ImportError:
        print("[tray] pystray/Pillow not installed - running without tray icon (Ctrl+C to quit)")
        while True:
            time.sleep(3600)

    img = Image.new("RGB", (64, 64), (30, 120, 220))
    d = ImageDraw.Draw(img)
    d.rectangle((14, 20, 50, 44), fill=(255, 255, 255))
    d.rectangle((26, 44, 38, 50), fill=(255, 255, 255))

    def quit_app(icon, _item):
        icon.stop()
        os._exit(0)

    menu = pystray.Menu(
        pystray.MenuItem(f"PC Remote - PIN {cfg['pin']}", None, enabled=False),
        pystray.MenuItem(f"Port {cfg['port']}", None, enabled=False),
        pystray.MenuItem("Quit", quit_app),
    )
    pystray.Icon("pcremote", img, "PC Remote", menu).run()


def main():
    cfg = load_config()
    print("=" * 50)
    print("  PC Remote server")
    print(f"  Name : {cfg['name']}")
    print(f"  PIN  : {cfg['pin']}   (change it in config.json)")
    print(f"  IPs  : {', '.join(local_ips()) or 'unknown'}")
    print(f"  Port : {cfg['port']}")
    print("=" * 50)
    threading.Thread(target=tcp_server, args=(cfg,), daemon=True).start()
    threading.Thread(target=discovery_server, args=(cfg,), daemon=True).start()
    try:
        run_tray(cfg)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
