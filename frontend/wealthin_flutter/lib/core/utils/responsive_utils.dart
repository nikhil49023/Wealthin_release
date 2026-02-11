import 'package:flutter/material.dart';

/// Responsive utilities for adaptive layouts across phone and tablet sizes
class ResponsiveUtils {
  // Breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Check if device is mobile (< 600dp)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if device is tablet (600dp - 900dp)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Check if device is desktop (> 900dp)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// Get responsive value based on screen size
  static T responsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }

  /// Get screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Get responsive padding
  static double getResponsivePadding(BuildContext context) {
    return responsiveValue(
      context: context,
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );
  }

  /// Get responsive font size
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = screenWidth(context);
    if (width >= tabletBreakpoint) {
      return baseSize * 1.2;
    } else if (width >= mobileBreakpoint) {
      return baseSize * 1.1;
    }
    return baseSize;
  }

  /// Get number of columns for grid layouts
  static int getGridColumns(BuildContext context, {int mobile = 1, int tablet = 2, int desktop = 3}) {
    return responsiveValue(
      context: context,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }

  /// Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get responsive card width (for centering on large screens)
  static double getMaxCardWidth(BuildContext context) {
    final width = screenWidth(context);
    if (width >= desktopBreakpoint) return 800;
    if (width >= tabletBreakpoint) return 700;
    return width;
  }

  /// Get responsive spacing
  static double getSpacing(BuildContext context, {double mobile = 8.0, double? tablet, double? desktop}) {
    return responsiveValue(
      context: context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.5,
      desktop: desktop ?? mobile * 2,
    );
  }

  /// Check if keyboard is visible
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  /// Get responsive aspect ratio
  static double getAspectRatio(BuildContext context, {double mobile = 1.0, double? tablet, double? desktop}) {
    return responsiveValue(
      context: context,
      mobile: mobile,
      tablet: tablet ?? mobile,
      desktop: desktop ?? mobile,
    );
  }
}

/// Extension on BuildContext for easier access
extension ResponsiveExtension on BuildContext {
  bool get isMobile => ResponsiveUtils.isMobile(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  bool get isDesktop => ResponsiveUtils.isDesktop(this);
  double get screenWidth => ResponsiveUtils.screenWidth(this);
  double get screenHeight => ResponsiveUtils.screenHeight(this);
  double get responsivePadding => ResponsiveUtils.getResponsivePadding(this);
}
