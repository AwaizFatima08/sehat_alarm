import 'package:flutter/material.dart';
import 'package:sehat_alarm_app/models/medicine_model.dart';
import 'package:sehat_alarm_app/services/medicine_service.dart';

class EditMedicineScreen extends StatefulWidget {
  final MedicineModel medicine;

  const EditMedicineScreen({
    super.key,
    required this.medicine,
  });

  @override
  State<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final MedicineService _medicineService = MedicineService();

  late final TextEditingController _nameController;
  late final TextEditingController _doseLabelController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _quantityController;
  late final TextEditingController _regimenNoteController;

  bool _isSaving = false;

  String _dosageForm = 'tablet';
  String _quantityUnit = 'tablet';
  String _defaultFrequencyLabel = 'once_daily';
  String _announcementLanguage = 'english';
  bool _announcementBilingual = false;

  final List<DropdownMenuItem<String>> _dosageFormItems = const [
    DropdownMenuItem(value: 'tablet', child: Text('Tablet')),
    DropdownMenuItem(value: 'capsule', child: Text('Capsule')),
    DropdownMenuItem(value: 'syrup', child: Text('Syrup')),
    DropdownMenuItem(value: 'drops', child: Text('Drops')),
    DropdownMenuItem(value: 'injection', child: Text('Injection')),
  ];

  final List<DropdownMenuItem<String>> _quantityUnitItems = const [
    DropdownMenuItem(value: 'tablet', child: Text('Tablet')),
    DropdownMenuItem(value: 'capsule', child: Text('Capsule')),
    DropdownMenuItem(value: 'ml', child: Text('mL')),
    DropdownMenuItem(value: 'drops', child: Text('Drops')),
    DropdownMenuItem(value: 'puff', child: Text('Puff')),
    DropdownMenuItem(value: 'unit', child: Text('Unit')),
  ];

  final List<DropdownMenuItem<String>> _frequencyItems = const [
    DropdownMenuItem(value: 'once_daily', child: Text('Once daily')),
    DropdownMenuItem(value: 'twice_daily', child: Text('Twice daily')),
    DropdownMenuItem(value: 'thrice_daily', child: Text('Thrice daily')),
    DropdownMenuItem(value: 'custom', child: Text('Custom')),
  ];

  final List<DropdownMenuItem<String>> _languageItems = const [
    DropdownMenuItem(value: 'english', child: Text('English')),
    DropdownMenuItem(value: 'urdu', child: Text('Urdu')),
  ];

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.medicine.name);
    _doseLabelController = TextEditingController(text: widget.medicine.doseLabel);
    _instructionsController =
        TextEditingController(text: widget.medicine.instructions);
    _quantityController = TextEditingController(
      text: widget.medicine.quantityPerDose?.toString() ?? '',
    );
    _regimenNoteController = TextEditingController(
      text: widget.medicine.regimenNote ?? '',
    );

    _dosageForm = _safeValue(
      widget.medicine.dosageForm,
      const ['tablet', 'capsule', 'syrup', 'drops', 'injection'],
      'tablet',
    );
    _quantityUnit = _safeValue(
      widget.medicine.quantityUnit,
      const ['tablet', 'capsule', 'ml', 'drops', 'puff', 'unit'],
      'tablet',
    );
    _defaultFrequencyLabel = _safeValue(
      widget.medicine.defaultFrequencyLabel,
      const ['once_daily', 'twice_daily', 'thrice_daily', 'custom'],
      'once_daily',
    );
    _announcementLanguage = _safeValue(
      widget.medicine.announcementLanguage,
      const ['english', 'urdu'],
      'english',
    );
    _announcementBilingual = widget.medicine.announcementBilingual ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseLabelController.dispose();
    _instructionsController.dispose();
    _quantityController.dispose();
    _regimenNoteController.dispose();
    super.dispose();
  }

  String _safeValue(String? value, List<String> allowed, String fallback) {
    final normalized = (value ?? '').trim().toLowerCase();
    return allowed.contains(normalized) ? normalized : fallback;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final quantityText = _quantityController.text.trim();
    final quantityPerDose =
        quantityText.isEmpty ? null : double.tryParse(quantityText);

    if (quantityText.isNotEmpty && quantityPerDose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity.')),
      );
      return;
    }

    final duplicateResult = await _medicineService.checkDuplicateMedicineName(
      name: _nameController.text,
      excludeMedicineId: widget.medicine.id,
    );

    if (!mounted) return;

    if (duplicateResult.isDuplicate) {
      final names = duplicateResult.matchedMedicines
          .map((e) => e.name)
          .toSet()
          .join(', ');

      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Possible duplicate medicine'),
          content: Text(
            'A medicine with a very similar name already exists:\n\n$names\n\n'
            'Do you want to continue saving anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Review'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    setState(() => _isSaving = true);

    try {
      await _medicineService.updateMedicine(
        medicineId: widget.medicine.id,
        name: _nameController.text.trim(),
        doseLabel: _doseLabelController.text.trim(),
        instructions: _instructionsController.text.trim(),
        dosageForm: _dosageForm,
        quantityPerDose: quantityPerDose,
        quantityUnit: _quantityUnit,
        defaultFrequencyLabel: _defaultFrequencyLabel,
        regimenNote: _regimenNoteController.text.trim(),
        announcementLanguage: _announcementLanguage,
        announcementBilingual: _announcementBilingual,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine updated successfully.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update medicine: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Medicine'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderPanel(
                  title: widget.medicine.name,
                  subtitle:
                      'Update medicine details safely. Historical dose events will remain unchanged.',
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isSaving,
                  decoration: _inputDecoration('Medicine Name'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Medicine name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _doseLabelController,
                  enabled: !_isSaving,
                  decoration: _inputDecoration('Dose Label'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _dosageForm,
                  decoration: _inputDecoration('Dosage Form'),
                  items: _dosageFormItems,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _dosageForm = value);
                        },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        enabled: !_isSaving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration('Quantity Per Dose'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _quantityUnit,
                        decoration: _inputDecoration('Unit'),
                        items: _quantityUnitItems,
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _quantityUnit = value);
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _defaultFrequencyLabel,
                  decoration: _inputDecoration('Default Frequency'),
                  items: _frequencyItems,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _defaultFrequencyLabel = value);
                        },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _announcementLanguage,
                  decoration: _inputDecoration('Announcement Language'),
                  items: _languageItems,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _announcementLanguage = value);
                        },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Bilingual Announcement',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Enable English + Urdu style announcements later where supported.',
                  ),
                  value: _announcementBilingual,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() => _announcementBilingual = value);
                        },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _instructionsController,
                  enabled: !_isSaving,
                  maxLines: 3,
                  decoration: _inputDecoration('Instructions'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _regimenNoteController,
                  enabled: !_isSaving,
                  maxLines: 2,
                  decoration: _inputDecoration('Regimen Note'),
                ),
                const SizedBox(height: 24),
                if (_isSaving)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Updating medicine. Please wait and do not go back.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      _isSaving ? 'Updating medicine...' : 'Update Medicine',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderPanel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeaderPanel({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
