import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../grammar/grammar_data.dart';
import '../grammar/school_screen.dart';
import '../library/library_data.dart';

/// Family voice messages (assets/data/messages.json, built by tool/make_messages.py): texts and voice notes
/// from the Thompsons and friends. Listen, check, then reply by picking, typing or saying it.
class MsgItem {
  final String kind, sp, spName, en, fa;
  final int ms;
  const MsgItem(this.kind, this.sp, this.spName, this.en, this.fa, this.ms);
  bool get isVoice => kind == 'voice';
  String get duration => '0:${((ms / 1000).ceil()).toString().padLeft(2, '0')}';
}

class Gloss {
  final String term, en, fa;
  const Gloss(this.term, this.en, this.fa);
}

class Thread {
  final String id, level, from, fromName, avatar, title, titleFa, time;
  final List<MsgItem> msgs;
  final List<Gloss> gloss;
  final String q;
  final List<String> qOptions, replies;
  final String replyFa, say;
  const Thread({
    required this.id,
    required this.level,
    required this.from,
    required this.fromName,
    required this.avatar,
    required this.title,
    required this.titleFa,
    required this.time,
    required this.msgs,
    required this.gloss,
    required this.q,
    required this.qOptions,
    required this.replies,
    required this.replyFa,
    required this.say,
  });

  /// Correct option is index 0 in both the question and the replies (shuffled for display).
  String get bestReply => replies[0];
  MsgItem get last => msgs.last;
  factory Thread.fromJson(Map<String, dynamic> j) => Thread(
    id: j['id'],
    level: j['level'],
    from: j['from'],
    fromName: j['fromName'],
    avatar: j['avatar'],
    title: j['title'],
    titleFa: j['titleFa'],
    time: j['time'],
    msgs: [for (final m in j['msgs'] as List) MsgItem(m['kind'], m['sp'], m['spn'], m['en'], m['fa'], (m['ms'] as num?)?.toInt() ?? 0)],
    gloss: [for (final g in j['gloss'] as List) Gloss(g['term'], g['en'], g['fa'])],
    q: j['quiz']['q'],
    qOptions: List<String>.from(j['quiz']['options']),
    replies: List<String>.from(j['reply']['options']),
    replyFa: j['reply']['fa'],
    say: j['reply']['say'],
  );
}

class Messages {
  static List<Thread> parse(String raw) => [for (final t in (jsonDecode(raw) as Map)['threads'] as List) Thread.fromJson(t)];
  static const pass = 60;

  /// Score: the quick check (40 if right first time) + the reply (60 picked first time / typed or said well).
  static int score({required bool qFirst, required int reply}) => (qFirst ? 40 : 0) + reply;
}

final messagesProvider = FutureProvider<List<Thread>>((ref) async => Messages.parse(await rootBundle.loadString('assets/data/messages.json')));

/// Which message levels are open. Same rule as the Library, Cinema, Radio, Missions and Grammar School.
class ThreadGate {
  final ProgressController ctrl;
  final GrammarGate grammar;
  final List<Thread> threads;
  ThreadGate(this.ctrl, ContentBundle? content, List<GTopic> topics, this.threads, {bool unlockAll = false}) : grammar = GrammarGate(ctrl, content, topics, unlockAll: unlockAll);

  List<Thread> of(String code) => threads.where((t) => t.level == code).toList();

  bool levelOpen(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    if (i <= 0 || grammar.unlockAll) return true;
    final prev = of(Library.levels[i - 1].code);
    if (prev.isNotEmpty && prev.every((t) => ctrl.threadDone(t.id))) return true;
    if (of(code).any((t) => ctrl.threadScore(t.id) != null)) return true;
    return grammar.classOpen(code);
  }

  static (String, String) why(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    final prev = i > 0 ? Library.levels[i - 1].code : 'A1';
    final lv = Grammar.courseLevel(code);
    return (
      '$code messages arrive at Level $lv of the course, when you pass Grammar Class $prev, or when you answer the $prev messages.',
      'پیام‌های $code در سطح $lv دوره، با قبولی در کلاس گرامر $prev یا با جواب دادن به پیام‌های $prev می‌رسند.',
    );
  }
}
