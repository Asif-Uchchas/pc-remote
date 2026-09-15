import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../remote_client.dart';
import '../screen_stream.dart';
import '../settings.dart';
import '../theme.dart';
import 'touchpad.dart';
import 'widgets.dart';

enum Quality { smooth, balanced, sharp }

/// Live view of the PC screen with tap-to-click.
class ScreenScreen extends StatefulWidget {
  final RemoteClient client;
  final Settings settings;
  const ScreenScreen({super.key, required this.client, required this.settings});

  @override
  State<ScreenScreen> createState() => _ScreenScreenState();
}

class _ScreenScreenState extends State<ScreenScreen> {
  ScreenStream? _stream;
  Quality _quality = Quality.balanced;
  int _monitor = 1;
  List<Map<String, dynamic>> _monitors = const [];
  final _viewer = TransformationController();

  bool get _supported => widget.client.serverSupports('screen');

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _stream?.dispose();
    _viewer.dispose();
    super.dispose();
  }

  void _tap(TapUpDetails d, Size box, String button) {
    // Position within the (possibly zoomed) image, as 0..1 fractions.
    final scenePoint = _viewer.toScene(d.localPosition);
    final fx = (scenePoint.dx / box.width).clamp(0.0, 1.0);
    final fy = (scenePoint.dy / box.height).clamp(0.0, 1.0);
    widget.client.clickAt(fx, fy, monitor: _monitor, button: button);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Screen preview needs the mss and Pillow packages on the PC:\npip install mss Pillow',
              textAlign: TextAlign.center, style: TextStyle(color: T.muted, height: 1.6)),
        ),
      );
    }
    final stream = _stream;
    final mon = _monitors.where((m) => m['index'] == _monitor).firstOrNull;
    final aspect = mon == null ? 16 / 9 : (mon['w'] as num) / (mon['h'] as num);
    final (fps, w, _) = _params;

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
        ClipRRect(
          borderRadius: T.r12,
          child: Container(
            decoration: BoxDecoration(borderRadius: T.r12, border: Border.all(color: T.line2)),
            child: AspectRatio(
              aspectRatio: aspect,
              child: LayoutBuilder(
                builder: (ctx, c) {
                  final box = Size(c.maxWidth, c.maxHeight);
                  return stream == null
                      ? const SizedBox()
                      : ValueListenableBuilder<String?>(
                          valueListenable: stream.error,
                          builder: (_, err, _) => err != null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(err, style: const TextStyle(color: T.muted, fontSize: 12)),
                                      const SizedBox(height: 8),
                                      ConsoleButton(height: 36, onTap: _restart, child: const Text('RETRY')),
                                    ],
                                  ),
                                )
                              : InteractiveViewer(
                                  transformationController: _viewer,
                                  minScale: 1,
                                  maxScale: 5,
                                  child: GestureDetector(
                                    onTapUp: (d) => _tap(d, box, 'left'),
                                    onLongPressEnd: (d) => _tap(TapUpDetails(kind: PointerDeviceKind.touch, localPosition: d.localPosition, globalPosition: d.globalPosition), box, 'right'),
                                    child: ValueListenableBuilder<Uint8List?>(
                                      valueListenable: stream.frame,
                                      builder: (_, bytes, _) => bytes == null
                                          ? const ColoredBox(
                                              color: T.surface,
                                              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: T.accent))),
                                            )
                                          : Image.memory(
                                              bytes,
                                              gaplessPlayback: true,
                                              fit: BoxFit.fill,
                                              width: box.width,
                                              height: box.height,
                                            ),
                                    ),
                                  ),
                                ),
                        );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text('Tap the preview to click there · long-press for right-click · pinch to zoom',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: T.muted)),
        const SizedBox(height: 10),
        const SectionLabel('Quality'),
        const SizedBox(height: 6),
        Segmented<Quality>(
          options: const [(Quality.smooth, 'Smooth'), (Quality.balanced, 'Balanced'), (Quality.sharp, 'Sharp')],
          value: _quality,
          onChanged: (q) {
            setState(() => _quality = q);
            _restart();
          },
        ),
        if (_monitors.length > 1) ...[
          const SizedBox(height: 10),
          const SectionLabel('Monitor'),
          const SizedBox(height: 6),
          Segmented<int>(
            options: [for (final m in _monitors) (m['index'] as int, '${m['index']} · ${m['w']}×${m['h']}')],
            value: _monitor,
            onChanged: (i) {
              setState(() => _monitor = i);
              _restart();
            },
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.settings,
            builder: (_, _) => Touchpad(
              client: widget.client,
              sensitivity: widget.settings.sensitivity,
              scrollSensitivity: widget.settings.scrollSensitivity,
              haptics: widget.settings.haptics,
            ),
          ),
        ),
      ],
    );
  }
}
