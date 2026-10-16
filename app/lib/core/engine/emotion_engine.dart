import 'dart:math';

class MoodInfo {
  final String emoji, en, fa;
  const MoodInfo(this.emoji, this.en, this.fa);
}

/// Mood is short-term (how this chat is going), Trust is long-term (the relationship).
/// Mood ∈ [-1, 1] is an exponential moving average of recent turn quality.
class EmotionEngine {
  static const _keep = .6;

  static double update(double mood, {required bool understood, int trustDelta = 0}) {
    final target = understood ? min(1.0, .3 + trustDelta / 10) : -.6;
    return (mood * _keep + target * (1 - _keep)).clamp(-1.0, 1.0);
  }

  /// Warm characters give a little extra trust; cross ones a little less.
  static int trustWithMood(int delta, double mood) => delta <= 0 ? delta : max(1, delta + (mood > .45 ? 1 : (mood < -.3 ? -1 : 0)));

  static MoodInfo label(double m) {
    if (m > .45) return const MoodInfo('😄', 'Cheerful', 'سرحال');
    if (m > .1) return const MoodInfo('🙂', 'Content', 'راضی');
    if (m > -.2) return const MoodInfo('😐', 'Neutral', 'معمولی');
    return const MoodInfo('😕', 'Puzzled', 'گیج');
  }
}
