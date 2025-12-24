import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/medicine_model.dart';
import 'package:flutter/material.dart';

// Arka plan bildirim aksiyonu işleyicisi (Top-level olmak zorunda)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('Arka plan bildirim aksiyonu: ${notificationResponse.actionId}');
}

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // StreamController bildirim tıklamalarını dinlemek için
  final StreamController<String?> selectNotificationStream =
      StreamController<String?>.broadcast();

  Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Android 13+ bildirim izni
      final bool? granted =
          await androidPlugin.requestNotificationsPermission();
      debugPrint('Bildirim İzni Durumu: $granted');

      // Android 12+ kesin alarm izni
      final bool? alarmGranted =
          await androidPlugin.requestExactAlarmsPermission();
      debugPrint('Alarm İzni Durumu: $alarmGranted');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      selectNotificationStream.add(response.payload);
    }
  }

  Future<void> scheduleMedicineNotifications(IlacModel medicine) async {
    await cancelMedicineNotifications(medicine.id);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'medicine_alarm_channel_v2', // Kanal ID'yi değiştirdik (Ayarların yenilenmesi için)
      'İlaç Alarmları',
      channelDescription: 'Tam ekran ilaç alarmları',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true, // Tam ekran niyeti
      visibility: NotificationVisibility.public, // Kilit ekranında görün
      ongoing: true,
      autoCancel: false,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'TAKE',
          'İlacı Aldım',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'SNOOZE',
          'Ertele',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    for (int i = 0; i < medicine.times.length; i++) {
      final String timeStr = medicine.times[i];
      final parts = timeStr.split(':');
      if (parts.length != 2) continue;

      final int hour = int.tryParse(parts[0]) ?? 0;
      final int minute = int.tryParse(parts[1]) ?? 0;
      final int id = medicine.id.hashCode + i;

      // Payload formatı: id|name|dose|time|audioPath
      final String payload =
          '${medicine.id}|${medicine.name}|${medicine.dose}|$timeStr|${medicine.audioPath ?? ''}';

      try {
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          '💊 ${medicine.name}',
          '${medicine.dose} - Alma vakti!',
          _nextInstanceOfTime(hour, minute),
          platformDetails,
          payload: payload,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
        );
      } catch (e) {
        debugPrint('Alarm kurulamadı: $e');
      }
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Tolerans Kontrolü: Eğer alarm zamanı geçmişteyse ama
    // fark 1 dakikadan az ise (örn: saniye farkı),
    // bunu "geçmiş" sayma, 5 saniye sonrasına kur ki çalsın.
    if (scheduledDate.isBefore(now)) {
      if (now.difference(scheduledDate).inSeconds < 60) {
        // Çok az farkla kaçırdık, hemen çalması için biraz ileri al
        // Ancak zonedSchedule geçmişe izin vermez, o yüzden now + 5 sn
        debugPrint(
            '⏰ Alarm zamanı çok yakın, hemen çalması için ayarlanıyor...');
        return now.add(const Duration(seconds: 5));
      } else {
        // Gerçekten geçmiş, yarına kur
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }
    }

    debugPrint('⏰ Alarm Zamanı: $scheduledDate');
    return scheduledDate;
  }

  Future<void> cancelMedicineNotifications(String medicineId) async {
    for (int i = 0; i < 10; i++) {
      await flutterLocalNotificationsPlugin.cancel(medicineId.hashCode + i);
    }
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
