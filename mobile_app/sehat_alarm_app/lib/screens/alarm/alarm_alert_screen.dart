import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sehat_alarm_app/models/dose_event_model.dart';
import 'package:sehat_alarm_app/models/medicine_model.dart';
import 'package:sehat_alarm_app/services/alarm_runtime_service.dart';
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

  DoseEventModel? _event;
  MedicineModel? _medicine;

  bool _loading = true;
  bool _busy = false;
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
    _autoRetryTimer?.cancel();
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
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  Future<void> _loadAlarmContext() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AlarmRuntimeService.instance.initialize();

      final event =
          await _doseEventService.getEventById(widget.payload.eventId);

      if (event == null) {
        setState(() {
          _loading = false;
          _error = 'Dose event not found.';
        });
        return;
      }

      final medicine =
          await _medicineService.getMedicineById(event.medicineId);

      setState(() {
        _event = event;
        _medicine = medicine;
        _loading = false;
      });

      await AlarmRuntimeService.instance.startAlarmLoop(
        medicine: medicine,
        scheduledAt: event.snoozeUntil ?? event.scheduledDateTime,
      );

      _startRetryGuard();
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Unable to load alarm details.';
      });
    }
  }

  void _startRetryGuard() {
    _autoRetryTimer?.cancel();
    _retryCount = 0;

    _autoRetryTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) return;
      if (_busy) return;

      final eventId = _event?.id;
      if (eventId == null) return;

      final refreshed = await _doseEventService.getEventById(eventId);
      if (refreshed == null) return;

      final activeStatus =
          refreshed.status == 'pending' || refreshed.status == 'snoozed';

      if (!activeStatus) {
        await AlarmRuntimeService.instance.stopAlarmLoop();
        _autoRetryTimer?.cancel();
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      _retryCount += 1;

      if (_retryCount <= 4) {
        await AlarmRuntimeService.instance.startAlarmLoop(
          medicine: _medicine,
          scheduledAt: refreshed.snoozeUntil ?? refreshed.scheduledDateTime,
        );
      }
    });
  }

  Future<void> _markTaken() async {
    final event = _event;
    if (event == null || _busy) return;

    setState(() => _busy = true);

    try {
      await _doseEventService.updateStatus(
        eventId: event.id,
        status: 'taken',
      );

      await NotificationService.instance.cancelNotificationForEvent(event.id);
      await AlarmRuntimeService.instance.stopAlarmLoop();

      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _skipDose() async {
    final event = _event;
    if (event == null || _busy) return;

    setState(() => _busy = true);

    try {
      await _doseEventService.updateStatus(
        eventId: event.id,
        status: 'skipped',
      );

      await NotificationService.instance.cancelNotificationForEvent(event.id);
      await AlarmRuntimeService.instance.stopAlarmLoop();

      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _snoozeDose() async {
    final event = _event;
    if (event == null || _busy) return;

    setState(() => _busy = true);

    try {
      await _doseEventService.snoozeEvent(
        eventId: event.id,
        minutes: 10,
      );

      final refreshedEvent = await _doseEventService.getEventById(event.id);

      if (refreshedEvent != null) {
        await NotificationService.instance.scheduleDoseEventNotification(
          event: refreshedEvent,
          medicineName: _medicine?.name,
        );
      }

      await AlarmRuntimeService.instance.stopAlarmLoop();

      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _ErrorCard(
                            message: _error!,
                            onClose: () => Navigator.of(context).pop(),
                          )
                        : _AlarmCard(
                            medicineName: _medicine?.name ?? 'Medicine',
                            doseLabel: _medicine?.doseLabel ?? '',
                            instructions: _medicine?.instructions ?? '',
                            timeLabel: timeLabel,
                            status: _event?.status ?? 'pending',
                            busy: _busy,
                            retryCount: _retryCount,
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
  final String timeLabel;
  final String status;
  final bool busy;
  final int retryCount;
  final VoidCallback onTaken;
  final VoidCallback onSnooze;
  final VoidCallback onSkip;

  const _AlarmCard({
    required this.medicineName,
    required this.doseLabel,
    required this.instructions,
    required this.timeLabel,
    required this.status,
    required this.busy,
    required this.retryCount,
    required this.onTaken,
    required this.onSnooze,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 14,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active, size: 76),
            const SizedBox(height: 16),
            Text(
              medicineName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (doseLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                doseLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Scheduled at $timeLabel',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Chip(
              label: Text(
                status.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Alert cycle: ${retryCount + 1}',
              style: const TextStyle(fontSize: 14),
            ),
            if (instructions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade100,
                ),
                child: Text(
                  instructions,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onTaken,
                icon: const Icon(Icons.check_circle),
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
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Snooze 10 Minutes',
                    style: TextStyle(fontSize: 18),
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
  final VoidCallback onClose;

  const _ErrorCard({
    required this.message,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
              onPressed: onClose,
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
