const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Broadcast to everyone subscribed to "all" topic
exports.broadcastNotification = functions.https.onCall(async (data, context) => {

  // 1. Auth check (admin only)
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be logged in to trigger notifications."
    );
  }

  // 2. Validate input
  const title = data.title;
  const body = data.body;
  const imageUrl = data.imageUrl || null;

  if (!title || !body) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Title and body are required"
    );
  }

  // 3. Build FCM message
  const message = {
    notification: {
      title: title,
      body: body,
      image: imageUrl || undefined,
    },
    data: {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      screen: "notifications",
      image: imageUrl ?? "",
    },
    topic: "all",   // 🔥 THIS sends to ALL USERS
  };

  try {
    const response = await admin.messaging().send(message);
    return { success: true, response };
  } catch (error) {
    throw new functions.https.HttpsError(
      "unknown",
      "Failed to send message: " + error
    );
  }
});
