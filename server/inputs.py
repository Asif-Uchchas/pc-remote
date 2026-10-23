"""Input injection backends.

* PynputBackend  - Windows, macOS, Linux/X11 (via pynput)
* UInputBackend  - Linux/Wayland (Hyprland, Sway, GNOME, KDE...) via a virtual
                   /dev/uinput keyboard+mouse. Needs the user in the `input`
                   group (or a udev rule) - see README.
"""

import subprocess
import time

from platform_util import IS_WAYLAND, which

MODIFIER_NAMES = ("ctrl", "shift", "alt", "win", "super", "cmd", "meta")


def normalize_mod(m):
    m = m.lower()
    return "win" if m in ("super", "cmd", "meta", "win") else m


# ---------------------------------------------------------------------------
# pynput
# ---------------------------------------------------------------------------

class PynputBackend:
    name = "pynput"

    def __init__(self):
        from pynput.keyboard import Controller as KC, Key
        from pynput.mouse import Button, Controller as MC
        self.mouse = MC()
        self.keyboard = KC()
        self.Key = Key
        self.buttons = {"left": Button.left, "right": Button.right, "middle": Button.middle}
        self.special = {
            "enter": Key.enter, "backspace": Key.backspace, "tab": Key.tab, "esc": Key.esc,
            "space": Key.space, "delete": Key.delete, "insert": Key.insert,
            "home": Key.home, "end": Key.end, "pageup": Key.page_up, "pagedown": Key.page_down,
            "up": Key.up, "down": Key.down, "left": Key.left, "right": Key.right,
            "shift": Key.shift, "ctrl": Key.ctrl, "alt": Key.alt, "win": Key.cmd,
            "capslock": Key.caps_lock, "printscreen": Key.print_screen,
            "play_pause": Key.media_play_pause, "next": Key.media_next, "prev": Key.media_previous,
            "vol_up": Key.media_volume_up, "vol_down": Key.media_volume_down, "mute": Key.media_volume_mute,
        }
        for i in range(1, 13):
            self.special[f"f{i}"] = getattr(Key, f"f{i}")
        self.mods = {"ctrl": Key.ctrl, "shift": Key.shift, "alt": Key.alt, "win": Key.cmd}

    def _key(self, name):
        n = str(name)
        if n.lower() in self.special:
            return self.special[n.lower()]
        if len(n) == 1:
            return n
        raise ValueError(f"unknown key: {name}")

    # mouse
    def move(self, dx, dy):
        self.mouse.move(dx, dy)

    def move_to(self, x, y):
        self.mouse.position = (x, y)

    def click(self, button, n=1):
        self.mouse.click(self.buttons.get(button, self.buttons["left"]), n)

    def press(self, button):
        self.mouse.press(self.buttons.get(button, self.buttons["left"]))

    def release(self, button):
        self.mouse.release(self.buttons.get(button, self.buttons["left"]))

    def scroll(self, dx, dy):
        self.mouse.scroll(dx, dy)

    # keyboard
    def type_text(self, text):
        self.keyboard.type(text)

    def combo(self, key_name, mods):
        key = self._key(key_name)
        mod_keys = [self.mods[normalize_mod(m)] for m in mods if normalize_mod(m) in self.mods]
        for m in mod_keys:
            self.keyboard.press(m)
        try:
            self.keyboard.press(key)
            self.keyboard.release(key)
        finally:
            for m in reversed(mod_keys):
                self.keyboard.release(m)

    def key_down(self, key_name):
        self.keyboard.press(self._key(key_name))

    def key_up(self, key_name):
        self.keyboard.release(self._key(key_name))


# ---------------------------------------------------------------------------
# uinput (Wayland)
# ---------------------------------------------------------------------------

