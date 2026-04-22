import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettingsModel {
  final String id;
  final String defaultAnnouncementLanguage;
  final bool bilingualAnnouncements;

  final String alarmStrengthProfile;
  final bool vibrationEnabled;
  final int repeatIntervalSeconds;
  final int maxAlarmDurationMinutes;
  final int defaultSnoozeMinutes;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppSettingsModel({
    required this.id,
    required this.defaultAnnouncementLanguage,
    required this.bilingualAnnouncements,
    required this.alarmStrengthProfile,
    required this.vibrationEnabled,
    required this.repeatIntervalSeconds,
    required this.maxAlarmDurationMinutes,
    required this.defaultSnoozeMinutes,
    this.createdAt,
    this.updatedAt,
  });

  factory AppSettingsModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return AppSettingsModel(
      id: doc.id,
      defaultAnnouncementLanguage:
          (data['default_announcement_language'] ?? 'english')
              .toString()
              .trim()
              .toLowerCase(),
      bilingualAnnouncements: data['bilingual_announcements'] == true,
      alarmStrengthProfile: _normalizedAlarmStrength(
        data['alarm_strength_profile'],
      ),
      vibrationEnabled: data['vibration_enabled'] != false,
      repeatIntervalSeconds: _normalizedPositiveInt(
        data['repeat_interval_seconds'],
        fallback: 20,
      ),
      maxAlarmDurationMinutes: _normalizedPositiveInt(
        data['max_alarm_duration_minutes'],
        fallback: 5,
      ),
      defaultSnoozeMinutes: _normalizedPositiveInt(
        data['default_snooze_minutes'],
        fallback: 10,
      ),
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'default_announcement_language': defaultAnnouncementLanguage,
      'bilingual_announcements': bilingualAnnouncements,
      'alarm_strength_profile': alarmStrengthProfile,
      'vibration_enabled': vibrationEnabled,
      'repeat_interval_seconds': repeatIntervalSeconds,
      'max_alarm_duration_minutes': maxAlarmDurationMinutes,
      'default_snooze_minutes': defaultSnoozeMinutes,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  AppSettingsModel copyWith({
    String? id,
    String? defaultAnnouncementLanguage,
    bool? bilingualAnnouncements,
    String? alarmStrengthProfile,
    bool? vibrationEnabled,
    int? repeatIntervalSeconds,
    int? maxAlarmDurationMinutes,
    int? defaultSnoozeMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSettingsModel(
      id: id ?? this.id,
      defaultAnnouncementLanguage:
          defaultAnnouncementLanguage ?? this.defaultAnnouncementLanguage,
      bilingualAnnouncements:
          bilingualAnnouncements ?? this.bilingualAnnouncements,
      alarmStrengthProfile:
          alarmStrengthProfile ?? this.alarmStrengthProfile,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      repeatIntervalSeconds:
          repeatIntervalSeconds ?? this.repeatIntervalSeconds,
      maxAlarmDurationMinutes:
          maxAlarmDurationMinutes ?? this.maxAlarmDurationMinutes,
      defaultSnoozeMinutes:
          defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _normalizedAlarmStrength(dynamic raw) {
    final value = (raw ?? 'strong').toString().trim().toLowerCase();
    switch (value) {
      case 'normal':
      case 'strong':
      case 'very_strong':
        return value;
      default:
        return 'strong';
    }
  }

  static int _normalizedPositiveInt(
    dynamic raw, {
    required int fallback,
  }) {
    final value = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (value == null || value <= 0) return fallback;
    return value;
  }
}
