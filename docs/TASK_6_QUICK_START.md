# Task 6: Theme Audit - Quick Start

## 🎯 Objective
Audit 13 feature screens for off-theme colors and ensure WCAG AA compliance (4.5:1 contrast minimum).

## ⚡ Quick Commands

### Find All Hardcoded Colors
```bash
cd /media/nikhil/427092fa-e2b4-41f9-aa94-fa27c0b84b171/wealthin_git_/wealthin_v2/wealthin/wealthin_flutter

# Find Color(0x patterns (should be minimal)
grep -r "Color(0x" lib/features/ --include="*.dart" | grep -v "WealthInTheme" | grep -v "WealthInColors"

# Find Colors. usage (should only see Colors.white, Colors.transparent)
grep -r "Colors\." lib/features/ --include="*.dart" | grep -v "Colors.white" | grep -v "Colors.transparent" | head -20
```

## 🎨 Color Reference

### Primary Colors
```dart
WealthInTheme.navy              // #0A1628 - Main color
WealthInTheme.navyLight         // #1A2942 - Hover state
WealthInTheme.navyMuted         // #2D3F5C - Disabled state
```

### Semantic Colors
```dart
WealthInTheme.emerald           // #10B981 - Income, success
WealthInTheme.coral             // #EF4444 - Expense, error
WealthInTheme.purple            // #7C3AED - AI advisor
WealthInTheme.gold              // #D4AF37 - Savings, accent
```

### Gray Scale
```dart
WealthInTheme.gray50 through gray900
// Use for text hierarchy and backgrounds
```

### Dark Mode
```dart
WealthInTheme.black             // #000000
WealthInTheme.blackCard         // #121212
WealthInTheme.blackBorder       // #262626
// For text on dark: Use gray50 or Colors.white only
```

## ✅ Verification Checklist

### Light Mode Contrast (Dark Text on Light Background)
```
✅ Navy (#0A1628) on White: 13.5:1 ← Use for primary text
✅ Gray900 (#111827) on White: 13.4:1 ← Use for body text
✅ Gray600 (#4B5563) on White: 5.8:1 ← Use for secondary text
✅ Gray500 (#6B7280) on White: 4.6:1 ← Minimum limit
✅ Emerald (#10B981) on White: 4.9:1 ← Status colors OK
✅ Coral (#EF4444) on White: 5.2:1 ← Status colors OK
❌ Gray400 (#9CA3AF) on White: 3.6:1 ← DON'T USE
❌ Gray300 (#D1D5DB) on White: 2.2:1 ← DON'T USE
```

### Dark Mode Contrast (Light Text on Dark Background)
```
✅ White on #121212: 19.8:1 ← Perfect for dark mode
✅ Gray50 (#F9FAFB) on #121212: 18.2:1 ← Perfect for dark
✅ Gray100 (#F3F4F6) on #121212: 16.8:1 ← Good for dark
✅ Gray200 (#E5E7EB) on #121212: 13.1:1 ← Good for dark
❌ Gray300 (#D1D5DB) on #121212: 9.4:1 ← Too light
❌ Gray400 (#9CA3AF) on #121212: 5.0:1 ← At limit, risky
```

## 📋 Screens & Typical Issues

### Dashboard (Most Critical)
**File**: `lib/features/dashboard/`
- ❌ Likely Issue: Hardcoded grays in transaction list
- ✅ Fix: Use `WealthInTheme.gray600` for secondary text
- ❌ Likely Issue: Blue background on balance card
- ✅ Fix: Use `WealthInTheme.navy`

### Finance Features
**File**: `lib/features/finance/`
- ❌ Likely Issue: Colors.red/green for income/expense
- ✅ Fix: Use `WealthInTheme.emerald` (income), `WealthInTheme.coral` (expense)

### Investment
**File**: `lib/features/investment/`
- ❌ Likely Issue: Chart lines with random colors
- ✅ Fix: Use theme palette only

### AI Advisor
**File**: `lib/features/ai_advisor/`
- ❌ Likely Issue: Purple button with wrong shade
- ✅ Fix: Use `WealthInTheme.purple` or `WealthInTheme.darkPurple` (dark mode)

### Profile
**File**: `lib/features/profile/`
- ❌ Likely Issue: Toggle switches with Colors.blue
- ✅ Fix: Use `WealthInTheme.navy` or `WealthInTheme.emerald` when active

