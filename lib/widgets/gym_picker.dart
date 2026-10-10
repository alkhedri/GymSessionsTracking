import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../i18n.dart';
import '../theme.dart';

/// Pick where you are training, and manage the list.
Future<void> showGymPicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _GymPicker(),
    );

class _GymPicker extends StatefulWidget {
  const _GymPicker();

  @override
  State<_GymPicker> createState() => _GymPickerState();
}

class _GymPickerState extends State<_GymPicker> {
  Future<void> _refresh() async {
    await appState.loadGyms();
    if (mounted) setState(() {});
  }

  Future<String?> _askName({String initial = '', required String title}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: L.gymNameHint),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(L.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(L.save),
          ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final name = await _askName(title: L.addGym);
    if (name == null || name.isEmpty) return;
    final id = await GymDb.instance.addGym(name);
    await appState.loadGyms();
    await appState.setGym(id);
    if (mounted) setState(() {});
  }

  Future<void> _rename(Gym g) async {
    final name = await _askName(title: L.renameGym, initial: g.name);
    if (name == null || name.isEmpty) return;
    await GymDb.instance.renameGym(g.id, name);
    await _refresh();
  }

  Future<void> _delete(Gym g) async {
    if (appState.gyms.length <= 1) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(L.deleteGymQ(g.name)),
        content: Text(L.deleteGymBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L.delete,
                style: const TextStyle(color: AppColors.hot)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await GymDb.instance.deleteGym(g.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final gyms = appState.gyms;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(L.whereTraining,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(L.gymsExplainer,
                style: const TextStyle(
                    fontSize: 12.5, height: 1.45, color: AppColors.muted)),
            const SizedBox(height: 14),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final g in gyms) _row(g),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Panel(
              onTap: _add,
              color: AppColors.bg2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, size: 19, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(L.addGym,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Gym g) {
    final on = g.id == appState.gymId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        color: on ? AppColors.card2 : AppColors.card,
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        onTap: () async {
          await appState.setGym(g.id);
          if (mounted) Navigator.pop(context);
        },
        child: Row(
          children: [
            Icon(on ? Icons.check_circle : Icons.circle_outlined,
                size: 19, color: on ? AppColors.accent : AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(g.name,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500)),
            ),
            IconButton(
              tooltip: L.renameGym,
              icon: const Icon(Icons.edit_outlined,
                  size: 17, color: AppColors.muted),
              onPressed: () => _rename(g),
            ),
            if (appState.gyms.length > 1)
              IconButton(
                tooltip: L.delete,
                icon: const Icon(Icons.close,
                    size: 17, color: AppColors.muted),
                onPressed: () => _delete(g),
              ),
          ],
        ),
      ),
    );
  }
}
