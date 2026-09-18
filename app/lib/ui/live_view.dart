import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../remote_client.dart';
import '../screen_stream.dart';
import '../theme.dart';

/// The PC screen image with "direct touch" gestures:
///
/// * 1 finger drag   -> pointer follows the finger (absolute)
/// * 1 finger tap    -> left click at that spot (double tap = double click)
/// * hold still      -> press & hold (drag windows / select text), release to drop
/// * 2 finger tap    -> right click at that spot
/// * 2 finger drag   -> scroll
class LiveView extends StatefulWidget {
  final RemoteClient client;
  final ScreenStream stream;
  final int monitor;
  final double aspect;
  final bool haptics;
  final BoxFit fit;
  final VoidCallback? onRetry;

  const LiveView({
    super.key,
    required this.client,
    required this.stream,
    required this.monitor,
    required this.aspect,
    this.haptics = true,
    this.fit = BoxFit.contain,
    this.onRetry,
  });

  @override
  State<LiveView> createState() => _LiveViewState();
}

class _LiveViewState extends State<LiveView> {
  static const _tapMaxMs = 220;
  static const _tapMaxMove = 10.0;
  static const _holdMs = 400;
  static const _doubleTapMs = 300;
  static const _scrollStepPx = 16.0;
  static const _moveIntervalMs = 12; // ~80 Hz cap on absolute moves

  final Map<int, Offset> _pointers = {};
  Rect _image = Rect.zero; // where the frame is drawn inside the widget
  int _maxPointers = 0;
  DateTime? _downTime;
  DateTime? _lastTapUp;
  Offset? _lastTapPos;
  double _travel = 0;
  bool _holding = false;
  Timer? _holdTimer;
  DateTime _lastMoveSent = DateTime.fromMillisecondsSinceEpoch(0);
  Offset? _pendingMove;
  Timer? _moveFlush;
  double _scrollAcc = 0, _scrollAccX = 0;

  Offset _frac(Offset local) => Offset(
        ((local.dx - _image.left) / _image.width).clamp(0.0, 1.0),
        ((local.dy - _image.top) / _image.height).clamp(0.0, 1.0),
      );

  void _haptic([bool medium = false]) {
    if (!widget.haptics) return;
    medium ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
  }

  void _sendMove(Offset local) {
    final f = _frac(local);
    final now = DateTime.now();
    if (now.difference(_lastMoveSent).inMilliseconds >= _moveIntervalMs) {
      _lastMoveSent = now;
      _pendingMove = null;
      widget.client.moveAbs(f.dx, f.dy, monitor: widget.monitor);
    } else {
      _pendingMove = local;
      _moveFlush ??= Timer(const Duration(milliseconds: _moveIntervalMs), () {
        _moveFlush = null;
        final p = _pendingMove;
        if (p != null) _sendMove(p);
      });
    }
  }

