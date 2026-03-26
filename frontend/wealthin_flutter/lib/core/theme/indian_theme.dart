import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Indian-Inspired Premium Theme — AMOLED Edition
/// Deep, muted tones drawn from Indian cultural heritage:
/// temple stone, saffron dawn, peacock feather, lotus dusk.
/// Optimised for AMOLED displays and dark-first fintech UI.
class IndianTheme {
  // ============================================================
  //  AMOLED-SAFE DARK FOUNDATIONS
  // ============================================================
  static const deepOnyx        = Color(0xFF060608); // True AMOLED black
  static const richNavy        = Color(0xFF0D1117); // Main scaffold (dark)
  static const deepSlate       = Color(0xFF141924); // Card surface
  static const inkSlate        = Color(0xFF1C2433); // Elevated card
  static const silverMist      = Color(0xFF8A96A8); // Secondary text
  static const pearlWhite      = Color(0xFFE8EDF5); // Primary text (dark)

  // ============================================================
  //  SAFFRON FAMILY — Muted, AMOLED-safe prosperity tones
  // ============================================================
  static const saffron         = Color(0xFFD4622A); // Deep muted saffron
  static const saffronLight    = Color(0xFFE8804A); // Warm saffron glow
  static const saffronDeep    = Color(0xFFAA4A1E); // Dark saffron ember
  static const kesarCream      = Color(0xFFFBF3E1); // Saffron parchment

  // ============================================================
  //  GOLD FAMILY — Antique, heritage gold (not garish)
  // ============================================================
  static const royalGold       = Color(0xFFC9A84C); // Antique gold
  static const mutedGold       = Color(0xFFB8923E); // Muted heritage gold
  static const champagneGold   = Color(0xFFE0C070); // Champagne highlight
  static const antiqGold       = Color(0xFF8A6820); // Dark antique
  static const goldShimmer     = Color(0xFFF4E4C7); // Soft gold wash

  // ============================================================
  //  PEACOCK FAMILY — Deep teal, the pulse of fintech
  // ============================================================
  static const peacockBlue     = Color(0xFF0B4F6C); // Deep peacock
  static const peacockTeal     = Color(0xFF0A7070); // Peacock teal (primary)
  static const peacockGreen    = Color(0xFF0F7A5A); // Peacock green
  static const peacockFeather  = Color(0xFF062E2E); // Very dark teal surface
  static const peacockLight    = Color(0xFF2AACAC); // Bright teal accent

  // ============================================================
  //  LOTUS FAMILY — Soft magenta, feminine accents
  // ============================================================
  static const lotusPink       = Color(0xFFC1446A); // Lotus magenta
  static const lotusPetal      = Color(0xFF8B2F4F); // Deep lotus
  static const lotusWhite      = Color(0xFFFCEFF3); // Lotus-tinted light surface
  static const lotusMagenta    = Color(0xFFD4567E); // Bright lotus accent

  // ============================================================
  //  TEMPLE STONE — Grounding neutrals
  // ============================================================
  static const templeStone     = Color(0xFF7A6A58); // Warm sandstone
  static const templeGranite   = Color(0xFF3A3A3A); // Dark granite
  static const marbleCream     = Color(0xFFF8F4EC); // Cream marble
  static const sandalwood      = Color(0xFF5C4A35); // Rich sandalwood

  // ============================================================
  //  TURMERIC / MEHENDI — Semantic use
  // ============================================================
  static const turmeric        = Color(0xFFCF9B00); // Deep turmeric
  static const mehendiGreen    = Color(0xFF3D6B3D); // Forest mehendi
  static const vermillion      = Color(0xFFCC3333); // Sindoor vermillion
  
  // --- Backward Compatibility Aliases ---
  static const turmericPaste    = saffron;
  static const vermillionLight = lotusPink;
  static const royalPurple      = peacockTeal;

  // ============================================================
  //  GRADIENTS
  // ============================================================

