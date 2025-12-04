# iOS Deployment Guide for MBBSFreaks App

## ⚠️ Important: Windows Limitation

**You are currently on Windows, and iOS app development requires macOS.** You cannot build, test, or deploy iOS apps directly from Windows. Here are your options:

### Options to Deploy to iOS:

1. **Use a Mac Computer** (Recommended)
   - Borrow or access a Mac (MacBook, iMac, Mac Mini, etc.)
   - Install Xcode and Flutter on the Mac
   - Clone your project repository
   - Follow the deployment steps below

2. **Use Cloud-Based Mac Services**
   - **Codemagic** (https://codemagic.io) - CI/CD for Flutter with free tier
   - **MacStadium** - Rent a Mac in the cloud
   - **MacinCloud** - Remote Mac access
   - **GitHub Actions** with macOS runners

3. **Use Flutter Web or Android First**
   - Deploy your app as a web app or Android app first
   - Later use a Mac for iOS deployment

---

## Prerequisites (When You Have Mac Access)

### 1. Install Required Software on Mac

- **macOS**: Version 12.0 (Monterey) or later
- **Xcode**: Latest version from Mac App Store (currently 15.x)
- **CocoaPods**: Install via Terminal:
  ```bash
  sudo gem install cocoapods
  ```
- **Flutter**: Install Flutter SDK on Mac
  ```bash
  # Download Flutter SDK
  git clone https://github.com/flutter/flutter.git -b stable
  
  # Add to PATH in ~/.zshrc or ~/.bash_profile
  export PATH="$PATH:`pwd`/flutter/bin"
  ```

### 2. Apple Developer Account

- **Free Account**: Can test on physical devices (7-day limit)
- **Paid Account ($99/year)**: Required for App Store deployment
  - Sign up at: https://developer.apple.com

---

## Step-by-Step iOS Deployment Process

### Step 1: Setup Xcode Project (On Mac)

1. **Open Terminal and navigate to your project**:
   ```bash
   cd /path/to/your/app
   ```

2. **Install iOS dependencies**:
   ```bash
   flutter pub get
   cd ios
   pod install
   cd ..
   ```

3. **Open Xcode**:
   ```bash
   open ios/Runner.xcworkspace
   ```
   ⚠️ **Important**: Always open `.xcworkspace`, NOT `.xcodeproj`

### Step 2: Configure Bundle Identifier and Signing

1. **In Xcode**:
   - Select `Runner` in the left sidebar
   - Go to `Signing & Capabilities` tab
   - Set your **Team** (Apple Developer account)
   - Update **Bundle Identifier**: `com.mbbsfreaks.app` (already set in your GoogleService-Info.plist)

2. **Configure App Display Name**:
   - In `Info.plist`, update `CFBundleDisplayName` to "MBBSFreaks" or your preferred name

### Step 3: Update Info.plist for Required Permissions

Your app uses several features that require permission descriptions. Add these to `ios/Runner/Info.plist`:

```xml
<!-- Camera Permission (for image_picker) -->
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to upload profile pictures and documents.</string>

<!-- Photo Library Permission (for image_picker) -->
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to select images for upload.</string>

<!-- Notifications Permission (for firebase_messaging) -->
<key>NSUserNotificationAlertStyle</key>
<string>alert</string>

<!-- File Access Permission (for file_picker) -->
<key>NSDocumentsFolderUsageDescription</key>
<string>This app needs access to documents to upload PDFs and files.</string>

<!-- URL Schemes for Google Sign-In -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.566827566356-51mihvhugvsgqj5bv3bsuhahdsafak1v</string>
    </array>
  </dict>
</array>
```

### Step 4: Configure Firebase for iOS

✅ **Already Done**: Your `GoogleService-Info.plist` is already in place at `ios/Runner/GoogleService-Info.plist`

Verify it contains:
- Bundle ID: `com.mbbsfreaks.app`
- All Firebase configuration keys

### Step 5: Configure App Icons

1. **Generate iOS icons** using your existing icon:
   ```bash
   flutter pub run flutter_launcher_icons
   ```

2. **Verify in Xcode**:
   - Go to `Runner` → `Assets.xcassets` → `AppIcon`
   - Ensure all icon sizes are present

### Step 6: Build and Test on Simulator

1. **List available simulators**:
   ```bash
   flutter emulators
   ```

2. **Launch a simulator**:
   ```bash
   flutter emulators --launch <simulator_id>
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

### Step 7: Test on Physical Device

1. **Connect iPhone/iPad via USB**
2. **Trust the computer** on your device
3. **In Xcode**:
   - Select your device from the device dropdown
   - Click ▶️ Run button

4. **On your device**:
   - Go to Settings → General → VPN & Device Management
   - Trust your developer certificate

### Step 8: Prepare for App Store Submission

1. **Update version in pubspec.yaml**:
   ```yaml
   version: 1.0.8+8
   ```
   - `1.0.8` = Version name (shown to users)
   - `8` = Build number (must increment with each upload)

2. **Create App Store listing**:
   - Go to https://appstoreconnect.apple.com
   - Click "My Apps" → "+" → "New App"
   - Fill in app information:
     - Name: MBBSFreaks
     - Bundle ID: com.mbbsfreaks.app
     - SKU: unique identifier (e.g., mbbsfreaks-001)

3. **Prepare app assets**:
   - App screenshots (required sizes for iPhone and iPad)
   - App preview videos (optional)
   - App icon (1024x1024 px)
   - Privacy policy URL
   - Support URL

### Step 9: Build Release Version

1. **Build IPA file**:
   ```bash
   flutter build ipa --release
   ```

2. **Archive in Xcode** (Alternative method):
   - In Xcode: Product → Archive
   - Wait for archive to complete
   - Click "Distribute App"
   - Select "App Store Connect"
   - Follow the wizard

### Step 10: Upload to App Store

1. **Using Xcode Organizer**:
   - Window → Organizer
   - Select your archive
   - Click "Distribute App"
   - Choose "App Store Connect"
   - Upload

2. **Using Transporter App** (Alternative):
   - Download Transporter from Mac App Store
   - Drag and drop your `.ipa` file
   - Click "Deliver"

### Step 11: Submit for Review

1. **In App Store Connect**:
   - Select your app
   - Go to "App Store" tab
   - Fill in all required information:
     - Description
     - Keywords
     - Screenshots
     - Privacy policy
     - Age rating
   - Click "Submit for Review"

2. **Review process**:
   - Typically takes 24-48 hours
   - You'll receive email updates
   - May be rejected if issues found (follow feedback and resubmit)

---

## Common iOS-Specific Issues and Fixes

### Issue 1: CocoaPods Installation Fails

**Solution**:
```bash
cd ios
rm -rf Pods Podfile.lock
pod install --repo-update
```

### Issue 2: Google Sign-In Not Working

**Solution**:
- Verify `REVERSED_CLIENT_ID` is in `Info.plist` URL schemes
- Check Bundle ID matches in Firebase Console
- Ensure iOS app is registered in Firebase

### Issue 3: Push Notifications Not Working

**Solution**:
- Enable Push Notifications capability in Xcode
- Upload APNs certificate to Firebase Console
- Request notification permissions in code

### Issue 4: Build Fails with "Signing for Runner requires a development team"

**Solution**:
- In Xcode, select your Team in Signing & Capabilities
- Or use automatic signing with your Apple ID

### Issue 5: Razorpay Not Working on iOS

**Solution**:
- Razorpay requires additional iOS configuration
- Add URL schemes for payment callbacks
- Check Razorpay iOS documentation

---

## iOS-Specific Code Considerations

### 1. Platform-Specific Code

Some features may need iOS-specific handling:

```dart
import 'dart:io' show Platform;

if (Platform.isIOS) {
  // iOS-specific code
} else if (Platform.isAndroid) {
  // Android-specific code
}
```

### 2. Safe Area Handling

iOS has notches and safe areas:

```dart
SafeArea(
  child: YourWidget(),
)
```

### 3. iOS-Style Widgets

Consider using Cupertino widgets for iOS:

```dart
import 'package:flutter/cupertino.dart';

CupertinoButton(
  child: Text('iOS Button'),
  onPressed: () {},
)
```

---

## Testing Checklist for iOS

Before submitting to App Store:

- [ ] App launches without crashes
- [ ] Google Sign-In works
- [ ] Firebase authentication works
- [ ] Push notifications work
- [ ] PDF viewing works
- [ ] Image picker works
- [ ] Payment integration works (Razorpay)
- [ ] Offline mode works
- [ ] All screens render correctly
- [ ] No console errors or warnings
- [ ] App icon displays correctly
- [ ] Splash screen works
- [ ] Deep links work (if applicable)
- [ ] App works on different iOS versions (iOS 13+)
- [ ] App works on different devices (iPhone, iPad)
- [ ] Dark mode support (if implemented)
- [ ] Landscape/portrait orientations work

---

## Continuous Integration (CI/CD) for iOS

### Using Codemagic (Recommended for Windows Users)

1. **Sign up at https://codemagic.io**
2. **Connect your repository** (GitHub, GitLab, Bitbucket)
3. **Configure workflow**:
   - Select Flutter project
   - Choose iOS platform
   - Add Apple Developer credentials
   - Configure build settings

4. **Automatic builds**:
   - Every push to main branch triggers build
   - Automatic testing
   - Automatic deployment to TestFlight/App Store

**Codemagic Configuration** (codemagic.yaml):

```yaml
workflows:
  ios-workflow:
    name: iOS Workflow
    max_build_duration: 60
    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
    scripts:
      - name: Install dependencies
        script: flutter pub get
      - name: Build iOS
        script: flutter build ipa --release
    artifacts:
      - build/ios/ipa/*.ipa
    publishing:
      app_store_connect:
        api_key: $APP_STORE_CONNECT_KEY
        submit_to_testflight: true
```

---

## Next Steps from Windows

Since you're on Windows, here's what you should do **right now**:

### Option A: Use Codemagic (Easiest)

1. Push your code to GitHub/GitLab
2. Sign up for Codemagic
3. Connect your repository
4. Configure iOS build
5. Let Codemagic build and deploy

### Option B: Find Mac Access

1. Borrow a Mac from a friend/colleague
2. Install Xcode and Flutter
3. Clone your repository
4. Follow the deployment steps above

### Option C: Hire a Developer

1. Find an iOS developer on Upwork/Fiverr
2. Give them access to your repository
3. They can handle the iOS deployment

---

## Required Files Already in Your Project

✅ **Already configured**:
- `ios/Runner/GoogleService-Info.plist` - Firebase configuration
- `ios/Runner/Info.plist` - App configuration
- `pubspec.yaml` - Dependencies configured for iOS
- `assets/icons.png` - App icon ready

⚠️ **Needs to be created on Mac**:
- Podfile (will be generated when you run `pod install`)
- Xcode project signing configuration
- Provisioning profiles

---

## Resources

- **Flutter iOS Deployment**: https://docs.flutter.dev/deployment/ios
- **Apple Developer**: https://developer.apple.com
- **App Store Connect**: https://appstoreconnect.apple.com
- **Codemagic Docs**: https://docs.codemagic.io/flutter-configuration/flutter-projects/
- **Firebase iOS Setup**: https://firebase.google.com/docs/ios/setup
- **Razorpay iOS**: https://razorpay.com/docs/payment-gateway/ios-integration/

---

## Summary

**Current Status**: Your iOS project structure is ready, but you need macOS to build and deploy.

**Recommended Path**:
1. Use **Codemagic** for automated iOS builds (works from Windows)
2. Or get access to a Mac for manual deployment
3. Follow the step-by-step guide above when you have Mac access

**Estimated Time**:
- First-time setup: 2-4 hours
- App Store review: 1-3 days
- Total: ~1 week from Mac access to App Store

Good luck with your iOS deployment! 🚀
