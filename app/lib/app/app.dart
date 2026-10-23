import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/providers.dart';
import '../core/i18n/helper_text.dart';

import '../core/platform/retry_bundle.dart';
import '../features/leitner/leitner_add.dart';
import 'router.dart';
import 'theme.dart';

class BritishLifeApp extends StatelessWidget {
  const BritishLifeApp({super.key});
  static final bundle = RetryAssetBundle();
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'New Life UK',
    debugShowCheckedModeBanner: false,
    theme: BL.theme(),
    routerConfig: router,
    builder: (context, child) => DefaultAssetBundle(bundle: bundle, child: ColoredBox(
      color: const Color(0xFFE9E2D6),
      // Keep a phone-width column on tablets/desktop browsers.
      child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: HelperLangScope(child: LeitnerSelect(child: child ?? const SizedBox()))),
      ),
    )),
  );
}

/// Keeps the helper-language table in step with the learner's choice. Switching language loads that table, then
/// rebuilds every widget in place (state and the current screen are kept), since every Text passes through hl().
class HelperLangScope extends ConsumerStatefulWidget {
  final Widget child;
  const HelperLangScope({super.key, required this.child});
  @override
  ConsumerState<HelperLangScope> createState() => _HelperLangScopeState();
}

class _HelperLangScopeState extends ConsumerState<HelperLangScope> {
  String? _want;

  void _rebuildAll(Element e) {
    e.markNeedsBuild();
    e.visitChildren(_rebuildAll);
  }

  Future<void> _switch(String code) async {
    _want = code;
    await useHelperLang(code);
    if (!mounted || _want != code) return;
    setState(() {});
    (context as Element).visitChildren(_rebuildAll);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(progressProvider.select((p) => p.lang));
    if (lang != helperLang && lang != _want) {
      if (isHelperLoaded(lang)) {
        useHelperLang(lang);
        WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) (context as Element).visitChildren(_rebuildAll); });
      } else {
        _switch(lang);
      }
    }
    return widget.child;
  }
}