  /// Sunrise — Deep saffron to antique gold (premium CTAs)
  static const sunriseGradient = LinearGradient(
    colors: [Color(0xFFAA4A1E), Color(0xFFC9A84C), Color(0xFF8A6820)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Peacock — Deep navy to teal (finance cards)
  static const peacockGradient = LinearGradient(
    colors: [Color(0xFF062030), Color(0xFF0A7070), Color(0xFF052828)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Lotus — Deep magenta to dark rose (AI / insight cards)
  static const lotusGradient = LinearGradient(
    colors: [Color(0xFF5A1430), Color(0xFFC1446A), Color(0xFF3A0D1E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Royal — Deep purple to gold (premium elements)
  static const royalGradient = LinearGradient(
    colors: [Color(0xFF1A0A30), Color(0xFF5A2D82), Color(0xFFC9A84C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Temple Sunset — Deep burnt sienna palette
  static const templeSunsetGradient = LinearGradient(
    colors: [Color(0xFF4A1208), Color(0xFF8B3A1A), Color(0xFFC9A84C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  /// Sacred Morning — modern + traditional light blend
  static const sacredMorningGradient = LinearGradient(
    colors: [Color(0xFFFCF7EA), Color(0xFFF3E6CC), Color(0xFFEDE2CE)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Sacred Night — dark counterpart for AMOLED surfaces
  static const sacredNightGradient = LinearGradient(
    colors: [Color(0xFF0D0A06), Color(0xFF1A140A), Color(0xFF0D0A06)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Prosperity — Deep forest to teal (growth indicators)
  static const prosperityGradient = LinearGradient(
    colors: [Color(0xFF0A2A0A), Color(0xFF3D6B3D), Color(0xFF0A7070)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Chat User Gradient — Warm saffron dark bubble
  static const chatUserGradient = LinearGradient(
    colors: [Color(0xFF8B3010), Color(0xFFC9A84C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Chat AI Gradient — Cool deep teal bubble
  static const chatAIGradient = LinearGradient(
    colors: [Color(0xFF0D1824), Color(0xFF122030)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// AMOLED background gradient (very subtle depth)
  static const amoledGradient = LinearGradient(
    colors: [Color(0xFF060608), Color(0xFF0A0C10), Color(0xFF060608)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ============================================================
  //  CARD DECORATIONS
  // ============================================================

  static BoxDecoration premiumCardDecoration({
    Gradient? gradient,
    Color? borderColor,
    double borderRadius = 20,
    bool hasShadow = true,
  }) {
    return BoxDecoration(
      gradient: gradient ?? sunriseGradient,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? royalGold.withValues(alpha: 0.35),
        width: 1.5,
      ),
      boxShadow: hasShadow
          ? [
              BoxShadow(
                color: royalGold.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    );
  }

  static BoxDecoration glassCardDecoration({
    double borderRadius = 16,
    bool dark = true,
  }) {
    return BoxDecoration(
      color: dark ? inkSlate : const Color(0xFFF5F7F6),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: royalGold.withValues(alpha: 0.18),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // --- Legacy Decoration Aliases ---
  static BoxDecoration marbleCardDecoration() => glassCardDecoration();
  static BoxDecoration goldButtonDecoration() => premiumCardDecoration(gradient: sunriseGradient);

  // ============================================================
  //  TYPOGRAPHY — Syne (headings) + DM Sans (body)
  // ============================================================

  static TextTheme get premiumTextTheme {
    return TextTheme(
      displayLarge: GoogleFonts.syne(
        fontSize: 40, fontWeight: FontWeight.bold,
        color: pearlWhite, letterSpacing: -1.0, height: 1.2,
      ),
      displayMedium: GoogleFonts.syne(
        fontSize: 32, fontWeight: FontWeight.w700,
        color: pearlWhite, letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.syne(
        fontSize: 26, fontWeight: FontWeight.w600,
        color: pearlWhite,
      ),
      headlineLarge: GoogleFonts.syne(
        fontSize: 24, fontWeight: FontWeight.w700, color: pearlWhite,
      ),
      headlineMedium: GoogleFonts.syne(
        fontSize: 20, fontWeight: FontWeight.w600, color: pearlWhite,
      ),
      headlineSmall: GoogleFonts.syne(
        fontSize: 18, fontWeight: FontWeight.w600, color: pearlWhite,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: 17, fontWeight: FontWeight.w600, color: pearlWhite,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 15, fontWeight: FontWeight.w500, color: silverMist,
      ),
      titleSmall: GoogleFonts.dmSans(
        fontSize: 13, fontWeight: FontWeight.w500, color: silverMist,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16, color: pearlWhite, height: 1.6,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14, color: silverMist, height: 1.55,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12, color: silverMist, height: 1.4,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: pearlWhite,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w500, color: silverMist,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11, fontWeight: FontWeight.w500, color: silverMist,
      ),
    );
  }

  // ============================================================
  //  CANVAS PAINT STYLES
  // ============================================================

  static Paint get mandalaPaint => Paint()
    ..color = royalGold.withValues(alpha: 0.08)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  static Paint get rangoliPaint => Paint()
    ..color = lotusPink.withValues(alpha: 0.10)
    ..style = PaintingStyle.fill;

  static Paint get templeLinePaint => Paint()
    ..color = templeStone.withValues(alpha: 0.15)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
}
