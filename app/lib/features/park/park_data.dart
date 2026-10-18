import 'dart:math';

import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../../core/models/dialogue_node.dart';
import '../grammar/grammar_data.dart';
import '../grammar/school_screen.dart';
import '../library/library_data.dart';

/// Park games: quick, replayable vocabulary and listening games. Words come from the course lessons the
/// learner has opened at that level (topped up with the level's next lessons when there aren't enough yet).
class ParkGame {
  final String id, name, nameFa, blurb, blurbFa;
  const ParkGame(this.id, this.name, this.nameFa, this.blurb, this.blurbFa);
}

/// An odd-one-out set: three that belong together, one that doesn't, and why.
class OddSet {
  final List<String> same;
  final String odd, why, whyFa;
  const OddSet(this.same, this.odd, this.why, this.whyFa);
}

class Park {
  static const pass = 60;
  static const games = [
    ParkGame('match', 'Word match', 'جفت کردن کلمه‌ها', 'Match words to Persian against the clock', 'کلمه‌ها را قبل از تمام شدن وقت با فارسی جفت کن'),
    ParkGame('listen', 'Listen & tap', 'گوش کن و بزن', 'Hear a British voice, tap the word', 'صدای بریتانیایی را بشنو و کلمه را بزن'),
    ParkGame('spell', 'Spelling bee', 'مسابقهٔ املا', 'Hear it, spell it the British way', 'بشنو و به املای بریتانیایی بنویس'),
    ParkGame('odd', 'Odd one out', 'کدام فرق دارد؟', 'Spot the word that doesn\'t belong', 'کلمه‌ای را که به بقیه نمی‌خورد پیدا کن'),
    ParkGame('build', 'Phrase builder', 'جمله‌سازی', 'Put the words in order', 'کلمه‌ها را به ترتیب بچین'),
  ];
  static ParkGame? game(String id) => games.where((g) => g.id == id).firstOrNull;
  static const matchPairs = 6, matchSeconds = 60, listenRounds = 8, spellRounds = 6, oddRounds = 4, buildRounds = 5;

  /// Course level (1–5) for a CEFR band.
  static int courseLevel(String code) => const {'A1': 1, 'A2': 2, 'B1': 3, 'B2': 4, 'C1': 5}[code] ?? 1;

  /// British spellings and words, with the American version learners often see online.
  static const us = {
    'colour': 'color',
    'favourite': 'favorite',
    'neighbour': 'neighbor',
    'theatre': 'theater',
    'cheque': 'check',
    'kerb': 'curb',
    'cancelled': 'canceled',
    'licence': 'license',
    'grey': 'gray',
    'pyjamas': 'pajamas',
    'honour': 'honor',
    'flavour': 'flavor',
    'humour': 'humor',
    'realise': 'realize',
    'recognise': 'recognize',
    'apologise': 'apologize',
    'mum': 'mom',
    'maths': 'math',
    'autumn': 'fall',
    'biscuit': 'cookie',
    'trainers': 'sneakers',
    'rubbish': 'trash',
    'flat': 'apartment',
    'lift': 'elevator',
    'holiday': 'vacation',
    'nappy': 'diaper',
    'pushchair': 'stroller',
    'pavement': 'sidewalk',
    'postcode': 'zip code',
    'favour': 'favor',
    'harbour': 'harbor',
    'sceptical': 'skeptical',
    'anaesthetic': 'anesthetic',
    'mould': 'mold',
    'queue': 'line',
    'centre': 'center',
    'organise': 'organize',
    'programme': 'program',
    'tyre': 'tire',
    'jewellery': 'jewelry',
    'travelling': 'traveling',
    'behaviour': 'behavior',
  };

