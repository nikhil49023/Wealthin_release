import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/indian_theme.dart';

/// Glassmorphic UI Components
/// Luxury frosted glass effects with vibrant Indian authentic styling
/// Using Peach Cream, Vanilla Latte, Mint Whisper, Golden Sand, Deep Olive, Deep Purple

/// Main Glassmorphic Container
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color? tintColor;
  final double borderRadius;
  final double borderWidth;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 15,
    this.opacity = 0.15,
    this.tintColor,
    this.borderRadius = 20,
    this.borderWidth = 1.5,
    this.borderColor,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient:
                  gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (tintColor ??
                              (isDark ? AppTheme.peachCream : AppTheme.goldenSand))
                          .withValues(alpha: opacity),
                      (tintColor ??
                              (isDark
                                  ? AppTheme.vanillaLatte
                                  : AppTheme.mintWhisper))
                          .withValues(alpha: opacity * 0.5),
                    ],
                  ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color:
                    borderColor ??
                    (isDark
                        ? AppTheme.goldenSand.withValues(alpha: 0.3)
                        : AppTheme.royalGold.withValues(alpha: 0.4)),
                width: borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? AppTheme.deepPurple : AppTheme.mintWhisper)
                      .withValues(alpha: 0.3),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Premium Glass Card with shimmer edge
class PremiumGlassCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool hasShimmerBorder;

  const PremiumGlassCard({
    super.key,
    required this.child,
    this.gradient,
    this.borderRadius = 24,
    this.padding,
    this.margin,
    this.hasShimmerBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius + 2),
        gradient: hasShimmerBorder
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.goldenSand,
                  AppTheme.peachCream,
                  AppTheme.champagneGold,
                  AppTheme.goldenSand,
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              )
            : null,
      ),
      child: Container(
        margin: EdgeInsets.all(hasShimmerBorder ? 2 : 0),
        child: GlassContainer(
          borderRadius: borderRadius,
          padding: padding,
          gradient: gradient,
          child: child,
        ),
      ),
    );
  }
}

/// Glass Button with premium effects
class GlassButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final Gradient? gradient;
  final double? width;
  final double height;

  const GlassButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.gradient,
    this.width,
    this.height = 56,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: widget.gradient ?? AppTheme.sunriseGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.goldenSand.withValues(
                      alpha: _isPressed ? 0.3 : 0.5,
                    ),
                    blurRadius: _isPressed ? 12 : 20,
                    offset: Offset(0, _isPressed ? 4 : 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.2),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: Center(
                      child: widget.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.icon != null) ...[
                                  Icon(
                                    widget.icon,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Text(
                                  widget.text,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Glass Navigation Bar
class GlassNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<GlassNavItem> items;

  const GlassNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.peachCream.withValues(alpha: 0.95),
                  AppTheme.vanillaLatte.withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppTheme.goldenSand.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.deepOlive.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(items.length, (index) {
                final isSelected = index == currentIndex;
                return _buildNavItem(
                  items[index],
                  isSelected,
                  () => onTap(index),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(GlassNavItem item, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.sunriseGradient : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              color: isSelected ? AppTheme.deepPurple : AppTheme.deepOlive,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                item.label,
                style: const TextStyle(
                  color: AppTheme.deepPurple,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class GlassNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const GlassNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Glass App Bar
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double height;

  const GlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.height = 80,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height + MediaQuery.of(context).padding.top,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.peachCream.withValues(alpha: 0.95),
                  AppTheme.vanillaLatte.withValues(alpha: 0.85),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.goldenSand.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                if (leading != null) leading! else const SizedBox(width: 16),
                if (centerTitle) const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.deepOlive,
                  ),
                ),
                if (centerTitle) const Spacer(),
                if (actions != null) ...actions!,
                if (actions == null) const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating Glass Card with animation
class FloatingGlassCard extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double floatHeight;

  const FloatingGlassCard({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 3),
    this.floatHeight = 8,
  });

  @override
  State<FloatingGlassCard> createState() => _FloatingGlassCardState();
}

class _FloatingGlassCardState extends State<FloatingGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation =
        Tween<double>(
          begin: -widget.floatHeight,
          end: widget.floatHeight,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: GlassContainer(child: widget.child),
        );
      },
    );
  }
}

/// Glass Text Field
class GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const GlassTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.mintWhisper.withValues(alpha: 0.3),
                AppTheme.peachCream.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.goldenSand.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            onChanged: onChanged,
            style: const TextStyle(
              color: AppTheme.deepOlive,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              labelText: labelText,
              hintStyle: TextStyle(
                color: AppTheme.deepOlive.withValues(alpha: 0.6),
              ),
              labelStyle: TextStyle(
                color: AppTheme.deepOlive.withValues(alpha: 0.8),
              ),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: AppTheme.goldenSand)
                  : null,
              suffixIcon: suffixIcon != null
                  ? IconButton(
                      icon: Icon(suffixIcon, color: AppTheme.deepOlive),
                      onPressed: onSuffixTap,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
