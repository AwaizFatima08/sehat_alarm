import 'package:cloud_firestore/cloud_firestore.dart';

class DoseEventModel {
  final String id;
  final String medicineId;
  final String scheduleId;
  final DateTime? scheduledDateTime;
  final String status;
  final DateTime? responseDateTime;
  final DateTime? snoozeUntil;
  final String remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DoseEventModel({
    required this.id,
    required this.medicineId,
    required this.scheduleId,
    this.scheduledDateTime,
    required this.status,
    this.responseDateTime,
    this.snoozeUntil,
    required this.remarks,
    this.createdAt,
    this.updatedAt,
  });

  factory DoseEventModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return DoseEventModel(
      id: doc.id,
      medicineId: data['medicine_id'] ?? '',
      scheduleId: data['schedule_id'] ?? '',
      scheduledDateTime: (data['scheduled_datetime'] as Timestamp?)?.toDate(),
      status: data['status'] ?? 'pending',
      responseDateTime: (data['response_datetime'] as Timestamp?)?.toDate(),
      snoozeUntil: (data['snooze_until'] as Timestamp?)?.toDate(),
      remarks: data['remarks'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicine_id': medicineId,
      'schedule_id': scheduleId,
      'scheduled_datetime': scheduledDateTime != null
          ? Timestamp.fromDate(scheduledDateTime!)
          : null,
      'status': status,
      'response_datetime': responseDateTime != null
          ? Timestamp.fromDate(responseDateTime!)
          : null,
      'snooze_until': snoozeUntil != null
          ? Timestamp.fromDate(snoozeUntil!)
          : null,
      'remarks': remarks,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}
