import 'package:flutter/painting.dart';

enum GrowthStage { baby, child, teen, adult }

class Character {
  final String id, name, role, roleFa, accent, avatar, bio, bioFa;
  final int age;
  final GrowthStage growthStage;
  final Color color;
  final String? starterScene;
  final bool family;

  /// Baseline mood (Sec 9) — live mood lives in UserProgress.moodMap.
  final String mood;

  const Character({
    required this.id,
    required this.name,
    required this.role,
    required this.roleFa,
    required this.age,
    required this.growthStage,
    required this.accent,
    required this.color,
    required this.avatar,
    required this.bio,
    required this.bioFa,
    this.starterScene,
    this.family = true,
    this.mood = 'neutral',
  });

  Character copyWithName(String n) => Character(id: id, name: n, role: role, roleFa: roleFa, age: age, growthStage: growthStage, accent: accent, color: color, avatar: avatar, bio: bio, bioFa: bioFa, starterScene: starterScene, family: family, mood: mood);

  factory Character.fromJson(Map<String, dynamic> j) => Character(
    id: j['id'],
    name: j['name'],
    role: j['role'],
    roleFa: j['roleFa'],
    age: j['age'],
    growthStage: GrowthStage.values.byName(j['growthStage']),
    accent: j['accent'],
    color: Color(int.parse((j['color'] as String).substring(1), radix: 16) | 0xFF000000),
    avatar: j['avatar'],
    bio: j['bio'],
    bioFa: j['bioFa'],
    starterScene: j['starterScene'],
    family: j['family'] ?? true,
    mood: j['mood'] ?? 'neutral',
  );
}
