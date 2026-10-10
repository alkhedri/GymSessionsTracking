# Lift Log

CODED BY - MOHAMMED ALKHUDARI - 2026

A native mobile gym-session tracker (Flutter + SQLite) built from
**5-Day-Machine-Hypertrophy-Program_1.xlsx**. Android and iOS only — there is no
web build.

## What it does

- **Train** — pick a week, pick one of the 5 sessions, log every set as
  `kg × reps` and tap ✓. Each exercise carries its prescribed sets, rep range,
  RIR, rest time and the workbook's coaching note.
- **Rest timer** — starts automatically at the exercise's prescribed rest when a
  set is ticked; ±15 s and skip, vibration and a tone at zero.
- **Last time** — each exercise shows your best previous set as the input hint,
  so progression is decided in front of the machine, not afterwards.
- **Editable exercises** — rename or swap any movement, change sets, reps, RIR,
  rest and the coaching note, add your own exercises, remove ones your gym
  cannot do, and drag to reorder. See below.
- **Progress** — tonnage per week (bar chart), plus bodyweight, average sleep
  and a one-line note per week, and the weekly hard-sets-per-muscle reference.
- **Guide** — the workbook's programming, nutrition and sleep notes.

## Editing the program

Three ways in: the **tune** icon in a session's app bar (full day editor), the
pencil on any exercise card, or a long-press on a day card in Train.

Edits are stored as a _diff_ against the printed program, not a copy of it. If
you only change the rest timer, the sets and rep range still track the workbook.
Every screen reads the program through that layer, so a changed set count
immediately moves the day's target and the week's completion state.

| Action                    | What happens                                                               |
| ------------------------- | -------------------------------------------------------------------------- |
| Edit a program exercise   | Only the fields you changed are stored; "Reset" restores it                |
| Add an exercise           | Appended to the day, counts toward its set target                          |
| Remove a program exercise | Hidden, logged sets kept, listed under "Removed from this day" to put back |
| Delete an added exercise  | Removed along with everything logged against it                            |
| Reorder                   | Drag handles in the day editor                                             |
| Reset day                 | Everything back to the printed program                                     |

**Swapping a movement resets its history.** Each logged set records the movement
name, and the "last time" hint only matches sets logged under the current name.
Change Hack Squat to Pendulum Squat and the hint goes blank rather than
prefilling a load you lifted on a different machine.

## The program never ends

The workbook stops at week 5. This app does not: weeks count up forever.

| Week  | 1           | 2     | 3       | 4    | 5    | 6           | 7     | …   | 10   | 11          |
| ----- | ----------- | ----- | ------- | ---- | ---- | ----------- | ----- | --- | ---- | ----------- |
| Block | 1           | 1     | 1       | 1    | 1    | 2           | 2     |     | 2    | 3           |
| Phase | Calibration | Build | Load up | Peak | Push | Calibration | Build |     | Push | Calibration |

Week 1 of every block after the first shows a reminder to swap one exercise per
day and start 2-3% above the previous block's week-4 loads. Use the `‹ ›` arrows
in the header, the week strip, or Settings → _Jump to a week_ to move around;
there is no upper bound.

### Deload weeks are switched off

The workbook deloads on week 5 of each block at half volume. That is currently
disabled at the user's request: every week runs the full prescription, and the
fifth week is an ordinary training week labelled _Push_.

It is one flag — `Program.deloadEnabled` in [`lib/program.dart`](lib/program.dart).
Set it back to `true` and the half-set maths, the "half sets" header, the
dimmed deload bars on the Progress chart, the `· deload` week labels and the
workbook's deload copy all come back; nothing else needs touching. The tests in
`widget_test.dart` assert the current (off) behaviour and would need flipping
back with it.

## Arabic and English

Tap **Settings → Language** to switch. The whole app flips, including right-to-left
layout, and the choice is remembered. Everything is translated — not just the
chrome, but the exercise names, muscles, coaching notes, phase guidance, the
weekly volume table and the full guide.

Arabic renders in **Zain** (SIL Open Font License; the licence ships in
`assets/fonts/OFL-Zain.txt`). English keeps the platform font, which handles
Latin text better than an Arabic-first face.

The translations live in [`lib/program_ar.dart`](lib/program_ar.dart) as a side
table keyed by the English ids, deliberately _not_ as fields on the program
data. `Exercise.name` is the identity written into `workout_set.movement` and
matched by the "last time" hint, so it must never change with the UI language —
`i18n_test.dart` asserts exactly that. An exercise you rename yourself keeps
your wording in both languages rather than snapping back to the Arabic original.

## Training at more than one gym

The exercise list is identical everywhere — what changes is what a number on a
machine means. 80 kg on one chest press is not 80 kg on another, so **loads are
tracked per gym**.

