// Emergency removal of local notifications to fix iOS launch crash
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

class NotificationService {
  // static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Disabled to prevent crash
    /*
    try {
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        darwin: initializationSettingsDarwin,
      );

      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {},
      );

      // Request permissions for Android 13+
      if (Platform.isAndroid) {
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      }
    } catch (e) {
      print("NotificationService init error: $e");
    }
    */
  }

  static Future<void> showNotification(String title, String body) async {
    // Disabled to prevent crash
    /*
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'delivery_updates',
      'Delivery Updates',
      channelDescription: 'Notifications for order status and new assignments',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      darwin: const DarwinNotificationDetails(),
    );
    
    await _notificationsPlugin.show(
      id: DateTime.now().millisecond, // Unique ID
      title: title, 
      body: body, 
      notificationDetails: platformChannelSpecifics,
    );
    */
  }
}
