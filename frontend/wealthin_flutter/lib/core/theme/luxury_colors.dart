import 'package:flutter/material.dart';

/// Luxury Color Palette for Vibrant Indian Authentic App
/// Glassmorphic-ready colors with premium feel
class LuxuryColors {
  const LuxuryColors._();

  // ============================================================
  //  PRIMARY LUXURY PALETTE
  // ============================================================
  
  /// Peach Cream (#FCDFC5) - Warm luxury background
  static const peachCream = Color(0xFFFCDFC5);
  
  /// Vanilla Latte (#F3E5C3) - Soft elegant surface
  static const vanillaLatte = Color(0xFFF3E5C3);
  
  /// Mint Whisper (#D7EAE2) - Fresh calm accent
  static const mintWhisper = Color(0xFFD7EAE2);
  
  /// Golden Sand (#F0E193) - Prosperity highlight
  static const goldenSand = Color(0xFFF0E193);
  
  /// Deep Olive (#1A2417) - Grounded wealth
  static const deepOlive = Color(0xFF1A2417);
  
  /// Deep Purple (#25092E) - Royal mystery
  static const deepPurple = Color(0xFF25092E);

  // ============================================================
  //  EXTENDED LUXURY PALETTE
  // ============================================================
  
  /// Rich Burgundy - Premium depth
  static const richBurgundy = Color(0xFF5C1A33);
  
  /// Forest Emerald - Growth and prosperity
  static const forestEmerald = Color(0xFF0D4D3E);
  
  /// Champagne Gold - Celebration
  static const champagneGold = Color(0xFFE0C070);
  
  /// Rose Gold - Feminine luxury
  static const roseGold = Color(0xFFE8B4A0);
  
  /// Sage Green - Natural wealth
  static const sageGreen = Color(0xFF9CAF88);
  
  /// Lavender Mist - Soft premium
  static const lavenderMist = Color(0xFFE6D5E8);
  
  /// Terracotta - Earthy Indian
  static const terracotta = Color(0xFFD4622A);
  
  /// Ivory Silk - Pure luxury
  static const ivorySilk = Color(0xFFFFFDF7);

  // ============================================================
  //  GLASSMORPHIC OVERLAYS
  // ============================================================
  
  /// Light glass overlay for dark backgrounds
  static Color glassLight({double opacity = 0.15}) =>
      peachCream.withValues(alpha: opacity);
  
  /// Dark glass overlay for light backgrounds
  static Color glassDark({double opacity = 0.2}) =>
      deepOlive.withValues(alpha: opacity);
  
  /// Mint glass overlay
  static Color glassMint({double opacity = 0.2}) =>
      mintWhisper.withValues(alpha: opacity);
  
  /// Golden glass overlay
  static Color glassGold({double opacity = 0.25}) =>
      goldenSand.withValues(alpha: opacity);

  // ============================================================
  //  LUXURY GRADIENTS
  // ============================================================
  
  /// Sunrise Luxury - Peach to Golden
  static const sunriseLuxury = LinearGradient(
    colors: [peachCream, goldenSand, champagneGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Mint Breeze - Fresh and calm
  static const mintBreeze = LinearGradient(
    colors: [mintWhisper, vanillaLatte, peachCream],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Royal Night - Deep and mysterious
  static const royalNight = LinearGradient(
    colors: [deepPurple, deepOlive, richBurgundy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Prosperity Flow - Growth gradient
  static const prosperityFlow = LinearGradient(
    colors: [forestEmerald, mintWhisper, sageGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Golden Hour - Premium warmth
  static const goldenHour = LinearGradient(
    colors: [goldenSand, champagneGold, roseGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Lavender Dream - Soft luxury
  static const lavenderDream = LinearGradient(
    colors: [lavenderMist, peachCream, vanillaLatte],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================================
  //  GLASSMORPHIC DECORATIONS
  // ============================================================
  
  /// Premium glass card with luxury colors
  static BoxDecoration luxuryGlassCard({
    double borderRadius = 20,
    bool isDark = false,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: isDark
            ? [
                deepPurple.withValues(alpha: 0.7),
                deepOlive.withValues(alpha: 0.6),
              ]
            : [
                peachCream.withValues(alpha: 0.8),
                mintWhisper.withValues(alpha: 0.7),
              ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: goldenSand.withValues(alpha: 0.4),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: (isDark ? deepPurple : goldenSand).withValues(alpha: 0.3),
          blurRadius: 24,
          spreadRadius: 2,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
  
  /// Vibrant glass card with shimmer
  static BoxDecoration vibrantGlassCard({
    double borderRadius = 20,
    Gradient? customGradient,
  }) {
    return BoxDecoration(
      gradient: customGradient ?? sunriseLuxury,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: champagneGold.withValues(alpha: 0.5),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: goldenSand.withValues(alpha: 0.4),
          blurRadius: 28,
          spreadRadius: 3,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: peachCream.withValues(alpha: 0.2),
          blurRadius: 16,
          spreadRadius: 1,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // ============================================================
  //  SEMANTIC COLORS WITH LUXURY TONES
  // ============================================================
  
  /// Success - Emerald growth
  static const success = forestEmerald;
  
  /// Warning - Golden alert
  static const warning = goldenSand;
  
  /// Error - Burgundy danger
  static const error = richBurgundy;
  
  /// Info - Mint information
  static const info = mintWhisper;

  // ============================================================
  //  TEXT COLORS
  // ============================================================
  
  /// Primary text on dark
  static const textDarkPrimary = peachCream;
  
  /// Secondary text on dark
  static const textDarkSecondary = vanillaLatte;
  
  /// Primary text on light
  static const textLightPrimary = deepOlive;
  
  /// Secondary text on light
  static const textLightSecondary = Color(0xFF4A5D47);

  // ============================================================
  //  HELPER METHODS
  // ============================================================
  
  /// Get text color based on background brightness
  static Color getTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? deepOlive : peachCream;
  }
  
  /// Create custom glass gradient
  static LinearGradient customGlass({
    required Color color1,
    required Color color2,
    double opacity1 = 0.8,
    double opacity2 = 0.6,
  }) {
    return LinearGradient(
      colors: [
        color1.withValues(alpha: opacity1),
        color2.withValues(alpha: opacity2),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
