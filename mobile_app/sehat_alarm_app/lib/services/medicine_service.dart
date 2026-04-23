import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sehat_alarm_app/core/constants/firestore_constants.dart';
import 'package:sehat_alarm_app/models/medicine_model.dart';

class MedicineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _medicineCollection =>
      _firestore.collection(FirestoreConstants.medicineMaster);

  CollectionReference<Map<String, dynamic>> get _scheduleCollection =>
      _firestore.collection(FirestoreConstants.scheduleEntries);

  Stream<List<MedicineModel>> getMedicines() {
    return _medicineCollection
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(MedicineModel.fromFirestore).toList();
    });
  }

  Stream<List<MedicineModel>> getActiveMedicines() {
    return _medicineCollection
        .where('is_active', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(MedicineModel.fromFirestore).toList();
    });
  }

  Future<void> addMedicine({
    required String name,
    required String doseLabel,
    required String instructions,
    String? dosageForm,
    double? quantityPerDose,
    String? quantityUnit,
    String? defaultFrequencyLabel,
    String? regimenNote,
    String? announcementLanguage,
    bool? announcementBilingual,
  }) async {
    final model = MedicineModel(
      id: '',
      name: name.trim(),
      doseLabel: doseLabel.trim(),
      instructions: instructions.trim(),
      dosageForm: _normalizeString(dosageForm),
      quantityPerDose: quantityPerDose,
      quantityUnit: _normalizeString(quantityUnit),
      defaultFrequencyLabel: _normalizeString(defaultFrequencyLabel),
      regimenNote: _normalizeString(regimenNote),
      announcementLanguage: announcementLanguage ?? 'english',
      announcementBilingual: announcementBilingual ?? false,
      startDate: null,
      endDate: null,
      isActive: true,
      languageMode: announcementLanguage ?? 'english',
      reminderSound: 'default',
      notes: '',
      createdAt: null,
      updatedAt: null,
    );

    await _medicineCollection.add(model.toMap());
  }

  Future<void> updateMedicine({
    required String medicineId,
    required String name,
    required String doseLabel,
    required String instructions,
    String? dosageForm,
    double? quantityPerDose,
    String? quantityUnit,
    String? defaultFrequencyLabel,
    String? regimenNote,
    String? announcementLanguage,
    bool? announcementBilingual,
  }) async {
    await _medicineCollection.doc(medicineId).update({
      'name': name.trim(),
      'dose_label': doseLabel.trim(),
      'instructions': instructions.trim(),
      'dosage_form': _normalizeString(dosageForm),
      'quantity_per_dose': quantityPerDose,
      'quantity_unit': _normalizeString(quantityUnit),
      'default_frequency_label': _normalizeString(defaultFrequencyLabel),
      'regimen_note': _normalizeString(regimenNote),
      'announcement_language': announcementLanguage ?? 'english',
      'announcement_bilingual': announcementBilingual ?? false,
      'language_mode': announcementLanguage ?? 'english',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMedicineStatus({
    required String medicineId,
    required bool isActive,
  }) async {
    await _medicineCollection.doc(medicineId).update({
      'is_active': isActive,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMedicine(String medicineId) async {
    await _medicineCollection.doc(medicineId).delete();
  }

  Future<MedicineModel?> getMedicineById(String medicineId) async {
    final doc = await _medicineCollection.doc(medicineId).get();
    if (!doc.exists) return null;
    return MedicineModel.fromFirestore(doc);
  }

  Future<Map<String, MedicineModel>> getMedicinesByIds(
    Iterable<String> medicineIds,
  ) async {
    final ids = medicineIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return {};

    final Map<String, MedicineModel> result = {};

    for (int i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();

      final snapshot = await _medicineCollection
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        result[doc.id] = MedicineModel.fromFirestore(doc);
      }
    }

    return result;
  }

  Future<bool> hasSchedulesForMedicine(String medicineId) async {
    final snapshot = await _scheduleCollection
        .where('medicine_id', isEqualTo: medicineId)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<int> countSchedulesForMedicine(String medicineId) async {
    final snapshot = await _scheduleCollection
        .where('medicine_id', isEqualTo: medicineId)
        .get();

    return snapshot.docs.length;
  }

  Future<int> countEnabledSchedulesForMedicine(String medicineId) async {
    final snapshot = await _scheduleCollection
        .where('medicine_id', isEqualTo: medicineId)
        .where('is_enabled', isEqualTo: true)
        .get();

    return snapshot.docs.length;
  }

  Future<MedicineDeleteCheckResult> evaluateDeleteEligibility(
    String medicineId,
  ) async {
    final totalSchedules = await countSchedulesForMedicine(medicineId);
    final enabledSchedules = await countEnabledSchedulesForMedicine(medicineId);

    return MedicineDeleteCheckResult(
      canDelete: totalSchedules == 0,
      totalSchedules: totalSchedules,
      enabledSchedules: enabledSchedules,
    );
  }

  Future<MedicineDuplicateCheckResult> checkDuplicateMedicineName({
    required String name,
    String? excludeMedicineId,
  }) async {
    final normalizedInput = _normalizeMedicineName(name);
    if (normalizedInput.isEmpty) {
      return const MedicineDuplicateCheckResult(
        isDuplicate: false,
        matchedMedicines: [],
      );
    }

    final snapshot = await _medicineCollection.get();

    final matches = snapshot.docs
        .map(MedicineModel.fromFirestore)
        .where((medicine) {
          if (excludeMedicineId != null && medicine.id == excludeMedicineId) {
            return false;
          }
          return _normalizeMedicineName(medicine.name) == normalizedInput;
        })
        .toList();

    return MedicineDuplicateCheckResult(
      isDuplicate: matches.isNotEmpty,
      matchedMedicines: matches,
    );
  }

  String? _normalizeString(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _normalizeMedicineName(String value) {
    final lowered = value.trim().toLowerCase();
    return lowered.replaceAll(RegExp(r'\s+'), ' ');
  }
}

class MedicineDuplicateCheckResult {
  final bool isDuplicate;
  final List<MedicineModel> matchedMedicines;

  const MedicineDuplicateCheckResult({
    required this.isDuplicate,
    required this.matchedMedicines,
  });
}

class MedicineDeleteCheckResult {
  final bool canDelete;
  final int totalSchedules;
  final int enabledSchedules;

  const MedicineDeleteCheckResult({
    required this.canDelete,
    required this.totalSchedules,
    required this.enabledSchedules,
  });
}
