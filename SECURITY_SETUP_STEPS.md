# 🚀 Complete Security Setup - Step by Step

## ⚠️ IMPORTANT: Follow These Steps IN ORDER

### Step 1: Set Up Firebase Secrets (REQUIRED)

```powershell
# Set Razorpay Key
firebase functions:secrets:set RAZORPAY_KEY
# When prompted, paste: rzp_live_Rkix3Q3zGpJC96

# Set Razorpay Secret
firebase functions:secrets:set RAZORPAY_SECRET
# When prompted, paste: ElWpnmxCEgdwXTwl2c2rI
```

**Why?** Your Cloud Functions need these secrets to process payments in production.

---

### Step 2: Deploy Functions with Secrets

```powershell
firebase deploy --only functions
```

**Why?** This uploads your functions and connects them to the secrets you just created.

---

### Step 3: Run Security Cleanup Script

```powershell
.\secure-cleanup.ps1
```

**What it does:**
- Removes `functions/config.json` from Git tracking
- Removes `android/app/google-services.json` from Git tracking
- Removes `ios/Runner/GoogleService-Info.plist` from Git tracking
- Keeps the files on your computer (so your app still works locally)

**Answer "yes"** when prompted.

---

### Step 4: Commit the Security Changes

```powershell
# Add the updated .gitignore and example files
git add .gitignore
git add functions/config.example.json
git add functions/CONFIG_README.md
git add .gemini/

# Commit the changes
git commit -m "Security: Remove sensitive files and add .gitignore rules"
```

**Why?** This saves the security improvements to Git.

---

### Step 5: Push to GitHub

```powershell
git push origin main
```

**Why?** Now it's safe to push because sensitive files are excluded.

---

## ✅ Complete Command Sequence (Copy & Paste)

```powershell
# 1. Set Firebase Secrets
firebase functions:secrets:set RAZORPAY_KEY
# Paste: rzp_live_Rkix3Q3zGpJC96

firebase functions:secrets:set RAZORPAY_SECRET
# Paste: ElWpnmxCEgdwXTwl2c2rI

# 2. Deploy Functions
firebase deploy --only functions

# 3. Clean up Git tracking
.\secure-cleanup.ps1
# Answer "yes" when prompted

# 4. Commit changes
git add .gitignore
git add functions/config.example.json
git add functions/CONFIG_README.md
git add .gemini/
git commit -m "Security: Remove sensitive files and add .gitignore rules"

# 5. Push to GitHub
git push origin main
```

---

## 🔍 Verification Steps

After completing the above, verify everything is secure:

### Check 1: Verify Secrets Are Set

```powershell
firebase functions:secrets:access RAZORPAY_KEY
# Should show: rzp_live_Rkix3Q3zGpJC96

firebase functions:secrets:access RAZORPAY_SECRET
# Should show: ElWpnmxCEgdwXTwl2c2rI
```

### Check 2: Verify Files Are NOT Tracked

```powershell
git ls-files | Select-String -Pattern "config.json|google-services.json|GoogleService-Info.plist"
# Should show NOTHING or only config.example.json
```

### Check 3: Verify .gitignore Is Working

```powershell
git status
# Should NOT show:
# - functions/config.json
# - android/app/google-services.json
# - ios/Runner/GoogleService-Info.plist
```

---

## ❓ What If Something Goes Wrong?

### Error: "firebase: command not found"

**Solution**: Install Firebase CLI first:
```powershell
npm install -g firebase-tools
firebase login
```

### Error: "Permission denied" when setting secrets

**Solution**: Make sure you're logged in:
```powershell
firebase login
```

### Error: "Failed to deploy functions"

**Solution**: Check your Firebase project:
```powershell
firebase use --add
# Select your project: mbbsfreaks-90b4f
```

### Sensitive files still showing in git status

**Solution**: Run the cleanup script again:
```powershell
.\secure-cleanup.ps1
```

---

## 📋 Final Checklist

Before pushing to GitHub, make sure:

- [ ] Firebase secrets are set (RAZORPAY_KEY, RAZORPAY_SECRET)
- [ ] Functions are deployed: `firebase deploy --only functions`
- [ ] Cleanup script ran successfully: `.\secure-cleanup.ps1`
- [ ] Sensitive files removed from Git: `git ls-files` shows no config.json
- [ ] .gitignore is committed: `git status` shows it's staged
- [ ] Changes are committed: `git commit` completed
- [ ] Ready to push: `git push origin main`

---

## 🎯 Summary

**Your original 4 commands were close, but you need 5 steps:**

1. ✅ `firebase functions:secrets:set RAZORPAY_KEY`
2. ✅ `firebase functions:secrets:set RAZORPAY_SECRET`
3. ✅ **`firebase deploy --only functions`** ← YOU WERE MISSING THIS!
4. ✅ `.\secure-cleanup.ps1`
5. ✅ **`git add .` and `git commit`** ← YOU WERE MISSING THIS!
6. ✅ `git push origin main`

**The key difference**: You need to deploy functions AND commit the changes before pushing.

---

## 🚀 Ready? Run This Now:

```powershell
# Complete security setup (copy all of this):

firebase functions:secrets:set RAZORPAY_KEY
# Paste when prompted: rzp_live_Rkix3Q3zGpJC96

firebase functions:secrets:set RAZORPAY_SECRET
# Paste when prompted: ElWpnmxCEgdwXTwl2c2rI

firebase deploy --only functions

.\secure-cleanup.ps1
# Answer "yes"

git add .gitignore functions/config.example.json functions/CONFIG_README.md .gemini/

git commit -m "Security: Remove sensitive files and add .gitignore rules"

git push origin main
```

That's it! You're secure! 🎉
