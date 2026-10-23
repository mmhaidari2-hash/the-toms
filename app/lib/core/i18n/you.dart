/// The learner's name in authored lines ({you}). With a name, it's shown; without one,
/// lines read naturally with no name (vocatives dropped, other mentions -> "our neighbour"). The recorded audio
/// always uses the no-name form (tool/you_neutral.py mirrors these rules).
final _n = r"\{you\}";
const _greet = r'(Hi|Hello|Hiya|Morning|Evening|Thanks|Thank you|Cheers|Night|Bye|Welcome|Oi|Ta|Well done|Come on|Sorry|Lovely|Right|Hey|Oh)';
final _start = r'''(^|(?<=[.!?…]\s)|(?<=["“]))''';

String youNeutral(String t) {
  t = t.replaceAllMapped(RegExp("\\bI'm $_n(?!['\\w])"), (_) => "I'm your new neighbour");
  t = t.replaceAllMapped(RegExp("\\bIt's $_n(?!['\\w])"), (_) => "It's me");
  t = t.replaceAllMapped(RegExp("\\bThis is $_n(?!['\\w])"), (_) => 'This is your neighbour');
  t = t.replaceAll(RegExp(',\\s*$_n(?=\\s*[!?.,;:—–)"”]|\$)'), '');
  t = t.replaceAllMapped(RegExp('$_start$_n\\s*[,!]\\s*'), (m) => m[1] ?? '');
  t = t.replaceAllMapped(RegExp('\\b$_greet\\s+$_n(?![\'\\w])'), (m) => m[1]!);
  t = t.replaceAll(RegExp('\\s+$_n(?=[!?.])'), '');
  t = t.replaceAll(RegExp("$_n's"), "our neighbour's");
  t = t.replaceAllMapped(RegExp('$_start$_n'), (m) => '${m[1]}Our neighbour');
  t = t.replaceAll(RegExp(_n), 'our neighbour');
  return t.replaceAllMapped(RegExp('$_start([a-z])'), (m) => '${m[1]}${m[2]!.toUpperCase()}');
}

/// Shown line -> authored line, so a clip (keyed by the authored text) is still found for a filled-in line.
final youRawOf = <String, String>{};

/// English line with the learner's [name] (or the no-name form when it's empty).
String fillYou(String t, String name) {
  if (!t.contains('{you}')) return t;
  final n = name.trim();
  final out = n.isEmpty ? youNeutral(t) : t.replaceAll('{you}', n);
  youRawOf[out] = t;
  return out;
}

/// Persian line: the name, or none.
String fillYouFa(String t, String name) {
  if (!t.contains('{you}')) return t;
  final n = name.trim();
  if (n.isNotEmpty) return t.replaceAll('{you}', n);
  return t.replaceAll(RegExp(r'[،,]\s*\{you\}'), '').replaceAll(RegExp(r'\{you\}'), 'همسایه‌مان');
}
