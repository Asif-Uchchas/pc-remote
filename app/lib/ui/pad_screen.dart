import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../remote_client.dart';
import '../settings.dart';
import '../theme.dart';
import 'touchpad.dart';
import 'widgets.dart';

/// Touchpad tab. With [keyboard] the live typing field is shown (the "Keys" tab).
class PadScreen extends StatefulWidget {
  final RemoteClient client;
  final Settings settings;
  final bool keyboard;
  const PadScreen({super.key, required this.client, required this.settings, required this.keyboard});

  @override
  State<PadScreen> createState() => _PadScreenState();
}

class _PadScreenState extends State<PadScreen> {
  /// Sticky modifiers: applied to the next key chip / typed character.
  final Set<String> _mods = {};

  void _toggleMod(String m) {
    HapticFeedback.selectionClick();
    setState(() => _mods.contains(m) ? _mods.remove(m) : _mods.add(m));
  }

  void _sendKey(String key, List<String> mods) {
    widget.client.key(key, [...mods, ..._mods]);
    if (_mods.isNotEmpty) setState(_mods.clear);
  }

  /// Typed text: with sticky modifiers active, each character becomes a
  /// modifier+key press (e.g. Super + Enter) instead of plain text.
  void _typed(String text) {
    if (_mods.isEmpty) {
      widget.client.typeText(text);
      return;
    }
    for (final ch in text.characters) {
      widget.client.key(ch == '\n' ? 'enter' : ch, _mods.toList());
    }
    setState(_mods.clear);
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    final settings = widget.settings;
    final superLabel = client.pcIsLinux ? 'SUPER' : (client.pcOs == 'macos' ? 'CMD' : 'WIN');
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        children: [
          Expanded(
            child: Touchpad(
              client: client,
              sensitivity: settings.sensitivity,
              scrollSensitivity: settings.scrollSensitivity,
              haptics: settings.haptics,
            ),
          ),
          const SizedBox(height: 10),
          _MouseButtons(client: client),
          const SizedBox(height: 10),
          _ModifierRow(active: _mods, onToggle: _toggleMod, superLabel: superLabel),
          const SizedBox(height: 8),
          _KeyRow(onKey: _sendKey, superLabel: superLabel),
          if (settings.showMedia && !widget.keyboard) ...[
            const SizedBox(height: 10),
            _MediaRow(client: client),
          ],
          if (widget.keyboard) ...[
            const SizedBox(height: 10),
            TypingField(client: client, onText: _typed, onEnter: () => _sendKey('enter', const [])),
          ],
        ],
      ),
    );
  }
}

/// CTRL / ALT / SHIFT / SUPER toggles that stick until the next key.
class _ModifierRow extends StatelessWidget {
  final Set<String> active;
  final ValueChanged<String> onToggle;
  final String superLabel;
  const _ModifierRow({required this.active, required this.onToggle, required this.superLabel});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final (m, label) in [('ctrl', 'CTRL'), ('alt', 'ALT'), ('shift', 'SHIFT'), ('win', superLabel)]) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => onToggle(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  height: 36,
                  decoration: BoxDecoration(
                    color: active.contains(m) ? T.accent : T.surface3,
                    borderRadius: T.r10,
                    border: Border.all(color: active.contains(m) ? T.accent : T.line2),
                  ),
                  alignment: Alignment.center,
                  child: Text(label,
                      style: TextStyle(fontFamily: T.mono, fontSize: 11, letterSpacing: 1, color: active.contains(m) ? T.bg : T.text3)),
                ),
              ),
            ),
            if (m != 'win') const SizedBox(width: 6),
          ],
        ],
      );
}

class _MouseButtons extends StatelessWidget {
  final RemoteClient client;
  const _MouseButtons({required this.client});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(flex: 3, child: HoldButton(label: 'LEFT', button: 'left', client: client)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: HoldButton(label: 'MID', button: 'middle', client: client, dim: true)),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: HoldButton(label: 'RIGHT', button: 'right', client: client)),
        ],
      );
}

/// Tap = click. Press & hold = mouse button stays down until released,
/// so you can drag with another finger on the touchpad.
class HoldButton extends StatefulWidget {
  final String label;
  final String button;
  final RemoteClient client;
  final bool dim;
  const HoldButton({super.key, required this.label, required this.button, required this.client, this.dim = false});

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> {
  bool _holding = false;

  void _release() {
    if (!_holding) return;
    setState(() => _holding = false);
    widget.client.buttonUp(widget.button);
  }

  @override
  void dispose() {
    if (_holding) widget.client.buttonUp(widget.button);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          widget.client.click(button: widget.button);
          HapticFeedback.lightImpact();
        },
        onLongPressStart: (_) {
          setState(() => _holding = true);
          widget.client.buttonDown(widget.button);
          HapticFeedback.mediumImpact();
        },
        onLongPressEnd: (_) => _release(),
        onLongPressCancel: _release,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 52,
          decoration: BoxDecoration(
            color: _holding ? T.accent : T.surface2,
            borderRadius: T.r12,
            border: Border.all(color: _holding ? T.accent : T.line2),
          ),
          alignment: Alignment.center,
          child: Text(
            _holding ? '${widget.label} · HELD' : widget.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: _holding ? T.bg : (widget.dim ? T.text3 : T.text),
            ),
          ),
        ),
      );
}

