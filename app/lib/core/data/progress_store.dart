import 'package:hive_flutter/hive_flutter.dart';

abstract class ProgressStore {
  String? read();
  Future<void> write(String data);
  Future<void> clear();
}

class HiveProgressStore implements ProgressStore {
  static const _boxName = 'progress', _key = 'v1';
  final Box<String> box;
  HiveProgressStore(this.box);
  static Future<HiveProgressStore> open() async {
    await Hive.initFlutter();
    return HiveProgressStore(await Hive.openBox<String>(_boxName));
  }

  @override
  String? read() => box.get(_key);
  @override
  Future<void> write(String data) => box.put(_key, data);
  @override
  Future<void> clear() => box.delete(_key);
}

class MemoryProgressStore implements ProgressStore {
  String? data;
  @override
  String? read() => data;
  @override
  Future<void> write(String d) async => data = d;
  @override
  Future<void> clear() async => data = null;
}
