import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reminder.dart';
import '../routing/navigation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 1. Setup Timezone
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (e) {
      tz.setLocalLocation(tz.UTC);
    }

    // 2. Setup Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. Setup iOS & macOS
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // 4. Setup Linux
    final LinuxInitializationSettings linuxSettings =
        LinuxInitializationSettings(defaultActionName: 'Open notification');

    // 5. Initialize Plugin
    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
      linux: linuxSettings,
      windows: WindowsInitializationSettings(
        appName: 'ReminderKita',
        appUserModelId: 'com.reminderkita.app',
        guid: 'f3781fd7-37f8-4d59-9f42-a2fe6bb317d5',
      ),
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) {
          navigateAndRemoveAll('/login');
        } else {
          navigateAndRemoveAll('/classes');
        }
      },
    );

    // 6. Create Channel (Android Only)
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      await androidImplementation?.requestNotificationsPermission();

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'channel_tugas_v2',
        'Reminder Tugas',
        description: 'Notifikasi deadline tugas',
        importance: Importance.max,
      );

      await androidImplementation?.createNotificationChannel(channel);
    }
  }

  static Future<void> cancelTaskNotifications(int taskId) async {
    for (int i = 1; i <= 4; i++) {
      await _notifications.cancel(taskId * 10 + i);
    }
  }

  static Future<void> scheduleReminder(Reminder reminder) async {
    await cancelTaskNotifications(reminder.id);
    if (reminder.status != ReminderStatus.pending) return;

    final schedules = <({int slot, Duration offset, String label})>[
      (slot: 1, offset: const Duration(days: 7), label: 'H-7'),
      (slot: 2, offset: const Duration(days: 3), label: 'H-3'),
      (slot: 3, offset: const Duration(days: 1), label: 'H-1'),
      (slot: 4, offset: Duration.zero, label: 'Hari H'),
    ];
    final dueLabel = DateFormat(
      'd MMM yyyy, HH:mm',
      'id_ID',
    ).format(reminder.dueDate.toLocal());

    for (final item in schedules) {
      final scheduledAt = reminder.dueDate.subtract(item.offset);
      if (!scheduledAt.isAfter(DateTime.now())) continue;
      await schedule(
        reminder.id * 10 + item.slot,
        '${item.label}: ${reminder.title}',
        'Tenggat $dueLabel. Prioritas ${reminder.priority.label}.',
        scheduledAt,
        'reminder:${reminder.id}:${reminder.targetClass}',
      );
    }
  }

  static Future<void> schedule(
    int id,
    String title,
    String body,
    DateTime scheduledDate,
    String payload,
  ) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_tugas_v2',
          'Reminder Tugas',
          channelDescription: 'Notifikasi deadline tugas',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
          color: Color(0xFF2563EB),
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }
}
