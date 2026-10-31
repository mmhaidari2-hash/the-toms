import 'package:british_life/core/i18n/helper_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../grammar/grammar_data.dart';
import '../library/library_data.dart';
import '../shared/nav.dart';
import 'messages_data.dart';

const phoneBg = Color(0xFFF4F1EA), bubbleThem = Colors.white, bubbleMe = Color(0xFF2E7D5B);

/// The learner's phone: a Messages inbox from the Thompsons and friends, per level.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(progressProvider);
    final ctrl = ref.read(progressProvider.notifier);
    final ts = ref.watch(messagesProvider).value, topics = ref.watch(grammarProvider).value, content = ref.watch(contentProvider).value;
    if (ts == null || topics == null || content == null) return const NavLoading();
    final gate = ThreadGate(ctrl, content, topics, ts, unlockAll: ref.read(progressProvider).gatesOpen);
    final pad = MediaQuery.paddingOf(context);
    final unread = ts.where((t) => gate.levelOpen(t.level) && !ctrl.threadDone(t.id)).length;
    return Scaffold(
      backgroundColor: phoneBg,
      body: ListView(
        key: const ValueKey('inbox-list'),
        padding: EdgeInsets.fromLTRB(16, pad.top + 6, 16, pad.bottom + 32),
        children: [
          const Row(
            children: [
              NavButtons(),
              SizedBox(width: 10),
              Icon(Icons.smartphone_rounded, size: 16, color: BL.muted),
              SizedBox(width: 4),
              Text(
                'YOUR PHONE',
                style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: BL.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Messages', style: BL.display(30)),
              const SizedBox(width: 10),
              if (unread > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Container(
                    key: const ValueKey('inbox-unread'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: bubbleMe, borderRadius: BorderRadius.circular(99)),
                    child: Text(
                      hl('$unread new'),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
          Text(
            hl('پیام‌ها · پیام صوتی و متنی از خانوادهٔ تامسون؛ گوش کن و جواب بده'),
            textDirection: helperDir,
            style: BL.fa(13, color: BL.muted),
          ),
          for (final lv in Library.levels)
            if (gate.of(lv.code).isNotEmpty) _Block(level: lv, ts: gate.of(lv.code), open: gate.levelOpen(lv.code)),
        ],
      ),
    );
  }
}

class _Block extends ConsumerWidget {
  final LibraryLevel level;
  final List<Thread> ts;
  final bool open;
  const _Block({required this.level, required this.ts, required this.open});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(progressProvider.notifier);
    return Padding(
      key: ValueKey('inbox-level-${level.code}'),
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: open ? bubbleMe : BL.muted.withValues(alpha: .5), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!open)
                      const Padding(
                        padding: EdgeInsets.only(right: 3),
                        child: Icon(Icons.lock_rounded, size: 12, color: Colors.white),
                      ),
                    Text(
                      hl(level.code),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: hl(level.name),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: hl(level.nameFa),
                        style: BL.fa(13, color: BL.muted),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                hl(open ? '${ts.where((t) => ctrl.threadDone(t.id)).length}/${ts.length}' : 'Locked · قفل'),
                key: ValueKey('inbox-status-${level.code}'),
                style: const TextStyle(color: BL.muted, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < ts.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 70),
                  _Tile(
                    t: ts[i],
                    open: open,
                    done: ctrl.threadDone(ts[i].id),
                    onTap: () {
                      if (open) {
                        context.push('/messages/${ts[i].id}');
                      } else {
                        final (en, fa) = ThreadGate.why(level.code);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 4),
                              content: Text(hl('$en\n$fa'), key: const ValueKey('inbox-locked-snack')),
                            ),
                          );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Thread t;
  final bool open, done;
  final VoidCallback onTap;
  const _Tile({required this.t, required this.open, required this.done, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final l = t.last;
    return InkWell(
      key: ValueKey('thread-${t.id}'),
      onTap: onTap,
      child: Opacity(
        opacity: open ? 1 : .45,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              CircleAvatar(radius: 24, backgroundColor: BL.mist, backgroundImage: AssetImage(t.avatar)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hl(t.fromName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: done ? FontWeight.w600 : FontWeight.w900, fontSize: 15.5),
                          ),
                        ),
                        Text(
                          hl(t.time),
                          style: TextStyle(fontSize: 12, color: done || !open ? BL.muted : bubbleMe, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (!open)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.lock_rounded, size: 14, color: BL.muted),
                          ),
                        if (open && l.isVoice)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.mic_rounded, size: 15, color: BL.muted),
                          ),
                        Expanded(
                          child: Text(
                            hl(open ? (l.isVoice ? 'Voice message · ${l.duration}' : l.en) : t.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, color: BL.muted),
                          ),
                        ),
                        if (done)
                          Icon(Icons.done_all_rounded, key: ValueKey('thread-done-${t.id}'), size: 18, color: bubbleMe)
                        else if (open)
                          Container(
                            key: ValueKey('thread-unread-${t.id}'),
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(color: bubbleMe, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
