# PyInstaller spec — build with:  python -m PyInstaller MobileRemote.spec
# -*- mode: python ; coding: utf-8 -*-

a = Analysis(
    ["server.py"],
    pathex=[],
    binaries=[],
    datas=[("icon.png", ".")],
    hiddenimports=["pystray._win32", "pynput.keyboard._win32", "pynput.mouse._win32", "psutil"],
    hookspath=[],
    runtime_hooks=[],
    excludes=["tkinter", "unittest", "test", "email", "http", "xml", "pydoc"],
    noarchive=False,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="MobileRemote",
    icon="icon.ico",
    console=False,          # tray app; PIN is shown in a dialog / tray menu
    upx=False,
    strip=False,
    disable_windowed_traceback=False,
    version="version_info.txt",
)