_ASCII_KEYS = {
    "a": "KEY_A", "b": "KEY_B", "c": "KEY_C", "d": "KEY_D", "e": "KEY_E", "f": "KEY_F", "g": "KEY_G",
    "h": "KEY_H", "i": "KEY_I", "j": "KEY_J", "k": "KEY_K", "l": "KEY_L", "m": "KEY_M", "n": "KEY_N",
    "o": "KEY_O", "p": "KEY_P", "q": "KEY_Q", "r": "KEY_R", "s": "KEY_S", "t": "KEY_T", "u": "KEY_U",
    "v": "KEY_V", "w": "KEY_W", "x": "KEY_X", "y": "KEY_Y", "z": "KEY_Z",
    "1": "KEY_1", "2": "KEY_2", "3": "KEY_3", "4": "KEY_4", "5": "KEY_5", "6": "KEY_6", "7": "KEY_7",
    "8": "KEY_8", "9": "KEY_9", "0": "KEY_0",
    " ": "KEY_SPACE", "-": "KEY_MINUS", "=": "KEY_EQUAL", "[": "KEY_LEFTBRACE", "]": "KEY_RIGHTBRACE",
    "\\": "KEY_BACKSLASH", ";": "KEY_SEMICOLON", "'": "KEY_APOSTROPHE", "`": "KEY_GRAVE", ",": "KEY_COMMA",
    ".": "KEY_DOT", "/": "KEY_SLASH", "\n": "KEY_ENTER", "\t": "KEY_TAB",
}
_SHIFTED = {
    "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9", ")": "0",
    "_": "-", "+": "=", "{": "[", "}": "]", "|": "\\", ":": ";", '"': "'", "~": "`", "<": ",", ">": ".", "?": "/",
}
_SPECIAL_KEYS = {
    "enter": "KEY_ENTER", "backspace": "KEY_BACKSPACE", "tab": "KEY_TAB", "esc": "KEY_ESC", "space": "KEY_SPACE",
    "delete": "KEY_DELETE", "insert": "KEY_INSERT", "home": "KEY_HOME", "end": "KEY_END",
    "pageup": "KEY_PAGEUP", "pagedown": "KEY_PAGEDOWN", "up": "KEY_UP", "down": "KEY_DOWN",
    "left": "KEY_LEFT", "right": "KEY_RIGHT", "shift": "KEY_LEFTSHIFT", "ctrl": "KEY_LEFTCTRL",
    "alt": "KEY_LEFTALT", "win": "KEY_LEFTMETA", "capslock": "KEY_CAPSLOCK", "printscreen": "KEY_SYSRQ",
    "play_pause": "KEY_PLAYPAUSE", "next": "KEY_NEXTSONG", "prev": "KEY_PREVIOUSSONG",
    "vol_up": "KEY_VOLUMEUP", "vol_down": "KEY_VOLUMEDOWN", "mute": "KEY_MUTE",
    **{f"f{i}": f"KEY_F{i}" for i in range(1, 13)},
}


