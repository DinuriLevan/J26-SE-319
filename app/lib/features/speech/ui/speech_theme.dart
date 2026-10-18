import 'package:flutter/material.dart';

/// Soft pastel palette for the Speech screens (dyslexia- and child-friendly): cream instead of
/// white and dark navy instead of black (less glare), pastel colours that code the three levels.
class SpeechColors {
  const SpeechColors._();

  static const cream = Color(0xFFFFF8EC);
  static const paper = Color(0xFFFFFDF8); // card surface; never pure white
  static const navy = Color(0xFF1F2A44); // text
  static const navySoft = Color(0xFF55607A); // secondary text
  static const mint = Color(0xFFCFF3DA); // level 1
  static const sky = Color(0xFFCFE6FF); // level 2
  static const lilac = Color(0xFFE5D9FF); // level 3
  static const peach = Color(0xFFFFD9C2);
  static const butter = Color(0xFFFFF1B8);
  static const coral = Color(0xFFFF8A65); // mic / main accent
  static const coralDeep = Color(0xFFE8684A);
  static const blue = Color(0xFF3D7BD9); // primary buttons
  static const sun = Color(0xFFFFC94D); // stars
  static const success = Color(0xFF57C785);
  static const shadow = Color(0x221F2A44);

  static Color level(int level) => switch (level) {
        1 => mint,
        2 => sky,
        _ => lilac,
      };

  /// A slightly deeper shade of a level colour, for ribbons and borders.
  static Color levelDeep(int level) => switch (level) {
        1 => const Color(0xFF8ED9A6),
        2 => const Color(0xFF8DBCF2),
        _ => const Color(0xFFB9A3F0),
      };
}

class SpeechTheme {
  const SpeechTheme._();

  static const radius = 28.0;

  /// Whether to animate: follows the system "reduce motion" setting.
  static bool motion(BuildContext context) =>
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  static ThemeData of(BuildContext context) {
    final base = Theme.of(context);
    TextStyle? soft(TextStyle? s) => s?.copyWith(
          color: SpeechColors.navy,
          letterSpacing: 0.3,
          height: 1.35,
          fontStyle: FontStyle.normal,
        );
    final t = base.textTheme;
    final pill =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(40));
    return base.copyWith(
      scaffoldBackgroundColor: SpeechColors.cream,
      colorScheme: base.colorScheme.copyWith(
        primary: SpeechColors.blue,
        onPrimary: SpeechColors.paper,
        surface: SpeechColors.cream,
        onSurface: SpeechColors.navy,
        error: SpeechColors.coralDeep,
      ),
      textTheme: t.copyWith(
        displayLarge:
            soft(t.displayLarge)?.copyWith(fontWeight: FontWeight.w600),
        displayMedium:
            soft(t.displayMedium)?.copyWith(fontWeight: FontWeight.w600),
        displaySmall:
            soft(t.displaySmall)?.copyWith(fontWeight: FontWeight.w600),
        headlineLarge:
            soft(t.headlineLarge)?.copyWith(fontWeight: FontWeight.w600),
        headlineMedium:
            soft(t.headlineMedium)?.copyWith(fontWeight: FontWeight.w600),
        headlineSmall:
            soft(t.headlineSmall)?.copyWith(fontWeight: FontWeight.w600),
        titleLarge: soft(t.titleLarge)?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: soft(t.titleMedium),
        titleSmall: soft(t.titleSmall),
        bodyLarge: soft(t.bodyLarge),
        bodyMedium: soft(t.bodyMedium),
        bodySmall: soft(t.bodySmall)?.copyWith(color: SpeechColors.navySoft),
        labelLarge: soft(t.labelLarge)?.copyWith(fontWeight: FontWeight.w600),
        labelSmall: soft(t.labelSmall)?.copyWith(color: SpeechColors.navySoft),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: SpeechColors.cream,
        foregroundColor: SpeechColors.navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle:
            soft(t.titleLarge)?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: SpeechColors.paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SpeechColors.blue,
          foregroundColor: SpeechColors.paper,
          minimumSize: const Size(64, 64),
          shape: pill,
          textStyle: soft(t.titleMedium)?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SpeechColors.navy,
          minimumSize: const Size(64, 64),
          shape: pill,
          side: const BorderSide(color: SpeechColors.navySoft, width: 2),
          textStyle: soft(t.titleMedium)?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}

/// Applies the speech theme to a subtree (each speech screen wraps its Scaffold in this).
class SpeechThemed extends StatelessWidget {
  const SpeechThemed({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: SpeechTheme.of(context), child: child);
}

/// Soft drop shadow used by cards and buttons.
const speechShadow = [
  BoxShadow(color: SpeechColors.shadow, blurRadius: 16, offset: Offset(0, 6)),
];
