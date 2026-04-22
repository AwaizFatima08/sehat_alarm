import 'package:flutter/material.dart';
import 'package:sehat_alarm_app/models/medicine_model.dart';
import 'package:sehat_alarm_app/models/schedule_entry_model.dart';
import 'package:sehat_alarm_app/services/medicine_service.dart';
import 'package:sehat_alarm_app/services/schedule_service.dart';

class AddScheduleScreen extends StatefulWidget {
  final String medicineId;
  final String medicineName;
  final ScheduleEntryModel? existingSchedule;

  const AddScheduleScreen({
    super.key,
    required this.medicineId,
    required this.medicineName,
    this.existingSchedule,
  });

  bool get isEditMode => existingSchedule != null;

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  final MedicineService _medicineService = MedicineService();

  MedicineModel? _medicine;
  bool _loadingMedicine = true;
  bool _isSaving = false;

  TimeOfDay? _selectedTime;
  String _repeatType = 'daily';

  String _slotLabel = 'custom';
  final TextEditingController _quantityController = TextEditingController();
  String _selectedQuantityUnit = 'tablet';
  String _selectedAnnouncementLanguage = 'english';
  bool _isEnabled = true;

  String _regimenMode = 'once_daily';

  final Map<String, bool> _days = {
    'mon': false,
    'tue': false,
    'wed': false,
    'thu': false,
    'fri': false,
    'sat': false,
    'sun': false,
  };

  final List<DropdownMenuItem<String>> _slotItems = const [
    DropdownMenuItem(value: 'morning', child: Text('Morning')),
    DropdownMenuItem(value: 'afternoon', child: Text('Afternoon')),
    DropdownMenuItem(value: 'night', child: Text('Night')),
    DropdownMenuItem(value: 'custom', child: Text('Custom')),
  ];

  final List<DropdownMenuItem<String>> _quantityUnitItems = const [
    DropdownMenuItem(value: 'tablet', child: Text('Tablet')),
    DropdownMenuItem(value: 'capsule', child: Text('Capsule')),
    DropdownMenuItem(value: 'ml', child: Text('mL')),
    DropdownMenuItem(value: 'drops', child: Text('Drops')),
    DropdownMenuItem(value: 'puff', child: Text('Puff')),
    DropdownMenuItem(value: 'unit', child: Text('Unit')),
  ];

  final List<DropdownMenuItem<String>> _languageItems = const [
    DropdownMenuItem(value: 'english', child: Text('English')),
    DropdownMenuItem(value: 'urdu', child: Text('Urdu')),
  ];

