import '../models/user_progress.dart';

/// Daily mission (Sec 7.2): one concrete goal a day, deterministic from the date (offline).
class Mission {
  final String id, en, fa;
  final List<String> sceneIds; // finishing any of these counts…
  final bool clean; // …with zero recasts/misses
  const Mission(this.id, this.en, this.fa, this.sceneIds, {this.clean = false});
}

class Missions {
  static const all = [
    Mission('shop_clean', 'Shop at the supermarket with no mistakes', 'بدون هیچ اشتباهی از سوپرمارکت خرید کن', ['priya_till'], clean: true),
    Mission('table_polite', 'Get through the Morning Table without a single recast', 'میز صبحانه را بدون حتی یک اصلاح تمام کن', ['ep1_morning_table'], clean: true),
    Mission('bakery', 'Order at the bakery and the butcher', 'از نانوایی و قصابی سفارش بده', ['ep3_high_street']),
    Mission('plumber', 'Book the plumber on the phone', 'با تلفن لوله‌کش را رزرو کن', ['ep4_evening_tea']),
    Mission('rain', 'Get Tom & Ryan out of the door in the rain', 'تام و رایان را زیر باران از خانه بیرون بفرست', ['ep2_muddy_hallway']),
    Mission('coffee_clean', 'Order a coffee perfectly', 'یک قهوه بی‌نقص سفارش بده', ['callum_coffee'], clean: true),
    Mission('bus', 'Ride the 38 with Tom', 'با تام سوار اتوبوس ۳۸ شو', ['tom_bus', 'doris_bus']),
  ];
  static String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
  static Mission today(DateTime d) => all[DateTime(d.year, d.month, d.day).difference(DateTime(2026)).inDays % all.length];
  static bool done(UserProgress p, DateTime d) => p.missionsDone[dayKey(d)] == today(d).id;
  static bool satisfies(Mission m, String sceneId, int slips) => m.sceneIds.contains(sceneId) && (!m.clean || slips == 0);
}
