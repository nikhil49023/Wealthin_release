import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// WealthIn 2026 "Luxury Finance" Theme
/// Premium glassmorphism design with psychologically calming luxury colors
class AppTheme {
  // ============== LUXURY COLOR PALETTE ==============
  
  // Mint & Emerald Family (Growth, Prosperity)
  static const mintWhisper = Color(0xFFF7F9F8);      // Very soft mint-gray (neutral)
  static const emeraldGreen = Color(0xFF2E7D32);     // Rich emerald primary
  static const emeraldLight = Color(0xFF4CAF50);     // Light emerald accent
  static const darkEvergreen = Color(0xFF1B5E20);    // Deep forest

  // Purple & Amethyst Family (Luxury, Creativity)
  static const lilacMist = Color(0xFFE1BEE7);        // Soft lilac surface
  static const softViolet = Color(0xFF9575CD);       // Gentle violet
  static const royalAmethyst = Color(0xFF7B1FA2);    // Royal purple primary
  static const midnightPlum = Color(0xFF4A148C);     // Deep plum for dark mode

  // Rose & Coral Family (Warmth, Energy)
  static const softBlush = Color(0xFFFCE4EC);        // Soft pink surface
  static const roseGold = Color(0xFFE8B4B8);         // Elegant rose gold
  static const crimsonSilk = Color(0xFFE57373);      // Silk red accent
  static const rubyRed = Color(0xFFC62828);          // Ruby for emphasis
  static const deepBordeaux = Color(0xFF7F0000);     // Deep wine

  // Blue & Sapphire Family (Trust, Stability)
  static const iceBlue = Color(0xFFE3F2FD);          // Ice blue surface
  static const powderBlue = Color(0xFF90CAF9);       // Gentle blue accent
  static const sapphire = Color(0xFF1976D2);         // Sapphire primary
  static const deepNavy = Color(0xFF0D1B2A);         // Navy for dark mode

  // Copper & Mahogany Family (Premium, Grounded)
  static const mutedCopper = Color(0xFFBCAAA4);      // Soft copper
  static const darkMahogany = Color(0xFF4E342E);     // Deep brown

  // ============== THEME ALIASES ==============
  // Light Theme Base
  static const cream = Color(0xFFFBFCFB);            // Very soft off-white
  static const white = Color(0xFFFCFDFC);
  static const surface = Color(0xFFF5F7F6);          // Muted light gray-mint
  static const warmCream = Color(0xFFFAF9F7);

  // Dark Theme Base (Deep Navy, NOT pure black)
  static const oceanDeep = deepNavy;
  static const oceanMid = Color(0xFF1B263B);
  static const oceanLight = Color(0xFF415A77);
  static const oceanMist = Color(0xFF778DA9);

  // Primary Semantic
  static const primary = emeraldGreen;
  static const primaryLight = emeraldLight;
  static const sereneTeal = Color(0xFF2A9D8F);
  static const sereneTealLight = Color(0xFF40B4A4);
  static const sereneTealDark = Color(0xFF1A7A70);

  // Secondary Semantic
  static const secondary = royalAmethyst;
  static const secondaryLight = softViolet;
  static const lavender = lilacMist;
  static const lavenderLight = Color(0xFFCE93D8);
  static const lavenderMist = lilacMist;

  // Accent
  static const accent = roseGold;
  static const accentLight = softBlush;
  static const warmCoral = Color(0xFFE07A5F);
  static const peach = Color(0xFFF2CC8F);
  static const tertiary = cream;

  // Success/Income
  static const sageGreen = Color(0xFF81B29A);
  static const sageLight = Color(0xFFA8D5BA);
  static const success = emeraldGreen;
  static const incomeGreen = emeraldGreen;
  static const emerald = emeraldGreen; // Alias for backward compatibility

  // Error/Expense
  static const mutedRose = crimsonSilk;
  static const coral = rubyRed;
  static const coralLight = Color(0xFFEF5350);
  static const error = rubyRed;
  static const expenseRed = crimsonSilk;

  // Warning/Info
  static const warning = Color(0xFFFFA726);
  static const info = sapphire;

  // Typography Scale
  static const slate900 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate100 = Color(0xFFF1F5F9);

