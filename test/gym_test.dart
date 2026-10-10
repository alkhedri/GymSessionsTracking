import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/db.dart';
import 'package:gym_tracker/program.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Same exercise list everywhere; only the loading differs, so history and the
/// "last time" hint are scoped per gym.
void main() {
  sqfliteFfiInit();

  late Directory tmp;

  const dayId = 'd1';
  final lift = Program.dayById(dayId).exercises.first;

  Future<void> openFresh(String name) async {
    await GymDb.instance.close();
    await GymDb.instance
        .open(factory: databaseFactoryFfi, path: '${tmp.path}/$name.db');
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('liftlog_gym');
    await openFresh('main');
  });

  tearDown(() async {
    await GymDb.instance.close();
    await tmp.delete(recursive: true);
  });

  Future<void> log(int gymId, int week, double kg, int reps) =>
      GymDb.instance.saveSet(
        week: week,
        dayId: dayId,
        exerciseId: lift.id,
        setIndex: 0,
        movement: lift.name,
        gymId: gymId,
        kg: kg,
        reps: reps,
        done: true,
      );

  group('gyms', () {
    test('a fresh database always has one to log against', () async {
      final gyms = await GymDb.instance.gyms();
      expect(gyms, hasLength(1));
      expect(await GymDb.instance.currentGymId(), gyms.first.id);
    });

    test('can be added, renamed and listed', () async {
      final b = await GymDb.instance.addGym('Hotel Gym');
      await GymDb.instance.renameGym(b, 'Hotel Basement');

      final gyms = await GymDb.instance.gyms();
      expect(gyms, hasLength(2));
      expect(gyms.firstWhere((g) => g.id == b).name, 'Hotel Basement');
    });
  });

  group('loads are tracked per gym', () {
    test('each gym keeps its own last-best for the same exercise', () async {
      final home = (await GymDb.instance.gyms()).first.id;
      final away = await GymDb.instance.addGym('Hotel Gym');

      await log(home, 1, 100, 8); // week 1 at home, heavy machine
      await log(away, 2, 60, 8); // week 2 away, same lift, lighter machine

      // back home in week 3: the hint must be week 1's 100, not week 2's 60
      final atHome =
          await GymDb.instance.lastBest(lift.id, lift.name, 3, gymId: home);
      final atAway =
          await GymDb.instance.lastBest(lift.id, lift.name, 3, gymId: away);

      expect(atHome!.kg, 100);
      expect(atHome.week, 1);
      expect(atAway!.kg, 60);
      expect(atAway.week, 2);
    });

    test('a gym with no history here offers nothing, rather than guessing',
        () async {
      final home = (await GymDb.instance.gyms()).first.id;
      final away = await GymDb.instance.addGym('Hotel Gym');
      await log(home, 1, 100, 8);

      expect(
        await GymDb.instance.lastBest(lift.id, lift.name, 2, gymId: away),
        isNull,
        reason: "another gym's load must never be offered as the hint",
      );
    });

    test('asking without a gym still sees everything', () async {
      final home = (await GymDb.instance.gyms()).first.id;
      await log(home, 1, 100, 8);

      final any = await GymDb.instance.lastBest(lift.id, lift.name, 2);
      expect(any!.kg, 100);
    });

    test('sets from a deleted gym stop feeding any gym\'s hint but still count',
        () async {
      final home = (await GymDb.instance.gyms()).first.id;
      final away = await GymDb.instance.addGym('Hotel Gym');
      await log(away, 1, 60, 8);

      await GymDb.instance.deleteGym(away);

      // the tonnage is still yours
      expect((await GymDb.instance.weekByDay(1))[dayId]!.tonnage, 480);
      // and an orphaned row matches any gym rather than disappearing
      final atHome =
          await GymDb.instance.lastBest(lift.id, lift.name, 2, gymId: home);
      expect(atHome!.kg, 60);
      expect(await GymDb.instance.gyms(), hasLength(1));
    });
  });

  group('progress can be read per gym', () {
    test('tonnage filters to one gym', () async {
      final home = (await GymDb.instance.gyms()).first.id;
      final away = await GymDb.instance.addGym('Hotel Gym');
      await log(home, 1, 100, 8); // 800
      await log(away, 2, 60, 8); // 480

      final all = await GymDb.instance.allByWeekDay();
      expect(all[1]![dayId]!.tonnage, 800);
      expect(all[2]![dayId]!.tonnage, 480);

      final homeOnly = await GymDb.instance.allByWeekDay(gymId: home);
      expect(homeOnly[1]![dayId]!.tonnage, 800);
      expect(homeOnly.containsKey(2), isFalse);
    });
  });

  group('upgrading a version 2 database', () {
    test('existing sets are filed under the first gym, keeping their history',
        () async {
      await GymDb.instance.close();
      final legacyPath = '${tmp.path}/legacy.db';

      // the shape the app shipped before gyms existed
      final v2 = await databaseFactoryFfi.openDatabase(legacyPath,
          options: OpenDatabaseOptions(
            version: 2,
            onCreate: (d, _) async {
              await d.execute('''
                CREATE TABLE workout_set (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  week INTEGER NOT NULL, day_id TEXT NOT NULL,
                  exercise_id TEXT NOT NULL, set_index INTEGER NOT NULL,
                  kg REAL, reps INTEGER,
                  done INTEGER NOT NULL DEFAULT 0, movement TEXT, logged_at TEXT,
                  UNIQUE (week, day_id, exercise_id, set_index))
              ''');
              await d.execute(
                  'CREATE TABLE week_log (week INTEGER PRIMARY KEY, bodyweight REAL, sleep REAL, feel TEXT)');
              await d.execute(
                  'CREATE TABLE setting (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
              await d.execute('''
                CREATE TABLE exercise_custom (
                  exercise_id TEXT PRIMARY KEY, day_id TEXT NOT NULL,
                  name TEXT, muscle TEXT, sets INTEGER, reps TEXT, rir TEXT,
                  rest INTEGER, note TEXT, position INTEGER,
                  hidden INTEGER NOT NULL DEFAULT 0,
                  is_custom INTEGER NOT NULL DEFAULT 0)
              ''');
            },
          ));
      await v2.insert('workout_set', {
        'week': 1,
        'day_id': dayId,
        'exercise_id': lift.id,
        'set_index': 0,
        'kg': 72.5,
        'reps': 8,
        'done': 1,
        'movement': lift.name,
      });
      await v2.close();

      await GymDb.instance.open(factory: databaseFactoryFfi, path: legacyPath);

      final gyms = await GymDb.instance.gyms();
      expect(gyms, hasLength(1));

      // the old set was backfilled, so it still drives the hint at that gym
      final best = await GymDb.instance
          .lastBest(lift.id, lift.name, 2, gymId: gyms.first.id);
      expect(best!.kg, 72.5);
      expect((await GymDb.instance.weekByDay(1))[dayId]!.sets, 1);
    });
  });
}
