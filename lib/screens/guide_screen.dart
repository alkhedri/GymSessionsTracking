import 'package:flutter/material.dart';

import '../app_state.dart';
import '../program.dart';
import '../i18n.dart';
import '../theme.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

/// Listens to the app state purely so a language change redraws it.
///
/// The tabs sit in an IndexedStack built from const widgets, and Flutter skips
/// an element whose widget is the identical instance — so this screen is never
/// rebuilt from above, however often its parent rebuilds. Train and Progress
/// get away with it only because they already listen for their own data.
class _GuideScreenState extends State<GuideScreen> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(L.howToRun),
              const SizedBox(height: 2),
              Text(L.guide,
                  style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Panel(
                color: AppColors.bg2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Program.displayTitle,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(Program.displaySubtitle,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
              for (final section in Program.displayGuide) ...[
                const SizedBox(height: 20),
                Text(section.title.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent)),
                const SizedBox(height: 10),
                for (final item in section.items) ...[
                  Panel(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item[0],
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(item[1],
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: AppColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
