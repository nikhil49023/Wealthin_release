import 'package:flutter/material.dart';

/// Shared spacing and shape tokens for consistent production UI.
class DesignTokens {
  const DesignTokens._();

  // Spacing scale
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  // Radius scale
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 20;

  static BorderRadius brSm = BorderRadius.circular(radiusSm);
  static BorderRadius brMd = BorderRadius.circular(radiusMd);
  static BorderRadius brLg = BorderRadius.circular(radiusLg);

  // Standard component paddings
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(xl);
  static const EdgeInsets chipPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );
}