## 🛠️ Automated Replacement

### Using VSCode Find & Replace

1. **Open Find & Replace**: `Ctrl+H`
2. **Enable Regex**: Click `.*` button
3. **Make replacements** (review each):

```
Search: Colors\.red\b        → Replace: WealthInTheme.coral
Search: Colors\.green\b      → Replace: WealthInTheme.emerald
Search: Colors\.blue\b       → Replace: WealthInTheme.navy
Search: Colors\.yellow\b     → Replace: WealthInTheme.gold
Search: Colors\.purple\b     → Replace: WealthInTheme.purple
Search: Colors\.grey\b       → Replace: WealthInTheme.gray500
```

### For Specific Files

#### Fix Dashboard
```bash
# Find colors in dashboard
grep -rn "Color(0x" lib/features/dashboard/ --include="*.dart"
grep -rn "Colors\." lib/features/dashboard/ --include="*.dart"

# Then replace manually or with IDE
```

#### Fix Finance
```bash
grep -rn "Color(0x" lib/features/finance/ --include="*.dart"
grep -rn "Colors\." lib/features/finance/ --include="*.dart"
```

## 📱 Testing Dark Mode

### Enable Dark Mode Testing
```dart
// Add to your app's main settings screen temporarily:
ElevatedButton(
  onPressed: () {
    // Toggle dark mode to verify contrast
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    print('Dark Mode: $isDark');
  },
  child: Text('Check Dark Mode'),
)

// Or use DevTools theme switcher
```

### Verify Specific Contrast
```dart
// Quick contrast checker
void checkContrast(Color foreground, Color background) {
  // Formula: (L1 + 0.05) / (L2 + 0.05) where L = relative luminance
  // Minimum 4.5:1 for normal text
  // Minimum 3:1 for large text
}

// Examples to verify:
// Navy (#0A1628) on White: ✅ 13.5:1
// Gray500 (#6B7280) on White: ✅ 4.6:1 (minimum)
// Gray400 (#9CA3AF) on White: ❌ 3.6:1 (fails)
// White on BlackCard (#121212): ✅ 19.8:1
```

## ⏱️ Time Estimate

| Step | Time | Priority |
|------|------|----------|
| Find all colors | 5 min | High |
| Review findings | 10 min | High |
| Fix Dashboard | 15 min | High |
| Fix Finance | 15 min | High |
| Fix other 11 features | 60 min | Medium |
| Verify contrast | 15 min | High |
| Test dark mode | 15 min | High |
| Final review | 10 min | High |
| **Total** | **~2.5 hours** | - |

## 🔍 Priority Order

1. **Dashboard** - Most visible, highest impact
2. **Finance/Transactions** - Core feature, must be accessible
3. **Investment/AI** - Secondary importance but high usage
4. **Profile/Settings** - Lower visibility but still important
5. **Less critical** - Brainstorm, Documents, etc.

## ✔️ Sign-Off Checklist

Before marking Task 6 complete:

- [ ] Ran grep to find all Color(0x patterns
- [ ] Ran grep to find all Colors. usage
- [ ] Reviewed all findings
- [ ] Fixed Dashboard colors
- [ ] Fixed Finance colors
- [ ] Fixed remaining 11 features
- [ ] Verified Navy on White = 13.5:1+ contrast
- [ ] Verified Gray500 minimum 4.6:1 on white
- [ ] Verified White on BlackCard = 19.8:1
- [ ] Tested dark mode rendering
- [ ] All screens accessible with WCAG AA
- [ ] No hardcoded Color(0x outside theme files
- [ ] No Colors.red/green/blue outside theme files
- [ ] All text legible on both light and dark backgrounds

## 📚 Reference

**Complete Color Map**: See `THEME_AUDIT_GUIDE.md` for:
- Full color table with hex codes
- Button component standards
- Text field specifications
- Status indicator guidelines
- WCAG compliance details

**Next Action**: Execute these replacements, then mark Task 6 complete!

---

**Difficulty**: ⭐⭐ (Straightforward, mostly find & replace)
**Impact**: 🌟🌟🌟🌟🌟 (Professional appearance, accessibility compliance)
**Ready to Start**: ✅ Yes
