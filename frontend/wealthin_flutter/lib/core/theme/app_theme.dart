import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// WealthIn 2026 "Sovereign Growth" Theme
/// A sophisticated palette balancing Wealth (Green) and Intelligence (Purple)
class AppTheme {
  // ============== CLEAN GROWTH PALETTE ==============

  // Base Layer - Fresh & Clean
  static const mint = Color(0xFFF0FDF4); // Very pale green (Tailwind Green-50)
  static const mintLight = Color(0xFFFFFFFF); // White for cards
  static const mintDark = Color(0xFFDCFCE7); // Green-100

  // Primary Actions - Wealth & Growth
  static const emerald = Color(0xFF16A34A); // Green-600
  static const emeraldDark = Color(0xFF15803D); // Green-700
  static const emeraldLight = Color(0xFF4ADE80); // Green-400

  // Accents - Deep Green & Teal (No Purple/Violet)
  static const royalPurple = Color(0xFF0F766E); // Teal-700 (Replaces Purple)
  static const purpleLight = Color(0xFF14B8A6); // Teal-500
  static const purpleDark = Color(0xFF111827); // Gray-900 (High contrast)
  static const purpleGlow = Color(0xFF2DD4BF); // Teal-400

  // Typography & Contrast
  static const forestGreen = Color(0xFF064E3B); // Green-900
  static const forestLight = Color(0xFF166534); // Green-800
  static const forestMuted = Color(0xFF374151); // Gray-700

  // ============== LEGACY ALIASES ==============
  static const primary = emerald;
  static const primaryLight = emeraldLight;
  static const secondary = royalPurple; // Now Teal
  static const secondaryLight = purpleLight; // Now Teal-Light
  static const tertiary = mint;
  static const accent = royalPurple;
  static const accentLight = purpleLight;

  // Premium Gradient Colors - Fresh Green
  static const gradientStart = emeraldDark;
  static const gradientMiddle = emerald;
  static const gradientEnd = emeraldLight;

  // Glassmorphism Colors
  static const glassWhite = Color(0xFFFFFFFF);
  static const glassMint = Color(0xFFF0FDF4);
  static const glassBorder = Color(0x66FFFFFF);
  static const glassShadow = Color(0x15064E3B); // Green-tinted shadow

