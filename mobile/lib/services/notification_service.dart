import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../domain/product.dart';
import '../domain/reminder.dart';

class NotificationService {
  final plugin = FlutterLocalNotificationsPlugin();
  bool ready = false;
  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    await refreshTimezone();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_leaf'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    ready = true;
  }

  Future<void> refreshTimezone() async {
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
  }

  Future<bool> requestPermission() async {
    if (!ready) await initialize();
    if (Platform.isAndroid) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  // One digest per date keeps pending requests below Apple's 64-request limit.
  // Retain the closest 60 dates, and rebuild on launch, resume and every mutation.
  Future<bool> reschedule(
    List<Product> products, {
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    if (!ready) await initialize();
    await refreshTimezone();
    final groups = <String, List<Reminder>>{};
    if (enabled) {
      for (final r in buildReminders(products, DateTime.now(), hour, minute)) {
        groups.putIfAbsent(dateKey(r.at), () => []).add(r);
      }
    }
    await plugin.cancelAllPendingNotifications();
    var id = 1;
    for (final entries in groups.values.take(60)) {
      final at = entries.first.at;
      final body =
          entries.take(4).map((r) => r.message).join('\n') +
          (entries.length > 4
              ? '\nve ${entries.length - 4} ürün daha. Uygulamayı aç.'
              : '');
      await plugin.zonedSchedule(
        id: id++,
        title: 'Taze Kal · ${entries.length} ürün için hatırlatma',
        body: body,
        scheduledDate: tz.TZDateTime(
          tz.local,
          at.year,
          at.month,
          at.day,
          hour,
          minute,
        ),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'freshness',
            'Tazelik hatırlatmaları',
            channelDescription: 'Son tüketim ve açılma süresi hatırlatmaları',
            importance: Importance.defaultImportance,
            styleInformation: BigTextStyleInformation(body),
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    return groups.length > 60;
  }
}
