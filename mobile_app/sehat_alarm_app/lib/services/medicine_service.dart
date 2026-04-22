import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sehat_alarm_app/core/constants/firestore_constants.dart';
import 'package:sehat_alarm_app/models/medicine_model.dart';

class MedicineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _medicineCollection =>
      _firestore.collection(FirestoreConstants.medicineMaster);

  Stream<List<MedicineModel>> getMedicines() {
    return _medicineCollection
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

  Future<void> updateMedicineStatus({
    required String medicineId,
    required bool isActive,
  }) async {
    await _medicineCollection.doc(medicineId).update({
      'is_active': isActive,
      'updated_at': FieldValue.serverTimestamp(),
    });
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

  String? _normalizeString(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
