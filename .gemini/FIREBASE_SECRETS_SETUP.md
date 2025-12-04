# 🔐 Firebase Secrets Setup Guide

## Current Status

Your `functions/index.js` is already configured to use **Firebase Functions v2 Secrets** for Razorpay credentials. This is the **most secure** method! ✅

## What You Need to Do

### Step 1: Set Up Firebase Secrets (Required for Production)

Firebase Functions v2 uses **Secret Manager** instead of config files.

#### A. Install Firebase CLI (if not already installed)

```bash
npm install -g firebase-tools
```

#### B. Login to Firebase

```bash
firebase login
```

#### C. Create Secrets in Google Cloud Secret Manager

```bash
# Set Razorpay Key
firebase functions:secrets:set RAZORPAY_KEY

# When prompted, paste your key: rzp_live_Rkix3Q3zGpJC96
# Press Enter

# Set Razorpay Secret
firebase functions:secrets:set RAZORPAY_SECRET

# When prompted, paste your secret: ElWpnmxCEgdwXTwl2c2rI
# Press Enter
```

#### D. Grant Access to Cloud Functions

```bash
# The secrets are automatically accessible to functions that declare them
# Your function already declares: { secrets: ["RAZORPAY_KEY", "RAZORPAY_SECRET"] }
```

#### E. Deploy Functions

```bash
firebase deploy --only functions
```

### Step 2: Verify Secrets Are Set

```bash
# List all secrets
firebase functions:secrets:access RAZORPAY_KEY
firebase functions:secrets:access RAZORPAY_SECRET
```

---

## Alternative: Use config.json for Local Development

For **local testing only**, you can keep `config.json` on your computer (it's already gitignored).

### Local Development Setup

1. **Keep your local `config.json`** (already exists):
   ```json
   {
     "razorpay": {
       "key": "rzp_live_Rkix3Q3zGpJC96",
       "secret": "ElWpnmxCEgdwXTwl2c2rI"
     }
   }
   ```

2. **For local emulator testing**, create a `.env` file in `functions/`:
   ```bash
   # functions/.env (gitignored)
   RAZORPAY_KEY=rzp_live_Rkix3Q3zGpJC96
   RAZORPAY_SECRET=ElWpnmxCEgdwXTwl2c2rI
   ```

3. **Run Firebase emulator**:
   ```bash
   firebase emulators:start --only functions
   ```

---

## How It Works

### In Production (Firebase Deployed)

```javascript
// functions/index.js (already configured ✅)
exports.createRazorpayOrder = onCall(
  { secrets: ["RAZORPAY_KEY", "RAZORPAY_SECRET"] },  // ← Declares required secrets
  async (request) => {
    const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY;      // ← Auto-injected
    const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_SECRET; // ← Auto-injected
    
    const razorpay = new Razorpay({
      key_id: RAZORPAY_KEY_ID,
      key_secret: RAZORPAY_KEY_SECRET,
    });
    // ...
  }
);
```

### Security Benefits

✅ **Secrets are encrypted** in Google Cloud Secret Manager  
✅ **Not stored in code** or config files  
✅ **Automatically rotated** (you can update without redeploying)  
✅ **Access controlled** by IAM permissions  
✅ **Audit logs** track who accessed secrets  

---

## Migration Checklist

- [ ] Install Firebase CLI: `npm install -g firebase-tools`
- [ ] Login: `firebase login`
- [ ] Set RAZORPAY_KEY secret: `firebase functions:secrets:set RAZORPAY_KEY`
- [ ] Set RAZORPAY_SECRET secret: `firebase functions:secrets:set RAZORPAY_SECRET`
- [ ] Deploy functions: `firebase deploy --only functions`
- [ ] Test payment flow in production
- [ ] Remove `config.json` from Git tracking (use secure-cleanup.ps1)
- [ ] Push to GitHub safely

---

## Troubleshooting

### Error: "Razorpay secrets not configured"

**Cause**: Secrets not set in Secret Manager

**Solution**:
```bash
firebase functions:secrets:set RAZORPAY_KEY
firebase functions:secrets:set RAZORPAY_SECRET
firebase deploy --only functions
```

### Error: "Permission denied"

**Cause**: Cloud Functions doesn't have access to secrets

**Solution**:
```bash
# Grant access (automatic when you deploy)
firebase deploy --only functions
```

### Local Testing Not Working

**Cause**: Emulator doesn't have access to secrets

**Solution**: Create `functions/.env` file:
```
RAZORPAY_KEY=rzp_live_Rkix3Q3zGpJC96
RAZORPAY_SECRET=ElWpnmxCEgdwXTwl2c2rI
```

---

## Cost

**Secret Manager Pricing** (as of 2024):
- First 6 active secrets: **FREE**
- Additional secrets: $0.06 per secret per month
- Access operations: $0.03 per 10,000 accesses

**Your cost**: $0/month (you have 2 secrets, well within free tier)

---

## Updating Secrets

To rotate/update secrets:

```bash
# Update RAZORPAY_KEY
firebase functions:secrets:set RAZORPAY_KEY

# Update RAZORPAY_SECRET
firebase functions:secrets:set RAZORPAY_SECRET

# Redeploy functions to use new secrets
firebase deploy --only functions
```

---

## Summary

✅ **Your code is already secure!** It uses Firebase Functions v2 Secrets.  
⚠️ **You just need to set the secrets** in Google Cloud Secret Manager.  
🚀 **Then you can safely push to GitHub** without exposing API keys.

Run these commands now:

```bash
firebase functions:secrets:set RAZORPAY_KEY
firebase functions:secrets:set RAZORPAY_SECRET
firebase deploy --only functions
```

Then run the cleanup script:

```powershell
.\secure-cleanup.ps1
```

You're all set! 🎉
