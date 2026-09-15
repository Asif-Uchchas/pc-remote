"""Generates the direction-A screen artboards (*.dc.html) from shared fragments."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))

BG, SURF, SURF2, LINE, LINE2 = "#0b0d10", "#101418", "#14181d", "#1f252c", "#262d35"
TXT, MUTED, DIM, ACC = "#e8ecf1", "#6b7684", "#4a5461", "#5ee0ff"
SANS = "'Space Grotesk', 'Segoe UI', system-ui, sans-serif"
MONO = "'JetBrains Mono', Consolas, monospace"

ICONS = {
    "pad": '<path d="M5 3l14 8-7 1-4 7z"></path>',
    "keys": '<rect x="3" y="6" width="18" height="12" rx="2"></rect><path d="M7 10h.01M11 10h.01M15 10h.01M7 14h10"></path>',
    "apps": '<rect x="4" y="4" width="6" height="6" rx="1.5"></rect><rect x="14" y="4" width="6" height="6" rx="1.5"></rect><rect x="4" y="14" width="6" height="6" rx="1.5"></rect><rect x="14" y="14" width="6" height="6" rx="1.5"></rect>',
    "screen": '<rect x="3" y="5" width="18" height="12" rx="2"></rect><path d="M8 20h8M12 17v3"></path>',
    "share": '<path d="M12 16V4M7 9l5-5 5 5"></path><path d="M4 15v4a1 1 0 001 1h14a1 1 0 001-1v-4"></path>',
    "tune": '<path d="M4 7h16M4 12h10M4 17h6"></path><circle cx="18" cy="12" r="2"></circle><circle cx="14" cy="17" r="2"></circle>',
    "lock": '<rect x="5" y="11" width="14" height="10" rx="2"></rect><path d="M8 11V7a4 4 0 018 0v4"></path>',
    "moon": '<path d="M20 14.5A8 8 0 019.5 4a8 8 0 1010.5 10.5z"></path>',
    "power": '<path d="M12 3v9M6.3 6.3a8 8 0 1011.4 0"></path>',
    "refresh": '<path d="M20 12a8 8 0 01-14.9 4M4 12a8 8 0 0114.9-4"></path><path d="M20 4v4h-4M4 20v-4h4"></path>',
    "plus": '<path d="M12 5v14M5 12h14"></path>',
    "copy": '<rect x="9" y="9" width="11" height="11" rx="2"></rect><path d="M5 15V5a2 2 0 012-2h10"></path>',
    "paste": '<rect x="6" y="5" width="12" height="16" rx="2"></rect><path d="M9 5V3h6v2M9 12h6M9 16h4"></path>',
    "file": '<path d="M14 3H7a2 2 0 00-2 2v14a2 2 0 002 2h10a2 2 0 002-2V8z"></path><path d="M14 3v5h5"></path>',
    "image": '<rect x="3" y="5" width="18" height="14" rx="2"></rect><circle cx="9" cy="10" r="1.5"></circle><path d="M21 16l-5-5-8 8"></path>',
    "check": '<path d="M5 12l4 4L19 7"></path>',
    "monitor": '<rect x="3" y="4" width="18" height="13" rx="2"></rect><path d="M8 21h8M12 17v4"></path>',
    "cursor": '<path d="M5 3l14 8-7 1-4 7z"></path>',
    "wifi": '<path d="M2 9a15 15 0 0120 0M5.5 12.5a10 10 0 0113 0M9 16a5 5 0 016 0"></path><circle cx="12" cy="19.5" r="1"></circle>',
    "pin": '<rect x="4" y="10" width="16" height="11" rx="2"></rect><path d="M8 10V7a4 4 0 018 0v3"></path>',
    "link": '<path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"></path><path d="M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1"></path>',
    "chev": '<path d="M9 6l6 6-6 6"></path>',
    "x": '<path d="M6 6l12 12M18 6L6 18"></path>',
}


def icon(name, size=20, color=TXT, sw=1.8):
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" fill="none" stroke="{color}" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">{ICONS[name]}</svg>')


def head():
    return f"""<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=JetBrains+Mono:wght@400;500&display=swap">
  <style>
    body {{ margin: 0; background: {BG}; font-family: {SANS}; }}
    a {{ color: {ACC}; }} a:hover {{ color: #9eecff; }}
  </style>
</helmet>
"""


TAIL = "</x-dc>\n</body>\n</html>\n"


def frame(inner, gap=12):
    return (f'<div style="width: 390px; height: 844px; background: {BG}; color: {TXT}; display: flex; '
            f'flex-direction: column; box-sizing: border-box; padding: 56px 16px 20px 16px; gap: {gap}px; '
            f'font-family: {SANS};">\n{inner}\n</div>\n')


def iconbtn(name):
    return (f'<div style="width: 40px; height: 40px; border-radius: 10px; background: {SURF2}; border: 1px solid {LINE}; '
            f'display: flex; align-items: center; justify-content: center;">{icon(name, 20, "#c9d1da")}</div>')


def header(title="JARVIS", sub="192.168.0.104 · 3 ms", buttons=("keys", "tune")):
    btns = "".join(iconbtn(b) for b in buttons)
    return f"""  <div style="display: flex; align-items: center; justify-content: space-between;">
    <div style="display: flex; align-items: center; gap: 10px;">
      <div style="width: 8px; height: 8px; border-radius: 50%; background: {ACC}; box-shadow: 0 0 10px {ACC};"></div>
      <div style="display: flex; flex-direction: column; gap: 1px;">
        <div style="font-size: 16px; font-weight: 600; letter-spacing: -0.01em;">{title}</div>
        <div style="font-family: {MONO}; font-size: 11px; color: {MUTED};">{sub}</div>
      </div>
    </div>
    <div style="display: flex; gap: 8px;">{btns}</div>
  </div>"""


def nav(active):
    items = [("pad", "PAD"), ("keys", "KEYS"), ("apps", "APPS"), ("screen", "SCREEN"), ("share", "SHARE")]
    cells = []
    for key, label in items:
        c = ACC if key == active else MUTED
        cells.append(
            f'<div style="display: flex; flex-direction: column; align-items: center; gap: 4px; padding: 6px 0;">'
            f'{icon(key, 22, c)}<div style="font-size: 10px; font-weight: 600; color: {c}; letter-spacing: 0.08em;">{label}</div></div>')
    return (f'  <div style="display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 4px; padding-top: 6px; '
            f'border-top: 1px solid {LINE};">{"".join(cells)}</div>')


def label(text):
    return (f'<div style="font-family: {MONO}; font-size: 10px; color: {DIM}; letter-spacing: 0.12em; '
            f'padding: 4px 2px 0 2px;">{text}</div>')


def card(inner, extra=""):
    return (f'<div style="border-radius: 14px; background: {SURF}; border: 1px solid {LINE}; padding: 14px; '
            f'box-sizing: border-box; {extra}">{inner}</div>')


def keychip(text):
    return (f'<div style="height: 44px; padding: 0 14px; border-radius: 10px; background: #0f1317; border: 1px solid {LINE2}; '
            f'display: flex; align-items: center; font-family: {MONO}; font-size: 12px; color: #c9d1da; white-space: nowrap;">{text}</div>')


# ---------------------------------------------------------------- Main (touchpad)

def main_screen():
    media = [("M6 6h2v12H6zM20 6L9 12l11 6z", False), ("M7 5l12 7-12 7z", True), ("M16 6h2v12h-2zM4 6l11 6-11 6z", False)]
    media_html = ""
    for d, hot in media:
        bg = ACC if hot else SURF2
        fill = BG if hot else "#c9d1da"
        media_html += (f'<div style="height: 44px; border-radius: 10px; background: {bg}; display: flex; align-items: center; justify-content: center;">'
                       f'<svg width="18" height="18" viewBox="0 0 24 24" fill="{fill}"><path d="{d}"></path></svg></div>')
    vols = ['<path d="M4 10v4h4l5 4V6L8 10H4zM18 9l4 6M22 9l-4 6"></path>',
            '<path d="M4 10v4h4l5 4V6L8 10H4zM17 12h4"></path>',
            '<path d="M4 10v4h4l5 4V6L8 10H4zM19 10v4M17 12h4"></path>']
    for d in vols:
        media_html += (f'<div style="height: 44px; border-radius: 10px; background: {SURF2}; display: flex; align-items: center; justify-content: center;">'
                       f'<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#c9d1da" stroke-width="2" stroke-linecap="round">{d}</svg></div>')

    inner = header() + f"""
  <div style="flex-grow: 1; border-radius: 16px; background: {SURF}; border: 1px solid {LINE}; position: relative; overflow: hidden; display: flex; align-items: flex-end; justify-content: center; padding-bottom: 18px; box-sizing: border-box;">
    <div style="position: absolute; inset: 0; background-image: radial-gradient(#1c2229 1px, transparent 1px); background-size: 22px 22px; opacity: 0.7;"></div>
    <div style="position: absolute; top: 14px; left: 14px; font-family: {MONO}; font-size: 10px; color: {DIM}; letter-spacing: 0.12em;">TRACKPAD</div>
    <div style="position: absolute; top: 14px; right: 14px; font-family: {MONO}; font-size: 10px; color: {DIM}; letter-spacing: 0.12em;">2.5×</div>
    <div style="position: relative; font-family: {MONO}; font-size: 11px; color: {DIM}; text-align: center; line-height: 1.6;">tap · click  ·  2 fingers · right / scroll<br>hold · drag</div>
  </div>
  <div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px;">
    <div style="height: 52px; border-radius: 12px; background: {SURF2}; border: 1px solid {LINE2}; display: flex; align-items: center; justify-content: center; font-size: 14px; font-weight: 600; color: {TXT};">LEFT</div>
    <div style="height: 52px; border-radius: 12px; background: {SURF2}; border: 1px solid {LINE2}; display: flex; align-items: center; justify-content: center; font-size: 14px; font-weight: 600; color: #8b95a2;">MID</div>
    <div style="height: 52px; border-radius: 12px; background: {SURF2}; border: 1px solid {LINE2}; display: flex; align-items: center; justify-content: center; font-size: 14px; font-weight: 600; color: {TXT};">RIGHT</div>
  </div>
  <div style="display: flex; gap: 6px; overflow: hidden;">{"".join(keychip(k) for k in ["ESC", "TAB", "⌫", "ENTER", "ALT+TAB", "CTRL+C"])}</div>
  <div style="display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 6px;">{media_html}</div>
""" + nav("pad")
    return head() + frame(inner) + TAIL


# ---------------------------------------------------------------- Connect

def connect_screen():
    def pc_row(name, ip, last):
        return (f'<div style="display: flex; align-items: center; gap: 12px; padding: 14px; border-radius: 12px; background: {SURF2}; border: 1px solid {LINE2};">'
                f'<div style="width: 40px; height: 40px; border-radius: 10px; background: {SURF}; border: 1px solid {LINE}; display: flex; align-items: center; justify-content: center;">{icon("monitor", 20, ACC)}</div>'
                f'<div style="display: flex; flex-direction: column; gap: 2px; flex-grow: 1;"><div style="font-size: 15px; font-weight: 600;">{name}</div>'
                f'<div style="font-family: {MONO}; font-size: 11px; color: {MUTED};">{ip} · {last}</div></div>'
                f'{icon("chev", 18, MUTED)}</div>')

    inner = f"""
  <div style="display: flex; flex-direction: column; gap: 6px; padding-top: 24px;">
    <div style="font-family: {MONO}; font-size: 11px; color: {ACC}; letter-spacing: 0.14em;">PC REMOTE</div>
    <div style="font-size: 32px; font-weight: 700; letter-spacing: -0.02em; line-height: 1.1;">Pick a PC</div>
    <div style="font-size: 13px; color: {MUTED}; line-height: 1.5;">Phone and PC must share a Wi‑Fi network, or connect the PC to this phone's hotspot.</div>
  </div>
  <div style="display: flex; align-items: center; justify-content: space-between; padding-top: 8px;">
    {label("ON YOUR NETWORK")}
    <div style="display: flex; align-items: center; gap: 6px; font-family: {MONO}; font-size: 10px; color: {ACC}; letter-spacing: 0.12em;">{icon("refresh", 14, ACC)}SCANNING</div>
  </div>
  <div style="display: flex; flex-direction: column; gap: 8px;">
    {pc_row("Jarvis", "192.168.0.104", "used 2 h ago")}
    {pc_row("Office-PC", "192.168.0.112", "new")}
  </div>
  <div style="display: flex; align-items: center; gap: 10px; padding: 12px 14px; border-radius: 12px; border: 1px dashed {LINE2}; color: {MUTED}; font-size: 13px;">{icon("plus", 16, MUTED)}Enter an address manually</div>
  <div style="flex-grow: 1;"></div>
  {label("PIN · SHOWN IN THE SERVER WINDOW")}
  <div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 8px;">
    <div style="height: 56px; border-radius: 12px; background: {SURF2}; border: 1px solid {ACC}; display: flex; align-items: center; justify-content: center; font-family: {MONO}; font-size: 22px; color: {TXT};">4</div>
    <div style="height: 56px; border-radius: 12px; background: {SURF2}; border: 1px solid {ACC}; display: flex; align-items: center; justify-content: center; font-family: {MONO}; font-size: 22px; color: {TXT};">8</div>
    <div style="height: 56px; border-radius: 12px; background: {SURF2}; border: 1px solid {LINE2}; display: flex; align-items: center; justify-content: center; font-family: {MONO}; font-size: 22px; color: {DIM};">·</div>
    <div style="height: 56px; border-radius: 12px; background: {SURF2}; border: 1px solid {LINE2}; display: flex; align-items: center; justify-content: center; font-family: {MONO}; font-size: 22px; color: {DIM};">·</div>
  </div>
  <div style="height: 54px; border-radius: 12px; background: {ACC}; display: flex; align-items: center; justify-content: center; gap: 8px; font-size: 15px; font-weight: 700; color: {BG}; letter-spacing: 0.02em;">{icon("link", 18, BG, 2.2)}CONNECT TO JARVIS</div>
"""
    return head() + frame(inner) + TAIL


# ---------------------------------------------------------------- Apps & shortcuts

def apps_screen():
    def tile(letter, name, hue):
        return (f'<div style="display: flex; flex-direction: column; align-items: center; gap: 8px; padding: 14px 6px; border-radius: 12px; background: {SURF2}; border: 1px solid {LINE2};">'
                f'<div style="width: 44px; height: 44px; border-radius: 12px; background: {hue}; display: flex; align-items: center; justify-content: center; font-size: 18px; font-weight: 700; color: {BG};">{letter}</div>'
                f'<div style="font-size: 11px; font-weight: 600; color: #c9d1da; text-align: center;">{name}</div></div>')

    def sysbtn(ic, text, danger=False):
        c = "#ff6b6b" if danger else "#c9d1da"
        return (f'<div style="height: 48px; border-radius: 12px; background: {SURF2}; border: 1px solid {LINE2}; display: flex; align-items: center; justify-content: center; gap: 8px; '
                f'font-size: 12px; font-weight: 600; color: {c}; letter-spacing: 0.06em;">{icon(ic, 18, c)}{text}</div>')

    def macro(name, keys):
        return (f'<div style="display: flex; align-items: center; justify-content: space-between; padding: 12px 14px; border-radius: 12px; background: {SURF2}; border: 1px solid {LINE2};">'
                f'<div style="font-size: 14px; font-weight: 600;">{name}</div>'
                f'<div style="font-family: {MONO}; font-size: 11px; color: {MUTED};">{keys}</div></div>')

    tiles = [("B", "Browser", "#5ee0ff"), ("C", "Code", "#7c9cff"), ("M", "Music", "#7dffb0"), ("F", "Files", "#ffd166"),
             ("T", "Terminal", "#c9d1da"), ("V", "Video", "#ff8fa3"), ("S", "Settings", "#9eecff"), ("+", "Add", LINE2)]
    inner = header(buttons=("plus", "tune")) + f"""
  {label("SYSTEM")}
  <div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px;">
    {sysbtn("lock", "LOCK")}{sysbtn("moon", "SLEEP")}{sysbtn("power", "SHUT DOWN", True)}
  </div>
  {label("LAUNCH")}
  <div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 8px;">{"".join(tile(*t) for t in tiles)}</div>
  {label("MACROS · TAP TO RUN")}
  <div style="display: flex; flex-direction: column; gap: 8px;">
    {macro("Screenshot to clipboard", "WIN + SHIFT + S")}
    {macro("Show desktop", "WIN + D")}
    {macro("Task manager", "CTRL + SHIFT + ESC")}
  </div>
  <div style="flex-grow: 1;"></div>
""" + nav("apps")
    return head() + frame(inner) + TAIL


# ---------------------------------------------------------------- Screen preview

def screen_screen():
    # A stylised desktop inside the preview: taskbar + two windows drawn as plain shapes.
    desktop = f"""
    <div style="position: absolute; inset: 0; background: linear-gradient(160deg, #182333 0%, #0e1622 100%);"></div>
    <div style="position: absolute; left: 10%; top: 12%; width: 56%; height: 58%; border-radius: 4px; background: #1c2431; border: 1px solid #2c3543;">
      <div style="height: 10px; background: #2a3442; border-radius: 4px 4px 0 0;"></div>
    </div>
    <div style="position: absolute; left: 44%; top: 30%; width: 46%; height: 52%; border-radius: 4px; background: #212b38; border: 1px solid #34404f;">
      <div style="height: 10px; background: #34404f; border-radius: 4px 4px 0 0;"></div>
    </div>
    <div style="position: absolute; left: 0; right: 0; bottom: 0; height: 8%; background: #0a0f16; display: flex; align-items: center; justify-content: center; gap: 6px;">
      <div style="width: 8px; height: 8px; border-radius: 2px; background: #3a4656;"></div><div style="width: 8px; height: 8px; border-radius: 2px; background: #3a4656;"></div><div style="width: 8px; height: 8px; border-radius: 2px; background: {ACC};"></div><div style="width: 8px; height: 8px; border-radius: 2px; background: #3a4656;"></div>
    </div>
    <div style="position: absolute; left: 58%; top: 46%;">{icon("cursor", 16, "#ffffff", 2)}</div>
    """

    def seg(text, on):
        bg = ACC if on else "transparent"
        c = BG if on else MUTED
        return (f'<div style="flex-grow: 1; height: 36px; border-radius: 8px; background: {bg}; display: flex; align-items: center; justify-content: center; '
                f'font-family: {MONO}; font-size: 11px; font-weight: 500; color: {c}; letter-spacing: 0.08em;">{text}</div>')

    inner = header() + f"""
  <div style="display: flex; align-items: center; justify-content: space-between;">
    {label("LIVE VIEW")}
    <div style="display: flex; align-items: center; gap: 6px; font-family: {MONO}; font-size: 10px; color: {MUTED}; letter-spacing: 0.1em;"><div style="width: 6px; height: 6px; border-radius: 50%; background: #7dffb0;"></div>12 FPS · 1280×720</div>
  </div>
  <div style="width: 358px; height: 201px; border-radius: 12px; border: 1px solid {LINE2}; position: relative; overflow: hidden;">{desktop}</div>
  <div style="font-size: 12px; color: {MUTED}; line-height: 1.5; text-align: center;">Tap anywhere on the preview to click there. Pinch to zoom in.</div>
  {label("QUALITY")}
  <div style="display: flex; gap: 4px; padding: 4px; border-radius: 12px; background: {SURF}; border: 1px solid {LINE};">{seg("SMOOTH", False)}{seg("BALANCED", True)}{seg("SHARP", False)}</div>
  {label("MONITOR")}
  <div style="display: flex; gap: 4px; padding: 4px; border-radius: 12px; background: {SURF}; border: 1px solid {LINE};">{seg("1 · MAIN", True)}{seg("2", False)}</div>
  <div style="flex-grow: 1; border-radius: 16px; background: {SURF}; border: 1px solid {LINE}; position: relative; overflow: hidden; display: flex; align-items: center; justify-content: center;">
    <div style="position: absolute; inset: 0; background-image: radial-gradient(#1c2229 1px, transparent 1px); background-size: 22px 22px; opacity: 0.7;"></div>
    <div style="position: absolute; top: 14px; left: 14px; font-family: {MONO}; font-size: 10px; color: {DIM}; letter-spacing: 0.12em;">TRACKPAD</div>
    <div style="position: relative; font-family: {MONO}; font-size: 11px; color: {DIM};">or use the pad</div>
  </div>
""" + nav("screen")
    return head() + frame(inner) + TAIL


# ---------------------------------------------------------------- Clipboard & files

def share_screen():
    def action(ic, text, primary=False):
        bg = ACC if primary else SURF2
        c = BG if primary else "#c9d1da"
        bd = ACC if primary else LINE2
        return (f'<div style="flex-grow: 1; height: 46px; border-radius: 10px; background: {bg}; border: 1px solid {bd}; display: flex; align-items: center; justify-content: center; gap: 8px; '
                f'font-size: 12px; font-weight: 600; color: {c}; letter-spacing: 0.06em;">{icon(ic, 16, c, 2)}{text}</div>')

    def transfer(ic, name, meta, done=True):
        st = icon("check", 16, "#7dffb0") if done else f'<div style="font-family: {MONO}; font-size: 10px; color: {ACC};">64%</div>'
        return (f'<div style="display: flex; align-items: center; gap: 12px; padding: 12px 14px; border-radius: 12px; background: {SURF2}; border: 1px solid {LINE2};">'
                f'{icon(ic, 20, MUTED)}<div style="display: flex; flex-direction: column; gap: 2px; flex-grow: 1;"><div style="font-size: 13px; font-weight: 600;">{name}</div>'
                f'<div style="font-family: {MONO}; font-size: 10px; color: {MUTED};">{meta}</div></div>{st}</div>')

    inner = header() + f"""
  {label("PC CLIPBOARD")}
  <div style="border-radius: 14px; background: {SURF}; border: 1px solid {LINE}; padding: 14px; box-sizing: border-box; display: flex; flex-direction: column; gap: 10px;">
    <div style="font-size: 14px; line-height: 1.5; color: {TXT}; max-height: 66px; overflow: hidden;">https://github.com/Asif-Uchchas/pc-remote</div>
    <div style="display: flex; gap: 8px;">{action("copy", "COPY TO PHONE")}{action("refresh", "REFRESH")}</div>
  </div>
  {label("PHONE CLIPBOARD")}
  <div style="border-radius: 14px; background: {SURF}; border: 1px solid {LINE}; padding: 14px; box-sizing: border-box; display: flex; flex-direction: column; gap: 10px;">
    <div style="font-size: 14px; line-height: 1.5; color: {MUTED}; font-style: italic;">Meeting notes — call at 6:30, bring the adapter</div>
    <div style="display: flex; gap: 8px;">{action("paste", "PASTE ON PC", True)}{action("keys", "TYPE IT OUT")}</div>
  </div>
  {label("SEND TO PC")}
  <div style="display: flex; gap: 8px;">{action("image", "PHOTOS")}{action("file", "FILES")}</div>
  <div style="font-size: 11px; color: {DIM}; text-align: center;">Saved to Downloads\\PC Remote on the PC</div>
  {label("RECENT")}
  <div style="display: flex; flex-direction: column; gap: 8px;">
    {transfer("image", "IMG_20260915_1842.jpg", "3.2 MB · sending", False)}
    {transfer("file", "presentation.pdf", "12 MB · 18:40")}
    {transfer("copy", "Clipboard text", "18:31")}
  </div>
  <div style="flex-grow: 1;"></div>
""" + nav("share")
    return head() + frame(inner) + TAIL


SCREENS = {
    "Connect.dc.html": connect_screen,
    "Main.dc.html": main_screen,
    "Apps.dc.html": apps_screen,
    "Screen.dc.html": screen_screen,
    "Share.dc.html": share_screen,
}

if __name__ == "__main__":
    for name, fn in SCREENS.items():
        with open(os.path.join(HERE, name), "w", encoding="utf-8") as f:
            f.write(fn())
        print("wrote", name)
