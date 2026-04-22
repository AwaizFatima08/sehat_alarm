import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:sehat_alarm_app/models/dose_event_model.dart';
import 'package:sehat_alarm_app/services/app_settings_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class AlarmNavigationPayload {
  final String eventId;
  final String medicineId;
  final String scheduleId;

  const AlarmNavigationPayload({
    required this.eventId,
    required this.medicineId,
    required this.scheduleId,
  });

  factory AlarmNavigationPayload.fromMap(Map<String, dynamic> map) {
    return AlarmNavigationPayload(
      eventId: map['event_id']?.toString() ?? '',
      medicineId: map['medicine_id']?.toString() ?? '',
      scheduleId: map['schedule_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'medicine_id': medicineId,
      'schedule_id': scheduleId,
    };
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final AppSettingsService _appSettingsService = AppSettingsService();

  final StreamController<AlarmNavigationPayload> _alarmNavigationController =
      StreamController<AlarmNavigationPayload>.broadcast();

  Stream<AlarmNavigationPayload> get alarmNavigationStream =>
      _alarmNavigationController.stream;

  static const String _channelId = 'sehat_alarm_reminders';
  static const String _channelName = 'Medicine Reminders';
  static const String _channelDescription =
      'Reminder notifications for scheduled medicines';

  Future<AlarmNavigationPayload?> initialize() async {
    await _configureLocalTimeZone();

    const androidSettings = AndroidInitializationSettings('app_icon');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _createAndroidChannel();

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final initialResponse = launchDetails?.notificationResponse;

    if (launchDetails?.didNotificationLaunchApp == true &&
        initialResponse?.payload != null) {
      return _parsePayload(initialResponse!.payload);
    }

    return null;
  }

  Future<void> requestAndroidPermissions() async {
    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
  }

  Future<void> syncNotificationsForEvents(List<DoseEventModel> events) async {
    final stopwatch = Stopwatch()..start();

    final futures = <Future<void>>[];
    for (final event in events) {
      futures.add(_processEvent(event));
    }

    await Future.wait(futures);

    stopwatch.stop();
    debugPrint(
      'NotificationService.syncNotificationsForEvents processed '
      '${events.length} events in ${stopwatch.elapsedMilliseconds} ms',
    );
  }

  Future<void> _processEvent(DoseEventModel event) async {
    await cancelNotificationForEvent(event.id);

    final scheduleAt = event.snoozeUntil ?? event.scheduledDateTime;
    if (scheduleAt == null) return;
    if (!event.isAlarmActive) return;
    if (!scheduleAt.isAfter(DateTime.now())) return;

    await scheduleDoseEventNotification(event: event);
  }

  Future<void> scheduleDoseEventNotification({
    required DoseEventModel event,
    String? medicineName,
  }) async {
    final scheduleAt = event.snoozeUntil ?? event.scheduledDateTime;
    if (scheduleAt == null) return;
    if (!event.isAlarmActive) return;

    final settings = await _appSettingsService.getSettings();
    final zonedTime = tz.TZDateTime.from(scheduleAt, tz.local);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      enableVibration: settings.vibrationEnabled,
      ticker: 'Sehat Alarm',
      ongoing: true,
      autoCancel: false,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );

    final payload = jsonEncode({
      'event_id': event.id,
      'medicine_id': event.medicineId,
      'schedule_id': event.scheduleId,
    });

    await _plugin.zonedSchedule(
      _notificationIdForEvent(event.id),
      medicineName ?? 'Medicine Reminder',
      _notificationBodyForEvent(event),
      zonedTime,
      NotificationDetails(android: androidDetails),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelNotificationForEvent(String eventId) async {
    await _plugin.cancel(_notificationIdForEvent(eventId));
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return _plugin.pendingNotificationRequests();
  }

  int _notificationIdForEvent(String eventId) {
    return eventId.hashCode & 0x7fffffff;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = _parsePayload(response.payload);
    if (payload == null) return;
    _alarmNavigationController.add(payload);
  }

  AlarmNavigationPayload? _parsePayload(String? rawPayload) {
    if (rawPayload == null || rawPayload.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(rawPayload) as Map<String, dynamic>;
      return AlarmNavigationPayload.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  String _notificationBodyForEvent(DoseEventModel event) {
    final quantity = event.quantityPerDoseSnapshot;
    final unit = event.quantityUnitSnapshot.trim();
    final slot = event.slotLabelSnapshot.trim();

    final parts = <String>[];

    if (quantity != null) {
      final quantityText = quantity == quantity.roundToDouble()
          ? quantity.toInt().toString()
          : quantity.toString();
      parts.add(
        unit.isEmpty ? quantityText : '$quantityText $unit',
      );
    }

    if (slot.isNotEmpty) {
      parts.add(slot);
    }

    if (parts.isEmpty) {
      return 'It is time to take your medicine now.';
    }

    return 'It is time to take your medicine now. ${parts.join(' • ')}';
  }

  Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
  }

  Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
    );

    final androidImplementation =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.createNotificationChannel(channel);
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // Launch handling is completed through app launch details.
}
