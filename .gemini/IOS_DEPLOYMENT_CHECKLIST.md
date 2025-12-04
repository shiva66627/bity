# iOS Deployment Quick Checklist

## 🚨 IMPORTANT: You're on Windows!

**You CANNOT build iOS apps on Windows.** You need macOS to proceed.

---

## Quick Decision Tree

### Do you have access to a Mac?

#### ✅ YES → Follow "Manual Deployment" below
#### ❌ NO → Use "Cloud Build Service" (Recommended: Codemagic)

---

## Option 1: Cloud Build (No Mac Needed) ⭐ RECOMMENDED FOR YOU

### Using Codemagic (Free Tier Available)

1. **Sign up**: https://codemagic.io
2. **Connect GitHub/GitLab** repository
3. **Add Apple Developer credentials**:
   - Apple ID
   - App-specific password
   - Team ID
4. **Configure build**:
   - Select iOS platform
   - Set Bundle ID: `com.mbbsfreaks.app`
   - Enable automatic code signing
5. **Trigger build**:
   - Push to repository
   - Codemagic builds automatically
   - Deploys to TestFlight/App Store

**Cost**: Free for 500 build minutes/month

---

## Option 2: Manual Deployment (Requires Mac)

### Prerequisites Checklist

- [ ] macOS 12.0+ (Monterey or later)
- [ ] Xcode 15.x (from Mac App Store)
- [ ] CocoaPods installed (`sudo gem install cocoapods`)
- [ ] Flutter SDK installed on Mac
- [ ] Apple Developer Account ($99/year for App Store)

### Step-by-Step Checklist

#### 1. Initial Setup (One-time)

- [ ] Clone repository to Mac
- [ ] Run `flutter pub get`
- [ ] Run `cd ios && pod install`
- [ ] Open `ios/Runner.xcworkspace` in Xcode

#### 2. Configure Xcode

- [ ] Select Team in Signing & Capabilities
- [ ] Verify Bundle ID: `com.mbbsfreaks.app`
- [ ] Enable Push Notifications capability
- [ ] Enable Background Modes (if needed)

#### 3. Test Build

- [ ] Run on iOS Simulator: `flutter run`
- [ ] Test on physical device (connect via USB)
- [ ] Verify all features work:
  - [ ] Google Sign-In
  - [ ] Firebase authentication
  - [ ] Push notifications
  - [ ] PDF viewing
  - [ ] Image picker
  - [ ] Razorpay payments
  - [ ] Offline mode

#### 4. Build Release

- [ ] Update version in `pubspec.yaml` (e.g., `1.0.9+9`)
- [ ] Run: `flutter build ipa --release`
- [ ] Or in Xcode: Product → Archive

#### 5. App Store Connect Setup

- [ ] Create app at https://appstoreconnect.apple.com
- [ ] Fill in app information:
  - [ ] App name: MBBSFreaks
  - [ ] Bundle ID: com.mbbsfreaks.app
  - [ ] SKU: unique identifier
  - [ ] Primary language
  - [ ] Category: Education
- [ ] Prepare assets:
  - [ ] Screenshots (iPhone 6.7", 6.5", 5.5")
  - [ ] Screenshots (iPad Pro 12.9", 12.9" 2nd gen)
  - [ ] App icon (1024x1024 px)
  - [ ] Privacy policy URL
  - [ ] Support URL

#### 6. Upload to App Store

- [ ] In Xcode Organizer: Distribute App → App Store Connect
- [ ] Or use Transporter app
- [ ] Wait for processing (10-30 minutes)

#### 7. Submit for Review

- [ ] Complete all App Store Connect fields
- [ ] Add test account credentials (if needed)
- [ ] Submit for review
- [ ] Wait for approval (24-48 hours typically)

---

## Files Already Configured ✅

Your project already has these iOS files ready:

- ✅ `ios/Runner/GoogleService-Info.plist` - Firebase config
- ✅ `ios/Runner/Info.plist` - App permissions (just updated!)
- ✅ `pubspec.yaml` - iOS dependencies configured
- ✅ `assets/icons.png` - App icon ready

---

## Common Issues & Quick Fixes

### Issue: "pod install" fails
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
```

### Issue: Signing error in Xcode
- Go to Signing & Capabilities
- Select your Team
- Enable "Automatically manage signing"

### Issue: Google Sign-In not working
- Verify URL scheme in Info.plist (already added ✅)
- Check Bundle ID matches Firebase Console

### Issue: Build fails with "No such module"
```bash
flutter clean
flutter pub get
cd ios && pod install
```

---

## What You Should Do RIGHT NOW

Since you're on **Windows**, here's your action plan:

### Immediate Next Steps:

1. **Push your code to GitHub/GitLab** (if not already done)
   ```bash
   git add .
   git commit -m "iOS deployment ready"
   git push
   ```

2. **Choose your deployment method**:

   **Option A: Codemagic (Easiest)**
   - Sign up at https://codemagic.io
   - Connect your repository
   - Follow their iOS setup wizard
   - Let them build and deploy

   **Option B: Get Mac Access**
   - Borrow a Mac from friend/colleague
   - Or use cloud Mac service (MacStadium, MacinCloud)
   - Follow manual deployment checklist above

   **Option C: Hire iOS Developer**
   - Post job on Upwork/Fiverr
   - Budget: $50-200 for deployment help
   - They handle the Mac-specific parts

---

## Estimated Timeline

### Using Codemagic:
- Setup: 1-2 hours
- First build: 30 minutes
- App Store review: 1-3 days
- **Total: ~3-4 days**

### Using Mac (Manual):
- Setup: 2-4 hours (first time)
- Build & upload: 1 hour
- App Store review: 1-3 days
- **Total: ~1 week**

---

## Resources

- **iOS Deployment Guide**: `.gemini/IOS_DEPLOYMENT_GUIDE.md` (detailed guide)
- **Flutter Docs**: https://docs.flutter.dev/deployment/ios
- **Codemagic**: https://codemagic.io
- **App Store Connect**: https://appstoreconnect.apple.com
- **Apple Developer**: https://developer.apple.com

---

## Need Help?

If you get stuck:

1. Check the detailed guide: `.gemini/IOS_DEPLOYMENT_GUIDE.md`
2. Flutter Discord: https://discord.gg/flutter
3. Stack Overflow: Tag with `flutter` and `ios`
4. Codemagic Support: support@codemagic.io

---

## Summary

✅ **Your iOS project is configured and ready**
⚠️ **You need macOS or Codemagic to build**
🚀 **Recommended: Use Codemagic from Windows**

Good luck! 🎉
