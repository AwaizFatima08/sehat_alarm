import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sehat_alarm_app/core/constants/firestore_constants.dart';
import 'package:sehat_alarm_app/models/dose_event_model.dart';
import 'package:sehat_alarm_app/models/schedule_entry_model.dart';

class DoseEventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _eventCollection =>
      _firestore.collection(FirestoreConstants.doseEventLog);

  Future<void> generateTodayEvents({
    required List<ScheduleEntryModel> schedules,
  }) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    for (final schedule in schedules) {
      if (!schedule.isEnabled) continue;
      if (!_shouldGenerateForToday(schedule, now)) continue;

      final scheduledDateTime =
          _buildScheduledDateTimeForToday(schedule.timeOfDay, now);
      if (scheduledDateTime == null) continue;

      final existing = await _eventCollection
          .where('schedule_id', isEqualTo: schedule.id)
          .where(
            'scheduled_datetime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where(
            'scheduled_datetime',
            isLessThan: Timestamp.fromDate(endOfDay),
          )
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) continue;

      final event = DoseEventModel(
        id: '',
        medicineId: schedule.medicineId,
        scheduleId: schedule.id,
        scheduledDateTime: scheduledDateTime,
        status: 'pending',
        responseDateTime: null,
        snoozeUntil: null,
        remarks: '',
        createdAt: null,
        updatedAt: null,
      );

      await _eventCollection.add(event.toMap());
    }
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
    int minutes = 10,
  }) async {
    final snoozeUntil = DateTime.now().add(Duration(minutes: minutes));

    await _eventCollection.doc(eventId).update({
      'status': 'snoozed',
      'snooze_until': Timestamp.fromDate(snoozeUntil),
      'updated_at': FieldValue.serverTimestamp(),
    });
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
