import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../remote_client.dart';
import '../theme.dart';
import 'widgets.dart';

/// Clipboard sync and file transfer tab.
class ShareScreen extends StatefulWidget {
  final RemoteClient client;
  const ShareScreen({super.key, required this.client});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _Transfer {
  final String name;
  final int size;
  double progress = 0;
  String? error;
  String? savedPath;
  final DateTime at = DateTime.now();
  _Transfer(this.name, this.size);
  bool get done => savedPath != null;
}

class _ShareScreenState extends State<ShareScreen> {
  String _pcClip = '';
  bool _pcClipLoading = false;
  String _phoneClip = '';
  final List<_Transfer> _transfers = [];
  final _typed = TextEditingController();

  bool get _clipSupported => widget.client.serverSupports('clipboard');

  @override
  void initState() {
    super.initState();
    _refreshPc();
    _refreshPhone();
  }

  Future<void> _refreshPc() async {
    if (!_clipSupported) return;
    setState(() => _pcClipLoading = true);
    try {
      final s = await widget.client.getClipboard();
      if (mounted) setState(() => _pcClip = s);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not read PC clipboard: $e');
    } finally {
      if (mounted) setState(() => _pcClipLoading = false);
    }
  }

  Future<void> _refreshPhone() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (mounted) setState(() => _phoneClip = d?.text ?? '');
  }

  Future<void> _copyToPhone() async {
    await Clipboard.setData(ClipboardData(text: _pcClip));
    HapticFeedback.lightImpact();
    if (mounted) {
      showSnack(context, 'Copied to phone clipboard');
      _refreshPhone();
    }
  }

  void _pasteOnPc(String text) {
    if (text.isEmpty) return;
    widget.client.setClipboard(text);
    HapticFeedback.lightImpact();
    showSnack(context, 'Sent to PC clipboard — press Ctrl+V there');
    Future.delayed(const Duration(milliseconds: 300), _refreshPc);
  }

  void _typeOnPc(String text) {
    if (text.isEmpty) return;
    widget.client.typeText(text);
    HapticFeedback.lightImpact();
    showSnack(context, 'Typing on PC…');
  }

  Future<void> _pickAndSend({required bool photos}) async {
    final files = await FilePicker.pickFiles(type: photos ? FileType.image : FileType.any);
    for (final f in files) {
      final size = await f.length() ?? 0;
      final t = _Transfer(f.name, size);
      if (!mounted) return;
      setState(() => _transfers.insert(0, t));
      try {
        final saved = await widget.client.sendFile(name: f.name, size: size, data: f.readAsByteStream(), onProgress: (p) {
          if (mounted) setState(() => t.progress = p);
        });
        if (mounted) setState(() => t.savedPath = saved);
      } catch (e) {
        if (mounted) setState(() => t.error = e.toString());
      }
    }
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.zero,
        children: [
          SectionLabel(
            'PC clipboard',
            trailing: GestureDetector(
              onTap: _refreshPc,
              child: _pcClipLoading
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: T.accent))
                  : const Icon(Icons.refresh, size: 16, color: T.accent),
            ),
          ),
          const SizedBox(height: 8),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_clipSupported)
                  const Text('Server needs the pyperclip package for clipboard sync.', style: TextStyle(color: T.muted, fontSize: 13))
                else
                  Text(
                    _pcClip.isEmpty ? 'PC clipboard is empty' : _pcClip,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, height: 1.5, color: _pcClip.isEmpty ? T.dim : T.text),
                  ),
                const SizedBox(height: 10),
                ConsoleButton(
                  height: 44,
                  onTap: _pcClip.isEmpty ? null : _copyToPhone,
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.copy_outlined, size: 16), SizedBox(width: 8), Text('COPY TO PHONE')]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionLabel(
            'Phone clipboard',
            trailing: GestureDetector(onTap: _refreshPhone, child: const Icon(Icons.refresh, size: 16, color: T.accent)),
          ),
          const SizedBox(height: 8),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _phoneClip.isEmpty ? 'Nothing copied on the phone' : _phoneClip,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, height: 1.5, color: _phoneClip.isEmpty ? T.dim : T.text2, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ConsoleButton(
                        primary: true,
                        height: 44,
                        onTap: _phoneClip.isEmpty || !_clipSupported ? null : () => _pasteOnPc(_phoneClip),
                        background: _phoneClip.isEmpty || !_clipSupported ? T.surface2 : null,
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.content_paste, size: 16), SizedBox(width: 8), Text('TO PC CLIPBOARD')]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ConsoleButton(
                        height: 44,
                        onTap: _phoneClip.isEmpty ? null : () => _typeOnPc(_phoneClip),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.keyboard_outlined, size: 16), SizedBox(width: 8), Text('TYPE IT OUT')]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SectionLabel('Send text'),
          const SizedBox(height: 8),
          TextField(
            controller: _typed,
            minLines: 1,
            maxLines: 4,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Paste a link or note here…',
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, size: 18, color: T.accent),
                onPressed: () {
                  final t = _typed.text.trim();
                  if (t.isEmpty) return;
                  if (_clipSupported) {
                    _pasteOnPc(t);
                  } else {
                    _typeOnPc(t);
                  }
                  _typed.clear();
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SectionLabel('Send to PC'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ConsoleButton(
                  onTap: () => _pickAndSend(photos: true),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image_outlined), SizedBox(width: 8), Text('PHOTOS')]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ConsoleButton(
                  onTap: () => _pickAndSend(photos: false),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.insert_drive_file_outlined), SizedBox(width: 8), Text('FILES')]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Saved to Downloads \\ Mobile Remote on the PC', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: T.dim)),
          if (_transfers.isNotEmpty) ...[
            const SizedBox(height: 12),
            const SectionLabel('Recent'),
            const SizedBox(height: 8),
            for (final t in _transfers) ...[
              _TransferRow(t),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 8),
        ],
      );
}

class _TransferRow extends StatelessWidget {
  final _Transfer t;
  const _TransferRow(this.t);

  String _size(int b) => b < 1024 * 1024 ? '${(b / 1024).toStringAsFixed(0)} KB' : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    final isImage = RegExp(r'\.(png|jpe?g|gif|webp|heic|bmp)$', caseSensitive: false).hasMatch(t.name);
    final hh = t.at.hour.toString().padLeft(2, '0');
    final mm = t.at.minute.toString().padLeft(2, '0');
    final status = t.error != null
        ? 'failed · ${t.error}'
        : t.done
            ? '${_size(t.size)} · $hh:$mm'
            : '${_size(t.size)} · sending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: T.surface2, borderRadius: T.r12, border: Border.all(color: T.line2)),
      child: Row(
        children: [
          Icon(isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined, size: 20, color: T.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(status, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: T.mono, fontSize: 10, color: t.error != null ? T.danger : T.muted)),
                if (!t.done && t.error == null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(value: t.progress, minHeight: 3, backgroundColor: T.line, color: T.accent),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (t.done)
            const Icon(Icons.check, size: 16, color: T.ok)
          else if (t.error == null)
            Text('${(t.progress * 100).round()}%', style: const TextStyle(fontFamily: T.mono, fontSize: 10, color: T.accent)),
        ],
      ),
    );
  }
}
