import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../backup.dart';
import '../i18n.dart';
import '../theme.dart';

/// Writes the whole database to a JSON file and hands it to the share sheet,
/// so it can go to Files, Drive, email — wherever the user keeps things.
Future<void> runExport(BuildContext context) async {
  try {
    final json = await Backup.export();
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, Backup.suggestedFileName()));
    await file.writeAsString(json);

    if (!context.mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final result = await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      fileNameOverrides: [Backup.suggestedFileName()],
      subject: 'Lift Log backup',
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ));

    if (!context.mounted) return;
    if (result.status == ShareResultStatus.success) {
      _toast(context, L.backupSaved);
    }
  } catch (e) {
    if (!context.mounted) return;
    _toast(context, L.couldNotExport('$e'));
  }
}

/// Picks a backup file, shows what is in it, and only then replaces anything.
Future<void> runImport(BuildContext context) async {
  try {
    final picked = await openFile(acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Lift Log backup',
        extensions: ['json'],
        mimeTypes: ['application/json'],
        uniformTypeIdentifiers: ['public.json'],
      ),
    ]);
    if (picked == null) return;

    final source = await picked.readAsString();
    final summary = Backup.inspect(source);

    if (!context.mounted) return;
    final ok = await _confirm(context, summary);
    if (ok != true) return;

    await Backup.restore(summary);
    if (!context.mounted) return;
    _toast(context, L.restoredSets(summary.sets));
  } on BackupFormatException catch (e) {
    if (!context.mounted) return;
    _toast(context, e.message);
  } catch (e) {
    if (!context.mounted) return;
    _toast(context, L.couldNotImport('$e'));
  }
}

Future<bool?> _confirm(BuildContext context, BackupSummary s) {
  final when = s.exportedAt;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(L.restoreQ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(L.backupSets(s.sets)),
          _line(L.backupWeeks(s.weeks)),
          if (s.editedExercises > 0)
            _line(L.backupEdits(s.editedExercises)),
          if (when != null)
            _line('exported ${when.day}/${when.month}/${when.year}'),
          if (s.skippedRows > 0)
            _line(L.backupSkipped(s.skippedRows)),
          const SizedBox(height: 12),
          Text(L.backupReplaceWarning,
              style: const TextStyle(
                  fontSize: 13, height: 1.45, color: AppColors.hot)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L.cancel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(L.replace),
        ),
      ],
    ),
  );
}

Widget _line(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text('· $text', style: const TextStyle(fontSize: 14)),
    );

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 3),
  ));
}
