import 'dart:convert';

enum ProfileKind { adult, child }

/// One calm learner on this device. Progress (streaks, XP, lessons) is stored separately per profile.
class LearnerProfile {
  final String id, displayName;
  final ProfileKind kind;
  final DateTime createdAt;
  const LearnerProfile({required this.id, required this.displayName, required this.kind, required this.createdAt});

  bool get isChild => kind == ProfileKind.child;
  bool get isAdult => kind == ProfileKind.adult;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': displayName,
        'kind': kind.name,
        'at': createdAt.toIso8601String(),
      };

  factory LearnerProfile.fromJson(Map<String, dynamic> j) => LearnerProfile(
        id: j['id'] as String,
        displayName: (j['name'] as String?)?.trim().isNotEmpty == true ? (j['name'] as String).trim() : (j['kind'] == 'child' ? 'Child' : 'Me'),
        kind: j['kind'] == 'child' ? ProfileKind.child : ProfileKind.adult,
        createdAt: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Device-level calm circle: family challenge + optional study-buddy share code (no server).
class CalmCircle {
  final String week;
  final int goalXp;
  final String? myCode; // code we generated to share
  final String? buddyCode; // code we joined
  final String? buddyLabel;
  const CalmCircle({required this.week, this.goalXp = 50, this.myCode, this.buddyCode, this.buddyLabel});

  CalmCircle copyWith({String? week, int? goalXp, String? myCode, String? buddyCode, String? buddyLabel, bool clearBuddy = false}) => CalmCircle(
        week: week ?? this.week,
        goalXp: goalXp ?? this.goalXp,
        myCode: myCode ?? this.myCode,
        buddyCode: clearBuddy ? null : (buddyCode ?? this.buddyCode),
        buddyLabel: clearBuddy ? null : (buddyLabel ?? this.buddyLabel),
      );

  Map<String, dynamic> toJson() => {
        'week': week,
        'goal': goalXp,
        if (myCode != null) 'my': myCode,
        if (buddyCode != null) 'buddy': buddyCode,
        if (buddyLabel != null && buddyLabel!.isNotEmpty) 'label': buddyLabel,
      };

  factory CalmCircle.fromJson(Map<String, dynamic> j, String fallbackWeek) => CalmCircle(
        week: j['week'] as String? ?? fallbackWeek,
        goalXp: (j['goal'] as num?)?.toInt() ?? 50,
        myCode: j['my'] as String?,
        buddyCode: j['buddy'] as String?,
        buddyLabel: j['label'] as String?,
      );

  String encode() => jsonEncode(toJson());
  static CalmCircle decode(String? s, String week) {
    if (s == null || s.isEmpty) return CalmCircle(week: week);
    try {
      return CalmCircle.fromJson(jsonDecode(s) as Map<String, dynamic>, week);
    } catch (_) {
      return CalmCircle(week: week);
    }
  }
}

/// Routes hidden in kid-friendly mode (UK Children's Code: minimise data & adult bureaucracy practice).
const kidBlockedRoutes = <String>{
  '/forms',
  '/visa',
  '/settlement',
  '/premium',
  '/driving',
  '/theory',
  '/coach',
  '/arrival',
};

bool kidBlocks(String route) {
  final path = route.split('?').first;
  if (kidBlockedRoutes.contains(path)) return true;
  for (final b in kidBlockedRoutes) {
    if (path.startsWith('$b/')) return true;
  }
  return false;
}
