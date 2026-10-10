import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/app_state.dart';
import 'package:gym_tracker/db.dart';
import 'package:gym_tracker/i18n.dart';
import 'package:gym_tracker/screens/guide_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The tabs live in an `IndexedStack(children: const [...])`. Flutter skips an
/// element whose widget is the identical instance, and const widgets are
/// canonicalised — so a const tab is never rebuilt from above no matter how
/// often its parent rebuilds. A screen that only reads [L] at build time has
/// to listen for the change itself or it keeps the old language forever.
void main() {
  sqfliteFfiInit();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('liftlog_lang');
    // the widget-test binding deadlocks on sqflite's background isolate
    await GymDb.instance
        .open(factory: databaseFactoryFfiNoIsolate, path: '${tmp.path}/t.db');
    L.lang = AppLang.en;
  });

  tearDown(() async {
    L.lang = AppLang.en;
    await GymDb.instance.close();
    await tmp.delete(recursive: true);
  });

  Future<void> pumpGuide(WidgetTester tester) => tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IndexedStack(index: 0, children: [GuideScreen()]),
          ),
        ),
      );

  testWidgets('the guide follows a switch into Arabic', (tester) async {
    await pumpGuide(tester);
    expect(find.text('Guide'), findsOneWidget);

    await appState.setLang(AppLang.ar);
    await tester.pump();

    expect(find.text('الدليل'), findsOneWidget);
    expect(find.text('Guide'), findsNothing);
  });

  testWidgets('and back out of it again', (tester) async {
    L.lang = AppLang.ar;
    await pumpGuide(tester);
    expect(find.text('الدليل'), findsOneWidget);

    await appState.setLang(AppLang.en);
    await tester.pump();

    expect(find.text('Guide'), findsOneWidget);
    expect(find.text('الدليل'), findsNothing);
  });

  testWidgets('the body text changes too, not just the heading',
      (tester) async {
    await pumpGuide(tester);
    expect(find.text('THE WEEK'), findsOneWidget);

    await appState.setLang(AppLang.ar);
    await tester.pump();

    expect(find.text('الأسبوع'), findsOneWidget);
  });
}
