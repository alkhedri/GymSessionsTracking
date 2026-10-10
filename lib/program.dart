/// 5-Day Machine Hypertrophy Program — transcribed from the source workbook.
///
/// The block is five weeks long but the program does not stop there: week 6 is
/// block 2 week 1, week 11 is block 3 week 1, and so on forever. Everything in
/// this file keys off an absolute week number that only ever counts up.
library;

import 'i18n.dart';
import 'program_ar.dart';

class Exercise {
  final String id;
  final String name;
  final String muscle;
  final int sets;
  final String reps;
  final String rir;
  final int rest; // seconds
  final String note;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscle,
    required this.sets,
    required this.reps,
    required this.rir,
    required this.rest,
    required this.note,
  });

  /// Deload weeks run half the prescribed sets, rounded up. With deloads
  /// switched off this is always the full prescription.
  int targetSets(int week) =>
      Program.isDeload(week) ? (sets / 2).ceil() : sets;

  Exercise copyWith({
    String? name,
    String? muscle,
    int? sets,
    String? reps,
    String? rir,
    int? rest,
    String? note,
  }) =>
      Exercise(
        id: id,
        name: name ?? this.name,
        muscle: muscle ?? this.muscle,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        rir: rir ?? this.rir,
        rest: rest ?? this.rest,
        note: note ?? this.note,
      );

  String get restLabel {
    if (rest % 60 == 0) return '${rest ~/ 60} ${L.minShort}';
    if (rest > 60) return '${(rest / 60).toStringAsFixed(1)} ${L.minShort}';
    return '$rest ${L.secShort}';
  }

  // ---- display ----
  // [name] is the identity stored in workout_set.movement, so it never
  // changes with the UI language. These getters translate only while the
  // value still matches the printed program — once the user edits it, their
  // own wording wins in both languages.

  String get displayName {
    if (!L.isAr) return name;
    final base = Program.baseExercise(id);
    if (base == null || base.name != name) return name;
    return ProgramAr.exerciseName[id] ?? name;
  }

  String get displayMuscle =>
      L.isAr ? (ProgramAr.muscle[muscle] ?? muscle) : muscle;

  String get displayNote {
    if (!L.isAr) return note;
    final base = Program.baseExercise(id);
    if (base == null || base.note != note) return note;
    return ProgramAr.exerciseNote[id] ?? note;
  }
}

class TrainingDay {
  final String id;
  final String short;
  final String name;
  final String focus;
  final int minutes;
  final String intro;
  final List<Exercise> exercises;

  const TrainingDay({
    required this.id,
    required this.short,
    required this.name,
    required this.focus,
    required this.minutes,
    required this.intro,
    required this.exercises,
  });

  int targetSets(int week) =>
      exercises.fold(0, (n, e) => n + e.targetSets(week));

  String get displayShort => L.isAr ? (ProgramAr.dayShort[id] ?? short) : short;
  String get displayName => L.isAr ? (ProgramAr.dayName[id] ?? name) : name;
  String get displayFocus => L.isAr ? (ProgramAr.dayFocus[id] ?? focus) : focus;
  String get displayIntro => L.isAr ? (ProgramAr.dayIntro[id] ?? intro) : intro;
}

class Phase {
  final String tag;
  final String note;
  final bool deload;
  const Phase(this.tag, this.note, {this.deload = false});

  String get displayTag => L.isAr ? (ProgramAr.phaseTag[tag] ?? tag) : tag;
  String get displayNote => L.isAr ? (ProgramAr.phaseNote[tag] ?? note) : note;
}

class VolumeRow {
  final String muscle;
  final int sets;
  final String target;
  final int sessions;
  final String note;
  const VolumeRow(this.muscle, this.sets, this.target, this.sessions, this.note);

  String get displayMuscle =>
      L.isAr ? (ProgramAr.muscle[muscle] ?? muscle) : muscle;
  String get displayTarget =>
      L.isAr ? (ProgramAr.volumeTarget[target] ?? target) : target;
  String get displayNote =>
      L.isAr ? (ProgramAr.volumeNote[muscle] ?? note) : note;
}

class GuideSection {
  final String title;
  final List<List<String>> items;
  const GuideSection(this.title, this.items);
}

