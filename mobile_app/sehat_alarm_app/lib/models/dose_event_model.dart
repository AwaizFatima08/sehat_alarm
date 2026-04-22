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

  final String medicineNameSnapshot;
  final String doseLabelSnapshot;
  final String instructionsSnapshot;
  final double? quantityPerDoseSnapshot;
  final String quantityUnitSnapshot;
  final String slotLabelSnapshot;
  final String announcementLanguageSnapshot;
  final String alarmType;

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
    required this.medicineNameSnapshot,
    required this.doseLabelSnapshot,
    required this.instructionsSnapshot,
    this.quantityPerDoseSnapshot,
    required this.quantityUnitSnapshot,
    required this.slotLabelSnapshot,
    required this.announcementLanguageSnapshot,
    required this.alarmType,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActioned =>
      status == 'taken' || status == 'skipped' || status == 'missed';

  bool get isAlarmActive =>
      status == 'pending' || status == 'ringing' || status == 'snoozed';

  factory DoseEventModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return DoseEventModel(
      id: doc.id,
      medicineId: data['medicine_id'] ?? '',
      scheduleId: data['schedule_id'] ?? '',
      scheduledDateTime: (data['scheduled_datetime'] as Timestamp?)?.toDate(),
      status: _normalizedStatus(data['status']),
      responseDateTime: (data['response_datetime'] as Timestamp?)?.toDate(),
      snoozeUntil: (data['snooze_until'] as Timestamp?)?.toDate(),
      remarks: data['remarks'] ?? '',
      medicineNameSnapshot: data['medicine_name_snapshot'] ?? '',
      doseLabelSnapshot: data['dose_label_snapshot'] ?? '',
      instructionsSnapshot: data['instructions_snapshot'] ?? '',
      quantityPerDoseSnapshot:
          (data['quantity_per_dose_snapshot'] as num?)?.toDouble(),
      quantityUnitSnapshot: data['quantity_unit_snapshot'] ?? '',
      slotLabelSnapshot: data['slot_label_snapshot'] ?? '',
      announcementLanguageSnapshot:
          data['announcement_language_snapshot'] ?? '',
      alarmType: data['alarm_type'] ?? 'medicine',
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
      'status': _normalizedStatus(status),
      'response_datetime': responseDateTime != null
          ? Timestamp.fromDate(responseDateTime!)
          : null,
      'snooze_until': snoozeUntil != null
          ? Timestamp.fromDate(snoozeUntil!)
          : null,
      'remarks': remarks,
      'medicine_name_snapshot': medicineNameSnapshot,
      'dose_label_snapshot': doseLabelSnapshot,
      'instructions_snapshot': instructionsSnapshot,
      'quantity_per_dose_snapshot': quantityPerDoseSnapshot,
      'quantity_unit_snapshot': quantityUnitSnapshot,
      'slot_label_snapshot': slotLabelSnapshot,
      'announcement_language_snapshot': announcementLanguageSnapshot,
      'alarm_type': alarmType,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  DoseEventModel copyWith({
    String? id,
    String? medicineId,
    String? scheduleId,
    DateTime? scheduledDateTime,
    String? status,
    DateTime? responseDateTime,
    DateTime? snoozeUntil,
    String? remarks,
    String? medicineNameSnapshot,
    String? doseLabelSnapshot,
    String? instructionsSnapshot,
    double? quantityPerDoseSnapshot,
    String? quantityUnitSnapshot,
    String? slotLabelSnapshot,
    String? announcementLanguageSnapshot,
    String? alarmType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DoseEventModel(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      scheduleId: scheduleId ?? this.scheduleId,
      scheduledDateTime: scheduledDateTime ?? this.scheduledDateTime,
      status: status ?? this.status,
      responseDateTime: responseDateTime ?? this.responseDateTime,
      snoozeUntil: snoozeUntil ?? this.snoozeUntil,
      remarks: remarks ?? this.remarks,
      medicineNameSnapshot: medicineNameSnapshot ?? this.medicineNameSnapshot,
      doseLabelSnapshot: doseLabelSnapshot ?? this.doseLabelSnapshot,
      instructionsSnapshot: instructionsSnapshot ?? this.instructionsSnapshot,
      quantityPerDoseSnapshot:
          quantityPerDoseSnapshot ?? this.quantityPerDoseSnapshot,
      quantityUnitSnapshot: quantityUnitSnapshot ?? this.quantityUnitSnapshot,
      slotLabelSnapshot: slotLabelSnapshot ?? this.slotLabelSnapshot,
      announcementLanguageSnapshot:
          announcementLanguageSnapshot ?? this.announcementLanguageSnapshot,
      alarmType: alarmType ?? this.alarmType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _normalizedStatus(dynamic raw) {
    final value = (raw ?? 'pending').toString().trim().toLowerCase();

    switch (value) {
      case 'pending':
      case 'ringing':
      case 'snoozed':
      case 'taken':
      case 'skipped':
      case 'missed':
        return value;
      default:
        return 'pending';
    }
  }
}
