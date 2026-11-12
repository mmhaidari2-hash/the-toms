import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'speech_result.dart';

/// One recognition event from the platform recognizer.
class SttEvent {
  final List<String> alternatives;
  final double confidence;
  final bool isFinal;
  const SttEvent(this.alternatives, {this.confidence = 0, this.isFinal = false});
}

/// The platform speech recognizer, behind a seam so tests can fake it.
abstract class SttBackend {
  Future<bool> hasPermission();
  Future<bool> initialize({required void Function(String error, bool permanent) onError, required void Function(String status) onStatus});
  Future<void> listen({required void Function(SttEvent e) onResult, required bool onDevice, required String localeId});
  Future<void> stop();
}

/// Android's own SpeechRecognizer through the `speech_to_text` plugin. Free, no key, no server of ours.
/// The app never records or uploads audio itself: the recognizer is Android's (usually Google's). With
/// [onDevice] it uses the on-device recognizer when the phone has one (Android 12+ with the offline English
/// pack); otherwise Android decides, and Google's service may process the voice on its servers.
class PluginSttBackend implements SttBackend {
  final SpeechToText _stt = SpeechToText();
  @override
  Future<bool> hasPermission() => _stt.hasPermission;
  @override
  Future<bool> initialize({required void Function(String error, bool permanent) onError, required void Function(String status) onStatus}) => _stt.initialize(
        onError: (SpeechRecognitionError e) => onError(e.errorMsg, e.permanent),
        onStatus: onStatus,
        // No Bluetooth permission: only RECORD_AUDIO is declared.
        options: [SpeechToText.androidNoBluetooth],
      );
  @override
  Future<void> listen({required void Function(SttEvent e) onResult, required bool onDevice, required String localeId}) => _stt.listen(
        onResult: (SpeechRecognitionResult r) => onResult(SttEvent(
          [for (final a in r.alternates) a.recognizedWords],
          confidence: r.hasConfidenceRating ? r.confidence : 0,
          isFinal: r.finalResult,
        )),
        listenOptions: SpeechListenOptions(
          onDevice: onDevice,
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          localeId: localeId,
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 3),
        ),
      );
  @override
  Future<void> stop() => _stt.stop();
}

/// On-device speech recognition for the installed Android app (owner t306, item 1).
///
/// Flow: explain first (EN+FA rationale, via [rationale]) → Android runtime permission (RECORD_AUDIO) →
/// recognise, preferring the on-device recognizer → on any failure the caller falls back to typing.
/// Error codes match the web recognizer's so the existing UI handles both.
class NativeStt {
  NativeStt(this.backend);
  final SttBackend backend;

  bool _ready = false;
  bool unavailable = false;
  bool _offlineFailed = false;
  bool _rationaleAccepted = false;
  Completer<SpeechResult>? _active;
  List<String> _last = const [];
  double _conf = 0;
  void Function(String)? _onPartial;

  bool get listening => _active != null && !_active!.isCompleted;

  static String mapError(String e) {
    if (e.contains('permission')) return 'not-allowed';
    if (e.contains('no_match') || e.contains('speech_timeout')) return 'no-speech';
    if (e.contains('network') || e.contains('server')) return 'network';
    if (e.contains('audio')) return 'audio-capture';
    if (e.contains('busy') || e.contains('client')) return 'aborted';
    if (e.contains('language')) return 'language';
    return 'start-failed';
  }

  void _finish(SpeechResult r) {
    final c = _active;
    if (c != null && !c.isCompleted) c.complete(r);
  }

  Future<SpeechResult> listen({void Function(String partial)? onPartial, String localeId = 'en_GB'}) async {
    if (unavailable) return const SpeechResult(error: 'unsupported');
    if (listening) return const SpeechResult(error: 'aborted');
    if (!await backend.hasPermission()) {
      if (!_rationaleAccepted) {
        final ok = await (SpeechHooks.rationale?.call() ?? Future.value(true));
        if (!ok) return const SpeechResult(error: 'not-allowed');
        _rationaleAccepted = true;
      }
    }
    if (!_ready) {
      final ok = await backend.initialize(
        onError: (e, permanent) {
          if (!listening) return;
          final code = mapError(e);
          if (code == 'no-speech' && _last.isNotEmpty) return _finish(SpeechResult(alternatives: _last, confidence: _conf));
          _finish(SpeechResult(error: code));
        },
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && listening && _last.isNotEmpty) {
            // Some recognizers end without a final result: use the last partial.
            Future.delayed(const Duration(milliseconds: 600), () => _finish(SpeechResult(alternatives: _last, confidence: _conf)));
          }
        },
      );
      if (!ok) {
        if (!await backend.hasPermission()) return const SpeechResult(error: 'not-allowed');
        unavailable = true; // no recognizer on this phone: typing only
        return const SpeechResult(error: 'unsupported');
      }
      _ready = true;
    }
    final r = await _listenOnce(onPartial, localeId, onDevice: !_offlineFailed);
    if (r.error == 'language' && !_offlineFailed) {
      // The on-device recognizer has no English model: let Android choose its default recognizer.
      _offlineFailed = true;
      return _listenOnce(onPartial, localeId, onDevice: false);
    }
    return r.error == 'language' ? const SpeechResult(error: 'start-failed') : r;
  }

  Future<SpeechResult> _listenOnce(void Function(String)? onPartial, String localeId, {required bool onDevice}) async {
    final c = _active = Completer<SpeechResult>();
    _last = const [];
    _conf = 0;
    _onPartial = onPartial;
    try {
      await backend.listen(
        onDevice: onDevice,
        localeId: localeId,
        onResult: (e) {
          if (!identical(c, _active)) return;
          final alts = [for (final a in e.alternatives) if (a.trim().isNotEmpty) a.trim()];
          if (alts.isEmpty) return;
          _last = alts;
          _conf = e.confidence;
          _onPartial?.call(alts.first);
          if (e.isFinal) _finish(SpeechResult(alternatives: alts, confidence: e.confidence));
        },
      );
    } catch (_) {
      _finish(const SpeechResult(error: 'start-failed'));
    }
    final timeout = Timer(const Duration(seconds: 30), () => _finish(_last.isEmpty ? const SpeechResult(error: 'no-speech') : SpeechResult(alternatives: _last, confidence: _conf)));
    final r = await c.future;
    timeout.cancel();
    return r;
  }

  void stop() {
    if (!listening) return;
    backend.stop();
    // The final result normally arrives after stop; if not, use what was heard.
    Future.delayed(const Duration(milliseconds: 1500), () => _finish(_last.isEmpty ? const SpeechResult(error: 'aborted') : SpeechResult(alternatives: _last, confidence: _conf)));
  }
}