class _KeyRow extends StatelessWidget {
  final void Function(String key, List<String> mods) onKey;
  final String superLabel;
  const _KeyRow({required this.onKey, required this.superLabel});

  static const _keys = <(String, String, List<String>)>[
    ('ESC', 'esc', []),
    ('TAB', 'tab', []),
    ('⌫', 'backspace', []),
    ('ENTER', 'enter', []),
    ('←', 'left', []),
    ('↑', 'up', []),
    ('↓', 'down', []),
    ('→', 'right', []),
    ('DEL', 'delete', []),
    ('WIN', 'win', []),
    ('ALT+TAB', 'tab', ['alt']),
    ('CTRL+C', 'c', ['ctrl']),
    ('CTRL+V', 'v', ['ctrl']),
    ('CTRL+Z', 'z', ['ctrl']),
    ('CTRL+A', 'a', ['ctrl']),
    ('CTRL+S', 's', ['ctrl']),
    ('CTRL+W', 'w', ['ctrl']),
    ('F5', 'f5', []),
    ('F11', 'f11', []),
    ('SPACE', 'space', []),
    ('PGUP', 'pageup', []),
    ('PGDN', 'pagedown', []),
    ('HOME', 'home', []),
    ('END', 'end', []),
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
            return KeyChip(label == 'WIN' ? superLabel : label, onTap: () => onKey(key, mods));
          },
        ),
      );
}

class _MediaRow extends StatelessWidget {
  final RemoteClient client;
  const _MediaRow({required this.client});

  Widget _btn(IconData icon, String key, {bool hot = false}) => Expanded(
        child: Material(
          color: hot ? T.accent : T.surface2,
          borderRadius: T.r10,
          child: InkWell(
            borderRadius: T.r10,
            onTap: () {
              HapticFeedback.selectionClick();
              client.key(key);
            },
            child: SizedBox(height: 44, child: Icon(icon, size: 20, color: hot ? T.bg : T.text2)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _btn(Icons.skip_previous_rounded, 'prev'),
          const SizedBox(width: 6),
          _btn(Icons.play_arrow_rounded, 'play_pause', hot: true),
          const SizedBox(width: 6),
          _btn(Icons.skip_next_rounded, 'next'),
          const SizedBox(width: 6),
          _btn(Icons.volume_off_rounded, 'mute'),
          const SizedBox(width: 6),
          _btn(Icons.volume_down_rounded, 'vol_down'),
          const SizedBox(width: 6),
          _btn(Icons.volume_up_rounded, 'vol_up'),
        ],
      );
}

/// A text field whose edits are streamed to the PC as keystrokes.
class TypingField extends StatefulWidget {
  final RemoteClient client;
  final ValueChanged<String>? onText;
  final VoidCallback? onEnter;
  const TypingField({super.key, required this.client, this.onText, this.onEnter});

  @override
  State<TypingField> createState() => _TypingFieldState();
}

class _TypingFieldState extends State<TypingField> {
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
    var p = 0;
    final n = now.length < _last.length ? now.length : _last.length;
    while (p < n && now.codeUnitAt(p) == _last.codeUnitAt(p)) {
      p++;
    }
    final removed = _last.length - p;
    for (var i = 0; i < removed; i++) {
      widget.client.key('backspace');
    }
    final added = now.substring(p);
    if (added.isNotEmpty) (widget.onText ?? widget.client.typeText)(added);
    _last = now;
  }

  void _clearSilently() {
    _muted = true;
    _ctrl.clear();
    _last = '';
    _muted = false;
  }

  void _submit(String _) {
    (widget.onEnter ?? () => widget.client.key('enter'))();
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
        style: const TextStyle(fontFamily: T.mono, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Type here — goes to the PC live. ⏎ = Enter',
          hintStyle: const TextStyle(fontFamily: T.sans, color: T.dim, fontSize: 13),
          suffixIcon: IconButton(
            tooltip: 'Clear field (keeps text on PC)',
            icon: const Icon(Icons.clear, size: 18, color: T.muted),
            onPressed: _clearSilently,
          ),
        ),
      );
}
