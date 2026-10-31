import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../shared/nav.dart';
import 'arrival_pack_data.dart';
import 'arrival_prefetch.dart';

/// One-tap download of week-1 lessons + Forms Lab + emergency phrases for low-data / offline use.
class ArrivalPackScreen extends ConsumerStatefulWidget {
  const ArrivalPackScreen({super.key});

  @override
  ConsumerState<ArrivalPackScreen> createState() => _ArrivalPackScreenState();
}

class _ArrivalPackScreenState extends ConsumerState<ArrivalPackScreen> {
  bool _busy = false;
  bool _cancel = false;
  double _progress = 0;
  int _done = 0, _total = 0;
  String? _status;

  bool _ready = false;

  Future<void> _markReady(bool v) async {
    setState(() => _ready = v);
  }

  Future<void> _download(ArrivalPack pack) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _cancel = false;
      _progress = 0;
      _done = 0;
      _total = pack.audioKeys.length;
      _status = 'Downloading British audio…';
    });
    final n = await warmArrivalAudio(
      pack.audioKeys,
      shouldCancel: () => _cancel,
      onProgress: (p, d, t) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          _done = d;
          _total = t;
        });
      },
    );
    if (!mounted) return;
    setState(() {
      // warmed count in status
      _busy = false;
      _status = _cancel ? 'Cancelled — you can finish later.' : 'Ready offline: $n of ${pack.audioKeys.length} clips.';
    });
    if (!_cancel && n > pack.audioKeys.length * 0.8) {
      await _markReady(true);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(arrivalPackProvider);
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: BL.cream,
      bottomNavigationBar: async.maybeWhen(
        data: (pack) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: _busy
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    LinearProgressIndicator(value: _progress == 0 ? null : _progress, color: BL.red, backgroundColor: BL.mist),
                    const SizedBox(height: 6),
                    Text(hl('$_done / $_total'), style: const TextStyle(fontSize: 12, color: BL.muted)),
                    OutlinedButton(key: const ValueKey('arrival-cancel'), onPressed: () => setState(() => _cancel = true), child: Text(hl('Cancel'))),
                  ])
                : FilledButton.icon(
                    key: const ValueKey('arrival-download'),
                    style: FilledButton.styleFrom(backgroundColor: BL.red, minimumSize: const Size.fromHeight(48)),
                    onPressed: () => _download(pack),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(hl(_ready ? 'Download again' : 'Download offline pack')),
                  ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(hl('$e'))),
        data: (pack) => ListView(
          key: const ValueKey('arrival-pack'),
          padding: EdgeInsets.fromLTRB(20, pad.top + 6, 20, pad.bottom + 32),
          children: [
            const Row(children: [
              NavButtons(),
              SizedBox(width: 10),
              Text('ARRIVAL', style: TextStyle(fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: BL.red)),
            ]),
            const SizedBox(height: 10),
            Text(hl(pack.title), style: BL.display(24)),
            Text(hl(pack.titleFa), textDirection: helperDir, style: BL.fa(14)),
            const SizedBox(height: 8),
            Text(hl(pack.tagline), style: const TextStyle(height: 1.4, fontSize: 14)),
            const SizedBox(height: 4),
            Text(hl(pack.taglineFa), textDirection: helperDir, style: BL.fa(13, color: BL.muted)),
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('arrival-disclaimer'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0A800))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hl(pack.disclaimer), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35, fontSize: 13)),
                const SizedBox(height: 6),
                Text(hl(pack.disclaimerFa), textDirection: helperDir, style: BL.fa(12.5, color: BL.ink)),
              ]),
            ),
            const SizedBox(height: 16),
            if (_ready)
              Container(
                key: const ValueKey('arrival-ready'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(14)),
                child: Text(hl('Pack downloaded on this device. Forms Lab and week‑1 audio work with weak Wi‑Fi.'), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 12),
            Text(hl('What\'s inside'), style: BL.display(18)),
            Text(hl('داخل بسته'), textDirection: helperDir, style: BL.fa(13, color: BL.muted)),
            const SizedBox(height: 8),
            _card(
              icon: Icons.school_rounded,
              title: 'First week of English (Level 1)',
              titleFa: 'هفتهٔ اول انگلیسی (سطح ۱)',
              body: '${pack.units.length} units · ${pack.sceneIds.length} conversations · ~${pack.approxAudioMb} MB audio',
            ),
            for (final u in pack.units)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 6),
                child: Text(hl('• ${u.title} — ${u.titleFa}'), style: const TextStyle(fontSize: 13, height: 1.35)),
              ),
            if (pack.formsLab)
              _card(
                icon: Icons.description_rounded,
                title: 'UK Forms Practice Lab',
                titleFa: 'آزمایشگاه فرم‌های بریتانیا',
                body: 'GP, NHS 111, council tax, job application — already in the app, works offline.',
                onTap: () => context.push('/forms'),
              ),
            _card(
              icon: Icons.health_and_safety_rounded,
              title: 'Emergency & first phrases',
              titleFa: 'اورژانس و جمله‌های اول',
              body: '${pack.phrases.length} essential lines with British audio.',
            ),
            for (final p in pack.phrases)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Container(
                  key: ValueKey('arrival-phrase-${p.id}'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: BL.mist)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(hl(p.en), style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35)),
                    const SizedBox(height: 4),
                    Text(hl(p.fa), textDirection: helperDir, style: BL.fa(13, color: BL.muted)),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            if (_status != null) Text(hl(_status!), style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _card({required IconData icon, required String title, required String titleFa, required String body, VoidCallback? onTap}) {
    final child = Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: BL.mist, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: BL.red, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(hl(title), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(hl(titleFa), textDirection: helperDir, style: BL.fa(12.5, color: BL.muted)),
            const SizedBox(height: 4),
            Text(hl(body), style: const TextStyle(fontSize: 13, height: 1.35)),
          ]),
        ),
        if (onTap != null) const Icon(Icons.chevron_right_rounded, color: BL.muted),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        elevation: 1,
        shadowColor: BL.navy.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
        child: onTap == null ? child : InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: child),
      ),
    );
  }
}
