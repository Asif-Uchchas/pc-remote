import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../remote_client.dart';
import '../theme.dart';

/// Multi-touch trackpad.
///
/// * 1 finger move  -> mouse move
/// * 1 finger tap   -> left click
/// * 2 finger tap   -> right click
/// * 2 finger drag  -> scroll
/// * press & hold (~0.35 s) then move -> drag (button held until release)
class Touchpad extends StatefulWidget {
  final RemoteClient client;
  final double sensitivity;
  final double scrollSensitivity;
  final bool haptics;

  const Touchpad({
    super.key,
    required this.client,
    this.sensitivity = 2.5,
    this.scrollSensitivity = 1.0,
    this.haptics = true,
  });

  @override
  State<Touchpad> createState() => _TouchpadState();
}

class _TouchpadState extends State<Touchpad> {
  static const _tapMaxMs = 250;
  static const _tapMaxMove = 12.0;
  static const _holdToDragMs = 350;
  static const _scrollStepPx = 18.0;
  // Pointer acceleration: at [_accelFullSpeedPxPerMs] finger speed the
  // multiplier reaches 1 + _accelMax.
  static const _accelMax = 2.0;
  static const _accelFullSpeedPxPerMs = 2.5;

  final Map<int, Offset> _pointers = {};
  int _maxPointers = 0;
  DateTime? _downTime;
  double _travel = 0;

  // Fractional accumulators so slow movements are not lost to rounding.
  double _accX = 0, _accY = 0;
  double _scrollAcc = 0, _scrollAccX = 0;

  Duration? _lastMoveTs;
  Timer? _holdTimer;
  // Batch relative moves: at most one packet every 8 ms.
  int _batchX = 0, _batchY = 0;
  Timer? _batchTimer;
  bool _dragging = false;

  void _onDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _downTime = DateTime.now();
      _travel = 0;
      _maxPointers = 1;
      _accX = _accY = _scrollAcc = _scrollAccX = 0;
      _lastMoveTs = e.timeStamp;

      // Hold still for a moment -> start a drag (mouse button held down).
      _holdTimer?.cancel();
      _holdTimer = Timer(const Duration(milliseconds: _holdToDragMs), () {
        if (_pointers.length == 1 && _travel <= _tapMaxMove && !_dragging) {
          setState(() => _dragging = true);
          widget.client.buttonDown('left');
          if (widget.haptics) HapticFeedback.mediumImpact();
        }
      });
    } else {
      _holdTimer?.cancel();
      _maxPointers = _maxPointers < _pointers.length ? _pointers.length : _maxPointers;
    }
  }

  void _onMove(PointerMoveEvent e) {
    final prev = _pointers[e.pointer];
    if (prev == null) return;
    final delta = e.localPosition - prev;
    _pointers[e.pointer] = e.localPosition;
    _travel += delta.distance;
    if (_travel > _tapMaxMove && !_dragging) _holdTimer?.cancel();

    if (_pointers.length == 1) {
      // Speed-based acceleration so small motions stay precise while flicks
      // cross the screen.
      final dtMs = (e.timeStamp - (_lastMoveTs ?? e.timeStamp)).inMicroseconds / 1000.0;
      _lastMoveTs = e.timeStamp;
      final speed = dtMs > 0 ? delta.distance / dtMs : 0.0;
      final accel = 1 + _accelMax * (speed / _accelFullSpeedPxPerMs).clamp(0.0, 1.0);
      final gain = widget.sensitivity * accel;
      _accX += delta.dx * gain;
      _accY += delta.dy * gain;
      final dx = _accX.truncate();
      final dy = _accY.truncate();
      if (dx != 0 || dy != 0) {
        _accX -= dx;
        _accY -= dy;
        _batchX += dx;
        _batchY += dy;
        _batchTimer ??= Timer(const Duration(milliseconds: 8), _flushMoves);
      }
    } else if (_pointers.length == 2) {
      // Use the average vertical movement of the two fingers.
      _scrollAcc += delta.dy * widget.scrollSensitivity / 2;
      _scrollAccX += delta.dx * widget.scrollSensitivity / 2;
      final steps = (_scrollAcc / _scrollStepPx).truncate();
      final stepsX = (_scrollAccX / _scrollStepPx).truncate();
      if (steps != 0 || stepsX != 0) {
        // Natural scrolling: fingers down -> content down -> wheel negative.
        widget.client.scroll(stepsX, -steps);
        _scrollAcc -= steps * _scrollStepPx;
        _scrollAccX -= stepsX * _scrollStepPx;
      }
    }
  }

  void _flushMoves() {
    _batchTimer = null;
    if (_batchX != 0 || _batchY != 0) {
      widget.client.move(_batchX, _batchY);
      _batchX = _batchY = 0;
    }
  }

  void _onUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isNotEmpty) return;
    _holdTimer?.cancel();
    _batchTimer?.cancel();
    _flushMoves();

    final now = DateTime.now();
    final downTime = _downTime;
    final isTap = downTime != null &&
        now.difference(downTime).inMilliseconds <= _tapMaxMs &&
        _travel <= _tapMaxMove * _maxPointers;

    if (_dragging) {
      widget.client.buttonUp('left');
      setState(() => _dragging = false);
    } else if (isTap) {
      if (_maxPointers == 1) {
        widget.client.click(button: 'left');
      } else if (_maxPointers == 2) {
        widget.client.click(button: 'right');
      } else if (_maxPointers >= 3) {
        widget.client.click(button: 'middle');
      }
      if (widget.haptics) HapticFeedback.lightImpact();
    }
    _downTime = null;
    _maxPointers = 0;
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _batchTimer?.cancel();
    if (_dragging) widget.client.buttonUp('left');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onUp,
        child: ClipRRect(
          borderRadius: T.r16,
          child: Container(
            decoration: BoxDecoration(
              color: T.surface,
              borderRadius: T.r16,
              border: Border.all(color: _dragging ? T.accent : T.line),
            ),
            child: Stack(
              children: [
                const Positioned.fill(child: CustomPaint(painter: _DotGrid())),
                const Positioned(
                  top: 14,
                  left: 14,
                  child: Text('TRACKPAD', style: T.label),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Text('${widget.sensitivity.toStringAsFixed(1)}×', style: T.label),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18,
                  child: Text(
                    _dragging
                        ? 'DRAGGING · LIFT TO DROP'
                        : 'tap · click   ·   2 fingers · right / scroll\nhold · drag',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: T.mono,
                      fontSize: 11,
                      height: 1.6,
                      color: _dragging ? T.accent : T.dim,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DotGrid extends CustomPainter {
  const _DotGrid();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = T.grid;
    const step = 22.0;
    for (var y = step; y < size.height; y += step) {
      for (var x = step; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGrid oldDelegate) => false;
}