class Program {
  Program._();

  static const String title = '5-Day Machine Hypertrophy';
  static const String subtitle = 'Machine & cable based · no barbells';

  static String get displayTitle => L.isAr ? ProgramAr.title : title;
  static String get displaySubtitle => L.isAr ? ProgramAr.subtitle : subtitle;

  /// The exercise exactly as the program prints it, before any user edit.
  static final Map<String, Exercise> _baseById = {
    for (final d in days)
      for (final e in d.exercises) e.id: e
  };
  static Exercise? baseExercise(String id) => _baseById[id];
  static const int weeksPerBlock = 5;

  // ---- infinite week maths -------------------------------------------------

  /// Deload weeks are switched off at the user's request. Set this back to
  /// true to restore the half-volume fifth week — nothing else needs changing:
  /// the set maths, the week labels, the chart styling and the guide copy all
  /// key off this one flag.
  static const bool deloadEnabled = false;

  static int blockOf(int week) => ((week - 1) ~/ weeksPerBlock) + 1;
  static int weekInBlock(int week) => ((week - 1) % weeksPerBlock) + 1;
  static bool isDeload(int week) =>
      deloadEnabled && weekInBlock(week) == weeksPerBlock;
  static Phase phaseOf(int week) => phases[weekInBlock(week) - 1];

  static String weekLabel(int week) => L.week(week);
  static String blockLabel(int week) => L.block(blockOf(week), weekInBlock(week));

  /// Extra guidance shown when a fresh block starts after the first one.
  static String? blockOpener(int week) {
    if (weekInBlock(week) != 1 || blockOf(week) == 1) return null;
    if (L.isAr) return ProgramAr.blockOpener(blockOf(week));
    return 'Block ${blockOf(week)} starts here. Swap one exercise per day for a '
        'variation and start 2-3% above your week-4 loads from the last block.';
  }

  static const Phase _deloadWeek = Phase('Deload',
      'Same exercises and loads, half the sets, stop 4-5 reps shy of failure. On 6-7 hours of sleep, deload every 4th week, not every 6th.',
      deload: true);

  /// What the fifth week is when deloads are off — a full training week.
  static const Phase _fifthWeek = Phase('Push',
      'Full sets, same as week 4. Hold your loads and add a rep wherever you can before the next block starts.');

  static const List<Phase> phases = [
    Phase('Calibration',
        'Add 1 rep in reserve to everything — deliberately easy. Log every set; this is your baseline.'),
    Phase('Build',
        'Hit the listed RIR. Beat last week by a rep somewhere in every session.'),
    Phase('Load up',
        'When you hit the top of a rep range on all sets, add the smallest available increment and drop back to the bottom of the range.'),
    Phase('Peak',
        'Hardest week. Push the isolations to failure and add one drop set per session. Do not add sets.'),
    deloadEnabled ? _deloadWeek : _fifthWeek,
  ];

  // ---- the five sessions ---------------------------------------------------