  void _onDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 1) {
      _downTime = DateTime.now();
      _travel = 0;
      _maxPointers = 1;
      _scrollAcc = _scrollAccX = 0;
      _holdTimer?.cancel();
      _holdTimer = Timer(const Duration(milliseconds: _holdMs), () {
        if (_pointers.length == 1 && _travel <= _tapMaxMove && !_holding) {
          _holding = true;
          _sendMove(e.localPosition);
          widget.client.buttonDown('left');
          _haptic(true);
          setState(() {});
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
    if (_travel > _tapMaxMove && !_holding) _holdTimer?.cancel();

    if (_pointers.length == 1) {
      if (_travel > _tapMaxMove / 2 || _holding) _sendMove(e.localPosition);
    } else if (_pointers.length == 2) {
      _scrollAcc += delta.dy / 2;
      _scrollAccX += delta.dx / 2;
      final steps = (_scrollAcc / _scrollStepPx).truncate();
      final stepsX = (_scrollAccX / _scrollStepPx).truncate();
      if (steps != 0 || stepsX != 0) {
        widget.client.scroll(stepsX, -steps);
        _scrollAcc -= steps * _scrollStepPx;
        _scrollAccX -= stepsX * _scrollStepPx;
      }
    }
  }

  void _onUp(PointerEvent e) {
    final pos = _pointers[e.pointer] ?? e.localPosition;
    _pointers.remove(e.pointer);
    if (_pointers.isNotEmpty) return;
    _holdTimer?.cancel();
    final now = DateTime.now();
    final isTap = _downTime != null &&
        now.difference(_downTime!).inMilliseconds <= _tapMaxMs &&
        _travel <= _tapMaxMove * _maxPointers;

    if (_holding) {
      widget.client.buttonUp('left');
      _holding = false;
      setState(() {});
    } else if (isTap) {
      final f = _frac(pos);
      if (_maxPointers == 1) {
        final isDouble = _lastTapUp != null &&
            now.difference(_lastTapUp!).inMilliseconds < _doubleTapMs &&
            _lastTapPos != null &&
            (_lastTapPos! - pos).distance < 30;
        widget.client.clickAt(f.dx, f.dy, monitor: widget.monitor, count: isDouble ? 2 : 1);
        _lastTapUp = isDouble ? null : now;
        _lastTapPos = pos;
      } else if (_maxPointers == 2) {
        widget.client.clickAt(f.dx, f.dy, monitor: widget.monitor, button: 'right');
        _lastTapUp = null;
      }
      _haptic();
    } else {
      _lastTapUp = null;
    }
    _downTime = null;
    _maxPointers = 0;
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _moveFlush?.cancel();
    if (_holding) widget.client.buttonUp('left');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (ctx, c) {
          // Fit the monitor's aspect ratio inside the available box.
          final box = Size(c.maxWidth, c.maxHeight);
          double w = box.width, h = w / widget.aspect;
          if (h > box.height) {
            h = box.height;
            w = h * widget.aspect;
          }
          _image = Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: _onUp,
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: _image,
                  child: ValueListenableBuilder<String?>(
                    valueListenable: widget.stream.error,
                    builder: (_, err, _) => err != null
                        ? ColoredBox(
                            color: T.surface,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(err, style: const TextStyle(color: T.muted, fontSize: 12)),
                                  if (widget.onRetry != null) ...[
                                    const SizedBox(height: 8),
                                    TextButton(onPressed: widget.onRetry, child: const Text('RETRY', style: TextStyle(color: T.accent))),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : ValueListenableBuilder<Uint8List?>(
                            valueListenable: widget.stream.frame,
                            builder: (_, bytes, _) => bytes == null
                                ? const ColoredBox(
                                    color: T.surface,
                                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: T.accent))),
                                  )
                                : Image.memory(bytes, gaplessPlayback: true, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
                          ),
                  ),
                ),
                if (_holding)
                  Positioned.fromRect(
                    rect: _image,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(border: Border.all(color: T.accent, width: 2)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

/// Landscape, immersive live view. Pops itself when the phone is rotated back.
class FullscreenLiveView extends StatefulWidget {
  final RemoteClient client;
  final ScreenStream stream;
  final int monitor;
  final double aspect;
  final bool haptics;
  final VoidCallback onRetry;
  /// Opened because the phone was rotated: rotating back to portrait exits.
  /// Opened from the button: stay in landscape until EXIT is tapped.
  final bool exitOnPortrait;
  const FullscreenLiveView({
    super.key,
    required this.client,
    required this.stream,
    required this.monitor,
    required this.aspect,
    required this.haptics,
    required this.onRetry,
    this.exitOnPortrait = false,
  });

  @override
  State<FullscreenLiveView> createState() => _FullscreenLiveViewState();
}

class _FullscreenLiveViewState extends State<FullscreenLiveView> {
  bool _chrome = false;
  Timer? _chromeTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (!widget.exitOnPortrait) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _showChrome() {
    setState(() => _chrome = true);
    _chromeTimer?.cancel();
    _chromeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _chrome = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exitOnPortrait && MediaQuery.of(context).orientation == Orientation.portrait) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
    return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: LiveView(
                client: widget.client,
                stream: widget.stream,
                monitor: widget.monitor,
                aspect: widget.aspect,
                haptics: widget.haptics,
                onRetry: widget.onRetry,
              ),
            ),
            // Small handle at the top-right: tap to reveal the exit button.
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _showChrome,
                  child: AnimatedOpacity(
                    opacity: _chrome ? 1 : 0.35,
                    duration: const Duration(milliseconds: 150),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _chrome
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ValueListenableBuilder<double>(
                                  valueListenable: widget.stream.fps,
                                  builder: (_, f, _) => Text('${f.round()} FPS', style: T.label.copyWith(color: T.text2)),
                                ),
                                const SizedBox(width: 10),
                                Material(
                                  color: T.surface2,
                                  borderRadius: T.r10,
                                  child: InkWell(
                                    borderRadius: T.r10,
                                    onTap: () => Navigator.of(context).maybePop(),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Row(children: [Icon(Icons.fullscreen_exit, size: 18, color: T.text), SizedBox(width: 6), Text('EXIT', style: TextStyle(fontFamily: T.mono, fontSize: 11, color: T.text))]),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: T.surface2.withValues(alpha: 0.7), borderRadius: T.r10),
                              child: const Icon(Icons.more_horiz, size: 18, color: T.text2),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }
}
