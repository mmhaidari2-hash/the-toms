import 'package:flutter/widgets.dart';

/// Non-web: no video, the painting underneath stays visible.
class LoopVideo extends StatelessWidget {
  final String asset;
  final String? poster;
  const LoopVideo({super.key, required this.asset, this.poster});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
