import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../discovery.dart';
import '../remote_client.dart';
import '../theme.dart';
import 'widgets.dart';

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
  final _pinFocus = FocusNode();

  List<DiscoveredPc> _found = [];
  String? _selectedHost;
  bool _scanning = false;
  bool _connecting = false;
  bool _manual = false;

  @override
  void initState() {
    super.initState();
    _pin.addListener(() => setState(() {}));
    _loadPrefs().then((_) => _scan());
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _host.text = p.getString('host') ?? '';
    _port.text = p.getString('port') ?? '48889';
    _pin.text = p.getString('pin') ?? '';
    _selectedHost = _host.text.isEmpty ? null : _host.text;
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
      if (list.length == 1 && (_selectedHost == null || !list.any((p) => p.host == _selectedHost))) {
        _select(list.first);
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _select(DiscoveredPc pc) {
    setState(() {
      _selectedHost = pc.host;
      _host.text = pc.host;
      _port.text = pc.port.toString();
      _manual = false;
    });
    if (_pin.text.isEmpty) _pinFocus.requestFocus();
  }

  Future<void> _connect() async {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim()) ?? 48889;
    final pin = _pin.text.trim();
    if (host.isEmpty) return showSnack(context, 'Pick a PC or enter its address');
    if (pin.length < 4) return showSnack(context, 'Enter the 4-digit PIN from the server window');
    setState(() => _connecting = true);
    await _savePrefs();
    final ok = await widget.client.connect(host: host, port: port, pin: pin);
    if (!mounted) return;
    setState(() => _connecting = false);
    if (!ok) showSnack(context, widget.client.errorMessage);
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _pin.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  String get _targetName {
    for (final pc in _found) {
      if (pc.host == _selectedHost) return pc.name;
    }
    return _host.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final pinDigits = _pin.text.trim();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('MOBILE REMOTE',
                  style: TextStyle(fontFamily: T.mono, fontSize: 11, color: T.accent, letterSpacing: 1.6)),
              const SizedBox(height: 6),
              const Text('Pick a PC',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.1)),
              const SizedBox(height: 6),
              const Text(
                'Phone and PC must share a Wi‑Fi network, or connect the PC to this phone\'s hotspot.',
                style: TextStyle(fontSize: 13, color: T.muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              SectionLabel(
                'On your network',
                trailing: GestureDetector(
                  onTap: _scan,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_scanning)
                        const SizedBox(
                            width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: T.accent))
                      else
                        const Icon(Icons.refresh, size: 14, color: T.accent),
                      const SizedBox(width: 6),
                      Text(_scanning ? 'SCANNING' : 'RESCAN',
                          style: const TextStyle(fontFamily: T.mono, fontSize: 10, color: T.accent, letterSpacing: 1.2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    if (_found.isEmpty && !_scanning)
                      Panel(
                        child: const Text(
                          'No PC found yet. Make sure server.py is running on the PC and allowed through the firewall, then rescan — or enter the address manually.',
                          style: TextStyle(fontSize: 13, color: T.muted, height: 1.5),
                        ),
                      ),
                    for (final pc in _found) ...[
                      _PcRow(pc: pc, selected: pc.host == _selectedHost, onTap: () => _select(pc)),
                      const SizedBox(height: 8),
                    ],
                    if (!_manual)
                      GestureDetector(
                        onTap: () => setState(() => _manual = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: T.r12,
                            border: Border.all(color: T.line2, style: BorderStyle.solid),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, size: 16, color: T.muted),
                              SizedBox(width: 10),
                              Text('Enter an address manually', style: TextStyle(fontSize: 13, color: T.muted)),
                            ],
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _host,
                              keyboardType: TextInputType.url,
                              style: const TextStyle(fontFamily: T.mono, fontSize: 14),
                              decoration: const InputDecoration(hintText: '192.168.1.10'),
                              onChanged: (v) => setState(() => _selectedHost = v.trim()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _port,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontFamily: T.mono, fontSize: 14),
                              decoration: const InputDecoration(hintText: 'Port'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SectionLabel('PIN · shown in the server window'),
              const SizedBox(height: 8),
              _PinField(controller: _pin, focusNode: _pinFocus, onDone: _connect),
              const SizedBox(height: 10),
              ConsoleButton(
                primary: true,
                height: 54,
                onTap: _connecting || _selectedHost == null || pinDigits.length < 4 ? null : _connect,
                background: _connecting || _selectedHost == null || pinDigits.length < 4 ? T.surface2 : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_connecting)
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: T.bg))
                    else
                      const Icon(Icons.link, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _connecting
                          ? 'CONNECTING…'
                          : _selectedHost == null
                              ? 'PICK A PC'
                              : 'CONNECT TO ${_targetName.toUpperCase()}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PcRow extends StatelessWidget {
  final DiscoveredPc pc;
  final bool selected;
  final VoidCallback onTap;
  const _PcRow({required this.pc, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: T.surface2,
        borderRadius: T.r12,
        child: InkWell(
          borderRadius: T.r12,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: T.r12,
              border: Border.all(color: selected ? T.accent : T.line2),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: T.surface, borderRadius: T.r10, border: Border.all(color: T.line)),
                  child: const Icon(Icons.desktop_windows_outlined, size: 20, color: T.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pc.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${pc.host}:${pc.port}', style: T.monoSmall),
                    ],
                  ),
                ),
                Icon(selected ? Icons.check_circle : Icons.chevron_right, size: 20,
                    color: selected ? T.accent : T.muted),
              ],
            ),
          ),
        ),
      );
}

/// Four-box PIN entry backed by a single hidden text field.
class _PinField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onDone;
  const _PinField({required this.controller, required this.focusNode, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final digits = controller.text;
    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    height: 56,
                    decoration: BoxDecoration(
                      color: T.surface2,
                      borderRadius: T.r12,
                      border: Border.all(
                          color: i < digits.length || (i == digits.length && focusNode.hasFocus) ? T.accent : T.line2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      i < digits.length ? digits[i] : '·',
                      style: TextStyle(
                          fontFamily: T.mono, fontSize: 22, color: i < digits.length ? T.text : T.dim),
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Invisible field that actually receives input.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                maxLength: 4,
                autocorrect: false,
                enableSuggestions: false,
                showCursor: false,
                decoration: const InputDecoration(counterText: ''),
                onSubmitted: (_) => onDone(),
                onChanged: (v) {
                  if (v.length == 4) FocusScope.of(context).unfocus();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
