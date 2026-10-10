import 'package:flutter/foundation.dart';

import 'db.dart';
import 'program.dart';

/// The program as the user actually trains it: the printed block from
/// [Program] with their edits layered on top.
///
/// Every screen reads exercises through here rather than from [Program]
/// directly, so an edit shows up everywhere at once. The composed lists are
/// cached in memory because widget builds need them synchronously.
class ExerciseStore extends ChangeNotifier {
  final Map<String, List<Exercise>> _byDay = {};
  final Map<String, ExerciseOverride> _overrides = {};

  Future<void> load() async {
    final rows = await GymDb.instance.exerciseOverrides();
    _overrides
      ..clear()
      ..addEntries(rows.map((o) => MapEntry(o.exerciseId, o)));
    for (final day in Program.days) {
      _byDay[day.id] = _compose(day);
    }
    notifyListeners();
  }

  List<Exercise> forDay(String dayId) =>
      _byDay[dayId] ?? Program.dayById(dayId).exercises;

  int targetSets(String dayId, int week) =>
      forDay(dayId).fold(0, (n, e) => n + e.targetSets(week));

  /// True when this day no longer matches the printed program.
  bool isEdited(String dayId) =>
      _overrides.values.any((o) => o.dayId == dayId);

  ExerciseOverride? overrideFor(String exerciseId) => _overrides[exerciseId];

  bool isCustom(String exerciseId) =>
      _overrides[exerciseId]?.isCustom ?? false;

  /// The exercise as the program prints it, or null if the user added it.
  Exercise? programDefault(String dayId, String exerciseId) {
    for (final e in Program.dayById(dayId).exercises) {
      if (e.id == exerciseId) return e;
    }
    return null;
  }

  List<Exercise> _compose(TrainingDay day) {
    // (position, insertion order, exercise) so ties keep a stable order.
    final rows = <(int, int, Exercise)>[];
    var seq = 0;

    for (var i = 0; i < day.exercises.length; i++) {
      final base = day.exercises[i];
      final o = _overrides[base.id];
      if (o != null && o.hidden) continue;
      rows.add((
        o?.position ?? i,
        seq++,
        o == null
            ? base
            : base.copyWith(
                name: o.name,
                muscle: o.muscle,
                sets: o.sets,
                reps: o.reps,
                rir: o.rir,
                rest: o.rest,
                note: o.note,
              ),
      ));
    }

    for (final o in _overrides.values) {
      if (!o.isCustom || o.dayId != day.id || o.hidden) continue;
      rows.add((
        o.position ?? day.exercises.length + seq,
        seq++,
        Exercise(
          id: o.exerciseId,
          name: o.name ?? 'Exercise',
          muscle: o.muscle ?? '',
          sets: o.sets ?? 3,
          reps: o.reps ?? '8-12',
          rir: o.rir ?? '1-2',
          rest: o.rest ?? 120,
          note: o.note ?? '',
        ),
      ));
    }

    rows.sort((a, b) {
      final byPos = a.$1.compareTo(b.$1);
      return byPos != 0 ? byPos : a.$2.compareTo(b.$2);
    });
    return [for (final r in rows) r.$3];
  }

  // ---- mutations -----------------------------------------------------------

  /// Writes an edit, storing only the fields that differ from the program so a
  /// slot that is later changed upstream still tracks the rest of it.
  Future<void> edit(String dayId, Exercise edited) async {
    final base = programDefault(dayId, edited.id);
    final existing = _overrides[edited.id];
    final custom = existing?.isCustom ?? base == null;

    ExerciseOverride next;
    if (custom) {
      next = ExerciseOverride(
        exerciseId: edited.id,
        dayId: dayId,
        name: edited.name,
        muscle: edited.muscle,
        sets: edited.sets,
        reps: edited.reps,
        rir: edited.rir,
        rest: edited.rest,
        note: edited.note,
        position: existing?.position,
        isCustom: true,
      );
    } else {
      next = ExerciseOverride(
        exerciseId: edited.id,
        dayId: dayId,
        name: edited.name == base!.name ? null : edited.name,
        muscle: edited.muscle == base.muscle ? null : edited.muscle,
        sets: edited.sets == base.sets ? null : edited.sets,
        reps: edited.reps == base.reps ? null : edited.reps,
        rir: edited.rir == base.rir ? null : edited.rir,
        rest: edited.rest == base.rest ? null : edited.rest,
        note: edited.note == base.note ? null : edited.note,
        position: existing?.position,
      );
    }
    await GymDb.instance.saveOverride(next);
    await load();
  }

