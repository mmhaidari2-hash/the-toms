import 'dart:convert';

import 'package:british_life/core/i18n/helper_text.dart';
import 'package:british_life/core/platform/asset_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../shared/nav.dart';

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});
  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    loadAssetText('assets/data/settlement.json').then((s) {
      if (mounted) setState(() => data = jsonDecode(s) as Map<String, dynamic>);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    if (data == null) return const Scaffold(backgroundColor: BL.cream, body: Center(child: CircularProgressIndicator()));
    final mods = (data!['modules'] as List).cast<Map<String, dynamic>>();
    return Scaffold(
      backgroundColor: BL.cream,
      body: ListView(
        key: const ValueKey('settlement-hub'),
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          const Row(children: [NavButtons(), SizedBox(width: 10), Text('B2 · SETTLEMENT', style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.red))]),
          const SizedBox(height: 10),
          Text(hl(data!['title'] as String), style: BL.display(24)),
          Text(hl(data!['titleFa'] as String), textDirection: helperDir, style: BL.fa(14)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0A800))),
            child: Text(hl(data!['disclaimer_en'] as String), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
          ),
          for (final m in mods) ...[
            const SizedBox(height: 14),
            Material(
              color: Colors.white,
              elevation: 1,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                key: ValueKey('settle-${m['id']}'),
                borderRadius: BorderRadius.circular(18),
                onTap: () => context.push(m['route'] as String),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(hl(m['title'] as String), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(hl(m['titleFa'] as String), textDirection: helperDir, style: BL.fa(12.5, color: BL.muted)),
                    const SizedBox(height: 6),
                    Text(hl(m['blurb'] as String), style: const TextStyle(height: 1.35, fontSize: 13.5)),
                    if (m['gov'] != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => launchUrl(Uri.parse(m['gov'] as String), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(hl('GOV.UK page')),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
