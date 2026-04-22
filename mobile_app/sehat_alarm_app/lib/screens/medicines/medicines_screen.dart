import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sehat_alarm_app/models/medicine_model.dart';
import 'package:sehat_alarm_app/models/schedule_entry_model.dart';
import 'package:sehat_alarm_app/screens/medicines/add_medicine_screen.dart';
import 'package:sehat_alarm_app/screens/medicines/add_schedule_screen.dart';
import 'package:sehat_alarm_app/services/medicine_service.dart';
import 'package:sehat_alarm_app/services/schedule_service.dart';

class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  final MedicineService _medicineService = MedicineService();

  Future<void> _openAddMedicine() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddMedicineScreen(),
      ),
    );
  }

  Future<void> _openAddSchedule(MedicineModel medicine) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddScheduleScreen(
          medicineId: medicine.id,
          medicineName: medicine.name,
        ),
      ),
    );
  }

  Future<void> _openEditSchedule(
    MedicineModel medicine,
    ScheduleEntryModel schedule,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddScheduleScreen(
          medicineId: medicine.id,
          medicineName: medicine.name,
          existingSchedule: schedule,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicines'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddMedicine,
        icon: const Icon(Icons.add),
        label: const Text('Add Medicine'),
      ),
      body: StreamBuilder<List<MedicineModel>>(
        stream: _medicineService.getMedicines(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading medicines:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final medicines = snapshot.data ?? [];

          if (medicines.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No medicines added yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add your first medicine to begin creating reminders and regimens.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _openAddMedicine,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Medicine'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: medicines.length,
            separatorBuilder: (context, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final medicine = medicines[index];
              return _MedicineCard(
                medicine: medicine,
                onAddSchedule: () => _openAddSchedule(medicine),
                onEditSchedule: (schedule) => _openEditSchedule(medicine, schedule),
              );
            },
          );
        },
      ),
    );
  }
}

class _MedicineCard extends StatefulWidget {
  final MedicineModel medicine;
  final VoidCallback onAddSchedule;
  final ValueChanged<ScheduleEntryModel> onEditSchedule;

  const _MedicineCard({
    required this.medicine,
    required this.onAddSchedule,
    required this.onEditSchedule,
  });

  @override
  State<_MedicineCard> createState() => _MedicineCardState();
}

class _MedicineCardState extends State<_MedicineCard> {
  final MedicineService _medicineService = MedicineService();

  bool _busy = false;
  bool _expanded = true;

