import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:sehat_alarm_app/core/constants/firestore_constants.dart';
import 'package:sehat_alarm_app/models/dose_event_model.dart';
import 'package:sehat_alarm_app/models/schedule_entry_model.dart';
import 'package:sehat_alarm_app/services/medicine_service.dart';

class DoseEventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MedicineService _medicineService = MedicineService();

  CollectionReference<Map<String, dynamic>> get _eventCollection =>
      _firestore.collection(FirestoreConstants.doseEventLog);

  Future<void> generateTodayEvents({
    required List<ScheduleEntryModel> schedules,
  }) async {
    final stopwatch = Stopwatch()..start();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final existingSnapshot = await _eventCollection
        .where(
          'scheduled_datetime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where(
          'scheduled_datetime',
          isLessThan: Timestamp.fromDate(endOfDay),
        )
        .get();

    final existingKeys = existingSnapshot.docs
        .map(DoseEventModel.fromFirestore)
        .map((event) {
          final ms = event.scheduledDateTime?.millisecondsSinceEpoch ?? 0;
          return '${event.scheduleId}_$ms';
        })
        .toSet();

    final medicineIds = schedules.map((s) => s.medicineId).toSet().toList();
    final medicineMap = await _medicineService.getMedicinesByIds(medicineIds);

    final batch = _firestore.batch();
    int addedCount = 0;

    for (final schedule in schedules) {
      if (!schedule.isEnabled) continue;
      if (!_shouldGenerateForToday(schedule, now)) continue;

      final scheduledDateTime =
          _buildScheduledDateTimeForToday(schedule.timeOfDay, now);
      if (scheduledDateTime == null) continue;

      final key = '${schedule.id}_${scheduledDateTime.millisecondsSinceEpoch}';
      if (existingKeys.contains(key)) continue;

      final medicine = medicineMap[schedule.medicineId];

      final medicineName = (medicine?.name ?? 'Medicine').trim();
      final doseLabel = (medicine?.doseLabel ?? '').trim();
      final instructions = (medicine?.instructions ?? '').trim();

      final quantityPerDose =
          schedule.quantityPerDose ?? medicine?.quantityPerDose;

      final quantityUnit =
          (schedule.quantityUnit ?? medicine?.quantityUnit ?? '').trim();

      final slotLabel = (schedule.slotLabel ?? '').trim();

      final announcementLanguage =
          (schedule.announcementLanguage ??
                  medicine?.announcementLanguage ??
                  'english')
              .trim();

      final event = DoseEventModel(
        id: '',
        medicineId: schedule.medicineId,
        scheduleId: schedule.id,
        scheduledDateTime: scheduledDateTime,
        status: 'pending',
        responseDateTime: null,
        snoozeUntil: null,
        remarks: '',
        medicineNameSnapshot: medicineName,
        doseLabelSnapshot: doseLabel,
        instructionsSnapshot: instructions,
        quantityPerDoseSnapshot: quantityPerDose,
        quantityUnitSnapshot: quantityUnit,
        slotLabelSnapshot: slotLabel,
        announcementLanguageSnapshot: announcementLanguage,
        alarmType: 'medicine',
        createdAt: null,
        updatedAt: null,
      );

      final docRef = _eventCollection.doc();
      batch.set(docRef, event.toMap());

      existingKeys.add(key);
      addedCount++;
    }

    if (addedCount > 0) {
      await batch.commit();
    }

    stopwatch.stop();
    debugPrint(
      'DoseEventService.generateTodayEvents scanned ${schedules.length} '
      'schedules, added $addedCount events in '
      '${stopwatch.elapsedMilliseconds} ms',
    );
  }

  Stream<List<DoseEventModel>> getTodayEvents() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _eventCollection
        .where(
          'scheduled_datetime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where(
          'scheduled_datetime',
          isLessThan: Timestamp.fromDate(endOfDay),
        )
        .orderBy('scheduled_datetime')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(DoseEventModel.fromFirestore).toList();
    });
  }

  Future<List<DoseEventModel>> fetchTodayEventsOnce() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _eventCollection
        .where(
          'scheduled_datetime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where(
          'scheduled_datetime',
          isLessThan: Timestamp.fromDate(endOfDay),
        )
        .orderBy('scheduled_datetime')
        .get();

    return snapshot.docs.map(DoseEventModel.fromFirestore).toList();
  }

  Future<DoseEventModel?> getEventById(String eventId) async {
    final doc = await _eventCollection.doc(eventId).get();
    if (!doc.exists) return null;
    return DoseEventModel.fromFirestore(doc);
  }

  Future<void> markEventAsRinging({
    required String eventId,
  }) async {
    await _eventCollection.doc(eventId).update({
      'status': 'ringing',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStatus({
    required String eventId,
    required String status,
  }) async {
    await _eventCollection.doc(eventId).update({
      'status': status,
      'response_datetime': FieldValue.serverTimestamp(),
      'snooze_until': null,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> snoozeEvent({
    required String eventId,
    required int minutes,
  }) async {
    final snoozeUntil = DateTime.now().add(Duration(minutes: minutes));

    await _eventCollection.doc(eventId).update({
      'status': 'snoozed',
      'snooze_until': Timestamp.fromDate(snoozeUntil),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<int> markTodayMissedEvents({
    int graceMinutes = 30,
  }) async {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(minutes: graceMinutes));

    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _eventCollection
        .where(
          'scheduled_datetime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where(
          'scheduled_datetime',
          isLessThan: Timestamp.fromDate(endOfDay),
        )
        .get();

    final candidates = snapshot.docs
        .map(DoseEventModel.fromFirestore)
        .where((event) {
          if (!event.isAlarmActive) return false;

          final effectiveTime = event.snoozeUntil ?? event.scheduledDateTime;
          if (effectiveTime == null) return false;

          return effectiveTime.isBefore(cutoff);
        })
        .toList();

    if (candidates.isEmpty) return 0;

    final batch = _firestore.batch();

    for (final event in candidates) {
      batch.update(_eventCollection.doc(event.id), {
        'status': 'missed',
        'response_datetime': FieldValue.serverTimestamp(),
        'snooze_until': null,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return candidates.length;
  }

  Future<List<DoseEventModel>> refreshTodayEventStates({
    int graceMinutes = 30,
  }) async {
    await markTodayMissedEvents(graceMinutes: graceMinutes);
    return fetchTodayEventsOnce();
  }

  bool _shouldGenerateForToday(
    ScheduleEntryModel schedule,
    DateTime today,
  ) {
    if (schedule.repeatType == 'daily') return true;

    if (schedule.repeatType == 'selected_days') {
      final todayCode = _weekdayCode(today.weekday);
      return schedule.daysOfWeek.contains(todayCode);
    }

    return false;
  }

  String _weekdayCode(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
        return 'sun';
      default:
        return 'mon';
    }
  }

  DateTime? _buildScheduledDateTimeForToday(String timeOfDay, DateTime today) {
    final parts = timeOfDay.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return DateTime(today.year, today.month, today.day, hour, minute);
  }
}
