import 'package:flutter/material.dart';
import 'package:sehat_alarm_app/screens/medicines/medicines_screen.dart';
import 'package:sehat_alarm_app/screens/settings/settings_screen.dart';
import 'package:sehat_alarm_app/screens/today_log/today_log_screen.dart';
import 'package:sehat_alarm_app/widgets/app_credits.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sehat Alarm'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _HomeButton(
              label: 'Tell Time',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Talking clock coming next phase'),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _HomeButton(
              label: 'Medicines',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MedicinesScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _HomeButton(
              label: 'Today Log',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TodayLogScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _HomeButton(
              label: 'Settings',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),
            const Spacer(),
            const AppCredits(),
          ],
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _HomeButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      child: Text(label),
    );
  }
}
