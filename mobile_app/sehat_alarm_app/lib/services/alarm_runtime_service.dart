import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:sehat_alarm_app/models/app_settings_model.dart';
import 'package:sehat_alarm_app/models/medicine_model.dart';
import 'package:sehat_alarm_app/services/app_settings_service.dart';

class AlarmRuntimeService {
  AlarmRuntimeService._();

  static final AlarmRuntimeService instance = AlarmRuntimeService._();

  final FlutterTts _tts = FlutterTts();
  final AppSettingsService _appSettingsService = AppSettingsService();

  Timer? _repeatTimer;
  Timer? _autoStopTimer;

  bool _active = false;
  bool _initialized = false;

  bool get isActive => _active;

  Future<void> initialize() async {
    if (_initialized) return;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(false);

    _initialized = true;
  }

  Future<void> startAlarmLoop({
    required MedicineModel? medicine,
    required DateTime? scheduledAt,
  }) async {
    await initialize();
    await stopAlarmLoop();

    final settings = await _safeGetSettings();
    final profile = _resolvedProfile(settings.alarmStrengthProfile);

    _active = true;

    await _speakAlarmMessage(
      medicine: medicine,
      scheduledAt: scheduledAt,
      isFirstCycle: true,
      profile: profile,
    );

    _repeatTimer = Timer.periodic(
      Duration(seconds: settings.repeatIntervalSeconds),
      (_) async {
        if (!_active) return;

        await _speakAlarmMessage(
          medicine: medicine,
          scheduledAt: scheduledAt,
          isFirstCycle: false,
          profile: profile,
        );
      },
    );

    _autoStopTimer = Timer(
      Duration(minutes: settings.maxAlarmDurationMinutes),
      () async {
        if (!_active) return;
        await stopAlarmLoop();
      },
    );
  }

  Future<void> stopAlarmLoop() async {
    _active = false;

    _repeatTimer?.cancel();
    _repeatTimer = null;

    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    try {
      await _tts.stop();
    } catch (_) {
      // Ignore TTS stop errors for resilience.
    }
  }

  Future<void> _speakAlarmMessage({
    required MedicineModel? medicine,
    required DateTime? scheduledAt,
    required bool isFirstCycle,
    required _AlarmSpeechProfile profile,
  }) async {
    final medicineName = (medicine?.name ?? 'your medicine').trim();
    final doseLabel = (medicine?.doseLabel ?? '').trim();
    final instructions = (medicine?.instructions ?? '').trim();

    final timeTextEnglish = scheduledAt == null
        ? 'now'
        : _formatTimeForSpeechEnglish(scheduledAt);

    final timeTextUrdu = scheduledAt == null
        ? 'ابھی'
        : _formatTimeForSpeechUrdu(scheduledAt);

    final settings = await _safeGetSettings();

    final medicineLanguage =
        (medicine?.announcementLanguage ?? '').trim().toLowerCase();
    final appLanguage =
        settings.defaultAnnouncementLanguage.trim().toLowerCase();

    final effectiveLanguage = medicineLanguage.isNotEmpty
        ? medicineLanguage
        : (appLanguage.isNotEmpty ? appLanguage : 'english');

    final bilingual =
        medicine?.announcementBilingual ?? settings.bilingualAnnouncements;

    final englishMessage = _buildEnglishMessage(
      medicineName: medicineName,
      doseLabel: doseLabel,
      instructions: instructions,
      timeText: timeTextEnglish,
      isFirstCycle: isFirstCycle,
      profile: profile,
    );

    final urduMessage = _buildUrduMessage(
      medicineName: medicineName,
      doseLabel: doseLabel,
      instructions: instructions,
      timeText: timeTextUrdu,
      isFirstCycle: isFirstCycle,
      profile: profile,
    );

    try {
      if (bilingual) {
        await _speakBilingual(
          englishMessage: englishMessage,
          urduMessage: urduMessage,
          primaryLanguage: effectiveLanguage,
          profile: profile,
        );
        return;
      }

      if (effectiveLanguage == 'urdu') {
        final urduSuccess = await _trySpeakInLanguage(
          languageCode: 'ur-PK',
          text: urduMessage,
          speechRate: profile.urduSpeechRate,
          volume: profile.volume,
          pitch: profile.pitch,
        );

        if (!urduSuccess && _active) {
          await _trySpeakInLanguage(
            languageCode: 'en-US',
            text: englishMessage,
            speechRate: profile.englishSpeechRate,
            volume: profile.volume,
            pitch: profile.pitch,
          );
        }
        return;
      }

      await _trySpeakInLanguage(
        languageCode: 'en-US',
        text: englishMessage,
        speechRate: profile.englishSpeechRate,
        volume: profile.volume,
        pitch: profile.pitch,
      );
    } catch (_) {
      // TTS failures should not crash alarm flow.
    }
  }

