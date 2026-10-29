import 'package:flutter/widgets.dart';

/// Skala spacing 4–32 dan margin layar 20.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  static const screen = EdgeInsets.symmetric(horizontal: xl);

  /// Tablet: konten dibatasi 720 px.
  static const maxContentWidth = 720.0;

  static const minTouchTarget = 48.0;
  static const primaryButtonHeight = 52.0;
}

abstract final class AppRadius {
  static const field = 14.0;
  static const card = 20.0;
  static const hero = 24.0;
}
