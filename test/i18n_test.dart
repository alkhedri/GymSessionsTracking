import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/i18n.dart';
import 'package:gym_tracker/program.dart';
import 'package:gym_tracker/program_ar.dart';

void main() {
  tearDown(() => L.lang = AppLang.en);

  group('Arabic covers the whole program', () {
    test('every exercise has a name and a coaching note', () {
      for (final d in Program.days) {
        for (final e in d.exercises) {
          expect(ProgramAr.exerciseName[e.id], isNotNull,
              reason: 'no Arabic name for ${e.id} (${e.name})');
          expect(ProgramAr.exerciseNote[e.id], isNotNull,
              reason: 'no Arabic note for ${e.id} (${e.name})');
        }
      }
    });

    test('every muscle used anywhere is translated', () {
      final used = {
        for (final d in Program.days)
          for (final e in d.exercises) e.muscle,
        for (final v in Program.volume) v.muscle,
      };
      for (final m in used) {
        expect(ProgramAr.muscle[m], isNotNull, reason: 'no Arabic for "$m"');
      }
    });

    test('every day is translated', () {
      for (final d in Program.days) {
        expect(ProgramAr.dayShort[d.id], isNotNull);
        expect(ProgramAr.dayName[d.id], isNotNull);
        expect(ProgramAr.dayFocus[d.id], isNotNull);
        expect(ProgramAr.dayIntro[d.id], isNotNull);
      }
    });

    test('every phase is translated, including the disabled deload', () {
      for (final p in Program.phases) {
        expect(ProgramAr.phaseTag[p.tag], isNotNull, reason: p.tag);
        expect(ProgramAr.phaseNote[p.tag], isNotNull, reason: p.tag);
      }
      expect(ProgramAr.phaseTag['Deload'], isNotNull);
    });

    test('every volume row has an Arabic note', () {
      for (final v in Program.volume) {
        expect(ProgramAr.volumeNote[v.muscle], isNotNull, reason: v.muscle);
      }
    });

    test('the guide is translated section for section, item for item', () {
      expect(ProgramAr.guide, hasLength(Program.guide.length));
      for (var i = 0; i < Program.guide.length; i++) {
        final en = Program.guide[i].items;
        final ar = ProgramAr.guide[i][1] as List;
        expect(ar, hasLength(en.length),
            reason: 'section "${Program.guide[i].title}" item count');
        for (final item in ar) {
          expect((item as List)[0] as String, isNotEmpty);
          expect(item[1] as String, isNotEmpty);
        }
      }
      L.lang = AppLang.ar;
      expect(Program.displayGuide, hasLength(Program.guide.length));
      expect(Program.displayGuide.first.title, ProgramAr.guide[0][0]);
    });
  });

  group('switching language', () {
    final lift = Program.dayById('d1').exercises.first;

    test('swaps what is shown', () {
      expect(lift.displayName, lift.name);
      L.lang = AppLang.ar;
      expect(lift.displayName, ProgramAr.exerciseName[lift.id]);
      expect(lift.displayMuscle, ProgramAr.muscle[lift.muscle]);
      expect(lift.displayNote, ProgramAr.exerciseNote[lift.id]);
    });

    test('never moves the identity written into the database', () {
      // workout_set.movement stores Exercise.name and lastBest matches on it,
      // so a language switch must not orphan a single logged set.
      final before = [
        for (final d in Program.days)
          for (final e in d.exercises) e.name
      ];
      L.lang = AppLang.ar;
      final after = [
        for (final d in Program.days)
          for (final e in d.exercises) e.name
      ];
      expect(after, before);
    });

    test('a renamed exercise keeps the user wording in both languages', () {
      final renamed = lift.copyWith(name: 'Pendulum Squat');
      expect(renamed.displayName, 'Pendulum Squat');
      L.lang = AppLang.ar;
      expect(renamed.displayName, 'Pendulum Squat',
          reason: 'the Arabic original must not override a user rename');
    });

    test('a custom exercise falls back to its own text', () {
      const custom = Exercise(
        id: 'd1-c123',
        name: 'Adductor Machine',
        muscle: 'Adductors',
        sets: 3,
        reps: '12-15',
        rir: '1',
        rest: 60,
        note: 'squeeze',
      );
      L.lang = AppLang.ar;
      expect(custom.displayName, 'Adductor Machine');
      expect(custom.displayMuscle, 'Adductors');
      expect(custom.displayNote, 'squeeze');
    });

    test('UI strings and direction follow the language', () {
      expect(L.isAr, isFalse);
      expect(L.locale.languageCode, 'en');
      final en = L.train;
      L.lang = AppLang.ar;
      expect(L.locale.languageCode, 'ar');
      expect(L.train, isNot(en));
      expect(L.train, 'التمرين');
    });
  });
}