  // Semantic Colors
  static const incomeGreen = Color(0xFF16A34A);
  static const expenseRed = Color(0xFFEF4444); // Red-500
  static const success = emerald;
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B); // Amber-500 (Kept for warnings only)
  static const info = royalPurple; // Teal

  // Scribble/Decorative Colors
  static const scribblePrimary = emerald;
  static const scribbleSecondary = purpleLight; // Teal
  static const scribbleTertiary = mintDark;

  static final TextTheme _textTheme = GoogleFonts.interTextTheme();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: emerald,
        primary: emerald,
        secondary: royalPurple,
        tertiary: mint,
        surface: mintLight,
        onSurface: forestGreen,
        primaryContainer: emeraldLight,
        secondaryContainer: purpleLight.withValues(alpha: 0.2),
      ),
      textTheme: _textTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: forestGreen,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: forestGreen,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: forestGreen,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: forestLight,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: forestLight,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: forestMuted,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: forestGreen,
        ),
      ),
      scaffoldBackgroundColor: mint,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: forestGreen,
        ),
        iconTheme: const IconThemeData(color: forestGreen),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: glassWhite,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: mintDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: mintDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: emerald, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: forestMuted.withValues(alpha: 0.6)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: forestGreen,
          side: const BorderSide(color: emerald, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: emerald,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: mintLight,
        selectedColor: emerald.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: forestGreen,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: glassWhite,
        selectedItemColor: emerald,
        unselectedItemColor: forestMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: mintDark.withValues(alpha: 0.5),
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: emerald,
        brightness: Brightness.dark,
        primary: emeraldLight,
        secondary: purpleLight,
        tertiary: const Color(0xFF1A2E23),
        surface: const Color(0xFF0D1512),
        onSurface: const Color(0xFFE8F8F5),
        primaryContainer: const Color(0xFF1E3A2F),
        secondaryContainer: purpleDark.withValues(alpha: 0.3),
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: mintLight,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: mintLight,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: mintLight,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: const Color(0xFFB5E8DE),
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: const Color(0xFFB5E8DE),
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF8FCFBF),
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: mintLight,
        ),
      ),
      scaffoldBackgroundColor: const Color(0xFF0A1210),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: mintLight,
        ),
        iconTheme: const IconThemeData(color: mintLight),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: const Color(0xFF0F1D18),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F1D18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1E3A2F)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1E3A2F)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: emeraldLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: Color(0xFF5A8A7A)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: emeraldLight,
          side: const BorderSide(color: emerald, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: emerald,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1E3A2F),
        selectedColor: emerald.withValues(alpha: 0.3),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: mintLight,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0D1512),
        selectedItemColor: emeraldLight,
        unselectedItemColor: Color(0xFF5A8A7A),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1E3A2F),
        thickness: 1,
      ),
    );
  }

  // ============== GLASSMORPHISM DECORATIONS ==============

  /// Premium Glass Container - The "Glass Dashboard" effect
  static BoxDecoration glassDecoration({
    double opacity = 0.85,
    double borderRadius = 20,
    bool hasShadow = true,
    bool hasMintTint = false,
  }) {
    return BoxDecoration(
      color: hasMintTint
          ? glassMint.withValues(alpha: opacity)
          : glassWhite.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: glassBorder,
        width: 1.5,
      ),
      boxShadow: hasShadow
          ? [
              BoxShadow(
                color: glassShadow,
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: glassWhite.withValues(alpha: 0.6),
                blurRadius: 0,
                spreadRadius: 0,
                offset: const Offset(0, -1),
              ),
            ]
          : null,
    );
  }

  /// AI/Agentic Glass Container - Teal tinted
  static BoxDecoration aiGlassDecoration({
    double opacity = 0.95,
    double borderRadius = 20,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          glassWhite.withValues(alpha: opacity),
          purpleLight.withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: royalPurple.withValues(alpha: 0.2),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: royalPurple.withValues(alpha: 0.08),
          blurRadius: 20,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ============== GRADIENTS ==============

  /// Sovereign Premium Gradient - Teal intelligence
  static LinearGradient get premiumGradient => const LinearGradient(
    colors: [royalPurple, purpleLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Growth Gradient - Green wealth
  static LinearGradient get growthGradient => const LinearGradient(
    colors: [emerald, emeraldLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Background gradient - Subtle mint
  static LinearGradient get subtleGradient => LinearGradient(
    colors: [
      mint,
      mintLight,
      glassWhite,
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// AI Advisor specific gradient - Sovereign Teal
  static LinearGradient get aiGradient => const LinearGradient(
    colors: [
      royalPurple, // Teal-700
      Color(0xFF14B8A6), // Teal-500
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Progress bar gradient with AI glow projection
  static LinearGradient progressGradient(double progress) => LinearGradient(
    colors: [
      emerald,
      emeraldLight,
      purpleGlow.withValues(alpha: 0.6), // AI projection
    ],
    stops: [0, progress.clamp(0.0, 0.8), 1.0],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ============== SHADOWS ==============

  /// Soft elevation shadow
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: forestGreen.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Teal glow for AI elements
  static List<BoxShadow> get aiGlow => [
    BoxShadow(
      color: royalPurple.withValues(alpha: 0.15),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  /// Green glow for success/wealth elements
  static List<BoxShadow> get successGlow => [
    BoxShadow(
      color: emerald.withValues(alpha: 0.2),
      blurRadius: 16,
      spreadRadius: 1,
    ),
  ];
}
