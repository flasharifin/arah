import 'package:arah/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Skala tipografi. Angka keuangan memakai [AppTypography.amount] (tabular figures).
abstract final class AppTypography {
  static const _tabular = [FontFeature.tabularFigures()];

  static const textTheme = TextTheme(
    headlineMedium: TextStyle(fontSize: 30, height: 38 / 30, fontWeight: FontWeight.w700),
    headlineSmall: TextStyle(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 18, height: 26 / 18, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500),
    bodySmall: TextStyle(
      fontSize: 12,
      height: 18 / 12,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
  );

  /// Nilai utama (hero), 30/38 bold.
  static const amountLarge = TextStyle(
    fontSize: 30,
    height: 38 / 30,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
  );

  static const amount = TextStyle(fontWeight: FontWeight.w600, fontFeatures: _tabular);
}
