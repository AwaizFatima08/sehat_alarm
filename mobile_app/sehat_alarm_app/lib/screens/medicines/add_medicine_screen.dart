import 'package:flutter/material.dart';
import 'package:sehat_alarm_app/services/medicine_service.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({super.key});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _doseLabelController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _quantityController = TextEditingController();
  final _regimenNoteController = TextEditingController();

  final MedicineService _medicineService = MedicineService();

  bool _isSaving = false;

  String _selectedDosageForm = 'tablet';
  String _selectedQuantityUnit = 'tablet';
  String _selectedFrequencyLabel = 'once_daily';
  String _selectedAnnouncementLanguage = 'english';
  bool _announcementBilingual = false;

  final List<DropdownMenuItem<String>> _dosageFormItems = const [
    DropdownMenuItem(value: 'tablet', child: Text('Tablet')),
    DropdownMenuItem(value: 'capsule', child: Text('Capsule')),
    DropdownMenuItem(value: 'syrup', child: Text('Syrup')),
    DropdownMenuItem(value: 'drops', child: Text('Drops')),
    DropdownMenuItem(value: 'injection', child: Text('Injection')),
    DropdownMenuItem(value: 'other', child: Text('Other')),
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
    DropdownMenuItem(value: 'once_daily', child: Text('Once Daily')),
    DropdownMenuItem(value: 'twice_daily', child: Text('Twice Daily')),
    DropdownMenuItem(value: 'thrice_daily', child: Text('Thrice Daily')),
    DropdownMenuItem(value: 'custom', child: Text('Custom')),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _doseLabelController.dispose();
    _instructionsController.dispose();
    _quantityController.dispose();
    _regimenNoteController.dispose();
    super.dispose();
  }

  Future<void> _saveMedicine() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final stopwatch = Stopwatch()..start();

    setState(() {
      _isSaving = true;
    });

    try {
      final quantityText = _quantityController.text.trim();
      final quantityPerDose = quantityText.isEmpty
          ? null
          : double.tryParse(quantityText);

      await _medicineService.addMedicine(
        name: _nameController.text,
        doseLabel: _doseLabelController.text,
        instructions: _instructionsController.text,
        dosageForm: _selectedDosageForm,
        quantityPerDose: quantityPerDose,
        quantityUnit: _selectedQuantityUnit,
        defaultFrequencyLabel: _selectedFrequencyLabel,
        regimenNote: _regimenNoteController.text,
        announcementLanguage: _selectedAnnouncementLanguage,
        announcementBilingual: _announcementBilingual,
      );

      stopwatch.stop();
      debugPrint(
        'AddMedicineScreen._saveMedicine completed in '
        '${stopwatch.elapsedMilliseconds} ms',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine added successfully')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      stopwatch.stop();
      debugPrint(
        'AddMedicineScreen._saveMedicine failed after '
        '${stopwatch.elapsedMilliseconds} ms: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save medicine: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Medicine'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                  decoration: _inputDecoration('Medicine Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter medicine name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _doseLabelController,
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                  decoration: _inputDecoration('Dose Label'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter dose label';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _instructionsController,
                  textInputAction: TextInputAction.next,
                  enabled: !_isSaving,
                  maxLines: 3,
                  decoration: _inputDecoration('Instructions (Optional)'),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _sectionLabel('Regimen Basics'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDosageForm,
                  decoration: _inputDecoration('Dosage Form'),
                  items: _dosageFormItems,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedDosageForm = value;
                          });
                        },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        textInputAction: TextInputAction.next,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        enabled: !_isSaving,
                        decoration: _inputDecoration('Quantity Per Dose'),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;
                          if (double.tryParse(text) == null) {
                            return 'Enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedQuantityUnit,
                        decoration: _inputDecoration('Unit'),
                        items: _quantityUnitItems,
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedQuantityUnit = value;
                                });
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedFrequencyLabel,
                  decoration: _inputDecoration('Default Frequency'),
                  items: _frequencyItems,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedFrequencyLabel = value;
                          });
                        },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _regimenNoteController,
                  textInputAction: TextInputAction.done,
                  enabled: !_isSaving,
                  maxLines: 2,
                  decoration: _inputDecoration('Regimen Note (Optional)'),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _sectionLabel('Announcement Language'),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: 'english',
                      label: Text('English'),
                    ),
                    ButtonSegment<String>(
                      value: 'urdu',
                      label: Text('Urdu'),
                    ),
                  ],
                  selected: {_selectedAnnouncementLanguage},
                  onSelectionChanged: _isSaving
                      ? null
                      : (selection) {
                          setState(() {
                            _selectedAnnouncementLanguage = selection.first;
                          });
                        },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Bilingual Announcements',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Use both English and Urdu where device support allows.',
                  ),
                  value: _announcementBilingual,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _announcementBilingual = value;
                          });
                        },
                ),
                const SizedBox(height: 24),
                if (_isSaving)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Saving medicine. Please wait and do not go back.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveMedicine,
                    child: _isSaving
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('Saving... Please wait'),
                              ],
                            ),
                          )
                        : const Text('Save Medicine'),
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
