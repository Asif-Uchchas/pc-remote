import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../theme.dart';

/// Mic button: tap to dictate, text is delivered through [onText] when a
/// phrase is final. Partial text is previewed via [onPartial].
class VoiceButton extends StatefulWidget {
  final ValueChanged<String> onText;
  final ValueChanged<String?>? onPartial;
  const VoiceButton({super.key, required this.onText, this.onPartial});

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton> {
  final _stt = SpeechToText();
  bool _ready = false;
  bool _listening = false;

  Future<bool> _init() async {
    if (_ready) return true;
    _ready = await _stt.initialize(
      onStatus: (s) {
        if (s == 'notListening' || s == 'done') {
          if (mounted) setState(() => _listening = false);
          widget.onPartial?.call(null);
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _listening = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Voice: ${e.errorMsg}')));
        }
        widget.onPartial?.call(null);
      },
    );
    return _ready;
  }

  Future<void> _toggle() async {
    if (_listening) {
      await _stt.stop();
      setState(() => _listening = false);
      widget.onPartial?.call(null);
      return;
    }
    if (!await _init()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition is not available (check mic permission / Google app)')));
      }
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _listening = true);
    await _stt.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(minutes: 2),
      ),
    );
  }

  void _onResult(SpeechRecognitionResult r) {
    final words = r.recognizedWords;
    if (r.finalResult) {
        widget.onPartial?.call(null);
      if (words.trim().isNotEmpty) widget.onText('${words.trim()} ');
      // Keep the session going for the next phrase in dictation mode.
      if (mounted && _listening) {
        Future<void>.delayed(const Duration(milliseconds: 150), () {
          if (mounted && _listening && !_stt.isListening) _restart();
        });
      }
    } else {
      widget.onPartial?.call(words);
    }
  }

  Future<void> _restart() async {
    await _stt.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(minutes: 2),
      ),
    );
  }

  @override
  void dispose() {
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Tooltip(
        message: _listening ? 'Stop dictation' : 'Dictate (speech to PC)',
        child: Material(
          color: _listening ? T.danger : T.surface2,
          borderRadius: T.r12,
          child: InkWell(
            borderRadius: T.r12,
            onTap: _toggle,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(borderRadius: T.r12, border: Border.all(color: _listening ? T.danger : T.line2)),
              child: Icon(_listening ? Icons.mic : Icons.mic_none, size: 22, color: _listening ? T.bg : T.text2),
            ),
          ),
        ),
      );
}
