# 🔒 Security Guide: Protecting Sensitive Data in GitHub

## ⚠️ CRITICAL: Sensitive Files Found

Your project contains sensitive API keys and credentials that **MUST NOT** be pushed to GitHub:

### 🚨 Sensitive Files in Your Project:

1. **`functions/config.json`** - Contains Razorpay API keys
2. **`android/app/google-services.json`** - Firebase Android config
3. **`ios/Runner/GoogleService-Info.plist`** - Firebase iOS config

---

## 🛡️ Solution: Environment Variables & .gitignore

### Step 1: Update .gitignore (CRITICAL - Do This First!)

I've already updated your `.gitignore` file to exclude sensitive files.

### Step 2: Use Environment Variables for Secrets

Instead of hardcoding secrets in `config.json`, use Firebase Functions environment variables.

---

## 📋 Implementation Steps

### A. Secure Firebase Cloud Functions (Razorpay Keys)

#### 1. Remove `config.json` from Git

```bash
# Remove from Git tracking (but keep local file)
git rm --cached functions/config.json

# The file will stay on your computer but won't be pushed to GitHub
```

#### 2. Set Environment Variables in Firebase

**Option A: Using Firebase CLI (Recommended)**

```bash
# Install Firebase CLI if not installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Set Razorpay credentials as environment variables
firebase functions:config:set razorpay.key="rzp_live_Rkix3Q3zGpJC96"
firebase functions:config:set razorpay.secret="ElWpnmxCEgdwXTwl2c2rI"

# View current config (to verify)
firebase functions:config:get

# Deploy functions with new config
firebase deploy --only functions
```

**Option B: Using Firebase Console**

1. Go to Firebase Console → Functions
2. Click on "Environment Variables"
3. Add:
   - `RAZORPAY_KEY` = `rzp_live_Rkix3Q3zGpJC96`
   - `RAZORPAY_SECRET` = `ElWpnmxCEgdwXTwl2c2rI`

#### 3. Update `functions/index.js` to Use Environment Variables

Replace hardcoded config with environment variables:

```javascript
// OLD (INSECURE):
const config = require('./config.json');
const razorpayKey = config.razorpay.key;
const razorpaySecret = config.razorpay.secret;

// NEW (SECURE):
const functions = require('firebase-functions');
const razorpayKey = functions.config().razorpay.key;
const razorpaySecret = functions.config().razorpay.secret;
```

#### 4. Create `config.example.json` (Template for Others)

```json
{
  "razorpay": {
    "key": "YOUR_RAZORPAY_KEY_HERE",
    "secret": "YOUR_RAZORPAY_SECRET_HERE"
  }
}
```

This file can be pushed to GitHub as a template.

---

### B. Secure Firebase Configuration Files

#### Option 1: Keep Firebase Files (Recommended for Public Apps)

Firebase config files (`google-services.json` and `GoogleService-Info.plist`) are **generally safe** to commit because:
- They contain public API keys
- Firebase security is handled by Firestore Rules
- The API keys are restricted by Firebase App Check

**However**, if you want extra security, use Option 2.

#### Option 2: Use Environment Variables (Extra Secure)

**For Android:**

1. Create `android/app/google-services.json.example`:
```json
{
  "project_info": {
    "project_id": "YOUR_PROJECT_ID"
  }
}
```

2. Add to `.gitignore`:
```
android/app/google-services.json
```

3. Use FlutterFire CLI to regenerate:
```bash
flutterfire configure
```

**For iOS:**

1. Create `ios/Runner/GoogleService-Info.plist.example`
2. Add to `.gitignore`:
```
ios/Runner/GoogleService-Info.plist
```

---

### C. Secure Other Sensitive Data

#### 1. API Keys in Dart Code

**NEVER** hardcode API keys in Dart files. Use environment variables:

**Create `.env` file** (add to .gitignore):
```
RAZORPAY_KEY=rzp_live_Rkix3Q3zGpJC96
FIREBASE_API_KEY=your_firebase_api_key
```

**Use `flutter_dotenv` package:**

```yaml
# pubspec.yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

```dart
// Load in main.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

// Use in code
final razorpayKey = dotenv.env['RAZORPAY_KEY'];
```

---

## 🔍 Check What's Already in Git

Before pushing to GitHub, check what's tracked:

```bash
# See all tracked files
git ls-files

