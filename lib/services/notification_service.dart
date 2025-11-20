import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: androidInit);

    await _plugin.initialize(settings);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'mbbs_channel',
      'MBBS Freaks Channel',
      description: 'App notifications',
      importance: Importance.max,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> showLocal({
    required String title,
    required String message,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'mbbs_channel',
      'MBBS Freaks Channel',
      channelDescription: 'App notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      message,
      details,
    );
  }
}
