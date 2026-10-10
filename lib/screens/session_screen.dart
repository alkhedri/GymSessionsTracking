import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../db.dart';
import '../exercise_store.dart';
import '../program.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/exercise_form.dart';
import '../widgets/gym_picker.dart';
import 'edit_day_screen.dart';

class SessionScreen extends StatefulWidget {
  final String dayId;
  final int week;
  const SessionScreen({super.key, required this.dayId, required this.week});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with WidgetsBindingObserver {
  late final TrainingDay day = Program.dayById(widget.dayId);

  final Map<String, List<SetEntry>> _sets = {};
  final Map<String, PrevBest?> _prev = {};
  final Map<String, TextEditingController> _ctrls = {};
  final Set<String> _openNotes = {};
  bool _loading = true;

  int? _lastGymId;

  Timer? _restTimer;
  DateTime? _restEndsAt;
  String _restLabel = '';
  bool _restAlerted = false;

  /// The day as the user has edited it, not as the workbook prints it.
  List<Exercise> get _exercises => exerciseStore.forDay(widget.dayId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    exerciseStore.addListener(_load);
    _lastGymId = appState.gymId;
    appState.addListener(_onAppState);
    _load();
  }

  /// Only a gym switch needs a reload; appState also fires on every logged set.
  void _onAppState() {
    if (appState.gymId != _lastGymId) {
      _lastGymId = appState.gymId;
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appState.removeListener(_onAppState);
    exerciseStore.removeListener(_load);
    _restTimer?.cancel();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final stored = await GymDb.instance.loadSession(widget.week, widget.dayId);
    for (final ex in _exercises) {
      final rows = stored[ex.id] ?? <SetEntry>[];
      final target = ex.targetSets(widget.week);
      final byIndex = {for (final s in rows) s.index: s};
      final count = rows.isEmpty
          ? target
          : (rows.map((s) => s.index).reduce((a, b) => a > b ? a : b) + 1)
              .clamp(target, 99);
      _sets[ex.id] = List.generate(
        count,
        (i) => byIndex[i] ?? SetEntry(index: i),
      );
      _prev[ex.id] = await GymDb.instance
          .lastBest(ex.id, ex.name, widget.week, gymId: appState.gymId);
    }
    if (mounted) setState(() => _loading = false);
  }

  // ---- persistence ---------------------------------------------------------

  Future<void> _persist(Exercise ex, SetEntry s) async {
    await GymDb.instance.saveSet(
      week: widget.week,
      dayId: widget.dayId,
      exerciseId: ex.id,
      setIndex: s.index,
      movement: ex.name,
      gymId: appState.gymId,
      kg: s.kg,
      reps: s.reps,
      done: s.done,
    );
    // Only a completed set moves any total, so don't wake the other tabs on
    // every keystroke.
    if (s.done) appState.dataChanged();
  }

  TextEditingController _ctrl(String key, String initial) =>
      _ctrls.putIfAbsent(key, () => TextEditingController(text: initial));

  int _doneCount(Exercise ex) =>
      (_sets[ex.id] ?? []).where((s) => s.done).length;

  ({int sets, double tonnage}) get _stats {
    int n = 0;
    double t = 0;
    for (final list in _sets.values) {
      for (final s in list) {
        if (s.done) {
          n++;
          t += s.tonnage;
        }
      }
    }
    return (sets: n, tonnage: t);
  }

  // ---- rest timer ----------------------------------------------------------

  /// Seconds left, derived from the deadline rather than counted down, so
  /// backgrounding the app or locking the screen cannot freeze it — Android
  /// suspends the periodic timer, but the clock keeps moving.
  int get _restLeft {
    final end = _restEndsAt;
    if (end == null) return 0;
    final ms = end.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _startRest(Exercise ex) {
    setState(() {
      _restEndsAt = DateTime.now().add(Duration(seconds: ex.rest));
      _restLabel = ex.name;
      _restAlerted = false;
    });
    _runRestTicker();
  }

  void _runRestTicker() {
    _restTimer?.cancel();
    _restTimer =
        Timer.periodic(const Duration(milliseconds: 250), (_) => _tickRest());
  }

  void _tickRest() {
    if (!mounted || _restEndsAt == null) return;

    if (_restLeft <= 0 && !_restAlerted) {
      _restAlerted = true;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      _restTimer?.cancel();
      _restTimer = null;
      // leave "GO" up briefly, then clear the bar
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && _restAlerted && _restLeft <= 0) _stopRest();
      });
    }
    setState(() {});
  }