  // Legacy Aliases
  static const navy = oceanDeep;
  static const navyLight = oceanMid;
  static const navyDark = Color(0xFF0A1628);
  static const gold = roseGold;
  static const goldLight = Color(0xFFF7DBA7);
  static const goldDark = Color(0xFFD4A574);
  static const royalPurple = royalAmethyst;
  static const purpleLight = softViolet;
  static const purpleDark = midnightPlum;
  static const purpleGlow = Color(0x33CE93D8);
  static const forestGreen = slate900;
  static const forestLight = slate700;
  static const forestMuted = slate500;
  static const mint = cream;
  static const mintLight = surface;
  static const mintDark = slate300;

  // Gradient Colors
  static const gradientStart = darkEvergreen;
  static const gradientMiddle = emeraldGreen;
  static const gradientEnd = emeraldLight;

  // Glassmorphism System
  static const glassWhite = Color(0xFFFAFCFB);
  static const glassMint = mintWhisper;
  static const glassBorder = Color(0x20000000);
  static const glassShadow = Color(0x10000000);

  // Scribble/Decorative
  static const scribblePrimary = emeraldGreen;
  static const scribbleSecondary = royalAmethyst;
  static const scribbleTertiary = sapphire;

  // ============== GLASSMORPHISM DECORATIONS ==============
  
