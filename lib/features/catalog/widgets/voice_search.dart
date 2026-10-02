import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/feedback.dart';

//==============================================================================
// SPOCART — Voice search
//------------------------------------------------------------------------------
// Uses the phone's own speech engine, so nothing is recorded or uploaded and
// there is no per-search cost. The recognised words go into the ordinary search
// — nothing bypasses it.
//
// Every way this can fail is a sentence the buyer can act on: no microphone
// permission, no speech engine on the device, the chosen language not
// installed, or simply nothing heard.
//==============================================================================

/// Locales the sheet offers. The device decides which it actually has.
const List<({String id, String label})> kVoiceLocales = <({String id, String label})>[
  (id: 'en_IN', label: 'English'),
  (id: 'hi_IN', label: 'हिन्दी'),
];

/// Opens the listening sheet and returns what the buyer said, or null if they
/// cancelled or nothing could be recognised.
Future<String?> showVoiceSearchSheet(BuildContext context) {
  // Speech recognition needs a microphone the web build cannot assume.
  if (kIsWeb) {
    showAppSnackBar(
      context,
      'Voice search works in the SPOCART app on your phone.',
      tone: SnackTone.neutral,
    );
    return Future<String?>.value();
  }
  return showAppBottomSheet<String>(
    context,
    title: 'Speak to search',
    builder: (context) => const _VoiceSearchBody(),
  );
}

class _VoiceSearchBody extends StatefulWidget {
  const _VoiceSearchBody();

  @override
  State<_VoiceSearchBody> createState() => _VoiceSearchBodyState();
}

enum _Stage { starting, listening, heard, failed }

class _VoiceSearchBodyState extends State<_VoiceSearchBody> {
  final SpeechToText _speech = SpeechToText();

  _Stage _stage = _Stage.starting;
  String _words = '';
  String _message = '';
  String _locale = kVoiceLocales.first.id;
  bool _available = false;

  /// Stop on our own terms rather than waiting for the engine, so the sheet
  /// cannot sit open listening to a room.
  static const Duration _listenFor = Duration(seconds: 12);
  static const Duration _pauseFor = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    // Never leave the microphone open behind a closed sheet.
    _speech.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _stage = _Stage.starting;
      _words = '';
      _message = '';
    });

    try {
      _available = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
    } catch (_) {
      _available = false;
    }
    if (!mounted) return;

    if (!_available) {
      setState(() {
        _stage = _Stage.failed;
        _message = 'Speech recognition is not available on this phone, or the '
            'microphone permission was refused. You can still type your search.';
      });
      return;
    }

    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          listenMode: ListenMode.search,
          partialResults: true,
          cancelOnError: true,
          listenFor: _listenFor,
          pauseFor: _pauseFor,
        ),
        onResult: _onResult,
      );
      if (mounted) setState(() => _stage = _Stage.listening);
    } catch (_) {
      if (mounted) {
        setState(() {
          _stage = _Stage.failed;
          _message = 'Could not start listening. Please try again, or type your search.';
        });
      }
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _words = result.recognizedWords;
      if (result.finalResult) _stage = _Stage.heard;
    });
    if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
      Navigator.of(context).pop(result.recognizedWords.trim());
    }
  }

  void _onStatus(String status) {
    if (!mounted) return;
    // The engine stopped by itself and we have nothing: say so plainly.
    if (status == 'done' || status == 'notListening') {
      if (_words.trim().isEmpty && _stage == _Stage.listening) {
        setState(() {
          _stage = _Stage.failed;
          _message = 'Nothing was heard. Hold the phone closer and try again.';
        });
      }
    }
  }

  void _onError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _stage = _Stage.failed;
      _message = switch (error.errorMsg) {
        'error_speech_timeout' || 'error_no_match' =>
          'Nothing was heard. Hold the phone closer and try again.',
        'error_permission' =>
          'SPOCART needs the microphone to hear you. Allow it in your phone settings.',
        'error_language_not_supported' || 'error_language_unavailable' =>
          'This phone does not have that language installed for speech. '
              'Try English, or type your search.',
        'error_network' || 'error_network_timeout' =>
          'Speech recognition needs a connection on this phone. Please type your search.',
        _ => 'Could not understand that. Please try again, or type your search.',
      };
    });
  }

  Future<void> _switchLocale(String locale) async {
    if (_locale == locale) return;
    await _speech.cancel();
    setState(() => _locale = locale);
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final ({String id, String label}) locale in kVoiceLocales)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(locale.label),
                    selected: _locale == locale.id,
                    onSelected: (_) => _switchLocale(locale.id),
                    selectedColor: AppColors.black,
                    showCheckmark: false,
                    labelStyle: AppTypography.smallStrong.copyWith(
                      color: _locale == locale.id ? AppColors.white : AppColors.text,
                    ),
                    side: BorderSide(
                      color: _locale == locale.id ? AppColors.black : AppColors.border,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(child: _Indicator(stage: _stage)),
          const SizedBox(height: AppSpacing.md),
          Text(
            switch (_stage) {
              _Stage.starting => 'Getting ready…',
              _Stage.listening => _words.isEmpty ? 'Listening…' : _words,
              _Stage.heard => _words,
              _Stage.failed => _message,
            },
            textAlign: TextAlign.center,
            style: _stage == _Stage.failed
                ? AppTypography.small.copyWith(color: AppColors.textSoft)
                : AppTypography.bodyStrong,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_stage == _Stage.failed)
            PrimaryButton(label: 'Try Again', onPressed: _start)
          else
            GhostButton(
              label: 'Cancel',
              onPressed: () {
                _speech.cancel();
                Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your voice is processed by your phone and never leaves it.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.stage});

  final _Stage stage;

  @override
  Widget build(BuildContext context) {
    final bool live = stage == _Stage.listening;
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: stage == _Stage.failed ? AppColors.surfaceAlt : AppColors.red,
      ),
      child: stage == _Stage.starting
          ? const Padding(
              padding: EdgeInsets.all(26),
              child: CircularProgressIndicator(
                color: AppColors.white,
                strokeWidth: 2.5,
              ),
            )
          : Icon(
              stage == _Stage.failed ? Icons.mic_off_rounded : Icons.mic_rounded,
              size: 40,
              color: stage == _Stage.failed ? AppColors.textMuted : AppColors.white,
              semanticLabel: live ? 'Listening' : null,
            ),
    );
  }
}
