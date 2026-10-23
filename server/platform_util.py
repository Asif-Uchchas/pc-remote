"""Platform detection and small OS helpers shared by the server modules."""

import os
import platform
import socket
import subprocess
import sys
import uuid

SYSTEM = platform.system()
IS_WIN = SYSTEM == "Windows"
IS_MAC = SYSTEM == "Darwin"
IS_LINUX = SYSTEM == "Linux"
IS_WAYLAND = IS_LINUX and (os.environ.get("XDG_SESSION_TYPE", "").lower() == "wayland" or bool(os.environ.get("WAYLAND_DISPLAY")))
IS_HYPRLAND = IS_WAYLAND and bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"))
FROZEN = getattr(sys, "frozen", False)


def desktop_name():
    """Human-readable OS / desktop for the app to adapt shortcuts to."""
    if IS_WIN:
        return "windows"
    if IS_MAC:
        return "macos"
    if IS_HYPRLAND:
        return "hyprland"
    return "linux-wayland" if IS_WAYLAND else "linux-x11"


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


def mac_address():
    """MAC of the interface that carries our LAN address, for Wake-on-LAN."""
    try:
        import psutil
        ips = set(local_ips())
        for nic, addrs in psutil.net_if_addrs().items():
            has_ip = any(a.family == socket.AF_INET and a.address in ips for a in addrs)
            if not has_ip:
                continue
            for a in addrs:
                if a.family == psutil.AF_LINK and a.address and a.address != "00:00:00:00:00:00":
                    return a.address.replace("-", ":").lower()
    except Exception:  # noqa: BLE001
        pass
    n = uuid.getnode()
    return ":".join(f"{(n >> (8 * i)) & 0xFF:02x}" for i in reversed(range(6)))


def is_locked():
    """True when the session is on a lock screen (input injection will not work)."""
    if IS_WIN:
        import ctypes
        user32 = ctypes.windll.user32
        hdesk = user32.OpenInputDesktop(0, False, 0x0001)  # DESKTOP_READOBJECTS
        if not hdesk:
            return True
        try:
            buf = ctypes.create_unicode_buffer(64)
            needed = ctypes.c_uint(0)
            user32.GetUserObjectInformationW(hdesk, 2, buf, 128, ctypes.byref(needed))  # UOI_NAME
            return buf.value.lower() != "default"
        finally:
            user32.CloseDesktop(hdesk)
    if IS_MAC:
        try:
            out = subprocess.run(["python3", "-c",
                                  "import Quartz;d=Quartz.CGSessionCopyCurrentDictionary();print(d.get('CGSSessionScreenIsLocked',0))"],
                                 capture_output=True, text=True, timeout=2).stdout.strip()
            return out == "1"
        except Exception:  # noqa: BLE001
            return False
    if IS_LINUX:
        try:
            out = subprocess.run(["loginctl", "show-session", "self", "-p", "LockedHint"],
                                 capture_output=True, text=True, timeout=2).stdout
            return "LockedHint=yes" in out
        except Exception:  # noqa: BLE001
            return False
    return False


def which(cmd):
    from shutil import which as _which
    return _which(cmd)
