// functions/index.js (Firebase Cloud Functions)

const { setGlobalOptions } = require("firebase-functions");
const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

// Initialize Firebase Admin SDK
admin.initializeApp();
setGlobalOptions({ maxInstances: 10 });

/**
 * Cloud Function to broadcast a push notification to all users subscribed to the 'all' topic.
 * This function is callable ONLY by an authenticated Firebase user (like an Admin).
 */
exports.broadcastNotification = onCall(
  {
    cors: true,
    // The default onCall security is used: it requires the Firebase ID token.
    // The function is deployed in the default region (us-central1), 
    // but the region can be explicitly set here if needed: region: 'us-central1'
  },
  async (request) => {
    // 1. Authentication Check
    if (!request.auth || !request.auth.uid) {
      logger.warn("Attempted unauthenticated call to broadcastNotification");
      // Throwing an Error here is correctly caught by the Dart SDK as UNAUTHENTICATED
      throw new Error('The function must be called by an authenticated user.');
    }
    
    // 2. Data Validation and extraction
    const title = request.data.title;
    const body = request.data.body;
    const imageUrl = request.data.imageUrl;

    if (!title || !body) {
      throw new Error('Title and body are required fields.');
    }

    // 3. Construct the FCM Message
    const message = {
      notification: {
        title: title,
        body: body,
        // Firebase Cloud Messaging (FCM) uses 'image' field for notification image
        // which falls back to data payload handling on some devices.
        imageUrl: imageUrl || undefined, 
      },
      topic: "all",
      // Add data payload for reliable image display and custom handling
      data: {
          title: title,
          body: body,
          image: imageUrl || '',
      }
    };

    // 4. Send the Message
    try {
      logger.info(`Sending notification: ${title} to topic: all`);
      
      const response = await admin.messaging().send(message);
      
      logger.info("✅ Notification sent successfully:", { response: response, title: title });
      
      return { success: true, response: response };
    } catch (error) {
      logger.error("❌ Error sending notification:", error);
      // Re-throw the error so it's reported back to the Dart client
      throw new Error(`Failed to send notification: ${error.message}`);
    }
  }
);