import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color Constants for WealthIn App
/// Can be used directly: WealthInColors.primary, WealthInColors.success, etc.
class WealthInColors {
  WealthInColors._();

  // Primary Colors
  static const primary = Color(0xFF0A1628);
  static const primaryLight = Color(0xFF1A2942);

  // Semantic Colors
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFF34D399);
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFF87171);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF7C3AED);

  // Background Colors
  static const background = Color(0xFFF3F4F6);
  static const surfaceLight = Color(0xFFF9FAFB);
  static const white = Color(0xFFFFFFFF);

  // Text Colors
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFD1D5DB);

  // Dark Mode Colors
  static const black = Color(0xFF000000);
  static const blackLight = Color(0xFF0A0A0A);
  static const blackCard = Color(0xFF121212);
  static const blackElevated = Color(0xFF1A1A1A);
  static const blackBorder = Color(0xFF262626);
  static const textPrimaryDark = Color(0xFFF9FAFB);
  static const textSecondaryDark = Color(0xFF9CA3AF);
}

/// WealthIn 2026 Professional Theme
/// Formal color scheme with deep black dark mode
class WealthInTheme {
  WealthInTheme._();

  // ============== PROFESSIONAL COLOR PALETTE ==============

  // Primary - Professional Navy
  static const navy = Color(0xFF0A1628);
  static const navyLight = Color(0xFF1A2942);
  static const navyMuted = Color(0xFF2D3F5C);

  // Accent - Refined Gold/Amber
  static const gold = Color(0xFFD4AF37);
  static const goldLight = Color(0xFFE8C547);
  static const goldMuted = Color(0xFFF5E6A3);

  // Success/Income - Emerald Green
  static const emerald = Color(0xFF10B981);
  static const emeraldLight = Color(0xFF34D399);
  static const emeraldDark = Color(0xFF059669);

  // Expense/Alert - Coral Red
  static const coral = Color(0xFFEF4444);
  static const coralLight = Color(0xFFF87171);
  static const coralDark = Color(0xFFDC2626);

