import 'package:cloud_firestore/cloud_firestore.dart';

class MedicineModel {
  final String id;
  final String name;
  final String doseLabel;
  final String instructions;

  final String? dosageForm;
  final double? quantityPerDose;
  final String? quantityUnit;
  final String? defaultFrequencyLabel;
  final String? regimenNote;
  final String? announcementLanguage;
  final bool? announcementBilingual;

  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final String languageMode;
  final String reminderSound;
  final String notes;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  MedicineModel({
    required this.id,
    required this.name,
    required this.doseLabel,
    required this.instructions,
    this.dosageForm,
    this.quantityPerDose,
    this.quantityUnit,
    this.defaultFrequencyLabel,
    this.regimenNote,
    this.announcementLanguage,
    this.announcementBilingual,
    this.startDate,
    this.endDate,
    required this.isActive,
    required this.languageMode,
    required this.reminderSound,
    required this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory MedicineModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return MedicineModel(
      id: doc.id,
      name: data['name'] ?? '',
      doseLabel: data['dose_label'] ?? '',
      instructions: data['instructions'] ?? '',
      dosageForm: data['dosage_form'],
      quantityPerDose: (data['quantity_per_dose'] as num?)?.toDouble(),
      quantityUnit: data['quantity_unit'],
      defaultFrequencyLabel: data['default_frequency_label'],
      regimenNote: data['regimen_note'],
      announcementLanguage: data['announcement_language'] ?? 'english',
      announcementBilingual: data['announcement_bilingual'] ?? false,
      startDate: (data['start_date'] as Timestamp?)?.toDate(),
      endDate: (data['end_date'] as Timestamp?)?.toDate(),
      isActive: data['is_active'] ?? true,
      languageMode: data['language_mode'] ?? 'english',
      reminderSound: data['reminder_sound'] ?? 'default',
      notes: data['notes'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dose_label': doseLabel,
      'instructions': instructions,
      'dosage_form': dosageForm,
      'quantity_per_dose': quantityPerDose,
      'quantity_unit': quantityUnit,
      'default_frequency_label': defaultFrequencyLabel,
      'regimen_note': regimenNote,
      'announcement_language': announcementLanguage ?? 'english',
      'announcement_bilingual': announcementBilingual ?? false,
      'start_date': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'end_date': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'is_active': isActive,
      'language_mode': languageMode,
      'reminder_sound': reminderSound,
      'notes': notes,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}
