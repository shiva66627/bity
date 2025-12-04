# Firebase Cloud Functions Configuration

## Setup Instructions

1. Copy this file to `config.json`:
   ```bash
   cp config.example.json config.json
   ```

2. Update `config.json` with your actual Razorpay credentials:
   - Get your Razorpay API keys from: https://dashboard.razorpay.com/app/keys
   - Use **Test Keys** for development
   - Use **Live Keys** for production

3. **NEVER** commit `config.json` to Git (it's in .gitignore)

## Alternative: Use Firebase Environment Variables (Recommended for Production)

Instead of using `config.json`, set environment variables:

```bash
# Set Razorpay credentials
firebase functions:config:set razorpay.key="YOUR_KEY"
firebase functions:config:set razorpay.secret="YOUR_SECRET"

# View current config
firebase functions:config:get

# Deploy with config
firebase deploy --only functions
```

Then update `index.js` to use environment variables:

```javascript
const functions = require('firebase-functions');
const razorpayKey = functions.config().razorpay.key;
const razorpaySecret = functions.config().razorpay.secret;
```

## Security Notes

- ⚠️ Never share your API keys publicly
- ⚠️ Never commit `config.json` to version control
- ✅ Use environment variables for production
- ✅ Rotate keys if exposed
- ✅ Use Razorpay webhooks for payment verification