  static const List<TrainingDay> days = [
    TrainingDay(
      id: 'd1',
      short: 'Day 1',
      name: 'Upper A',
      focus: 'Chest, Back & Delts',
      minutes: 55,
      intro:
          'Superset the last three exercises with 60 sec rest if you are short on time — it saves ~8 minutes and costs nothing.',
      exercises: [
        Exercise(
            id: 'd1-e0',
            name: 'Incline Smith Machine Press (30°)',
            muscle: 'Chest',
            sets: 3,
            reps: '6-10',
            rir: '1-2',
            rest: 180,
            note:
                'Your main chest lift. Set the bench so the bar path lands on your upper chest, not your throat — mark the floor position and use it every week.'),
        Exercise(
            id: 'd1-e1',
            name: 'Chest-Supported Machine Row',
            muscle: 'Back',
            sets: 3,
            reps: '8-12',
            rir: '1-2',
            rest: 120,
            note:
                'Chest-supported so a tired lower back is never the limiting factor.'),
        Exercise(
            id: 'd1-e2',
            name: 'Machine Chest Press or Weighted Dip',
            muscle: 'Chest',
            sets: 2,
            reps: '10-15',
            rir: '1',
            rest: 120,
            note: 'Second chest angle. Machine is fine — less setup, less fatigue.'),
        Exercise(
            id: 'd1-e3',
            name: 'Neutral-Grip Lat Pulldown',
            muscle: 'Back',
            sets: 3,
            reps: '10-12',
            rir: '1',
            rest: 120,
            note: 'Full stretch at the top, drive the elbows down to your hips.'),
        Exercise(
            id: 'd1-e4',
            name: 'Seated DB Shoulder Press',
            muscle: 'Front Delts',
            sets: 2,
            reps: '8-12',
            rir: '1-2',
            rest: 120,
            note:
                'Dumbbells let the shoulders find their own path. Two sets is plenty next to the chest work.'),
        Exercise(
            id: 'd1-e5',
            name: 'Cable Lateral Raise',
            muscle: 'Side Delts',
            sets: 3,
            reps: '12-20',
            rir: '0-1',
            rest: 75,
            note: 'Cheap to recover from. Take these close to failure.'),
        Exercise(
            id: 'd1-e6',
            name: 'Overhead Cable Triceps Extension',
            muscle: 'Triceps',
            sets: 3,
            reps: '10-15',
            rir: '0-1',
            rest: 75,
            note: 'Long-head stretch. Superset with the laterals to save time.'),
      ],
    ),
    TrainingDay(
      id: 'd2',
      short: 'Day 2',
      name: 'Lower A',
      focus: 'Quad Emphasis',
      minutes: 50,
      intro:
          'Machine-based squatting — you can push much closer to failure safely, with no spotter and no technique breakdown on a bad-sleep day.',
      exercises: [
        Exercise(
            id: 'd2-e0',
            name: 'Hack Squat (or Smith Machine Squat)',
            muscle: 'Quads',
            sets: 3,
            reps: '6-8',
            rir: '1-2',
            rest: 180,
            note:
                'Pick ONE and run it the whole block. Hack squat is the better choice — fixed path, deep ROM, safe to push.'),
        Exercise(
            id: 'd2-e1',
            name: 'Leg Press',
            muscle: 'Quads',
            sets: 3,
            reps: '10-15',
            rir: '1',
            rest: 150,
            note: 'Feet low and narrow for quad bias. Deep, controlled reps.'),
        Exercise(
            id: 'd2-e2',
            name: 'Seated Leg Curl',
            muscle: 'Hamstrings',
            sets: 3,
            reps: '10-15',
            rir: '0-1',
            rest: 90,
            note: 'Seated beats lying for hamstring stretch under load.'),
        Exercise(
            id: 'd2-e3',
            name: 'Leg Extension',
            muscle: 'Quads',
            sets: 2,
            reps: '12-20',
            rir: '0',
            rest: 90,
            note: 'Last set: one drop. Cheap extra quad volume.'),
        Exercise(
            id: 'd2-e4',
            name: 'Standing Calf Raise (machine)',
            muscle: 'Calves',
            sets: 3,
            reps: '8-12',
            rir: '0-1',
            rest: 75,
            note: '3 sec pause in the stretched position. No bouncing.'),
        Exercise(
            id: 'd2-e5',
            name: 'Cable Crunch',
            muscle: 'Abs',
            sets: 2,
            reps: '10-15',
            rir: '0-1',
            rest: 60,
            note: 'Loaded and progressive, not endless reps.'),
      ],
    ),
    TrainingDay(
      id: 'd3',
      short: 'Day 3',
      name: 'Upper B',
      focus: 'Back & Arm Emphasis',
      minutes: 55,
      intro:
          'Pulling loaded first this time so the back gets one session where it is completely fresh.',
      exercises: [
        Exercise(
            id: 'd3-e0',
            name: 'Wide-Grip Lat Pulldown (or Assisted Pull-Up)',
            muscle: 'Back',
            sets: 3,
            reps: '6-10',
            rir: '1-2',
            rest: 180,
            note:
                'Lean back ~15°, pull to the collarbone. Load it heavy — this is your vertical pull.'),
        Exercise(
            id: 'd3-e1',
            name: 'Single-Arm Machine Row',
            muscle: 'Back',
            sets: 3,
            reps: '8-12',
            rir: '1-2',
            rest: 120,
            note:
                'One arm at a time gives a bigger stretch and lets you drive the elbow past your torso — the best lat row available. Brace the other hand, no torso twisting.'),
        Exercise(
            id: 'd3-e2',
            name: 'Flat Dumbbell Press',
            muscle: 'Chest',
            sets: 3,
            reps: '8-12',
            rir: '1-2',
            rest: 150,
            note: 'Deep stretch. Covers what the Smith incline misses.'),
        Exercise(
            id: 'd3-e3',
            name: 'Pec Deck or Incline Cable Fly',
            muscle: 'Chest',
            sets: 2,
            reps: '12-15',
            rir: '0-1',
            rest: 90,
            note: 'Stretch and squeeze, no ego load.'),
        Exercise(
            id: 'd3-e4',
            name: 'Reverse Pec Deck or Face Pull',
            muscle: 'Rear Delts',
            sets: 3,
            reps: '15-20',
            rir: '0-1',
            rest: 60,
            note: 'High rep, near-zero fatigue. Also undoes a day at a desk.'),
        Exercise(
            id: 'd3-e5',
            name: 'Cable Lateral Raise',
            muscle: 'Side Delts',
            sets: 3,
            reps: '12-20',
            rir: '0-1',
            rest: 60,
            note: 'Second side-delt hit. Superset with the rear delts.'),
        Exercise(
            id: 'd3-e6',
            name: 'Incline DB Curl',
            muscle: 'Biceps',
            sets: 3,
            reps: '8-12',
            rir: '0-1',
            rest: 90,
            note: 'Shoulder behind the body = maximum long-head stretch.'),
      ],
    ),
    TrainingDay(
      id: 'd4',
      short: 'Day 4',
      name: 'Lower B',
      focus: 'Hamstring & Glute Emphasis',
      minutes: 50,
      intro:
          'No deadlift of any kind — the recovery bill is too high on 6-7 hours of sleep, and the machines cover the same muscles.',
      exercises: [
        Exercise(
            id: 'd4-e0',
            name: 'Smith Machine RDL (or Dumbbell RDL)',
            muscle: 'Hamstrings',
            sets: 3,
            reps: '6-10',
            rir: '2',
            rest: 180,
            note:
                'Fixed path means you can chase the hamstring stretch without your lower back deciding when the set ends. Never to failure.'),
        Exercise(
            id: 'd4-e1',
            name: 'Lying Leg Curl',
            muscle: 'Hamstrings',
            sets: 3,
            reps: '8-12',
            rir: '0-1',
            rest: 90,
            note:
                'Different knee/hip angle to the Day 2 seated curl — both are needed.'),
        Exercise(
            id: 'd4-e2',
            name: 'Bulgarian Split Squat (DBs or Smith)',
            muscle: 'Quads',
            sets: 3,
            reps: '8-12 / leg',
            rir: '1-2',
            rest: 120,
            note:
                'Second quad dose, almost no spinal load. Stay upright, long stride.'),
        Exercise(
            id: 'd4-e3',
            name: 'Machine or Smith Hip Thrust',
            muscle: 'Glutes',
            sets: 2,
            reps: '8-12',
            rir: '1',
            rest: 120,
            note: '2 sec pause at lockout, ribs down.'),
        Exercise(
            id: 'd4-e4',
            name: 'Seated Calf Raise',
            muscle: 'Calves',
            sets: 3,
            reps: '10-15',
            rir: '0-1',
            rest: 75,
            note: 'Bent knee targets the soleus — different from Day 2.'),
        Exercise(
            id: 'd4-e5',
            name: 'Hanging Leg Raise',
            muscle: 'Abs',
            sets: 2,
            reps: '10-15',
            rir: '0-1',
            rest: 60,
            note: 'Curl the pelvis up. Add weight once you clear 15.'),
      ],
    ),
    TrainingDay(
      id: 'd5',
      short: 'Day 5',
      name: 'Arms & Delts',
      focus: 'Arms, Delts & Weak Points',
      minutes: 40,
      intro:
          'All cables and machines. No systemic fatigue, so it slots in anywhere and never interferes with the other four days. This is a real training day, not a bonus.',
      exercises: [
        Exercise(
            id: 'd5-e0',
            name: 'Cable Lateral Raise',
            muscle: 'Side Delts',
            sets: 3,
            reps: '12-20',
            rir: '0-1',
            rest: 60,
            note:
                'Third weekly exposure. The best return on 10 minutes in the whole program.'),
        Exercise(
            id: 'd5-e1',
            name: 'Machine Shoulder Press',
            muscle: 'Front Delts',
            sets: 2,
            reps: '8-12',
            rir: '1',
            rest: 120,
            note:
                'Second front-delt dose of the week. Moderate load, full ROM.'),
        Exercise(
            id: 'd5-e2',
            name: 'Rear Delt Cable Fly',
            muscle: 'Rear Delts',
            sets: 2,
            reps: '15-20',
            rir: '0-1',
            rest: 60,
            note: 'Superset with the laterals.'),
        Exercise(
            id: 'd5-e3',
            name: 'Cable Pushdown',
            muscle: 'Triceps',
            sets: 3,
            reps: '10-15',
            rir: '0',
            rest: 60,
            note: 'Last set: double drop. Push these to failure — the cost is nil.'),
        Exercise(
            id: 'd5-e4',
            name: 'Cable Curl (straight or rope)',
            muscle: 'Biceps',
            sets: 3,
            reps: '10-15',
            rir: '0',
            rest: 60,
            note: 'Superset with the pushdowns.'),
        Exercise(
            id: 'd5-e5',
            name: 'Hammer Curl (DB or rope)',
            muscle: 'Biceps',
            sets: 2,
            reps: '10-15',
            rir: '0-1',
            rest: 60,
            note:
                'Brachialis — this is what pushes the arm wider from the side.'),
      ],
    ),
  ];

