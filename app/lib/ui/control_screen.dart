import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../remote_client.dart';
import 'touchpad.dart';

class ControlScreen extends StatefulWidget {
  final RemoteClient client;
  const ControlScreen({super.key, required this.client});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  bool _showKeyboard = false;
  bool _showMedia = true;
  double _sensitivity = 2.5;
  double _scrollSensitivity = 1.0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _sensitivity = p.getDouble('sensitivity') ?? 2.5;
        _scrollSensitivity = p.getDouble('scrollSensitivity') ?? 1.0;
        _showMedia = p.getBool('showMedia') ?? true;
      });
    });
  }

  Future<void> _saveSettings() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('sensitivity', _sensitivity);
    await p.setDouble('scrollSensitivity', _scrollSensitivity);
    await p.setBool('showMedia', _showMedia);
  }

  void _key(String k, [List<String> mods = const []]) {
    widget.client.key(k, mods);
    HapticFeedback.selectionClick();
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('Pointer speed  ${_sensitivity.toStringAsFixed(1)}×'),
              Slider(
                value: _sensitivity,
                min: 0.5,
                max: 10,
                divisions: 38,
                onChanged: (v) {
                  setSheet(() {});
                  setState(() => _sensitivity = v);
                },
                onChangeEnd: (_) => _saveSettings(),
              ),
              Text('Scroll speed  ${_scrollSensitivity.toStringAsFixed(1)}×'),
              Slider(
                value: _scrollSensitivity,
                min: 0.3,
                max: 3,
                divisions: 27,
                onChanged: (v) {
                  setSheet(() {});
                  setState(() => _scrollSensitivity = v);
                },
                onChangeEnd: (_) => _saveSettings(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show media keys'),
                value: _showMedia,
                onChanged: (v) {
                  setSheet(() {});
                  setState(() => _showMedia = v);
                  _saveSettings();
                },
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.circle, size: 10, color: Colors.greenAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(client.pcName, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Keyboard',
            isSelected: _showKeyboard,
            onPressed: () => setState(() => _showKeyboard = !_showKeyboard),
            icon: const Icon(Icons.keyboard_outlined),
            selectedIcon: const Icon(Icons.keyboard),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: 'Disconnect',
            onPressed: client.disconnect,
            icon: const Icon(Icons.link_off),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            children: [
              Expanded(
                child: Touchpad(
                  client: client,
                  sensitivity: _sensitivity,
                  scrollSensitivity: _scrollSensitivity,
                ),
              ),
              const SizedBox(height: 8),
              _MouseButtons(client: client),
              const SizedBox(height: 8),
              _KeyRow(onKey: _key),
              if (_showMedia) ...[
                const SizedBox(height: 8),
                _MediaRow(onKey: _key),
              ],
              if (_showKeyboard) ...[
                const SizedBox(height: 8),
                _TypingField(client: client),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MouseButtons extends StatelessWidget {
  final RemoteClient client;
  const _MouseButtons({required this.client});

  Widget _btn(String label, String button, {int flex = 3}) => Expanded(
        flex: flex,
        child: _HoldableButton(
          label: label,
          onClick: () => client.click(button: button),
          onHoldStart: () => client.buttonDown(button),
          onHoldEnd: () => client.buttonUp(button),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _btn('Left', 'left'),
          const SizedBox(width: 8),
          _btn('Middle', 'middle', flex: 2),
          const SizedBox(width: 8),
          _btn('Right', 'right'),
        ],
      );
}

class _KeyRow extends StatelessWidget {
  final void Function(String key, [List<String> mods]) onKey;
  const _KeyRow({required this.onKey});

  static const _keys = <(String label, String key, List<String> mods)>[
    ('Esc', 'esc', []),
    ('Tab', 'tab', []),
    ('⌫', 'backspace', []),
    ('Enter', 'enter', []),
    ('←', 'left', []),
    ('↑', 'up', []),
    ('↓', 'down', []),
    ('→', 'right', []),
    ('Del', 'delete', []),
    ('Win', 'win', []),
    ('Alt+Tab', 'tab', ['alt']),
    ('Ctrl+C', 'c', ['ctrl']),
    ('Ctrl+V', 'v', ['ctrl']),
    ('Ctrl+Z', 'z', ['ctrl']),
    ('Ctrl+A', 'a', ['ctrl']),
    ('Ctrl+S', 's', ['ctrl']),
    ('Ctrl+W', 'w', ['ctrl']),
    ('F5', 'f5', []),
    ('F11', 'f11', []),
    ('Space', 'space', []),
    ('PgUp', 'pageup', []),
    ('PgDn', 'pagedown', []),
    ('Home', 'home', []),
    ('End', 'end', []),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _keys.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final (label, key, mods) = _keys[i];
            return OutlinedButton(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14)),
              onPressed: () => onKey(key, mods),
              child: Text(label),
            );
          },
        ),
      );
}

class _MediaRow extends StatelessWidget {
  final void Function(String key, [List<String> mods]) onKey;
  const _MediaRow({required this.onKey});

  Widget _btn(IconData icon, String key, String tip) => Expanded(
        child: IconButton.filledTonal(
          tooltip: tip,
          onPressed: () => onKey(key),
          icon: Icon(icon),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _btn(Icons.skip_previous, 'prev', 'Previous'),
          _btn(Icons.play_arrow, 'play_pause', 'Play / Pause'),
          _btn(Icons.skip_next, 'next', 'Next'),
          const SizedBox(width: 12),
          _btn(Icons.volume_off, 'mute', 'Mute'),
          _btn(Icons.volume_down, 'vol_down', 'Volume down'),
          _btn(Icons.volume_up, 'vol_up', 'Volume up'),
        ],
      );
}

/// A text field whose edits are streamed to the PC as keystrokes.
class _TypingField extends StatefulWidget {
  final RemoteClient client;
  const _TypingField({required this.client});

  @override
  State<_TypingField> createState() => _TypingFieldState();
}

class _TypingFieldState extends State<_TypingField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _last = '';
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _onChanged() {
    if (_muted) return;
    final now = _ctrl.text;
    if (now == _last) return;

    // Length of the unchanged prefix.
    var p = 0;
    final n = now.length < _last.length ? now.length : _last.length;
    while (p < n && now.codeUnitAt(p) == _last.codeUnitAt(p)) {
      p++;
    }
    final removed = _last.length - p;
    final added = now.substring(p);

    for (var i = 0; i < removed; i++) {
      widget.client.key('backspace');
    }
    widget.client.typeText(added);
    _last = now;
  }

  void _clearSilently() {
    _muted = true;
    _ctrl.clear();
    _last = '';
    _muted = false;
  }

  void _submit(String _) {
    widget.client.key('enter');
    _clearSilently();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _ctrl,
        focusNode: _focus,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.send,
        onSubmitted: _submit,
        decoration: InputDecoration(
          hintText: 'Type here — sent to PC live. ⏎ sends Enter',
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: IconButton(
            tooltip: 'Clear (does not delete on PC)',
            icon: const Icon(Icons.clear),
            onPressed: _clearSilently,
          ),
        ),
      );
}

/// Tap = click. Press and hold = mouse button stays down until released,
/// so you can drag with another finger on the touchpad.
class _HoldableButton extends StatefulWidget {
  final String label;
  final VoidCallback onClick;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;
  const _HoldableButton({
    required this.label,
    required this.onClick,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  @override
  State<_HoldableButton> createState() => _HoldableButtonState();
}

class _HoldableButtonState extends State<_HoldableButton> {
  bool _holding = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        widget.onClick();
        HapticFeedback.lightImpact();
      },
      onLongPressStart: (_) {
        setState(() => _holding = true);
        widget.onHoldStart();
        HapticFeedback.mediumImpact();
      },
      onLongPressEnd: (_) {
        setState(() => _holding = false);
        widget.onHoldEnd();
      },
      onLongPressCancel: () {
        if (_holding) {
          setState(() => _holding = false);
          widget.onHoldEnd();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _holding ? scheme.primary : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          _holding ? '${widget.label} (held)' : widget.label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _holding ? scheme.onPrimary : scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
