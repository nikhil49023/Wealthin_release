import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'indian_theme.dart';

/// WealthIn — "Artha" Premium Fintech Theme  
/// AMOLED-native, Indian cultural heritage, dark-first.
/// Typography: Syne (headings) + DM Sans (body)
/// Colour philosophy: Deep onyx backgrounds, muted saffron-gold accents,
/// peacock-teal primary — elegant and readable on every Android display.
class AppTheme {
  // ============================================================
  //  COLOUR ALIASES (delegates to IndianTheme)
  // ============================================================

  // Primary palette
  static const saffron         = IndianTheme.saffron;
  static const royalGold       = IndianTheme.royalGold;
  static const mutedGold       = IndianTheme.mutedGold;
  static const champagneGold   = IndianTheme.champagneGold;
  static const peacockTeal     = IndianTheme.peacockTeal;
  static const peacockLight    = IndianTheme.peacockLight;
  static const lotusPink       = IndianTheme.lotusPink;

  // Dark surfaces
  static const deepOnyx        = IndianTheme.deepOnyx;
  static const richNavy        = IndianTheme.richNavy;
  static const deepSlate       = IndianTheme.deepSlate;
  static const inkSlate        = IndianTheme.inkSlate;

  // Text
  static const pearlWhite      = IndianTheme.pearlWhite;
  static const silverMist      = IndianTheme.silverMist;

  // Semantic
  static const success         = Color(0xFF2E8B5A);   // Emerald green (growth)
  static const successLight    = Color(0xFF4CAF85);
  static const error           = Color(0xFFCC3340);   // Deep crimson
  static const warning         = Color(0xFFCF9B00);   // Turmeric amber
  static const info            = Color(0xFF2196F3);

  // Light-mode surfaces (modern + traditional Indian blend)
  static const lightSurface    = Color(0xFFF6F3EC);
  static const lightCard       = Color(0xFFFFFCF6);
  static const lightBorder     = Color(0xFFE6D9C4);
  static const lightTextPrimary = Color(0xFF1B1A17);
  static const lightTextSecondary = Color(0xFF62594C);

  // --- Backward Compatibility Aliases (for sovereign_widgets.dart) ---
  static const glassWhite      = Color(0x1AFFFFFF); // Very subtle white overlay
  static const glassMint       = Color(0x1A4CAF85); // Subtle success tint
  static const glassBorder     = Color(0x33FFFFFF);
  static const glassShadow     = Color(0x66000000);
  static const royalPurple     = peacockTeal;       // Intelligence accent map
  static const purpleGlow      = peacockLight;      // Glow accent map
  static const purpleLight     = Color(0xFFE0B0FF); // Mauve (rarely used)
  static const forestLight     = successLight;
  static const forestGreen     = success;
  static const forestMuted     = silverMist;
  static const mintDark        = richNavy;
  static const emerald         = success;
  static const mint            = peacockLight;
  static const emeraldLight    = successLight;
  static const gradientEnd     = peacockTeal;
  static const gradientStart   = peacockLight;
  static const expenseRed      = error;
  static const incomeGreen     = success;
  static const primary         = peacockTeal;
  static const secondary       = royalGold;
  static const navy            = richNavy;
  static const deepNavy        = deepOnyx;
  static const gold            = royalGold;
  static const sereneTeal      = peacockTeal;
  static const sageGreen       = success;
  static const slate500        = silverMist;
  static const slate900        = pearlWhite;

  // Gradient helpers
  static LinearGradient get sunriseGradient => IndianTheme.sunriseGradient;
  static LinearGradient get peacockGradient => IndianTheme.peacockGradient;
  static LinearGradient get lotusGradient   => IndianTheme.lotusGradient;
  static LinearGradient get royalGradient   => IndianTheme.royalGradient;
  static LinearGradient get amoledGradient  => IndianTheme.amoledGradient;

