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
  }) async {
    final model = ScheduleEntryModel(
      id: '',
      medicineId: medicineId,
      timeOfDay: timeOfDay,
      repeatType: repeatType,
      daysOfWeek: daysOfWeek,
      isEnabled: true,
      createdAt: null,
      updatedAt: null,
    );

    await scheduleCollection.add(model.toMap());
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
}
