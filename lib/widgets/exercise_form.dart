import 'package:flutter/material.dart';

import '../program.dart';
import '../i18n.dart';
import '../theme.dart';

/// Full-height sheet for editing one exercise. Returns the edited [Exercise],
/// or null if the user backed out.
Future<Exercise?> showExerciseForm(
  BuildContext context, {
  required Exercise exercise,
  required String title,
  Exercise? programDefault,
}) =>
    showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ExerciseForm(
        exercise: exercise,
        title: title,
        programDefault: programDefault,
      ),
    );

class _ExerciseForm extends StatefulWidget {
  final Exercise exercise;
  final String title;
  final Exercise? programDefault;

  const _ExerciseForm({
    required this.exercise,
    required this.title,
    this.programDefault,
  });

  @override
  State<_ExerciseForm> createState() => _ExerciseFormState();
}

class _ExerciseFormState extends State<_ExerciseForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.exercise.name);
  late final _muscle = TextEditingController(text: widget.exercise.muscle);
  late final _sets = TextEditingController(text: '${widget.exercise.sets}');
  late final _reps = TextEditingController(text: widget.exercise.reps);
  late final _rir = TextEditingController(text: widget.exercise.rir);
  late final _note = TextEditingController(text: widget.exercise.note);
  late int _rest = widget.exercise.rest;

  static const _restChoices = [45, 60, 75, 90, 120, 150, 180, 240];

  @override
  void dispose() {
    for (final c in [_name, _muscle, _sets, _reps, _rir, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      widget.exercise.copyWith(
        name: _name.text.trim(),
        muscle: _muscle.text.trim(),
        sets: int.parse(_sets.text.trim()),
        reps: _reps.text.trim(),
        rir: _rir.text.trim(),
        rest: _rest,
        note: _note.text.trim(),
      ),
    );
  }

  void _revert() {
    final d = widget.programDefault;
    if (d == null) return;
    setState(() {
      _name.text = d.name;
      _muscle.text = d.muscle;
      _sets.text = '${d.sets}';
      _reps.text = d.reps;
      _rir.text = d.rir;
      _note.text = d.note;
      _rest = d.rest;
    });
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    if (widget.programDefault != null)
                      TextButton(
                        onPressed: _revert,
                        child: Text(L.reset,
                            style: const TextStyle(fontSize: 13)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  children: [
                    _label(L.exercise),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                          hintText: L.pick('e.g. Pendulum Squat',
                              'مثال: سكوات بندول')),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? L.giveItAName : null,
                    ),
                    const SizedBox(height: 6),
                    Text(L.renameWarning,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted)),
                    const SizedBox(height: 14),
                    _label(L.muscle),
                    TextFormField(
                      controller: _muscle,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                          hintText: L.pick('e.g. Quads',
                              'مثال: رباعية الفخذ')),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(L.setsField),
                              TextFormField(
                                controller: _sets,
                                keyboardType: TextInputType.number,
                                decoration:
                                    const InputDecoration(hintText: '3'),
                                validator: (v) {
                                  final n = int.tryParse(v?.trim() ?? '');
                                  if (n == null || n < 1 || n > 12) {
                                    return '1-12';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(L.reps),
                              TextFormField(
                                controller: _reps,
                                decoration:
                                    const InputDecoration(hintText: '8-12'),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? L.required
                                        : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(L.rir),
                              TextFormField(
                                controller: _rir,
                                decoration:
                                    const InputDecoration(hintText: '1-2'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _label(L.restBetweenSets),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in _restChoices)
                          _restChip(r),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _label(L.coachingNote),
                    TextFormField(
                      controller: _note,
                      maxLines: 4,
                      minLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          InputDecoration(hintText: L.coachingNoteHint),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: const Color(0xFF191400),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(L.save,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    SizedBox(
                        height: MediaQuery.paddingOf(context).bottom + 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _restChip(int seconds) {
    final on = _rest == seconds;
    final label = seconds % 60 == 0
        ? '${seconds ~/ 60} ${L.minShort}'
        : seconds > 60
            ? '${(seconds / 60).toStringAsFixed(1)} ${L.minShort}'
            : '$seconds ${L.secShort}';
    return InkWell(
      onTap: () => setState(() => _rest = seconds),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.accent : AppColors.card,
          border: Border.all(color: on ? AppColors.accent : AppColors.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: on ? const Color(0xFF191400) : AppColors.muted)),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: SectionLabel(text),
      );
}
