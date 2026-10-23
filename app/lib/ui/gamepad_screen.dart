import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../remote_client.dart';
import '../settings.dart';
import '../theme.dart';

/// Button bit positions — must match server/gamepad.py BUTTONS.
const _btnA = 1 << 0, _btnB = 1 << 1, _btnX = 1 << 2, _btnY = 1 << 3;
const _btnLB = 1 << 4, _btnRB = 1 << 5, _btnBack = 1 << 6, _btnStart = 1 << 7;
const _btnLS = 1 << 8, _btnRS = 1 << 9;
const _btnDU = 1 << 10, _btnDD = 1 << 11, _btnDL = 1 << 12, _btnDR = 1 << 13;

/// Full-screen landscape virtual controller.
class GamepadScreen extends StatefulWidget {
  final RemoteClient client;
  final Settings settings;
  const GamepadScreen({super.key, required this.client, required this.settings});

  @override
  State<GamepadScreen> createState() => _GamepadScreenState();
}

class _GamepadScreenState extends State<GamepadScreen> {
  int _buttons = 0;
  Offset _left = Offset.zero, _right = Offset.zero;
  double _lt = 0, _rt = 0;
  String _mode = 'keys';
  String _modeNote = '';
  Timer? _tick;
  bool _dirty = false;

  bool get _xboxAvailable => widget.client.serverSupports('gamepad_xbox');

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SharedPreferences.getInstance().then((p) {
      final m = p.getString('padMode') ?? (_xboxAvailable ? 'xbox' : 'keys');
      _setMode(m);
    });
    // Send state at most every 16 ms, and a keep-alive every 250 ms.
    var n = 0;
    _tick = Timer.periodic(const Duration(milliseconds: 16), (_) {
      n++;
      if (_dirty || n % 16 == 0) {
        _dirty = false;
        widget.client.send({
          't': 'pad',
          'b': _buttons,
          'lx': _r(_left.dx), 'ly': _r(_left.dy),
          'rx': _r(_right.dx), 'ry': _r(_right.dy),
          'lt': _r(_lt), 'rt': _r(_rt),
        });
      }
    });
  }

  double _r(double v) => (v * 100).round() / 100;

  Future<void> _setMode(String m) async {
    try {
      final r = await widget.client.request({'t': 'pad_mode', 'mode': m});
      if (!mounted) return;
      setState(() {
        _mode = m;
        _modeNote = (r['msg'] as String?) ?? '';
        if ((r['mode'] as String? ?? '').startsWith('keys') && m == 'xbox') _mode = 'keys';
      });
      final p = await SharedPreferences.getInstance();
      await p.setString('padMode', _mode);
    } catch (_) {}
  }

  void _press(int bit, bool down) {
    final was = _buttons;
    _buttons = down ? (_buttons | bit) : (_buttons & ~bit);
    if (_buttons != was) {
      _dirty = true;
      if (down && widget.settings.haptics) HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    widget.client.send({'t': 'pad', 'b': 0, 'lx': 0, 'ly': 0, 'rx': 0, 'ry': 0, 'lt': 0, 'rt': 0});
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                // Top row: bumpers / triggers, mode, exit
                Row(
                  children: [
                    _Trigger(label: 'LT', onChanged: (v) { _lt = v; _dirty = true; }),
                    const SizedBox(width: 6),
                    _PadButton(label: 'LB', width: 72, height: 40, down: _buttons & _btnLB != 0, onChange: (d) => _press(_btnLB, d)),
                    const Spacer(),
                    _PadButton(label: 'BACK', width: 64, height: 32, small: true, down: _buttons & _btnBack != 0, onChange: (d) => _press(_btnBack, d)),
                    const SizedBox(width: 8),
                    _ModeToggle(mode: _mode, xboxAvailable: _xboxAvailable, onChanged: _setMode),
                    const SizedBox(width: 8),
                    _PadButton(label: 'START', width: 64, height: 32, small: true, down: _buttons & _btnStart != 0, onChange: (d) => _press(_btnStart, d)),
                    const Spacer(),
                    _PadButton(label: 'RB', width: 72, height: 40, down: _buttons & _btnRB != 0, onChange: (d) => _press(_btnRB, d)),
                    const SizedBox(width: 6),
                    _Trigger(label: 'RT', onChanged: (v) { _rt = v; _dirty = true; }),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: T.surface2, borderRadius: T.r10, border: Border.all(color: T.line2)),
                        child: const Icon(Icons.close, size: 18, color: T.text2),
                      ),
                    ),
                  ],
                ),
                if (_modeNote.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_modeNote, style: const TextStyle(fontSize: 10, color: T.danger), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                Expanded(
                  child: Row(
                    children: [
                      // Left: stick + d-pad
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: Center(child: _Joystick(size: 150, onChanged: (o) { _left = o; _dirty = true; }, onPress: (d) => _press(_btnLS, d)))),
                            Expanded(child: Center(child: _DPad(buttons: _buttons, onPress: _press))),
                          ],
                        ),
                      ),
                      // Right: ABXY + stick
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: Center(child: _Joystick(size: 120, onChanged: (o) { _right = o; _dirty = true; }, onPress: (d) => _press(_btnRS, d)))),
                            Expanded(child: Center(child: _FaceButtons(buttons: _buttons, onPress: _press))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _mode == 'xbox'
                      ? 'Virtual Xbox 360 controller — games see a real gamepad'
                      : 'Keyboard mode — arrows · Z X A S · Q W E R · Enter Backspace',
                  style: const TextStyle(fontSize: 10, color: T.dim),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ModeToggle extends StatelessWidget {
  final String mode;
  final bool xboxAvailable;
  final ValueChanged<String> onChanged;
  const _ModeToggle({required this.mode, required this.xboxAvailable, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: T.surface, borderRadius: T.r10, border: Border.all(color: T.line)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (m, label) in [('xbox', 'XBOX'), ('keys', 'KEYS')])
              GestureDetector(
                onTap: (m == 'xbox' && !xboxAvailable) ? null : () => onChanged(m),
                child: Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: mode == m ? T.accent : Colors.transparent,
                    borderRadius: const BorderRadius.all(Radius.circular(7)),
                  ),
                  alignment: Alignment.center,
                  child: Text(label,
                      style: TextStyle(
                          fontFamily: T.mono,
                          fontSize: 10,
                          letterSpacing: 1,
                          color: mode == m ? T.bg : ((m == 'xbox' && !xboxAvailable) ? T.dim : T.muted))),
                ),
              ),
          ],
        ),
      );
}

