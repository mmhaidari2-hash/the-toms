/// Speech speed + line length by CEFR level (Sec 7.4 & level table) and the character linguistic matrix.
class LevelProfile {
  final String level;
  final int maxChars; // authoring budget per character line
  final double slow, medium, normal; // TTS rates for the three per-line speeds
  const LevelProfile(this.level, this.maxChars, this.slow, this.medium, this.normal);

  static const all = {
    'A0': LevelProfile('A0', 90, .28, .36, .46),
    'A1': LevelProfile('A1', 110, .30, .40, .50),
    'A2': LevelProfile('A2', 150, .32, .44, .53),
    'B1': LevelProfile('B1', 170, .34, .48, .56),
    'B2': LevelProfile('B2', 200, .36, .52, .58),
    'C1': LevelProfile('C1', 240, .38, .55, .60),
    'C2': LevelProfile('C2', 280, .40, .58, .62),
  };
  static LevelProfile of(String l) => all[l] ?? all['A1']!;
  double rate(Speed s) => [slow, medium, normal][s.index];
}

enum Speed { slow, medium, normal }

/// Who speaks how (Sec 6 linguistic matrix). Used for authoring checks and the in-app character card.
class VoiceProfile {
  final String band, style;
  final List<String> markers; // features the character's lines should show
  final int maxWords;
  const VoiceProfile(this.band, this.style, this.markers, this.maxWords);
  static const matrix = {
    'nicola': VoiceProfile('A1–A2', 'Short, simple sentences', [], 14),
    'leslie': VoiceProfile('A2–B1', 'Polite requests, table manners', ['please', 'would you', 'could you', 'mind', 'lovely'], 30),
    'ryan': VoiceProfile('B1–B2', "Slang + contractions (Alright?, mate, knackered)", ["'", 'mate', 'alright', 'knackered', 'like'], 30),
    'tom': VoiceProfile('B2–C1', 'Idioms and dry wit', ["'", 'right', 'eh', 'mind you', 'proper', 'sorted'], 40),
    'william': VoiceProfile('Pre-A1', 'Short simple sentences (age 3–6) & surprise events', [], 8),
  };
}
