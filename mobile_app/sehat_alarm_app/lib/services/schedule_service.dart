import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sehat_alarm_app/core/constants/firestore_constants.dart';
import 'package:sehat_alarm_app/models/schedule_entry_model.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get scheduleCollection =>
      _firestore.collection(FirestoreConstants.scheduleEntries);

  Stream<List<ScheduleEntryModel>> getSchedulesForMedicine(String medicineId) {
    return scheduleCollection
        .where('medicine_id', isEqualTo: medicineId)
        .orderBy('time_of_day')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ScheduleEntryModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> addSchedule({
    required String medicineId,
    required String timeOfDay,
    required String repeatType,
    required List<String> daysOfWeek,
    String? regimenGroupId,
    String? slotLabel,
    double? quantityPerDose,
    String? quantityUnit,
    String? announcementLanguage,
    int? sortOrder,
  }) async {
    final model = ScheduleEntryModel(
      id: '',
      medicineId: medicineId,
      timeOfDay: timeOfDay,
      repeatType: repeatType,
      daysOfWeek: daysOfWeek,
      regimenGroupId: regimenGroupId,
      slotLabel: slotLabel,
      quantityPerDose: quantityPerDose,
      quantityUnit: quantityUnit,
      announcementLanguage: announcementLanguage,
      sortOrder: sortOrder,
      isEnabled: true,
      createdAt: null,
      updatedAt: null,
    );

    await scheduleCollection.add(model.toMap());
  }

  Future<void> addSchedulesBatch({
    required List<ScheduleEntryModel> schedules,
  }) async {
    if (schedules.isEmpty) return;

    final batch = _firestore.batch();

    for (final schedule in schedules) {
      final docRef = scheduleCollection.doc();
      batch.set(docRef, schedule.toMap());
    }

    await batch.commit();
  }

  Future<void> updateScheduleStatus({
    required String scheduleId,
    required bool isEnabled,
  }) async {
    await scheduleCollection.doc(scheduleId).update({
      'is_enabled': isEnabled,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateScheduleEntry({
    required String scheduleId,
    required String timeOfDay,
    required String repeatType,
    required List<String> daysOfWeek,
    String? slotLabel,
    double? quantityPerDose,
    String? quantityUnit,
    String? announcementLanguage,
  }) async {
    await scheduleCollection.doc(scheduleId).update({
      'time_of_day': timeOfDay,
      'repeat_type': repeatType,
      'days_of_week': daysOfWeek,
      'slot_label': slotLabel,
      'quantity_per_dose': quantityPerDose,
      'quantity_unit': quantityUnit,
      'announcement_language': announcementLanguage,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteScheduleEntry(String scheduleId) async {
    await scheduleCollection.doc(scheduleId).delete();
  }

  Future<void> deleteRegimenGroup(String regimenGroupId) async {
    final snapshot = await scheduleCollection
        .where('regimen_group_id', isEqualTo: regimenGroupId)
        .get();

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<int> disableSchedulesForMedicine(String medicineId) async {
    final snapshot = await scheduleCollection
        .where('medicine_id', isEqualTo: medicineId)
        .where('is_enabled', isEqualTo: true)
        .get();

    if (snapshot.docs.isEmpty) return 0;

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'is_enabled': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    return snapshot.docs.length;
  }

  Future<int> countSchedulesForMedicine(String medicineId) async {
    final snapshot = await scheduleCollection
        .where('medicine_id', isEqualTo: medicineId)
        .get();

    return snapshot.docs.length;
  }

  Future<int> countEnabledSchedulesForMedicine(String medicineId) async {
    final snapshot = await scheduleCollection
        .where('medicine_id', isEqualTo: medicineId)
        .where('is_enabled', isEqualTo: true)
        .get();

    return snapshot.docs.length;
  }

  Future<bool> hasSchedulesForMedicine(String medicineId) async {
    final snapshot = await scheduleCollection
        .where('medicine_id', isEqualTo: medicineId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<bool> hasEnabledSchedulesForMedicine(String medicineId) async {
    final snapshot = await scheduleCollection
        .where('medicine_id', isEqualTo: medicineId)
        .where('is_enabled', isEqualTo: true)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<List<ScheduleEntryModel>> fetchEnabledSchedules() async {
    final snapshot = await scheduleCollection
        .where('is_enabled', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => ScheduleEntryModel.fromFirestore(doc))
        .toList();
  }

  Future<Map<String, ScheduleEntryModel>> getSchedulesByIds(
    Iterable<String> scheduleIds,
  ) async {
    final ids = scheduleIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};

    final Map<String, ScheduleEntryModel> result = {};

    for (int i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();

      final snapshot = await scheduleCollection
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        result[doc.id] = ScheduleEntryModel.fromFirestore(doc);
      }
    }

    return result;
  }
}
