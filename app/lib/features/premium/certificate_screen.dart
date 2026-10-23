import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../shared/nav.dart';

const certLevels = {
  1: ('Home', 'خانه', 'A1'),
  2: ('Neighbourhood', 'محله', 'A2'),
  3: ('High Street', 'خیابان اصلی', 'B1'),
  4: ('Town centre', 'مرکز شهر', 'B2'),
  5: ('The city', 'شهر', 'C1'),
};

/// A completion certificate for each course level. Locked levels show progress instead.
class CertificateScreen extends ConsumerStatefulWidget {
  final int level;
  const CertificateScreen({super.key, required this.level});
  static const disclaimer = 'Not an accredited qualification. CEFR level is an indication only. Not a CEFR, IELTS, Ofqual-regulated or Home Office-approved English test.';
  static const disclaimerFa = 'این یک مدرک معتبر/رسمی نیست و سطح CEFR فقط تقریبی است؛ آزمون رسمی زبان (مثل IELTS یا آزمون مورد تأیید وزارت کشور) هم نیست.';
  @override
  ConsumerState<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends ConsumerState<CertificateScreen> {
  late final TextEditingController _name;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(progressProvider.notifier).certName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(contentProvider).value;
    final p = ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    if (c == null) return const NavLoading();
    final lv = widget.level.clamp(1, 5);
    final (name, nameFa, cefr) = certLevels[lv]!;
    final done = ctrl.levelComplete(c.course, lv) || p.unlockAll;
    final prog = ctrl.levelProgress(c.course, lv);
    final units = ctrl.levelUnits(c.course, lv);
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: BL.cream,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
        children: [
          Row(children: [const NavButtons(), const SizedBox(width: 10), Text('CERTIFICATES', style: const TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red))]),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final l in certLevels.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('cert-level-$l'),
                    label: Text(hl('Level $l')),
                    avatar: Icon(ctrl.levelComplete(c.course, l) || p.unlockAll ? Icons.verified_rounded : Icons.lock_outline_rounded, size: 16),
                    selected: l == lv,
                    onSelected: (_) => context.go('/certificate/$l'),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1 / 1.25,
            child: Container(
              key: ValueKey(done ? 'certificate' : 'certificate-locked'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: BL.paper, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8))]),
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFC9A04C), width: 3), borderRadius: BorderRadius.circular(4)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Opacity(
                  opacity: done ? 1 : .45,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 280,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('NEW LIFE UK · BRITISH ENGLISH FOR LIFE', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.red)),
                        const SizedBox(height: 10),
                        Text('Certificate of Completion', textAlign: TextAlign.center, style: BL.display(24)),
                        Text(hl('گواهی پایان دوره'), textDirection: helperDir, style: BL.fa(13, color: BL.muted)),
                        const SizedBox(height: 14),
                        const Text('Awarded to', style: TextStyle(fontSize: 12, color: BL.muted)),
                        const SizedBox(height: 6),
                        Text(hl(ctrl.certName.isEmpty ? 'Your name' : ctrl.certName), textAlign: TextAlign.center, style: BL.display(26, color: BL.navy)),
                        Container(height: 1, width: 200, color: BL.mist, margin: const EdgeInsets.symmetric(vertical: 6)),
                        const Text('for completing New Life UK course content', style: TextStyle(fontSize: 12, color: BL.muted)),
                        const SizedBox(height: 6),
                        Text(hl('Level $lv · $name'), textAlign: TextAlign.center, style: BL.display(20)),
                        Text(hl(nameFa), key: const ValueKey('cert-level-fa'), textDirection: helperDir, style: BL.fa(13, color: BL.muted)),
                        Text(hl('Aligned to CEFR descriptors · $cefr'), key: const ValueKey('cert-cefr'), textDirection: TextDirection.ltr, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: BL.muted)),
                        const SizedBox(height: 6),
                        Text(hl('${units.length} units · ${units.expand((u) => u.lessons).length} lessons of everyday British English'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: BL.ink)),
                        const SizedBox(height: 16),
                        Icon(done ? Icons.verified_rounded : Icons.lock_rounded, size: 46, color: done ? const Color(0xFFC9A04C) : BL.muted),
                        const SizedBox(height: 4),
                        Text(hl(done ? 'Tom, Leslie & the family · Hackney, London' : 'Locked'), style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: BL.muted)),
                        const SizedBox(height: 10),
                        Text(hl(CertificateScreen.disclaimer), key: ValueKey('cert-disclaimer'), textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, color: BL.muted, height: 1.3)),
                        Text(hl(CertificateScreen.disclaimerFa), textAlign: TextAlign.center, textDirection: helperDir, style: BL.fa(9.5, color: BL.muted)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!done) ...[
            Text(hl('${(prog * 100).round()}% of Level $lv done. Finish every unit to earn this certificate.'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(hl('همهٔ واحدهای این سطح را تمام کنید تا گواهی را بگیرید.'), textAlign: TextAlign.center, textDirection: helperDir, style: BL.fa(12, color: BL.muted)),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: prog, minHeight: 8, color: BL.green, backgroundColor: BL.mist)),
          ] else
            TextField(
              key: const ValueKey('cert-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Name on the certificate', filled: true, fillColor: BL.paper, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
              onSubmitted: (v) => ctrl.setCertName(v),
              onChanged: (v) => ctrl.setCertName(v),
            ),
        ],
      ),
    );
  }
}
