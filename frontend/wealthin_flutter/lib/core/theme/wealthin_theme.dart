import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

/// ============================================================
/// WEALTHIN 2026 SOVEREIGN THEME
/// "The Emerald Vault" (Dark) & "The Ivory Mint" (Light)
/// ============================================================

/// Color Constants for WealthIn App - 2026 Sovereign Edition
class WealthInColors {
  WealthInColors._();

  // ============== DARK MODE: "THE EMERALD VAULT" ==============
  // AMOLED-optimized deep blacks with cyan accents (better on dark)
  
  /// Deep Obsidian - Main background for AMOLED
  static const deepObsidian = Color(0xFF040D08);
  
  /// Vault Green - Card surfaces (recessed tray look)
  static const vaultGreen = Color(0xFF0D1F14);
  
  /// Cyan Glow - Primary action color for dark mode (better than green)
  static const cyanGlow = Color(0xFF22D3EE);  // Tailwind cyan-400
  
  /// Emerald Glow - Secondary/Income color
  static const emeraldGlow = Color(0xFF50C878);
  
  /// Regal Gold - Premium features & high-value alerts
  static const regalGold = Color(0xFFD4AF37);
  
  /// Pure Frost - High-legibility text (off-white with green tint)
  static const pureFrost = Color(0xFFF2FBF5);
  
  /// Jade Shadow - Secondary text, borders, inactive states
  static const jadeShadow = Color(0xFF4A6353);

  // ============== LIGHT MODE: "THE IVORY MINT" ==============
  // Premium stationery feel, avoiding stark white
  
  /// Ivory Mist - Main background
  static const ivoryMist = Color(0xFFFBFDFA);
  
  /// Paper White - Card surfaces
  static const paperWhite = Color(0xFFFFFFFF);
  
  /// Mint Border - Subtle card borders
  static const mintBorder = Color(0xFFE8F2EC);
  
  /// True Emerald - Primary CTA and text
  static const trueEmerald = Color(0xFF046307);
  
  /// Vintage Gold - Sophisticated gold indicators
  static const vintageGold = Color(0xFFB8860B);
  
  /// Deep Forest - Headlines and primary text
  static const deepForest = Color(0xFF06130B);
  
  /// Sage Gray - Captions, labels, disabled elements
  static const sageGray = Color(0xFF8FBC8F);

  // ============== SEMANTIC COLORS ==============
  
  /// Success/Income indicator
  static const success = emeraldGlow;
  static const successLight = Color(0xFF6FE097);
  
  /// Error/Expense indicator
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFF87171);
  
  /// Warning
  static const warning = Color(0xFFF59E0B);
  
  /// Info/AI
  static const info = Color(0xFF7C3AED);

  // ============== LEGACY COMPATIBILITY ==============
  // These maintain backward compatibility with existing code
  
  static const primary = trueEmerald;
  static const primaryLight = emeraldGlow;
  static const background = ivoryMist;
  static const surfaceLight = paperWhite;
  static const white = paperWhite;
  static const textPrimary = deepForest;
  static const textSecondary = jadeShadow;
  static const border = mintBorder;
  
  // Dark mode legacy
  static const black = deepObsidian;
  static const blackLight = Color(0xFF061A0D);
  static const blackCard = vaultGreen;
  static const blackSurface = Color(0xFF0F2518);
  static const blackElevated = Color(0xFF132B1C);
  static const blackBorder = Color(0xFF1A3D24);
  static const textPrimaryDark = pureFrost;
  static const textSecondaryDark = jadeShadow;
}

/// WealthIn 2026 Sovereign Theme
/// Premium, depth-focused design with emerald wealth aesthetic
class WealthInTheme {
  WealthInTheme._();

  // ============== SOVEREIGN COLOR PALETTE ==============

  // Dark Mode Colors
  static const deepObsidian = WealthInColors.deepObsidian;
  static const vaultGreen = WealthInColors.vaultGreen;
  static const cyanGlow = WealthInColors.cyanGlow; // Primary for dark mode
  static const emeraldGlow = WealthInColors.emeraldGlow;
  static const regalGold = WealthInColors.regalGold;
  static const pureFrost = WealthInColors.pureFrost;
  static const jadeShadow = WealthInColors.jadeShadow;

  // Light Mode Colors
  static const ivoryMist = WealthInColors.ivoryMist;
  static const paperWhite = WealthInColors.paperWhite;
  static const mintBorder = WealthInColors.mintBorder;
  static const trueEmerald = WealthInColors.trueEmerald;
  static const vintageGold = WealthInColors.vintageGold;
  static const deepForest = WealthInColors.deepForest;
  static const sageGray = WealthInColors.sageGray;

