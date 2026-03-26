# Luxury Color Palette Migration Checklist

## 📋 Pre-Migration Setup

- [ ] Review `/docs/LUXURY_COLOR_GUIDE.md`
- [ ] Review `/docs/COLOR_QUICK_REFERENCE.md`
- [ ] Review `/docs/LUXURY_IMPLEMENTATION_SUMMARY.md`
- [ ] Test example widgets in `/lib/core/widgets/luxury_example_widgets.dart`
- [ ] Backup current theme files (if needed)

## 🎨 Theme Files (Already Updated)

- [x] `/lib/core/theme/app_theme.dart` - Updated with luxury colors
- [x] `/lib/core/theme/indian_theme.dart` - Updated with luxury palette
- [x] `/lib/core/widgets/glassmorphic.dart` - Updated with new colors
- [x] `/lib/core/theme/luxury_colors.dart` - Created new utility file

## 📱 Screen Migration Checklist

### Dashboard Screen (`/lib/features/dashboard/dashboard_screen.dart`)

- [ ] Update scaffold background color
  ```dart
  // Before: scaffoldBackgroundColor: AppTheme.deepOnyx
  // After: scaffoldBackgroundColor: AppTheme.deepPurple (dark) / AppTheme.mintWhisper (light)
  ```

- [ ] Update card backgrounds
  ```dart
  // Wrap cards with GlassContainer
  GlassContainer(
    gradient: LuxuryColors.mintBreeze,
    child: YourCardContent(),
  )
  ```

- [ ] Update text colors
  ```dart
  // Use context-aware colors
  style: TextStyle(color: AppTheme.textPrimary(context))
  ```

- [ ] Update accent colors (borders, dividers)
  ```dart
  // Use Golden Sand for borders
  border: Border.all(color: LuxuryColors.goldenSand.withValues(alpha: 0.4))
  ```

- [ ] Update gradients
  ```dart
  // Replace old gradients with luxury gradients
  gradient: LuxuryColors.sunriseLuxury
  ```

### Transaction Screen (`/lib/features/transactions/transactions_screen.dart`)

- [ ] Update income transaction colors
  ```dart
  // Use Forest Emerald with Mint accent
  color: LuxuryColors.forestEmerald
  ```

- [ ] Update expense transaction colors
  ```dart
  // Use Rich Burgundy with Peach accent
  color: LuxuryColors.richBurgundy
  ```

- [ ] Update transaction card backgrounds
  ```dart
  // Use Vanilla Latte with glass effect
  decoration: LuxuryColors.luxuryGlassCard()
  ```

- [ ] Update dividers
  ```dart
  // Use Golden Sand with opacity
  color: LuxuryColors.goldenSand.withValues(alpha: 0.3)
  ```

### AI Advisor / Chat Screen (`/lib/features/ai_advisor/`)

- [ ] Update user message bubbles
  ```dart
  // Use Sunrise Luxury gradient
  decoration: BoxDecoration(gradient: LuxuryColors.sunriseLuxury)
  ```

- [ ] Update AI message bubbles
  ```dart
  // Use Mint Breeze gradient
  decoration: BoxDecoration(gradient: LuxuryColors.mintBreeze)
  ```

- [ ] Update chat background
  ```dart
  // Use Deep Purple (dark) / Mint Whisper (light)
  backgroundColor: Theme.of(context).brightness == Brightness.dark
    ? LuxuryColors.deepPurple
    : LuxuryColors.mintWhisper
  ```

- [ ] Update input field
  ```dart
  // Use GlassTextField or glass effect
  GlassTextField(
    hintText: 'Type a message...',
  )
  ```

### Goals Screen (`/lib/features/goals/goals_screen.dart`)

- [ ] Update progress bars
  ```dart
  // Use Prosperity Flow gradient
  decoration: BoxDecoration(gradient: LuxuryColors.prosperityFlow)
  ```

- [ ] Update goal cards
  ```dart
  // Use Peach Cream with glass effect
  GlassContainer(
    tintColor: LuxuryColors.peachCream,
    child: GoalCard(),
  )
  ```

- [ ] Update completed goals
  ```dart
  // Use Golden Hour gradient
  gradient: LuxuryColors.goldenHour
  ```

- [ ] Update pending goals
  ```dart
  // Use Mint Breeze gradient
  gradient: LuxuryColors.mintBreeze
  ```

### Analysis Screen (`/lib/features/analysis/`)

- [ ] Update chart colors
  ```dart
  // Use luxury color palette
  colors: [
    LuxuryColors.forestEmerald,
    LuxuryColors.goldenSand,
    LuxuryColors.richBurgundy,
    LuxuryColors.mintWhisper,
  ]
  ```

- [ ] Update stat cards
  ```dart
  // Use vibrant glass cards
  decoration: LuxuryColors.vibrantGlassCard()
  ```

- [ ] Update category breakdown
  ```dart
  // Use luxury gradients for categories
  gradient: LuxuryColors.sunriseLuxury // or other gradients
  ```

### Profile Screen (`/lib/features/profile/profile_screen.dart`)

- [ ] Update profile header
  ```dart
  // Use Royal Night gradient
  decoration: BoxDecoration(gradient: LuxuryColors.royalNight)
  ```

- [ ] Update settings cards
  ```dart
  // Use luxury glass cards
  decoration: LuxuryColors.luxuryGlassCard()
  ```

- [ ] Update premium badge
  ```dart
  // Use Golden Hour gradient
  gradient: LuxuryColors.goldenHour
  ```

### Onboarding Screen (`/lib/features/onboarding/onboarding_screen.dart`)

- [ ] Update background
  ```dart
  // Use Lavender Dream gradient
  decoration: BoxDecoration(gradient: LuxuryColors.lavenderDream)
  ```

