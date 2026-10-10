import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../exercise_store.dart';
import '../program.dart';
import '../i18n.dart';
import '../theme.dart';
import '../widgets/backup_actions.dart';
import '../widgets/gym_picker.dart';
import 'edit_day_screen.dart';
import 'session_screen.dart';

class TrainScreen extends StatefulWidget {
  const TrainScreen({super.key});

  @override
  State<TrainScreen> createState() => _TrainScreenState();
}

class _TrainScreenState extends State<TrainScreen> {
  Map<String, DayStat> _byDay = {};
  final _weekStrip = ScrollController();

  @override
  void initState() {
    super.initState();
    appState.addListener(_refresh);
    _refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) => _centreWeek());
  }

  @override
  void dispose() {
    appState.removeListener(_refresh);
    _weekStrip.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final data = await GymDb.instance.weekByDay(appState.week);
    if (mounted) setState(() => _byDay = data);
  }

  void _centreWeek() {
    if (!_weekStrip.hasClients) return;
    const chip = 86.0;
    final target = (appState.week - 1) * chip - 100;
    _weekStrip.jumpTo(target.clamp(0, _weekStrip.position.maxScrollExtent));
  }

  int get _weekCount => (appState.week > appState.maxWeek
          ? appState.week
          : appState.maxWeek) +
      5;

  @override
  Widget build(BuildContext context) {
    final week = appState.week;
    final phase = Program.phaseOf(week);
    final opener = Program.blockOpener(week);

    int totalSets = 0;
    double tonnage = 0;
    int doneSessions = 0;
    for (final d in Program.days) {
      final s = _byDay[d.id] ?? DayStat.empty;
      totalSets += s.sets;
      tonnage += s.tonnage;
      if (s.sets >= exerciseStore.targetSets(d.id, week)) doneSessions++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(week),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              SizedBox(
                height: 58,
                child: ListView.separated(
                  controller: _weekStrip,
                  scrollDirection: Axis.horizontal,
                  itemCount: _weekCount,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _weekChip(i + 1),
                ),
              ),
              const SizedBox(height: 10),
              _gymChip(),
              const SizedBox(height: 10),
              Text(phase.displayNote,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.5, color: AppColors.muted)),
              if (opener != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim.withValues(alpha: 0.45),
                    border: Border.all(color: AppColors.accent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 16, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(opener,
                            style: const TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                color: AppColors.accent)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              for (final d in Program.days) ...[
                _dayCard(d, week),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 8),
              Panel(
                color: AppColors.bg2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(L.thisWeek),
                    const SizedBox(height: 10),
                    Row(children: [
                      StatTile('$doneSessions/5', L.sessions),
                      const SizedBox(width: 8),
                      StatTile('$totalSets', L.setsLogged),
                      const SizedBox(width: 8),
                      StatTile(fmtKg(tonnage), L.kgTonnage),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(int week) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(
                      '${Program.blockLabel(week)} · ${Program.phaseOf(week).displayTag}'),
                  const SizedBox(height: 2),
                  Text(L.appName,
                      style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5)),
                ],
              ),
            ),
            _roundBtn(Icons.chevron_left, () => appState.setWeek(week - 1)),
            const SizedBox(width: 6),
            _roundBtn(Icons.chevron_right, () => appState.setWeek(week + 1)),
            const SizedBox(width: 6),
            _roundBtn(Icons.settings_outlined, _openSettings),
          ],
        ),
      );

  Widget _gymChip() => InkWell(
        onTap: () async {
          await showGymPicker(context);
          _refresh();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.place_outlined,
                  size: 15, color: AppColors.accent),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  appState.gym?.name ?? L.setYourGym,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 16, color: AppColors.muted),
            ],
          ),
        ),
      );

  Widget _roundBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 19, color: AppColors.text),
        ),
      );

  Widget _weekChip(int n) {
    final on = n == appState.week;
    final phase = Program.phaseOf(n);
    return InkWell(
      onTap: () => appState.setWeek(n),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppColors.accent : AppColors.card,
          border: Border.all(color: on ? AppColors.accent : AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(L.week(n),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: on ? const Color(0xFF191400) : AppColors.text)),
            const SizedBox(height: 1),
            Text(phase.displayTag.toUpperCase(),
                style: TextStyle(
                    fontSize: 8.5,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    color:
                        on ? const Color(0xFF191400) : AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _dayCard(TrainingDay d, int week) {
    final st = _byDay[d.id] ?? DayStat.empty;
    final target = exerciseStore.targetSets(d.id, week);
    final complete = st.sets >= target;
    final started = st.sets > 0;

    return Panel(
      padding: const EdgeInsets.all(14),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SessionScreen(dayId: d.id, week: week),
        ));
        _refresh();
      },
      onLongPress: () async {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => EditDayScreen(dayId: d.id, week: week),
        ));
        _refresh();
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: complete
                  ? AppColors.good
                  : started
                      ? AppColors.accentDim
                      : AppColors.bg2,
              border: Border.all(
                  color: complete
                      ? AppColors.good
                      : started
                          ? AppColors.accent
                          : AppColors.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: complete
                ? const Icon(Icons.check, size: 22, color: Color(0xFF04240F))
                : Text(d.displayShort.replaceAll(RegExp(r'[^0-9]'), ''),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color:
                            started ? AppColors.accent : AppColors.muted)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${d.displayShort} · ${d.displayName}',
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2)),
                const SizedBox(height: 3),
                Text(
                  '${d.displayFocus} · ${L.sets(target)} · ${L.minutes(d.minutes)}'
                  '${started ? ' · ${L.doneOf(st.sets, target)}' : ''}',
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.35, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
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
              Text(L.settings,
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              _sheetRow(
                L.jumpToWeek,
                L.currentlyWeek(appState.week),
                Icons.calendar_today_outlined,
                () {
                  Navigator.pop(sheetCtx);
                  _askWeek();
                },
              ),
              _sheetRow(
                L.language,
                L.isAr ? 'العربية' : 'English',
                Icons.translate,
                () async {
                  Navigator.pop(sheetCtx);
                  await appState
                      .setLang(L.isAr ? AppLang.en : AppLang.ar);
                  _refresh();
                },
              ),
              _sheetRow(
                L.about,
                L.author,
                Icons.info_outline,
                () {
                  Navigator.pop(sheetCtx);
                  _showAbout();
                },
              ),
              _sheetRow(
                L.exportBackup,
                L.exportSub,
                Icons.ios_share,
                () {
                  Navigator.pop(sheetCtx);
                  runExport(context);
                },
              ),
              _sheetRow(
                L.restoreBackup,
                L.restoreSub,
                Icons.download_outlined,
                () {
                  Navigator.pop(sheetCtx);
                  runImport(context);
                },
              ),
              _sheetRow(
                L.eraseAll,
                L.eraseSub,
                Icons.delete_outline,
                () async {
                  Navigator.pop(sheetCtx);
                  final ok = await _confirmWipe();
                  if (!ok) return;
                  await GymDb.instance.wipe();
                  await appState.setWeek(1);
                  appState.dataChanged();
                },
                danger: true,
              ),
              const SizedBox(height: 8),
              Text(L.storageNote,
                  style: const TextStyle(
                      fontSize: 12, height: 1.45, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetRow(String title, String sub, IconData icon, VoidCallback onTap,
          {bool danger = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Panel(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon,
                  size: 19, color: danger ? AppColors.hot : AppColors.text),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        color: danger ? AppColors.hot : AppColors.text)),
              ),
              Text(sub,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.muted)),
            ],
          ),
        ),
      );

  void _showAbout() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.fitness_center,
                      size: 34, color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(L.appName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(L.aboutBlurb,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: AppColors.muted)),
              ),
              const SizedBox(height: 18),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionLabel(L.createdBy),
                    const SizedBox(height: 6),
                    Text(L.author,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('${L.version} ',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.muted)),
                        const Text('1.0.0',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Panel(
                color: AppColors.bg2,
                child: Text(
                  '${Program.displayTitle} · ${Program.displaySubtitle}',
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.5, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _askWeek() async {
    final ctrl = TextEditingController(text: '${appState.week}');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(L.jumpToWeek),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: L.weekNumber),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(L.cancel)),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: Text(L.go),
          ),
        ],
      ),
    );
    if (value != null && value >= 1) {
      await appState.setWeek(value);
      _centreWeek();
    }
  }

  Future<bool> _confirmWipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(L.eraseQ),
        content: Text(L.eraseBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L.erase,
                style: const TextStyle(color: AppColors.hot)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