  static LinearGradient get premiumGradient => const LinearGradient(
    colors: [IndianTheme.peacockTeal, IndianTheme.peacockBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get aiGradient => const LinearGradient(
    colors: [Color(0xFF5A1430), Color(0xFF0A7070)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get growthGradient => const LinearGradient(
    colors: [Color(0xFF0A2A0A), Color(0xFF2E8B5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============================================================
  //  TEXT THEMES
  // ============================================================

  static TextTheme get _darkTextTheme => TextTheme(
    displayLarge:  GoogleFonts.syne(fontSize: 38, fontWeight: FontWeight.bold,  color: pearlWhite, letterSpacing: -1.0, height: 1.2),
    displayMedium: GoogleFonts.syne(fontSize: 30, fontWeight: FontWeight.w700,  color: pearlWhite, letterSpacing: -0.5),
    displaySmall:  GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w600,  color: pearlWhite),
    headlineLarge: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w700,  color: pearlWhite),
    headlineMedium:GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w600,  color: pearlWhite),
    headlineSmall: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w600,  color: pearlWhite),
    titleLarge:    GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w600, color: pearlWhite),
    titleMedium:   GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500, color: silverMist),
    titleSmall:    GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: silverMist),
    bodyLarge:     GoogleFonts.dmSans(fontSize: 16, height: 1.6,  color: pearlWhite),
    bodyMedium:    GoogleFonts.dmSans(fontSize: 14, height: 1.55, color: silverMist),
    bodySmall:     GoogleFonts.dmSans(fontSize: 12, height: 1.4,  color: silverMist),
    labelLarge:    GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: pearlWhite),
    labelMedium:   GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: silverMist),
    labelSmall:    GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: silverMist),
  );

  static TextTheme get _lightTextTheme => TextTheme(
    displayLarge:  GoogleFonts.syne(fontSize: 38, fontWeight: FontWeight.bold,  color: lightTextPrimary, letterSpacing: -1.0, height: 1.2),
    displayMedium: GoogleFonts.syne(fontSize: 30, fontWeight: FontWeight.w700,  color: lightTextPrimary, letterSpacing: -0.5),
    displaySmall:  GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w600,  color: lightTextPrimary),
    headlineLarge: GoogleFonts.syne(fontSize: 22, fontWeight: FontWeight.w700,  color: lightTextPrimary),
    headlineMedium:GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w600,  color: lightTextPrimary),
    headlineSmall: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w600,  color: lightTextPrimary),
    titleLarge:    GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w600, color: lightTextPrimary),
    titleMedium:   GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w500, color: lightTextSecondary),
    titleSmall:    GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500, color: lightTextSecondary),
    bodyLarge:     GoogleFonts.dmSans(fontSize: 16, height: 1.6,  color: lightTextPrimary),
    bodyMedium:    GoogleFonts.dmSans(fontSize: 14, height: 1.55, color: lightTextSecondary),
    bodySmall:     GoogleFonts.dmSans(fontSize: 12, height: 1.4,  color: lightTextSecondary),
    labelLarge:    GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: lightTextPrimary),
    labelMedium:   GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: lightTextSecondary),
    labelSmall:    GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: lightTextSecondary),
  );

  // ============================================================
  //  DARK THEME (primary — AMOLED optimised)
  // ============================================================

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary:           peacockTeal,
        primaryContainer:  IndianTheme.peacockFeather,
        secondary:         royalGold,
        secondaryContainer:IndianTheme.goldShimmer,
        tertiary:          lotusPink,
        surface:           richNavy,
        onPrimary:         pearlWhite,
        onSecondary:       deepOnyx,
        onSurface:         pearlWhite,
        onSurfaceVariant:  silverMist,
        error:             error,
        onError:           pearlWhite,
        outline:           IndianTheme.inkSlate,
        outlineVariant:    IndianTheme.deepSlate,
      ),
      textTheme: _darkTextTheme,
      scaffoldBackgroundColor: deepOnyx,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.syne(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: pearlWhite, letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: pearlWhite),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: inkSlate,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: royalGold.withValues(alpha: 0.12), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: deepSlate,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: inkSlate.withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: inkSlate.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: royalGold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        hintStyle: GoogleFonts.dmSans(color: silverMist, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: peacockTeal,
          foregroundColor: pearlWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: peacockLight,
          side: const BorderSide(color: peacockTeal, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: peacockTeal,
        foregroundColor: pearlWhite,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: deepSlate,
        selectedColor: peacockTeal.withValues(alpha: 0.3),
        labelStyle: GoogleFonts.dmSans(fontSize: 13, color: pearlWhite),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: inkSlate.withValues(alpha: 0.8)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: richNavy,
        selectedItemColor: peacockLight,
        unselectedItemColor: silverMist,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: inkSlate.withValues(alpha: 0.8),
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: deepSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: inkSlate,
        contentTextStyle: GoogleFonts.dmSans(color: pearlWhite),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: deepSlate,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  // ============================================================
  //  LIGHT THEME (modern Indian blend)
  // ============================================================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary:           peacockTeal,
        primaryContainer:  const Color(0xFFDDEFEA),
        secondary:         royalGold,
        secondaryContainer:const Color(0xFFF4E8CC),
        tertiary:          lotusPink,
        surface:           lightSurface,
        onPrimary:         Colors.white,
        onSecondary:       const Color(0xFF2D2416),
        onSurface:         lightTextPrimary,
        onSurfaceVariant:  lightTextSecondary,
        error:             error,
        onError:           Colors.white,
        outline:           lightBorder,
      ),
      textTheme: _lightTextTheme,
      scaffoldBackgroundColor: lightSurface,
      appBarTheme: AppBarTheme(
        backgroundColor: lightCard,
        elevation: 0,
        titleTextStyle: GoogleFonts.syne(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: lightTextPrimary, letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: lightTextPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: lightBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: lightBorder.withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: lightBorder.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: royalGold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        hintStyle: GoogleFonts.dmSans(color: lightTextSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: peacockTeal,
          foregroundColor: pearlWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: peacockTeal,
          side: const BorderSide(color: peacockTeal, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: peacockTeal,
        foregroundColor: pearlWhite,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightCard,
        selectedColor: peacockTeal.withValues(alpha: 0.16),
        labelStyle: GoogleFonts.dmSans(fontSize: 13, color: lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: lightBorder),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: peacockTeal,
        unselectedItemColor: lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: lightBorder,
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightCard,
        contentTextStyle: GoogleFonts.dmSans(color: lightTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  // ============================================================
  //  SHARED DECORATIONS
  // ============================================================

  static BoxDecoration glassDecoration({
    double opacity = 0.9,
    double borderRadius = 20,
    bool hasShadow = true,
  }) {
    return BoxDecoration(
      color: inkSlate.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: royalGold.withValues(alpha: 0.15),
        width: 1,
      ),
      boxShadow: hasShadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    );
  }

  static BoxDecoration aiGlassDecoration({double borderRadius = 20}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [IndianTheme.deepSlate, IndianTheme.inkSlate],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: peacockTeal.withValues(alpha: 0.25),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: peacockTeal.withValues(alpha: 0.10),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration luxuryGlassDecoration({
    double opacity = 0.85,
    double borderRadius = 24,
    bool isDark = true,
  }) => glassDecoration(opacity: opacity, borderRadius: borderRadius);

  // ============================================================
  //  SHADOWS
  // ============================================================

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.4),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get aiGlow => [
    BoxShadow(
      color: peacockTeal.withValues(alpha: 0.20),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> get goldGlow => [
    BoxShadow(
      color: royalGold.withValues(alpha: 0.25),
      blurRadius: 16,
      spreadRadius: 1,
    ),
  ];

  static List<BoxShadow> get successGlow => [
    BoxShadow(
      color: success.withValues(alpha: 0.20),
      blurRadius: 16,
      spreadRadius: 1,
    ),
  ];

  // Legacy alias
  static List<BoxShadow> get successGlowDeprecated => successGlow;

  // ============================================================
  //  BACKGROUND DECORATIONS
  // ============================================================

  static BoxDecoration get frostedGradientBackground => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppTheme.lightSurface, AppTheme.lightCard, AppTheme.lightSurface],
    ),
  );

  static BoxDecoration get frostedGradientBackgroundDark => const BoxDecoration(
    gradient: IndianTheme.amoledGradient,
  );

  // Legacy progress gradient
  static LinearGradient progressGradient(double progress) => LinearGradient(
    colors: [peacockTeal, peacockLight, royalGold.withValues(alpha: 0.6)],
    stops: [0, progress.clamp(0.0, 0.8), 1.0],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

/// FrostedGradientBackground widget — wraps screens with AMOLED-safe BG
class FrostedGradientBackground extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const FrostedGradientBackground({
    super.key,
    required this.child,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isDark
          ? AppTheme.frostedGradientBackgroundDark
          : AppTheme.frostedGradientBackground,
      child: child,
    );
  }
}
