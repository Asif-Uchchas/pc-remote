import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../remote_client.dart';
import '../settings.dart';
import '../theme.dart';
import 'widgets.dart';

/// Apps & shortcuts tab: system actions, favourite app tiles, macros.
class AppsScreen extends StatefulWidget {
  final RemoteClient client;
  final Settings settings;
  const AppsScreen({super.key, required this.client, required this.settings});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  List<PcApp>? _apps;
  String? _error;
  List<String> _favourites = []; // app names pinned to the grid, per PC

  String get _favKey => 'fav:${widget.client.pcName}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    _favourites = p.getStringList(_favKey) ?? const [];
    try {
      final apps = await widget.client.listApps();
      if (!mounted) return;
      setState(() {
        _apps = apps;
        if (_favourites.isEmpty) {
          // First visit: seed with a few common ones if the PC has them.
          const wanted = ['Google Chrome', 'Microsoft Edge', 'Firefox', 'Visual Studio Code', 'Spotify',
            'File Explorer', 'Terminal', 'Command Prompt', 'Notepad', 'VLC media player', 'Steam', 'Discord'];
          _favourites = [for (final w in wanted) if (apps.any((a) => a.name == w)) w].take(7).toList();
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _saveFavs() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_favKey, _favourites);
  }

  void _launch(PcApp app) {
    widget.client.launch(app.path);
    HapticFeedback.lightImpact();
    showSnack(context, 'Opening ${app.name}');
  }

  Future<void> _pickApp() async {
    final apps = _apps;
    if (apps == null) return;
    final picked = await showModalBottomSheet<PcApp>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _AppPicker(apps: apps, favourites: _favourites),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (_favourites.contains(picked.name)) {
        _favourites.remove(picked.name);
      } else {
        _favourites.add(picked.name);
      }
    });
    _saveFavs();
  }

  void _removeFav(String name) {
    setState(() => _favourites.remove(name));
    _saveFavs();
  }

  Future<void> _system(String action, String label) async {
    if (action == 'shutdown' || action == 'restart') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('$label ${widget.client.pcName}?'),
          content: const Text('Unsaved work on the PC will be lost.', style: TextStyle(color: T.muted)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: T.muted))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(label, style: const TextStyle(color: T.danger))),
          ],
        ),
      );
      if (ok != true) return;
    }
    widget.client.system(action);
    HapticFeedback.mediumImpact();
  }

  Future<void> _addMacro() async {
    final m = await showDialog<Macro>(context: context, builder: (ctx) => const _MacroDialog());
    if (m == null) return;
    widget.settings.update((s) => s.macros = [...s.macros, m]);
  }

  void _runMacro(Macro m) {
    widget.client.key(m.key, m.mods);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final apps = _apps;
    final favApps = [
      for (final name in _favourites)
        if (apps != null)
          for (final a in apps)
            if (a.name == name) a
    ];
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => ListView(
        padding: EdgeInsets.zero,
        children: [
          const SectionLabel('System'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: ConsoleButton(onTap: () => _system('lock', 'Lock'), child: const _IconLabel(Icons.lock_outline, 'LOCK'))),
              const SizedBox(width: 8),
              Expanded(child: ConsoleButton(onTap: () => _system('sleep', 'Sleep'), child: const _IconLabel(Icons.dark_mode_outlined, 'SLEEP'))),
              const SizedBox(width: 8),
              Expanded(
                child: ConsoleButton(
                  danger: true,
                  onTap: () => _system('shutdown', 'Shut down'),
                  onLongPress: () => _system('restart', 'Restart'),
                  child: const _IconLabel(Icons.power_settings_new, 'POWER'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Power: tap = shut down · hold = restart', style: TextStyle(fontSize: 10, color: T.dim), textAlign: TextAlign.right),
          const SizedBox(height: 8),
          SectionLabel(
            'Launch',
            trailing: apps == null
                ? null
                : GestureDetector(
                    onTap: _pickApp,
                    child: const Text('EDIT', style: TextStyle(fontFamily: T.mono, fontSize: 10, color: T.accent, letterSpacing: 1.2)),
                  ),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Panel(child: Text('Could not list apps: $_error', style: const TextStyle(color: T.muted, fontSize: 13)))
          else if (apps == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: T.accent))),
            )
          else
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.92,
              children: [
                for (final a in favApps)
                  _AppTile(app: a, onTap: () => _launch(a), onLongPress: () => _removeFav(a.name)),
                _AddTile(onTap: _pickApp),
              ],
            ),
          const SizedBox(height: 12),
          SectionLabel(
            'Macros · tap to run',
            trailing: GestureDetector(
              onTap: _addMacro,
              child: const Text('ADD', style: TextStyle(fontFamily: T.mono, fontSize: 10, color: T.accent, letterSpacing: 1.2)),
            ),
          ),
          const SizedBox(height: 8),
          for (final m in widget.settings.macros) ...[
            _MacroRow(
              macro: m,
              onTap: () => _runMacro(m),
              onDelete: () => widget.settings.update((s) => s.macros = [for (final x in s.macros) if (x != m) x]),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _IconLabel(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(icon), const SizedBox(width: 6), Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)))],
      );
}

