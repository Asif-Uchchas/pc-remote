"""Virtual gamepad.

Modes:
* "xbox" - a real virtual Xbox 360 controller: vgamepad (ViGEmBus driver) on
           Windows, a uinput gamepad device on Linux.
* "keys" - buttons/sticks mapped to keyboard keys (works everywhere, for
           emulators that accept keyboard input).

State message from the app: {"t":"pad","b":<button bitmask>,"lx","ly","rx","ry":-1..1,"lt","rt":0..1}
"""

import time

from platform_util import IS_LINUX, IS_WIN

# Button bit positions (shared with the app).
BUTTONS = ["a", "b", "x", "y", "lb", "rb", "back", "start", "ls", "rs", "du", "dd", "dl", "dr", "guide"]
BIT = {n: 1 << i for i, n in enumerate(BUTTONS)}

DEFAULT_KEYMAP = {
    "a": "z", "b": "x", "x": "a", "y": "s", "lb": "q", "rb": "w", "lt": "e", "rt": "r",
    "back": "backspace", "start": "enter", "ls": "shift", "rs": "ctrl",
    "du": "up", "dd": "down", "dl": "left", "dr": "right",
    "lu": "up", "ld": "down", "ll": "left", "lr": "right",   # left stick as d-pad
    "ru": "i", "rd": "k", "rl": "j", "rr": "l",              # right stick
}


class _XboxWin:
    name = "xbox (ViGEm)"

    def __init__(self):
        import vgamepad as vg
        self.vg = vg
        self.pad = vg.VX360Gamepad()
        B = vg.XUSB_BUTTON
        self.map = {
            "a": B.XUSB_GAMEPAD_A, "b": B.XUSB_GAMEPAD_B, "x": B.XUSB_GAMEPAD_X, "y": B.XUSB_GAMEPAD_Y,
            "lb": B.XUSB_GAMEPAD_LEFT_SHOULDER, "rb": B.XUSB_GAMEPAD_RIGHT_SHOULDER,
            "back": B.XUSB_GAMEPAD_BACK, "start": B.XUSB_GAMEPAD_START,
            "ls": B.XUSB_GAMEPAD_LEFT_THUMB, "rs": B.XUSB_GAMEPAD_RIGHT_THUMB,
            "du": B.XUSB_GAMEPAD_DPAD_UP, "dd": B.XUSB_GAMEPAD_DPAD_DOWN,
            "dl": B.XUSB_GAMEPAD_DPAD_LEFT, "dr": B.XUSB_GAMEPAD_DPAD_RIGHT, "guide": B.XUSB_GAMEPAD_GUIDE,
        }

    def update(self, st):
        for n, btn in self.map.items():
            (self.pad.press_button if st["b"] & BIT[n] else self.pad.release_button)(btn)
        self.pad.left_joystick_float(x_value_float=st["lx"], y_value_float=-st["ly"])
        self.pad.right_joystick_float(x_value_float=st["rx"], y_value_float=-st["ry"])
        self.pad.left_trigger_float(value_float=st["lt"])
        self.pad.right_trigger_float(value_float=st["rt"])
        self.pad.update()

    def close(self):
        try:
            self.pad.reset()
            self.pad.update()
        except Exception:  # noqa: BLE001
            pass


