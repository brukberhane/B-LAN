import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'app/app.dart';
import 'core/persistence/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _configureLogging();
  final database = await AppDatabase.open();
  runApp(AppBootstrap(database: database));
}

void _configureLogging() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    debugPrint('[${record.loggerName}] ${record.message}');
  });
}
