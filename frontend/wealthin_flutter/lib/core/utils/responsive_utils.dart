import 'package:flutter/material.dart';

/// Responsive utilities for Android phone/tablet layouts.
class ResponsiveUtils {
  // Android-focused breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double wideBreakpoint = 1200;

  /// Check if device is mobile (< 600dp)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if device is tablet (>= 600dp)
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobileBreakpoint;
  }

  /// Check if device is wide tablet (>= 1200dp)
  static bool isWide(BuildContext context) {
    return MediaQuery.of(context).size.width >= wideBreakpoint;
  }

  /// Get responsive value based on phone/tablet/wide sizing.
  static T responsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? wide,
  }) {
    if (isWide(context) && wide != null) return wide;
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
      tablet: 20.0,
      wide: 24.0,
    );
  }

  /// Get responsive font size
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = screenWidth(context);
    if (width >= wideBreakpoint) {
      return baseSize * 1.15;
    } else if (width >= tabletBreakpoint) {
      return baseSize * 1.1;
    } else if (width >= mobileBreakpoint) {
      return baseSize * 1.05;
    }
    return baseSize;
  }

  /// Get number of columns for grid layouts
  static int getGridColumns(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int wide = 2,
  }) {
    return responsiveValue(
      context: context,
      mobile: mobile,
      tablet: tablet,
      wide: wide,
    );
  }

  /// Get safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get responsive card width (for centering on larger tablets)
  static double getMaxCardWidth(BuildContext context) {
    final width = screenWidth(context);
    if (width >= wideBreakpoint) return 800;
    if (width >= tabletBreakpoint) return 720;
    return width;
  }

  /// Get responsive spacing
  static double getSpacing(
    BuildContext context, {
    double mobile = 8.0,
    double? tablet,
    double? wide,
  }) {
    return responsiveValue(
      context: context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.5,
      wide: wide ?? mobile * 2,
    );
  }

  /// Check if keyboard is visible
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  /// Get responsive aspect ratio
  static double getAspectRatio(
    BuildContext context, {
    double mobile = 1.0,
    double? tablet,
    double? wide,
  }) {
    return responsiveValue(
      context: context,
      mobile: mobile,
      tablet: tablet ?? mobile,
      wide: wide ?? mobile,
    );
  }
}

/// Extension on BuildContext for easier access
extension ResponsiveExtension on BuildContext {
  bool get isMobile => ResponsiveUtils.isMobile(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  bool get isWide => ResponsiveUtils.isWide(this);
  double get screenWidth => ResponsiveUtils.screenWidth(this);
  double get screenHeight => ResponsiveUtils.screenHeight(this);
  double get responsivePadding => ResponsiveUtils.getResponsivePadding(this);
}
