import 'package:flutter/material.dart';

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
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: LeitnerSelect(child: child ?? const SizedBox())),
      ),
    )),
  );
}
