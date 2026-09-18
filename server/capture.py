"""Screen capture backends.

* MssCapture  - Windows, macOS, Linux/X11
* GrimCapture - Wayland (wlroots-based compositors: Hyprland, Sway, river...)
"""

import io
import json
import subprocess

from platform_util import IS_HYPRLAND, IS_WAYLAND, which


class MssCapture:
    name = "mss"

    def __init__(self):
        import mss
        from PIL import Image
        self.mss = mss
        self.Image = Image

    def monitors(self):
        with self.mss.MSS() as sct:
            return [{"index": i, "w": m["width"], "h": m["height"], "x": m["left"], "y": m["top"]}
                    for i, m in enumerate(sct.monitors) if i > 0]

    def monitor_rect(self, index):
        with self.mss.MSS() as sct:
            m = sct.monitors[max(1, min(index, len(sct.monitors) - 1))]
        return m["left"], m["top"], m["width"], m["height"]

    def frames(self, index, width, quality, stop, interval):
        """Generator of JPEG bytes."""
        import time
        with self.mss.MSS() as sct:
            m = sct.monitors[max(1, min(index, len(sct.monitors) - 1))]
            scale = min(1.0, width / m["width"])
            size = (int(m["width"] * scale), int(m["height"] * scale))
            while not stop.is_set():
                t0 = time.time()
                try:
                    shot = sct.grab(m)
                except Exception:  # noqa: BLE001 - e.g. secure desktop / lock screen
                    time.sleep(0.5)
                    continue
                img = self.Image.frombytes("RGB", shot.size, shot.bgra, "raw", "BGRX")
                if scale < 1.0:
                    img = img.resize(size, self.Image.BILINEAR)
                buf = io.BytesIO()
                img.save(buf, "JPEG", quality=quality, optimize=False)
                yield buf.getvalue()
                dt = time.time() - t0
                if dt < interval:
                    time.sleep(interval - dt)


class GrimCapture:
    """Uses `grim` (wlroots screenshot tool) - Hyprland ships it."""
    name = "grim"

    def __init__(self):
        self.grim = which("grim")
        if not self.grim:
            raise RuntimeError("grim not found (sudo pacman -S grim)")
        self._mons = None

    def monitors(self):
        mons = []
        if IS_HYPRLAND and which("hyprctl"):
            try:
                data = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=3).stdout)
                for i, m in enumerate(data, start=1):
                    scale = float(m.get("scale", 1) or 1)
                    mons.append({"index": i, "name": m["name"], "w": int(m["width"] / scale), "h": int(m["height"] / scale),
                                 "x": m["x"], "y": m["y"]})
            except Exception:  # noqa: BLE001
                mons = []
        if not mons:
            # Fall back to a single capture to learn the size.
            from PIL import Image
            data = subprocess.run([self.grim, "-t", "png", "-"], capture_output=True, timeout=5).stdout
            img = Image.open(io.BytesIO(data))
            mons = [{"index": 1, "name": None, "w": img.width, "h": img.height, "x": 0, "y": 0}]
        self._mons = mons
        return mons

    def monitor_rect(self, index):
        mons = self._mons or self.monitors()
        m = mons[max(0, min(index - 1, len(mons) - 1))]
        return m["x"], m["y"], m["w"], m["h"]

    def frames(self, index, width, quality, stop, interval):
        import time
        mons = self._mons or self.monitors()
        m = mons[max(0, min(index - 1, len(mons) - 1))]
        scale = min(1.0, width / m["w"])
        cmd = [self.grim, "-t", "jpeg", "-q", str(quality), "-s", f"{scale:.3f}"]
        if m.get("name"):
            cmd += ["-o", m["name"]]
        cmd.append("-")
        while not stop.is_set():
            t0 = time.time()
            try:
                data = subprocess.run(cmd, capture_output=True, timeout=5).stdout
            except subprocess.TimeoutExpired:
                continue
            if data:
                yield data
            dt = time.time() - t0
            if dt < interval:
                time.sleep(interval - dt)


def make_capture():
    """Returns (capture, note). capture is None when nothing works."""
    if IS_WAYLAND:
        try:
            return GrimCapture(), None
        except Exception as ex:  # noqa: BLE001
            return None, f"screen preview unavailable: {ex}"
    try:
        return MssCapture(), None
    except ImportError:
        return None, "screen preview unavailable: pip install mss Pillow"