  // AI/Intelligence - Royal Purple
  static const purple = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFA78BFA);
  static const purpleDark = Color(0xFF5B21B6);

  // Neutral - Professional Grays
  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray700 = Color(0xFF374151);
  static const gray800 = Color(0xFF1F2937);
  static const gray900 = Color(0xFF111827);

  // ============== DARK MODE - DEEP BLACKS ==============

  static const black = Color(0xFF000000);
  static const blackLight = Color(0xFF0A0A0A);
  static const blackCard = Color(0xFF121212);
  static const blackElevated = Color(0xFF1A1A1A);
  static const blackBorder = Color(0xFF262626);

  // Dark mode accent colors (sharper/brighter)
  static const darkEmerald = Color(0xFF22C55E);
  static const darkCoral = Color(0xFFF87171);
  static const darkPurple = Color(0xFFA78BFA);
  static const darkGold = Color(0xFFFBBF24);

  // ============== SEMANTIC COLORS ==============

  static const income = emerald;
  static const expense = coral;
  static const savings = gold;
  static const warning = Color(0xFFF59E0B);
  static const info = purple;

  // ============== GRADIENTS ==============

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, navyLight],
  );

  static const successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [emerald, emeraldLight],
  );

  // ============== TYPOGRAPHY ==============

  static TextTheme get _baseTextTheme => GoogleFonts.interTextTheme();

  // ============== LIGHT THEME ==============

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: navy,
        onPrimary: Colors.white,
        primaryContainer: navyLight,
        onPrimaryContainer: Colors.white,
        secondary: emerald,
        onSecondary: Colors.white,
        secondaryContainer: emeraldLight.withOpacity(0.2),
        onSecondaryContainer: emeraldDark,
        tertiary: purple,
        onTertiary: Colors.white,
        tertiaryContainer: purpleLight.withOpacity(0.2),
        onTertiaryContainer: purpleDark,
        surface: gray50,
        onSurface: gray900,
        surfaceContainerHighest: Colors.white,
        onSurfaceVariant: gray600,
        outline: gray300,
        outlineVariant: gray200,
        error: coral,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: gray100,
      textTheme: _baseTextTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: navy,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: navy,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: navy,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: navy,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: gray900,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: gray800,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: gray700,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: gray700,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: gray600,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: gray500,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: gray900,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: gray700,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: gray500,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: navy,
        ),
        iconTheme: const IconThemeData(color: navy),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: gray200),
        ),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: gray300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: gray300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: navy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: coral),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: gray400),
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
          textStyle: GoogleFonts.inter(
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
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: navy,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: emerald,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: gray100,
        selectedColor: navy.withOpacity(0.1),
        labelStyle: GoogleFonts.inter(fontSize: 13, color: gray700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: gray300),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: navy,
        unselectedItemColor: gray400,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: navy.withOpacity(0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: navy,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: gray500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: navy, size: 24);
          }
          return IconThemeData(color: gray400, size: 24);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: gray200,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: gray900,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  // ============== DARK THEME - DEEP BLACKS ==============

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: darkEmerald,
        onPrimary: black,
        primaryContainer: darkEmerald.withOpacity(0.2),
        onPrimaryContainer: darkEmerald,
        secondary: darkPurple,
        onSecondary: black,
        secondaryContainer: darkPurple.withOpacity(0.2),
        onSecondaryContainer: darkPurple,
        tertiary: darkGold,
        onTertiary: black,
        tertiaryContainer: darkGold.withOpacity(0.2),
        onTertiaryContainer: darkGold,
        surface: blackCard,
        onSurface: Colors.white,
        surfaceContainerHighest: blackElevated,
        onSurfaceVariant: gray400,
        outline: blackBorder,
        outlineVariant: Color(0xFF333333),
        error: darkCoral,
        onError: black,
      ),
      scaffoldBackgroundColor: black,
      textTheme: _baseTextTheme.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: gray200,
        ),
        titleSmall: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: gray300,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: gray300,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: gray400,
          height: 1.5,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: gray500,
          height: 1.4,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: gray300,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: gray500,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: black,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: blackBorder),
        ),
        color: blackCard,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: blackElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: blackBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: blackBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkEmerald, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkCoral),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: gray600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkEmerald,
          foregroundColor: black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkEmerald,
          side: const BorderSide(color: darkEmerald, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkEmerald,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: darkEmerald,
        foregroundColor: black,
        elevation: 2,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: blackElevated,
        selectedColor: darkEmerald.withOpacity(0.2),
        labelStyle: GoogleFonts.inter(fontSize: 13, color: gray300),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(color: blackBorder),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: blackCard,
        selectedItemColor: darkEmerald,
        unselectedItemColor: gray500,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: blackCard,
        surfaceTintColor: Colors.transparent,
        indicatorColor: darkEmerald.withOpacity(0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: darkEmerald,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: gray500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: darkEmerald, size: 24);
          }
          return IconThemeData(color: gray500, size: 24);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: blackBorder,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: blackElevated,
        contentTextStyle: GoogleFonts.inter(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: blackCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: blackCard,
        shape: const RoundedRectangleBorder(
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
      return isDark ? darkEmerald : emerald;
    } else {
      return isDark ? darkCoral : coral;
    }
  }

  /// Get AI/chat bubble color
  static Color getAIColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkPurple : purple;
  }

  /// Card decoration with subtle shadow
  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? blackCard : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isDark ? blackBorder : gray200,
      ),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: gray900.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }

  /// Elevated card decoration
  static BoxDecoration elevatedCardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? blackElevated : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isDark ? blackBorder : gray200,
      ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : [
              BoxShadow(
                color: gray900.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  /// Gradient for income
  static LinearGradient incomeGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      colors: isDark
          ? [darkEmerald.withOpacity(0.8), darkEmerald]
          : [emeraldLight, emerald],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Gradient for expense
  static LinearGradient expenseGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      colors: isDark
          ? [darkCoral.withOpacity(0.8), darkCoral]
          : [coralLight, coral],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// AI/Chat gradient
  static LinearGradient aiGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      colors: isDark
          ? [darkPurple.withOpacity(0.8), darkPurple]
          : [purpleLight, purple],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
