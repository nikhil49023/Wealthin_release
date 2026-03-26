import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Indian-Inspired Luxury Theme — Vibrant Authentic Edition
/// Luxury color palette: Peach Cream, Vanilla Latte, Mint Whisper, Golden Sand,
/// Deep Olive, Deep Purple, and traditional Indian heritage tones.
/// Optimised for glassmorphic effects and vibrant Indian fintech UI.
class IndianTheme {
  // ============================================================
  //  LUXURY VIBRANT FOUNDATIONS
  // ============================================================
  static const deepOnyx = Color(0xFF25092E); // Deep Purple base
  static const richNavy = Color(0xFF1A2417); // Deep Olive scaffold
  static const deepSlate = Color(0xFF2A1F3D); // Purple-tinted card
  static const inkSlate = Color(0xFF3D2A4A); // Elevated purple card
  static const silverMist = Color(0xFFF3E5C3); // Vanilla Latte secondary
  static const pearlWhite = Color(0xFFFCDFC5); // Peach Cream primary

  // ============================================================
  //  LUXURY COLOR PALETTE
  // ============================================================
  static const peachCream = Color(0xFFFCDFC5); // Peach Cream - warm luxury
  static const vanillaLatte = Color(0xFFF3E5C3); // Vanilla Latte - soft elegance
  static const mintWhisper = Color(0xFFD7EAE2); // Mint Whisper - fresh calm
  static const goldenSand = Color(0xFFF0E193); // Golden Sand - prosperity
  static const deepOlive = Color(0xFF1A2417); // Deep Olive - grounded wealth
  static const deepPurple = Color(0xFF25092E); // Deep Purple - royal mystery

  // ============================================================
  //  SAFFRON FAMILY — Vibrant prosperity tones
  // ============================================================
  static const saffron = Color(0xFFD4622A); // Vibrant saffron
  static const saffronLight = Color(0xFFE8804A); // Warm saffron glow
  static const saffronDeep = Color(0xFFAA4A1E); // Deep saffron ember
  static const kesarCream = peachCream; // Saffron parchment = Peach Cream

  // ============================================================
  //  GOLD FAMILY — Luxury golden tones
  // ============================================================
  static const royalGold = goldenSand; // Golden Sand
  static const mutedGold = Color(0xFFB8923E); // Muted heritage gold
  static const champagneGold = Color(0xFFE0C070); // Champagne highlight
  static const antiqGold = Color(0xFF8A6820); // Dark antique
  static const goldShimmer = vanillaLatte; // Vanilla Latte shimmer

  // ============================================================
  //  PEACOCK FAMILY — Vibrant teal with mint
  // ============================================================
  static const peacockBlue = Color(0xFF0B4F6C); // Deep peacock
  static const peacockTeal = Color(0xFF0A7070); // Peacock teal (primary)
  static const peacockGreen = Color(0xFF0F7A5A); // Peacock green
  static const peacockFeather = deepOlive; // Deep Olive surface
  static const peacockLight = mintWhisper; // Mint Whisper accent

  // ============================================================
  //  LOTUS FAMILY — Vibrant magenta accents
  // ============================================================
  static const lotusPink = Color(0xFFC1446A); // Lotus magenta
  static const lotusPetal = Color(0xFF8B2F4F); // Deep lotus
  static const lotusWhite = peachCream; // Peach Cream lotus surface
  static const lotusMagenta = Color(0xFFD4567E); // Bright lotus accent

  // ============================================================
  //  TEMPLE STONE — Luxury neutrals
  // ============================================================
  static const templeStone = Color(0xFF7A6A58); // Warm sandstone
  static const templeGranite = deepOlive; // Deep Olive granite
  static const marbleCream = peachCream; // Peach Cream marble
  static const sandalwood = Color(0xFF5C4A35); // Rich sandalwood

  // ============================================================
  //  TURMERIC / MEHENDI — Semantic use
  // ============================================================
  static const turmeric = Color(0xFFCF9B00); // Deep turmeric
  static const mehendiGreen = Color(0xFF3D6B3D); // Forest mehendi
  static const vermillion = Color(0xFFCC3333); // Sindoor vermillion

