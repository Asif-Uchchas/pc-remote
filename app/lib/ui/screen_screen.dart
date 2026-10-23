import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../remote_client.dart';
import '../screen_stream.dart';
import '../settings.dart';
import '../theme.dart';
import 'live_view.dart';
import 'widgets.dart';

enum Quality { smooth, balanced, sharp }

/// Live view of the PC screen with direct-touch control.
/// Rotating the phone to landscape opens the immersive fullscreen view.
class ScreenScreen extends StatefulWidget {
  final RemoteClient client;
  final Settings settings;
  const ScreenScreen({super.key, required this.client, required this.settings});

  @override
  State<ScreenScreen> createState() => _ScreenScreenState();
}

class _ScreenScreenState extends State<ScreenScreen> with WidgetsBindingObserver {
  ScreenStream? _stream;
  Quality _quality = Quality.balanced;
  int _monitor = 1;
  List<Map<String, dynamic>> _monitors = const [];
  bool _fullscreenOpen = false;
  bool _paused = false;

  bool get _supported => widget.client.serverSupports('screen');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_supported) _init();
  }

  Future<void> _init() async {
    try {
      final r = await widget.client.request({'t': 'monitors'});
      if (mounted) setState(() => _monitors = ((r['monitors'] as List?) ?? const []).cast<Map<String, dynamic>>());
    } catch (_) {}
    _restart();
  }

  (int, int, int) get _params => switch (_quality) {
        Quality.smooth => (10, 854, 45),
        Quality.balanced => (12, 1280, 60),
        Quality.sharp => (8, 1920, 78),
      };

  Future<void> _restart() async {
    _stream?.dispose();
    final s = ScreenStream(host: widget.client.host, port: widget.client.port, pin: widget.client.pin);
    setState(() => _stream = s);
    final (fps, w, q) = _params;
    await s.start(fpsTarget: fps, width: w, quality: q, monitor: _monitor);
  }

  // Stop streaming while the app is in the background (battery + bandwidth).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bg = state != AppLifecycleState.resumed;
    if (bg && !_paused) {
      _paused = true;
      _stream?.stop();
    } else if (!bg && _paused) {
      _paused = false;
      if (widget.client.isConnected) _restart();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stream?.dispose();
    super.dispose();
  }

  double get _aspect {
    final mon = _monitors.where((m) => m['index'] == _monitor).firstOrNull;
    return mon == null ? 16 / 9 : (mon['w'] as num) / (mon['h'] as num);
  }

  Future<void> _openFullscreen({bool fromRotation = false}) async {
    final stream = _stream;
    if (stream == null || _fullscreenOpen) return;
    _fullscreenOpen = true;
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, a, _) => FadeTransition(
        opacity: a,
        child: FullscreenLiveView(
          client: widget.client,
          stream: stream,
          monitor: _monitor,
          aspect: _aspect,
          haptics: widget.settings.haptics,
          onRetry: _restart,
          exitOnPortrait: fromRotation,
        ),
      ),
    ));
    _fullscreenOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) {
      final linux = widget.client.pcIsLinux;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            linux
                ? 'Screen preview needs grim on the PC (Wayland):\nsudo pacman -S grim'
                : 'Screen preview needs the mss and Pillow packages on the PC:\npip install mss Pillow',
            textAlign: TextAlign.center,
            style: const TextStyle(color: T.muted, height: 1.6),
          ),
        ),
      );
    }
    final stream = _stream;
    final (fps, w, _) = _params;

    // Landscape -> go immersive automatically.
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (landscape && !_fullscreenOpen && stream != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFullscreen(fromRotation: true));
    }

    return Column(
      children: [
        SectionLabel(
          'Live view',
          trailing: stream == null
              ? null
              : ValueListenableBuilder<double>(
                  valueListenable: stream.fps,
                  builder: (_, f, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusDot(color: f > 0 ? T.ok : T.dim),
                      const SizedBox(width: 6),
                      Text('${f.round()} FPS · ${w}p · ${fps}fps max', style: T.label),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: T.r12,
            child: Container(
              decoration: BoxDecoration(color: T.bg, borderRadius: T.r12, border: Border.all(color: T.line2)),
              child: stream == null
                  ? const SizedBox()
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: LiveView(
                            client: widget.client,
                            stream: stream,
                            monitor: _monitor,
                            aspect: _aspect,
                            haptics: widget.settings.haptics,
                            onRetry: _restart,
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Material(
                            color: T.surface2.withValues(alpha: 0.85),
                            borderRadius: T.r10,
                            child: InkWell(
                              borderRadius: T.r10,
                              onTap: _openFullscreen,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.fullscreen, size: 20, color: T.text),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Finger = pointer · tap = click · hold = drag · 2 fingers = right-click / scroll · rotate for fullscreen',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: T.muted, height: 1.4),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Segmented<Quality>(
                options: const [(Quality.smooth, 'Smooth'), (Quality.balanced, 'Balanced'), (Quality.sharp, 'Sharp')],
                value: _quality,
                onChanged: (q) {
                  setState(() => _quality = q);
                  _restart();
                },
              ),
            ),
            if (_monitors.length > 1) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Segmented<int>(
                  options: [for (final m in _monitors) (m['index'] as int, 'Mon ${m['index']}')],
                  value: _monitor,
                  onChanged: (i) {
                    setState(() => _monitor = i);
                    _restart();
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
