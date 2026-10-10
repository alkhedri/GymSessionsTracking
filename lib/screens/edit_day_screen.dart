import 'package:flutter/material.dart';

import '../app_state.dart';
import '../exercise_store.dart';
import '../program.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/exercise_form.dart';

/// Reorder, edit, add and remove the exercises of one training day.
class EditDayScreen extends StatefulWidget {
  final String dayId;
  final int week;
  const EditDayScreen({super.key, required this.dayId, required this.week});

  @override
  State<EditDayScreen> createState() => _EditDayScreenState();
}

class _EditDayScreenState extends State<EditDayScreen> {
  late final TrainingDay day = Program.dayById(widget.dayId);

  @override
  void initState() {
    super.initState();
    exerciseStore.addListener(_onStore);
  }

  @override
  void dispose() {
    exerciseStore.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  Future<void> _editExercise(Exercise ex) async {
    final edited = await showExerciseForm(
      context,
      exercise: ex,
      title: L.editExercise,
      programDefault: exerciseStore.programDefault(day.id, ex.id),
    );
    if (edited == null) return;
    await exerciseStore.edit(day.id, edited);
    appState.dataChanged();
  }

  Future<void> _addExercise() async {
    const blank = Exercise(
      id: '',
      name: '',
      muscle: '',
      sets: 3,
      reps: '8-12',
      rir: '1-2',
      rest: 120,
      note: '',
    );
    final draft = await showExerciseForm(
      context,
      exercise: blank,
      title: L.addExercise,
    );
    if (draft == null) return;
    await exerciseStore.addExercise(day.id, draft);
    appState.dataChanged();
  }

  Future<void> _remove(Exercise ex) async {
    final custom = exerciseStore.isCustom(ex.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('${custom ? L.delete : L.remove}: ${ex.displayName}'),
        content: Text(custom
            ? L.pick(
                'This exercise and everything you logged against it will be deleted.',
                'سيُحذف هذا التمرين وكل ما سجّلته عليه.')
            : L.pick(
                'It comes out of this session. Sets you already logged are kept, and you can put it back from this screen.',
                'سيخرج من هذه الحصة. تبقى المجموعات التي سجّلتها، ويمكنك إرجاعه من هذه الشاشة.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(custom ? L.delete : L.remove,
                style: const TextStyle(color: AppColors.hot)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await exerciseStore.remove(day.id, ex.id);
    appState.dataChanged();
  }

  Future<void> _resetDay() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('${L.resetToProgram}?'),
        content: Text(L.pick(
            'Every exercise goes back to the printed program. Exercises you added are deleted along with their logged sets; logs against the program exercises are kept.',
            'يعود كل تمرين إلى البرنامج الأصلي. التمارين التي أضفتها تُحذف مع مجموعاتها المسجّلة، وتبقى سجلات تمارين البرنامج.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L.reset,
                style: const TextStyle(color: AppColors.hot)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await exerciseStore.resetDay(day.id);
    appState.dataChanged();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = exerciseStore.forDay(day.id);
    final hidden = exerciseStore.hiddenIn(day.id);
    final target = exerciseStore.targetSets(day.id, widget.week);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(L.editSession),
            const SizedBox(height: 1),
            Text('${day.displayShort} · ${day.displayName}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          if (exerciseStore.isEdited(day.id))
            IconButton(
              tooltip: L.resetToProgram,
              icon: const Icon(Icons.settings_backup_restore),
              onPressed: _resetDay,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            '${L.sets(target)} · ${L.week(widget.week)}'
            '${Program.isDeload(widget.week) ? ' (${L.halfSets})' : ''}. '
            '${L.dragToReorder}',
            style: const TextStyle(
                fontSize: 13, height: 1.5, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: exercises.length,
            onReorder: (from, to) async {
              final list = [...exercises];
              if (to > from) to -= 1;
              list.insert(to, list.removeAt(from));
              await exerciseStore.reorder(day.id, list);
              appState.dataChanged();
            },
            itemBuilder: (_, i) => Padding(
              key: ValueKey(exercises[i].id),
              padding: const EdgeInsets.only(bottom: 10),
              child: _row(exercises[i], i),
            ),
          ),
          const SizedBox(height: 4),
          Panel(
            onTap: _addExercise,
            color: AppColors.bg2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, size: 19, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(L.addExercise,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent)),
              ],
            ),
          ),
          if (hidden.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionLabel(L.removedFromDay),
            const SizedBox(height: 10),
            for (final ex in hidden)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Panel(
                  padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(ex.displayName,
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.muted)),
                      ),
                      TextButton(
                        onPressed: () async {
                          await exerciseStore.restore(day.id, ex.id);
                          appState.dataChanged();
                        },
                        child: Text(L.putBack,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(Exercise ex, int index) {
    final custom = exerciseStore.isCustom(ex.id);
    final edited = !custom && exerciseStore.overrideFor(ex.id) != null;

    return Panel(
      onTap: () => _editExercise(ex),
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child:
                  Icon(Icons.drag_handle, size: 20, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(ex.displayName,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              height: 1.25)),
                    ),
                    if (custom || edited) ...[
                      const SizedBox(width: 6),
                      Pill(custom ? L.added : L.edited, highlight: true),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  '${ex.displayMuscle} · ${ex.sets} × ${ex.reps} · ${L.rir} ${ex.rir} · ${L.restLabel(ex.restLabel)}',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
            onPressed: () => _remove(ex),
          ),
        ],
      ),
    );
  }
}
