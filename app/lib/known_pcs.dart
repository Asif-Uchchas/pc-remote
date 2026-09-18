import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// A PC we have connected to before; kept so it can be woken and reconnected
/// even when discovery does not see it.
class KnownPc {
  final String name;
  final String host;
  final int port;
  final String? mac;
  final DateTime lastUsed;

  const KnownPc({required this.name, required this.host, required this.port, this.mac, required this.lastUsed});

  Map<String, Object?> toJson() =>
      {'name': name, 'host': host, 'port': port, 'mac': mac, 'lastUsed': lastUsed.toIso8601String()};

  static KnownPc fromJson(Map<String, dynamic> j) => KnownPc(
        name: j['name'] as String,
        host: j['host'] as String,
        port: (j['port'] as num?)?.toInt() ?? 48889,
        mac: j['mac'] as String?,
        lastUsed: DateTime.tryParse(j['lastUsed'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class KnownPcs {
  static const _key = 'knownPcs';

  static Future<List<KnownPc>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return const [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(KnownPc.fromJson).toList();
      list.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
      return list;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> remember(KnownPc pc) async {
    final list = (await load()).where((k) => k.host != pc.host).toList()..insert(0, pc);
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(list.take(8).map((k) => k.toJson()).toList()));
  }

  static Future<void> forget(String host) async {
    final list = (await load()).where((k) => k.host != host).toList();
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(list.map((k) => k.toJson()).toList()));
  }
}

/// Sends a Wake-on-LAN magic packet for [mac] to the broadcast address(es).
Future<void> wakeOnLan(String mac, {String? host}) async {
  final clean = mac.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (clean.length != 12) throw ArgumentError('Bad MAC address: $mac');
  final macBytes = [for (var i = 0; i < 12; i += 2) int.parse(clean.substring(i, i + 2), radix: 16)];
  final packet = [...List.filled(6, 0xFF), for (var i = 0; i < 16; i++) ...macBytes];

  final targets = <InternetAddress>{InternetAddress('255.255.255.255')};
  try {
    for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final a in iface.addresses) {
        final b = a.rawAddress;
        if (b.length == 4 && b[0] != 127) targets.add(InternetAddress('${b[0]}.${b[1]}.${b[2]}.255'));
      }
    }
  } catch (_) {}
  if (host != null) {
    final b = host.split('.');
    if (b.length == 4) targets.add(InternetAddress('${b[0]}.${b[1]}.${b[2]}.255'));
  }

  final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  sock.broadcastEnabled = true;
  try {
    for (var i = 0; i < 3; i++) {
      for (final t in targets) {
        sock.send(packet, t, 9);
        sock.send(packet, t, 7);
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  } finally {
    sock.close();
  }
}
