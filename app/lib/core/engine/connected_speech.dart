import '../models/dialogue_node.dart';

/// Connected Speech X-Ray: formal sentence → British connected speech + broad IPA.
/// Authored X-Rays win; otherwise rules (contractions, wanna/gonna, cuppa, glottal T) generate one.
class ConnectedSpeech {
  static const _phrases = <String, String>{
    'do you want to have a cup of tea': "d'you wanna cuppa",
    'do you want a cup of tea': "d'you wanna cuppa",
    'a cup of tea': 'a cuppa',
    'cup of tea': 'cuppa',
    'do you want to': "d'you wanna",
    'do you want': "d'you want",
    'want to': 'wanna',
    'going to': 'gonna',
    'got to': 'gotta',
    'have got to': "'ve gotta",
    'what are you': 'wotcha',
    'what do you': 'whaddya',
    'did you': 'didja',
    'would you': 'wouldja',
    'could you': 'couldja',
    "don't know": 'dunno',
    'do not know': 'dunno',
    'let me': 'lemme',
    'give me': 'gimme',
    'kind of': 'kinda',
    'out of': 'outta',
    'a lot of': 'a lotta',
    'sort of': 'sorta',
    'do you': "d'you",
    'i am': "I'm",
    'it is': "it's",
    'that is': "that's",
    'there is': "there's",
    'you are': "you're",
    'we are': "we're",
    'they are': "they're",
    'do not': "don't",
    'does not': "doesn't",
    'is not': "isn't",
    'cannot': "can't",
    'will not': "won't",
    'i would': "I'd",
    'i will': "I'll",
    'would have': "would've",
    'should have': "should've",
    'fish and chips': "fish 'n' chips",
  };

  static const _glottal = {'water': "wa'er", 'bottle': "bo'le", 'little': "li'le", 'butter': "bu'er", 'better': "be'er", 'get': "ge'", 'got': "go'", 'lot': "lo'", 'bit': "bi'", 'what': "wha'", 'right': "righ'", 'alright': "alrigh'", 'not': "no'", 'it': "i'", 'that': "tha'", 'quite': "quí'"};

