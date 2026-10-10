import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'i18n.dart';
import 'exercise_store.dart';
import 'screens/guide_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/train_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg2,
  ));
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await appState.load();
  await exerciseStore.load();
  runApp(const LiftLogApp());
}

/// Rebuilds on a language change so the locale — and with it the whole app's
/// text direction — swaps live.
class LiftLogApp extends StatefulWidget {
  const LiftLogApp({super.key});

  @override
  State<LiftLogApp> createState() => _LiftLogAppState();
}

class _LiftLogAppState extends State<LiftLogApp> {
  @override
  void initState() {
    super.initState();
    appState.addListener(_onState);
  }

  @override
  void dispose() {
    appState.removeListener(_onState);
    super.dispose();
  }

  void _onState() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lift Log',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: L.locale,
      supportedLocales: L.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  // MaterialApp's `home` is a const widget, so a locale change alone does not
  // rebuild this subtree — the tab labels would stay in the old language.
  @override
  void initState() {
    super.initState();
    appState.addListener(_onState);
  }

  @override
  void dispose() {
    appState.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: const [
            TrainScreen(),
            ProgressScreen(),
            GuideScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg2,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              indicatorColor: AppColors.accentDim,
              labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: s.contains(WidgetState.selected)
                        ? AppColors.accent
                        : AppColors.muted,
                  )),
              iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
                    size: 22,
                    color: s.contains(WidgetState.selected)
                        ? AppColors.accent
                        : AppColors.muted,
                  )),
            ),
            child: NavigationBar(
              height: 62,
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                NavigationDestination(
                    icon: const Icon(Icons.fitness_center), label: L.train),
                NavigationDestination(
                    icon: const Icon(Icons.show_chart), label: L.progress),
                NavigationDestination(
                    icon: const Icon(Icons.menu_book_outlined), label: L.guide),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
