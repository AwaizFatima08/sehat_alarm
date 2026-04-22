import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sehat_alarm_app/core/constants/firestore_constants.dart';
import 'package:sehat_alarm_app/models/app_settings_model.dart';

class AppSettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _settingsCollection =>
      _firestore.collection(FirestoreConstants.appSettings);

  static const String settingsDocId = 'global';

  Future<AppSettingsModel> getSettings() async {
    final doc = await _settingsCollection.doc(settingsDocId).get();

    if (!doc.exists) {
      final defaultModel = _defaultModel();
      await _settingsCollection.doc(settingsDocId).set(defaultModel.toMap());
      return defaultModel;
    }

    return AppSettingsModel.fromFirestore(doc);
  }

  Stream<AppSettingsModel> watchSettings() {
    return _settingsCollection
        .doc(settingsDocId)
        .snapshots()
        .asyncMap((doc) async {
      if (doc.exists) {
        return AppSettingsModel.fromFirestore(doc);
      }

      final defaultModel = _defaultModel();
      await _settingsCollection.doc(settingsDocId).set(defaultModel.toMap());
      return defaultModel;
    });
  }

  Future<void> updateLanguageSettings({
    required String defaultAnnouncementLanguage,
    required bool bilingualAnnouncements,
  }) async {
    await _settingsCollection.doc(settingsDocId).set(
      {
        'default_announcement_language':
            defaultAnnouncementLanguage.trim().toLowerCase(),
        'bilingual_announcements': bilingualAnnouncements,
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateAlarmSettings({
    required String alarmStrengthProfile,
    required bool vibrationEnabled,
    required int repeatIntervalSeconds,
    required int maxAlarmDurationMinutes,
    required int defaultSnoozeMinutes,
  }) async {
    await _settingsCollection.doc(settingsDocId).set(
      {
        'alarm_strength_profile': _normalizeAlarmStrength(alarmStrengthProfile),
        'vibration_enabled': vibrationEnabled,
        'repeat_interval_seconds':
            repeatIntervalSeconds < 5 ? 5 : repeatIntervalSeconds,
        'max_alarm_duration_minutes':
            maxAlarmDurationMinutes < 1 ? 1 : maxAlarmDurationMinutes,
        'default_snooze_minutes':
            defaultSnoozeMinutes < 1 ? 1 : defaultSnoozeMinutes,
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  AppSettingsModel _defaultModel() {
    return const AppSettingsModel(
      id: settingsDocId,
      defaultAnnouncementLanguage: 'english',
      bilingualAnnouncements: false,
      alarmStrengthProfile: 'strong',
      vibrationEnabled: true,
      repeatIntervalSeconds: 20,
      maxAlarmDurationMinutes: 5,
      defaultSnoozeMinutes: 10,
      createdAt: null,
      updatedAt: null,
    );
  }

  String _normalizeAlarmStrength(String value) {
    switch (value.trim().toLowerCase()) {
      case 'normal':
      case 'strong':
      case 'very_strong':
        return value.trim().toLowerCase();
      default:
        return 'strong';
    }
  }
}
