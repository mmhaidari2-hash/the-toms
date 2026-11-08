import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../lifeuk/lifeuk_data.dart';
import '../shared/nav.dart';
import 'premium_screen.dart';

/// Premium areas beyond the Career Packs (decision 2026-11-08: Life in the UK and IELTS Life Skills prep are
/// Premium; chapter 1 of Life in the UK stays free as a sample). In the beta (`PremiumConfig.betaFree`) every
/// gate is open. Locked: the route shows the paywall in place of the screen, like a Career Pack lesson.
class PremiumGate extends ConsumerWidget {
  final Widget child;

  /// Life in the UK chapter id: the first chapter is the free sample. Null for a whole Premium area.
  final String? lukChapter;
  const PremiumGate({super.key, required this.child, this.lukChapter});

  /// Is a Life in the UK chapter the free sample?
  static bool lukFree(List<LukChapter> cs, String id) => cs.isNotEmpty && cs.first.id == id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    if (ref.read(progressProvider.notifier).hasPremium) return child;
    final ch = lukChapter;
    if (ch != null) {
      final cs = ref.watch(lukProvider).value;
      if (cs == null) return const NavLoading();
      if (lukFree(cs, ch)) return child;
    }
    return const PremiumScreen();
  }
}
