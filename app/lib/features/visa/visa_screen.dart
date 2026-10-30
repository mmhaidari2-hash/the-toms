import 'dart:convert';

import 'package:british_life/core/i18n/helper_text.dart';
import 'package:british_life/core/platform/asset_text.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../shared/nav.dart';

/// Visa Help Desk — general information and signposts only (GOV.UK + OISC). Never case advice.
class VisaScreen extends StatefulWidget {
  const VisaScreen({super.key});
  @override
  State<VisaScreen> createState() => _VisaScreenState();
}

class _VisaScreenState extends State<VisaScreen> {
  Map<String, dynamic>? data;
  Object? err;

  @override
  void initState() {
    super.initState();
    loadAssetText('assets/data/visa_desk.json').then((s) {
      if (!mounted) return;
      setState(() => data = jsonDecode(s) as Map<String, dynamic>);
    }).catchError((e) {
      if (mounted) setState(() => err = e);
    });
  }

  Future<void> _open(String url) async {
    final u = Uri.parse(url);
    if (!await launchUrl(u, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hl('Could not open link'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    if (err != null) {
      return Scaffold(backgroundColor: BL.cream, body: Center(child: Text(hl('$err'))));
    }
    if (data == null) {
      return const Scaffold(backgroundColor: BL.cream, body: Center(child: CircularProgressIndicator()));
    }
    final topics = (data!['topics'] as List).cast<Map<String, dynamic>>();
    return Scaffold(
      backgroundColor: BL.cream,
      body: ListView(
        key: const ValueKey('visa-desk'),
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          const Row(children: [NavButtons(), SizedBox(width: 10), Text('VISA HELP DESK', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red))]),
          const SizedBox(height: 12),
          Text(hl(data!['title'] as String), style: BL.display(26)),
          Text(hl(data!['titleFa'] as String), textDirection: helperDir, style: BL.fa(14)),
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('visa-disclaimer'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0A800))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hl(data!['disclaimer_en'] as String), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
              const SizedBox(height: 6),
              Text(hl(data!['disclaimer_fa'] as String), textDirection: helperDir, style: BL.fa(13, color: BL.ink)),
            ]),
          ),
          for (final t in topics) ...[
            const SizedBox(height: 18),
            Text(hl(t['title'] as String), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            Text(hl(t['titleFa'] as String), textDirection: helperDir, style: BL.fa(13, color: BL.muted)),
            const SizedBox(height: 6),
            Text(hl(t['body'] as String), style: const TextStyle(height: 1.4, fontSize: 14)),
            const SizedBox(height: 4),
            Text(hl(t['bodyFa'] as String), textDirection: helperDir, style: BL.fa(13, color: BL.muted)),
            const SizedBox(height: 8),
            for (final link in (t['links'] as List).cast<Map<String, dynamic>>())
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OutlinedButton.icon(
                  key: ValueKey('visa-link-${t['id']}-${link['url']}'),
                  onPressed: () => _open(link['url'] as String),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Align(alignment: Alignment.centerLeft, child: Text(hl(link['label'] as String), style: const TextStyle(fontWeight: FontWeight.w700))),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
