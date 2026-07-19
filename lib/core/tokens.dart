/// Central design tokens — spacing, corner radius, shadows and gradients.
/// Screens compose from these instead of hard-coding values, so the whole
/// app stays visually consistent.
library;

import 'package:flutter/material.dart';
import 'theme.dart';

/// Corner radii.
class AppRadius {
  static const double sm = 11;
  static const double md = 14;
  static const double lg = 20; // cards / panels
  static const double pill = 30;
}

/// Spacing scale (multiples of 4).
class AppSpacing {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Soft, violet-tinted shadows.
class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x143A2483), blurRadius: 24, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> panel = [
    BoxShadow(color: Color(0x1A3A2483), blurRadius: 30, offset: Offset(0, 14)),
  ];

  /// Colored glow under a gradient element (button / stat card).
  static List<BoxShadow> glow(Color c) => [
        BoxShadow(color: c.withValues(alpha: 0.38), blurRadius: 26, offset: const Offset(0, 12)),
      ];
}

/// Named gradients used across the app.
class AppGradients {
  // Primary action gradient: violet → lilac (#6C4CFF → #A06BFF).
  static const primary = LinearGradient(colors: [AppColors.violet, AppColors.lilac]);

  // Sidebar background: diagonal deep-indigo → plum-indigo → plum.
  static const sidebar = LinearGradient(
    colors: [AppColors.sidebarDeep, AppColors.sidebarMid, AppColors.sidebarPlum],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Brand icon tile: warm coral → amber (#FF6B81 → #FFB020) to pop on violet.
  static const brandTile = LinearGradient(
    colors: [AppColors.coral, AppColors.amber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Destructive action gradient (Delete / Restore): soft red → deep red.
  static const danger = LinearGradient(colors: [Color(0xFFE2456A), AppColors.danger]);

  // Stat-card gradients (top-left → bottom-right).
  static const violet = LinearGradient(
      colors: [Color(0xFF7A5CFF), Color(0xFF5A3CE0)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const coral = LinearGradient(
      colors: [Color(0xFFFF6B81), Color(0xFFFF9558)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const teal = LinearGradient(
      colors: [Color(0xFF12C2B6), Color(0xFF37C6FF)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const amber = LinearGradient(
      colors: [Color(0xFFFFB020), Color(0xFFFF8A3C)], begin: Alignment.topLeft, end: Alignment.bottomRight);

  // Vertical bar gradients for the chart.
  static const barViolet = LinearGradient(
      colors: [AppColors.lilac, AppColors.violet], begin: Alignment.topCenter, end: Alignment.bottomCenter);
  static const barToday = LinearGradient(
      colors: [AppColors.amber, AppColors.coral], begin: Alignment.topCenter, end: Alignment.bottomCenter);
}