Pick where you are with the chip under the week strip (it also appears in the
session header and the session's info sheet). Every logged set records its gym,
and the "last time" hint only reads history from the gym you are standing in.

That matters more than it sounds: without it, arriving at a second gym would
offer you the first gym's load as the hint — and since tapping ✓ commits the
prefilled value, you would silently write a number you never lifted into your
log. At a gym with no history for that exercise the hint is simply blank.

The Progress chart gets a gym filter once you have more than one, because
tonnage from two gyms is not comparable and a gym switch would otherwise read
as a stall.

Deleting a gym keeps its logged sets — they still count toward your totals —
but they stop feeding any gym's hint. Upgrading from an older version files all
your existing sets under the first gym, so nothing loses its history.

## Backup — read this before you uninstall

The database lives in the app's private storage (`/data/data/<pkg>/databases` on
Android, the app's `Documents` folder on iOS). **Uninstalling the app, or
"Clear storage", deletes everything.** Android Auto Backup is nominally enabled
but only restores on a Play install, so it will not help a sideloaded APK.

So: **Settings → Export a backup**. It writes every set, week log and exercise
edit to a dated JSON file and opens the share sheet — save it to Files, Drive,
or mail it to yourself. **Settings → Restore a backup** reads one back.

Backups from older versions still import. The envelope is still `format: 1`,
a table the old export did not have (`gym`) comes in empty, and a restore always
ends by making sure a gym exists. Sets imported without a gym match every gym in
the "last time" lookup, so nothing logged before gyms existed is stranded —
though the Progress chart's per-gym filter will not show them, only _All gyms_.

A restore **replaces** everything currently in the app rather than merging, and
says what it found — sets, weeks, edited exercises, export date — before you
confirm. The file is validated on the way in: anything that isn't a Lift Log
backup is refused by name, and individual damaged rows are skipped and counted
instead of failing the whole import. The write happens in a single transaction,
so a restore either lands completely or leaves your data untouched.

## Data

Everything is local SQLite (`sqflite`), no account and no network.

```
gym             (id, name, created_at)
workout_set     (week, day_id, exercise_id, set_index, kg, reps, done, movement,
                 gym_id, logged_at)
exercise_custom (exercise_id, day_id, name, muscle, sets, reps, rir, rest, note,
                 position, hidden, is_custom)
week_log        (week, bodyweight, sleep, feel)
setting         (key, value)
```

`workout_set` is unique on `(week, day_id, exercise_id, set_index)`, so a set is
upserted as you type. Sets, tonnage and the "last time" hint are all derived
with SQL rather than stored, so nothing can drift out of sync.

In `exercise_custom` a null column means "use the program's value". Schema is at
version 3 and older databases are migrated in place: v1 gains `movement`, v2
gains `gym` plus `gym_id` with every existing set backfilled to the first gym.

## Layout

```
lib/
  program.dart               the workbook as data + the infinite-week maths
  db.dart                    SQLite schema and every query
  exercise_store.dart        the program with the user's edits layered on top
  backup.dart                export envelope, validation, restore
  i18n.dart                  UI strings, locale and direction
  program_ar.dart            Arabic for the whole program
  app_state.dart             selected week + change notifications
  theme.dart                 dark palette and shared widgets
  screens/
    train_screen.dart        week strip, the 5 day cards, settings
    session_screen.dart      set logging and the rest timer
    edit_day_screen.dart     reorder / add / remove / reset a day
    progress_screen.dart     tonnage chart, week log, volume reference
    guide_screen.dart        programming notes
  widgets/
    exercise_form.dart       the edit sheet
    gym_picker.dart          pick / add / rename / delete gyms
    backup_actions.dart      export / import flows
test/
  widget_test.dart           week/block maths, deload stays off
  exercise_edit_test.dart    edits, reordering, history, v1 -> v2 migration
  backup_test.dart           round trip, replace semantics, malformed files
  gym_test.dart              per-gym history, filtering, v2 -> v3 migration
  i18n_test.dart             Arabic coverage; identity never moves with language
```

## Icon and credits

The launcher icon is generated from `assets/icon/icon.png` by
`flutter_launcher_icons` (`dart run flutter_launcher_icons` after changing it),
with an adaptive foreground and the app's own near-black background.

Built by **Mo Khudari** — see Settings → About in the app.

## Run it

```bash
flutter run
```

Build a release APK:

```bash
flutter build apk --release
```

Tests:

```bash
flutter test
```

## Using it in the gym

Fill in the load and reps of each set as you do it and tap ✓ — the rest timer
starts on its own. Long-press **+ add set** to drop the last set of an exercise.
On Smith machine lifts log plate weight only and stay consistent; what matters
is that the number goes up.
