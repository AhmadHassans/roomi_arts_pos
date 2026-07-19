import 'package:flutter/material.dart';
import 'constants.dart';

/// The single teal accent theme. Clean, flat, friendly, high contrast.
class AppColors {
  static const Color teal = Color(0xFF0F6E56); // accent
  static const Color tealTint = Color(0xFFE1F5EE); // light tint
  static const Color surface = Colors.white;
  static const Color background = Color(0xFFF4F7F6); // very soft grey-green
  static const Color text = Color(0xFF1B2320); // near-black, high contrast
  static const Color textSoft = Color(0xFF5B6660);
  static const Color danger = Color(0xFFC62828); // remove / delete
  static const Color warn = Color(0xFFE8791A); // low stock highlight
  static const Color warnBg = Color(0xFFFFF1E3); // low stock row bg

  // ---- Premium dashboard palette (used by the Reports/Sales dashboard) ----
  static const Color bgLav = Color(0xFFF4F3FB); // soft lavender-white
  static const Color panel = Color(0xFFFFFFFF);
  static const Color panelBorder = Color(0xFFECE9F6);
  static const Color violet = Color(0xFF6C4CFF); // primary
  static const Color violetDark = Color(0xFF5A3CE0);
  static const Color violetTint = Color(0xFFEDE9FF); // light violet fill
  static const Color coral = Color(0xFFFF6B81);
  static const Color amber = Color(0xFFFFB020);
  static const Color tealBright = Color(0xFF12C2B6);
  static const Color sky = Color(0xFF4AA8FF);
  static const Color lilac = Color(0xFFA06BFF);
  static const Color ink = Color(0xFF1A1731);
  static const Color muted = Color(0xFF7B7898);

  // ---- Sidebar (violet gradient premium look) ----
  static const Color sidebarDeep = Color(0xFF2A1A5E); // deep indigo (top)
  static const Color sidebarMid = Color(0xFF3D2483); // plum-indigo (mid)
  static const Color sidebarPlum = Color(0xFF5A2D8A); // plum (bottom)
  static const Color navInactive = Color(0xFFC3B8EA); // soft light-violet text
  static const Color navActiveFill = Color(0x26FFFFFF); // translucent white 0.15
  static const Color navHoverFill = Color(0x14FFFFFF); // translucent white 0.08
}

class AppTheme {
  // Font families (bundled variable fonts — see pubspec fonts:).
  static const String display = 'Sora'; // headings + numbers
  static const String body = 'Inter'; // body text

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    final scheme = base.colorScheme.copyWith(
      primary: AppColors.violet,
      onPrimary: Colors.white,
      secondary: AppColors.coral,
      surface: AppColors.panel,
      onSurface: AppColors.ink,
      error: AppColors.danger,
      outline: AppColors.panelBorder,
    );

    // Inter body scale; headings switch to Sora per-widget or via titles below.
    TextStyle b(double s, [FontWeight w = FontWeight.w400]) =>
        TextStyle(fontFamily: body, fontSize: s, fontWeight: w, color: AppColors.ink);
    TextStyle d(double s, FontWeight w) =>
        TextStyle(fontFamily: display, fontSize: s, fontWeight: w, color: AppColors.ink, letterSpacing: -.01);

    final textTheme = TextTheme(
      displayLarge: d(30, FontWeight.w800),
      headlineSmall: d(22, FontWeight.w800),
      titleLarge: d(19, FontWeight.w700),
      titleMedium: d(17, FontWeight.w700),
      bodyLarge: b(Sizes.bodyText),
      bodyMedium: b(Sizes.bodyText),
      bodySmall: b(14, FontWeight.w400).copyWith(color: AppColors.muted),
      labelLarge: TextStyle(fontFamily: body, fontSize: Sizes.bodyText, fontWeight: FontWeight.w700),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgLav,
      colorScheme: scheme,
      textTheme: textTheme,
      dividerColor: AppColors.panelBorder,
      cardTheme: CardThemeData(
        color: AppColors.panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.panelBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      // Primary buttons — violet, rounded, tall. (Gradient variant is a shared
      // widget; this covers plain ElevatedButtons.)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.violet,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, Sizes.buttonHeight),
          elevation: 0,
          textStyle: const TextStyle(
              fontFamily: body, fontSize: Sizes.bodyText, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.panel,
          minimumSize: const Size(0, Sizes.buttonHeight),
          side: const BorderSide(color: AppColors.panelBorder),
          textStyle: const TextStyle(
              fontFamily: body, fontSize: Sizes.bodyText, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.violet),
      ),
      iconTheme: const IconThemeData(color: AppColors.ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.panel,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(fontFamily: body, fontSize: Sizes.bodyText, color: AppColors.muted),
        labelStyle: const TextStyle(fontFamily: body, fontSize: Sizes.bodyText, color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.panelBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.panelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.violet, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.violet),
    );
  }
}