  // Semantic
  static const income = emeraldGlow;
  static const expense = Color(0xFFEF4444);
  static const savings = regalGold;
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF7C3AED);

  // Secondary emerald shades
  static const emeraldDark = Color(0xFF2E8B57);
  static const emeraldLight = Color(0xFF6FE097);

  // Legacy compatibility
  static const navy = trueEmerald;
  static const navyLight = emeraldGlow;
  static const gold = regalGold;
  static const emerald = emeraldGlow;
  static const coral = Color(0xFFEF4444);
  static const purple = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFA78BFA);
  static const purpleDark = Color(0xFF5B21B6);
  static const black = deepObsidian;
  static const blackCard = vaultGreen;
  static const blackElevated = Color(0xFF132B1C);
  static const blackBorder = Color(0xFF1A3D24);
  static const gray50 = ivoryMist;
  static const gray100 = Color(0xFFF3F7F4);
  static const gray200 = mintBorder;
  static const gray300 = Color(0xFFCCDDD2);
  static const gray400 = sageGray;
  static const gray500 = jadeShadow;
  static const gray600 = Color(0xFF3D5346);
  static const gray700 = Color(0xFF2D3F33);
  static const gray800 = Color(0xFF1F2B24);
  static const gray900 = deepForest;
  static const darkEmerald = emeraldGlow;
  static const darkCoral = Color(0xFFF87171);
  static const darkPurple = Color(0xFFA78BFA);
  static const darkGold = regalGold;

  // ============== GRADIENTS ==============

  /// Primary gradient for dark mode buttons
  static const primaryGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [emeraldGlow, emeraldDark],
  );

  /// Primary gradient for light mode buttons
  static const primaryGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [trueEmerald, emeraldDark],
  );

  /// Legacy gradient
  static const primaryGradient = primaryGradientDark;
  static const successGradient = primaryGradientDark;

  /// AI Glow effect for agent avatar
  static BoxShadow aiGlowShadow = BoxShadow(
    color: emeraldGlow.withOpacity(0.6),
    blurRadius: 15,
    spreadRadius: 5,
  );

  // ============== TYPOGRAPHY - 2026 Sovereign ==============

  /// Headlines (Brand): Plus Jakarta Sans
  static TextStyle get headlineFont => GoogleFonts.plusJakartaSans();
  
  /// Financials (Data): JetBrains Mono for currency values
  static TextStyle get moneyFont => GoogleFonts.jetBrainsMono();

  // ============== LIGHT THEME: "THE IVORY MINT" ==============

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: trueEmerald,
        onPrimary: Colors.white,
        primaryContainer: emeraldGlow.withOpacity(0.15),
        onPrimaryContainer: trueEmerald,
        secondary: vintageGold,
        onSecondary: Colors.white,
        secondaryContainer: vintageGold.withOpacity(0.15),
        onSecondaryContainer: vintageGold,
        tertiary: info,
        onTertiary: Colors.white,
        surface: ivoryMist,
        onSurface: deepForest,
        surfaceContainerHighest: paperWhite,
        onSurfaceVariant: jadeShadow,
        outline: mintBorder,
        outlineVariant: Color(0xFFD8EDE0),
        error: expense,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: ivoryMist,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: deepForest,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: deepForest,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: deepForest,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: deepForest,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: deepForest,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: gray700,
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: jadeShadow,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: gray700,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: jadeShadow,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: sageGray,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: deepForest,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: jadeShadow,
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: sageGray,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: paperWhite,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: deepForest,
        ),
        iconTheme: IconThemeData(color: trueEmerald),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: mintBorder),
        ),
        color: paperWhite,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paperWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mintBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mintBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: trueEmerald, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: expense),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: sageGray),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: trueEmerald,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: trueEmerald,
          side: BorderSide(color: trueEmerald, width: 1.5),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: trueEmerald,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: trueEmerald,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ivoryMist,
        selectedColor: trueEmerald.withOpacity(0.15),
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: jadeShadow),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: mintBorder),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: paperWhite,
        selectedItemColor: trueEmerald,
        unselectedItemColor: sageGray,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paperWhite,
        indicatorColor: trueEmerald.withOpacity(0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: trueEmerald,
            );
          }
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: sageGray,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: trueEmerald, size: 24);
          }
          return IconThemeData(color: sageGray, size: 24);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: mintBorder,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: deepForest,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paperWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: paperWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  // ============== DARK THEME: "THE EMERALD VAULT" ==============

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: cyanGlow, // Using cyan for dark mode (better contrast)
        onPrimary: deepObsidian,
        primaryContainer: cyanGlow.withOpacity(0.2),
        onPrimaryContainer: cyanGlow,
        secondary: regalGold,
        onSecondary: deepObsidian,
        secondaryContainer: regalGold.withOpacity(0.2),
        onSecondaryContainer: regalGold,
        tertiary: emeraldGlow, // Keep emerald for tertiary/income
        onTertiary: deepObsidian,
        surface: vaultGreen,
        onSurface: pureFrost,
        surfaceContainerHighest: Color(0xFF132B1C),
        onSurfaceVariant: jadeShadow,
        outline: Color(0xFF1A3D24),
        outlineVariant: Color(0xFF254830),
        error: Color(0xFFF87171),
        onError: deepObsidian,
      ),
      scaffoldBackgroundColor: deepObsidian,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: pureFrost,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: pureFrost,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: pureFrost,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: pureFrost,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: pureFrost,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFFD0E8D8),
        ),
        titleSmall: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFFB0D0BC),
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: Color(0xFFB0D0BC),
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: jadeShadow,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: Color(0xFF5A7363),
          height: 1.4,
        ),
        labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: pureFrost,
        ),
        labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFFB0D0BC),
        ),
        labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: jadeShadow,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: deepObsidian,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: pureFrost,
        ),
        iconTheme: IconThemeData(color: emeraldGlow),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Color(0xFF1A3D24)),
        ),
        color: vaultGreen,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF132B1C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFF1A3D24)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFF1A3D24)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: emeraldGlow, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFFF87171)),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: jadeShadow),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emeraldGlow,
          foregroundColor: deepObsidian,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: emeraldGlow,
          side: BorderSide(color: emeraldGlow, width: 1.5),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: emeraldGlow,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: emeraldGlow,
        foregroundColor: deepObsidian,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Color(0xFF132B1C),
        selectedColor: emeraldGlow.withOpacity(0.2),
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, color: Color(0xFFB0D0BC)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: Color(0xFF1A3D24)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: vaultGreen,
        selectedItemColor: emeraldGlow,
        unselectedItemColor: jadeShadow,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: vaultGreen,
        surfaceTintColor: Colors.transparent,
        indicatorColor: emeraldGlow.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: emeraldGlow,
            );
          }
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: jadeShadow,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: emeraldGlow, size: 24);
          }
          return IconThemeData(color: jadeShadow, size: 24);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: Color(0xFF1A3D24),
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Color(0xFF132B1C),
        contentTextStyle: GoogleFonts.plusJakartaSans(color: pureFrost),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: vaultGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: vaultGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  // ============== HELPER METHODS ==============

  /// Get semantic color for transaction type
  static Color getTransactionColor(String type, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (type == 'income') {
      return emeraldGlow;
    } else {
      return isDark ? Color(0xFFF87171) : expense;
    }
  }

  /// Get AI/chat bubble color
  static Color getAIColor(BuildContext context) {
    return info;
  }

  /// Format currency with JetBrains Mono
  static TextStyle currencyStyle(BuildContext context, {double fontSize = 18, FontWeight fontWeight = FontWeight.w600}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: isDark ? pureFrost : deepForest,
    );
  }

  /// Card decoration with subtle shadow
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? vaultGreen : paperWhite,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? Color(0xFF1A3D24) : mintBorder,
      ),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: deepForest.withOpacity(0.04),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
    );
  }

  /// Elevated card decoration
  static BoxDecoration elevatedCardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? Color(0xFF132B1C) : paperWhite,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? Color(0xFF1A3D24) : mintBorder,
      ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ]
          : [
              BoxShadow(
                color: deepForest.withOpacity(0.08),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
    );
  }

  /// Glassmorphism decoration for bottom nav
  static BoxDecoration glassDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark 
          ? vaultGreen.withOpacity(0.85) 
          : paperWhite.withOpacity(0.85),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark 
            ? Colors.white.withOpacity(0.1) 
            : Colors.white.withOpacity(0.5),
        width: 1,
      ),
    );
  }

  /// Gradient for income
  static LinearGradient incomeGradient(BuildContext context) {
    return LinearGradient(
      colors: [emeraldGlow, emeraldDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Gradient for expense
  static LinearGradient expenseGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      colors: isDark
          ? [Color(0xFFF87171).withOpacity(0.8), Color(0xFFF87171)]
          : [Color(0xFFF87171), expense],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// AI/Chat gradient
  static LinearGradient aiGradient(BuildContext context) {
    return LinearGradient(
      colors: [info.withOpacity(0.8), info],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Primary button gradient
  static LinearGradient buttonGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? primaryGradientDark : primaryGradientLight;
  }
}