  static TrainingDay dayById(String id) => days.firstWhere((d) => d.id == id);

  /// The guide in the active language, falling back section by section.
  static List<GuideSection> get displayGuide {
    if (!L.isAr) return guide;
    return [
      for (var i = 0; i < guide.length; i++)
        if (i < ProgramAr.guide.length)
          GuideSection(
            ProgramAr.guide[i][0] as String,
            [
              for (final item in ProgramAr.guide[i][1] as List)
                [(item as List)[0] as String, item[1] as String]
            ],
          )
        else
          guide[i]
    ];
  }

  static const List<VolumeRow> volume = [
    VolumeRow('Chest', 10, '8-14', 2,
        'Two angles, twice a week. Enough to grow on imperfect recovery.'),
    VolumeRow('Back', 12, '10-16', 2,
        'Highest allocation — back tolerates volume better than anything else.'),
    VolumeRow('Quads', 11, '8-14', 2,
        'Split across a machine squat day and a low-spinal-load day.'),
    VolumeRow('Hamstrings', 9, '6-12', 2,
        'Hinge and knee-flexion both covered without any deadlift.'),
    VolumeRow('Glutes', 2, '2-6 direct', 1,
        'Plus heavy indirect work from hack squats, RDLs and split squats.'),
    VolumeRow('Front Delts', 4, '2-6 direct', 2,
        'Kept modest — all your pressing already trains them hard.'),
    VolumeRow('Side Delts', 9, '6-12', 3,
        'Prioritised: cheap to recover from and they change how you look.'),
    VolumeRow('Rear Delts', 5, '3-8', 2,
        'High rep, near-zero fatigue cost. Good for desk posture too.'),
    VolumeRow('Biceps', 8, '4-10 direct', 2,
        'Sits on top of 12 weekly rowing and pulldown sets, which count for a lot.'),
    VolumeRow('Triceps', 6, '3-8 direct', 2,
        'Sits on top of 10 chest sets plus two pressing movements.'),
    VolumeRow('Calves', 6, '4-8', 2, 'Two exposures, straight-leg and bent-knee.'),
    VolumeRow('Abs', 4, '3-6', 2,
        'Loaded and progressive rather than high-rep filler.'),
  ];

