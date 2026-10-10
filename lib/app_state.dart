import 'package:flutter/foundation.dart';

import 'db.dart';
import 'i18n.dart';

/// Tiny global store: which week is selected, plus a revision counter that
/// screens listen to so a set logged on one tab refreshes the others.
class AppState extends ChangeNotifier {
  int week = 1;
  int maxWeek = 1;
  bool ready = false;

  /// Where you are training. Loads are tracked per gym, so this decides which
  /// history the "last time" hint reads from.
  List<Gym> gyms = [];
  int? gymId;

  Gym? get gym {
    for (final g in gyms) {
      if (g.id == gymId) return g;
    }
    return gyms.isEmpty ? null : gyms.first;
  }

  Future<void> setLang(AppLang value) async {
    if (value == L.lang) return;
    L.lang = value;
    await GymDb.instance.setSetting('lang', value.name);
    notifyListeners();
  }

  Future<void> load() async {
    await GymDb.instance.open();
    final saved = await GymDb.instance.getSetting('lang');
    L.lang = saved == AppLang.ar.name ? AppLang.ar : AppLang.en;
    week = await GymDb.instance.currentWeek();
    maxWeek = await GymDb.instance.maxLoggedWeek();
    if (maxWeek < week) maxWeek = week;
    await loadGyms();
    ready = true;
    notifyListeners();
  }

  Future<void> loadGyms() async {
    gyms = await GymDb.instance.gyms();
    gymId = await GymDb.instance.currentGymId();
    // a restored backup or a deleted gym can leave the pointer dangling
    if (gyms.isNotEmpty && !gyms.any((g) => g.id == gymId)) {
      gymId = gyms.first.id;
      await GymDb.instance.setCurrentGym(gymId!);
    }
    notifyListeners();
  }

  Future<void> setGym(int id) async {
    if (id == gymId) return;
    gymId = id;
    await GymDb.instance.setCurrentGym(id);
    notifyListeners();
  }

  Future<void> setWeek(int value) async {
    if (value < 1 || value == week) return;
    week = value;
    if (value > maxWeek) maxWeek = value;
    await GymDb.instance.setCurrentWeek(value);
    notifyListeners();
  }

  /// Call after any write so listening screens re-query.
  void dataChanged() {
    if (week > maxWeek) maxWeek = week;
    notifyListeners();
  }
}

final appState = AppState();
