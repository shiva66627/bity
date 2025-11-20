import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'dart:io' show Platform;
import 'package:mbbsfreaks/screens/user_notifications_page.dart';

import 'package:no_screenshot/no_screenshot.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/home_page.dart';
import 'screens/user_content_browser.dart';
import 'screens/notes.dart';
import 'screens/pyqs.dart';
import 'screens/question_bank.dart';
import 'screens/quiz.dart';
import 'screens/admin_login_page.dart';
import 'screens/admin_dashboard.dart';
import 'screens/notifications_page.dart';

/// 🔔 Local notification plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Global navigator key so we can navigate from background / notification tap
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 🔔 Local notification display
Future<void> _showLocalNotification(RemoteMessage message) async {
  const androidDetails = AndroidNotificationDetails(
    'mbbsfreaks_channel',
    'MBBS Freaks Notifications',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
  );

  const details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    message.notification.hashCode,
    message.notification?.title ?? 'MBBS Freaks',
    message.notification?.body ?? '',
    details,
  );
}

/// 🔔 Background FCM handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _showLocalNotification(message);
}

/// ⭐ SAVE DEVICE TOKEN
Future<void> saveDeviceToken() async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) return;

  await FirebaseFirestore.instance
      .collection('device_tokens')
      .doc(token)
      .set({
    'token': token,
    'createdAt': FieldValue.serverTimestamp(),
  });
  print('🔥 Saved FCM token to Firestore: $token');
}

/// 🌟 MAIN
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase first
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ⭐ App Check (optional but you already imported it)
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  // ⭐ Local Notification Initialization (BEFORE runApp)
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    // 👉 Tap on notification (when app in foreground/background)
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      navigatorKey.currentState?.pushNamed('/notifications');
    },
  );
  print("🔥 NOTIFICATION INITIALIZED");

  // ⭐ Background FCM handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ⭐ Ask Notification Permission (Android 13+ + iOS)
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print("🔥 Notification permission: ${settings.authorizationStatus}");

  // (Optional) extra Android 13 permission via permission_handler
  if (!kIsWeb && Platform.isAndroid) {
    final notifStatus = await Permission.notification.status;
    if (notifStatus.isDenied) {
      await Permission.notification.request();
    }
  }

  // Save token to Firestore
  await saveDeviceToken();

  // Subscribe everyone to topic "all" (for broadcast)
  await FirebaseMessaging.instance.subscribeToTopic('all');

  // ⭐ Foreground notifications
  FirebaseMessaging.onMessage.listen((message) {
    if (message.notification != null) {
      _showLocalNotification(message);
    }
  });

  // ⭐ When user taps notification and app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    navigatorKey.currentState?.pushNamed('/notifications');
  });

  // ⭐ When app is launched from terminated by tapping a notification
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();

  // Start UI
  runApp(const EducationalApp(startScreen: SplashScreen()));

  // Navigate if opened from terminated state via notification
  if (initialMessage != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushNamed('/notifications');
    });
  }

  // Background tasks AFTER UI loads
  Future.delayed(Duration.zero, () async {
    await _initializeBackgroundServices();
  });
}

/// ⭐ ALL heavy initialization
Future<void> _initializeBackgroundServices() async {
  // Hive (offline)
  await Hive.initFlutter();
  await Hive.openBox('notesBox');

  // Only mobile
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    // Screenshot Lock
    await NoScreenshot.instance.screenshotOff();

    // Just log token / ensure it exists
    final token = await FirebaseMessaging.instance.getToken();
    print("🔥 FCM Token: $token");
  }
}

class EducationalApp extends StatefulWidget {
    // <-- ADD THIS

  final Widget startScreen;
  const EducationalApp({super.key, required this.startScreen});

  static _EducationalAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_EducationalAppState>();

  @override
  State<EducationalApp> createState() => _EducationalAppState();
}

class _EducationalAppState extends State<EducationalApp> {
      static bool isUserMode = false;   // ✅ CORRECT PLACE

  ThemeMode _themeMode = ThemeMode.light;

  void changeTheme(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'MBBS Freaks',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: widget.startScreen,
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const HomePage(),
        '/content': (context) => const UserContentBrowser(),
        '/notes': (context) => const NotesPage(),
        '/pyqs': (context) => const PyqsPage(),
        '/question_bank': (context) => const QuestionBankPage(),
        '/quiz': (context) => const QuizPage(),
        '/admin_login': (context) => const AdminLoginPage(),
        '/admin_dashboard': (context) => const AdminDashboard(),
        '/notifications': (context) => const NotificationsPage(),
        '/user_notifications': (context) => const UserNotificationsPage(),

      },
    );
  }
}