  static const List<GuideSection> guide = [
    GuideSection('The week', [
      [
        'Layout',
        'Mon Day 1 / Tue Day 2 / Wed off / Thu Day 3 / Fri Day 4 / Sat Day 5 / Sun off. Slide them around your work week freely — the only rule is never two hard days back to back after a night under 6 hours.'
      ],
      [
        'Total',
        '86 working sets per week across 5 sessions, roughly 4 hours in the gym.'
      ],
      [
        'It never ends',
        'Weeks keep counting up. Every five weeks the next block starts automatically — swap one exercise per day and start 2-3% above your last week-4 loads.'
      ],
    ]),
    GuideSection('Is machine-only training a compromise?', [
      [
        'For muscle growth, no',
        'Machines and free weights produce comparable hypertrophy when sets, effort and progression are matched. Stability is not what makes a muscle grow — tension close to failure is, and machines deliver that more reliably.'
      ],
      [
        'It suits your situation',
        'No spotter needed, no technique breakdown when you are underslept, less systemic fatigue per set, and faster setup — which matters when you have 50 minutes after work.'
      ],
      [
        'The real trade-off',
        'You give up some skill and carryover to heavy barbell strength, and Smith machines fix the bar path, so if a movement pinches your shoulder or hip, change the foot or bench position rather than pushing through it.'
      ],
      [
        'One thing to watch',
        'Machines make it easy to add plates without adding effort. Log every session and hold yourself to the rep ranges — these numbers are your only real feedback.'
      ],
    ]),
    GuideSection('When the week goes badly', [
      [
        'Short on time',
        'Cut the last exercise of the session, not the first. The first lift is where the growth is.'
      ],
      [
        'Slept under 5 hours',
        'Cut every exercise to 2 sets and stop at 3 reps in reserve. You will hold your muscle and you will not dig a hole.'
      ],
      [
        'Missed a session',
        'Do not double up. Push the week forward by a day. If you can only train 4 times, drop Day 5 — it is the least costly to lose.'
      ],
    ]),
    GuideSection('Nutrition', [
      [
        'Be realistic',
        'Without a consistent surplus, expect recomposition — slowly leaner and slightly bigger — rather than fast weight gain. That is a real result, just not a fast one.'
      ],
      [
        'Protein is the priority',
        '2.0-2.2 g per kg of bodyweight daily. When calories are inconsistent, protein is what protects the muscle you are building.'
      ],
      [
        'Anchor it',
        'Fix 3-4 protein sources you will actually eat on a work day and repeat them. Decision fatigue breaks diets, not lack of knowledge.'
      ],
      [
        'Slight surplus if you can',
        '100-200 kcal over maintenance is enough. Aiming higher while your eating is already inconsistent just adds fat.'
      ],
      [
        'Creatine',
        '5 g monohydrate daily. It also partly offsets the performance cost of poor sleep.'
      ],
    ]),
    GuideSection('Sleep: the honest part', [
      [
        'What 6-7h costs you',
        'Sleep restriction lowers performance, raises perceived effort and blunts the muscle-building response. It does not stop you growing — it slows you down. This program is already scaled for it.'
      ],
      [
        'Cheapest fixes',
        'Fixed wake time every day including weekends; no caffeine within 8 hours of bed; phone out of the bedroom. A consistent 6.5 hours beats an erratic 7.5.'
      ],
      [
        'Naps count',
        '20-30 minutes recovers a meaningful part of the deficit. Weekend naps are training equipment, not laziness.'
      ],
      [
        'If you fix the sleep',
        'Add one set to the first exercise of each session before you add anything else. Earn the volume with recovery, never the other way round.'
      ],
    ]),
    GuideSection('Reading your numbers', [
      [
        'Smith machine loads',
        'Note whether your Smith is counterbalanced — the bar can weigh anywhere from 7 to 20 kg. Log plate weight only and stay consistent; what matters is that the number goes up.'
      ],
      [
        'Tonnage',
        'Sets × kg × reps. Climbing tonnage while bodyweight holds steady = recomposition, which is the realistic win without a clean surplus.'
      ],
      [
        'Stalling',
        'Tonnage flat for two weeks while sleep sits at 6h = take the deload early rather than grinding through.'
      ],
      [
        'Bodyweight',
        'Climbing faster than 0.4 kg per week means the surplus got away from you. Weigh first thing, same conditions, use the weekly average.'
      ],
    ]),
  ];
}
