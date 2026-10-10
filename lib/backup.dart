import 'dart:convert';

import 'app_state.dart';
import 'db.dart';
import 'exercise_store.dart';

/// The file is written by this app but read back from wherever the user kept
/// it, so every row is re-validated on the way in rather than trusted.
class BackupFormatException implements Exception {
  final String message;
  const BackupFormatException(this.message);
  @override
  String toString() => message;
}

/// What a backup file contains, shown to the user before anything is replaced.
class BackupSummary {
  final int sets;
  final int weeks;
  final int editedExercises;
  final DateTime? exportedAt;
  final int skippedRows;
  final Map<String, List<Map<String, Object?>>> tables;

  const BackupSummary({
    required this.sets,
    required this.weeks,
    required this.editedExercises,
    required this.exportedAt,
    required this.skippedRows,
    required this.tables,
  });
}

enum _Kind { integer, real, text }

class _Col {
  final _Kind kind;
  final bool required;
  const _Col(this.kind, {this.required = false});
}

const _schema = <String, Map<String, _Col>>{
  // id is required: workout_set.gym_id references it
  'gym': {
    'id': _Col(_Kind.integer, required: true),
    'name': _Col(_Kind.text, required: true),
    'created_at': _Col(_Kind.text),
  },
  'workout_set': {
    'week': _Col(_Kind.integer, required: true),
    'day_id': _Col(_Kind.text, required: true),
    'exercise_id': _Col(_Kind.text, required: true),
    'set_index': _Col(_Kind.integer, required: true),
    'kg': _Col(_Kind.real),
    'reps': _Col(_Kind.integer),
    'done': _Col(_Kind.integer, required: true),
    'movement': _Col(_Kind.text),
    'gym_id': _Col(_Kind.integer),
    'logged_at': _Col(_Kind.text),
  },
  'week_log': {
    'week': _Col(_Kind.integer, required: true),
    'bodyweight': _Col(_Kind.real),
    'sleep': _Col(_Kind.real),
    'feel': _Col(_Kind.text),
  },
  'setting': {
    'key': _Col(_Kind.text, required: true),
    'value': _Col(_Kind.text, required: true),
  },
  'exercise_custom': {
    'exercise_id': _Col(_Kind.text, required: true),
    'day_id': _Col(_Kind.text, required: true),
    'name': _Col(_Kind.text),
    'muscle': _Col(_Kind.text),
    'sets': _Col(_Kind.integer),
    'reps': _Col(_Kind.text),
    'rir': _Col(_Kind.text),
    'rest': _Col(_Kind.integer),
    'note': _Col(_Kind.text),
    'position': _Col(_Kind.integer),
    'hidden': _Col(_Kind.integer, required: true),
    'is_custom': _Col(_Kind.integer, required: true),
  },
};

const _appTag = 'lift-log';
const _formatVersion = 1;

class Backup {
  Backup._();

  /// The whole database plus an envelope identifying the file.
  static Future<String> export() async {
    final tables = await GymDb.instance.exportAll();
    return const JsonEncoder.withIndent('  ').convert({
      'app': _appTag,
      'format': _formatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': tables,
    });
  }

  static String suggestedFileName() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'lift-log-${now.year}-${two(now.month)}-${two(now.day)}.json';
  }

  /// Parses and validates without touching the database.
  static BackupSummary inspect(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const BackupFormatException('That file is not valid JSON.');
    }
    if (decoded is! Map) {
      throw const BackupFormatException('That file is not a Lift Log backup.');
    }
    if (decoded['app'] != _appTag) {
      throw const BackupFormatException(
          'That file was not exported by Lift Log.');
    }
    final format = decoded['format'];
    if (format is! int) {
      throw const BackupFormatException('That backup has no format version.');
    }
    if (format > _formatVersion) {
      throw BackupFormatException(
          'That backup was written by a newer version of Lift Log '
          '(format $format). Update the app and try again.');
    }
    final raw = decoded['tables'];
    if (raw is! Map) {
      throw const BackupFormatException('That backup has no data in it.');
    }

    var skipped = 0;
    final tables = <String, List<Map<String, Object?>>>{};
    for (final entry in _schema.entries) {
      final rows = raw[entry.key];
      final clean = <Map<String, Object?>>[];
      if (rows is List) {
        for (final row in rows) {
          final sane = _sanitise(row, entry.value);
          if (sane == null) {
            skipped++;
          } else {
            clean.add(sane);
          }
        }
      }
      tables[entry.key] = clean;
    }

    final sets = tables['workout_set']!;
    final weeks = sets.map((r) => r['week']).toSet();
    final edits = tables['exercise_custom']!;

    return BackupSummary(
      sets: sets.length,
      weeks: weeks.length,
      editedExercises: edits.length,
      exportedAt: DateTime.tryParse('${decoded['exported_at']}'),
      skippedRows: skipped,
      tables: tables,
    );
  }

  /// Replaces everything, then reloads the in-memory stores.
  static Future<void> restore(BackupSummary backup) async {
    await GymDb.instance.importAll(backup.tables);
    await appState.load();
    await appState.loadGyms();
    await exerciseStore.load();
    appState.dataChanged();
  }

  /// Keeps only columns the schema knows about, coerces their types, and
  /// rejects the row outright if a required one is missing.
  static Map<String, Object?>? _sanitise(Object? row, Map<String, _Col> cols) {
    if (row is! Map) return null;
    final out = <String, Object?>{};
    for (final entry in cols.entries) {
      final value = row[entry.key];
      final coerced = _coerce(value, entry.value.kind);
      if (coerced == null && entry.value.required) return null;
      if (coerced != null) out[entry.key] = coerced;
    }
    return out;
  }

  static Object? _coerce(Object? value, _Kind kind) {
    if (value == null) return null;
    switch (kind) {
      case _Kind.integer:
        if (value is int) return value;
        if (value is double) return value.round();
        if (value is bool) return value ? 1 : 0;
        return int.tryParse('$value');
      case _Kind.real:
        if (value is num) return value.toDouble();
        return double.tryParse('$value');
      case _Kind.text:
        if (value is String) return value;
        return null;
    }
  }
}
