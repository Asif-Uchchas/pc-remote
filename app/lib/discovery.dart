import 'dart:async';
import 'dart:convert';
import 'dart:io';

const int discoveryPort = 48888;
const String _discoverMsg = 'PCREMOTE_DISCOVER_V1';
const String _replyPrefix = 'PCREMOTE_HERE_V1|';

class DiscoveredPc {
  final String name;
  final String host;
  final int port;
  const DiscoveredPc({required this.name, required this.host, required this.port});

  @override
  bool operator ==(Object other) =>
      other is DiscoveredPc && other.host == host && other.port == port;
  @override
  int get hashCode => Object.hash(host, port);
}

/// Broadcasts a discovery packet on every IPv4 interface and collects replies
/// for [timeout].
Future<List<DiscoveredPc>> discoverPcs(
    {Duration timeout = const Duration(seconds: 2)}) async {
  final found = <DiscoveredPc>{};
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  socket.broadcastEnabled = true;

  final completer = Completer<void>();
  socket.listen((event) {
    if (event != RawSocketEvent.read) return;
    final dg = socket.receive();
    if (dg == null) return;
    final text = utf8.decode(dg.data, allowMalformed: true).trim();
    if (!text.startsWith(_replyPrefix)) return;
    final parts = text.split('|');
    if (parts.length < 3) return;
    found.add(DiscoveredPc(
      name: parts[1],
      host: dg.address.address,
      port: int.tryParse(parts[2]) ?? 48889,
    ));
  });

  final payload = utf8.encode(_discoverMsg);
  final targets = <InetTarget>{
    InetTarget(InternetAddress('255.255.255.255')),
  };
  // Also send to each subnet's directed broadcast — some phones/hotspots drop
  // the limited broadcast address.
  try {
    for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final addr in iface.addresses) {
        final b = addr.rawAddress;
        if (b.length == 4 && b[0] != 127) {
          // Assume /24; good enough for home networks and hotspots.
          targets.add(InetTarget(
              InternetAddress('${b[0]}.${b[1]}.${b[2]}.255')));
        }
      }
    }
  } catch (_) {}

  for (var i = 0; i < 3; i++) {
    for (final t in targets) {
      try {
        socket.send(payload, t.address, discoveryPort);
      } catch (_) {}
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Timer(timeout, () {
    if (!completer.isCompleted) completer.complete();
  });
  await completer.future;
  socket.close();
  return found.toList()..sort((a, b) => a.name.compareTo(b.name));
}

class InetTarget {
  final InternetAddress address;
  InetTarget(this.address);
  @override
  bool operator ==(Object other) =>
      other is InetTarget && other.address.address == address.address;
  @override
  int get hashCode => address.address.hashCode;
}
