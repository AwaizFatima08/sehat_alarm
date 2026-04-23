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
    final normalizedProfile = _normalizeAlarmStrength(alarmStrengthProfile);
    final resolvedRepeat = _resolvedRepeatInterval(
      normalizedProfile,
      repeatIntervalSeconds,
    );
    final resolvedDuration = _resolvedMaxDuration(
      normalizedProfile,
      maxAlarmDurationMinutes,
    );
    final resolvedSnooze = _resolvedDefaultSnooze(
      normalizedProfile,
      defaultSnoozeMinutes,
    );

    await _settingsCollection.doc(settingsDocId).set(
      {
        'alarm_strength_profile': normalizedProfile,
        'vibration_enabled': vibrationEnabled,
        'repeat_interval_seconds': resolvedRepeat,
        'max_alarm_duration_minutes': resolvedDuration,
        'default_snooze_minutes': resolvedSnooze,
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateSupportMode({
    required String supportMode,
  }) async {
    await _settingsCollection.doc(settingsDocId).set(
      {
        'support_mode': _normalizeSupportMode(supportMode),
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
      alarmStrengthProfile: 'standard',
      vibrationEnabled: true,
      repeatIntervalSeconds: 20,
      maxAlarmDurationMinutes: 5,
      defaultSnoozeMinutes: 10,
      supportMode: 'patient',
      createdAt: null,
      updatedAt: null,
    );
  }

  String _normalizeAlarmStrength(String value) {
    switch (value.trim().toLowerCase()) {
      case 'gentle':
      case 'standard':
      case 'strong':
        return value.trim().toLowerCase();
      case 'normal':
        return 'gentle';
      case 'very_strong':
        return 'strong';
      default:
        return 'standard';
    }
  }

  String _normalizeSupportMode(String value) {
    switch (value.trim().toLowerCase()) {
      case 'patient':
      case 'caregiver':
        return value.trim().toLowerCase();
      default:
        return 'patient';
    }
  }

  int _resolvedRepeatInterval(String profile, int requested) {
    final safeRequested = requested < 5 ? 5 : requested;

    switch (profile) {
      case 'gentle':
        return safeRequested < 30 ? 30 : safeRequested;
      case 'strong':
        return safeRequested > 15 ? 15 : safeRequested;
      case 'standard':
      default:
        return safeRequested;
    }
  }

  int _resolvedMaxDuration(String profile, int requested) {
    final safeRequested = requested < 1 ? 1 : requested;

    switch (profile) {
      case 'gentle':
        return safeRequested < 3 ? 3 : safeRequested;
      case 'strong':
        return safeRequested < 7 ? 7 : safeRequested;
      case 'standard':
      default:
        return safeRequested < 5 ? 5 : safeRequested;
    }
  }

  int _resolvedDefaultSnooze(String profile, int requested) {
    final safeRequested = requested < 1 ? 1 : requested;

    switch (profile) {
      case 'gentle':
        return safeRequested < 15 ? 15 : safeRequested;
      case 'strong':
        return safeRequested > 5 ? 5 : safeRequested;
      case 'standard':
      default:
        return safeRequested;
    }
  }
}
