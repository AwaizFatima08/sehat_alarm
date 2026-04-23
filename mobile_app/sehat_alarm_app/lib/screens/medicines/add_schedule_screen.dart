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
          _selectedQuantityUnit =
              (medicine?.quantityUnit ?? 'tablet').trim().isEmpty
                  ? 'tablet'
                  : medicine!.quantityUnit!.trim();
          _selectedAnnouncementLanguage =
              (medicine?.announcementLanguage ?? 'english').trim().isEmpty
                  ? 'english'
                  : medicine!.announcementLanguage!.trim();

          if (_regimenMode == 'custom') {
            _selectedTime ??= TimeOfDay.now();
          }
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
      initialTime: _selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
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

  String _friendlyRepeatType() {
    return _repeatType == 'daily' ? 'Daily' : 'Selected days';
  }

  String _friendlyDaysSummary() {
    final days = _selectedDays();
    if (_repeatType == 'daily') return 'Every day';
    if (days.isEmpty) return 'No days selected';

    const labels = {
      'mon': 'Mon',
      'tue': 'Tue',
      'wed': 'Wed',
      'thu': 'Thu',
      'fri': 'Fri',
      'sat': 'Sat',
      'sun': 'Sun',
    };

    return days.map((day) => labels[day] ?? day).join(', ');
  }

  String _friendlyRegimenMode() {
    switch (_regimenMode) {
      case 'once_daily':
        return 'Once daily';
      case 'twice_daily':
        return 'Twice daily';
      case 'thrice_daily':
        return 'Thrice daily';
      case 'custom':
        return 'Custom';
      default:
        return _regimenMode;
    }
  }

  String _summaryText() {
    if (widget.isEditMode) {
      final timeText = _selectedTime == null
          ? 'No time selected'
          : _selectedTime!.format(context);
      final quantity = _quantityController.text.trim();
      final quantityText = quantity.isEmpty
          ? 'No quantity entered'
          : '$quantity $_selectedQuantityUnit';

      return 'You are updating one schedule row.\n'
          'Time: $timeText\n'
          'Repeat: ${_friendlyRepeatType()}\n'
          'Days: ${_friendlyDaysSummary()}\n'
          'Slot: ${_titleCase(_slotLabel)}\n'
          'Dose: $quantityText\n'
          'Language: ${_titleCase(_selectedAnnouncementLanguage)}\n'
          'Status: ${_isEnabled ? 'Enabled' : 'Disabled'}';
    }

    switch (_regimenMode) {
      case 'twice_daily':
        return 'You are creating a twice-daily regimen.\n'
            'Rows: 2\n'
            'Times: 08:00 morning, 20:00 night\n'
            'Repeat: ${_friendlyRepeatType()}\n'
            'Days: ${_friendlyDaysSummary()}';
      case 'thrice_daily':
        return 'You are creating a thrice-daily regimen.\n'
            'Rows: 3\n'
            'Times: 08:00 morning, 14:00 afternoon, 20:00 night\n'
            'Repeat: ${_friendlyRepeatType()}\n'
            'Days: ${_friendlyDaysSummary()}';
      case 'custom':
        final timeText = _selectedTime == null
            ? 'No custom time selected'
            : _selectedTime!.format(context);
        return 'You are creating a custom schedule.\n'
            'Rows: 1\n'
            'Time: $timeText\n'
            'Repeat: ${_friendlyRepeatType()}\n'
            'Days: ${_friendlyDaysSummary()}';
      case 'once_daily':
      default:
        return 'You are creating a once-daily regimen.\n'
            'Rows: 1\n'
            'Time: 08:00 morning\n'
            'Repeat: ${_friendlyRepeatType()}\n'
            'Days: ${_friendlyDaysSummary()}';
    }
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

    if (widget.isEditMode && _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reminder time')),
      );
      return;
    }

    if (!widget.isEditMode &&
        _regimenMode == 'custom' &&
        _selectedTime == null) {
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
    final quantityPerDose = quantityText.isEmpty
        ? _medicine?.quantityPerDose
        : double.tryParse(quantityText);

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
                    _selectedTime ??= TimeOfDay.now();
                  });
                },
        ),
      ],
    );
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
                    _HeroHeader(
                      title: widget.medicineName,
                      subtitle: widget.isEditMode
                          ? 'Update one schedule row safely without changing the rest of the regimen.'
                          : 'Create a clear reminder schedule for this medicine.',
                      doseLabel: (_medicine?.doseLabel ?? '').trim(),
                    ),
                    const SizedBox(height: 18),
                    _SectionCard(
                      title: 'Summary',
                      child: _SummaryPanel(
                        text: _summaryText(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!widget.isEditMode) ...[
                      _SectionCard(
                        title: 'Regimen',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRegimenSelector(),
                            const SizedBox(height: 14),
                            _InfoPanel(
                              title: 'Current Selection',
                              body: _friendlyRegimenMode(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    _SectionCard(
                      title: widget.isEditMode ? 'Timing' : 'Repeat',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.isEditMode || _regimenMode == 'custom') ...[
                            const Text(
                              'Reminder Time',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _pickTime,
                                icon: const Icon(Icons.access_time),
                                label: Text(timeText),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          const Text(
                            'Repeat Type',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildRepeatTypeSelector(),
                          if (_repeatType == 'selected_days') ...[
                            const SizedBox(height: 18),
                            const Text(
                              'Select Days',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
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
                        ],
                      ),
                    ),

                    if (widget.isEditMode) ...[
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Dose and Schedule Details',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _slotLabel,
                              decoration: _inputDecoration('Slot Label'),
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
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _quantityController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    enabled: !_isSaving,
                                    decoration:
                                        _inputDecoration('Quantity Per Dose'),
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
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedAnnouncementLanguage,
                              decoration:
                                  _inputDecoration('Announcement Language'),
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
                              subtitle: const Text(
                                'Turn this off to keep the row saved but inactive.',
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
                        ),
                      ),
                    ],

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
                        child: Text(
                          widget.isEditMode
                              ? 'Updating schedule. Please wait and do not go back.'
                              : 'Saving schedule. Please wait and do not go back.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSchedule,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(widget.isEditMode
                                ? Icons.save_rounded
                                : Icons.add_alarm_rounded),
                        label: Text(
                          _isSaving
                              ? (widget.isEditMode
                                  ? 'Updating schedule...'
                                  : 'Saving schedule...')
                              : (widget.isEditMode
                                  ? 'Update Schedule'
                                  : 'Save Schedule'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final String doseLabel;

  const _HeroHeader({
    required this.title,
    required this.subtitle,
    required this.doseLabel,
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
          if (doseLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              doseLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            offset: const Offset(0, 3),
            color: Colors.black.withValues(alpha: 0.03),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final String text;

  const _SummaryPanel({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final String body;

  const _InfoPanel({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
