import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the persistent Voice POS database file.
///
/// Location: the app's documents directory (`voice_pos.sqlite`), which
/// survives app restarts, app upgrades, and normal Android lifecycle events.
/// Never temp/cache storage.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'voice_pos.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
