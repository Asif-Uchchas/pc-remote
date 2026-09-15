import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../remote_client.dart';

/// Multi-touch trackpad.
///
/// * 1 finger move  -> mouse move
/// * 1 finger tap   -> left click
/// * 2 finger tap   -> right click
/// * 2 finger drag  -> scroll
/// * tap, then press & hold -> drag (button held until release)
class Touchpad extends StatefulWidget {
  final RemoteClient client;
  final double sensitivity;
  final double scrollSensitivity;

  const Touchpad({
    super.key,
    required this.client,
    this.sensitivity = 1.6,
    this.scrollSensitivity = 1.0,
  });

  @override
  State<Touchpad> createState() => _TouchpadState();
}

class _TouchpadState extends State<Touchpad> {
  static const _tapMaxMs = 250;
  static const _tapMaxMove = 12.0;
  static const _dragTapWindowMs = 300;
  static const _scrollStepPx = 18.0;

  final Map<int, Offset> _pointers = {};
  int _maxPointers = 0;
  DateTime? _downTime;
  double _travel = 0;

  // Fractional accumulators so slow movements are not lost to rounding.
  double _accX = 0, _accY = 0;
  double _scrollAcc = 0, _scrollAccX = 0;

  DateTime? _lastTapUp;
  bool _dragging = false;

  void _onDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _downTime = DateTime.now();
      _travel = 0;
      _maxPointers = 1;
      _accX = _accY = _scrollAcc = _scrollAccX = 0;

      final last = _lastTapUp;
      if (last != null &&
          DateTime.now().difference(last).inMilliseconds < _dragTapWindowMs) {
        // Tap followed quickly by a press: start a drag.
        _dragging = true;
        widget.client.buttonDown('left');
        HapticFeedback.selectionClick();
      }
    } else {
      _maxPointers = _maxPointers < _pointers.length ? _pointers.length : _maxPointers;
    }
  }

  void _onMove(PointerMoveEvent e) {
    final prev = _pointers[e.pointer];
    if (prev == null) return;
    final delta = e.localPosition - prev;
    _pointers[e.pointer] = e.localPosition;
    _travel += delta.distance;

    if (_pointers.length == 1) {
      _accX += delta.dx * widget.sensitivity;
      _accY += delta.dy * widget.sensitivity;
      final dx = _accX.truncate();
      final dy = _accY.truncate();
      if (dx != 0 || dy != 0) {
        widget.client.move(dx, dy);
        _accX -= dx;
        _accY -= dy;
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

  void _onUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isNotEmpty) return;

    final now = DateTime.now();
    final downTime = _downTime;
    final isTap = downTime != null &&
        now.difference(downTime).inMilliseconds <= _tapMaxMs &&
        _travel <= _tapMaxMove * _maxPointers;

    if (_dragging) {
      widget.client.buttonUp('left');
      _dragging = false;
      _lastTapUp = null;
    } else if (isTap) {
      if (_maxPointers == 1) {
        widget.client.click(button: 'left');
        _lastTapUp = now;
      } else if (_maxPointers == 2) {
        widget.client.click(button: 'right');
        _lastTapUp = null;
      } else if (_maxPointers >= 3) {
        widget.client.click(button: 'middle');
        _lastTapUp = null;
      }
      HapticFeedback.lightImpact();
    } else {
      _lastTapUp = null;
    }
    _downTime = null;
    _maxPointers = 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Center(
          child: Opacity(
            opacity: 0.35,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_outlined, size: 40, color: scheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text('Touchpad', style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  'tap: click • 2 fingers: right-click / scroll\ntap then hold: drag',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
