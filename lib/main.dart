import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:no_screenshot/no_screenshot.dart';
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
}

/// 🌟 FAST APP START
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase first
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Show UI immediately
  runApp(const EducationalApp(startScreen: SplashScreen()));

  // Background heavy initialization
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
    // ⭐ FIXED: App Check (debug for dev, playIntegrity for release)
    await FirebaseAppCheck.instance.activate(
      androidProvider: kReleaseMode
          ? AndroidProvider.playIntegrity
          : AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );

    // Screenshot Lock
    await NoScreenshot.instance.screenshotOff();

    // Local Notification Init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // Background FCM
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );

    // Notification Permission
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // ⭐ Save token to Firestore
    saveDeviceToken();

    // ⭐ Foreground notifications
    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // ⭐ Subscribe everyone to "all"
    FirebaseMessaging.instance.subscribeToTopic('all');

    // Optional Log token
    FirebaseMessaging.instance.getToken().then((token) {
      print("🔥 FCM Token: $token");
    });
  }
}

/// Navigator key (if needed)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class EducationalApp extends StatefulWidget {
  final Widget startScreen;
  const EducationalApp({super.key, required this.startScreen});

  static _EducationalAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_EducationalAppState>();

  @override
  State<EducationalApp> createState() => _EducationalAppState();
}

class _EducationalAppState extends State<EducationalApp> {
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
      },
    );
  }
}