  /// Hand-made odd-one-out sets per level (British everyday words).
  static const odd = {
    'A1': [
      OddSet(['apple', 'banana', 'orange'], 'bus', 'A bus isn\'t a fruit.', 'اتوبوس میوه نیست.'),
      OddSet(['mum', 'dad', 'nan'], 'teacher', 'The others are family.', 'بقیه اعضای خانواده‌اند.'),
      OddSet(['red', 'blue', 'green'], 'Monday', 'The others are colours.', 'بقیه رنگ‌اند.'),
      OddSet(['tea', 'coffee', 'juice'], 'sandwich', 'You eat a sandwich; you drink the others.', 'ساندویچ را می‌خوری؛ بقیه را می‌نوشی.'),
      OddSet(['hiya', 'hello', 'morning'], 'bye', 'The others are greetings; "bye" ends a chat.', 'بقیه سلام‌اند؛ «بای» برای خداحافظی است.'),
    ],
    'A2': [
      OddSet(['train', 'bus', 'Tube'], 'ticket', 'You travel on the others; a ticket lets you.', 'با بقیه سفر می‌کنی؛ بلیت فقط اجازهٔ سفر است.'),
      OddSet(['chemist', 'bakery', 'butcher'], 'pavement', 'The others are shops.', 'بقیه مغازه‌اند.'),
      OddSet(['sunny', 'rainy', 'windy'], 'Tuesday', 'The others describe the weather.', 'بقیه هوا را توصیف می‌کنند.'),
      OddSet(['jumper', 'trousers', 'trainers'], 'biscuit', 'The others are clothes.', 'بقیه لباس‌اند.'),
      OddSet(['queue', 'platform', 'timetable'], 'kettle', 'The others are at a station; a kettle is in the kitchen.', 'بقیه در ایستگاه‌اند؛ کتری در آشپزخانه است.'),
    ],
    'B1': [
      OddSet(['GP', 'surgery', 'prescription'], 'mortgage', 'The others are about health.', 'بقیه دربارهٔ سلامت‌اند.'),
      OddSet(['rent', 'landlord', 'deposit'], 'symptom', 'The others are about renting a home.', 'بقیه دربارهٔ اجارهٔ خانه‌اند.'),
      OddSet(['crisps', 'biscuits', 'sweets'], 'quid', 'A quid is a pound; the others are snacks.', '«کوئید» یعنی یک پوند؛ بقیه خوراکی‌اند.'),
      OddSet(['knackered', 'shattered', 'exhausted'], 'chuffed', 'Chuffed means pleased; the others mean very tired.', '«چافد» یعنی خوشحال؛ بقیه یعنی خیلی خسته.'),
    ],
    'B2': [
      OddSet(['chuffed', 'over the moon', 'made up'], 'gutted', 'Gutted means very disappointed; the others mean happy.', '«گاتد» یعنی خیلی ناامید؛ بقیه یعنی خوشحال.'),
      OddSet(['council tax', 'payslip', 'P60'], 'fortnight', 'A fortnight is two weeks; the others are money paperwork.', '«فورتنایت» یعنی دو هفته؛ بقیه کاغذبازیِ مالی‌اند.'),
      OddSet(['motorway', 'roundabout', 'lay-by'], 'allotment', 'An allotment is a garden plot; the others are on the road.', '«الاتمنت» قطعه‌زمینی برای باغچه است؛ بقیه مربوط به جاده‌اند.'),
      OddSet(['brolly', 'wellies', 'mac'], 'telly', 'Telly is the TV; the others are for the rain.', '«تلی» یعنی تلویزیون؛ بقیه برای باران‌اند.'),
    ],
    'C1': [
      OddSet(['reckon', 'suppose', 'gather'], 'flog', 'To flog is to sell; the others mean think or understand.', '«فلاگ» یعنی فروختن؛ بقیه یعنی فکر کردن یا فهمیدن.'),
      OddSet(['gobsmacked', 'flabbergasted', 'astonished'], 'peckish', 'Peckish means a bit hungry; the others mean very surprised.', '«پکیش» یعنی کمی گرسنه؛ بقیه یعنی خیلی متعجب.'),
      OddSet(['dodgy', 'iffy', 'suspect'], 'spot on', 'Spot on means exactly right; the others mean doubtful.', '«اسپات آن» یعنی کاملاً درست؛ بقیه یعنی مشکوک.'),
      OddSet(['whinge', 'moan', 'grumble'], 'natter', 'To natter is to chat happily; the others mean complain.', '«نتر» یعنی گپ زدن؛ بقیه یعنی غر زدن.'),
    ],
  };
}

/// The words a learner reviews at a level: from opened lessons first, then the level's next lessons.
class ParkWords {
  final List<NewWord> words, phrases;
  final int fromOpen;
  const ParkWords(this.words, this.fromOpen, [this.phrases = const []]);

