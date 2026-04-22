import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleEntryModel {
  final String id;
  final String medicineId;
  final String timeOfDay;
  final String repeatType;
  final List<String> daysOfWeek;
  final bool isEnabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ScheduleEntryModel({
    required this.id,
    required this.medicineId,
    required this.timeOfDay,
    required this.repeatType,
    required this.daysOfWeek,
    required this.isEnabled,
    this.createdAt,
    this.updatedAt,
  });

  factory ScheduleEntryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return ScheduleEntryModel(
      id: doc.id,
      medicineId: data['medicine_id'] ?? '',
      timeOfDay: data['time_of_day'] ?? '',
      repeatType: data['repeat_type'] ?? 'daily',
      daysOfWeek: List<String>.from(data['days_of_week'] ?? []),
      isEnabled: data['is_enabled'] ?? true,
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicine_id': medicineId,
      'time_of_day': timeOfDay,
      'repeat_type': repeatType,
      'days_of_week': daysOfWeek,
      'is_enabled': isEnabled,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}
