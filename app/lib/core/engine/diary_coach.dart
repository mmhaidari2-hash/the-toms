import 'dart:math';

import '../models/character.dart';

class DiaryFeedback {
  final int words;
  final List<String> vocabUsed, tips;
  final String reactorId, reaction, reactionFa;
  const DiaryFeedback(this.words, this.vocabUsed, this.tips, this.reactorId, this.reaction, this.reactionFa);
}

/// Offline coach for diary entries the learner WRITES (Sec 7.7): checks, vocab credit and an in-character reaction.
class DiaryCoach {
  static const _topics = <String, List<String>>{
    'tom': ['bus', 'tea', 'cuppa', 'driving', 'work', 'football'],
    'leslie': ['school', 'cook', 'dinner', 'shopping', 'garden', 'please'],
    'nicola': ['teddy', 'play', 'park', 'birthday', 'unicorn', 'friend'],
    'ryan': ['game', 'school', 'mate', 'tired', 'knackered', 'music', 'phone'],
    'weda': ['rain', 'weather', 'garden', 'walk', 'baking'],
    'william': ['toast', 'jam', 'bath', 'ball'],
  };
  static const _reactions = <String, List<List<String>>>{
    'tom': [['Proper diary, that! You write better than I talk.', 'دفترچهٔ درست‌وحسابیه! بهتر از حرف زدن من می‌نویسی.'], ['Cracking entry. Put the kettle on and tell me more.', 'نوشتهٔ معرکه‌ای بود. کتری رو بذار و بیشتر بگو.']],
    'leslie': [['Oh, that is lovely. Thank you for sharing it with me.', 'وای، خیلی قشنگه. ممنون که با من درمیونش گذاشتی.'], ['Beautifully written — I might pin it on the fridge!', 'خیلی زیبا نوشتی — شاید بچسبونمش رو یخچال!']],
    'nicola': [['I can read that! Well, nearly. Teddy says it\'s brilliant.', 'من می‌تونم بخونمش! خب، تقریباً. خرسی می‌گه عالیه.']],
    'ryan': [['Not gonna lie, that\'s actually decent, mate.', 'دروغ نگم، واقعاً خوبه رفیق.']],
    'weda': [['You\'ve a way with words, pet. Mind you, so did I at your age.', 'با کلمات خوب بازی می‌کنی عزیزم. البته منم هم‌سن تو همین‌طور بودم.']],
    'william': [['Ooh! Pretty! *scribbles on it*', 'اوه! قشنگ! *روش خط‌خطی می‌کنه*']],
  };

  static DiaryFeedback review(String text, List<String> vocab, List<Character> family, Map<String, int> trust, {int seed = 0}) {
    final lower = text.toLowerCase();
    final words = RegExp(r"[a-zA-Z']+").allMatches(text).length;
    final used = [for (final v in vocab) if (RegExp('\\b${RegExp.escape(v.toLowerCase().replaceAll(RegExp(r'[?!]'), ''))}\\b').hasMatch(lower)) v];
    final tips = <String>[];
    if (text.trim().isNotEmpty && text.trim()[0] != text.trim()[0].toUpperCase()) tips.add('Start with a capital letter.');
    if (RegExp(r'(^|\s)i(\s|\x27)').hasMatch(text)) tips.add('“I” is always a capital letter in English.');
    if (!RegExp(r'[.!?]\s*$').hasMatch(text.trim())) tips.add('Finish with a full stop.');
    if (RegExp(r'\bi am agree\b', caseSensitive: false).hasMatch(text)) tips.add('Say “I agree”, not “I am agree”.');
    if (RegExp(r'\b(yesterday|last night)\b.*\b(go|eat|see|have)\b', caseSensitive: false).hasMatch(text)) tips.add('Talking about yesterday? Try the past: went / ate / saw / had.');
    if (words < 15) tips.add('Try 2–3 more sentences next time.');
    var best = 'leslie', bestScore = -1;
    for (final c in family.where((c) => _topics.containsKey(c.id))) {
      final s = _topics[c.id]!.where(lower.contains).length * 10 + (trust[c.id] ?? 0) ~/ 10;
      if (s > bestScore) {
        bestScore = s;
        best = c.id;
      }
    }
    final pool = _reactions[best]!;
    final r = pool[Random(seed + words).nextInt(pool.length)];
    return DiaryFeedback(words, used, tips, best, r[0], r[1]);
  }
}