- [ ] Update step indicators
  ```dart
  // Use Golden Sand for active, Vanilla Latte for inactive
  color: isActive ? LuxuryColors.goldenSand : LuxuryColors.vanillaLatte
  ```

- [ ] Update CTA buttons
  ```dart
  // Use GlassButton with Sunrise Luxury
  GlassButton(
    text: 'Get Started',
    gradient: LuxuryColors.sunriseLuxury,
    onPressed: () {},
  )
  ```

### Budget Screen (`/lib/features/budgets/budgets_screen.dart`)

- [ ] Update budget cards
  ```dart
  // Use Peach Cream with glass effect
  GlassContainer(
    tintColor: LuxuryColors.peachCream,
    child: BudgetCard(),
  )
  ```

- [ ] Update progress indicators
  ```dart
  // Use Prosperity Flow for under budget
  // Use warning gradient for near limit
  gradient: isUnderBudget 
    ? LuxuryColors.prosperityFlow 
    : LinearGradient(colors: [LuxuryColors.goldenSand, LuxuryColors.richBurgundy])
  ```

### Investment Calculator (`/lib/features/investment/`)

- [ ] Update calculator cards
  ```dart
  // Use Mint Breeze gradient
  decoration: BoxDecoration(gradient: LuxuryColors.mintBreeze)
  ```

- [ ] Update result displays
  ```dart
  // Use vibrant glass card
  decoration: LuxuryColors.vibrantGlassCard()
  ```

- [ ] Update input fields
  ```dart
  // Use GlassTextField
  GlassTextField(
    labelText: 'Investment Amount',
  )
  ```

## 🎨 Widget Components Migration

### Cards

- [ ] Replace `Card` widgets with `GlassContainer`
- [ ] Update card colors to use luxury palette
- [ ] Add glassmorphic effects
- [ ] Update borders to use Golden Sand

### Buttons

- [ ] Replace elevated buttons with `GlassButton`
- [ ] Update button gradients to luxury gradients
- [ ] Update button text colors
- [ ] Add proper shadows with luxury colors

### Text Fields

- [ ] Replace with `GlassTextField` where appropriate
- [ ] Update input decoration colors
- [ ] Update hint text colors
- [ ] Update focus colors to Golden Sand

### App Bar

- [ ] Update app bar background
  ```dart
  // Use GlassAppBar or custom gradient
  backgroundColor: Colors.transparent,
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: LuxuryColors.sunriseLuxury,
    ),
  )
  ```

### Bottom Navigation

- [ ] Update navigation bar background
- [ ] Update selected item color to Golden Sand
- [ ] Update unselected item color to Vanilla Latte
- [ ] Consider using `GlassNavigationBar`

### Dialogs & Bottom Sheets

- [ ] Update dialog backgrounds
  ```dart
  backgroundColor: Theme.of(context).brightness == Brightness.dark
    ? LuxuryColors.deepOlive
    : LuxuryColors.peachCream
  ```

- [ ] Update dialog borders
- [ ] Update button colors in dialogs

## 🔍 Testing Checklist

### Visual Testing

- [ ] Test on light mode
- [ ] Test on dark mode
- [ ] Test on different screen sizes
- [ ] Test glassmorphic effects
- [ ] Test gradient rendering
- [ ] Test text readability

### Accessibility Testing

- [ ] Check color contrast ratios
- [ ] Test with color blindness simulators
- [ ] Verify text is readable on all backgrounds
- [ ] Test with screen readers

### Performance Testing

- [ ] Check for performance issues with blur effects
- [ ] Verify smooth animations
- [ ] Test on low-end devices

## 📝 Code Review Checklist

- [ ] All old color constants replaced
- [ ] Consistent use of luxury colors
- [ ] Proper import statements
- [ ] No hardcoded color values
- [ ] Context-aware color usage
- [ ] Proper gradient usage
- [ ] Glassmorphic effects applied correctly

## 🎯 Priority Order

### High Priority (Core Screens)
1. Dashboard Screen
2. Transaction Screen
3. AI Advisor / Chat Screen

### Medium Priority (Feature Screens)
4. Goals Screen
5. Analysis Screen
6. Profile Screen

### Low Priority (Secondary Screens)
7. Onboarding Screen
8. Budget Screen
9. Investment Calculator
10. Settings & Other screens

## 📚 Resources

- **Color Guide**: `/docs/LUXURY_COLOR_GUIDE.md`
- **Quick Reference**: `/docs/COLOR_QUICK_REFERENCE.md`
- **Implementation Summary**: `/docs/LUXURY_IMPLEMENTATION_SUMMARY.md`
- **Example Widgets**: `/lib/core/widgets/luxury_example_widgets.dart`

## 🚀 Migration Steps

1. **Start with one screen** (recommend Dashboard)
2. **Update colors** using luxury palette
3. **Add glassmorphic effects** where appropriate
4. **Test thoroughly** in both light and dark modes
5. **Review and refine** based on visual feedback
6. **Move to next screen** and repeat

## ✅ Completion Criteria

- [ ] All screens updated with luxury colors
- [ ] Glassmorphic effects applied consistently
- [ ] Text readability verified
- [ ] Accessibility standards met
- [ ] Performance is acceptable
- [ ] Visual consistency across app
- [ ] Documentation updated
- [ ] Team review completed

## 🎉 Post-Migration

- [ ] Create before/after screenshots
- [ ] Update app store screenshots
- [ ] Update marketing materials
- [ ] Gather user feedback
- [ ] Monitor analytics for user engagement
- [ ] Plan iterative improvements

---

**Remember**: Take it one screen at a time. Quality over speed! 🎨✨
