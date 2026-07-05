import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import '../core/services/app_service.dart';
import '../core/persistence/database.dart';
import 'shell.dart';

class BlanApp extends ConsumerWidget {
  const BlanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'B-LAN',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}

class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key, required this.database});

  final AppDatabase database;

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap>
    with WidgetsBindingObserver {
  AppService? _service;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _service?.onAppResumed();
    }
  }

  Future<void> _start() async {
    try {
      final service = AppService(widget.database);
      await service.initialize();
      if (!mounted) {
        return;
      }
      setState(() => _service = service);
    } catch (error) {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Failed to start B-LAN: $_error')),
        ),
      );
    }
    if (_service == null) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(widget.database),
        appServiceProvider.overrideWithValue(_service!),
      ],
      child: const BlanApp(),
    );
  }
}
