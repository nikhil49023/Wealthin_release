import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// WealthIn 2026 "Premium Finance" Theme
/// Classic, professional design with refined color palette
class AppTheme {
  // ============== CORE PALETTE - PREMIUM NAVY & GOLD ==============

  // Base Layer - Clean White
  static const cream = Color(0xFFFAFBFC); // Soft off-white
  static const white = Color(0xFFFFFFFF); // Pure white
  static const surface = Color(0xFFF8F9FA); // Light gray surface

  // Primary - Deep Navy (Professional Authority)
  static const navy = Color(0xFF1A365D); // Deep navy blue
  static const navyLight = Color(0xFF2C5282); // Medium navy
  static const navyDark = Color(0xFF0F2744); // Extra dark navy

  // Accent - Gold (Wealth & Premium)
  static const gold = Color(0xFFD69E2E); // Rich gold
  static const goldLight = Color(0xFFECC94B); // Light gold
  static const goldDark = Color(0xFFB7791F); // Deep gold

  // Success/Income - Emerald
  static const emerald = Color(0xFF059669); // Rich emerald
  static const emeraldLight = Color(0xFF10B981); // Light emerald

  // Error/Expense - Coral Red
  static const coral = Color(0xFFDC2626); // Modern red
  static const coralLight = Color(0xFFEF4444); // Light coral

  // Typography - Slate Scale
  static const slate900 = Color(0xFF0F172A); // Near black
  static const slate700 = Color(0xFF334155); // Dark gray
  static const slate500 = Color(0xFF64748B); // Medium gray
  static const slate300 = Color(0xFFCBD5E1); // Light gray

  // ============== SEMANTIC ALIASES ==============
  static const primary = navy;
  static const primaryLight = navyLight;
  static const secondary = gold;
  static const secondaryLight = goldLight;
  static const tertiary = cream;
  static const accent = gold;
  static const accentLight = goldLight;

  // Gradient Colors
  static const gradientStart = navyDark;
  static const gradientMiddle = navy;
  static const gradientEnd = navyLight;

  // Glassmorphism Colors
  static const glassWhite = Color(0xFFFFFFFF);
  static const glassMint = Color(0xFFF8FAFC);
  static const glassBorder = Color(0x1A000000);
  static const glassShadow = Color(0x0A000000);

  // Semantic Colors  
  static const incomeGreen = emerald;
  static const expenseRed = coral;
  static const success = emerald;
  static const error = coral;
  static const warning = Color(0xFFF59E0B);
  static const info = navyLight;

  // Scribble/Decorative Colors
  static const scribblePrimary = navy;
  static const scribbleSecondary = gold;
  static const scribbleTertiary = emerald;

  // ============== BACKWARD COMPATIBILITY - OLD COLOR ALIASES ==============
  // These map old color names to the new premium palette
  static const royalPurple = Color(0xFF5B21B6); // Deep purple for AI elements
  static const purpleLight = Color(0xFFA78BFA); // Light purple
  static const purpleDark = Color(0xFF3B0D7D); // Darker purple
  static const purpleGlow = Color(0x33A78BFA); // Purple glow with alpha
  static const forestGreen = slate900; // Dark text (was green, now neutral)
  static const forestLight = slate700; // Medium text
  static const forestMuted = slate500; // Muted text
  static const mint = cream; // Light background
  static const mintLight = surface; // Lighter background
  static const mintDark = slate300; // Border/separator color

  // Modern text themes using Poppins + Source Sans Pro
  static TextTheme get _modernTextTheme => GoogleFonts.sourceSans3TextTheme();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: gold,
        tertiary: cream,
        surface: white,
        onSurface: slate900,
        primaryContainer: navyLight,
        secondaryContainer: goldLight.withValues(alpha: 0.2),
      ),
      textTheme: _modernTextTheme.copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: slate900,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: slate900,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: slate900,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: slate700,
        ),
        bodyLarge: GoogleFonts.sourceSans3(
          fontSize: 16,
          color: slate700,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.sourceSans3(
          fontSize: 14,
          color: slate500,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.sourceSans3(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: slate900,
        ),
      ),
      scaffoldBackgroundColor: cream,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: slate900,
        ),
        iconTheme: const IconThemeData(color: slate900),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: slate300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: slate300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navy, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: slate500.withValues(alpha: 0.6)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(color: navy, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: gold,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: gold.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.sourceSans3(
          fontSize: 13,
          color: slate900,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: white,
        selectedItemColor: navy,
        unselectedItemColor: slate500,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: slate300.withValues(alpha: 0.5),
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