/// Press-and-hold button that reports down/up (multi-touch safe: one pointer each).
class _PadButton extends StatelessWidget {
  final String label;
  final double width, height;
  final bool down;
  final bool small;
  final Color? color;
  final ValueChanged<bool> onChange;
  const _PadButton({
    required this.label,
    required this.width,
    required this.height,
    required this.down,
    required this.onChange,
    this.small = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onChange(true),
        onPointerUp: (_) => onChange(false),
        onPointerCancel: (_) => onChange(false),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: down ? (color ?? T.accent) : T.surface2,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: down ? (color ?? T.accent) : (color ?? T.line2).withValues(alpha: color == null ? 1 : 0.6), width: color == null ? 1 : 1.5),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontFamily: T.mono,
                  fontSize: small ? 10 : 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: down ? T.bg : (color ?? T.text2))),
        ),
      );
}

/// Analog trigger: drag down to pull; releases when the finger lifts.
class _Trigger extends StatefulWidget {
  final String label;
  final ValueChanged<double> onChanged;
  const _Trigger({required this.label, required this.onChanged});

  @override
  State<_Trigger> createState() => _TriggerState();
}

class _TriggerState extends State<_Trigger> {
  double _v = 0;
  Offset? _start;

  void _set(double v) {
    setState(() => _v = v.clamp(0.0, 1.0));
    widget.onChanged(_v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _start = e.localPosition;
          _set(1);
        },
        onPointerMove: (e) {
          if (_start == null) return;
          // Slide down from the tap point to feather the trigger between 1 and 0.3.
          final dy = (e.localPosition.dy - _start!.dy);
          _set(1 - (dy / 120).clamp(0.0, 0.7));
        },
        onPointerUp: (_) => _set(0),
        onPointerCancel: (_) => _set(0),
        child: Container(
          width: 56,
          height: 40,
          decoration: BoxDecoration(
            color: Color.lerp(T.surface2, T.accent, _v),
            borderRadius: T.r10,
            border: Border.all(color: _v > 0 ? T.accent : T.line2),
          ),
          alignment: Alignment.center,
          child: Text(widget.label,
              style: TextStyle(fontFamily: T.mono, fontSize: 12, fontWeight: FontWeight.w600, color: _v > 0.5 ? T.bg : T.text2)),
        ),
      );
}

