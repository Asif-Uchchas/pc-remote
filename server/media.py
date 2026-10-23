"""System volume and now-playing info.

Windows: pycaw (master volume) + WinRT media session (title/artist).
Linux:   wpctl (PipeWire) / pactl / amixer for volume, playerctl for now playing.
macOS:   osascript for volume; now playing unavailable.
"""

import asyncio
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor

from platform_util import IS_LINUX, IS_MAC, IS_WIN, which


def _init_com():
    # One dedicated worker thread for all Windows audio/media calls, initialised
    # as a multithreaded apartment: WinRT async calls deadlock on an STA thread
    # without a message pump, and server connection threads are STA (comtypes).
    if IS_WIN:
        import ctypes
        ctypes.windll.ole32.CoInitializeEx(None, 0)  # COINIT_MULTITHREADED


_worker = ThreadPoolExecutor(max_workers=1, initializer=_init_com)


def _run(fn, *args, timeout=4):
    return _worker.submit(fn, *args).result(timeout=timeout)


# ---------------------------------------------------------------------------
# Volume
# ---------------------------------------------------------------------------

class _WinVolume:
    def __init__(self):
        from ctypes import POINTER, cast
        from comtypes import CLSCTX_ALL
        from pycaw.pycaw import AudioUtilities, IAudioEndpointVolume
        self._AudioUtilities = AudioUtilities
        self._iface = IAudioEndpointVolume
        self._cast, self._POINTER, self._CLSCTX_ALL = cast, POINTER, CLSCTX_ALL

    def _ep(self):
        dev = self._AudioUtilities.GetSpeakers()
        if hasattr(dev, "EndpointVolume"):
            return dev.EndpointVolume
        return self._cast(dev.Activate(self._iface._iid_, self._CLSCTX_ALL, None), self._POINTER(self._iface))

    def _get(self):
        ep = self._ep()
        return {"vol": round(ep.GetMasterVolumeLevelScalar() * 100), "muted": bool(ep.GetMute())}

    def get(self):
        return _run(self._get)

    def set(self, vol):
        _run(lambda: self._ep().SetMasterVolumeLevelScalar(max(0.0, min(1.0, vol / 100.0)), None))

    def mute(self, on):
        _run(lambda: self._ep().SetMute(1 if on else 0, None))


class _LinuxVolume:
    def __init__(self):
        self.tool = next((t for t in ("wpctl", "pactl", "amixer") if which(t)), None)
        if not self.tool:
            raise RuntimeError("no wpctl/pactl/amixer")

    def _run(self, *args):
        return subprocess.run(list(args), capture_output=True, text=True, timeout=3).stdout

    def get(self):
        if self.tool == "wpctl":
            out = self._run("wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@")  # "Volume: 0.45 [MUTED]"
            m = re.search(r"([\d.]+)", out)
            return {"vol": round(float(m.group(1)) * 100) if m else 0, "muted": "MUTED" in out}
        if self.tool == "pactl":
            out = self._run("pactl", "get-sink-volume", "@DEFAULT_SINK@")
            m = re.search(r"(\d+)%", out)
            muted = "yes" in self._run("pactl", "get-sink-mute", "@DEFAULT_SINK@")
            return {"vol": int(m.group(1)) if m else 0, "muted": muted}
        out = self._run("amixer", "get", "Master")
        m = re.search(r"\[(\d+)%\].*\[(on|off)\]", out)
        return {"vol": int(m.group(1)) if m else 0, "muted": bool(m and m.group(2) == "off")}

    def set(self, vol):
        v = max(0, min(100, int(vol)))
        if self.tool == "wpctl":
            self._run("wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{v / 100:.2f}")
        elif self.tool == "pactl":
            self._run("pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{v}%")
        else:
            self._run("amixer", "set", "Master", f"{v}%")

    def mute(self, on):
        if self.tool == "wpctl":
            self._run("wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1" if on else "0")
        elif self.tool == "pactl":
            self._run("pactl", "set-sink-mute", "@DEFAULT_SINK@", "1" if on else "0")
        else:
            self._run("amixer", "set", "Master", "mute" if on else "unmute")


class _MacVolume:
    def _osa(self, script):
        return subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=3).stdout.strip()

    def get(self):
        out = self._osa("get volume settings")  # "output volume:45, input volume:..., output muted:false"
        m = re.search(r"output volume:(\d+)", out)
        return {"vol": int(m.group(1)) if m else 0, "muted": "output muted:true" in out}

    def set(self, vol):
        self._osa(f"set volume output volume {max(0, min(100, int(vol)))}")

    def mute(self, on):
        self._osa(f"set volume output muted {'true' if on else 'false'}")


def make_volume():
    try:
        if IS_WIN:
            return _WinVolume()
        if IS_MAC:
            return _MacVolume()
        if IS_LINUX:
            return _LinuxVolume()
    except Exception:  # noqa: BLE001
        return None
    return None


# ---------------------------------------------------------------------------
# Now playing
# ---------------------------------------------------------------------------

class _WinNowPlaying:
    def __init__(self):
        from winrt.windows.media.control import GlobalSystemMediaTransportControlsSessionManager as M
        self._M = M

    def get(self):
        async def _q():
            mgr = await self._M.request_async()
            s = mgr.get_current_session()
            if not s:
                return None
            p = await s.try_get_media_properties_async()
            status = s.get_playback_info().playback_status  # 4 = playing, 5 = paused
            return {"title": p.title or "", "artist": p.artist or "", "playing": int(status) == 4,
                    "app": s.source_app_user_model_id or ""}
        try:
            return _run(lambda: asyncio.run(_q()))
        except Exception:  # noqa: BLE001
            return None


class _PlayerctlNowPlaying:
    def __init__(self):
        if not which("playerctl"):
            raise RuntimeError("playerctl not found")

    def get(self):
        try:
            status = subprocess.run(["playerctl", "status"], capture_output=True, text=True, timeout=2).stdout.strip()
            if status not in ("Playing", "Paused"):
                return None
            meta = subprocess.run(["playerctl", "metadata", "--format", "{{title}}\t{{artist}}\t{{playerName}}"],
                                  capture_output=True, text=True, timeout=2).stdout.rstrip("\n")
            title, artist, app = (meta.split("\t") + ["", "", ""])[:3]
            return {"title": title, "artist": artist, "playing": status == "Playing", "app": app}
        except Exception:  # noqa: BLE001
            return None


def make_now_playing():
    try:
        if IS_WIN:
            return _WinNowPlaying()
        if IS_LINUX:
            return _PlayerctlNowPlaying()
    except Exception:  # noqa: BLE001
        return None
    return None