class UInputBackend:
    """Virtual keyboard + mouse through /dev/uinput. Works on every Wayland compositor."""
    name = "uinput"

    def __init__(self):
        from evdev import UInput, ecodes as e
        self.e = e
        keys = sorted({getattr(e, k) for k in set(_ASCII_KEYS.values()) | set(_SPECIAL_KEYS.values())} |
                      {e.KEY_LEFTSHIFT, e.KEY_RIGHTSHIFT, e.BTN_LEFT, e.BTN_RIGHT, e.BTN_MIDDLE})
        caps = {
            e.EV_KEY: keys,
            e.EV_REL: [e.REL_X, e.REL_Y, e.REL_WHEEL, e.REL_HWHEEL],
        }
        self.ui = UInput(caps, name="Mobile Remote virtual input", version=1)
        self.buttons = {"left": e.BTN_LEFT, "right": e.BTN_RIGHT, "middle": e.BTN_MIDDLE}
        self.mods = {"ctrl": e.KEY_LEFTCTRL, "shift": e.KEY_LEFTSHIFT, "alt": e.KEY_LEFTALT, "win": e.KEY_LEFTMETA}
        self._wtype = which("wtype")
        time.sleep(0.3)  # let the compositor pick the device up

    def _emit(self, etype, code, value):
        self.ui.write(etype, code, value)

    def _syn(self):
        self.ui.syn()

    def _tap(self, code):
        self._emit(self.e.EV_KEY, code, 1)
        self._syn()
        self._emit(self.e.EV_KEY, code, 0)
        self._syn()

    def _keycode(self, name):
        n = str(name)
        if n.lower() in _SPECIAL_KEYS:
            return getattr(self.e, _SPECIAL_KEYS[n.lower()]), False
        if len(n) == 1:
            ch = n
            shift = False
            if ch in _SHIFTED:
                ch, shift = _SHIFTED[ch], True
            elif ch.isalpha() and ch.isupper():
                ch, shift = ch.lower(), True
            if ch in _ASCII_KEYS:
                return getattr(self.e, _ASCII_KEYS[ch]), shift
        raise ValueError(f"unknown key: {name}")

    # mouse
    def move(self, dx, dy):
        if dx:
            self._emit(self.e.EV_REL, self.e.REL_X, int(dx))
        if dy:
            self._emit(self.e.EV_REL, self.e.REL_Y, int(dy))
        self._syn()

    def move_to(self, x, y):
        # No absolute axis on a relative device: park the pointer at the
        # top-left corner, then walk to the target.
        self.move(-20000, -20000)
        time.sleep(0.005)
        self.move(int(x), int(y))

    def click(self, button, n=1):
        for _ in range(n):
            self._tap(self.buttons.get(button, self.e.BTN_LEFT))

    def press(self, button):
        self._emit(self.e.EV_KEY, self.buttons.get(button, self.e.BTN_LEFT), 1)
        self._syn()

    def release(self, button):
        self._emit(self.e.EV_KEY, self.buttons.get(button, self.e.BTN_LEFT), 0)
        self._syn()

    def scroll(self, dx, dy):
        if dy:
            self._emit(self.e.EV_REL, self.e.REL_WHEEL, int(dy))
        if dx:
            self._emit(self.e.EV_REL, self.e.REL_HWHEEL, int(dx))
        self._syn()

    # keyboard
    def type_text(self, text):
        if self._wtype and any(ord(c) > 127 for c in text):
            subprocess.run([self._wtype, text], timeout=10)
            return
        for ch in text:
            try:
                code, shift = self._keycode(ch)
            except ValueError:
                if self._wtype:
                    subprocess.run([self._wtype, ch], timeout=5)
                continue
            if shift:
                self._emit(self.e.EV_KEY, self.e.KEY_LEFTSHIFT, 1)
            self._tap(code)
            if shift:
                self._emit(self.e.EV_KEY, self.e.KEY_LEFTSHIFT, 0)
                self._syn()

    def combo(self, key_name, mods):
        code, shift = self._keycode(key_name)
        mod_codes = [self.mods[normalize_mod(m)] for m in mods if normalize_mod(m) in self.mods]
        if shift:
            mod_codes.append(self.e.KEY_LEFTSHIFT)
        for m in mod_codes:
            self._emit(self.e.EV_KEY, m, 1)
        self._syn()
        try:
            self._tap(code)
        finally:
            for m in reversed(mod_codes):
                self._emit(self.e.EV_KEY, m, 0)
            self._syn()

    def key_down(self, key_name):
        code, _ = self._keycode(key_name)
        self._emit(self.e.EV_KEY, code, 1)
        self._syn()

    def key_up(self, key_name):
        code, _ = self._keycode(key_name)
        self._emit(self.e.EV_KEY, code, 0)
        self._syn()


def make_backend():
    """Pick the backend for this session; returns (backend, note)."""
    if IS_WAYLAND:
        try:
            return UInputBackend(), None
        except ImportError:
            note = "Wayland session but python-evdev is missing: pip install evdev"
        except PermissionError:
            note = "Wayland session but /dev/uinput is not writable: sudo usermod -aG input $USER (then log out/in)"
        except Exception as ex:  # noqa: BLE001
            note = f"uinput unavailable ({ex})"
        try:
            return PynputBackend(), note + " - falling back to pynput/XWayland (may not work)"
        except Exception as ex:  # noqa: BLE001
            raise RuntimeError(note + f"; pynput also failed: {ex}")
    return PynputBackend(), None
