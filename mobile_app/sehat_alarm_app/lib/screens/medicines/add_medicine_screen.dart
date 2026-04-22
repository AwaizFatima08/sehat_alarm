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

  final MedicineService _medicineService = MedicineService();

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _doseLabelController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _medicineService.addMedicine(
        name: _nameController.text,
        doseLabel: _doseLabelController.text,
        instructions: _instructionsController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicine added successfully')),
      );

      Navigator.pop(context);
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                textInputAction: TextInputAction.done,
                maxLines: 3,
                decoration: _inputDecoration('Instructions (Optional)'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveMedicine,
                  child: _isSaving
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: CircularProgressIndicator(),
                        )
                      : const Text('Save Medicine'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
