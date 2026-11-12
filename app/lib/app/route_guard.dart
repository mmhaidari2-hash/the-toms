import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/data/providers.dart';
import '../core/models/course.dart';
import '../features/shared/nav.dart';

/// Central entitlement guard for every content route (monetisation Option B, hardened t300/t301).
///
/// Runs as the router's top-level redirect for EVERY navigation and deep link (Android and web), and again inside
/// [GuardGate] once content has loaded (cold-start deep links). Lessons, stories (chat), practice, unit tests,
/// exam chapters, flashcards, quizzes, mock tests and Driving English all pass the same free-zone / daily-allowance
/// / entitlement checks as the in-app buttons. Certificates and downloads are decided by the same
/// [ProgressController] getters inside their screens. No-op while [PremiumConfig.betaFree] is true.
abstract final class RouteGuard {
  /// Installed by the app with live access to progress and content.
  static String? Function(Uri uri)? check;
  static String? redirect(BuildContext _, GoRouterState s) => check?.call(s.uri);

  /// First (free) chapter / lesson ids; a test asserts they match the data files.
  static const lifeukFree = 'values', theoryFree = 'attitude', drivingFree = 'cockpit';
}

/// Where [uri] must go instead, or null when it may open. Spends today's free lesson when a story or practice of a
/// new lesson outside the free zone actually starts (idempotent per lesson).
String? guardLocation(Uri uri, ProgressController ctrl, Course? c) {
  if (!ctrl.sellsContent) return null;
  final seg = uri.pathSegments;
  if (seg.isEmpty) return null;
  String? lessonTarget(Lesson l, {required bool starts}) {
    final u = c!.unitOf(l.id)!;
    final pk = c.packOf(u);
    switch (ctrl.lessonLock(c, l)) {
      case LessonLock.open:
        if (starts && !ctrl.claimDailyLesson(c, l)) return '/premium?reason=daily';
        return null;
      case LessonLock.daily:
        return '/premium?reason=daily';
      case LessonLock.pack:
        return '/premium?pack=${pk!.id}';
      case LessonLock.sequence:
        return pk != null ? '/pack/${pk.id}' : '/course';
    }
  }

  switch (seg.first) {
    case 'lesson' when seg.length == 2:
      if (c == null) return null; // GuardGate re-checks once content is loaded
      final l = c.lesson(seg[1]);
      return l == null ? null : lessonTarget(l, starts: false);
    case 'chat' when seg.length == 2:
      if (c == null) return null;
      final base = seg[1].split('__as_').first;
      final l = c.allUnits.expand((u) => u.lessons).where((l) => l.sceneIds.contains(base)).firstOrNull;
      return l == null ? null : lessonTarget(l, starts: true);
    case 'practice' when seg.length == 2:
      if (c == null) return null;
      final l = c.lesson(seg[1]);
      if (l != null) return lessonTarget(l, starts: true);
      final u = c.unit(seg[1]);
      if (u == null) return null; // mistakes review and other non-course practice
      final pk = c.packOf(u);
      if (pk != null) return ctrl.packOwned(pk) ? null : '/premium?pack=${pk.id}';
      final ok = ctrl.inFreeZone(c, u) || ctrl.unitPassed(u) || u.lessons.every(ctrl.lessonDone);
      return ok ? null : '/course';
    case 'lifeuk' || 'theory' when seg.length >= 2:
      final exam = seg.first;
      if (seg[1] == 'mock') return ctrl.examMockOpen(exam) ? null : '/premium?pack=$exam&reason=mock';
      final free = exam == 'lifeuk' ? RouteGuard.lifeukFree : RouteGuard.theoryFree;
      return ctrl.examChapterOpen(exam, seg[1] == free ? 0 : 1) ? null : '/premium?pack=$exam&reason=exam';
    case 'driving' when seg.length == 2:
      return ctrl.drivingLessonOpen(seg[1] == RouteGuard.drivingFree ? 0 : 1) ? null : '/premium?pack=theory&reason=exam';
  }
  return null;
}

/// Second layer of the same guard for routes that need content (cold-start deep links): decided ONCE when the
/// page first has content, so a started lesson or conversation is never swapped for the paywall.
class GuardGate extends ConsumerStatefulWidget {
  final Uri uri;
  final Widget child;
  const GuardGate({super.key, required this.uri, required this.child});
  @override
  ConsumerState<GuardGate> createState() => _GuardGateState();
}

class _GuardGateState extends ConsumerState<GuardGate> {
  bool _decided = false;
  @override
  Widget build(BuildContext context) {
    if (!_decided) {
      final ctrl = ref.read(progressProvider.notifier);
      if (ctrl.sellsContent) {
        final c = ref.watch(contentProvider).value;
        if (c == null) return const NavLoading();
        final to = guardLocation(widget.uri, ctrl, c.course);
        if (to != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go(to);
          });
          return const NavLoading();
        }
      }
      _decided = true;
    }
    return widget.child;
  }
}