  Future<Exercise> addExercise(String dayId, Exercise draft) async {
    final id = '$dayId-c${DateTime.now().microsecondsSinceEpoch}';
    final created = Exercise(
      id: id,
      name: draft.name,
      muscle: draft.muscle,
      sets: draft.sets,
      reps: draft.reps,
      rir: draft.rir,
      rest: draft.rest,
      note: draft.note,
    );
    await GymDb.instance.saveOverride(ExerciseOverride(
      exerciseId: id,
      dayId: dayId,
      name: created.name,
      muscle: created.muscle,
      sets: created.sets,
      reps: created.reps,
      rir: created.rir,
      rest: created.rest,
      note: created.note,
      position: forDay(dayId).length,
      isCustom: true,
    ));
    await load();
    return created;
  }

  /// Program exercises are hidden (their history survives); added ones are
  /// deleted outright along with anything logged against them.
  Future<void> remove(String dayId, String exerciseId) async {
    if (isCustom(exerciseId)) {
      await GymDb.instance.deleteCustomExercise(exerciseId);
    } else {
      final existing = _overrides[exerciseId];
      await GymDb.instance.saveOverride(ExerciseOverride(
        exerciseId: exerciseId,
        dayId: dayId,
        name: existing?.name,
        muscle: existing?.muscle,
        sets: existing?.sets,
        reps: existing?.reps,
        rir: existing?.rir,
        rest: existing?.rest,
        note: existing?.note,
        position: existing?.position,
        hidden: true,
      ));
    }
    await load();
  }

  Future<void> restore(String dayId, String exerciseId) async {
    await GymDb.instance.deleteOverride(exerciseId);
    await load();
  }

  Future<void> reorder(String dayId, List<Exercise> ordered) async {
    final updates = <ExerciseOverride>[];
    for (var i = 0; i < ordered.length; i++) {
      final ex = ordered[i];
      final existing = _overrides[ex.id];
      final base = programDefault(dayId, ex.id);
      updates.add(ExerciseOverride(
        exerciseId: ex.id,
        dayId: dayId,
        name: existing?.name ?? (base == null ? ex.name : null),
        muscle: existing?.muscle ?? (base == null ? ex.muscle : null),
        sets: existing?.sets ?? (base == null ? ex.sets : null),
        reps: existing?.reps ?? (base == null ? ex.reps : null),
        rir: existing?.rir ?? (base == null ? ex.rir : null),
        rest: existing?.rest ?? (base == null ? ex.rest : null),
        note: existing?.note ?? (base == null ? ex.note : null),
        position: i,
        isCustom: existing?.isCustom ?? base == null,
      ));
    }
    await GymDb.instance.saveOverrides(updates);
    await load();
  }

  /// Throws the day's edits away, hidden exercises included.
  Future<void> resetDay(String dayId) async {
    for (final o in _overrides.values.toList()) {
      if (o.dayId == dayId && o.isCustom) {
        await GymDb.instance.deleteCustomExercise(o.exerciseId);
      }
    }
    await GymDb.instance.resetDayOverrides(dayId);
    await load();
  }

  /// Program exercises the user has removed from a day, for the undo list.
  List<Exercise> hiddenIn(String dayId) => [
        for (final e in Program.dayById(dayId).exercises)
          if (_overrides[e.id]?.hidden ?? false) e
      ];
}

final exerciseStore = ExerciseStore();
