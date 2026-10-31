import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../shared/nav.dart';
import 'forms_data.dart';

IconData _icon(String name) => switch (name) {
      'local_hospital' => Icons.local_hospital_rounded,
      'phone_in_talk' => Icons.phone_in_talk_rounded,
      'home_work' => Icons.home_work_rounded,
      'work' => Icons.work_rounded,
      _ => Icons.description_rounded,
    };

/// Hub: pick a UK paperwork practice form. Practice only — links out to official sites.
class FormsLabScreen extends ConsumerWidget {
  const FormsLabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(formsLabProvider);
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: BL.cream,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(hl('$e'))),
        data: (lab) => ListView(
          key: const ValueKey('forms-lab'),
          cacheExtent: 4000,
          padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
          children: [
            const Row(children: [
              NavButtons(),
              SizedBox(width: 10),
              Text('LIFE SKILLS', style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.red)),
            ]),
            const SizedBox(height: 10),
            Text(hl(lab.title), style: BL.display(24)),
            Text(hl(lab.titleFa), textDirection: helperDir, style: BL.fa(14)),
            const SizedBox(height: 8),
            Text(hl(lab.blurb), style: const TextStyle(height: 1.4, fontSize: 14)),
            const SizedBox(height: 4),
            Text(hl(lab.blurbFa), textDirection: helperDir, style: BL.fa(13, color: BL.muted)),
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('forms-disclaimer'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0A800))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hl(lab.disclaimerEn), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35, fontSize: 13)),
                const SizedBox(height: 6),
                Text(hl(lab.disclaimerFa), textDirection: helperDir, style: BL.fa(12.5, color: BL.ink)),
              ]),
            ),
            const SizedBox(height: 18),
            for (final f in lab.forms) ...[
              Material(
                color: Colors.white,
                elevation: 1,
                shadowColor: BL.navy.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  key: ValueKey('form-card-${f.id}'),
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => context.push('/forms/${f.id}'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: BL.mist, borderRadius: BorderRadius.circular(14)),
                        child: Icon(_icon(f.icon), color: BL.red, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(hl(f.level), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: BL.red, letterSpacing: .6)),
                          Text(hl(f.title), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(hl(f.titleFa), textDirection: helperDir, style: BL.fa(12.5, color: BL.muted)),
                          const SizedBox(height: 4),
                          Text(hl(f.blurb), style: const TextStyle(height: 1.35, fontSize: 13)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: BL.muted),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(hl('Trusted starting points'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            Text(hl('نقطه‌های شروع رسمی'), textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
            const SizedBox(height: 6),
            for (final link in [
              ('NHS — find a GP', 'https://www.nhs.uk/service-search/find-a-gp'),
              ('NHS 111', 'https://111.nhs.uk/'),
              ('Council tax (GOV.UK)', 'https://www.gov.uk/council-tax'),
              ('Find a job (GOV.UK)', 'https://www.gov.uk/find-a-job'),
            ])
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(link.$2), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Align(alignment: Alignment.centerLeft, child: Text(hl(link.$1))),
              ),
          ],
        ),
      ),
    );
  }
}
