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
  }) async {
    final model = MedicineModel(
      id: '',
      name: name.trim(),
      doseLabel: doseLabel.trim(),
      instructions: instructions.trim(),
      startDate: null,
      endDate: null,
      isActive: true,
      languageMode: 'english',
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
}