  static bool _isPhrase(String w) => w.split(' ').length >= 3 && w.split(' ').length <= 8;

  static ParkWords of(ProgressController ctrl, Course c, String code, {int min = 24, int minPhrases = 8}) {
    final lv = Park.courseLevel(code);
    final lessons = c.units.where((u) => u.level == lv).expand((u) => u.lessons).toList();
    final open = lessons.where((l) => ctrl.lessonOpen(c, l)).toList();
    List<NewWord> pick(bool Function(NewWord) keep, int atLeast, void Function(int) opened) {
      final seen = <String>{}, out = <NewWord>[];
      void add(Lesson l) {
        for (final w in l.words) {
          if (w.fa.trim().isNotEmpty && keep(w) && seen.add(w.word.toLowerCase())) out.add(w);
        }
      }

      open.forEach(add);
      opened(out.length);
      for (final l in lessons) {
        if (out.length >= atLeast) break;
        add(l);
      }
      return out;
    }

    var n = 0;
    final words = pick((_) => true, min, (k) => n = k);
    final phrases = pick((w) => _isPhrase(w.word), minPhrases, (_) {});
    return ParkWords(words, n, phrases);
  }

  static bool single(String w) => RegExp(r"^[A-Za-z]{3,12}$").hasMatch(w);
  List<NewWord> get singles => words.where((w) => single(w.word)).toList();
}

/// Builds the rounds for a game (a seeded shuffle so each play differs).
class ParkRounds {
  /// Word match: [Park.matchPairs] words.
  static List<NewWord> match(List<NewWord> pool, Random r) => (pool.toList()..shuffle(r)).take(Park.matchPairs).toList();

  /// Listen & tap: each round is a target plus 3 different distractors.
  static List<(NewWord, List<String>)> listen(List<NewWord> pool, Random r) {
    final ws = pool.where((w) => w.word.length <= 22).toList()..shuffle(r);
    return [
      for (final w in ws.take(Park.listenRounds)) (w, ([w.word, ...(ws.where((x) => x.word.toLowerCase() != w.word.toLowerCase()).toList()..shuffle(r)).take(3).map((x) => x.word)]..shuffle(r))),
    ];
  }

  /// Spelling bee: British spellings first, then other single words.
  static List<NewWord> spell(ParkWords pw, Random r) {
    final s = pw.singles..shuffle(r);
    final brit = s.where((w) => Park.us.containsKey(w.word.toLowerCase())).toList();
    return [...brit, ...s.where((w) => !brit.contains(w) && w.word.length >= 4)].take(Park.spellRounds).toList();
  }

  static List<OddSet> odd(String code, Random r) => (List<OddSet>.of(Park.odd[code] ?? const [])..shuffle(r)).take(Park.oddRounds).toList();

  static List<NewWord> build(ParkWords pw, Random r) => (pw.phrases.toList()..shuffle(r)).take(Park.buildRounds).toList();
}

/// Which park levels are open: the same rule as every other section.
class ParkGate {
  final ProgressController ctrl;
  final GrammarGate grammar;
  ParkGate(this.ctrl, ContentBundle? content, List<GTopic> topics, {bool unlockAll = false}) : grammar = GrammarGate(ctrl, content, topics, unlockAll: unlockAll);

  bool levelOpen(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    if (i <= 0 || grammar.unlockAll) return true;
    final prev = Library.levels[i - 1].code;
    if (Park.games.every((g) => ctrl.parkCleared(prev, g.id))) return true;
    if (Park.games.any((g) => ctrl.parkBest(code, g.id) != null)) return true;
    return grammar.classOpen(code);
  }

  static (String, String) why(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    final prev = i > 0 ? Library.levels[i - 1].code : 'A1';
    final lv = Grammar.courseLevel(code);
    return (
      '$code games open at Level $lv of the course, when you pass Grammar Class $prev, or when you score 60% in every $prev game.',
      'بازی‌های $code در سطح $lv دوره، با قبولی در کلاس گرامر $prev یا با گرفتن ۶۰٪ در همهٔ بازی‌های $prev باز می‌شوند.',
    );
  }
}
