import 'package:flutter/material.dart';
import 'package:sehat_alarm_app/services/schedule_service.dart';

class AddScheduleScreen extends StatefulWidget {
  final String medicineId;
  final String medicineName;

  const AddScheduleScreen({
    super.key,
    required this.medicineId,
    required this.medicineName,
  });

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  final ScheduleService _scheduleService = ScheduleService();

  TimeOfDay? _selectedTime;
  String _repeatType = 'daily';
  bool _isSaving = false;

  final Map<String, bool> _days = {
    'mon': false,
    'tue': false,
    'wed': false,
    'thu': false,
    'fri': false,
    'sat': false,
    'sun': false,
  };

  Future<void> _pickTime() async {
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
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reminder time')),
      );
      return;
    }

    final selectedDays = _selectedDays();

    if (_repeatType == 'selected_days' && selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _scheduleService.addSchedule(
        medicineId: widget.medicineId,
        timeOfDay: _formatTimeOfDay(_selectedTime!),
        repeatType: _repeatType,
        daysOfWeek: _repeatType == 'daily' ? [] : selectedDays,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule added successfully')),
      );

      Navigator.pop(context);
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

  Widget _buildDayChip(String key, String label) {
    final selected = _days[key] ?? false;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) {
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
          onSelected: (selected) {
            if (!selected) return;
            setState(() {
              _repeatType = 'daily';
            });
          },
        ),
        ChoiceChip(
          label: const Text('Selected Days'),
          selected: _repeatType == 'selected_days',
          onSelected: (selected) {
            if (!selected) return;
            setState(() {
              _repeatType = 'selected_days';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Schedule'),
      ),
      body: SingleChildScrollView(
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
            const SizedBox(height: 24),
            const Text(
              'Reminder Time',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _pickTime,
                child: Text(timeText),
              ),
            ),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSchedule,
                child: _isSaving
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Save Schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
