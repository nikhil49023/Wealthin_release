# WealthIn v2.2.1 - Enhanced Onboarding & SMS Integration

## New Features
- **Smart SMS Integration**: Automatic transaction tracking from bank SMS messages (supports major Indian banks).
- **Google Sign-In Onboarding**: Seamless onboarding experience for Google users with auto-filled profile details.
- **Enhanced Profile Setup**: New onboarding flow to capture financial & business details for better AI insights.

## Improvements
- **Security**: Added `google-services.json` proper configuration for release builds.
- **Performance**: Optimized build size and dependencies.
- **Bug Fixes**: Resolved lint warnings and potential runtime errors in profile and health screens.

## Technical Details
- Added `flutter_sms_inbox` for SMS parsing.
- Fixed Firebase Auth `User` metadata access.
- Restored missing Google Services configuration.
