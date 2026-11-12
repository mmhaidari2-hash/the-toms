import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../driving/driving_data.dart';
import '../lifeuk/lifeuk_data.dart';
import '../shared/nav.dart';
import '../theory/theory_data.dart';
import 'premium_screen.dart';

/// Exam / Driving English gate (Option B). Decided ONCE when the screen opens, so a mock test or lesson that has
/// started is never replaced by the paywall when its result is saved. Free: chapter 1, one mock test and the first
/// Driving English lesson. Never used for Arrival, emergency, Forms Lab, Visa desk or Settlement.
class EntryGate extends ConsumerStatefulWidget {
  /// 'lifeuk' or 'theory' (the Driving English lessons belong to the Theory pack).
  final String exam;
  /// Chapter id, or null for the mock test.
  final String? chapter;
  /// Driving English lesson id (exam must be 'theory').
  final String? driving;
  final Widget child;
  const EntryGate({super.key, required this.exam, this.chapter, this.driving, required this.child});
  @override
  ConsumerState<EntryGate> createState() => _EntryGateState();
}

class _EntryGateState extends ConsumerState<EntryGate> {
  bool? _open;

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.read(progressProvider.notifier);
    if (_open == null) {
      if (!ctrl.sellsContent) {
        _open = true;
      } else if (widget.driving != null) {
        final ls = ref.watch(drivingProvider).value;
        if (ls == null) return const NavLoading();
        _open = ctrl.drivingLessonOpen(ls.indexWhere((l) => l.id == widget.driving).clamp(0, 1 << 20));
      } else if (widget.chapter == null) {
        _open = ctrl.examMockOpen(widget.exam);
      } else {
        final ids = widget.exam == 'theory' ? ref.watch(thyProvider).value?.map((c) => c.id).toList() : ref.watch(lukProvider).value?.map((c) => c.id).toList();
        if (ids == null) return const NavLoading();
        _open = ctrl.examChapterOpen(widget.exam, ids.indexOf(widget.chapter!).clamp(0, 1 << 20));
      }
    }
    return _open! ? widget.child : PremiumScreen(pack: widget.exam, reason: widget.chapter == null && widget.driving == null ? 'mock' : 'exam');
  }
}
