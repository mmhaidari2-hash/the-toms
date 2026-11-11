import 'dart:io';

Future<bool> progressHiveHasBytes(String directory, String boxName) async {
  final file = File('$directory/$boxName.hive');
  return file.existsSync() && file.lengthSync() > 0;
}

Future<bool> progressHiveKeptExists(String directory, String boxName) async {
  return File('$directory/$boxName.hive.kept').existsSync();
}

Future<void> progressHiveCopyToKept(String directory, String boxName) async {
  final src = File('$directory/$boxName.hive');
  if (!src.existsSync()) return;
  await src.copy('$directory/$boxName.hive.kept');
}

Future<void> progressHiveRestoreKept(String directory, String boxName) async {
  final kept = File('$directory/$boxName.hive.kept');
  if (!kept.existsSync()) return;
  await kept.copy('$directory/$boxName.hive');
}

Future<void> progressHiveDeleteKept(String directory, String boxName) async {
  final kept = File('$directory/$boxName.hive.kept');
  if (kept.existsSync()) await kept.delete();
}

Future<void> progressHiveCopyKeptAsBox(String directory, String boxName, String sideBox) async {
  final kept = File('$directory/$boxName.hive.kept');
  await kept.copy('$directory/$sideBox.hive');
}
