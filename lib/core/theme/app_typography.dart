import 'package:arah/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Skala tipografi Plus Jakarta Sans. Angka keuangan memakai [AppTypography.amount] (tabular figures).
abstract final class AppTypography {
  static const family = 'PlusJakartaSans';
  static const _tabular = [FontFeature.tabularFigures()];

  static const textTheme = TextTheme(
    headlineMedium: TextStyle(fontSize: 30, height: 38 / 30, fontWeight: FontWeight.w800, letterSpacing: -0.6),
    headlineSmall: TextStyle(fontSize: 22, height: 30 / 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
    titleLarge: TextStyle(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w800),
    titleMedium: TextStyle(fontSize: 17, height: 24 / 17, fontWeight: FontWeight.w700),
    titleSmall: TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w600),
    bodySmall: TextStyle(fontSize: 12, height: 18 / 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
  );

  /// Nilai utama (hero), 32 extra bold.
  static const amountLarge = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    fontFeatures: _tabular,
  );

  static const amount = TextStyle(fontWeight: FontWeight.w700, fontFeatures: _tabular);
}
