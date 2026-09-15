import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Connection lifecycle as seen by the UI.
enum ConnectionStatus { disconnected, connecting, connected, error }

/// TCP client for the newline-delimited JSON protocol implemented by
/// `server/server.py`.
class RemoteClient extends ChangeNotifier {
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _pcName = '';
  String _errorMessage = '';

  Socket? _socket;
  StreamSubscription<String>? _sub;

  ConnectionStatus get status => _status;
  String get pcName => _pcName;
  String get errorMessage => _errorMessage;
  bool get isConnected => _status == ConnectionStatus.connected;

  void _set(ConnectionStatus s, {String pcName = '', String error = ''}) {
    _status = s;
    _pcName = pcName;
    _errorMessage = error;
    notifyListeners();
  }

  Future<bool> connect({
    required String host,
    required int port,
    required String pin,
    String deviceName = 'Android',
  }) async {
    await disconnect();
    _set(ConnectionStatus.connecting);
    try {
      final socket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 4));
      socket.setOption(SocketOption.tcpNoDelay, true);

      final lines = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();

      // Handshake: first line back must be {"t":"ok"}.
      final firstLine = lines.first.timeout(const Duration(seconds: 4));
      socket.write('${jsonEncode({
            't': 'hello',
            'pin': pin,
            'name': deviceName,
          })}\n');
      await socket.flush();
      final reply = jsonDecode(await firstLine) as Map<String, dynamic>;
      if (reply['t'] != 'ok') {
        socket.destroy();
        _set(ConnectionStatus.error,
            error: (reply['msg'] as String?) ?? 'Rejected by server');
        return false;
      }

      _socket = socket;
      _sub = lines.listen(
        (_) {}, // server replies (pong / err) are informational only
        onDone: () => _onLost('Server disconnected'),
        onError: (Object e) => _onLost(e.toString()),
        cancelOnError: true,
      );
      _set(ConnectionStatus.connected,
          pcName: (reply['name'] as String?) ?? host);
      return true;
    } on TimeoutException {
      _set(ConnectionStatus.error, error: 'Timed out — is the server running?');
    } on SocketException catch (e) {
      _set(ConnectionStatus.error,
          error: e.osError?.message ?? e.message);
    } catch (e) {
      _set(ConnectionStatus.error, error: e.toString());
    }
    return false;
  }

  void _onLost(String reason) {
    _closeSocket();
    if (_status == ConnectionStatus.connected) {
      _set(ConnectionStatus.error, error: reason);
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    _closeSocket();
    if (_status != ConnectionStatus.disconnected) {
      _set(ConnectionStatus.disconnected);
    }
  }

  void _closeSocket() {
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
  }

  void _send(Map<String, Object?> msg) {
    final s = _socket;
    if (s == null || !isConnected) return;
    try {
      s.write('${jsonEncode(msg)}\n');
    } catch (e) {
      _onLost(e.toString());
    }
  }

  // ---- Commands ---------------------------------------------------------

  void move(int dx, int dy) {
    if (dx == 0 && dy == 0) return;
    _send({'t': 'mv', 'dx': dx, 'dy': dy});
  }

  void click({String button = 'left', int count = 1}) =>
      _send({'t': 'click', 'b': button, 'n': count});

  void buttonDown([String button = 'left']) => _send({'t': 'down', 'b': button});
  void buttonUp([String button = 'left']) => _send({'t': 'up', 'b': button});

  void scroll(int dx, int dy) {
    if (dx == 0 && dy == 0) return;
    _send({'t': 'scroll', 'dx': dx, 'dy': dy});
  }

  void typeText(String text) {
    if (text.isEmpty) return;
    _send({'t': 'text', 's': text});
  }

  void key(String name, [List<String> mods = const []]) =>
      _send({'t': 'key', 'k': name, 'mods': mods});

  void ping() => _send({'t': 'ping'});

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
