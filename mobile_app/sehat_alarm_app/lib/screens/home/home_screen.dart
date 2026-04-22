import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sehat_alarm_app/screens/medicines/medicines_screen.dart';
import 'package:sehat_alarm_app/screens/settings/settings_screen.dart';
import 'package:sehat_alarm_app/screens/today_log/today_log_screen.dart';
import 'package:sehat_alarm_app/widgets/app_credits.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String _formattedTime() {
    return DateFormat('hh:mm:ss a').format(_now);
  }

  String _formattedDate() {
    return DateFormat('EEEE, d MMMM y').format(_now);
  }

  void _showComingSoonMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Talking clock feature will be added in next phase.'),
      ),
    );
  }

  void _openMedicines() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MedicinesScreen(),
      ),
    );
  }

  void _openTodayLog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TodayLogScreen(),
      ),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sehat Alarm'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroHeader(
                        timeText: _formattedTime(),
                        dateText: _formattedDate(),
                      ),
                      const SizedBox(height: 24),
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: _FeatureCard(
                                icon: Icons.medication_rounded,
                                title: 'Medicines',
                                subtitle: 'Add and manage your medicines',
                                onTap: _openMedicines,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _FeatureCard(
                                icon: Icons.today_rounded,
                                title: 'Today Log',
                                subtitle: 'Review today\'s reminders and actions',
                                onTap: _openTodayLog,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _FeatureCard(
                          icon: Icons.medication_rounded,
                          title: 'Medicines',
                          subtitle: 'Add and manage your medicines',
                          onTap: _openMedicines,
                        ),
                        const SizedBox(height: 16),
                        _FeatureCard(
                          icon: Icons.today_rounded,
                          title: 'Today Log',
                          subtitle: 'Review today\'s reminders and actions',
                          onTap: _openTodayLog,
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (isWide)
                        Row(
                          children: [
                            Expanded(
                              child: _FeatureCard(
                                icon: Icons.record_voice_over_rounded,
                                title: 'Tell Time',
                                subtitle: 'Talking clock feature coming next',
                                onTap: _showComingSoonMessage,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _FeatureCard(
                                icon: Icons.settings_rounded,
                                title: 'Settings',
                                subtitle: 'Language and app information',
                                onTap: _openSettings,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _FeatureCard(
                          icon: Icons.record_voice_over_rounded,
                          title: 'Tell Time',
                          subtitle: 'Talking clock feature coming next',
                          onTap: _showComingSoonMessage,
                        ),
                        const SizedBox(height: 16),
                        _FeatureCard(
                          icon: Icons.settings_rounded,
                          title: 'Settings',
                          subtitle: 'Language and app information',
                          onTap: _openSettings,
                        ),
                      ],
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Sehat Alarm is designed to help users remember their medicines on time with clear reminders, speaking alerts, and a simple daily log.',
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      const AppCredits(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String timeText;
  final String dateText;

  const _HeroHeader({
    required this.timeText,
    required this.dateText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.alarm_rounded,
                  size: 34,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sehat Alarm',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Never miss a dose',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              timeText,
              style: const TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                offset: const Offset(0, 4),
                color: Colors.black.withValues(alpha: 0.04),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.74),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