  /// Luxury Glass Card - Multi-layer effect
  static BoxDecoration luxuryGlassDecoration({
    double opacity = 0.85,
    double borderRadius = 24,
    bool isDark = false,
  }) {
    return BoxDecoration(
      // Layer 1: Gradient Fill
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
          ? [oceanMid.withValues(alpha: opacity), oceanDeep.withValues(alpha: opacity * 0.9)]
          : [glassWhite.withValues(alpha: opacity), glassMint.withValues(alpha: opacity * 0.95)],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      // Layer 2: Border for glass frame
      border: Border.all(
        color: isDark ? oceanLight.withValues(alpha: 0.3) : glassBorder,
        width: 1.5,
      ),
      // Layer 3: Inner Shadow (simulated via box shadow)
      boxShadow: [
        // Outer shadow for lift
        BoxShadow(
          color: isDark ? Colors.black.withValues(alpha: 0.4) : glassShadow,
          blurRadius: 20,
          spreadRadius: -2,
          offset: const Offset(0, 8),
        ),
        // Inner light for glass effect
        BoxShadow(
          color: isDark ? oceanLight.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.6),
          blurRadius: 0,
          spreadRadius: 0,
          offset: const Offset(0, -1),
        ),
      ],
    );
  }

  /// Premium Gradient Button
  static LinearGradient get premiumGradient => const LinearGradient(
    colors: [emeraldGreen, sereneTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Amethyst Gradient for AI/Special elements
  static LinearGradient get amethystGradient => const LinearGradient(
    colors: [royalAmethyst, softViolet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Growth Gradient
  static LinearGradient get growthGradient => const LinearGradient(
    colors: [emeraldGreen, emeraldLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Subtle Background Gradient
  static LinearGradient get subtleGradient => LinearGradient(
    colors: [mintWhisper, surface, glassWhite],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// AI Advisor Gradient
  static LinearGradient get aiGradient => const LinearGradient(
    colors: [royalAmethyst, sapphire],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Premium text themes: Playfair Display (luxury serif headlines) + DM Sans (modern body)
  static TextTheme get _modernTextTheme => GoogleFonts.dmSansTextTheme();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: sereneTeal,
        primary: sereneTeal,
        secondary: lavender,
        tertiary: sageGreen,
        surface: cream, // Soft sage-cream, not plain white
        onSurface: slate900,
        primaryContainer: sereneTealLight.withValues(alpha: 0.2),
        secondaryContainer: lavenderMist,
      ),
      textTheme: _modernTextTheme.copyWith(
        // Luxury serif for large display text
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: slate900,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: slate900,
          letterSpacing: -0.3,
        ),
        // Modern sans for headlines
        headlineMedium: GoogleFonts.dmSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: slate900,
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: slate900,
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: slate700,
        ),
        // Clean body text
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16,
          color: slate700,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14,
          color: slate500,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: slate900,
        ),
      ),
      scaffoldBackgroundColor: cream, // Soft sage-cream background
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
        color: white, // Warm white cards on sage background
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: slate300.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: slate300.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: sereneTeal, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: slate500.withValues(alpha: 0.6)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: sereneTeal,
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
          foregroundColor: sereneTeal,
          side: const BorderSide(color: sereneTeal, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: sereneTeal,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: sereneTeal.withValues(alpha: 0.15),
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
        selectedItemColor: sereneTeal,
        unselectedItemColor: slate500,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: sageGreen.withValues(alpha: 0.2),
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    // Deep Ocean Blue theme - calming, reduces eye strain, improves focus
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: sereneTeal,
        brightness: Brightness.dark,
        primary: sereneTealLight,
        secondary: lavenderLight,
        tertiary: sageLight,
        surface: oceanDeep, // Deep ocean blue, NOT pure black
        onSurface: const Color(0xFFE0E7ED),
        primaryContainer: oceanMid,
        secondaryContainer: oceanLight.withValues(alpha: 0.3),
      ),
      textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme).copyWith(
        // Luxury serif for display text
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFE8EEF4),
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFE8EEF4),
          letterSpacing: -0.3,
        ),
        // Modern sans for headlines & body
        headlineMedium: GoogleFonts.dmSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFE8EEF4),
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFE8EEF4),
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: oceanMist,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16,
          color: oceanMist,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14,
          color: const Color(0xFF94A3B8),
          height: 1.5,
        ),
        labelLarge: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFE8EEF4),
        ),
      ),
      scaffoldBackgroundColor: oceanDeep, // Deep ocean blue background
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFE8EEF4),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFE8EEF4)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: oceanMid, // Slightly lighter ocean blue for cards
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: oceanMid,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: oceanLight.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: oceanLight.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: sereneTealLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: oceanMist.withValues(alpha: 0.6)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: sereneTeal,
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
          foregroundColor: sereneTealLight,
          side: const BorderSide(color: sereneTeal, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: sereneTeal,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: oceanMid,
        selectedColor: sereneTeal.withValues(alpha: 0.3),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFFE8EEF4),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: oceanDeep,
        selectedItemColor: sereneTealLight,
        unselectedItemColor: oceanMist,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: oceanLight.withValues(alpha: 0.2),
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

  /// Progress bar gradient with AI glow projection
  static LinearGradient progressGradient(double progress) => LinearGradient(
    colors: [
      emeraldGreen,
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
      color: emeraldGreen.withValues(alpha: 0.2),
      blurRadius: 16,
      spreadRadius: 1,
    ),
  ];

  // ============== FROSTED BLUR GRADIENT BACKGROUND ==============
  
  /// Frosted blur gradient decoration for light theme scaffolds
  /// Creates a frozen mint/teal gradient with glassmorphism effect
  static BoxDecoration get frostedGradientBackground => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFE8F5F0), // Soft mint-teal
        const Color(0xFFF0F7F5), // Light frosted
        const Color(0xFFE5F2EE), // Gentle sage
        const Color(0xFFF5F9F8), // Icy mint
      ],
      stops: const [0.0, 0.35, 0.7, 1.0],
    ),
  );

  /// Dark frosted gradient for dark mode
  static BoxDecoration get frostedGradientBackgroundDark => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        oceanDeep,
        oceanMid,
        const Color(0xFF162536),
        oceanDeep,
      ],
      stops: const [0.0, 0.35, 0.7, 1.0],
    ),
  );
}

/// FrostedGradientBackground - A widget that provides a frosted blur gradient background
/// Use this to wrap screens for a premium frosted glass effect
class FrostedGradientBackground extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final double blurAmount;

  const FrostedGradientBackground({
    super.key,
    required this.child,
    this.isDark = false,
    this.blurAmount = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActuallyDark = isDark || theme.brightness == Brightness.dark;

    return Container(
      decoration: isActuallyDark
          ? AppTheme.frostedGradientBackgroundDark
          : AppTheme.frostedGradientBackground,
      child: Stack(
        children: [
          // Frosted blur overlay for light theme
          if (!isActuallyDark)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.4),
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),
            ),
          // Main content
          child,
        ],
      ),
    );
  }
}