  // --- Backward Compatibility Aliases ---
  static const turmericPaste = saffron;
  static const vermillionLight = lotusPink;
  static const royalPurple = peacockTeal;

  // ============================================================
  //  GRADIENTS
  // ============================================================

  /// Luxury Peach Sunrise — Peach to Golden gradient
  static const sunriseGradient = LinearGradient(
    colors: [peachCream, goldenSand, champagneGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Mint Peacock — Mint to Teal gradient
  static const peacockGradient = LinearGradient(
    colors: [mintWhisper, peacockTeal, Color(0xFF0D4D3E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Royal Purple — Deep Purple gradient
  static const lotusGradient = LinearGradient(
    colors: [deepPurple, Color(0xFF5C1A33), lotusPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Luxury Royal — Purple to Golden gradient
  static const royalGradient = LinearGradient(
    colors: [deepPurple, deepOlive, goldenSand],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Luxury Sunset — Burgundy to Golden gradient
  static const templeSunsetGradient = LinearGradient(
    colors: [Color(0xFF5C1A33), saffron, goldenSand],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  /// Luxury Light — Mint to Peach to Vanilla gradient
  static const sacredMorningGradient = LinearGradient(
    colors: [mintWhisper, peachCream, vanillaLatte],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Luxury Dark — Deep Purple to Olive gradient
  static const sacredNightGradient = LinearGradient(
    colors: [deepPurple, deepOlive, deepPurple],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Prosperity — Emerald to Mint gradient
  static const prosperityGradient = LinearGradient(
    colors: [Color(0xFF0D4D3E), mintWhisper, peacockTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Chat User Gradient — Warm peach bubble
  static const chatUserGradient = LinearGradient(
    colors: [peachCream, goldenSand],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Chat AI Gradient — Cool mint bubble
  static const chatAIGradient = LinearGradient(
    colors: [mintWhisper, vanillaLatte],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Luxury Dark gradient
  static const amoledGradient = LinearGradient(
    colors: [deepPurple, deepOlive, deepPurple],
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
        color: borderColor ?? goldenSand.withValues(alpha: 0.4),
        width: 1.5,
      ),
      boxShadow: hasShadow
          ? [
              BoxShadow(
                color: goldenSand.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 10),
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
      color: dark ? inkSlate : mintWhisper,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: goldenSand.withValues(alpha: 0.3),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: (dark ? deepPurple : peachCream).withValues(alpha: 0.4),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  // --- Legacy Decoration Aliases ---
  static BoxDecoration marbleCardDecoration() => glassCardDecoration();
  static BoxDecoration goldButtonDecoration() =>
      premiumCardDecoration(gradient: sunriseGradient);

  // ============================================================
  //  TYPOGRAPHY — Syne (headings) + DM Sans (body)
  // ============================================================

  static TextTheme get premiumTextTheme {
    return TextTheme(
      displayLarge: GoogleFonts.syne(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        color: pearlWhite,
        letterSpacing: -1.0,
        height: 1.2,
      ),
      displayMedium: GoogleFonts.syne(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: pearlWhite,
        letterSpacing: -0.5,
      ),
      displaySmall: GoogleFonts.syne(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: pearlWhite,
      ),
      headlineLarge: GoogleFonts.syne(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: pearlWhite,
      ),
      headlineMedium: GoogleFonts.syne(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: pearlWhite,
      ),
      headlineSmall: GoogleFonts.syne(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: pearlWhite,
      ),
      titleLarge: GoogleFonts.dmSans(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: pearlWhite,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: silverMist,
      ),
      titleSmall: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: silverMist,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        color: pearlWhite,
        height: 1.6,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        color: silverMist,
        height: 1.55,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        color: silverMist,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: pearlWhite,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: silverMist,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: silverMist,
      ),
    );
  }

  // ============================================================
  //  CANVAS PAINT STYLES
  // ============================================================

  static Paint get mandalaPaint => Paint()
    ..color = goldenSand.withValues(alpha: 0.15)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  static Paint get rangoliPaint => Paint()
    ..color = peachCream.withValues(alpha: 0.20)
    ..style = PaintingStyle.fill;

  static Paint get templeLinePaint => Paint()
    ..color = mintWhisper.withValues(alpha: 0.25)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
}