# Check if sensitive files are tracked
git ls-files | grep -E "(config.json|google-services.json|GoogleService-Info.plist)"
```

---

## 🧹 Remove Sensitive Data Already Committed

If you've already committed sensitive data:

### Option 1: Remove from Last Commit (If Not Pushed)

```bash
# Remove file from last commit
git rm --cached functions/config.json
git commit --amend -m "Remove sensitive config file"
```

### Option 2: Remove from Git History (If Already Pushed)

⚠️ **WARNING**: This rewrites history. Only do this if necessary.

```bash
# Install BFG Repo Cleaner
# Download from: https://rtyley.github.io/bfg-repo-cleaner/

# Remove file from entire history
bfg --delete-files config.json

# Clean up
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push (⚠️ WARNING: Destructive!)
git push --force
```

### Option 3: Rotate API Keys (Safest)

1. **Generate new Razorpay keys** in Razorpay Dashboard
2. **Update Firebase config** (if exposed)
3. **Update your local files** with new keys
4. **Set up proper .gitignore** before committing
5. **Revoke old keys** in Razorpay Dashboard

---

## ✅ Pre-Push Checklist

Before pushing to GitHub, verify:

- [ ] `.gitignore` includes all sensitive files
- [ ] `functions/config.json` is NOT in Git
- [ ] Environment variables are set in Firebase
- [ ] `config.example.json` template exists
- [ ] No API keys hardcoded in `.dart` files
- [ ] Run `git status` to check staged files
- [ ] Run `git ls-files` to check tracked files

---

## 🚀 Safe Deployment Workflow

### 1. Local Development

```bash
# Keep your real config.json locally
functions/config.json  (gitignored)
```

### 2. Push to GitHub

```bash
# Only push safe files
git add .
git commit -m "Add features"
git push origin main
```

### 3. Deploy to Firebase

```bash
# Environment variables are already set in Firebase
firebase deploy --only functions
```

### 4. CI/CD (Codemagic)

In Codemagic, add environment variables:
- `RAZORPAY_KEY`
- `RAZORPAY_SECRET`
- Firebase service account JSON

---

## 🔐 Best Practices Summary

### ✅ DO:
- Use environment variables for secrets
- Add sensitive files to `.gitignore`
- Create `.example` template files
- Use Firebase Functions config
- Rotate keys if exposed
- Use Firebase App Check
- Review commits before pushing

### ❌ DON'T:
- Hardcode API keys in code
- Commit `config.json` with real keys
- Share `.env` files
- Push sensitive data to public repos
- Ignore security warnings

---

## 🆘 Emergency: Keys Already Exposed

If you've already pushed sensitive keys to GitHub:

### Immediate Actions:

1. **Revoke exposed keys immediately**:
   - Razorpay: Dashboard → Settings → API Keys → Regenerate
   - Firebase: Console → Project Settings → Regenerate

2. **Remove from GitHub**:
   - Delete repository (if possible)
   - Or use BFG Repo Cleaner (see above)

3. **Generate new keys**:
   - Create new API keys
   - Update local config
   - Set as environment variables

4. **Secure going forward**:
   - Follow this guide
   - Use `.gitignore` properly
   - Never commit secrets again

---

## 📚 Additional Resources

- **Firebase Functions Config**: https://firebase.google.com/docs/functions/config-env
- **Git Secrets**: https://github.com/awslabs/git-secrets
- **BFG Repo Cleaner**: https://rtyley.github.io/bfg-repo-cleaner/
- **GitHub Secret Scanning**: https://docs.github.com/en/code-security/secret-scanning

---

## 🎯 Quick Start Commands

```bash
# 1. Update .gitignore (already done ✅)

# 2. Remove sensitive files from Git
git rm --cached functions/config.json

# 3. Set Firebase environment variables
firebase functions:config:set razorpay.key="YOUR_KEY"
firebase functions:config:set razorpay.secret="YOUR_SECRET"

# 4. Create example config
cp functions/config.json functions/config.example.json
# Then edit config.example.json to remove real values

# 5. Commit and push safely
git add .
git commit -m "Secure sensitive data"
git push origin main
```

---

## ✨ You're Now Secure!

Follow these steps and your sensitive data will be protected. Your API keys will be safe, and you can push to GitHub without worry! 🎉
