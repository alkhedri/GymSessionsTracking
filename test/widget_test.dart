import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/program.dart';

void main() {
  group('the block repeats forever', () {
    test('weeks map onto blocks', () {
      expect(Program.blockOf(1), 1);
      expect(Program.blockOf(5), 1);
      expect(Program.blockOf(6), 2);
      expect(Program.blockOf(11), 3);
      expect(Program.blockOf(103), 21);
    });

    test('week within a block cycles 1..5', () {
      expect(Program.weekInBlock(1), 1);
      expect(Program.weekInBlock(5), 5);
      expect(Program.weekInBlock(6), 1);
      expect(Program.weekInBlock(12), 2);
    });

    test('no week is a deload while deloads are switched off', () {
      expect(Program.deloadEnabled, isFalse);
      for (var w = 1; w <= 60; w++) {
        expect(Program.isDeload(w), isFalse, reason: 'week $w');
      }
    });

    test('the fifth week is an ordinary training week', () {
      expect(Program.phaseOf(5).deload, isFalse);
      expect(Program.phaseOf(5).tag, isNot(equalsIgnoringCase('deload')));
      expect(Program.phaseOf(10).deload, isFalse);
    });

    test('a phase exists for any week, however far out', () {
      for (final w in [1, 7, 42, 500, 5000]) {
        expect(Program.phaseOf(w).tag, isNotEmpty);
      }
    });

    test('block opener appears on week 1 of blocks after the first', () {
      expect(Program.blockOpener(1), isNull);
      expect(Program.blockOpener(5), isNull);
      expect(Program.blockOpener(6), contains('Block 2'));
      expect(Program.blockOpener(7), isNull);
      expect(Program.blockOpener(11), contains('Block 3'));
    });
  });

  group('volume is never halved while deloads are off', () {
    final day1 = Program.dayById('d1');

    test('normal weeks use the prescribed sets', () {
      expect(day1.targetSets(1), 19);
      expect(day1.targetSets(4), 19);
    });

    test('the fifth week carries the full prescription too', () {
      expect(day1.targetSets(5), 19);
      expect(day1.targetSets(10), 19);
    });

    test('every day holds its full set count on every week of a block', () {
      for (final d in Program.days) {
        final full = d.targetSets(1);
        for (var w = 1; w <= 10; w++) {
          expect(d.targetSets(w), full, reason: '${d.short} week $w');
        }
      }
    });
  });

  test('the five sessions match the workbook', () {
    expect(Program.days.length, 5);
    expect(
        Program.days.fold<int>(0, (n, d) => n + d.targetSets(1)), 86);
  });

  test('exercise ids are unique across the program', () {
    final ids = [
      for (final d in Program.days)
        for (final e in d.exercises) e.id
    ];
    expect(ids.toSet().length, ids.length);
  });
}
