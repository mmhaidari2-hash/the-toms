import 'dart:math';

import '../models/milestone.dart';

/// Growth % = weighted blend of
///   • successful dialogue branches (45%)
///   • words mastered in Leitner box 5 (35%)
///   • trust, through a soft cap so it saturates instead of being grinded (20%)
class GrowthEngine {
  static const branchTarget = 8;
  static const masteredTarget = 10;
  static const trustScale = 50.0;

  /// Raw trust 0..∞ → effective 0..100 with diminishing returns.
  static double softTrust(int raw) => 100 * (1 - exp(-max(0, raw) / trustScale));

  /// Streak is a small accelerator (≤ +14%), never the main driver.
  static double streakBoost(int streak) => 1 + min(streak, 7) * .02;

  static double growth({required int successfulBranches, required int masteredWords, required int trust, int streak = 0}) {
    final b = min(1.0, successfulBranches / branchTarget);
    final w = min(1.0, masteredWords / masteredTarget);
    final t = softTrust(trust) / 100;
    return ((0.45 * b + 0.35 * w + 0.20 * t) * 100 * streakBoost(streak)).clamp(0, 100).toDouble();
  }

  static Milestone milestoneFor(double growth, List<Milestone> ms) {
    final sorted = [...ms]..sort((a, b) => a.threshold.compareTo(b.threshold));
    return sorted.lastWhere((m) => growth >= m.threshold, orElse: () => sorted.first);
  }

  static Milestone? nextMilestone(double growth, List<Milestone> ms) {
    final sorted = [...ms]..sort((a, b) => a.threshold.compareTo(b.threshold));
    for (final m in sorted) {
      if (m.threshold > growth) return m;
    }
    return null;
  }
}
