import 'package:flutter/material.dart';
import 'package:sehat_alarm_app/services/app_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettingsService _appSettingsService = AppSettingsService();

  bool _loading = true;
  bool _savingLanguage = false;
  bool _savingAlarm = false;

  String _defaultAnnouncementLanguage = 'english';
  bool _bilingualAnnouncements = false;

  String _alarmStrengthProfile = 'strong';
  bool _vibrationEnabled = true;
  int _repeatIntervalSeconds = 20;
  int _maxAlarmDurationMinutes = 5;
  int _defaultSnoozeMinutes = 10;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
    });

    try {
      final settings = await _appSettingsService.getSettings();

      if (!mounted) return;

      setState(() {
        _defaultAnnouncementLanguage =
            settings.defaultAnnouncementLanguage;
        _bilingualAnnouncements = settings.bilingualAnnouncements;
        _alarmStrengthProfile = settings.alarmStrengthProfile;
        _vibrationEnabled = settings.vibrationEnabled;
        _repeatIntervalSeconds = settings.repeatIntervalSeconds;
        _maxAlarmDurationMinutes = settings.maxAlarmDurationMinutes;
        _defaultSnoozeMinutes = settings.defaultSnoozeMinutes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load settings: $e')),
      );
    }
  }

  Future<void> _saveLanguageSettings() async {
    if (_savingLanguage || _savingAlarm) return;

    setState(() {
      _savingLanguage = true;
    });

    try {
      await _appSettingsService.updateLanguageSettings(
        defaultAnnouncementLanguage: _defaultAnnouncementLanguage,
        bilingualAnnouncements: _bilingualAnnouncements,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Language settings saved successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save language settings: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingLanguage = false;
        });
      }
    }
  }

  Future<void> _saveAlarmSettings() async {
    if (_savingLanguage || _savingAlarm) return;

    setState(() {
      _savingAlarm = true;
    });

    try {
      await _appSettingsService.updateAlarmSettings(
        alarmStrengthProfile: _alarmStrengthProfile,
        vibrationEnabled: _vibrationEnabled,
        repeatIntervalSeconds: _repeatIntervalSeconds,
        maxAlarmDurationMinutes: _maxAlarmDurationMinutes,
        defaultSnoozeMinutes: _defaultSnoozeMinutes,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alarm settings saved successfully'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save alarm settings: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingAlarm = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _savingLanguage || _savingAlarm;

    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
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
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Settings & Information',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Phase 7 now focuses on stronger, harder-to-miss alarm behavior while keeping the reminder flow simple and dependable.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          _SectionCard(
                            title: 'Language',
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Default Announcement Language',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment<String>(
                                        value: 'english',
                                        label: Text('English'),
                                        icon: Icon(Icons.language),
                                      ),
                                      ButtonSegment<String>(
                                        value: 'urdu',
                                        label: Text('Urdu'),
                                        icon: Icon(Icons.translate),
                                      ),
                                    ],
                                    selected: {_defaultAnnouncementLanguage},
                                    onSelectionChanged: _savingLanguage
                                        ? null
                                        : (selection) {
                                            setState(() {
                                              _defaultAnnouncementLanguage =
                                                  selection.first;
                                            });
                                          },
                                  ),
                                  const SizedBox(height: 18),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Bilingual Announcements',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Keep off unless device TTS supports both languages clearly.',
                                    ),
                                    value: _bilingualAnnouncements,
                                    onChanged: _savingLanguage
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _bilingualAnnouncements = value;
                                            });
                                          },
                                  ),
                                  const SizedBox(height: 16),
                                  if (_savingLanguage)
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Saving language settings. Please wait.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _savingLanguage
                                          ? null
                                          : _saveLanguageSettings,
                                      icon: _savingLanguage
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.save_rounded),
                                      label: Text(
                                        _savingLanguage
                                            ? 'Saving...'
                                            : 'Save Language Settings',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Alarm Strength & Reliability',
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Alarm Strength',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment<String>(
                                        value: 'normal',
                                        label: Text('Normal'),
                                        icon: Icon(Icons.volume_down),
                                      ),
                                      ButtonSegment<String>(
                                        value: 'strong',
                                        label: Text('Strong'),
                                        icon: Icon(Icons.volume_up),
                                      ),
                                      ButtonSegment<String>(
                                        value: 'very_strong',
                                        label: Text('Very Strong'),
                                        icon: Icon(Icons.notification_important),
                                      ),
                                    ],
                                    selected: {_alarmStrengthProfile},
                                    onSelectionChanged: _savingAlarm
                                        ? null
                                        : (selection) {
                                            setState(() {
                                              _alarmStrengthProfile =
                                                  selection.first;
                                            });
                                          },
                                  ),
                                  const SizedBox(height: 18),
                                  SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text(
                                      'Vibration Enabled',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Used by the notification alarm path where device support allows it.',
                                    ),
                                    value: _vibrationEnabled,
                                    onChanged: _savingAlarm
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _vibrationEnabled = value;
                                            });
                                          },
                                  ),
                                  const SizedBox(height: 8),
                                  _NumberSettingRow(
                                    label: 'Repeat Interval',
                                    value: _repeatIntervalSeconds,
                                    unitLabel: 'seconds',
                                    minValue: 5,
                                    maxValue: 120,
                                    step: 5,
                                    onChanged: _savingAlarm
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _repeatIntervalSeconds = value;
                                            });
                                          },
                                  ),
                                  const SizedBox(height: 12),
                                  _NumberSettingRow(
                                    label: 'Maximum Alarm Duration',
                                    value: _maxAlarmDurationMinutes,
                                    unitLabel: 'minutes',
                                    minValue: 1,
                                    maxValue: 30,
                                    step: 1,
                                    onChanged: _savingAlarm
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _maxAlarmDurationMinutes = value;
                                            });
                                          },
                                  ),
                                  const SizedBox(height: 12),
                                  _NumberSettingRow(
                                    label: 'Default Snooze',
                                    value: _defaultSnoozeMinutes,
                                    unitLabel: 'minutes',
                                    minValue: 1,
                                    maxValue: 60,
                                    step: 1,
                                    onChanged: _savingAlarm
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _defaultSnoozeMinutes = value;
                                            });
                                          },
                                  ),
                                  const SizedBox(height: 16),
                                  if (_savingAlarm)
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Saving alarm settings. Please wait.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _savingAlarm
                                          ? null
                                          : _saveAlarmSettings,
                                      icon: _savingAlarm
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.alarm),
                                      label: Text(
                                        _savingAlarm
                                            ? 'Saving...'
                                            : 'Save Alarm Settings',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'About Sehat Alarm',
                            child: const Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sehat Alarm is a talking clock and medicine reminder built with an accessibility-first approach. The current development priority is stronger alarm reliability, clear response actions, and safe daily medicine support.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.45,
                                    ),
                                  ),
                                  SizedBox(height: 14),
                                  Text(
                                    'Current focus',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text('• stronger repeat alarm loop'),
                                  Text('• configurable snooze behavior'),
                                  Text('• clearer active reminder handling'),
                                  Text('• gradual bilingual support'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Development Team',
                            child: const Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Developed by Homi Labs',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Code with Purpose, build with heart',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                  SizedBox(height: 18),
                                  Text(
                                    'Core Team',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text('Awaiz Fatima — Chief Developer'),
                                  Text('Muhammad Abdulhadi — QC Manager'),
                                  Text('Parishay Zainab — Developer'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _NumberSettingRow extends StatelessWidget {
  final String label;
  final int value;
  final String unitLabel;
  final int minValue;
  final int maxValue;
  final int step;
  final ValueChanged<int>? onChanged;

  const _NumberSettingRow({
    required this.label,
    required this.value,
    required this.unitLabel,
    required this.minValue,
    required this.maxValue,
    required this.step,
    required this.onChanged,
  });

  void _change(int direction) {
    if (onChanged == null) return;

    final updated = value + (step * direction);
    if (updated < minValue || updated > maxValue) return;
    onChanged!(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$label: $value $unitLabel',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: onChanged == null ? null : () => _change(-1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        IconButton(
          onPressed: onChanged == null ? null : () => _change(1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
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
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
