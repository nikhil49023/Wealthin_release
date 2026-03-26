# Luxury Color Palette & Glassmorphic Design Guide

## 🎨 Color Palette Overview

Your WealthIn app now features a vibrant, Indian-authentic luxury color palette with glassmorphic effects throughout.

### Primary Luxury Colors

| Color Name | Hex Code | Usage |
|------------|----------|-------|
| **Peach Cream** | `#FCDFC5` | Warm backgrounds, primary text on dark, card surfaces |
| **Vanilla Latte** | `#F3E5C3` | Soft surfaces, secondary text on dark, elevated cards |
| **Mint Whisper** | `#D7EAE2` | Fresh accents, calm backgrounds, info states |
| **Golden Sand** | `#F0E193` | Prosperity highlights, borders, warning states |
| **Deep Olive** | `#1A2417` | Dark backgrounds, primary text on light, grounded elements |
| **Deep Purple** | `#25092E` | Royal dark base, premium accents, mystery elements |

### Extended Palette

- **Rich Burgundy** (`#5C1A33`) - Premium depth, error states
- **Forest Emerald** (`#0D4D3E`) - Growth, success states
- **Champagne Gold** (`#E0C070`) - Celebration, premium highlights
- **Rose Gold** (`#E8B4A0`) - Feminine luxury touches
- **Sage Green** (`#9CAF88`) - Natural wealth indicators
- **Lavender Mist** (`#E6D5E8`) - Soft premium accents
- **Terracotta** (`#D4622A`) - Earthy Indian heritage
- **Ivory Silk** (`#FFFDF7`) - Pure luxury surfaces

## 🌟 Glassmorphic Effects

### Implementation

The app uses glassmorphic effects with the luxury colors for a modern, premium feel:

```dart
import 'package:wealthin_flutter/core/theme/luxury_colors.dart';
import 'package:wealthin_flutter/core/widgets/glassmorphic.dart';

// Basic glass container
GlassContainer(
  child: YourWidget(),
  tintColor: LuxuryColors.peachCream,
  opacity: 0.15,
  blur: 15,
)

// Premium glass card with shimmer
PremiumGlassCard(
  child: YourWidget(),
  gradient: LuxuryColors.sunriseLuxury,
)

// Vibrant glass card
Container(
  decoration: LuxuryColors.vibrantGlassCard(
    borderRadius: 20,
    customGradient: LuxuryColors.mintBreeze,
  ),
  child: YourWidget(),
)
```

## 🎭 Gradient Combinations

### Pre-defined Luxury Gradients

1. **Sunrise Luxury** - Peach Cream → Golden Sand → Champagne Gold
   - Use for: Premium CTAs, hero sections, success states

2. **Mint Breeze** - Mint Whisper → Vanilla Latte → Peach Cream
   - Use for: Calm sections, financial overview, balance cards

3. **Royal Night** - Deep Purple → Deep Olive → Rich Burgundy
   - Use for: Dark mode backgrounds, premium features, AI sections

4. **Prosperity Flow** - Forest Emerald → Mint Whisper → Sage Green
   - Use for: Growth indicators, investment cards, savings goals

5. **Golden Hour** - Golden Sand → Champagne Gold → Rose Gold
   - Use for: Premium features, gold tier benefits, achievements

6. **Lavender Dream** - Lavender Mist → Peach Cream → Vanilla Latte
   - Use for: Soft sections, onboarding, welcome screens

## 📱 Screen-by-Screen Color Usage

### Dashboard
- **Background**: Mint Whisper (light) / Deep Purple (dark)
- **Cards**: Peach Cream with glass effect
- **Accents**: Golden Sand borders
- **Text**: Deep Olive (light) / Peach Cream (dark)

### Financial Overview Cards
- **Background**: Vanilla Latte with glass blur
- **Gradient**: Mint Breeze
- **Border**: Golden Sand (40% opacity)
- **Shadow**: Golden Sand glow

### AI Advisor / Chat
- **User Bubbles**: Sunrise Luxury gradient
- **AI Bubbles**: Mint Breeze gradient
- **Background**: Deep Purple (dark) / Mint Whisper (light)
- **Input Field**: Glass effect with Peach Cream tint

### Transaction Lists
- **Income**: Forest Emerald with Mint Whisper accent
- **Expense**: Rich Burgundy with Peach Cream accent
- **Background**: Vanilla Latte cards
- **Dividers**: Golden Sand (30% opacity)

### Premium Features
- **Background**: Royal Night gradient
- **Cards**: Vibrant glass with Golden Hour gradient
- **Borders**: Champagne Gold shimmer
- **Icons**: Golden Sand

### Goals & Savings
- **Progress Bars**: Prosperity Flow gradient
- **Cards**: Peach Cream with glass effect
- **Completed**: Golden Hour gradient
- **In Progress**: Mint Breeze gradient

## 🎨 Theme Integration

### Using AppTheme