  Future<void> _speakBilingual({
    required String englishMessage,
    required String urduMessage,
    required String primaryLanguage,
    required _AlarmSpeechProfile profile,
  }) async {
    if (primaryLanguage == 'urdu') {
      final urduSuccess = await _trySpeakInLanguage(
        languageCode: 'ur-PK',
        text: urduMessage,
        speechRate: profile.urduSpeechRate,
        volume: profile.volume,
        pitch: profile.pitch,
      );

      if (urduSuccess && _active) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }

      if (_active) {
        await _trySpeakInLanguage(
          languageCode: 'en-US',
          text: englishMessage,
          speechRate: profile.englishSpeechRate,
          volume: profile.volume,
          pitch: profile.pitch,
        );
      }
      return;
    }

    await _trySpeakInLanguage(
      languageCode: 'en-US',
      text: englishMessage,
      speechRate: profile.englishSpeechRate,
      volume: profile.volume,
      pitch: profile.pitch,
    );

    if (_active) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }

    if (_active) {
      await _trySpeakInLanguage(
        languageCode: 'ur-PK',
        text: urduMessage,
        speechRate: profile.urduSpeechRate,
        volume: profile.volume,
        pitch: profile.pitch,
      );
    }
  }

  Future<bool> _trySpeakInLanguage({
    required String languageCode,
    required String text,
    required double speechRate,
    required double volume,
    required double pitch,
  }) async {
    if (!_active) return false;

    try {
      await _tts.setLanguage(languageCode);
      await _tts.setSpeechRate(speechRate);
      await _tts.setVolume(volume);
      await _tts.setPitch(pitch);
      await _tts.speak(text);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<AppSettingsModel> _safeGetSettings() async {
    try {
      return await _appSettingsService.getSettings();
    } catch (_) {
      return const AppSettingsModel(
        id: 'global',
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
  }

  _AlarmSpeechProfile _resolvedProfile(String profile) {
    switch (profile.trim().toLowerCase()) {
      case 'normal':
        return const _AlarmSpeechProfile(
          englishSpeechRate: 0.47,
          urduSpeechRate: 0.44,
          volume: 0.90,
          pitch: 1.0,
        );
      case 'very_strong':
        return const _AlarmSpeechProfile(
          englishSpeechRate: 0.40,
          urduSpeechRate: 0.38,
          volume: 1.0,
          pitch: 1.02,
        );
      case 'strong':
      default:
        return const _AlarmSpeechProfile(
          englishSpeechRate: 0.44,
          urduSpeechRate: 0.41,
          volume: 1.0,
          pitch: 1.0,
        );
    }
  }

  String _buildEnglishMessage({
    required String medicineName,
    required String doseLabel,
    required String instructions,
    required String timeText,
    required bool isFirstCycle,
    required _AlarmSpeechProfile profile,
  }) {
    final base = StringBuffer();

    if (isFirstCycle) {
      base.write('Medicine reminder. ');
    } else {
      base.write('Reminder again. ');
    }

    base.write('It is time to take $medicineName');

    if (doseLabel.isNotEmpty) {
      base.write(', dose $doseLabel');
    }

    base.write('. Scheduled for $timeText. ');

    if (instructions.isNotEmpty) {
      base.write('Instructions: $instructions. ');
    }

    if (profile.volume >= 1.0) {
      base.write('Please respond now. ');
    }

    base.write('Please choose taken, snooze, or skip.');

    return base.toString();
  }

  String _buildUrduMessage({
    required String medicineName,
    required String doseLabel,
    required String instructions,
    required String timeText,
    required bool isFirstCycle,
    required _AlarmSpeechProfile profile,
  }) {
    final base = StringBuffer();

    if (isFirstCycle) {
      base.write('دوائی یاددہانی۔ ');
    } else {
      base.write('دوبارہ یاددہانی۔ ');
    }

    base.write('$medicineName لینے کا وقت ہو گیا ہے');

    if (doseLabel.isNotEmpty) {
      base.write('۔ خوراک $doseLabel');
    }

    base.write('۔ وقت $timeText ہے۔ ');

    if (instructions.isNotEmpty) {
      base.write('ہدایت: $instructions۔ ');
    }

    if (profile.volume >= 1.0) {
      base.write('براہِ کرم ابھی جواب دیں۔ ');
    }

    base.write('براہِ کرم Taken، Snooze، یا Skip منتخب کریں۔');

    return base.toString();
  }

  String _formatTimeForSpeechEnglish(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;

    final hour12 = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;

    final amPm = hour >= 12 ? 'PM' : 'AM';
    final minuteText = minute == 0 ? "o'clock" : minute.toString();

    return '$hour12 $minuteText $amPm';
  }

  String _formatTimeForSpeechUrdu(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;

    final hour12 = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;

    final amPm = hour >= 12 ? 'بجے شام' : 'بجے صبح';

    if (minute == 0) {
      return '$hour12 $amPm';
    }

    return '$hour12 بج کر $minute منٹ $amPm';
  }
}

class _AlarmSpeechProfile {
  final double englishSpeechRate;
  final double urduSpeechRate;
  final double volume;
  final double pitch;

  const _AlarmSpeechProfile({
    required this.englishSpeechRate,
    required this.urduSpeechRate,
    required this.volume,
    required this.pitch,
  });
}
