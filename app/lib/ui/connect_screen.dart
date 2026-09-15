import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../discovery.dart';
import '../remote_client.dart';

class ConnectScreen extends StatefulWidget {
  final RemoteClient client;
  const ConnectScreen({super.key, required this.client});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '48889');
  final _pin = TextEditingController();

  List<DiscoveredPc> _found = [];
  bool _scanning = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs().then((_) => _scan());
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _host.text = p.getString('host') ?? '';
    _port.text = p.getString('port') ?? '48889';
    _pin.text = p.getString('pin') ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('host', _host.text.trim());
    await p.setString('port', _port.text.trim());
    await p.setString('pin', _pin.text.trim());
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      final list = await discoverPcs();
      if (!mounted) return;
      setState(() => _found = list);
      // Auto-fill if there is exactly one PC and nothing typed yet.
      if (list.length == 1 && _host.text.trim().isEmpty) {
        _host.text = list.first.host;
        _port.text = list.first.port.toString();
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect() async {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim()) ?? 48889;
    final pin = _pin.text.trim();
    if (host.isEmpty) {
      _snack('Enter the PC address or pick one from the list');
      return;
    }
    if (pin.isEmpty) {
      _snack('Enter the PIN shown by the server');
      return;
    }
    setState(() => _connecting = true);
    await _savePrefs();
    final ok = await widget.client.connect(host: host, port: port, pin: pin);
    if (!mounted) return;
    setState(() => _connecting = false);
    if (!ok) _snack(widget.client.errorMessage);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('PC Remote')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Text('PCs on your network',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                _scanning
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        tooltip: 'Scan again',
                        onPressed: _scan,
                        icon: const Icon(Icons.refresh)),
              ],
            ),
            const SizedBox(height: 8),
            if (_found.isEmpty && !_scanning)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No PC found. Make sure server.py is running and the phone '
                  'and PC are on the same Wi-Fi (or the PC is on the phone\'s '
                  'hotspot). You can also type the IP below.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            for (final pc in _found)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.computer),
                  title: Text(pc.name),
                  subtitle: Text('${pc.host}:${pc.port}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    setState(() {
                      _host.text = pc.host;
                      _port.text = pc.port.toString();
                    });
                  },
                ),
              ),
            const SizedBox(height: 20),
            Text('Connection', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _host,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'PC address',
                      hintText: '192.168.1.10',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _port,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'PIN (shown in the server window)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pin_outlined),
              ),
              onSubmitted: (_) => _connect(),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _connecting ? null : _connect,
              icon: _connecting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.link),
              label: Text(_connecting ? 'Connecting…' : 'Connect'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            if (widget.client.status == ConnectionStatus.error) ...[
              const SizedBox(height: 12),
              Text(widget.client.errorMessage,
                  style: TextStyle(color: scheme.error),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