const _tileColors = [
  Color(0xFF5EE0FF), Color(0xFF7C9CFF), Color(0xFF7DFFB0), Color(0xFFFFD166),
  Color(0xFFFF8FA3), Color(0xFF9EECFF), Color(0xFFC9D1DA), Color(0xFFB8A1FF),
];

Color tileColor(String name) => _tileColors[name.hashCode.abs() % _tileColors.length];

class _AppTile extends StatelessWidget {
  final PcApp app;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _AppTile({required this.app, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) => Material(
        color: T.surface2,
        borderRadius: T.r12,
        child: InkWell(
          borderRadius: T.r12,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(borderRadius: T.r12, border: Border.all(color: T.line2)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: tileColor(app.name), borderRadius: T.r12),
                  alignment: Alignment.center,
                  child: Text(
                    app.name.isEmpty ? '?' : app.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: T.bg),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  app.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: T.text2, height: 1.2),
                ),
              ],
            ),
          ),
        ),
      );
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: T.r12,
        child: InkWell(
          borderRadius: T.r12,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(borderRadius: T.r12, border: Border.all(color: T.line2)),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: T.muted),
                SizedBox(height: 8),
                Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: T.muted)),
              ],
            ),
          ),
        ),
      );
}

class _AppPicker extends StatefulWidget {
  final List<PcApp> apps;
  final List<String> favourites;
  const _AppPicker({required this.apps, required this.favourites});

  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.apps.where((a) => a.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(hintText: 'Search apps on the PC', prefixIcon: Icon(Icons.search, color: T.muted)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(alignment: Alignment.centerLeft, child: Text('Tap to add or remove from the grid', style: TextStyle(fontSize: 11, color: T.dim))),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: list.length,
              itemBuilder: (_, i) {
                final a = list[i];
                final fav = widget.favourites.contains(a.name);
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: tileColor(a.name), borderRadius: T.r10),
                    alignment: Alignment.center,
                    child: Text(a.name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, color: T.bg)),
                  ),
                  title: Text(a.name, style: const TextStyle(fontSize: 14)),
                  trailing: Icon(fav ? Icons.check_circle : Icons.add_circle_outline, color: fav ? T.accent : T.muted, size: 20),
                  onTap: () => Navigator.pop(ctx, a),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final Macro macro;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _MacroRow({required this.macro, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) => Material(
        color: T.surface2,
        borderRadius: T.r12,
        child: InkWell(
          borderRadius: T.r12,
          onTap: onTap,
          onLongPress: () {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Remove "${macro.label}"?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Keep', style: TextStyle(color: T.muted))),
                  TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete();
                      },
                      child: const Text('Remove', style: TextStyle(color: T.danger))),
                ],
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(borderRadius: T.r12, border: Border.all(color: T.line2)),
            child: Row(
              children: [
                Expanded(child: Text(macro.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                Text(macro.pretty, style: T.monoSmall),
              ],
            ),
          ),
        ),
      );
}

class _MacroDialog extends StatefulWidget {
  const _MacroDialog();

  @override
  State<_MacroDialog> createState() => _MacroDialogState();
}

class _MacroDialogState extends State<_MacroDialog> {
  final _label = TextEditingController();
  final _key = TextEditingController();
  final _mods = <String>{};

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('New macro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _label, decoration: const InputDecoration(hintText: 'Name, e.g. "Mute mic"')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final m in ['ctrl', 'shift', 'alt', 'win'])
                  FilterChip(
                    label: Text(m.toUpperCase(), style: const TextStyle(fontFamily: T.mono, fontSize: 11)),
                    selected: _mods.contains(m),
                    selectedColor: T.accent,
                    checkmarkColor: T.bg,
                    labelStyle: TextStyle(color: _mods.contains(m) ? T.bg : T.text2),
                    backgroundColor: T.surface2,
                    side: const BorderSide(color: T.line2),
                    onSelected: (v) => setState(() => v ? _mods.add(m) : _mods.remove(m)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              style: const TextStyle(fontFamily: T.mono),
              decoration: const InputDecoration(hintText: 'Key: a letter, f5, esc, tab, enter, space…'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: T.muted))),
          TextButton(
            onPressed: () {
              final k = _key.text.trim().toLowerCase();
              final l = _label.text.trim();
              if (k.isEmpty || l.isEmpty) return;
              Navigator.pop(context, Macro(l, [..._mods, k].join('+')));
            },
            child: const Text('Add', style: TextStyle(color: T.accent)),
          ),
        ],
      );
}
