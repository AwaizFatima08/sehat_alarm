import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sehat_alarm_app/models/app_settings_model.dart';
import 'package:sehat_alarm_app/models/dose_event_model.dart';
import 'package:sehat_alarm_app/services/app_settings_service.dart';
import 'package:sehat_alarm_app/services/dose_event_service.dart';
import 'package:sehat_alarm_app/services/notification_service.dart';
import 'package:sehat_alarm_app/services/schedule_service.dart';

class TodayLogScreen extends StatefulWidget {
  const TodayLogScreen({super.key});

  @override
  State<TodayLogScreen> createState() => _TodayLogScreenState();
}

class _TodayLogScreenState extends State<TodayLogScreen> {
  final DoseEventService _doseEventService = DoseEventService();
  final ScheduleService _scheduleService = ScheduleService();
  final AppSettingsService _appSettingsService = AppSettingsService();

  bool _isGenerating = false;
  bool _isSyncing = false;
  bool _isRefreshingStates = false;

  Future<void> _generateTodayEvents() async {
    if (_isGenerating || _isSyncing || _isRefreshingStates) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final allSchedules = await _scheduleService.fetchEnabledSchedules();

      await _doseEventService.generateTodayEvents(
        schedules: allSchedules,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Today events generated successfully')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate events: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _syncTodayReminders() async {
    if (_isGenerating || _isSyncing || _isRefreshingStates) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      await NotificationService.instance.requestAndroidPermissions();

      final settings = await _appSettingsService.getSettings();
      final events = await _doseEventService.refreshTodayEventStates(
        graceMinutes: settings.maxAlarmDurationMinutes,
      );

      await NotificationService.instance.syncNotificationsForEvents(events);

      final pending =
          await NotificationService.instance.getPendingNotifications();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Today reminders synced. Pending notifications: ${pending.length}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sync reminders: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _refreshTodayStates() async {
    if (_isGenerating || _isSyncing || _isRefreshingStates) return;

    setState(() {
      _isRefreshingStates = true;
    });

    try {
      final settings = await _appSettingsService.getSettings();
      final refreshed = await _doseEventService.refreshTodayEventStates(
        graceMinutes: settings.maxAlarmDurationMinutes,
      );

      if (!mounted) return;

      final missedCount =
          refreshed.where((event) => event.status == 'missed').length;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Today event states refreshed. Missed reminders now: $missedCount',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh today states: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingStates = false;
        });
      }
    }
  }

  String _formatDateHeader() {
    return DateFormat('EEEE, d MMMM y').format(DateTime.now());
  }

  Map<String, List<DoseEventModel>> _groupByMedicine(
    List<DoseEventModel> events,
  ) {
    final grouped = <String, List<DoseEventModel>>{};

    for (final event in events) {
      final medicineName = _medicineNameFor(event);
      grouped.putIfAbsent(medicineName, () => []).add(event);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return {
      for (final key in sortedKeys) key: (grouped[key]!..sort(_compareEvents)),
    };
  }

  int _compareEvents(DoseEventModel a, DoseEventModel b) {
    final aTime =
        (a.snoozeUntil ?? a.scheduledDateTime)?.millisecondsSinceEpoch ?? 0;
    final bTime =
        (b.snoozeUntil ?? b.scheduledDateTime)?.millisecondsSinceEpoch ?? 0;
    return aTime.compareTo(bTime);
  }

  static String _medicineNameFor(DoseEventModel event) {
    final name = event.medicineNameSnapshot.trim();
    return name.isNotEmpty ? name : 'Medicine';
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isGenerating || _isSyncing || _isRefreshingStates;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today Log'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today Log',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDateHeader(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (busy)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isGenerating
                          ? 'Generating today events. Please wait.'
                          : _isSyncing
                              ? 'Syncing notifications. Please wait.'
                              : 'Refreshing today states. Please wait.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: busy ? null : _generateTodayEvents,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.playlist_add_check),
                  label: Text(
                    _isGenerating ? 'Generating...' : 'Generate Today Events',
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: busy ? null : _syncTodayReminders,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.notifications_active),
                  label: Text(
                    _isSyncing ? 'Syncing...' : 'Sync Today Reminders',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: busy ? null : _refreshTodayStates,
                  icon: _isRefreshingStates
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    _isRefreshingStates
                        ? 'Refreshing...'
                        : 'Refresh Today States',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<AppSettingsModel>(
              future: _appSettingsService.getSettings(),
              builder: (context, settingsSnapshot) {
                final settings = settingsSnapshot.data;

                return StreamBuilder<List<DoseEventModel>>(
                  stream: _doseEventService.getTodayEvents(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Error loading today log:\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final events = snapshot.data ?? [];

                    if (events.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No events for today yet.\nTap "Generate Today Events" first.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      );
                    }

                    final groupedEvents = _groupByMedicine(events);

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: groupedEvents.length,
                      separatorBuilder: (context, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final medicineName = groupedEvents.keys.elementAt(index);
                        final medicineEvents = groupedEvents[medicineName] ?? [];

                        return _MedicineGroupCard(
                          medicineName: medicineName,
                          events: medicineEvents,
                          defaultSnoozeMinutes:
                              settings?.defaultSnoozeMinutes ?? 10,
                          missedGraceMinutes:
                              settings?.maxAlarmDurationMinutes ?? 5,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineGroupCard extends StatelessWidget {
  final String medicineName;
  final List<DoseEventModel> events;
  final int defaultSnoozeMinutes;
  final int missedGraceMinutes;

  const _MedicineGroupCard({
    required this.medicineName,
    required this.events,
    required this.defaultSnoozeMinutes,
    required this.missedGraceMinutes,
  });

  String _groupDoseLabel() {
    for (final event in events) {
      final label = event.doseLabelSnapshot.trim();
      if (label.isNotEmpty) return label;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final doseLabel = _groupDoseLabel();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              medicineName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (doseLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                doseLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Column(
              children: events
                  .map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DoseEventTile(
                        event: event,
                        defaultSnoozeMinutes: defaultSnoozeMinutes,
                        missedGraceMinutes: missedGraceMinutes,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoseEventTile extends StatefulWidget {
  final DoseEventModel event;
  final int defaultSnoozeMinutes;
  final int missedGraceMinutes;

  const _DoseEventTile({
    required this.event,
    required this.defaultSnoozeMinutes,
    required this.missedGraceMinutes,
  });

  @override
  State<_DoseEventTile> createState() => _DoseEventTileState();
}

class _DoseEventTileState extends State<_DoseEventTile> {
  final DoseEventService _doseEventService = DoseEventService();

  bool _busy = false;

  String _formattedTime() {
    final when = widget.event.snoozeUntil ?? widget.event.scheduledDateTime;
    if (when == null) return '--:--';
    return DateFormat('hh:mm a').format(when);
  }

  Color _statusColor() {
    switch (widget.event.status) {
      case 'taken':
        return Colors.green;
      case 'snoozed':
        return Colors.orange;
      case 'skipped':
        return Colors.grey;
      case 'missed':
        return Colors.red;
      case 'ringing':
        return Colors.deepOrange;
      default:
        return Colors.blue;
    }
  }

  String _slotText() {
    final slot = widget.event.slotLabelSnapshot.trim();
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

  String _quantityText() {
    final quantity = widget.event.quantityPerDoseSnapshot;
    final unit = widget.event.quantityUnitSnapshot.trim();

    if (quantity == null) return '';

    final quantityLabel = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();

    return unit.isEmpty ? quantityLabel : '$quantityLabel $unit';
  }

  String _instructionsText() {
    return widget.event.instructionsSnapshot.trim();
  }

  Future<void> _markTaken() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await _doseEventService.updateStatus(
        eventId: widget.event.id,
        status: 'taken',
      );
      await NotificationService.instance
          .cancelNotificationForEvent(widget.event.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as taken: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _snooze() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await _doseEventService.snoozeEvent(
        eventId: widget.event.id,
        minutes: widget.defaultSnoozeMinutes,
      );

      await NotificationService.instance
          .cancelNotificationForEvent(widget.event.id);

      final updated = await _doseEventService.getEventById(widget.event.id);
      if (updated != null) {
        await NotificationService.instance.scheduleDoseEventNotification(
          event: updated,
          medicineName: widget.event.medicineNameSnapshot.trim().isNotEmpty
              ? widget.event.medicineNameSnapshot
              : 'Medicine',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to snooze: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _skip() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await _doseEventService.updateStatus(
        eventId: widget.event.id,
        status: 'skipped',
      );
      await NotificationService.instance
          .cancelNotificationForEvent(widget.event.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to skip dose: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotText = _slotText();
    final quantityText = _quantityText();
    final instructions = _instructionsText();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: widget.event.status == 'ringing'
            ? Border.all(color: Colors.deepOrange, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _formattedTime(),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (slotText.isNotEmpty)
                Chip(
                  label: Text(
                    slotText,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              Chip(
                label: Text(
                  widget.event.status.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _statusColor(),
                  ),
                ),
              ),
            ],
          ),
          if (quantityText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Dose quantity: $quantityText',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (widget.event.snoozeUntil != null) ...[
            const SizedBox(height: 6),
            Text(
              'Snoozed until: ${DateFormat('hh:mm a').format(widget.event.snoozeUntil!)}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              instructions,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: _busy ? null : _markTaken,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Taken'),
              ),
              ElevatedButton(
                onPressed: _busy ? null : _snooze,
                child: Text('Snooze ${widget.defaultSnoozeMinutes}m'),
              ),
              ElevatedButton(
                onPressed: _busy ? null : _skip,
                child: const Text('Skip'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