  Future<void> _toggleMedicineStatus(bool value) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await _medicineService.updateMedicineStatus(
        medicineId: widget.medicine.id,
        isActive: value,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update medicine status: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _quantityText() {
    final quantity = widget.medicine.quantityPerDose;
    final unit = (widget.medicine.quantityUnit ?? '').trim();

    if (quantity == null) return '';

    final quantityLabel = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();

    return unit.isEmpty ? quantityLabel : '$quantityLabel $unit';
  }

  String _frequencyText() {
    switch ((widget.medicine.defaultFrequencyLabel ?? '').trim()) {
      case 'once_daily':
        return 'Once daily';
      case 'twice_daily':
        return 'Twice daily';
      case 'thrice_daily':
        return 'Thrice daily';
      case 'custom':
        return 'Custom';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final quantityText = _quantityText();
    final frequencyText = _frequencyText();
    final language = (widget.medicine.announcementLanguage ?? 'english').trim();
    final dosageForm = (widget.medicine.dosageForm ?? '').trim();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  child: Icon(
                    _medicineIconFor(dosageForm),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.medicine.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (widget.medicine.doseLabel.trim().isNotEmpty)
                        Text(
                          widget.medicine.doseLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (dosageForm.isNotEmpty)
                            Chip(label: Text(_titleCase(dosageForm))),
                          if (quantityText.isNotEmpty)
                            Chip(label: Text('Dose: $quantityText')),
                          if (frequencyText.isNotEmpty)
                            Chip(label: Text(frequencyText)),
                          Chip(label: Text('Lang: ${_titleCase(language)}')),
                          if (widget.medicine.announcementBilingual == true)
                            const Chip(label: Text('Bilingual')),
                          Chip(
                            label: Text(
                              widget.medicine.isActive ? 'Active' : 'Inactive',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Switch(
                      value: widget.medicine.isActive,
                      onChanged: _busy ? null : _toggleMedicineStatus,
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _expanded = !_expanded;
                        });
                      },
                      icon: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if ((widget.medicine.instructions).trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  widget.medicine.instructions,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ),
            ],
            if ((widget.medicine.regimenNote ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Regimen note: ${widget.medicine.regimenNote!.trim()}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onAddSchedule,
                    icon: const Icon(Icons.add_alarm_rounded),
                    label: const Text('Add Schedule'),
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 16),
              _MedicineSchedulesSection(
                medicine: widget.medicine,
                onEditSchedule: widget.onEditSchedule,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MedicineSchedulesSection extends StatelessWidget {
  final MedicineModel medicine;
  final ValueChanged<ScheduleEntryModel> onEditSchedule;

  const _MedicineSchedulesSection({
    required this.medicine,
    required this.onEditSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final scheduleService = ScheduleService();

    return StreamBuilder<List<ScheduleEntryModel>>(
      stream: scheduleService.getSchedulesForMedicine(medicine.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Failed to load schedules: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final schedules = snapshot.data ?? [];

        if (schedules.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'No schedules added yet for this medicine.',
              style: TextStyle(fontSize: 14),
            ),
          );
        }

        final grouped = _groupSchedules(schedules);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Schedules',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ...grouped.map(
              (group) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RegimenGroupCard(
                  group: group,
                  onEditSchedule: onEditSchedule,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<_ScheduleGroup> _groupSchedules(List<ScheduleEntryModel> schedules) {
    final map = <String, List<ScheduleEntryModel>>{};

    for (final schedule in schedules) {
      final key = (schedule.regimenGroupId ?? '').trim().isNotEmpty
          ? schedule.regimenGroupId!.trim()
          : 'single_${schedule.id}';
      map.putIfAbsent(key, () => []).add(schedule);
    }

    final groups = map.entries.map((entry) {
      final items = [...entry.value]
        ..sort((a, b) {
          final aOrder = a.sortOrder ?? 999;
          final bOrder = b.sortOrder ?? 999;

          if (aOrder != bOrder) return aOrder.compareTo(bOrder);
          return a.timeOfDay.compareTo(b.timeOfDay);
        });

      return _ScheduleGroup(
        regimenGroupId: entry.key,
        schedules: items,
      );
    }).toList();

    groups.sort((a, b) {
      final aFirst = a.schedules.first;
      final bFirst = b.schedules.first;
      return aFirst.timeOfDay.compareTo(bFirst.timeOfDay);
    });

    return groups;
  }
}

class _RegimenGroupCard extends StatelessWidget {
  final _ScheduleGroup group;
  final ValueChanged<ScheduleEntryModel> onEditSchedule;

  const _RegimenGroupCard({
    required this.group,
    required this.onEditSchedule,
  });

  String _groupTitle() {
    if (group.schedules.length == 1) {
      return 'Single schedule';
    }
    if (group.schedules.length == 2) {
      return 'Twice daily regimen';
    }
    if (group.schedules.length == 3) {
      return 'Thrice daily regimen';
    }
    return '${group.schedules.length} dose regimen';
  }

  String _repeatText(ScheduleEntryModel schedule) {
    if (schedule.repeatType == 'daily') {
      return 'Daily';
    }

    if (schedule.repeatType == 'selected_days') {
      final labels = schedule.daysOfWeek.map(_dayLabel).toList();
      return labels.isEmpty ? 'Selected days' : labels.join(', ');
    }

    return schedule.repeatType;
  }

  Future<void> _toggleSchedule(
    BuildContext context,
    ScheduleEntryModel schedule,
    bool value,
  ) async {
    final service = ScheduleService();

    try {
      await service.updateScheduleStatus(
        scheduleId: schedule.id,
        isEnabled: value,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update schedule: $e')),
      );
    }
  }

  Future<void> _deleteSchedule(
    BuildContext context,
    ScheduleEntryModel schedule,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text(
          'Do you want to delete this schedule entry?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ScheduleService().deleteScheduleEntry(schedule.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete schedule: $e')),
      );
    }
  }

  Future<void> _deleteRegimenGroup(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Regimen'),
        content: const Text(
          'This will delete all schedule rows in this regimen.\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ScheduleService().deleteRegimenGroup(group.regimenGroupId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete regimen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = group.schedules.first;
    final repeatText = _repeatText(first);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _groupTitle(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete regimen',
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                onPressed: () => _deleteRegimenGroup(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            repeatText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ...group.schedules.map(
            (schedule) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Text(
                              _formatTime(schedule.timeOfDay),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if ((schedule.slotLabel ?? '').trim().isNotEmpty)
                              Chip(
                                label: Text(_slotLabel(schedule.slotLabel!)),
                              ),
                            Chip(
                              label: Text(
                                schedule.isEnabled ? 'Enabled' : 'Disabled',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (schedule.quantityPerDose != null)
                              Text(
                                'Qty: ${_quantityText(schedule.quantityPerDose!, schedule.quantityUnit)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            if ((schedule.announcementLanguage ?? '')
                                .trim()
                                .isNotEmpty)
                              Text(
                                'Lang: ${_titleCase(schedule.announcementLanguage!.trim())}',
                                style: const TextStyle(fontSize: 14),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    children: [
                      Switch(
                        value: schedule.isEnabled,
                        onChanged: (value) =>
                            _toggleSchedule(context, schedule, value),
                      ),
                      IconButton(
                        tooltip: 'Edit schedule',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => onEditSchedule(schedule),
                      ),
                      IconButton(
                        tooltip: 'Delete schedule',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _deleteSchedule(context, schedule),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _quantityText(double quantity, String? unit) {
    final q = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
    final u = (unit ?? '').trim();
    return u.isEmpty ? q : '$q $u';
  }

  String _slotLabel(String slot) {
    switch (slot.trim()) {
      case 'morning':
        return 'Morning';
      case 'afternoon':
        return 'Afternoon';
      case 'night':
        return 'Night';
      case 'custom':
        return 'Custom';
      default:
        return _titleCase(slot.trim());
    }
  }

  String _dayLabel(String code) {
    switch (code) {
      case 'mon':
        return 'Mon';
      case 'tue':
        return 'Tue';
      case 'wed':
        return 'Wed';
      case 'thu':
        return 'Thu';
      case 'fri':
        return 'Fri';
      case 'sat':
        return 'Sat';
      case 'sun':
        return 'Sun';
      default:
        return code;
    }
  }

  String _formatTime(String hhmm) {
    try {
      final parts = hhmm.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, hour, minute);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return hhmm;
    }
  }
}

class _ScheduleGroup {
  final String regimenGroupId;
  final List<ScheduleEntryModel> schedules;

  const _ScheduleGroup({
    required this.regimenGroupId,
    required this.schedules,
  });
}

IconData _medicineIconFor(String dosageForm) {
  switch (dosageForm.trim()) {
    case 'syrup':
      return Icons.local_drink_rounded;
    case 'drops':
      return Icons.opacity_rounded;
    case 'injection':
      return Icons.vaccines_rounded;
    case 'capsule':
      return Icons.medication_rounded;
    case 'tablet':
      return Icons.tablet_mac_rounded;
    default:
      return Icons.medication_liquid_rounded;
  }
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
