import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:sehat_alarm_app/models/medicine_model.dart';

class AlarmRuntimeService {
  AlarmRuntimeService._();

  static final AlarmRuntimeService instance = AlarmRuntimeService._();

  final FlutterTts _tts = FlutterTts();

  Timer? _repeatTimer;
  bool _active = false;

  bool get isActive => _active;

  Future<void> initialize() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(false);
  }

  Future<void> startAlarmLoop({
    required MedicineModel? medicine,
    required DateTime? scheduledAt,
  }) async {
    await stopAlarmLoop();

    _active = true;

    await _speakAlarmMessage(
      medicine: medicine,
      scheduledAt: scheduledAt,
      isFirstCycle: true,
    );

    _repeatTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!_active) return;

      await _speakAlarmMessage(
        medicine: medicine,
        scheduledAt: scheduledAt,
        isFirstCycle: false,
      );
    });
  }

  Future<void> stopAlarmLoop() async {
    _active = false;
    _repeatTimer?.cancel();
    _repeatTimer = null;

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
  }) async {
    final medicineName = (medicine?.name ?? 'your medicine').trim();
    final doseLabel = (medicine?.doseLabel ?? '').trim();
    final instructions = (medicine?.instructions ?? '').trim();

    final timeText = scheduledAt == null
        ? 'now'
        : _formatTimeForSpeech(scheduledAt);

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

    base.write('Please choose taken, snooze, or skip.');

    try {
      await _tts.speak(base.toString());
    } catch (_) {
      // TTS failures should not crash alarm flow.
    }
  }

  String _formatTimeForSpeech(DateTime dateTime) {
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
}
