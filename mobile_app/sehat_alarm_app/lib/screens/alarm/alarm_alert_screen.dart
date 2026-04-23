import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sehat_alarm_app/models/app_settings_model.dart';
import 'package:sehat_alarm_app/models/dose_event_model.dart';
import 'package:sehat_alarm_app/models/medicine_model.dart';
import 'package:sehat_alarm_app/services/alarm_runtime_service.dart';
import 'package:sehat_alarm_app/services/app_settings_service.dart';
import 'package:sehat_alarm_app/services/dose_event_service.dart';
import 'package:sehat_alarm_app/services/medicine_service.dart';
import 'package:sehat_alarm_app/services/notification_service.dart';

class AlarmAlertScreen extends StatefulWidget {
  final AlarmNavigationPayload payload;

  const AlarmAlertScreen({
    super.key,
    required this.payload,
  });

  @override
  State<AlarmAlertScreen> createState() => _AlarmAlertScreenState();
}

class _AlarmAlertScreenState extends State<AlarmAlertScreen>
    with WidgetsBindingObserver {
  final DoseEventService _doseEventService = DoseEventService();
  final MedicineService _medicineService = MedicineService();
  final AppSettingsService _appSettingsService = AppSettingsService();

  DoseEventModel? _event;
  MedicineModel? _medicine;
  AppSettingsModel? _settings;

  bool _loading = true;
  bool _busy = false;
  String? _busyLabel;
  String? _error;

  Timer? _autoRetryTimer;
  int _retryCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configureImmersiveMode();
    _loadAlarmContext();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelRetryGuard();
    AlarmRuntimeService.instance.stopAlarmLoop();
    _restoreSystemUi();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _configureImmersiveMode();
    }
  }

  Future<void> _configureImmersiveMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _cancelRetryGuard() {
    _autoRetryTimer?.cancel();
    _autoRetryTimer = null;
  }

  Future<void> _loadAlarmContext() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AlarmRuntimeService.instance.initialize();

      final settings = await _appSettingsService.getSettings();
      final event =
          await _doseEventService.getEventById(widget.payload.eventId);

      if (event == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Dose event not found.';
        });
        return;
      }

      if (!event.isAlarmActive) {
        await NotificationService.instance.cancelNotificationForEvent(event.id);
        await AlarmRuntimeService.instance.stopAlarmLoop();

        if (!mounted) return;
        setState(() {
          _event = event;
          _settings = settings;
          _loading = false;
          _error = 'This reminder is already marked as ${event.status}.';
        });
        return;
      }

      final medicine =
          await _medicineService.getMedicineById(event.medicineId);

      await _doseEventService.markEventAsRinging(eventId: event.id);
      final refreshedEvent =
          await _doseEventService.getEventById(widget.payload.eventId);

      if (!mounted) return;

      setState(() {
        _event = refreshedEvent ?? event;
        _medicine = medicine;
        _settings = settings;
        _loading = false;
      });

      await AlarmRuntimeService.instance.startAlarmLoop(
        medicine: medicine,
        scheduledAt:
            (refreshedEvent ?? event).snoozeUntil ??
            (refreshedEvent ?? event).scheduledDateTime,
      );

      _startRetryGuard();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load alarm details.';
      });
    }
  }

  void _startRetryGuard() {
    _cancelRetryGuard();
    _retryCount = 0;

    final repeatSeconds = _settings?.repeatIntervalSeconds ?? 20;

    _autoRetryTimer = Timer.periodic(
      Duration(seconds: repeatSeconds),
      (_) async {
        if (!mounted || _busy) return;

        final eventId = _event?.id;
        if (eventId == null) return;

        try {
          final refreshed = await _doseEventService.getEventById(eventId);
          if (refreshed == null) return;

          if (!refreshed.isAlarmActive) {
            _cancelRetryGuard();
            await AlarmRuntimeService.instance.stopAlarmLoop();

            if (!mounted) return;
            await _closeAlarmScreen();
            return;
          }

          _retryCount += 1;

          if (mounted) {
            setState(() {
              _event = refreshed;
            });
          }

          await AlarmRuntimeService.instance.startAlarmLoop(
            medicine: _medicine,
            scheduledAt: refreshed.snoozeUntil ?? refreshed.scheduledDateTime,
          );
        } catch (_) {
          // Keep alarm screen alive.
        }
      },
    );
  }

  Future<void> _closeAlarmScreen() async {
    if (!mounted) return;

    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _markTaken() async {
    final event = _event;
    if (event == null || _busy) return;

    setState(() {
      _busy = true;
      _busyLabel = 'Marking dose as taken...';
    });

    try {
      _cancelRetryGuard();

      await _doseEventService.updateStatus(
        eventId: event.id,
        status: 'taken',
      );

      await NotificationService.instance.cancelNotificationForEvent(event.id);
      await AlarmRuntimeService.instance.stopAlarmLoop();

      await _closeAlarmScreen();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as taken: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  Future<void> _skipDose() async {
    final event = _event;
    if (event == null || _busy) return;

    setState(() {
      _busy = true;
      _busyLabel = 'Skipping this dose...';
    });

    try {
      _cancelRetryGuard();

      await _doseEventService.updateStatus(
        eventId: event.id,
        status: 'skipped',
      );

      await NotificationService.instance.cancelNotificationForEvent(event.id);
      await AlarmRuntimeService.instance.stopAlarmLoop();

      await _closeAlarmScreen();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to skip dose: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  Future<void> _snoozeDose() async {
    final event = _event;
    if (event == null || _busy) return;

    final snoozeMinutes = _settings?.defaultSnoozeMinutes ?? 10;

    setState(() {
      _busy = true;
      _busyLabel = 'Snoozing for $snoozeMinutes minutes...';
    });

    try {
      _cancelRetryGuard();

      await _doseEventService.snoozeEvent(
        eventId: event.id,
        minutes: snoozeMinutes,
      );

      await NotificationService.instance.cancelNotificationForEvent(event.id);

      final refreshedEvent = await _doseEventService.getEventById(event.id);

      if (refreshedEvent != null) {
        _event = refreshedEvent;

        await NotificationService.instance.scheduleDoseEventNotification(
          event: refreshedEvent,
          medicineName: _resolvedMedicineName(),
        );
      }

      await AlarmRuntimeService.instance.stopAlarmLoop();

      await _closeAlarmScreen();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to snooze dose: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  String _resolvedMedicineName() {
    final eventName = _event?.medicineNameSnapshot.trim() ?? '';
    if (eventName.isNotEmpty) return eventName;

    final medicineName = _medicine?.name.trim() ?? '';
    if (medicineName.isNotEmpty) return medicineName;

    return 'Medicine';
  }

  String _resolvedDoseLabel() {
    final eventDose = _event?.doseLabelSnapshot.trim() ?? '';
    if (eventDose.isNotEmpty) return eventDose;

    final medicineDose = _medicine?.doseLabel.trim() ?? '';
    if (medicineDose.isNotEmpty) return medicineDose;

    return '';
  }

  String _resolvedInstructions() {
    final eventInstructions = _event?.instructionsSnapshot.trim() ?? '';
    if (eventInstructions.isNotEmpty) return eventInstructions;

    final medicineInstructions = _medicine?.instructions.trim() ?? '';
    if (medicineInstructions.isNotEmpty) return medicineInstructions;

    return '';
  }

  String _resolvedLanguageLabel() {
    final eventLanguage = _event?.announcementLanguageSnapshot.trim() ?? '';
    if (eventLanguage.isNotEmpty) return eventLanguage;

    final medicineLanguage = _medicine?.announcementLanguage?.trim() ?? '';
    if (medicineLanguage.isNotEmpty) return medicineLanguage;

    return _medicine?.languageMode.trim().isNotEmpty == true
        ? _medicine!.languageMode.trim()
        : 'english';
  }

  String _resolvedQuantityText() {
    final eventQuantity = _event?.quantityPerDoseSnapshot;
    final eventUnit = _event?.quantityUnitSnapshot.trim() ?? '';

    if (eventQuantity != null) {
      final quantityText = eventQuantity == eventQuantity.roundToDouble()
          ? eventQuantity.toInt().toString()
          : eventQuantity.toString();

      return eventUnit.isNotEmpty ? '$quantityText $eventUnit' : quantityText;
    }

    final medicineQuantity = _medicine?.quantityPerDose;
    final medicineUnit = _medicine?.quantityUnit?.trim() ?? '';

    if (medicineQuantity != null) {
      final quantityText = medicineQuantity == medicineQuantity.roundToDouble()
          ? medicineQuantity.toInt().toString()
          : medicineQuantity.toString();

      return medicineUnit.isNotEmpty ? '$quantityText $medicineUnit' : quantityText;
    }

    return '';
  }

  String _resolvedSlotText() {
    final slot = _event?.slotLabelSnapshot.trim() ?? '';
    if (slot.isEmpty) return '';

    switch (slot) {
      case 'morning':
        return 'Morning';
      case 'afternoon':
        return 'Afternoon';
      case 'night':
        return 'Night';
      case 'custom':
        return 'Custom';
      default:
        return slot[0].toUpperCase() + slot.substring(1);
    }
  }

  DateTime? _effectiveTime() {
    return _event?.snoozeUntil ?? _event?.scheduledDateTime;
  }

  bool _isOverdue() {
    final effectiveTime = _effectiveTime();
    if (effectiveTime == null) return false;
    return DateTime.now().isAfter(effectiveTime);
  }

  String _profile() {
    final raw = _settings?.alarmStrengthProfile.trim().toLowerCase() ?? 'standard';
    switch (raw) {
      case 'gentle':
        return 'gentle';
      case 'strong':
        return 'strong';
      case 'normal':
        return 'gentle';
      case 'very_strong':
        return 'strong';
      case 'standard':
      default:
        return 'standard';
    }
  }

  String _headlineText() {
    final status = _event?.status ?? 'pending';
    final profile = _profile();

    if (status == 'snoozed') {
      return profile == 'strong'
          ? 'SNOOZED — RESPONSE NEEDED SOON'
          : 'REMINDER SNOOZED';
    }

    if (_isOverdue()) {
      return profile == 'gentle'
          ? 'DOSE OVERDUE'
          : 'MISSED DOSE — ACT NOW';
    }

    if (status == 'ringing') {
      switch (profile) {
        case 'gentle':
          return 'MEDICINE REMINDER';
        case 'strong':
          return 'TIME TO TAKE MEDICINE NOW';
        case 'standard':
        default:
          return 'TIME TO TAKE MEDICINE';
      }
    }

    return 'MEDICINE REMINDER';
  }

  String _subtitleText() {
    final status = _event?.status ?? 'pending';
    final language = _resolvedLanguageLabel().toLowerCase();
    final profile = _profile();

    if (language == 'urdu') {
      if (status == 'snoozed') {
        return profile == 'strong'
            ? 'یاددہانی ملتوی ہے، جلد جواب دیں'
            : 'یاددہانی ملتوی کی گئی ہے';
      }
      if (_isOverdue()) {
        return profile == 'gentle'
            ? 'خوراک وقت سے پیچھے ہے'
            : 'خوراک رہ گئی ہے — ابھی لے لیں';
      }
      return profile == 'gentle'
          ? 'اپنی دوا کی یاددہانی'
          : 'دوائی لینے کا وقت';
    }

    if (status == 'snoozed') {
      return profile == 'strong'
          ? 'Reminder snoozed, response needed soon'
          : 'Reminder has been snoozed';
    }
    if (_isOverdue()) {
      return profile == 'gentle'
          ? 'Dose is now overdue'
          : 'Dose is overdue — act now';
    }
    return profile == 'gentle'
        ? 'A reminder to take your medicine'
        : 'It is time to take your medicine';
  }

  String _dueText() {
    final effectiveTime = _effectiveTime();
    if (effectiveTime == null) return '';

    final now = DateTime.now();
    final difference = effectiveTime.difference(now);

    if (difference.inSeconds >= 0) {
      final minutes = difference.inMinutes;
      if (minutes < 1) return 'Due now';
      if (minutes < 60) return 'Due in $minutes min';
      final hours = difference.inHours;
      final remainingMinutes = minutes % 60;
      return remainingMinutes == 0
          ? 'Due in $hours hr'
          : 'Due in $hours hr $remainingMinutes min';
    }

    final overdue = now.difference(effectiveTime);
    final minutes = overdue.inMinutes;
    if (minutes < 1) return 'Due now';
    if (minutes < 60) return 'Overdue by $minutes min';
    final hours = overdue.inHours;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0
        ? 'Overdue by $hours hr'
        : 'Overdue by $hours hr $remainingMinutes min';
  }

  Color _accentColor() {
    final status = _event?.status ?? 'pending';
    final profile = _profile();

    if (_isOverdue()) {
      return profile == 'gentle' ? Colors.orange.shade700 : Colors.red.shade800;
    }

    switch (status) {
      case 'ringing':
        if (profile == 'gentle') return Colors.blue.shade700;
        if (profile == 'strong') return Colors.red.shade800;
        return Colors.red.shade700;
      case 'snoozed':
        return Colors.orange.shade700;
      case 'taken':
        return Colors.green.shade700;
      case 'skipped':
        return Colors.grey.shade700;
      case 'missed':
        return Colors.red.shade900;
      default:
        return Colors.blue.shade700;
    }
  }

  String _profileLabel() {
    switch (_profile()) {
      case 'gentle':
        return 'Gentle';
      case 'strong':
        return 'Strong';
      case 'standard':
      default:
        return 'Standard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayTime = _effectiveTime();
    final timeLabel = displayTime == null
        ? '--:--'
        : DateFormat('hh:mm a').format(displayTime);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _ErrorCard(
                            message: _error!,
                            onClose: _closeAlarmScreen,
                          )
                        : _AlarmCard(
                            headline: _headlineText(),
                            subtitle: _subtitleText(),
                            medicineName: _resolvedMedicineName(),
                            doseLabel: _resolvedDoseLabel(),
                            instructions: _resolvedInstructions(),
                            quantityText: _resolvedQuantityText(),
                            languageLabel: _resolvedLanguageLabel(),
                            slotText: _resolvedSlotText(),
                            timeLabel: timeLabel,
                            dueText: _dueText(),
                            status: _event?.status ?? 'pending',
                            busy: _busy,
                            busyLabel: _busyLabel,
                            retryCount: _retryCount,
                            snoozeMinutes:
                                _settings?.defaultSnoozeMinutes ?? 10,
                            accentColor: _accentColor(),
                            profileLabel: _profileLabel(),
                            onTaken: _markTaken,
                            onSnooze: _snoozeDose,
                            onSkip: _skipDose,
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlarmCard extends StatelessWidget {
  final String headline;
  final String subtitle;
  final String medicineName;
  final String doseLabel;
  final String instructions;
  final String quantityText;
  final String languageLabel;
  final String slotText;
  final String timeLabel;
  final String dueText;
  final String status;
  final bool busy;
  final String? busyLabel;
  final int retryCount;
  final int snoozeMinutes;
  final Color accentColor;
  final String profileLabel;
  final VoidCallback onTaken;
  final VoidCallback onSnooze;
  final VoidCallback onSkip;

  const _AlarmCard({
    required this.headline,
    required this.subtitle,
    required this.medicineName,
    required this.doseLabel,
    required this.instructions,
    required this.quantityText,
    required this.languageLabel,
    required this.slotText,
    required this.timeLabel,
    required this.dueText,
    required this.status,
    required this.busy,
    required this.busyLabel,
    required this.retryCount,
    required this.snoozeMinutes,
    required this.accentColor,
    required this.profileLabel,
    required this.onTaken,
    required this.onSnooze,
    required this.onSkip,
  });

  Color _statusSoftColor() {
    return accentColor.withValues(alpha: 0.12);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.45),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            offset: const Offset(0, 10),
            color: accentColor.withValues(alpha: 0.22),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.40),
                ),
              ),
              child: Icon(
                Icons.notifications_active,
                size: 42,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accentColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              medicineName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            if (doseLabel.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                doseLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: _statusSoftColor(),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.28),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    timeLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  if (dueText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      dueText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoBadge(
                  label: status.toUpperCase(),
                  foregroundColor: accentColor,
                  backgroundColor: accentColor.withValues(alpha: 0.12),
                ),
                if (slotText.isNotEmpty)
                  _InfoBadge(
                    label: slotText,
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white10,
                  ),
                _InfoBadge(
                  label: 'Language: $languageLabel',
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white10,
                ),
                _InfoBadge(
                  label: 'Profile: $profileLabel',
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white10,
                ),
              ],
            ),
            if (quantityText.isNotEmpty) ...[
              const SizedBox(height: 16),
              _DetailPanel(
                title: 'Dose Quantity',
                body: quantityText,
              ),
            ],
            if (instructions.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailPanel(
                title: 'Instructions',
                body: instructions,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Alert cycle: ${retryCount + 1}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (busy && busyLabel != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  busyLabel!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: busy ? null : onTaken,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: const Text('TAKE NOW'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: accentColor.withValues(alpha: 0.60)),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: busy ? null : onSnooze,
                icon: const Icon(Icons.snooze),
                label: Text('SNOOZE $snoozeMinutes MIN'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: busy ? null : onSkip,
              icon: const Icon(Icons.close),
              label: const Text('SKIP'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final String title;
  final String body;

  const _DetailPanel({
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const _InfoBadge({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onClose;

  const _ErrorCard({
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                onClose();
              },
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
