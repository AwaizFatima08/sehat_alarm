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

    final repeatSeconds =
        _settings?.repeatIntervalSeconds ?? 20;

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
          // Keep alarm screen alive; retry guard should not crash the screen.
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

  @override
  Widget build(BuildContext context) {
    final displayTime = _event?.snoozeUntil ?? _event?.scheduledDateTime;
    final timeLabel = displayTime == null
        ? '--:--'
        : DateFormat('hh:mm a').format(displayTime);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
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
                            medicineName: _resolvedMedicineName(),
                            doseLabel: _resolvedDoseLabel(),
                            instructions: _resolvedInstructions(),
                            quantityText: _resolvedQuantityText(),
                            languageLabel: _resolvedLanguageLabel(),
                            slotText: _resolvedSlotText(),
                            timeLabel: timeLabel,
                            status: _event?.status ?? 'pending',
                            busy: _busy,
                            busyLabel: _busyLabel,
                            retryCount: _retryCount,
                            snoozeMinutes:
                                _settings?.defaultSnoozeMinutes ?? 10,
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
  final String medicineName;
  final String doseLabel;
  final String instructions;
  final String quantityText;
  final String languageLabel;
  final String slotText;
  final String timeLabel;
  final String status;
  final bool busy;
  final String? busyLabel;
  final int retryCount;
  final int snoozeMinutes;
  final VoidCallback onTaken;
  final VoidCallback onSnooze;
  final VoidCallback onSkip;

  const _AlarmCard({
    required this.medicineName,
    required this.doseLabel,
    required this.instructions,
    required this.quantityText,
    required this.languageLabel,
    required this.slotText,
    required this.timeLabel,
    required this.status,
    required this.busy,
    required this.busyLabel,
    required this.retryCount,
    required this.snoozeMinutes,
    required this.onTaken,
    required this.onSnooze,
    required this.onSkip,
  });

  Color _statusColor() {
    switch (status) {
      case 'ringing':
        return Colors.red;
      case 'snoozed':
        return Colors.orange;
      case 'taken':
        return Colors.green;
      case 'skipped':
        return Colors.grey;
      case 'missed':
        return Colors.deepOrange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 14,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_active,
              size: 76,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              medicineName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (doseLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                doseLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (quantityText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Dose quantity: $quantityText',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Scheduled at $timeLabel',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (slotText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                slotText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                Chip(
                  label: Text(
                    status.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: _statusColor().withValues(alpha: 0.14),
                  side: BorderSide(
                    color: _statusColor().withValues(alpha: 0.28),
                  ),
                ),
                Chip(
                  label: Text(
                    'Language: $languageLabel',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Alert cycle: ${retryCount + 1}',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
              ),
            ),
            if (instructions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.grey.shade100,
                ),
                child: Text(
                  instructions,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
            if (busy && busyLabel != null) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  busyLabel!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onTaken,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Taken',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onSnooze,
                icon: const Icon(Icons.snooze),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Snooze $snoozeMinutes Minutes',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: busy ? null : onSkip,
                icon: const Icon(Icons.close),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Skip',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
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
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
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