  static const ipa = <String, String>{
    'a': 'ə', 'the': 'ðə', 'you': 'juː', "d'you": 'djə', 'wanna': 'ˈwɒnə', 'gonna': 'ˈɡɒnə', 'gotta': 'ˈɡɒtə', 'cuppa': 'ˈkʌpə', 'tea': 'tiː',
    'have': 'hæv', 'to': 'tə', 'of': 'əv', 'and': 'ən', "'n'": 'n', 'is': 'ɪz', 'it': 'ɪt', "i'": 'ɪʔ', "it's": 'ɪts', 'i': 'aɪ', "i'm": 'aɪm', "i'd": 'aɪd', "i'll": 'aɪl',
    'do': 'duː', "don't": 'dəʊnt', 'can': 'kən', "can't": 'kɑːnt', 'could': 'kʊd', 'would': 'wʊd', 'please': 'pliːz', 'cheers': 'tʃɪəz', 'lovely': 'ˈlʌvli',
    'morning': 'ˈmɔːnɪŋ', 'want': 'wɒnt', 'like': 'laɪk', 'love': 'lʌv', 'mate': 'meɪt', 'right': 'raɪt', "righ'": 'raɪʔ', 'alright': 'ɔːlˈraɪt', "alrigh'": 'ɔːlˈraɪʔ',
    'water': 'ˈwɔːtə', "wa'er": 'ˈwɔːʔə', 'butter': 'ˈbʌtə', "bu'er": 'ˈbʌʔə', 'bottle': 'ˈbɒtl', "bo'le": 'ˈbɒʔl', 'little': 'ˈlɪtl', "li'le": 'ˈlɪʔl',
    'better': 'ˈbetə', "be'er": 'ˈbeʔə', 'what': 'wɒt', "wha'": 'wɒʔ', 'get': 'ɡet', "ge'": 'ɡeʔ', 'got': 'ɡɒt', "go'": 'ɡɒʔ', 'not': 'nɒt', "no'": 'nɒʔ', 'bit': 'bɪt', "bi'": 'bɪʔ',
    'that': 'ðæt', "tha'": 'ðæʔ', "that's": 'ðæts', 'there': 'ðeə', "there's": 'ðeəz', 'here': 'hɪə', 'go': 'ɡəʊ', 'no': 'nəʊ', 'yes': 'jes', 'yeah': 'jeə',
    'thanks': 'θæŋks', 'thank': 'θæŋk', 'sorry': 'ˈsɒri', 'rain': 'reɪn', 'raining': 'ˈreɪnɪŋ', 'pouring': 'ˈpɔːrɪŋ', 'down': 'daʊn', 'chilly': 'ˈtʃɪli', 'drizzle': 'ˈdrɪzl', 'drizzling': 'ˈdrɪzlɪŋ',
    'bus': 'bʌs', 'school': 'skuːl', 'mum': 'mʌm', 'dad': 'dæd', 'jam': 'dʒæm', 'toast': 'təʊst', 'bread': 'bred', 'loaf': 'ləʊf', 'scone': 'skɒn', 'pipe': 'paɪp', 'leak': 'liːk',
    'with': 'wɪð', 'for': 'fə', 'me': 'mi', 'my': 'maɪ', 'your': 'jɔː', 'we': 'wi', 'they': 'ðeɪ', 'are': 'ə', 'was': 'wəz', 'be': 'bi', 'in': 'ɪn', 'on': 'ɒn', 'at': 'ət', 'off': 'ɒf',
    'how': 'haʊ', 'where': 'weə', 'when': 'wen', 'why': 'waɪ', 'who': 'huː', 'one': 'wʌn', 'two': 'tuː', 'some': 'sʌm', 'any': 'ˈeni', 'just': 'dʒʌst', 'now': 'naʊ', 'then': 'ðen',
    'good': 'ɡʊd', 'nice': 'naɪs', 'day': 'deɪ', 'time': 'taɪm', 'home': 'həʊm', 'kettle': 'ˈketl', 'brew': 'bruː', 'sure': 'ʃɔː', 'course': 'kɔːs', 'fancy': 'ˈfænsi', 'mind': 'maɪnd',
    'lemme': 'ˈlemi', 'gimme': 'ˈɡɪmi', 'dunno': 'dəˈnəʊ', 'kinda': 'ˈkaɪndə', 'wotcha': 'ˈwɒtʃə', 'didja': 'ˈdɪdʒə', 'wouldja': 'ˈwʊdʒə', 'couldja': 'ˈkʊdʒə', 'innit': 'ˈɪnɪt',
  };

  static String connected(String formal) {
    var s = ' ${formal.toLowerCase().replaceAll('’', "'")} ';
    final keys = _phrases.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      s = s.replaceAll(RegExp('(?<=[^a-z\'])${RegExp.escape(k)}(?=[^a-z\'])'), _phrases[k]!);
    }
    s = s.replaceAllMapped(RegExp(r"(?<=[^a-z'])([a-z]+)(?=[\s,.!?]+[aeiou])"), (m) => _glottal[m[1]] ?? m[1]!);
    s = s.trim();
    s = s.replaceAll(RegExp(r'\bi\b'), 'I');
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  /// Broad, approximate IPA: known words from the dictionary; unknown words are shown in angle brackets.
  static String toIpa(String s) {
    final words = s.toLowerCase().replaceAll(RegExp(r"[^a-z' ]"), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return '/${words.map((w) => ipa[w] ?? ipa[w.replaceAll("'", '')] ?? '‹$w›').join(' ')}/';
  }

  static XRay of(DialogueNode n) {
    if (n.xray != null) return n.xray!;
    final c = connected(n.text);
    return XRay(n.text, c, toIpa(c));
  }
}
