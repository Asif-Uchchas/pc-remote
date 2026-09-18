import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../remote_client.dart';
import '../settings.dart';
import '../theme.dart';
import 'touchpad.dart';
import 'voice_button.dart';
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
  String? _dictating; // partial speech text being previewed

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
            MediaPanel(client: client),
          ],
          if (widget.keyboard) ...[
            if (_dictating != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.graphic_eq, size: 14, color: T.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_dictating!.isEmpty ? 'Listening…' : _dictating!,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: T.text3, fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TypingField(client: client, onText: _typed, onEnter: () => _sendKey('enter', const []))),
                const SizedBox(width: 8),
                VoiceButton(
                  onText: (t) => client.typeText(t),
                  onPartial: (p) => setState(() => _dictating = p),
                ),
              ],
            ),
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

/// Media keys, live volume slider and now-playing line.
class MediaPanel extends StatefulWidget {
  final RemoteClient client;
  const MediaPanel({super.key, required this.client});

  @override
  State<MediaPanel> createState() => _MediaPanelState();
}

class _MediaPanelState extends State<MediaPanel> {
  Timer? _poll;
  Timer? _debounce;
  double? _vol; // 0..100
  bool _muted = false;
  bool _dragging = false;
  Map<String, dynamic>? _media;

  bool get _hasVolume => widget.client.serverSupports('volume');
  bool get _hasNowPlaying => widget.client.serverSupports('now_playing');

  @override
  void initState() {
    super.initState();
    if (_hasVolume || _hasNowPlaying) {
      _refresh();
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    if (!widget.client.isConnected) return;
    try {
      final r = await widget.client.request({'t': 'media_info'}, timeout: const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _media = r['media'] as Map<String, dynamic>?;
        if (!_dragging && r['vol'] != null) _vol = (r['vol'] as num).toDouble();
        if (r['muted'] != null) _muted = r['muted'] == true;
      });
    } catch (_) {}
  }

  void _setVolume(double v) {
    setState(() => _vol = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 60), () => widget.client.send({'t': 'volume_set', 'v': v.round()}));
  }

  void _key(String k) {
    HapticFeedback.selectionClick();
    widget.client.key(k);
    Future<void>.delayed(const Duration(milliseconds: 400), _refresh);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  Widget _btn(IconData icon, VoidCallback onTap, {bool hot = false}) => Expanded(
        child: Material(
          color: hot ? T.accent : T.surface2,
          borderRadius: T.r10,
          child: InkWell(
            borderRadius: T.r10,
            onTap: onTap,
            child: SizedBox(height: 44, child: Icon(icon, size: 20, color: hot ? T.bg : T.text2)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final m = _media;
    final playing = m?['playing'] == true;
    final title = (m?['title'] as String?) ?? '';
    final artist = (m?['artist'] as String?) ?? '';
    final vol = _vol;
    return Column(
      children: [
        if (_hasNowPlaying)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2, right: 2),
            child: Row(
              children: [
                Icon(playing ? Icons.graphic_eq : Icons.music_note_outlined, size: 14, color: m == null ? T.dim : T.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m == null ? 'Nothing playing' : (artist.isEmpty ? title : '$title — $artist'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: m == null ? T.dim : T.text2),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            _btn(Icons.skip_previous_rounded, () => _key('prev')),
            const SizedBox(width: 6),
            _btn(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, () => _key('play_pause'), hot: true),
            const SizedBox(width: 6),
            _btn(Icons.skip_next_rounded, () => _key('next')),
            const SizedBox(width: 6),
            if (_hasVolume && vol != null)
              Expanded(
                flex: 4,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: T.surface2, borderRadius: T.r10),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _muted = !_muted);
                          widget.client.send({'t': 'mute_set', 'm': _muted});
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            _muted
                                ? Icons.volume_off_rounded
                                : (vol < 1 ? Icons.volume_mute_rounded : vol < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                            size: 20,
                            color: _muted ? T.danger : T.text2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: const SliderThemeData(
                            trackHeight: 3,
                            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
                            overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                          ),
                          child: Slider(
                            value: vol.clamp(0, 100),
                            min: 0,
                            max: 100,
                            onChangeStart: (_) => _dragging = true,
                            onChanged: _setVolume,
                            onChangeEnd: (v) {
                              _dragging = false;
                              widget.client.send({'t': 'volume_set', 'v': v.round()});
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text('${vol.round()}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontFamily: T.mono, fontSize: 11, color: T.muted)),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              )
            else ...[
              _btn(Icons.volume_off_rounded, () => _key('mute')),
              const SizedBox(width: 6),
              _btn(Icons.volume_down_rounded, () => _key('vol_down')),
              const SizedBox(width: 6),
              _btn(Icons.volume_up_rounded, () => _key('vol_up')),
            ],
          ],
        ),
      ],
    );
  }
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
