# Wealthin - App Permissions Explained

**Principle**: Wealthin requests ONLY essential permissions needed for core features.

## Required Permissions

### 1. **INTERNET** ✓ Essential
- **Why**: Connect to Sarvam AI API for financial advice and document analysis
- **What we send**: Transaction descriptions, document content for analysis
- **Privacy**: All communication is encrypted (HTTPS)
- **Can be disabled**: No - requires AI features to work

### 2. **READ_EXTERNAL_STORAGE** ✓ Essential
- **Why**: Allow users to upload bank statements, receipts, PDFs via file picker
- **What we access**: Only files you explicitly select (no automatic scanning)
- **Examples**: 
  - 📄 PDF bank statements
  - 📸 Receipt photos
  - 📊 Financial statements
- **Privacy**: We never access your entire file system - only files you choose
- **Can be disabled**: Yes - disables document upload features

### 3. **READ_MEDIA_IMAGES** ✓ Essential (Android 13+)
- **Why**: Same as above - modern Android requires explicit media permission
- **What we access**: Only images you select for upload
- **Privacy**: No automatic access to your gallery
- **Can be disabled**: Yes - disables photo upload features

### 4. **BIND_NOTIFICATION_LISTENER_SERVICE** ✓ Essential (Optional Feature)
- **Why**: Detect bank transaction notifications automatically
- **What we access**: Only notification title + content from apps you designate
- **Examples**: "₹5,000 transferred to XYZ Bank"
- **Privacy**: 
  - Only processes notifications from banking apps (configurable)
  - Never forwards notifications anywhere
  - Local processing only
- **Can be disabled**: Yes - in Settings > Transaction Detection

## Permissions We DO NOT Request

### ❌ Camera
- **Why we don't need it**: File picker provides access without this
- **Users can**: Manually take photos and upload

### ❌ Contacts
- **Why we don't need it**: We don't match merchants to your contacts
- **Alternative**: Manual merchant tagging

### ❌ SMS/Phone State
- **Why we don't need it**: Bank notifications come via notification system
- **Privacy advantage**: Prevents us from accessing all SMS

### ❌ Location
- **Why we don't need it**: Financial advice is not location-based
- **Privacy advantage**: Your location stays private

### ❌ Microphone
- **Why we don't need it**: We don't have voice features (yet)

## Runtime Permissions Flow

```
User opens Wealthin
    ↓
Permission Check
    ├── INTERNET → Always available (no runtime prompt)
    ├── READ_EXTERNAL_STORAGE → Prompt on first file upload
    ├── READ_MEDIA_IMAGES → Prompt on first image upload
    └── Notification Listener → Prompt in onboarding (optional)
```

## Revoking Permissions

Users can revoke any permission anytime:

1. **Android Settings** → Apps → Wealthin → Permissions
2. **In-App** → Settings → Privacy → Toggle individual permissions

**Effect of revoking**:
- Revoking **INTERNET** → App won't work (will show error)
- Revoking **File Access** → Upload disabled
- Revoking **Notification Access** → Auto-transaction detection disabled

## Data Minimalism

| Permission | Why It's Minimal | Comparison |
|---|---|---|
| Only 3 runtime permissions | 80% fewer than typical finance apps | Most: 15+ permissions |
| No SMS access | Can't log your messages | Competitors log everything |
| No Contact access | Merchant names are manual | Competitors scan contacts automatically |
| No Location | Privacy by default | Competitors track your shopping patterns |

## Transparency

Your permission usage is visible in:
- **Android Settings** → App Permissions
- **Wealthin Settings** → Privacy Dashboard
- **Wealthin Logs** → View permission access history (Settings → Logs)

---

**Questions?** Check Settings → Help → Permission FAQ
