import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/i18n/helper_text.dart';
import '../../core/platform/voice.dart';

/// Shared, non-blocking feedback for every screen using pre-recorded speech.
/// Missing speech never silently becomes robotic device TTS.
class VoiceFeedback extends StatefulWidget {
  final Widget child;
  const VoiceFeedback({super.key, required this.child});

  @override
  State<VoiceFeedback> createState() => _VoiceFeedbackState();
}

class _VoiceFeedbackState extends State<VoiceFeedback> {
  Timer? _timer;
  VoiceFailure? _visible;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    Voice.failure.addListener(_changed);
  }

  void _changed() {
    _timer?.cancel();
    // Several missing lines can report in one frame. Only the latest callback
    // may start the auto-hide timer, or an earlier one stays pending.
    final gen = ++_gen;
    // Some screens request speech during mount; never rebuild during that build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || gen != _gen) return;
      setState(() => _visible = Voice.failure.value);
      if (_visible != null) {
        _timer = Timer(const Duration(seconds: 7), () {
          if (mounted && gen == _gen) setState(() => _visible = null);
        });
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _gen++;
    _timer?.cancel();
    Voice.failure.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issue = _visible;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (issue != null)
          Positioned(
            left: 12,
            right: 12,
            // Above the lesson, not over the reply row. A bottom banner was
            // covering the message send control even after the text stopped
            // taking taps.
            top: MediaQuery.paddingOf(context).top + 8,
            child: Stack(
              children: [
                // The sentence stays on screen, but it must not cover the reply or
                // the next control. Only Dismiss and Retry take taps.
                IgnorePointer(
                  child: Material(
                    key: const ValueKey('voice-feedback'),
                    color: BL.navy,
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 48, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 3, right: 10),
                            child: Icon(
                              Icons.volume_off_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    hl(
                                      issue.kind == VoiceFailureKind.missing
                                          ? 'No recording for this line yet. You can keep reading.'
                                          : 'Audio could not play. Check your connection or try again.',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                  if (helperLang == 'fa')
                                    Text(
                                      issue.kind == VoiceFailureKind.missing
                                          ? 'صدای این جمله هنوز آماده نیست؛ می‌توانی خواندن را ادامه بدهی.'
                                          : 'صدا پخش نشد؛ اتصال را بررسی کن یا دوباره امتحان کن.',
                                      textDirection: TextDirection.rtl,
                                      style: BL.fa(12, color: Colors.white),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (issue.kind == VoiceFailureKind.playback)
                        TextButton(
                          key: const ValueKey('voice-retry'),
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          onPressed: Voice.retry,
                          child: Text(hl('Retry')),
                        ),
                      // No tooltip: this notice sits above the Navigator, where there is no Overlay for one.
                      IconButton(
                        key: const ValueKey('voice-dismiss'),
                        color: Colors.white,
                        onPressed: () {
                          _timer?.cancel();
                          setState(() => _visible = null);
                        },
                        icon: const Icon(Icons.close_rounded, size: 19, semanticLabel: 'Dismiss audio message'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