class _XboxUInput:
    name = "xbox (uinput)"

    def __init__(self):
        from evdev import AbsInfo, UInput, ecodes as e
        self.e = e
        self.map = {
            "a": e.BTN_SOUTH, "b": e.BTN_EAST, "x": e.BTN_WEST, "y": e.BTN_NORTH,
            "lb": e.BTN_TL, "rb": e.BTN_TR, "back": e.BTN_SELECT, "start": e.BTN_START,
            "ls": e.BTN_THUMBL, "rs": e.BTN_THUMBR, "guide": e.BTN_MODE,
        }
        stick = AbsInfo(value=0, min=-32768, max=32767, fuzz=16, flat=128, resolution=0)
        trig = AbsInfo(value=0, min=0, max=255, fuzz=0, flat=0, resolution=0)
        hat = AbsInfo(value=0, min=-1, max=1, fuzz=0, flat=0, resolution=0)
        caps = {
            e.EV_KEY: list(self.map.values()),
            e.EV_ABS: [(e.ABS_X, stick), (e.ABS_Y, stick), (e.ABS_RX, stick), (e.ABS_RY, stick),
                       (e.ABS_Z, trig), (e.ABS_RZ, trig), (e.ABS_HAT0X, hat), (e.ABS_HAT0Y, hat)],
        }
        # vendor/product of an Xbox 360 pad so games recognise the layout
        self.ui = UInput(caps, name="Microsoft X-Box 360 pad", vendor=0x045E, product=0x028E, version=0x110)
        time.sleep(0.3)

    def update(self, st):
        e = self.e
        for n, code in self.map.items():
            self.ui.write(e.EV_KEY, code, 1 if st["b"] & BIT[n] else 0)
        self.ui.write(e.EV_ABS, e.ABS_X, int(st["lx"] * 32767))
        self.ui.write(e.EV_ABS, e.ABS_Y, int(st["ly"] * 32767))
        self.ui.write(e.EV_ABS, e.ABS_RX, int(st["rx"] * 32767))
        self.ui.write(e.EV_ABS, e.ABS_RY, int(st["ry"] * 32767))
        self.ui.write(e.EV_ABS, e.ABS_Z, int(st["lt"] * 255))
        self.ui.write(e.EV_ABS, e.ABS_RZ, int(st["rt"] * 255))
        self.ui.write(e.EV_ABS, e.ABS_HAT0X, (1 if st["b"] & BIT["dr"] else 0) - (1 if st["b"] & BIT["dl"] else 0))
        self.ui.write(e.EV_ABS, e.ABS_HAT0Y, (1 if st["b"] & BIT["dd"] else 0) - (1 if st["b"] & BIT["du"] else 0))
        self.ui.syn()

    def close(self):
        try:
            self.ui.close()
        except Exception:  # noqa: BLE001
            pass


class _Keys:
    """Maps the pad to keyboard keys through the input backend."""
    name = "keys"

    def __init__(self, inp, keymap=None):
        self.inp = inp
        self.keymap = {**DEFAULT_KEYMAP, **(keymap or {})}
        self.down = set()

    def _wanted(self, st):
        want = set()
        for n in BUTTONS:
            if st["b"] & BIT[n] and n in self.keymap:
                want.add(self.keymap[n])
        if st["lt"] > 0.5 and "lt" in self.keymap:
            want.add(self.keymap["lt"])
        if st["rt"] > 0.5 and "rt" in self.keymap:
            want.add(self.keymap["rt"])
        for stick, (kx, ky) in (("l", ("ll", "lr")), ("r", ("rl", "rr"))):
            x, y = st[stick + "x"], st[stick + "y"]
            if x < -0.5:
                want.add(self.keymap[kx])
            elif x > 0.5:
                want.add(self.keymap[ky])
            if y < -0.5:
                want.add(self.keymap[stick + "u"])
            elif y > 0.5:
                want.add(self.keymap[stick + "d"])
        return want

    def update(self, st):
        want = self._wanted(st)
        for k in self.down - want:
            try:
                self.inp.key_up(k)
            except Exception:  # noqa: BLE001
                pass
        for k in want - self.down:
            try:
                self.inp.key_down(k)
            except Exception:  # noqa: BLE001
                pass
        self.down = want

    def close(self):
        for k in self.down:
            try:
                self.inp.key_up(k)
            except Exception:  # noqa: BLE001
                pass
        self.down = set()


def xbox_available():
    if IS_WIN:
        try:
            import vgamepad  # noqa: F401
            return True
        except Exception:  # noqa: BLE001
            return False
    if IS_LINUX:
        try:
            import evdev  # noqa: F401
            return True
        except Exception:  # noqa: BLE001
            return False
    return False


def make_gamepad(mode, inp, keymap=None):
    """Returns (device, note)."""
    if mode == "xbox":
        try:
            return (_XboxWin() if IS_WIN else _XboxUInput()), None
        except Exception as ex:  # noqa: BLE001
            note = ("Virtual Xbox controller needs the ViGEmBus driver (https://github.com/nefarius/ViGEmBus/releases)"
                    if IS_WIN else f"uinput gamepad unavailable: {ex}")
            return _Keys(inp, keymap), note
    return _Keys(inp, keymap), None


def parse_state(msg):
    def f(k, lo=-1.0, hi=1.0):
        try:
            return max(lo, min(hi, float(msg.get(k, 0))))
        except (TypeError, ValueError):
            return 0.0
    return {"b": int(msg.get("b", 0)), "lx": f("lx"), "ly": f("ly"), "rx": f("rx"), "ry": f("ry"),
            "lt": f("lt", 0.0), "rt": f("rt", 0.0)}