  /// Coming back from the background may be the first chance to notice the
  /// rest finished while we were away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _restEndsAt != null) {
      _tickRest();
    }
  }

  void _stopRest() {
    _restTimer?.cancel();
    _restTimer = null;
    setState(() {
      _restEndsAt = null;
      _restLabel = '';
      _restAlerted = false;
    });
  }

  void _adjustRest(int delta) {
    final end = _restEndsAt;
    if (end == null) return;
    final now = DateTime.now();
    // extend from the deadline, or from now if it already elapsed
    final from = end.isAfter(now) ? end : now;
    var next = from.add(Duration(seconds: delta));
    if (next.isBefore(now)) next = now;
    if (next.difference(now).inSeconds > 3600) {
      next = now.add(const Duration(hours: 1));
    }
    setState(() {
      _restEndsAt = next;
      if (next.isAfter(now)) _restAlerted = false;
    });
    if (_restTimer == null && next.isAfter(now)) _runRestTicker();
  }

  // ---- actions -------------------------------------------------------------

  Future<void> _toggleDone(Exercise ex, SetEntry s) async {
    if (s.done) {
      setState(() => s.done = false);
      _stopRest();
      await _persist(ex, s);
      return;
    }

    final prev = _prev[ex.id];
    s.kg ??= prev?.kg;
    s.reps ??= prev?.reps;
    if (s.reps == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.enterRepsFirst),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    _ctrl('${ex.id}:${s.index}:kg', '').text = fmtNum(s.kg);
    _ctrl('${ex.id}:${s.index}:reps', '').text = '${s.reps}';
    setState(() => s.done = true);
    HapticFeedback.selectionClick();
    await _persist(ex, s);
    _startRest(ex);
  }

  void _addSet(Exercise ex) {
    setState(() =>
        _sets[ex.id]!.add(SetEntry(index: _sets[ex.id]!.length)));
  }

  Future<void> _removeSet(Exercise ex) async {
    final list = _sets[ex.id]!;
    if (list.length <= 1) return;
    await GymDb.instance
        .deleteSet(widget.week, widget.dayId, ex.id, list.last.index);
    setState(() => list.removeLast());
    appState.dataChanged();
  }

  Future<void> _quickEdit(Exercise ex) async {
    final edited = await showExerciseForm(
      context,
      exercise: ex,
      title: L.editExercise,
      programDefault: exerciseStore.programDefault(widget.dayId, ex.id),
    );
    if (edited == null) return;
    await exerciseStore.edit(widget.dayId, edited);
    appState.dataChanged();
  }

  Future<void> _openDayEditor() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          EditDayScreen(dayId: widget.dayId, week: widget.week),
    ));
  }

  Future<void> _clearSession() async {
    await GymDb.instance.clearSession(widget.week, widget.dayId);
    for (final c in _ctrls.values) {
      c.text = '';
    }
    setState(() {
      for (final ex in _exercises) {
        _sets[ex.id] = List.generate(
            ex.targetSets(widget.week), (i) => SetEntry(index: i));
      }
    });
    appState.dataChanged();
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final week = widget.week;
    // Keeps the rest bar clear of the gesture bar / navigation buttons. Goes
    // to zero while the keyboard is up, since the Scaffold has already shrunk
    // the body above it.
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final target = exerciseStore.targetSets(widget.dayId, week);
    final st = _stats;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
                '${L.week(week)} · ${Program.phaseOf(week).displayTag}'
                '${Program.isDeload(week) ? ' · ${L.halfSets}' : ''}'
                '${appState.gym == null ? '' : ' · ${appState.gym!.name}'}'),
            const SizedBox(height: 1),
            Text('${day.displayShort} · ${day.displayName}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: L.editExercises,
            icon: const Icon(Icons.tune),
            onPressed: _openDayEditor,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: target == 0 ? 0 : (st.sets / target).clamp(0, 1),
            minHeight: 3,
            backgroundColor: AppColors.line,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(
                      16, 12, 16, (_restLabel.isEmpty ? 32 : 96) + safeBottom),
                  children: [
                    Text(day.displayIntro,
                        style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            color: AppColors.muted)),
                    const SizedBox(height: 14),
                    for (final ex in _exercises) ...[
                      _exerciseCard(ex),
                      const SizedBox(height: 12),
                    ],
                    Panel(
                      color: AppColors.bg2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionLabel(L.session),
                          const SizedBox(height: 10),
                          Row(children: [
                            StatTile('${st.sets}/$target', L.setsLabel),
                            const SizedBox(width: 8),
                            StatTile(fmtKg(st.tonnage), L.kgTonnage),
                            const SizedBox(width: 8),
                            StatTile('~${day.minutes}', L.minutesLabel),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_restLabel.isNotEmpty)
                  Positioned(
                      left: 12,
                      right: 12,
                      bottom: 16 + safeBottom,
                      child: _restBar()),
              ],
            ),
    );
  }

  Widget _exerciseCard(Exercise ex) {
    final target = ex.targetSets(widget.week);
    final list = _sets[ex.id] ?? [];
    final complete = _doneCount(ex) >= target;
    final prev = _prev[ex.id];
    final noteOpen = _openNotes.contains(ex.id);
    final index = _exercises.indexOf(ex) + 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onLongPress: () => _quickEdit(ex),
            child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: complete ? AppColors.good : AppColors.bg2,
                    border: Border.all(
                        color: complete ? AppColors.good : AppColors.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: complete
                      ? const Icon(Icons.check,
                          size: 15, color: Color(0xFF04240F))
                      : Text('$index',
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.displayName,
                          style: const TextStyle(
                              fontSize: 15.5,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2)),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          Pill(ex.displayMuscle, highlight: true),
                          Pill('$target × ${ex.reps}'),
                          Pill('${L.rir} ${ex.rir}'),
                          Pill(L.restLabel(ex.restLabel)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '${L.editExercise}: ${ex.displayName}',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 30, minHeight: 30),
                  icon: const Icon(Icons.edit_outlined,
                      size: 17, color: AppColors.muted),
                  onPressed: () => _quickEdit(ex),
                ),
              ],
            ),
            ),
          ),
          InkWell(
            onTap: () => setState(() =>
                noteOpen ? _openNotes.remove(ex.id) : _openNotes.add(ex.id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 0, 14, 12),
              child: noteOpen
                  ? Text(ex.displayNote,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.muted))
                  : Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: L.coachingNote,
                            style: const TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600)),
                        TextSpan(text: ' · ${L.tapToRead}'),
                      ]),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.muted)),
            ),
          ),
          Container(
            color: AppColors.bg2,
            child: Column(
              children: [
                for (final s in list) _setRow(ex, s, prev),
                InkWell(
                  onTap: () => _addSet(ex),
                  onLongPress: () => _removeSet(ex),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border:
                          Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: Text(L.addSet,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _setRow(Exercise ex, SetEntry s, PrevBest? prev) {
    final kgCtrl = _ctrl('${ex.id}:${s.index}:kg', fmtNum(s.kg));
    final repCtrl =
        _ctrl('${ex.id}:${s.index}:reps', s.reps == null ? '' : '${s.reps}');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text('${s.index + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 62,
            child: TextField(
              controller: kgCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: prev == null ? '—' : fmtNum(prev.kg),
                fillColor: AppColors.card,
              ),
              onChanged: (v) {
                s.kg = double.tryParse(v.replaceAll(',', '.'));
                _persist(ex, s);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(L.kgTimes,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
          SizedBox(
            width: 62,
            child: TextField(
              controller: repCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: prev == null ? '—' : '${prev.reps}',
                fillColor: AppColors.card,
              ),
              onChanged: (v) {
                s.reps = int.tryParse(v);
                _persist(ex, s);
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                s.index == 0 && prev != null
                    ? L.lastTime(fmtNum(prev.kg), prev.reps)
                    : '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
          ),
          InkWell(
            onTap: () => _toggleDone(ex, s),
            borderRadius: BorderRadius.circular(11),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: s.done ? AppColors.good : AppColors.card,
                border: Border.all(
                    color: s.done ? AppColors.good : AppColors.line),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.check,
                  size: 18,
                  color: s.done ? const Color(0xFF04240F) : AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _restBar() {
    final done = _restLeft <= 0;
    final m = (_restLeft ~/ 60), sec = _restLeft % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: done ? AppColors.good : AppColors.accent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          _restBtn('−15', () => _adjustRest(-15)),
          Expanded(
            child: Column(
              children: [
                Text('$m:${sec.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF191400),
                        letterSpacing: -0.5)),
                Text(done ? L.restGo : _restLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w700,
                        color: Color(0x99191400))),
              ],
            ),
          ),
          _restBtn('+15', () => _adjustRest(15)),
          const SizedBox(width: 6),
          _restBtn(L.skip, _stopRest),
        ],
      ),
    );
  }

  Widget _restBtn(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0x22000000),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF191400))),
        ),
      );

  void _showInfo() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${day.displayShort} · ${day.displayName}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  '${day.displayFocus} · ${L.sets(exerciseStore.targetSets(widget.dayId, widget.week))} · ${L.minutes(day.minutes)}',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.muted)),
              const SizedBox(height: 14),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${L.week(widget.week)} — ${Program.phaseOf(widget.week).displayTag}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(Program.phaseOf(widget.week).displayNote,
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Panel(
                onTap: () {
                  Navigator.pop(sheetCtx);
                  showGymPicker(context);
                },
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 19, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Text(L.changeGym,
                        style: const TextStyle(
                            color: AppColors.accent, fontSize: 15)),
                    const Spacer(),
                    Text(appState.gym?.name ?? '—',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Panel(
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _openDayEditor();
                },
                child: Row(
                  children: [
                    const Icon(Icons.tune, size: 19, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Text(L.editExercises,
                        style: const TextStyle(
                            color: AppColors.accent, fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Panel(
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _clearSession();
                },
                child: Row(
                  children: [
                    const Icon(Icons.restart_alt, size: 19, color: AppColors.hot),
                    const SizedBox(width: 12),
                    Text(L.clearSession,
                        style: const TextStyle(color: AppColors.hot, fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(L.longPressHint,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
