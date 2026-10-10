import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/backup.dart';
import 'package:gym_tracker/db.dart';
import 'package:gym_tracker/exercise_store.dart';
import 'package:gym_tracker/program.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tmp;
  late ExerciseStore store;

  const dayId = 'd1';
  final lift = Program.dayById(dayId).exercises.first;

  Future<void> openFresh(String name) async {
    await GymDb.instance.close();
    await GymDb.instance
        .open(factory: databaseFactoryFfi, path: '${tmp.path}/$name.db');
    store = ExerciseStore();
    await store.load();
  }

  /// A database with sets, a week log, a setting and an exercise edit in it.
  Future<void> seed() async {
    final gymId = (await GymDb.instance.gyms()).first.id;
    await GymDb.instance.saveSet(
      week: 1,
      dayId: dayId,
      exerciseId: lift.id,
      setIndex: 0,
      movement: lift.name,
      gymId: gymId,
      kg: 60,
      reps: 8,
      done: true,
    );
    await GymDb.instance.saveSet(
      week: 2,
      dayId: dayId,
      exerciseId: lift.id,
      setIndex: 0,
      movement: lift.name,
      gymId: gymId,
      kg: 62.5,
      reps: 8,
      done: true,
    );
    await GymDb.instance.saveWeekLog(
        2, WeekLog(bodyweight: 78.4, sleep: 6.5, feel: 'solid week'));
    await GymDb.instance.setCurrentWeek(2);
    await store.edit(dayId, lift.copyWith(name: 'Incline Press Machine'));
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('liftlog_backup');
    await openFresh('main');
  });

  tearDown(() async {
    await GymDb.instance.close();
    await tmp.delete(recursive: true);
  });

  group('export', () {
    test('produces an identifiable, valid JSON envelope', () async {
      await seed();
      final decoded = jsonDecode(await Backup.export()) as Map;

      expect(decoded['app'], 'lift-log');
      expect(decoded['format'], 1);
      expect(DateTime.tryParse('${decoded['exported_at']}'), isNotNull);
      expect((decoded['tables'] as Map).keys,
          containsAll(GymDb.backupTables));
    });

    test('carries sets, week logs, settings and exercise edits', () async {
      await seed();
      final tables =
          (jsonDecode(await Backup.export()) as Map)['tables'] as Map;

      expect((tables['workout_set'] as List).length, 2);
      expect((tables['week_log'] as List).length, 1);
      expect((tables['exercise_custom'] as List).length, 1);
      expect((tables['gym'] as List).length, 1);
      // current_week and current_gym
      expect((tables['setting'] as List).length, greaterThanOrEqualTo(1));
    });

    test('gym ids survive, since logged sets point at them', () async {
      await seed();
      final tables =
          (jsonDecode(await Backup.export()) as Map)['tables'] as Map;

      final gym = (tables['gym'] as List).first as Map;
      expect(gym['id'], isA<int>());

      final set = (tables['workout_set'] as List).first as Map;
      expect(set['gym_id'], gym['id']);
    });

    test('drops autoincrement ids so a restore does not depend on them',
        () async {
      await seed();
      final tables =
          (jsonDecode(await Backup.export()) as Map)['tables'] as Map;
      for (final row in tables['workout_set'] as List) {
        expect((row as Map).containsKey('id'), isFalse);
      }
    });

    test('a filename is dated and ends in .json', () {
      expect(Backup.suggestedFileName(),
          matches(r'^lift-log-\d{4}-\d{2}-\d{2}\.json$'));
    });
  });

  group('round trip', () {
    test('a fresh database ends up identical to the one exported', () async {
      await seed();
      final json = await Backup.export();

      // wipe out to a brand new database, then restore into it
      await openFresh('restored');
      expect((await GymDb.instance.weekByDay(1))[dayId], isNull);

      await Backup.restore(Backup.inspect(json));

      expect((await GymDb.instance.weekByDay(1))[dayId]!.sets, 1);
      expect((await GymDb.instance.weekByDay(2))[dayId]!.tonnage, 500);
      expect(await GymDb.instance.currentWeek(), 2);

      final log = await GymDb.instance.weekLog(2);
      expect(log.bodyweight, 78.4);
      expect(log.sleep, 6.5);
      expect(log.feel, 'solid week');

      final restoredStore = ExerciseStore();
      await restoredStore.load();
      expect(restoredStore.forDay(dayId).first.name, 'Incline Press Machine');
      // the untouched fields still track the printed program
      expect(restoredStore.forDay(dayId).first.reps, lift.reps);
    });

    test('history still resolves after a restore', () async {
      await seed();
      final json = await Backup.export();
      await openFresh('restored2');
      await Backup.restore(Backup.inspect(json));

      final best = await GymDb.instance.lastBest(lift.id, lift.name, 3);
      expect(best!.kg, 62.5);
      expect(best.week, 2);
    });

    test('restoring replaces rather than merges', () async {
      await seed();
      final json = await Backup.export();

      // a different database with a week the backup knows nothing about
      await openFresh('other');
      await GymDb.instance.saveSet(
        week: 9,
        dayId: dayId,
        exerciseId: lift.id,
        setIndex: 0,
        movement: lift.name,
        kg: 100,
        reps: 5,
        done: true,
      );
      await Backup.restore(Backup.inspect(json));

      expect((await GymDb.instance.weekByDay(9))[dayId], isNull,
          reason: 'pre-existing data must not survive a restore');
      expect((await GymDb.instance.weekByDay(1))[dayId]!.sets, 1);
    });
  });

  group('a backup from an older version of the app', () {
    const movement = 'Incline Smith Machine Press (30°)';

    /// Exactly what the app exported before gyms existed: no `gym` table and
    /// no `gym_id` on any set.
    String legacyFile() => jsonEncode({
          'app': 'lift-log',
          'format': 1,
          'exported_at': '2026-08-30T12:00:00.000',
          'tables': {
            'workout_set': [
              {
                'week': 1,
                'day_id': dayId,
                'exercise_id': lift.id,
                'set_index': 0,
                'kg': 60.0,
                'reps': 8,
                'done': 1,
                'movement': movement,
                'logged_at': '2026-08-30T11:00:00.000',
              },
              {
                'week': 2,
                'day_id': dayId,
                'exercise_id': lift.id,
                'set_index': 0,
                'kg': 62.5,
                'reps': 8,
                'done': 1,
                'movement': movement,
                'logged_at': '2026-09-06T11:00:00.000',
              },
            ],
            'week_log': [
              {'week': 2, 'bodyweight': 78.4, 'sleep': 6.5, 'feel': 'solid'}
            ],
            'setting': [
              {'key': 'current_week', 'value': '3'}
            ],
            'exercise_custom': [
              {
                'exercise_id': lift.id,
                'day_id': dayId,
                'name': 'Incline Press Machine',
                'hidden': 0,
                'is_custom': 0,
              }
            ],
          },
        });

    test('is accepted without complaint', () {
      final s = Backup.inspect(legacyFile());
      expect(s.sets, 2);
      expect(s.skippedRows, 0, reason: 'no row should be dropped');
      expect(s.editedExercises, 1);
    });

    test('restores every set, week log, setting and exercise edit', () async {
      await Backup.restore(Backup.inspect(legacyFile()));

      expect((await GymDb.instance.weekByDay(1))[dayId]!.sets, 1);
      expect((await GymDb.instance.weekByDay(2))[dayId]!.tonnage, 500);
      expect(await GymDb.instance.currentWeek(), 3);
      expect((await GymDb.instance.weekLog(2)).bodyweight, 78.4);

      final restored = ExerciseStore();
      await restored.load();
      expect(restored.forDay(dayId).first.name, 'Incline Press Machine');
    });

    test('gets a gym created for it, so new sets have somewhere to go',
        () async {
      await Backup.restore(Backup.inspect(legacyFile()));
      final gyms = await GymDb.instance.gyms();
      expect(gyms, hasLength(1));
      expect(await GymDb.instance.currentGymId(), gyms.first.id);
    });

    test('and its gym-less history still feeds the hint at any gym', () async {
      await Backup.restore(Backup.inspect(legacyFile()));
      final home = (await GymDb.instance.gyms()).first.id;
      final away = await GymDb.instance.addGym('Hotel Gym');

      // Sets imported without a gym match every gym rather than being
      // stranded, so nothing logged before gyms existed is lost.
      for (final gym in [home, away]) {
        final best =
            await GymDb.instance.lastBest(lift.id, movement, 3, gymId: gym);
        expect(best!.kg, 62.5, reason: 'old sets must not be stranded');
      }
    });

    test('but sets logged under a since-renamed movement stay separate',
        () async {
      await Backup.restore(Backup.inspect(legacyFile()));
      final home = (await GymDb.instance.gyms()).first.id;

      // The backup renamed this slot after those sets were logged, so they
      // belong to the old machine — the usual rule, not an import quirk.
      expect(
        await GymDb.instance
            .lastBest(lift.id, 'Incline Press Machine', 3, gymId: home),
        isNull,
      );
    });
  });

  group('rejecting bad files', () {
    void expectRejected(String source, Matcher message) {
      expect(
        () => Backup.inspect(source),
        throwsA(isA<BackupFormatException>()
            .having((e) => e.message, 'message', message)),
      );
    }

    test('not JSON at all', () {
      expectRejected('this is not json', contains('valid JSON'));
    });

    test('JSON, but not from this app', () {
      expectRejected(
          jsonEncode({'app': 'some-other-tracker', 'format': 1, 'tables': {}}),
          contains('not exported by Lift Log'));
    });

    test('no format version', () {
      expectRejected(
          jsonEncode({'app': 'lift-log', 'tables': {}}), contains('format'));
    });

    test('written by a newer app than this one', () {
      expectRejected(
          jsonEncode({'app': 'lift-log', 'format': 99, 'tables': {}}),
          contains('newer version'));
    });

    test('no tables key', () {
      expectRejected(jsonEncode({'app': 'lift-log', 'format': 1}),
          contains('no data'));
    });

    test('an empty but well-formed backup is accepted', () {
      final s = Backup.inspect(
          jsonEncode({'app': 'lift-log', 'format': 1, 'tables': {}}));
      expect(s.sets, 0);
      expect(s.weeks, 0);
    });
  });

  group('tolerating damaged rows', () {
    String fileWith(List<Object?> sets) => jsonEncode({
          'app': 'lift-log',
          'format': 1,
          'tables': {'workout_set': sets},
        });

    test('rows missing a required column are skipped, not fatal', () {
      final s = Backup.inspect(fileWith([
        {
          'week': 1,
          'day_id': 'd1',
          'exercise_id': 'd1-e0',
          'set_index': 0,
          'done': 1,
          'kg': 60,
          'reps': 8
        },
        {'week': 1, 'kg': 60}, // no day_id / exercise_id / set_index / done
        'not even a row',
      ]));
      expect(s.sets, 1);
      expect(s.skippedRows, 2);
    });

    test('unknown columns are dropped so a restore cannot fail on them',
        () async {
      final s = Backup.inspect(fileWith([
        {
          'week': 1,
          'day_id': 'd1',
          'exercise_id': 'd1-e0',
          'set_index': 0,
          'done': 1,
          'kg': 60,
          'reps': 8,
          'invented_column': 'boom',
        }
      ]));
      expect(s.tables['workout_set']!.first.containsKey('invented_column'),
          isFalse);

      await Backup.restore(s);
      expect((await GymDb.instance.weekByDay(1))['d1']!.sets, 1);
    });

    test('numbers arriving as strings are coerced', () {
      final s = Backup.inspect(fileWith([
        {
          'week': '3',
          'day_id': 'd1',
          'exercise_id': 'd1-e0',
          'set_index': '0',
          'done': true,
          'kg': '62.5',
          'reps': '8'
        }
      ]));
      final row = s.tables['workout_set']!.single;
      expect(row['week'], 3);
      expect(row['kg'], 62.5);
      expect(row['reps'], 8);
      expect(row['done'], 1);
    });
  });
}
