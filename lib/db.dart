import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'i18n.dart';

/// One logged set. [kg] and [reps] stay null until the user types something.
class SetEntry {
  final int index;
  double? kg;
  int? reps;
  bool done;

  SetEntry({required this.index, this.kg, this.reps, this.done = false});

  double get tonnage => (kg ?? 0) * (reps ?? 0);
}

class DayStat {
  final int sets;
  final double tonnage;
  const DayStat(this.sets, this.tonnage);
  static const empty = DayStat(0, 0);
}

class WeekTotals {
  final int week;
  final int sets;
  final double tonnage;
  const WeekTotals(this.week, this.sets, this.tonnage);
}

class PrevBest {
  final double kg;
  final int reps;
  final int week;
  const PrevBest(this.kg, this.reps, this.week);
}

class WeekLog {
  double? bodyweight;
  double? sleep;
  String feel;
  WeekLog({this.bodyweight, this.sleep, this.feel = ''});
}

/// A place you train. The exercise list is identical everywhere; what differs
/// is what a given number on a machine means, so loads are tracked per gym.
class Gym {
  final int id;
  final String name;
  const Gym(this.id, this.name);
}

/// A user edit to one exercise slot. Null fields mean "keep the program's
/// value", so an edit to the rest timer alone does not freeze the rest of the
/// prescription. Rows with [isCustom] are exercises the user added themselves
/// and therefore carry every field.
class ExerciseOverride {
  final String exerciseId;
  final String dayId;
  final String? name;
  final String? muscle;
  final int? sets;
  final String? reps;
  final String? rir;
  final int? rest;
  final String? note;
  final int? position;
  final bool hidden;
  final bool isCustom;

  const ExerciseOverride({
    required this.exerciseId,
    required this.dayId,
    this.name,
    this.muscle,
    this.sets,
    this.reps,
    this.rir,
    this.rest,
    this.note,
    this.position,
    this.hidden = false,
    this.isCustom = false,
  });

  Map<String, Object?> toRow() => {
        'exercise_id': exerciseId,
        'day_id': dayId,
        'name': name,
        'muscle': muscle,
        'sets': sets,
        'reps': reps,
        'rir': rir,
        'rest': rest,
        'note': note,
        'position': position,
        'hidden': hidden ? 1 : 0,
        'is_custom': isCustom ? 1 : 0,
      };

  static ExerciseOverride fromRow(Map<String, Object?> r) => ExerciseOverride(
        exerciseId: r['exercise_id'] as String,
        dayId: r['day_id'] as String,
        name: r['name'] as String?,
        muscle: r['muscle'] as String?,
        sets: r['sets'] as int?,
        reps: r['reps'] as String?,
        rir: r['rir'] as String?,
        rest: r['rest'] as int?,
        note: r['note'] as String?,
        position: r['position'] as int?,
        hidden: (r['hidden'] as int? ?? 0) == 1,
        isCustom: (r['is_custom'] as int? ?? 0) == 1,
      );
}

/// SQLite store. One row per logged set; everything else is derived with SQL.
class GymDb {
  GymDb._();
  static final GymDb instance = GymDb._();

  Database? _db;
  Database get db => _db!;