class _Joystick extends StatefulWidget {
  final double size;
  final ValueChanged<Offset> onChanged; // -1..1 each axis, y down positive
  final ValueChanged<bool> onPress; // stick click (tap without moving)
  const _Joystick({required this.size, required this.onChanged, required this.onPress});

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  Offset _knob = Offset.zero; // -1..1
  int? _pointer;
  bool _moved = false;

  void _update(Offset local) {
    final c = widget.size / 2;
    var v = (local - Offset(c, c)) / (c - 20);
    if (v.distance > 1) v = v / v.distance;
    if (v.distance > 0.1) _moved = true;
    setState(() => _knob = v);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.size / 2;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_pointer != null) return;
        _pointer = e.pointer;
        _moved = false;
        _update(e.localPosition);
      },
      onPointerMove: (e) {
        if (e.pointer == _pointer) _update(e.localPosition);
      },
      onPointerUp: (e) {
        if (e.pointer != _pointer) return;
        _pointer = null;
        if (!_moved) {
          widget.onPress(true);
          Future<void>.delayed(const Duration(milliseconds: 80), () => widget.onPress(false));
        }
        setState(() => _knob = Offset.zero);
        widget.onChanged(Offset.zero);
      },
      onPointerCancel: (e) {
        _pointer = null;
        setState(() => _knob = Offset.zero);
        widget.onChanged(Offset.zero);
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: T.surface,
                border: Border.all(color: _pointer != null ? T.accent : T.line2),
              ),
            ),
            Positioned(
              left: r + _knob.dx * (r - 20) - 22,
              top: r + _knob.dy * (r - 20) - 22,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _pointer != null ? T.accent : T.surface2,
                  border: Border.all(color: _pointer != null ? T.accent : T.line2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DPad extends StatelessWidget {
  final int buttons;
  final void Function(int bit, bool down) onPress;
  const _DPad({required this.buttons, required this.onPress});

  Widget _k(String label, int bit) => _PadButton(label: label, width: 44, height: 44, down: buttons & bit != 0, onChange: (d) => onPress(bit, d));

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          children: [
            Positioned(left: 48, top: 0, child: _k('▲', _btnDU)),
            Positioned(left: 48, bottom: 0, child: _k('▼', _btnDD)),
            Positioned(left: 0, top: 48, child: _k('◀', _btnDL)),
            Positioned(right: 0, top: 48, child: _k('▶', _btnDR)),
          ],
        ),
      );
}

class _FaceButtons extends StatelessWidget {
  final int buttons;
  final void Function(int bit, bool down) onPress;
  const _FaceButtons({required this.buttons, required this.onPress});

  Widget _k(String label, int bit, Color color) =>
      _PadButton(label: label, width: 52, height: 52, color: color, down: buttons & bit != 0, onChange: (d) => onPress(bit, d));

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          children: [
            Positioned(left: 54, top: 0, child: _k('Y', _btnY, const Color(0xFFFFD166))),
            Positioned(left: 54, bottom: 0, child: _k('A', _btnA, const Color(0xFF7DFFB0))),
            Positioned(left: 0, top: 54, child: _k('X', _btnX, const Color(0xFF7C9CFF))),
            Positioned(right: 0, top: 54, child: _k('B', _btnB, const Color(0xFFFF8FA3))),
          ],
        ),
      );
}

