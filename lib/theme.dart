import 'package:flutter/material.dart';

import 'i18n.dart';

class AppColors {
  AppColors._();
  static const bg = Color(0xFF0B0D10);
  static const bg2 = Color(0xFF12161B);
  static const card = Color(0xFF161B22);
  static const card2 = Color(0xFF1C222B);
  static const line = Color(0xFF252C36);
  static const text = Color(0xFFE8EDF4);
  static const muted = Color(0xFF8A95A5);
  static const accent = Color(0xFFFFD166);
  static const accentDim = Color(0xFF4A3F1E);
  static const good = Color(0xFF4ADE80);
  static const hot = Color(0xFFF87171);
}

ThemeData buildTheme() {
  // Zain (SIL OFL) for Arabic; English keeps the platform default, which
  // handles Latin text better than an Arabic-first face does.
  final family = L.isAr ? 'Zain' : null;
  final base = ThemeData.dark(useMaterial3: true).copyWith(
    textTheme: ThemeData.dark().textTheme.apply(fontFamily: family),
    primaryTextTheme: ThemeData.dark().primaryTextTheme.apply(fontFamily: family),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accent,
      surface: AppColors.card,
      onPrimary: const Color(0xFF191400),
      onSurface: AppColors.text,
      error: AppColors.hot,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: family,
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg2,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    dividerColor: AppColors.line,
    splashFactory: InkSparkle.splashFactory,
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.bg2,
      hintStyle: const TextStyle(color: Color(0xFF4A5462)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
    ),
  );
}

/// Shared card shell used across every screen.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
    if (onTap == null && onLongPress == null) return body;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: body,
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final bool highlight;
  const Pill(this.text, {super.key, this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: highlight ? AppColors.accentDim : AppColors.bg2,
          border: Border.all(
              color: highlight ? AppColors.accentDim : AppColors.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: highlight ? AppColors.accent : AppColors.muted,
          ),
        ),
      );
}

class StatTile extends StatelessWidget {
  final String value;
  final String label;
  const StatTile(this.value, this.label, {super.key});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4)),
              const SizedBox(height: 2),
              Text(label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted)),
            ],
          ),
        ),
      );
}

String fmtKg(double n) {
  if (n >= 10000) return '${(n / 1000).round()}k';
  return n.round().toString();
}

String fmtNum(double? n) {
  if (n == null) return '';
  if (n == n.roundToDouble()) return n.round().toString();
  return n.toString();
}