  /// [factory] and [path] exist so tests can run the real schema on a
  /// throwaway database; the app passes neither.
  Future<void> open({DatabaseFactory? factory, String? path}) async {
    if (_db != null) return;
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'gym_tracker.db');
    _db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
      version: 3,
      onCreate: (d, _) async {
        await d.execute('''
          CREATE TABLE workout_set (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            week        INTEGER NOT NULL,
            day_id      TEXT    NOT NULL,
            exercise_id TEXT    NOT NULL,
            set_index   INTEGER NOT NULL,
            kg          REAL,
            reps        INTEGER,
            done        INTEGER NOT NULL DEFAULT 0,
            movement    TEXT,
            gym_id      INTEGER,
            logged_at   TEXT,
            UNIQUE (week, day_id, exercise_id, set_index)
          )
        ''');
        await d.execute(
            'CREATE INDEX idx_set_week_day ON workout_set (week, day_id)');
        await d.execute(
            'CREATE INDEX idx_set_exercise ON workout_set (exercise_id, done, week)');
        await d.execute('''
          CREATE TABLE week_log (
            week       INTEGER PRIMARY KEY,
            bodyweight REAL,
            sleep      REAL,
            feel       TEXT
          )
        ''');
        await d.execute(
            'CREATE TABLE setting (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await _createExerciseTable(d);
        await _createGymTable(d);
        await _seedFirstGym(d);
      },
      onUpgrade: (d, from, to) async {
        if (from < 2) {
          await d.execute('ALTER TABLE workout_set ADD COLUMN movement TEXT');
          await _createExerciseTable(d);
        }
        if (from < 3) {
          await d.execute('ALTER TABLE workout_set ADD COLUMN gym_id INTEGER');
          await _createGymTable(d);
          // Everything logged before gyms existed was trained somewhere; put
          // it all in the first gym so no history loses its load history.
          final id = await _seedFirstGym(d);
          await d.update('workout_set', {'gym_id': id});
        }
      },
      ),
    );
  }

  /// Tests only — lets a fresh database be opened in the same process.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Future<void> _createGymTable(Database d) async {
    await d.execute('''
      CREATE TABLE gym (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL,
        created_at TEXT
      )
    ''');
    // the lookup behind the "last time" hint, now scoped per gym
    await d.execute(
        'CREATE INDEX idx_set_gym ON workout_set (exercise_id, gym_id, done, week)');
  }

  /// There is always at least one gym, so a set always has somewhere to go.
  static Future<int> _seedFirstGym(Database d) async {
    final id = await d.insert('gym', {
      'name': L.defaultGymName,
      'created_at': DateTime.now().toIso8601String(),
    });
    await d.insert('setting', {'key': 'current_gym', 'value': '$id'},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  static Future<void> _createExerciseTable(Database d) async {
    await d.execute('''
      CREATE TABLE exercise_custom (
        exercise_id TEXT PRIMARY KEY,
        day_id      TEXT NOT NULL,
        name        TEXT,
        muscle      TEXT,
        sets        INTEGER,
        reps        TEXT,
        rir         TEXT,
        rest        INTEGER,
        note        TEXT,
        position    INTEGER,
        hidden      INTEGER NOT NULL DEFAULT 0,
        is_custom   INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await d.execute(
        'CREATE INDEX idx_exercise_day ON exercise_custom (day_id)');
  }

  // ---- settings ------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final rows =
        await db.query('setting', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) => db.insert(
        'setting',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<int> currentWeek() async =>
      int.tryParse(await getSetting('current_week') ?? '1') ?? 1;

  Future<void> setCurrentWeek(int week) => setSetting('current_week', '$week');

  /// Highest week that has any data — used so the week list never runs out.
  Future<int> maxLoggedWeek() async {
    final r = await db.rawQuery('SELECT MAX(week) AS w FROM workout_set');
    return (r.first['w'] as int?) ?? 1;
  }

  // ---- gyms ----------------------------------------------------------------

  Future<List<Gym>> gyms() async {
    final rows = await db.query('gym', orderBy: 'id');
    return [for (final r in rows) Gym(r['id'] as int, r['name'] as String)];
  }

  Future<int> addGym(String name) => db.insert('gym', {
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });

  Future<void> renameGym(int id, String name) =>
      db.update('gym', {'name': name}, where: 'id = ?', whereArgs: [id]);

  /// Sets logged at a deleted gym keep counting toward your totals; they just
  /// lose their gym, so they stop feeding any gym's "last time" hint.
  Future<void> deleteGym(int id) async {
    await db.update('workout_set', {'gym_id': null},
        where: 'gym_id = ?', whereArgs: [id]);
    await db.delete('gym', where: 'id = ?', whereArgs: [id]);
  }

  Future<int?> currentGymId() async =>
      int.tryParse(await getSetting('current_gym') ?? '');

  Future<void> setCurrentGym(int id) => setSetting('current_gym', '$id');

  // ---- exercise edits ------------------------------------------------------

  Future<List<ExerciseOverride>> exerciseOverrides() async {
    final rows = await db.query('exercise_custom');
    return rows.map(ExerciseOverride.fromRow).toList();
  }

  Future<void> saveOverride(ExerciseOverride o) => db.insert(
        'exercise_custom',
        o.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> saveOverrides(List<ExerciseOverride> list) async {
    final batch = db.batch();
    for (final o in list) {
      batch.insert('exercise_custom', o.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Drops the edit so the slot falls back to the printed program.
  Future<void> deleteOverride(String exerciseId) => db.delete('exercise_custom',
      where: 'exercise_id = ?', whereArgs: [exerciseId]);

  Future<void> resetDayOverrides(String dayId) =>
      db.delete('exercise_custom', where: 'day_id = ?', whereArgs: [dayId]);

  /// Removes a user-added exercise outright, along with anything logged for it.
  Future<void> deleteCustomExercise(String exerciseId) async {
    await db.delete('exercise_custom',
        where: 'exercise_id = ?', whereArgs: [exerciseId]);
    await db.delete('workout_set',
        where: 'exercise_id = ?', whereArgs: [exerciseId]);
  }

  // ---- sets ----------------------------------------------------------------

  Future<Map<String, List<SetEntry>>> loadSession(int week, String dayId) async {
    final rows = await db.query('workout_set',
        where: 'week = ? AND day_id = ?',
        whereArgs: [week, dayId],
        orderBy: 'exercise_id, set_index');
    final out = <String, List<SetEntry>>{};
    for (final r in rows) {
      out.putIfAbsent(r['exercise_id'] as String, () => []).add(SetEntry(
            index: r['set_index'] as int,
            kg: (r['kg'] as num?)?.toDouble(),
            reps: r['reps'] as int?,
            done: (r['done'] as int) == 1,
          ));
    }
    return out;
  }

  Future<void> saveSet({
    required int week,
    required String dayId,
    required String exerciseId,
    required int setIndex,
    required String movement,
    int? gymId,
    double? kg,
    int? reps,
    required bool done,
  }) =>
      db.insert(
        'workout_set',
        {
          'week': week,
          'day_id': dayId,
          'exercise_id': exerciseId,
          'set_index': setIndex,
          'kg': kg,
          'reps': reps,
          'done': done ? 1 : 0,
          'movement': movement,
          'gym_id': gymId,
          'logged_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> deleteSet(
          int week, String dayId, String exerciseId, int setIndex) =>
      db.delete('workout_set',
          where: 'week = ? AND day_id = ? AND exercise_id = ? AND set_index = ?',
          whereArgs: [week, dayId, exerciseId, setIndex]);

  Future<void> clearSession(int week, String dayId) => db.delete('workout_set',
      where: 'week = ? AND day_id = ?', whereArgs: [week, dayId]);

  // ---- stats ---------------------------------------------------------------

  Future<Map<String, DayStat>> weekByDay(int week) async {
    final rows = await db.rawQuery('''
      SELECT day_id,
             COUNT(*) AS sets,
             SUM(COALESCE(kg,0) * COALESCE(reps,0)) AS tonnage
      FROM workout_set
      WHERE week = ? AND done = 1
      GROUP BY day_id
    ''', [week]);
    return {
      for (final r in rows)
        r['day_id'] as String:
            DayStat(r['sets'] as int, (r['tonnage'] as num?)?.toDouble() ?? 0)
    };
  }

  /// Every week's per-day totals in one query — drives the progress screen.
  /// [gymId] narrows it to one gym, since tonnage from two gyms with different
  /// machines is not comparable.
  Future<Map<int, Map<String, DayStat>>> allByWeekDay({int? gymId}) async {
    final rows = await db.rawQuery('''
      SELECT week, day_id,
             COUNT(*) AS sets,
             SUM(COALESCE(kg,0) * COALESCE(reps,0)) AS tonnage
      FROM workout_set
      WHERE done = 1 ${gymId == null ? '' : 'AND gym_id = ?'}
      GROUP BY week, day_id
    ''', gymId == null ? [] : [gymId]);
    final out = <int, Map<String, DayStat>>{};
    for (final r in rows) {
      out.putIfAbsent(r['week'] as int, () => {})[r['day_id'] as String] =
          DayStat(r['sets'] as int, (r['tonnage'] as num?)?.toDouble() ?? 0);
    }
    return out;
  }

  Future<Map<int, WeekTotals>> weekTotals(int fromWeek, int toWeek) async {
    final rows = await db.rawQuery('''
      SELECT week,
             COUNT(*) AS sets,
             SUM(COALESCE(kg,0) * COALESCE(reps,0)) AS tonnage
      FROM workout_set
      WHERE done = 1 AND week BETWEEN ? AND ?
      GROUP BY week
      ORDER BY week
    ''', [fromWeek, toWeek]);
    return {
      for (final r in rows)
        r['week'] as int: WeekTotals(r['week'] as int, r['sets'] as int,
            (r['tonnage'] as num?)?.toDouble() ?? 0)
    };
  }

  /// Heaviest working set for this slot in an earlier week.
  ///
  /// Matched on the movement name and the gym as well as the slot. Swapping an
  /// exercise, or training somewhere else, starts a fresh history rather than
  /// prefilling a load you lifted on a different machine — the same 80 kg does
  /// not mean the same thing on two gyms' chest presses, and a prefilled value
  /// gets committed the moment you tap the tick. Rows with a null movement
  /// (schema v1) or a null gym (gym since deleted) always match.
  Future<PrevBest?> lastBest(
      String exerciseId, String movement, int beforeWeek,
      {int? gymId}) async {
    final rows = await db.rawQuery('''
      SELECT kg, reps, week
      FROM workout_set
      WHERE exercise_id = ?
        AND done = 1
        AND week < ?
        AND reps IS NOT NULL
        AND (movement IS NULL OR movement = ?)
        AND (gym_id IS NULL OR ? IS NULL OR gym_id = ?)
      ORDER BY week DESC, (COALESCE(kg,0) * COALESCE(reps,0)) DESC
      LIMIT 1
    ''', [exerciseId, beforeWeek, movement, gymId, gymId]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return PrevBest(
        (r['kg'] as num?)?.toDouble() ?? 0, r['reps'] as int, r['week'] as int);
  }

  // ---- week log ------------------------------------------------------------

  Future<WeekLog> weekLog(int week) async {
    final rows = await db
        .query('week_log', where: 'week = ?', whereArgs: [week], limit: 1);
    if (rows.isEmpty) return WeekLog();
    final r = rows.first;
    return WeekLog(
      bodyweight: (r['bodyweight'] as num?)?.toDouble(),
      sleep: (r['sleep'] as num?)?.toDouble(),
      feel: (r['feel'] as String?) ?? '',
    );
  }

  Future<Map<int, WeekLog>> weekLogs(int fromWeek, int toWeek) async {
    final rows = await db.query('week_log',
        where: 'week BETWEEN ? AND ?', whereArgs: [fromWeek, toWeek]);
    return {
      for (final r in rows)
        r['week'] as int: WeekLog(
          bodyweight: (r['bodyweight'] as num?)?.toDouble(),
          sleep: (r['sleep'] as num?)?.toDouble(),
          feel: (r['feel'] as String?) ?? '',
        )
    };
  }

  Future<void> saveWeekLog(int week, WeekLog log) => db.insert(
        'week_log',
        {
          'week': week,
          'bodyweight': log.bodyweight,
          'sleep': log.sleep,
          'feel': log.feel,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> wipe() async {
    await db.delete('workout_set');
    await db.delete('week_log');
    await db.delete('setting');
    await db.delete('exercise_custom');
    await db.delete('gym');
    await ensureGym();
  }

  // ---- backup --------------------------------------------------------------

  static const backupTables = [
    'gym',
    'workout_set',
    'week_log',
    'setting',
    'exercise_custom'
  ];

  /// Tables whose `id` is a meaningless autoincrement. `gym.id` is NOT one of
  /// them — `workout_set.gym_id` points at it, so it has to survive a restore.
  static const _idIsDisposable = {'workout_set'};

  /// Every row in the database, table by table.
  Future<Map<String, List<Map<String, Object?>>>> exportAll() async {
    final out = <String, List<Map<String, Object?>>>{};
    for (final table in backupTables) {
      final rows = await db.query(table);
      final dropId = _idIsDisposable.contains(table);
      out[table] = [
        for (final r in rows)
          {
            for (final e in r.entries)
              if (!(dropId && e.key == 'id')) e.key: e.value,
          }
      ];
    }
    return out;
  }

  /// A database with no gym has nowhere to file new sets.
  Future<void> ensureGym() async {
    final rows = await db.query('gym', limit: 1);
    if (rows.isEmpty) await _seedFirstGym(db);
  }

  /// Replaces the whole database with [tables], in one transaction: either the
  /// restore lands completely or the existing data is left untouched.
  Future<void> importAll(Map<String, List<Map<String, Object?>>> tables) =>
      db.transaction((txn) async {
        for (final table in backupTables) {
          await txn.delete(table);
        }
        for (final table in backupTables) {
          final rows = tables[table];
          if (rows == null) continue;
          final batch = txn.batch();
          for (final row in rows) {
            batch.insert(table, row,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        }
      }).then((_) => ensureGym());
}
