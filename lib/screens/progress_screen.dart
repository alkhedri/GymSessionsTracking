import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../db.dart';
import '../exercise_store.dart';
import '../program.dart';
import '../i18n.dart';
import '../theme.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Map<int, Map<String, DayStat>> _byWeek = {};
  Map<int, WeekLog> _logs = {};
  final Map<String, TextEditingController> _ctrls = {};
  final Map<int, Timer> _debounce = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    appState.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    appState.removeListener(_load);
    for (final t in _debounce.values) {
      t.cancel();
    }
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _topWeek =>
      appState.week > appState.maxWeek ? appState.week : appState.maxWeek;

  /// null = every gym combined
  int? _filterGym;

  Future<void> _load() async {
    final byWeek = await GymDb.instance.allByWeekDay(gymId: _filterGym);
    final logs = await GymDb.instance.weekLogs(1, _topWeek);
    if (!mounted) return;
    setState(() {
      _byWeek = byWeek;
      _logs = logs;
      _loading = false;
    });
  }

  ({int sets, double tonnage, int sessions}) _week(int week) {
    final days = _byWeek[week] ?? const <String, DayStat>{};
    int sets = 0, sessions = 0;
    double tonnage = 0;
    for (final d in Program.days) {
      final s = days[d.id] ?? DayStat.empty;
      sets += s.sets;
      tonnage += s.tonnage;
      if (s.sets > 0 && s.sets >= exerciseStore.targetSets(d.id, week)) sessions++;
    }
    return (sets: sets, tonnage: tonnage, sessions: sessions);
  }

  /// Hold the edited object itself — a reload may have replaced the map entry.
  void _saveLog(int week, WeekLog log) {
    _debounce[week]?.cancel();
    _debounce[week] = Timer(const Duration(milliseconds: 400),
        () => GymDb.instance.saveWeekLog(week, log));
  }

  TextEditingController _ctrl(String key, String initial) =>
      _ctrls.putIfAbsent(key, () => TextEditingController(text: initial));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final top = _topWeek;
    // newest first, so the current week is always the first card
    final weeks = [for (int w = top; w >= 1; w--) w];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _header()),
        if (appState.gyms.length > 1)
          SliverToBoxAdapter(child: _gymFilter()),
        SliverToBoxAdapter(child: _chart(top)),
        SliverList.builder(
          itemCount: weeks.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _weekCard(weeks[i]),
          ),
        ),
        SliverToBoxAdapter(child: _volume()),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel('${L.weeksIn(_topWeek)} · ${Program.blockLabel(_topWeek)}'),
            const SizedBox(height: 2),
            Text(L.progress,
                style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5)),
          ],
        ),
      );

  /// Tonnage from two gyms is not comparable — the same machine reads a
  /// different number — so a gym switch would otherwise look like a stall.
  Widget _gymFilter() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip(L.allGyms, null),
              for (final g in appState.gyms) _filterChip(g.name, g.id),
            ],
          ),
        ),
      );

  Widget _filterChip(String label, int? id) {
    final on = _filterGym == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() => _filterGym = id);
          _load();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
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
      ),
    );
  }

  /// Tonnage bars for the last 10 weeks, oldest to newest.
  Widget _chart(int top) {
    final from = top - 9 < 1 ? 1 : top - 9;
    final weeks = [for (int w = from; w <= top; w++) w];
    final values = {for (final w in weeks) w: _week(w).tonnage};
    final max = values.values.fold<double>(1, (m, v) => v > m ? v : m);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(L.tonnageByWeek),
            const SizedBox(height: 12),
            SizedBox(
              height: 128,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final w in weeks)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              values[w]! > 0 ? fmtKg(values[w]!) : '',
                              style: const TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: (values[w]! / max * 84).clamp(3, 84),
                              decoration: BoxDecoration(
                                color: Program.isDeload(w)
                                    ? AppColors.accentDim
                                    : AppColors.accent,
                                border: Program.isDeload(w)
                                    ? Border.all(color: AppColors.accent)
                                    : null,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                  bottom: Radius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text('W$w',
                                style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekCard(int week) {
    final st = _week(week);
    final log = _logs.putIfAbsent(week, () => WeekLog());
    final days = _byWeek[week] ?? const <String, DayStat>{};
    final current = week == appState.week;

    return Panel(
      color: current ? AppColors.card2 : AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(L.week(week),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Text(
                      '${Program.blockLabel(week)}'
                      '${Program.isDeload(week) ? ' · ${L.pick('deload', 'تخفيف')}' : ''}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Text('${fmtKg(st.tonnage)} ${L.pick('kg', 'كجم')} · ${L.sets(st.sets)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  L.bodyweightKg,
                  _ctrl('$week:bw', fmtNum(log.bodyweight)),
                  (v) {
                    log.bodyweight = double.tryParse(v.replaceAll(',', '.'));
                    _saveLog(week, log);
                  },
                  numeric: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _field(
                  L.avgSleepH,
                  _ctrl('$week:sleep', fmtNum(log.sleep)),
                  (v) {
                    log.sleep = double.tryParse(v.replaceAll(',', '.'));
                    _saveLog(week, log);
                  },
                  numeric: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _field(L.howDidWeekFeel, _ctrl('$week:feel', log.feel), (v) {
            log.feel = v;
            _saveLog(week, log);
          }),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final d in Program.days) ...[
                Expanded(
                  child: Builder(builder: (_) {
                    final s = days[d.id] ?? DayStat.empty;
                    final full =
                        s.sets > 0 && s.sets >= exerciseStore.targetSets(d.id, week);
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color:
                            full ? AppColors.accentDim : AppColors.bg2,
                        border: Border.all(
                            color: full ? AppColors.accent : AppColors.line),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        d.displayShort.replaceAll(RegExp(r'[^0-9]'), ''),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color:
                                full ? AppColors.accent : AppColors.muted),
                      ),
                    );
                  }),
                ),
                if (d != Program.days.last) const SizedBox(width: 5),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
          ValueChanged<String> onChanged,
          {bool numeric = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            onChanged: onChanged,
            keyboardType: numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: const TextStyle(fontSize: 15),
            decoration: const InputDecoration(hintText: '—'),
          ),
        ],
      );

  Widget _volume() {
    final maxSets = Program.volume
        .fold<int>(1, (m, v) => v.sets > m ? v.sets : m);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(L.weeklyHardSets),
            const SizedBox(height: 6),
            Text(L.directSetsOnly,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 12),
            for (final v in Program.volume)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    SizedBox(
                      width: 82,
                      child: Text(v.displayMuscle,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppColors.bg2,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: v.sets / maxSets,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 68,
                      child: Text('${v.sets} / ${v.displayTarget}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.muted)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(L.volumeFooter,
                style: const TextStyle(
                    fontSize: 12, height: 1.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