  @override
  void initState() {
    super.initState();
    _loadMedicine();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicine() async {
    try {
      final medicine = await _medicineService.getMedicineById(widget.medicineId);
      if (!mounted) return;

      final existing = widget.existingSchedule;

      setState(() {
        _medicine = medicine;

        if (widget.isEditMode && existing != null) {
          _selectedTime = _parseTimeOfDay(existing.timeOfDay);
          _repeatType = existing.repeatType;
          _slotLabel = (existing.slotLabel ?? 'custom').trim().isEmpty
              ? 'custom'
              : existing.slotLabel!.trim();
          _quantityController.text =
              existing.quantityPerDose?.toString() ??
              medicine?.quantityPerDose?.toString() ??
              '';
          _selectedQuantityUnit =
              (existing.quantityUnit ?? medicine?.quantityUnit ?? 'tablet')
                  .trim()
                  .isEmpty
              ? 'tablet'
              : (existing.quantityUnit ?? medicine?.quantityUnit ?? 'tablet')
                    .trim();
          _selectedAnnouncementLanguage =
              (existing.announcementLanguage ??
                      medicine?.announcementLanguage ??
                      'english')
                  .trim()
                  .isEmpty
              ? 'english'
              : (existing.announcementLanguage ??
                      medicine?.announcementLanguage ??
                      'english')
                    .trim();
          _isEnabled = existing.isEnabled;

          for (final key in _days.keys) {
            _days[key] = existing.daysOfWeek.contains(key);
          }
        } else {
          _regimenMode = medicine?.defaultFrequencyLabel ?? 'once_daily';
          _quantityController.text = medicine?.quantityPerDose?.toString() ?? '';
          _selectedQuantityUnit = (medicine?.quantityUnit ?? 'tablet').trim().isEmpty
              ? 'tablet'
              : medicine!.quantityUnit!.trim();
          _selectedAnnouncementLanguage =
              (medicine?.announcementLanguage ?? 'english').trim().isEmpty
              ? 'english'
              : medicine!.announcementLanguage!.trim();
        }

        _loadingMedicine = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMedicine = false;
      });
    }
  }

  TimeOfDay? _parseTimeOfDay(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _pickTime() async {
    if (_isSaving) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  List<String> _selectedDays() {
    return _days.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  Future<void> _saveSchedule() async {
    if (_isSaving) return;

    final selectedDays = _selectedDays();

    if (_repeatType == 'selected_days' && selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reminder time')),
      );
      return;
    }

    final quantityText = _quantityController.text.trim();
    if (quantityText.isNotEmpty && double.tryParse(quantityText) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }

    final quantityPerDose =
        quantityText.isEmpty ? null : double.tryParse(quantityText);

    final stopwatch = Stopwatch()..start();

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isEditMode) {
        final existing = widget.existingSchedule!;

        await _scheduleService.updateScheduleEntry(
          scheduleId: existing.id,
          timeOfDay: _formatTimeOfDay(_selectedTime!),
          repeatType: _repeatType,
          daysOfWeek: _repeatType == 'daily' ? <String>[] : selectedDays,
          slotLabel: _slotLabel,
          quantityPerDose: quantityPerDose,
          quantityUnit: _selectedQuantityUnit,
          announcementLanguage: _selectedAnnouncementLanguage,
        );

        if (existing.isEnabled != _isEnabled) {
          await _scheduleService.updateScheduleStatus(
            scheduleId: existing.id,
            isEnabled: _isEnabled,
          );
        }
      } else {
        final regimenGroupId =
            'regimen_${widget.medicineId}_${DateTime.now().millisecondsSinceEpoch}';

        final repeatDays = _repeatType == 'daily' ? <String>[] : selectedDays;
        final schedules = _buildSchedulesForRegimen(
          regimenGroupId: regimenGroupId,
          repeatDays: repeatDays,
        );

        await _scheduleService.addSchedulesBatch(schedules: schedules);
      }

      stopwatch.stop();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditMode
                ? 'Schedule updated successfully'
                : 'Schedule added successfully',
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      stopwatch.stop();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save schedule: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<ScheduleEntryModel> _buildSchedulesForRegimen({
    required String regimenGroupId,
    required List<String> repeatDays,
  }) {
    final quantityText = _quantityController.text.trim();
    final quantityPerDose =
        quantityText.isEmpty ? _medicine?.quantityPerDose : double.tryParse(quantityText);

    List<_RegimenSlot> slots;

    switch (_regimenMode) {
      case 'twice_daily':
        slots = const [
          _RegimenSlot(timeOfDay: '08:00', slotLabel: 'morning', sortOrder: 1),
          _RegimenSlot(timeOfDay: '20:00', slotLabel: 'night', sortOrder: 2),
        ];
        break;
      case 'thrice_daily':
        slots = const [
          _RegimenSlot(timeOfDay: '08:00', slotLabel: 'morning', sortOrder: 1),
          _RegimenSlot(
            timeOfDay: '14:00',
            slotLabel: 'afternoon',
            sortOrder: 2,
          ),
          _RegimenSlot(timeOfDay: '20:00', slotLabel: 'night', sortOrder: 3),
        ];
        break;
      case 'custom':
        slots = [
          _RegimenSlot(
            timeOfDay: _formatTimeOfDay(_selectedTime!),
            slotLabel: _slotLabel,
            sortOrder: 1,
          ),
        ];
        break;
      case 'once_daily':
      default:
        slots = const [
          _RegimenSlot(timeOfDay: '08:00', slotLabel: 'morning', sortOrder: 1),
        ];
        break;
    }

    return slots.map((slot) {
      return ScheduleEntryModel(
        id: '',
        medicineId: widget.medicineId,
        timeOfDay: slot.timeOfDay,
        repeatType: _repeatType,
        daysOfWeek: repeatDays,
        regimenGroupId: regimenGroupId,
        slotLabel: slot.slotLabel,
        quantityPerDose: quantityPerDose,
        quantityUnit: _selectedQuantityUnit,
        announcementLanguage: _selectedAnnouncementLanguage,
        sortOrder: slot.sortOrder,
        isEnabled: true,
        createdAt: null,
        updatedAt: null,
      );
    }).toList();
  }

  Widget _buildDayChip(String key, String label) {
    final selected = _days[key] ?? false;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: _isSaving
          ? null
          : (value) {
              setState(() {
                _days[key] = value;
              });
            },
    );
  }

  Widget _buildRepeatTypeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ChoiceChip(
          label: const Text('Daily'),
          selected: _repeatType == 'daily',
          onSelected: _isSaving
              ? null
              : (selected) {
                  if (!selected) return;
                  setState(() {
                    _repeatType = 'daily';
                  });
                },
        ),
        ChoiceChip(
          label: const Text('Selected Days'),
          selected: _repeatType == 'selected_days',
          onSelected: _isSaving
              ? null
              : (selected) {
                  if (!selected) return;
                  setState(() {
                    _repeatType = 'selected_days';
                  });
                },
        ),
      ],
    );
  }

  Widget _buildRegimenSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ChoiceChip(
          label: const Text('Once Daily'),
          selected: _regimenMode == 'once_daily',
          onSelected: _isSaving
              ? null
              : (selected) {
                  if (!selected) return;
                  setState(() {
                    _regimenMode = 'once_daily';
                    if (_regimenMode != 'custom') {
                      _selectedTime = const TimeOfDay(hour: 8, minute: 0);
                    }
                  });
                },
        ),
        ChoiceChip(
          label: const Text('Twice Daily'),
          selected: _regimenMode == 'twice_daily',
          onSelected: _isSaving
              ? null
              : (selected) {
                  if (!selected) return;
                  setState(() {
                    _regimenMode = 'twice_daily';
                  });
                },
        ),
        ChoiceChip(
          label: const Text('Thrice Daily'),
          selected: _regimenMode == 'thrice_daily',
          onSelected: _isSaving
              ? null
              : (selected) {
                  if (!selected) return;
                  setState(() {
                    _regimenMode = 'thrice_daily';
                  });
                },
        ),
        ChoiceChip(
          label: const Text('Custom'),
          selected: _regimenMode == 'custom',
          onSelected: _isSaving
              ? null
              : (selected) {
                  if (!selected) return;
                  setState(() {
                    _regimenMode = 'custom';
                  });
                },
        ),
      ],
    );
  }

  String _regimenSummaryText() {
    switch (_regimenMode) {
      case 'twice_daily':
        return 'This will create 2 schedule rows: 08:00 morning and 20:00 night.';
      case 'thrice_daily':
        return 'This will create 3 schedule rows: 08:00 morning, 14:00 afternoon, and 20:00 night.';
      case 'custom':
        final timeText = _selectedTime == null
            ? 'No custom time selected yet.'
            : 'This will create 1 schedule row at ${_selectedTime!.format(context)}.';
        return timeText;
      case 'once_daily':
      default:
        return 'This will create 1 schedule row at 08:00 morning.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeText = _selectedTime == null
        ? 'No time selected'
        : _selectedTime!.format(context);

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditMode ? 'Edit Schedule' : 'Add Schedule'),
        ),
        body: _loadingMedicine
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.medicineName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if ((_medicine?.doseLabel ?? '').trim().isNotEmpty)
                      Text(
                        _medicine!.doseLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 24),

                    if (!widget.isEditMode) ...[
                      const Text(
                        'Regimen Helper',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildRegimenSelector(),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _regimenSummaryText(),
                          style: const TextStyle(height: 1.35),
                        ),
                      ),
                      if (_regimenMode == 'custom') ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Custom Reminder Time',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _pickTime,
                            child: Text(timeText),
                          ),
                        ),
                      ],
                    ],

                    if (widget.isEditMode) ...[
                      const Text(
                        'Reminder Time',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _pickTime,
                          child: Text(timeText),
                        ),
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        initialValue: _slotLabel,
                        decoration: InputDecoration(
                          labelText: 'Slot Label',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        items: _slotItems,
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _slotLabel = value;
                                });
                              },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              enabled: !_isSaving,
                              decoration: InputDecoration(
                                labelText: 'Quantity Per Dose',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedQuantityUnit,
                              decoration: InputDecoration(
                                labelText: 'Unit',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
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
                        initialValue: _selectedAnnouncementLanguage,
                        decoration: InputDecoration(
                          labelText: 'Announcement Language',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        items: _languageItems,
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedAnnouncementLanguage = value;
                                });
                              },
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Schedule Enabled',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        value: _isEnabled,
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                setState(() {
                                  _isEnabled = value;
                                });
                              },
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Text(
                      'Repeat Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildRepeatTypeSelector(),
                    if (_repeatType == 'selected_days') ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Select Days',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildDayChip('mon', 'Mon'),
                          _buildDayChip('tue', 'Tue'),
                          _buildDayChip('wed', 'Wed'),
                          _buildDayChip('thu', 'Thu'),
                          _buildDayChip('fri', 'Fri'),
                          _buildDayChip('sat', 'Sat'),
                          _buildDayChip('sun', 'Sun'),
                        ],
                      ),
                    ],
                    const SizedBox(height: 30),
                    if (_isSaving)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.isEditMode
                              ? 'Updating schedule. Please wait and do not go back.'
                              : 'Saving schedule. Please wait and do not go back.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSchedule,
                        child: _isSaving
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      widget.isEditMode
                                          ? 'Updating schedule...'
                                          : 'Saving schedule...',
                                    ),
                                  ],
                                ),
                              )
                            : Text(
                                widget.isEditMode
                                    ? 'Update Schedule'
                                    : 'Save Schedule',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _RegimenSlot {
  final String timeOfDay;
  final String slotLabel;
  final int sortOrder;

  const _RegimenSlot({
    required this.timeOfDay,
    required this.slotLabel,
    required this.sortOrder,
  });
}
