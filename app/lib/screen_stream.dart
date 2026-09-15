import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Receives JPEG frames from the server's stream mode
/// (`<4-byte big-endian length><jpeg bytes>` after a JSON hello line).
class ScreenStream {
  final String host;
  final int port;
  final String pin;

  Socket? _socket;
  StreamSubscription<Uint8List>? _sub;
  final _buf = BytesBuilder(copy: false);
  Uint8List _pending = Uint8List(0);
  bool _gotHello = false;

  final ValueNotifier<Uint8List?> frame = ValueNotifier(null);
  final ValueNotifier<double> fps = ValueNotifier(0);
  final ValueNotifier<String?> error = ValueNotifier(null);

  int _frames = 0;
  Timer? _fpsTimer;

  ScreenStream({required this.host, required this.port, required this.pin});

  Future<void> start({int fpsTarget = 12, int width = 1280, int quality = 60, int monitor = 1}) async {
    await stop();
    error.value = null;
    try {
      final s = await Socket.connect(host, port, timeout: const Duration(seconds: 4));
      s.setOption(SocketOption.tcpNoDelay, true);
      _socket = s;
      s.write('${jsonEncode({
            't': 'hello',
            'pin': pin,
            'name': 'Android (screen)',
            'mode': 'stream',
            'fps': fpsTarget,
            'w': width,
            'q': quality,
            'mon': monitor,
          })}\n');
      await s.flush();
      _gotHello = false;
      _pending = Uint8List(0);
      _sub = s.listen(_onData, onDone: () => _fail('Stream ended'), onError: (Object e) => _fail(e.toString()));
      _fpsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        fps.value = _frames.toDouble();
        _frames = 0;
      });
    } catch (e) {
      _fail(e.toString());
    }
  }

  void _fail(String msg) {
    if (_socket != null) error.value = msg;
    stop();
  }

  void _onData(Uint8List chunk) {
    // Append to pending bytes.
    if (_pending.isEmpty) {
      _pending = chunk;
    } else {
      _buf.add(_pending);
      _buf.add(chunk);
      _pending = _buf.takeBytes();
    }
    var offset = 0;

    if (!_gotHello) {
      final nl = _pending.indexOf(10);
      if (nl < 0) return;
      final line = utf8.decode(_pending.sublist(0, nl));
      offset = nl + 1;
      _gotHello = true;
      try {
        final reply = jsonDecode(line) as Map<String, dynamic>;
        if (reply['t'] != 'ok') {
          _pending = Uint8List(0);
          _fail((reply['msg'] as String?) ?? 'Rejected');
          return;
        }
      } catch (_) {
        _fail('Bad hello');
        return;
      }
    }

    while (_pending.length - offset >= 4) {
      final bd = ByteData.sublistView(_pending, offset, offset + 4);
      final len = bd.getUint32(0);
      if (_pending.length - offset - 4 < len) break;
      frame.value = Uint8List.sublistView(_pending, offset + 4, offset + 4 + len);
      _frames++;
      offset += 4 + len;
    }
    _pending = offset == 0 ? _pending : Uint8List.sublistView(_pending, offset);
    // Detach from the original buffer so old chunks can be GC'd.
    if (_pending.isNotEmpty && _pending.offsetInBytes > 0) {
      _pending = Uint8List.fromList(_pending);
    }
  }

  Future<void> stop() async {
    _fpsTimer?.cancel();
    _fpsTimer = null;
    final s = _socket;
    _socket = null;
    await _sub?.cancel();
    _sub = null;
    if (s != null) {
      try {
        s.write('{"t":"stream_stop"}\n');
        await s.flush().timeout(const Duration(milliseconds: 500), onTimeout: () {});
      } catch (_) {}
      s.destroy();
    }
    fps.value = 0;
  }

  void dispose() {
    stop();
    frame.dispose();
    fps.dispose();
    error.dispose();
  }
}
