import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../remote_client.dart';
import '../settings.dart';
import '../theme.dart';
import 'apps_screen.dart';
import 'pad_screen.dart';
import 'screen_screen.dart';
import 'share_screen.dart';
import 'widgets.dart';

enum Tab { pad, keys, apps, screen, share }

/// Connected-state shell: header, tab body, bottom navigation.
class HomeShell extends StatefulWidget {
  final RemoteClient client;
  final Settings settings;
  const HomeShell({super.key, required this.client, required this.settings});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  Tab _tab = Tab.pad;

  void _openSettings() {
    final s = widget.settings;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListenableBuilder(
        listenable: s,
        builder: (ctx, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              _SliderRow(
                label: 'Pointer speed',
                value: s.sensitivity,
                min: 0.5,
                max: 10,
                divisions: 38,
                onChanged: (v) => s.update((s) => s.sensitivity = v),
              ),
              _SliderRow(
                label: 'Scroll speed',
                value: s.scrollSensitivity,
                min: 0.3,
                max: 3,
                divisions: 27,
                onChanged: (v) => s.update((s) => s.scrollSensitivity = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Media keys on the pad', style: TextStyle(fontSize: 14)),
                value: s.showMedia,
                onChanged: (v) => s.update((s) => s.showMedia = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vibration feedback', style: TextStyle(fontSize: 14)),
                value: s.haptics,
                onChanged: (v) => s.update((s) => s.haptics = v),
              ),
              const SizedBox(height: 8),
              ConsoleButton(
                danger: true,
                onTap: () {
                  Navigator.pop(ctx);
                  widget.client.disconnect();
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Icon(Icons.link_off), SizedBox(width: 8), Text('DISCONNECT')],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final body = switch (_tab) {
      Tab.pad => PadScreen(client: client, settings: widget.settings, keyboard: false),
      Tab.keys => PadScreen(client: client, settings: widget.settings, keyboard: true),
      Tab.apps => AppsScreen(client: client, settings: widget.settings),
      Tab.screen => ScreenScreen(client: client, settings: widget.settings),
      Tab.share => ShareScreen(client: client),
    };
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Column(
            children: [
              _Header(client: client, onSettings: _openSettings),
              const SizedBox(height: 12),
              _StatusBanner(client: client),
              Expanded(child: body),
              const SizedBox(height: 6),
              _BottomNav(tab: _tab, onChanged: (t) {
                HapticFeedback.selectionClick();
                setState(() => _tab = t);
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows when the PC is locked or the link is being re-established.
class _StatusBanner extends StatelessWidget {
  final RemoteClient client;
  const _StatusBanner({required this.client});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([client, client.pcLocked]),
        builder: (context, _) {
          final reconnecting = client.status == ConnectionStatus.reconnecting;
          final locked = client.pcLocked.value;
          if (!reconnecting && !locked) return const SizedBox.shrink();
          final color = reconnecting ? T.danger : const Color(0xFFFFD166);
          final text = reconnecting
              ? 'Connection lost — reconnecting…'
              : '${client.pcName} is locked. Its OS blocks remote input on the lock screen; unlock it at the PC.';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: T.r12,
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  if (reconnecting)
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: color))
                  else
                    Icon(Icons.lock_outline, size: 16, color: color),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color, height: 1.3))),
                  if (reconnecting)
                    GestureDetector(
                      onTap: client.cancelReconnect,
                      child: const Text('GIVE UP', style: TextStyle(fontFamily: T.mono, fontSize: 10, color: T.text2, letterSpacing: 1)),
                    ),
                ],
              ),
            ),
          );
        },
      );
}

class _Header extends StatelessWidget {
  final RemoteClient client;
  final VoidCallback onSettings;
  const _Header({required this.client, required this.onSettings});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          StatusDot(color: client.isConnected ? T.accent : T.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.pcName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2)),
                ValueListenableBuilder<int>(
                  valueListenable: client.latencyMs,
                  builder: (_, ms, _) => Text(
                    '${client.host} · ${ms < 0 ? '…' : '$ms ms'}',
                    style: T.monoSmall,
                  ),
                ),
              ],
            ),
          ),
          IconSquare(Icons.tune, onTap: onSettings, tooltip: 'Settings'),
        ],
      );
}

class _BottomNav extends StatelessWidget {
  final Tab tab;
  final ValueChanged<Tab> onChanged;
  const _BottomNav({required this.tab, required this.onChanged});

  static const _items = [
    (Tab.pad, Icons.near_me_outlined, 'PAD'),
    (Tab.keys, Icons.keyboard_outlined, 'KEYS'),
    (Tab.apps, Icons.grid_view_outlined, 'APPS'),
    (Tab.screen, Icons.desktop_windows_outlined, 'SCREEN'),
    (Tab.share, Icons.ios_share_outlined, 'SHARE'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(top: 6),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: T.line))),
        child: Row(
          children: [
            for (final (t, icon, label) in _items)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(t),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 22, color: t == tab ? T.accent : T.muted),
                        const SizedBox(height: 4),
                        Text(label,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                                color: t == tab ? T.accent : T.muted)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              const Spacer(),
              Text('${value.toStringAsFixed(1)}×', style: const TextStyle(fontFamily: T.mono, fontSize: 12, color: T.accent)),
            ],
          ),
          Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
        ],
      );
}
