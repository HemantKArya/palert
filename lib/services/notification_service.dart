import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initializes the notification plugin.
  static Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const linuxInit = LinuxInitializationSettings(defaultActionName: 'Open');
    const windowsInit = WindowsInitializationSettings(
      appName: 'Palert',
      appUserModelId: 'com.palert.app',
      guid: "1be63a6e-cb76-4e55-8eeb-c20d52d7fdb1",
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
      macOS: iosInit,
      linux: linuxInit,
      windows: windowsInit,
    );

    await _notificationsPlugin.initialize(initSettings);

    // Create Android notification channels
    if (!kIsWeb && Platform.isAndroid) {
      // Price drop channel
      const priceDropChannel = AndroidNotificationChannel(
        'price_drop_channel',
        'Price Drop Notifications',
        description: 'Alerts when a tracked product price drops',
        importance: Importance.high,
      );

      // Stock alert channel
      const stockAlertChannel = AndroidNotificationChannel(
        'stock_alert_channel',
        'Stock Alert Notifications',
        description: 'Alerts when a tracked product is back in stock',
        importance: Importance.high,
      );

      // Price increase channel
      const priceIncreaseChannel = AndroidNotificationChannel(
        'price_increase_channel',
        'Price Increase Notifications',
        description: 'Alerts when a tracked product price increases',
        importance: Importance.defaultImportance,
      );

      // Out of stock channel
      const outOfStockChannel = AndroidNotificationChannel(
        'out_of_stock_channel',
        'Out of Stock Notifications',
        description: 'Alerts when a tracked product goes out of stock',
        importance: Importance.defaultImportance,
      );

      // Service status channel
      const serviceChannel = AndroidNotificationChannel(
        'service_channel',
        'Service Notifications',
        description: 'Browser service status notifications',
        importance: Importance.defaultImportance,
      );

      final androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(priceDropChannel);
        await androidPlugin.createNotificationChannel(stockAlertChannel);
        await androidPlugin.createNotificationChannel(priceIncreaseChannel);
        await androidPlugin.createNotificationChannel(outOfStockChannel);
        await androidPlugin.createNotificationChannel(serviceChannel);
      }
    }
  }

  /// Shows a notification when a price drop is detected.
  /// [imageUrl] is optional; if provided, the image will be downloaded and shown.
  static Future<void> showPriceDropNotification({
    required String title,
    String? imageUrl,
    required int oldPrice,
    required int newPrice,
  }) async {
    String? bigPicturePath;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final tempDir = await getTemporaryDirectory();
        final fileName = path.basename(Uri.parse(imageUrl).path);
        final filePath = path.join(tempDir.path, fileName);
        final response = await http.get(Uri.parse(imageUrl));
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        bigPicturePath = filePath;
      } catch (_) {
        bigPicturePath = null;
      }
    }

    // Android specifics
    AndroidNotificationDetails androidDetails;
    if (bigPicturePath != null) {
      androidDetails = AndroidNotificationDetails(
        'price_drop_channel',
        'Price Drop Notifications',
        channelDescription: 'Alerts when a tracked product price drops',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigPictureStyleInformation(
          FilePathAndroidBitmap(bigPicturePath),
          contentTitle: title,
          summaryText: 'Price dropped from \\$oldPrice to \\$newPrice',
        ),
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        'price_drop_channel',
        'Price Drop Notifications',
        channelDescription: 'Alerts when a tracked product price drops',
        importance: Importance.high,
        priority: Priority.high,
      );
    }

    // iOS / macOS specifics
    const darwinDetails = DarwinNotificationDetails(
      subtitle: 'Price Alert',
    );

    // Add Linux details for completeness, though the main issue is Windows
    const linuxDetails = LinuxNotificationDetails();

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );

    await _notificationsPlugin.show(
      0,
      title,
      'Price dropped from \\$oldPrice to \\$newPrice',
      notificationDetails,
    );
  }

  /// Shows a service-related notification
  static Future<void> showServiceNotification({
    required String title,
    required String message,
    bool isError = false,
    int? notificationId,
  }) async {
    await _notificationsPlugin.show(
      notificationId ?? 1,
      title,
      message,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'service_channel',
          'Service Notifications',
          channelDescription: 'Browser service status notifications',
          importance: isError ? Importance.high : Importance.defaultImportance,
          priority: isError ? Priority.high : Priority.defaultPriority,
          icon: isError ? '@drawable/ic_error' : '@drawable/ic_info',
        ),
        iOS: const DarwinNotificationDetails(
          subtitle: 'Service Status',
        ),
        macOS: const DarwinNotificationDetails(
          subtitle: 'Service Status',
        ),
        linux: const LinuxNotificationDetails(),
      ),
    );
  }

  /// Shows notification for service restart
  static Future<void> showServiceRestartNotification({
    required int newPort,
    int? oldPort,
  }) async {
    final message = oldPort != null && oldPort != newPort
        ? 'Browser service restarted on port $newPort (was $oldPort)'
        : 'Browser service restarted on port $newPort';

    await showServiceNotification(
      title: 'Service Restarted',
      message: message,
      notificationId: 2,
    );
  }

  /// Shows notification for service failure
  static Future<void> showServiceFailureNotification({
    required String reason,
    bool isRecoverable = true,
  }) async {
    final message = isRecoverable
        ? 'Browser service failed: $reason. Attempting automatic restart...'
        : 'Browser service failed: $reason. Manual intervention required.';

    await showServiceNotification(
      title: 'Service Failure',
      message: message,
      isError: true,
      notificationId: 3,
    );
  }

  /// Shows notification when product comes back in stock
  static Future<void> showBackInStockNotification({
    required String title,
    String? imageUrl,
  }) async {
    String? bigPicturePath;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final tempDir = await getTemporaryDirectory();
        final fileName = path.basename(Uri.parse(imageUrl).path);
        final filePath = path.join(tempDir.path, fileName);
        final response = await http.get(Uri.parse(imageUrl));
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        bigPicturePath = filePath;
      } catch (_) {
        bigPicturePath = null;
      }
    }

    // Android specifics
    AndroidNotificationDetails androidDetails;
    if (bigPicturePath != null) {
      androidDetails = AndroidNotificationDetails(
        'stock_alert_channel',
        'Stock Alert Notifications',
        channelDescription: 'Alerts when a tracked product is back in stock',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigPictureStyleInformation(
          FilePathAndroidBitmap(bigPicturePath),
          contentTitle: title,
          summaryText: 'Product is now back in stock',
        ),
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        'stock_alert_channel',
        'Stock Alert Notifications',
        channelDescription: 'Alerts when a tracked product is back in stock',
        importance: Importance.high,
        priority: Priority.high,
      );
    }

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(subtitle: 'Stock Alert'),
      macOS: const DarwinNotificationDetails(subtitle: 'Stock Alert'),
      linux: const LinuxNotificationDetails(),
    );

    await _notificationsPlugin.show(
      4,
      title,
      'Product is now back in stock!',
      notificationDetails,
    );
  }

  /// Shows notification when price increases
  static Future<void> showPriceIncreaseNotification({
    required String title,
    String? imageUrl,
    required int oldPrice,
    required int newPrice,
  }) async {
    String? bigPicturePath;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final tempDir = await getTemporaryDirectory();
        final fileName = path.basename(Uri.parse(imageUrl).path);
        final filePath = path.join(tempDir.path, fileName);
        final response = await http.get(Uri.parse(imageUrl));
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        bigPicturePath = filePath;
      } catch (_) {
        bigPicturePath = null;
      }
    }

    // Android specifics
    AndroidNotificationDetails androidDetails;
    if (bigPicturePath != null) {
      androidDetails = AndroidNotificationDetails(
        'price_increase_channel',
        'Price Increase Notifications',
        channelDescription: 'Alerts when a tracked product price increases',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        styleInformation: BigPictureStyleInformation(
          FilePathAndroidBitmap(bigPicturePath),
          contentTitle: title,
          summaryText: 'Price increased from ₹$oldPrice to ₹$newPrice',
        ),
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        'price_increase_channel',
        'Price Increase Notifications',
        channelDescription: 'Alerts when a tracked product price increases',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
    }

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(subtitle: 'Price Alert'),
      macOS: const DarwinNotificationDetails(subtitle: 'Price Alert'),
      linux: const LinuxNotificationDetails(),
    );

    await _notificationsPlugin.show(
      5,
      title,
      'Price increased from ₹$oldPrice to ₹$newPrice',
      notificationDetails,
    );
  }

  /// Shows notification when product goes out of stock
  static Future<void> showOutOfStockNotification({
    required String title,
    String? imageUrl,
  }) async {
    String? bigPicturePath;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final tempDir = await getTemporaryDirectory();
        final fileName = path.basename(Uri.parse(imageUrl).path);
        final filePath = path.join(tempDir.path, fileName);
        final response = await http.get(Uri.parse(imageUrl));
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        bigPicturePath = filePath;
      } catch (_) {
        bigPicturePath = null;
      }
    }

    // Android specifics
    AndroidNotificationDetails androidDetails;
    if (bigPicturePath != null) {
      androidDetails = AndroidNotificationDetails(
        'out_of_stock_channel',
        'Out of Stock Notifications',
        channelDescription: 'Alerts when a tracked product goes out of stock',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        styleInformation: BigPictureStyleInformation(
          FilePathAndroidBitmap(bigPicturePath),
          contentTitle: title,
          summaryText: 'Product is now out of stock',
        ),
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        'out_of_stock_channel',
        'Out of Stock Notifications',
        channelDescription: 'Alerts when a tracked product goes out of stock',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
    }

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(subtitle: 'Stock Alert'),
      macOS: const DarwinNotificationDetails(subtitle: 'Stock Alert'),
      linux: const LinuxNotificationDetails(),
    );

    await _notificationsPlugin.show(
      6,
      title,
      'Product is now out of stock',
      notificationDetails,
    );
  }
}
