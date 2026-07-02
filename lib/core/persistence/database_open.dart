import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';

/// Production database opener (Flutter / path_provider).
Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationSupportDirectory();
  final dbPath = p.join(dir.path, 'blan.db');
  return AppDatabase(
    driftDatabase(name: dbPath),
  );
}
