import 'package:blan/app/providers.dart';
import 'package:blan/app/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App shell renders navigation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharesProvider.overrideWith((ref) => Stream.value([])),
          peersProvider.overrideWith((ref) => Stream.value([])),
          downloadsProvider.overrideWith((ref) => Stream.value([])),
          downloadsDirectoryProvider.overrideWith(
            (ref) async => '/tmp/blan-downloads',
          ),
          serverRunningProvider.overrideWithValue(false),
          discoveryAdvertisingProvider.overrideWithValue(false),
          discoverySupportsAdvertisingProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pump();

    expect(find.text('Peers'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
