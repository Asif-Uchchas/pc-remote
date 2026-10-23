import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'remote_client.dart';

/// Something shared into the app from another Android app.
class SharedItem {
  final String label;
  final String? text; // text / URL shares
  final String? path; // file shares (already copied to app cache by the plugin)
  double progress = 0;
  String status = 'queued'; // queued | sending | done | failed
  String? error;
  SharedItem.text(this.text)
      : path = null,
        label = (text ?? '').length > 60 ? '${text!.substring(0, 60)}…' : (text ?? '');
  SharedItem.file(this.path)
      : text = null,
        label = path!.split(Platform.pathSeparator).last;
  bool get isFile => path != null;
}

/// Receives share-sheet intents and forwards them to the PC once connected.
class ShareIntake extends ChangeNotifier {
  final RemoteClient client;
  final List<SharedItem> items = [];
  StreamSubscription<List<SharedMediaFile>>? _sub;
  bool _busy = false;

  /// Called when items arrive while not connected; the app should connect.
  VoidCallback? onNeedConnection;

  ShareIntake(this.client) {
    client.addListener(_maybeProcess);
    final intent = ReceiveSharingIntent.instance;
    intent.getInitialMedia().then((list) {
      _accept(list);
      intent.reset();
    });
    _sub = intent.getMediaStream().listen(_accept, onError: (_) {});
  }

  bool get hasPending => items.any((i) => i.status == 'queued' || i.status == 'sending');

  void _accept(List<SharedMediaFile> list) {
    if (list.isEmpty) return;
    for (final f in list) {
      switch (f.type) {
        case SharedMediaType.text:
        case SharedMediaType.url:
          final t = f.path.trim();
          if (t.isNotEmpty) items.add(SharedItem.text(t));
        case SharedMediaType.image:
        case SharedMediaType.video:
        case SharedMediaType.file:
          items.add(SharedItem.file(f.path));
      }
    }
    notifyListeners();
    if (client.isConnected) {
      _maybeProcess();
    } else {
      onNeedConnection?.call();
    }
  }

  Future<void> _maybeProcess() async {
    if (_busy || !client.isConnected) return;
    final queued = items.where((i) => i.status == 'queued').toList();
    if (queued.isEmpty) return;
    _busy = true;
    try {
      for (final item in queued) {
        item.status = 'sending';
        notifyListeners();
        try {
          if (item.isFile) {
            final file = File(item.path!);
            final size = await file.length();
            await client.sendFile(
              name: item.label,
              size: size,
              data: file.openRead(),
              onProgress: (p) {
                item.progress = p;
                notifyListeners();
              },
            );
            try {
              await file.delete(); // plugin's cached copy
            } catch (_) {}
          } else if (client.serverSupports('clipboard')) {
            client.setClipboard(item.text!);
          } else {
            client.typeText(item.text!);
          }
          item.status = 'done';
          item.progress = 1;
        } catch (e) {
          item.status = 'failed';
          item.error = e.toString();
        }
        notifyListeners();
      }
    } finally {
      _busy = false;
    }
    // Retry anything that arrived meanwhile.
    if (items.any((i) => i.status == 'queued')) _maybeProcess();
  }

  void dismiss(SharedItem item) {
    items.remove(item);
    notifyListeners();
  }

  void clearFinished() {
    items.removeWhere((i) => i.status == 'done' || i.status == 'failed');
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    client.removeListener(_maybeProcess);
    super.dispose();
  }
}
