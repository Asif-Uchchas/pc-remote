import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Connection lifecycle as seen by the UI.
enum ConnectionStatus { disconnected, connecting, connected, error }

/// TCP client for the newline-delimited JSON protocol implemented by
/// `server/server.py`.
class RemoteClient extends ChangeNotifier {
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _pcName = '';
  String _host = '';
  int _port = 48889;
  String _pin = '';
  String _errorMessage = '';
  Map<String, dynamic> _serverInfo = const {};

  Socket? _socket;
  StreamSubscription<String>? _sub;
  Timer? _pingTimer;
  DateTime? _pingSentAt;

  /// Round-trip time of the last ping, in milliseconds (-1 = unknown).
  final ValueNotifier<int> latencyMs = ValueNotifier(-1);

  // Request/response bookkeeping: each request carries an "id"; the server
  // echoes it back on the reply.
  int _nextId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  ConnectionStatus get status => _status;
  String get pcName => _pcName;
  String get host => _host;
  int get port => _port;
  String get pin => _pin;
  String get errorMessage => _errorMessage;
  bool get isConnected => _status == ConnectionStatus.connected;

  /// Capabilities reported by the server in its hello reply.
  Map<String, dynamic> get serverInfo => _serverInfo;
  bool serverSupports(String feature) =>
      (_serverInfo['features'] as List?)?.contains(feature) ?? false;

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
    _host = host;
    _port = port;
    _pin = pin;
    _set(ConnectionStatus.connecting);
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 4));
      socket.setOption(SocketOption.tcpNoDelay, true);

      final lines = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();

      final firstLine = lines.first.timeout(const Duration(seconds: 4));
      socket.write('${jsonEncode({'t': 'hello', 'pin': pin, 'name': deviceName, 'v': 2})}\n');
      await socket.flush();
      final reply = jsonDecode(await firstLine) as Map<String, dynamic>;
      if (reply['t'] != 'ok') {
        socket.destroy();
        _set(ConnectionStatus.error, error: (reply['msg'] as String?) ?? 'Rejected by server');
        return false;
      }

      _socket = socket;
      _serverInfo = reply;
      _sub = lines.listen(
        _onLine,
        onDone: () => _onLost('Server disconnected'),
        onError: (Object e) => _onLost(e.toString()),
        cancelOnError: true,
      );
      _set(ConnectionStatus.connected, pcName: (reply['name'] as String?) ?? host);
      _pingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _sendPing());
      _sendPing();
      return true;
    } on TimeoutException {
      _set(ConnectionStatus.error, error: 'Timed out — is the server running?');
    } on SocketException catch (e) {
      _set(ConnectionStatus.error, error: e.osError?.message ?? e.message);
    } catch (e) {
      _set(ConnectionStatus.error, error: e.toString());
    }
    return false;
  }

  void _onLine(String line) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final id = msg['id'];
    if (id is int && _pending.containsKey(id)) {
      _pending.remove(id)!.complete(msg);
      return;
    }
    if (msg['t'] == 'pong' && _pingSentAt != null) {
      latencyMs.value = DateTime.now().difference(_pingSentAt!).inMilliseconds;
      _pingSentAt = null;
    }
  }

  void _sendPing() {
    if (_pingSentAt != null) return; // one in flight
    _pingSentAt = DateTime.now();
    _send({'t': 'ping'});
  }

  void _onLost(String reason) {
    _closeSocket();
    if (_status == ConnectionStatus.connected) {
      _set(ConnectionStatus.error, error: reason);
    }
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _sub?.cancel();
    _sub = null;
    _closeSocket();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(StateError('disconnected'));
    }
    _pending.clear();
    latencyMs.value = -1;
    if (_status != ConnectionStatus.disconnected) _set(ConnectionStatus.disconnected);
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

  /// Sends a message and waits for the reply carrying the same id.
  Future<Map<String, dynamic>> request(Map<String, Object?> msg,
      {Duration timeout = const Duration(seconds: 10)}) {
    if (!isConnected) return Future.error(StateError('Not connected'));
    final id = _nextId++;
    final c = Completer<Map<String, dynamic>>();
    _pending[id] = c;
    _send({...msg, 'id': id});
    return c.future.timeout(timeout, onTimeout: () {
      _pending.remove(id);
      throw TimeoutException('No reply from PC');
    });
  }

  // ---- Mouse / keyboard ---------------------------------------------------

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

  /// Click at a fractional position (0..1) on a monitor.
  void clickAt(double fx, double fy, {int monitor = 1, String button = 'left'}) =>
      _send({'t': 'click_at', 'x': fx, 'y': fy, 'mon': monitor, 'b': button});

  // ---- Apps & system ---------------------------------------------------

  Future<List<PcApp>> listApps() async {
    final r = await request({'t': 'apps'});
    final list = (r['apps'] as List?) ?? const [];
    return list
        .map((e) => PcApp(name: e['name'] as String, path: e['path'] as String))
        .toList();
  }

  void launch(String path) => _send({'t': 'launch', 'path': path});

  void system(String action) => _send({'t': 'system', 'action': action});

  // ---- Clipboard ---------------------------------------------------------

  Future<String> getClipboard() async {
    final r = await request({'t': 'clip_get'});
    return (r['s'] as String?) ?? '';
  }

  void setClipboard(String text) => _send({'t': 'clip_set', 's': text});

  // ---- Files -------------------------------------------------------------

  /// Streams a file to the PC in base64 chunks. [onProgress] gets 0..1.
  Future<String> sendFile(String path, String name,
      {void Function(double)? onProgress}) async {
    final f = File(path);
    final size = await f.length();
    final begin = await request({'t': 'file_begin', 'name': name, 'size': size});
    if (begin['t'] != 'ok') throw Exception(begin['msg'] ?? 'PC refused the file');
    final token = begin['token'] as String;

    var sent = 0;
    const chunk = 48 * 1024; // multiple of 3 so base64 chunks concatenate cleanly
    final stream = f.openRead();
    final buffer = BytesBuilder(copy: false);
    await for (final part in stream) {
      buffer.add(part);
      while (buffer.length >= chunk) {
        final bytes = buffer.takeBytes();
        final head = bytes.sublist(0, chunk);
        final rest = bytes.sublist(chunk);
        _send({'t': 'file_chunk', 'token': token, 'd': base64Encode(head)});
        buffer.add(rest);
        sent += head.length;
        onProgress?.call(sent / size);
        // Yield so the socket can drain; avoids buffering the whole file.
        await _socket?.flush();
      }
    }
    if (buffer.length > 0) {
      final bytes = buffer.takeBytes();
      _send({'t': 'file_chunk', 'token': token, 'd': base64Encode(bytes)});
      sent += bytes.length;
      onProgress?.call(sent / size);
    }
    final end = await request({'t': 'file_end', 'token': token}, timeout: const Duration(seconds: 30));
    if (end['t'] != 'ok') throw Exception(end['msg'] ?? 'Transfer failed');
    return (end['path'] as String?) ?? name;
  }

  @override
  void dispose() {
    disconnect();
    latencyMs.dispose();
    super.dispose();
  }
}

class PcApp {
  final String name;
  final String path;
  const PcApp({required this.name, required this.path});
}