```dart
import 'package:wealthin_flutter/core/theme/app_theme.dart';

// Access luxury colors
AppTheme.peachCream
AppTheme.vanillaLatte
AppTheme.mintWhisper
AppTheme.goldenSand
AppTheme.deepOlive
AppTheme.deepPurple

// Use gradients
Container(
  decoration: BoxDecoration(
    gradient: AppTheme.sunriseGradient,
  ),
)

// Context-aware colors
AppTheme.primaryColor(context)
AppTheme.surfaceColor(context)
AppTheme.textPrimary(context)
```

### Using LuxuryColors

```dart
import 'package:wealthin_flutter/core/theme/luxury_colors.dart';

// Direct color access
LuxuryColors.peachCream
LuxuryColors.goldenSand

// Glass overlays
LuxuryColors.glassLight(opacity: 0.15)
LuxuryColors.glassMint(opacity: 0.2)

// Decorations
Container(
  decoration: LuxuryColors.luxuryGlassCard(isDark: true),
)
```

## 🌈 Color Combinations Guide

### High Contrast (Accessibility)
- Deep Olive text on Peach Cream background
- Peach Cream text on Deep Purple background
- Golden Sand accents on Deep Olive

### Soft & Elegant
- Vanilla Latte background with Mint Whisper accents
- Peach Cream cards with Golden Sand borders
- Lavender Mist with Rose Gold highlights

### Vibrant & Energetic
- Golden Sand with Champagne Gold
- Terracotta with Peach Cream
- Forest Emerald with Mint Whisper

### Premium & Luxurious
- Deep Purple with Golden Sand
- Rich Burgundy with Champagne Gold
- Deep Olive with Rose Gold

## 🎯 Best Practices

1. **Glassmorphic Effects**
   - Use blur values between 10-20 for optimal effect
   - Keep opacity between 0.1-0.3 for backgrounds
   - Add subtle borders with Golden Sand (30-40% opacity)

2. **Gradients**
   - Use 2-3 colors maximum per gradient
   - Maintain color harmony (warm with warm, cool with cool)
   - Apply gradients to large surfaces for impact

3. **Text Readability**
   - Always use `LuxuryColors.getTextColor()` for dynamic backgrounds
   - Maintain minimum 4.5:1 contrast ratio
   - Use Deep Olive on light backgrounds
   - Use Peach Cream on dark backgrounds

4. **Shadows & Depth**
   - Use Golden Sand shadows for warm elements
   - Use Deep Purple shadows for cool elements
   - Spread radius: 2-3px for subtle depth
   - Blur radius: 20-28px for glass effect

5. **Indian Authenticity**
   - Combine Terracotta with Golden Sand for traditional feel
   - Use Mint Whisper for fresh, modern Indian aesthetic
   - Apply Peach Cream and Vanilla Latte for warm, welcoming vibe
   - Deep Olive and Forest Emerald for grounded, trustworthy feel

## 🔧 Quick Reference

### Import Statements
```dart
import 'package:wealthin_flutter/core/theme/app_theme.dart';
import 'package:wealthin_flutter/core/theme/luxury_colors.dart';
import 'package:wealthin_flutter/core/theme/indian_theme.dart';
import 'package:wealthin_flutter/core/widgets/glassmorphic.dart';
```

### Common Patterns

**Glass Card with Gradient:**
```dart
GlassContainer(
  gradient: LuxuryColors.sunriseLuxury,
  borderRadius: 20,
  child: Padding(
    padding: EdgeInsets.all(20),
    child: YourContent(),
  ),
)
```

**Premium Button:**
```dart
GlassButton(
  text: 'Premium Action',
  gradient: LuxuryColors.goldenHour,
  icon: Icons.star,
  onPressed: () {},
)
```

**Vibrant Card:**
```dart
Container(
  decoration: LuxuryColors.vibrantGlassCard(
    customGradient: LuxuryColors.prosperityFlow,
  ),
  child: YourWidget(),
)
```

## 🎨 Color Psychology

- **Peach Cream**: Warmth, comfort, approachability
- **Vanilla Latte**: Elegance, sophistication, calm
- **Mint Whisper**: Freshness, growth, tranquility
- **Golden Sand**: Prosperity, success, optimism
- **Deep Olive**: Stability, wealth, trust
- **Deep Purple**: Luxury, royalty, wisdom

## 📊 Usage Statistics

Recommended color distribution across the app:
- **Backgrounds**: 40% Mint Whisper/Peach Cream, 30% Deep Purple/Olive, 30% Vanilla Latte
- **Accents**: 50% Golden Sand, 30% Champagne Gold, 20% Forest Emerald
- **Text**: 70% Deep Olive/Peach Cream, 30% Vanilla Latte/Golden Sand
- **Borders**: 80% Golden Sand, 20% Champagne Gold

---

**Note**: All colors are designed to work harmoniously together. Feel free to experiment with combinations while maintaining the luxury, vibrant, and Indian-authentic aesthetic!
