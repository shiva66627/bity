import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:no_screenshot/no_screenshot.dart';

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

/// 🧠 Show local notification in system tray
Future<void> _showLocalNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'mbbsfreaks_channel',
    'MBBS Freaks Notifications',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    message.notification.hashCode,
    message.notification?.title ?? 'MBBS Freaks',
    message.notification?.body ?? '',
    notificationDetails,
  );
}

/// 🔔 Handle background messages (no UI)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _showLocalNotification(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ Enable Firebase App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.debug,
  );

  // ✅ Disable screenshots globally
  await NoScreenshot.instance.screenshotOff();

  // ✅ Initialize local notifications
  const AndroidInitializationSettings androidInitSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidInitSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // ✅ Handle background notifications
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ✅ Request notification permission
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // ✅ Subscribe to 'all' topic for broadcast notifications
  await FirebaseMessaging.instance.subscribeToTopic('all');
  print("✅ Subscribed to 'all' topic for notifications");

  // ✅ Foreground message listener
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _showLocalNotification(message);
  });

  // ✅ Handle notification tap when app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("🟡 Notification opened: ${message.data}");
    // Navigate to Notifications Page
    navigatorKey.currentState?.pushNamed('/notifications');
  });

  // ✅ Handle notification tap when app is terminated
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print("🚀 App opened from notification: ${initialMessage.data}");
    // Delay navigation to allow MaterialApp to build
    Future.delayed(const Duration(milliseconds: 500), () {
      navigatorKey.currentState?.pushNamed('/notifications');
    });
  }

  // ✅ Optional: print FCM token for testing
  String? token = await FirebaseMessaging.instance.getToken();
  print("🔥 FCM Token: $token");

  runApp(const EducationalApp(startScreen: SplashScreen()));
}

/// 🌐 Global navigator key to handle navigation outside of context
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
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ Added for navigation on tap
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
