import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/db.dart';
import 'package:gym_tracker/exercise_store.dart';
import 'package:gym_tracker/program.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exercises the real schema on a throwaway file database.
void main() {
  sqfliteFfiInit();

  late Directory tmp;
  late String dbPath;
  late ExerciseStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('liftlog_test');
    dbPath = '${tmp.path}/test.db';
    await GymDb.instance.open(factory: databaseFactoryFfi, path: dbPath);
    store = ExerciseStore();
    await store.load();
  });

  tearDown(() async {
    await GymDb.instance.close();
    await tmp.delete(recursive: true);
  });

  const dayId = 'd2';
  final firstLift = Program.dayById(dayId).exercises.first; // Hack Squat

  group('editing an exercise', () {
    test('an untouched day matches the printed program', () {
      expect(store.forDay(dayId).map((e) => e.name),
          Program.dayById(dayId).exercises.map((e) => e.name));
      expect(store.isEdited(dayId), isFalse);
    });

    test('a swapped movement replaces the name everywhere', () async {
      await store.edit(dayId, firstLift.copyWith(name: 'Pendulum Squat'));

      expect(store.forDay(dayId).first.name, 'Pendulum Squat');
      expect(store.isEdited(dayId), isTrue);
      // untouched fields still track the program
      expect(store.forDay(dayId).first.reps, firstLift.reps);
      expect(store.forDay(dayId).first.rest, firstLift.rest);
    });

    test('changing sets changes the day total on every week', () async {
      final before = store.targetSets(dayId, 1);
      await store.edit(dayId, firstLift.copyWith(sets: 5));

      expect(store.targetSets(dayId, 1), before + 2);
      // deloads are off, so the fifth week is not halved
      expect(store.forDay(dayId).first.targetSets(5), 5);
      expect(store.targetSets(dayId, 5), before + 2);
    });

    test('an edit survives a reload from the database', () async {
      await store.edit(dayId, firstLift.copyWith(name: 'Pendulum Squat'));

      final reopened = ExerciseStore();
      await reopened.load();
      expect(reopened.forDay(dayId).first.name, 'Pendulum Squat');
    });

    test('reset puts the printed exercise back', () async {
      await store.edit(dayId, firstLift.copyWith(name: 'Pendulum Squat'));
      await store.restore(dayId, firstLift.id);

      expect(store.forDay(dayId).first.name, firstLift.name);
      expect(store.isEdited(dayId), isFalse);
    });
  });

  group('adding and removing', () {
    test('an added exercise lands at the end and counts toward the target',
        () async {
      final before = store.targetSets(dayId, 1);
      await store.addExercise(
          dayId,
          const Exercise(
              id: '',
              name: 'Adductor Machine',
              muscle: 'Adductors',
              sets: 2,
              reps: '12-15',
              rir: '0-1',
              rest: 60,
              note: ''));

      final list = store.forDay(dayId);
      expect(list.last.name, 'Adductor Machine');
      expect(store.targetSets(dayId, 1), before + 2);
      expect(store.isCustom(list.last.id), isTrue);
    });

    test('a removed program exercise drops out but can be put back', () async {
      await store.remove(dayId, firstLift.id);

      expect(store.forDay(dayId).map((e) => e.id), isNot(contains(firstLift.id)));
      expect(store.hiddenIn(dayId).map((e) => e.id), contains(firstLift.id));

      await store.restore(dayId, firstLift.id);
      expect(store.forDay(dayId).first.id, firstLift.id);
      expect(store.hiddenIn(dayId), isEmpty);
    });

    test('deleting an added exercise also deletes what was logged for it',
        () async {
      final added = await store.addExercise(
          dayId,
          const Exercise(
              id: '',
              name: 'Adductor Machine',
              muscle: 'Adductors',
              sets: 2,
              reps: '12-15',
              rir: '0-1',
              rest: 60,
              note: ''));
      await GymDb.instance.saveSet(
        week: 1,
        dayId: dayId,
        exerciseId: added.id,
        setIndex: 0,
        movement: added.name,
        kg: 40,
        reps: 12,
        done: true,
      );
      expect((await GymDb.instance.weekByDay(1))[dayId]!.sets, 1);

      await store.remove(dayId, added.id);
      expect((await GymDb.instance.weekByDay(1))[dayId], isNull);
    });

    test('resetting a day clears edits, additions and removals', () async {
      await store.edit(dayId, firstLift.copyWith(name: 'Pendulum Squat'));
      await store.remove(dayId, Program.dayById(dayId).exercises[1].id);
      await store.addExercise(
          dayId,
          const Exercise(
              id: '',
              name: 'Adductor Machine',
              muscle: 'Adductors',
              sets: 2,
              reps: '12-15',
              rir: '0-1',
              rest: 60,
              note: ''));

      await store.resetDay(dayId);

      expect(store.forDay(dayId).map((e) => e.name),
          Program.dayById(dayId).exercises.map((e) => e.name));
      expect(store.isEdited(dayId), isFalse);
      expect(store.targetSets(dayId, 1), 16);
    });
  });

  group('reordering', () {
    test('a new order sticks and survives a reload', () async {
      final original = store.forDay(dayId);
      final moved = [...original];
      moved.insert(0, moved.removeAt(3));

      await store.reorder(dayId, moved);
      expect(store.forDay(dayId).first.id, original[3].id);

      final reopened = ExerciseStore();
      await reopened.load();
      expect(reopened.forDay(dayId).map((e) => e.id), moved.map((e) => e.id));
    });

    test('reordering does not change any prescription', () async {
      final moved = [...store.forDay(dayId)];
      moved.insert(0, moved.removeAt(2));
      await store.reorder(dayId, moved);

      expect(store.targetSets(dayId, 1), 16);
      final hack = store.forDay(dayId).firstWhere((e) => e.id == firstLift.id);
      expect(hack.name, firstLift.name);
      expect(hack.sets, firstLift.sets);
      expect(hack.rest, firstLift.rest);
    });
  });

  group('history follows the movement, not the slot', () {
    Future<void> log(String movement, double kg, int reps, int week) =>
        GymDb.instance.saveSet(
          week: week,
          dayId: dayId,
          exerciseId: firstLift.id,
          setIndex: 0,
          movement: movement,
          kg: kg,
          reps: reps,
          done: true,
        );

    test('the same movement carries its best set forward', () async {
      await log(firstLift.name, 140, 8, 1);
      final best = await GymDb.instance.lastBest(firstLift.id, firstLift.name, 2);
      expect(best!.kg, 140);
      expect(best.reps, 8);
      expect(best.week, 1);
    });

    test('a different movement in the same slot starts fresh', () async {
      await log(firstLift.name, 140, 8, 1);
      final best =
          await GymDb.instance.lastBest(firstLift.id, 'Pendulum Squat', 2);
      expect(best, isNull,
          reason: 'a load from another machine must not be suggested');
    });

    test('only earlier weeks count', () async {
      await log(firstLift.name, 140, 8, 3);
      expect(await GymDb.instance.lastBest(firstLift.id, firstLift.name, 3),
          isNull);
      expect(await GymDb.instance.lastBest(firstLift.id, firstLift.name, 4),
          isNotNull);
    });
  });

  group('upgrading a version 1 database', () {
    test('keeps logged sets and still offers them as history', () async {
      await GymDb.instance.close();
      final legacyPath = '${tmp.path}/legacy.db';

      // the shape the app shipped before exercises were editable
      final v1 = await databaseFactoryFfi.openDatabase(legacyPath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (d, _) async {
              await d.execute('''
                CREATE TABLE workout_set (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  week INTEGER NOT NULL, day_id TEXT NOT NULL,
                  exercise_id TEXT NOT NULL, set_index INTEGER NOT NULL,
                  kg REAL, reps INTEGER,
                  done INTEGER NOT NULL DEFAULT 0, logged_at TEXT,
                  UNIQUE (week, day_id, exercise_id, set_index))
              ''');
              await d.execute(
                  'CREATE TABLE week_log (week INTEGER PRIMARY KEY, bodyweight REAL, sleep REAL, feel TEXT)');
              await d.execute(
                  'CREATE TABLE setting (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
            },
          ));
      await v1.insert('workout_set', {
        'week': 1,
        'day_id': dayId,
        'exercise_id': firstLift.id,
        'set_index': 0,
        'kg': 120.0,
        'reps': 8,
        'done': 1,
      });
      await v1.close();

      await GymDb.instance
          .open(factory: databaseFactoryFfi, path: legacyPath);

      expect((await GymDb.instance.weekByDay(1))[dayId]!.sets, 1);
      // no movement was recorded back then, so it still matches
      final best =
          await GymDb.instance.lastBest(firstLift.id, firstLift.name, 2);
      expect(best!.kg, 120);

      // and the new table is there to be written to
      final upgraded = ExerciseStore();
      await upgraded.load();
      await upgraded.edit(dayId, firstLift.copyWith(sets: 4));
      expect(upgraded.forDay(dayId).first.sets, 4);
    });
  });
}
