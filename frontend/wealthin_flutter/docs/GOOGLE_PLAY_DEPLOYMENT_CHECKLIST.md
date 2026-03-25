# Google Play Deployment Checklist

## 1. Identity & Signing
- Set unique `applicationId` and `namespace` in android/app/build.gradle.kts.
- Create release keystore and configure `android/key.properties` from `android/key.properties.example`.
- Verify release build signs with release key (not debug).

## 2. AI Configuration (Sarvam)
- Provide `SARVAM_API_KEY` via secure storage or `--dart-define`.
- Optionally set:
  - `SARVAM_CHAT_MODEL`
  - `SARVAM_VISION_MODEL`
- Test chat, idea evaluation, and receipt/document extraction on a real device.

## 3. Authentication Readiness
- Ensure Firebase project is production-configured.
- Add valid `google-services.json` for release app id.
- Verify email verification flow:
  - Register -> verification email
  - Unverified login -> verification gate screen
  - Refresh after verify -> app unlock

## 4. Policy & Privacy
- Keep permissions minimal in AndroidManifest.xml.
- Upload the following policy docs to Play Console listing/website:
  - PRIVACY_POLICY.md
  - APP_PERMISSIONS.md
  - APP_POLICY.md
- Ensure Data Safety form reflects encrypted local storage + optional cloud sync.

## 5. Build Quality Gates
- Run: `flutter analyze`
- Run: `flutter test`
- Build release: `flutter build appbundle --release`
- Validate startup, login, dashboard, AI chat, OCR, and onboarding paths.

## 6. Play Console Submission
- Prepare screenshots for phone sizes.
- Add short/full description, category, contact email, and privacy policy URL.
- Upload `.aab` from build/app/outputs/bundle/release/.
- Complete Content Rating, App Access, Ads declaration, and Data Safety.

## 7. Post-Release Monitoring
- Enable Play pre-launch report.
- Monitor crash-free sessions and ANRs.
- Roll out staged percentage first, then full production.
