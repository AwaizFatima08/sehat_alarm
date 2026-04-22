import 'package:flutter/material.dart';
import 'package:sehat_alarm_app/models/medicine_model.dart';
import 'package:sehat_alarm_app/models/schedule_entry_model.dart';
import 'package:sehat_alarm_app/screens/medicines/add_medicine_screen.dart';
import 'package:sehat_alarm_app/screens/medicines/add_schedule_screen.dart';
import 'package:sehat_alarm_app/services/medicine_service.dart';
import 'package:sehat_alarm_app/services/schedule_service.dart';

class MedicinesScreen extends StatelessWidget {
  const MedicinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final medicineService = MedicineService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicines'),
      ),
      body: StreamBuilder<List<MedicineModel>>(
        stream: medicineService.getMedicines(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No medicines added yet.\nTap the + button to add your first medicine.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: medicines.length,
            separatorBuilder: (context, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final medicine = medicines[index];
              return _MedicineCard(
                medicine: medicine,
                onToggle: (value) async {
                  await medicineService.updateMedicineStatus(
                    medicineId: medicine.id,
                    isActive: value,
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final MedicineModel medicine;
  final ValueChanged<bool> onToggle;

  const _MedicineCard({
    required this.medicine,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheduleService = ScheduleService();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              medicine.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dose: ${medicine.doseLabel}',
              style: const TextStyle(fontSize: 18),
            ),
            if (medicine.instructions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Instructions: ${medicine.instructions}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    medicine.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: medicine.isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                Switch(
                  value: medicine.isActive,
                  onChanged: onToggle,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Schedules',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddScheduleScreen(
                          medicineId: medicine.id,
                          medicineName: medicine.name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_alarm),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<ScheduleEntryModel>>(
              stream: scheduleService.getSchedulesForMedicine(medicine.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    'Error loading schedules',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 14,
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(),
                  );
                }

                final schedules = snapshot.data ?? [];

                if (schedules.isEmpty) {
                  return const Text(
                    'No schedules added yet.',
                    style: TextStyle(fontSize: 15),
                  );
                }

                return Column(
                  children: schedules.map((schedule) {
                    return _ScheduleTile(
                      schedule: schedule,
                      onToggle: (value) async {
                        await scheduleService.updateScheduleStatus(
                          scheduleId: schedule.id,
                          isEnabled: value,
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final ScheduleEntryModel schedule;
  final ValueChanged<bool> onToggle;

  const _ScheduleTile({
    required this.schedule,
    required this.onToggle,
  });

  String _repeatText() {
    if (schedule.repeatType == 'daily') {
      return 'Daily';
    }

    if (schedule.daysOfWeek.isEmpty) {
      return 'Selected days';
    }

    return schedule.daysOfWeek
        .map((day) => day[0].toUpperCase() + day.substring(1))
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.timeOfDay,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _repeatText(),
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
          Switch(
            value: schedule.isEnabled,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}
