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
    final theme = Theme.of(context);

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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primaryContainer,
                        theme.colorScheme.surfaceContainerHighest,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today Log',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDateHeader(),
                        style: const TextStyle(
                          fontSize: 16,
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
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isGenerating
                          ? 'Generating today events. Please wait.'
                          : _isSyncing
                              ? 'Syncing notifications. Please wait.'
                              : 'Refreshing today states. Please wait.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : _generateTodayEvents,
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.playlist_add_check),
                        label: Text(
                          _isGenerating ? 'Generating...' : 'Generate Events',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : _syncTodayReminders,
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.notifications_active),
                        label: Text(
                          _isSyncing ? 'Syncing...' : 'Sync Reminders',
                        ),
                      ),
                    ),
                  ],
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
                            'No events for today yet.\nTap "Generate Events" first.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      );
                    }

                    final groupedEvents = _groupByMedicine(events);

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _TodaySummaryCard(
                          events: events,
                          supportMode: settings?.supportMode ?? 'patient',
                        ),
                        const SizedBox(height: 14),
                        ...groupedEvents.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _MedicineGroupCard(
                              medicineName: entry.key,
                              events: entry.value,
                              defaultSnoozeMinutes:
                                  settings?.defaultSnoozeMinutes ?? 10,
                              missedGraceMinutes:
                                  settings?.maxAlarmDurationMinutes ?? 5,
                              supportMode: settings?.supportMode ?? 'patient',
                            ),
                          ),
                        ),
                      ],
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

class _TodaySummaryCard extends StatelessWidget {
  final List<DoseEventModel> events;
  final String supportMode;

  const _TodaySummaryCard({
    required this.events,
    required this.supportMode,
  });

  int get total => events.length;
  int get taken => events.where((e) => e.status == 'taken').length;
  int get missed => events.where((e) => e.status == 'missed').length;
  int get skipped => events.where((e) => e.status == 'skipped').length;
  int get active => events.where((e) => e.isAlarmActive).length;

  double get adherencePercent {
    if (total == 0) return 0;
    return (taken / total) * 100;
  }

  Color get adherenceColor {
    if (adherencePercent >= 90) return Colors.green;
    if (adherencePercent >= 70) return Colors.orange;
    return Colors.red;
  }

  String get adherenceLabel {
    if (adherencePercent >= 90) return 'Good';
    if (adherencePercent >= 70) return 'Moderate';
    return 'Poor';
  }

  _NudgeData _nudge() {
    final caregiver = supportMode == 'caregiver';

    if (total > 0 && taken == total) {
      return _NudgeData(
        title: caregiver ? 'All doses completed' : 'Excellent work today',
        message: caregiver
            ? 'All scheduled doses were completed today.'
            : 'You completed all scheduled doses today. Keep following the same routine.',
        color: Colors.green,
        icon: Icons.celebration_outlined,
      );
    }

    if (missed > 0) {
      return _NudgeData(
        title: caregiver ? 'Missed doses need review' : 'Some doses were missed',
        message: caregiver
            ? 'Review the missed items and decide the next appropriate action.'
            : 'Review the missed items and try to return to your usual schedule.',
        color: Colors.red,
        icon: Icons.warning_amber_rounded,
      );
    }

    if (active > 0) {
      return _NudgeData(
        title: caregiver ? 'Pending reminders remain' : 'You still have reminders pending',
        message: caregiver
            ? 'There are still active reminders to monitor today.'
            : 'Try to complete the remaining doses on time today.',
        color: Colors.orange,
        icon: Icons.pending_actions_rounded,
      );
    }

    return _NudgeData(
      title: caregiver ? 'Progress is steady' : 'You are making progress',
      message: caregiver
          ? 'Today’s medicine routine is progressing steadily.'
          : 'Keep following your medicine routine one dose at a time.',
      color: Colors.blue,
      icon: Icons.trending_up_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final percentText = adherencePercent.toStringAsFixed(0);
    final nudge = _nudge();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today Summary',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Adherence: $percentText% ($adherenceLabel)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: adherenceColor,
              ),
            ),
            const SizedBox(height: 10),
            _AdherenceBar(
              percent: adherencePercent,
              color: adherenceColor,
            ),
            const SizedBox(height: 12),
            Text(
              'You took $taken out of $total doses today.',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (missed > 0) ...[
              const SizedBox(height: 4),
              Text(
                '$missed dose${missed == 1 ? '' : 's'} missed today.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (active > 0) ...[
              const SizedBox(height: 4),
              Text(
                '$active active reminder${active == 1 ? '' : 's'} remaining.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            _NudgePanel(data: nudge),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SummaryChip(
                  label: 'Total $total',
                  color: Colors.blue,
                ),
                _SummaryChip(
                  label: 'Taken $taken',
                  color: Colors.green,
                ),
                _SummaryChip(
                  label: 'Active $active',
                  color: Colors.orange,
                ),
                _SummaryChip(
                  label: 'Missed $missed',
                  color: Colors.red,
                ),
                _SummaryChip(
                  label: 'Skipped $skipped',
                  color: Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicineGroupCard extends StatelessWidget {
  final String medicineName;
  final List<DoseEventModel> events;
  final int defaultSnoozeMinutes;
  final int missedGraceMinutes;
  final String supportMode;

  const _MedicineGroupCard({
    required this.medicineName,
    required this.events,
    required this.defaultSnoozeMinutes,
    required this.missedGraceMinutes,
    required this.supportMode,
  });

  String _groupDoseLabel() {
    for (final event in events) {
      final label = event.doseLabelSnapshot.trim();
      if (label.isNotEmpty) return label;
    }
    return '';
  }

  int _takenCount() => events.where((e) => e.status == 'taken').length;
  int _missedCount() => events.where((e) => e.status == 'missed').length;
  int _activeCount() => events.where((e) => e.isAlarmActive).length;
  int _skippedCount() => events.where((e) => e.status == 'skipped').length;

  double _adherencePercent() {
    if (events.isEmpty) return 0;
    return (_takenCount() / events.length) * 100;
  }

  Color _adherenceColor() {
    final percent = _adherencePercent();
    if (percent >= 90) return Colors.green;
    if (percent >= 70) return Colors.orange;
    return Colors.red;
  }

  String _adherenceLabel() {
    final percent = _adherencePercent();
    if (percent >= 90) return 'Good';
    if (percent >= 70) return 'Moderate';
    return 'Poor';
  }

  _NudgeData _groupNudge() {
    final caregiver = supportMode == 'caregiver';

    if (events.isNotEmpty && _takenCount() == events.length) {
      return _NudgeData(
        title: caregiver ? 'This medicine is complete today' : 'Well done for this medicine',
        message: caregiver
            ? 'All scheduled doses for this medicine were completed today.'
            : 'All scheduled doses for this medicine were completed today.',
        color: Colors.green,
        icon: Icons.check_circle_outline,
      );
    }

    if (_missedCount() > 0) {
      return _NudgeData(
        title: caregiver ? 'This medicine needs review' : 'This medicine had missed doses',
        message: caregiver
            ? 'Review the missed reminders for this medicine and check the next appropriate step.'
            : 'Review the missed reminders and try to return to the normal routine.',
        color: Colors.red,
        icon: Icons.medication_liquid_rounded,
      );
    }

    if (_activeCount() > 0) {
      return _NudgeData(
        title: caregiver ? 'Pending reminders remain' : 'This medicine still has pending reminders',
        message: caregiver
            ? 'There are still reminders pending for this medicine.'
            : 'Try to complete the remaining scheduled doses on time.',
        color: Colors.orange,
        icon: Icons.alarm_rounded,
      );
    }

    return _NudgeData(
      title: caregiver ? 'Routine is stable' : 'Steady progress',
      message: caregiver
          ? 'This medicine routine is progressing steadily today.'
          : 'Keep following the planned schedule for this medicine.',
      color: Colors.blue,
      icon: Icons.track_changes_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doseLabel = _groupDoseLabel();
    final percent = _adherencePercent();
    final percentText = percent.toStringAsFixed(0);
    final nudge = _groupNudge();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset: const Offset(0, 4),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              medicineName,
              style: const TextStyle(
                fontSize: 24,
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
            const SizedBox(height: 8),
            Text(
              'Adherence: $percentText% (${_adherenceLabel()})',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _adherenceColor(),
              ),
            ),
            const SizedBox(height: 8),
            _AdherenceBar(
              percent: percent,
              color: _adherenceColor(),
            ),
            const SizedBox(height: 10),
            Text(
              'Taken ${_takenCount()} of ${events.length} doses for this medicine.',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _NudgePanel(data: nudge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(
                  label: 'Total ${events.length}',
                  color: Colors.blue,
                ),
                _SummaryChip(
                  label: 'Taken ${_takenCount()}',
                  color: Colors.green,
                ),
                _SummaryChip(
                  label: 'Active ${_activeCount()}',
                  color: Colors.orange,
                ),
                _SummaryChip(
                  label: 'Missed ${_missedCount()}',
                  color: Colors.red,
                ),
                _SummaryChip(
                  label: 'Skipped ${_skippedCount()}',
                  color: Colors.grey,
                ),
              ],
            ),
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
                        supportMode: supportMode,
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
  final String supportMode;

  const _DoseEventTile({
    required this.event,
    required this.defaultSnoozeMinutes,
    required this.missedGraceMinutes,
    required this.supportMode,
  });

  @override
  State<_DoseEventTile> createState() => _DoseEventTileState();
}

class _DoseEventTileState extends State<_DoseEventTile> {
  final DoseEventService _doseEventService = DoseEventService();

  bool _busy = false;

  DateTime? _effectiveTime() {
    return widget.event.snoozeUntil ?? widget.event.scheduledDateTime;
  }

  String _formattedTime() {
    final when = _effectiveTime();
    if (when == null) return '--:--';
    return DateFormat('hh:mm a').format(when);
  }

  bool _isOverdueAndShouldBeMissed() {
    if (!widget.event.isAlarmActive) return false;

    final effectiveTime = _effectiveTime();
    if (effectiveTime == null) return false;

    return DateTime.now().isAfter(
      effectiveTime.add(Duration(minutes: widget.missedGraceMinutes)),
    );
  }

  bool _isMissed() {
    return _displayStatus() == 'missed';
  }

  String _displayStatus() {
    if (_isOverdueAndShouldBeMissed()) {
      return 'missed';
    }
    return widget.event.status;
  }

  Color _statusColor() {
    switch (_displayStatus()) {
      case 'ringing':
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

  Color _softStatusColor() {
    switch (_displayStatus()) {
      case 'ringing':
        return Colors.red.shade50;
      case 'snoozed':
        return Colors.orange.shade50;
      case 'taken':
        return Colors.green.shade50;
      case 'skipped':
        return Colors.grey.shade200;
      case 'missed':
        return Colors.red.shade100;
      default:
        return Colors.blue.shade50;
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

  String _dueText() {
    final effectiveTime = _effectiveTime();
    if (effectiveTime == null) return '';

    final now = DateTime.now();
    final difference = effectiveTime.difference(now);

    if (_displayStatus() == 'taken') {
      return 'Dose completed';
    }

    if (_displayStatus() == 'skipped') {
      return 'Dose skipped';
    }

    if (_displayStatus() == 'missed') {
      final overdue = now.difference(effectiveTime);
      final minutes = overdue.inMinutes;
      if (minutes < 1) return 'Marked missed';
      if (minutes < 60) return 'Overdue by $minutes min';
      final hours = overdue.inHours;
      final remMinutes = minutes % 60;
      return remMinutes == 0
          ? 'Overdue by $hours hr'
          : 'Overdue by $hours hr $remMinutes min';
    }

    if (difference.inSeconds >= 0) {
      final minutes = difference.inMinutes;
      if (minutes < 1) return 'Due now';
      if (minutes < 60) return 'Due in $minutes min';
      final hours = difference.inHours;
      final remMinutes = minutes % 60;
      return remMinutes == 0
          ? 'Due in $hours hr'
          : 'Due in $hours hr $remMinutes min';
    }

    final overdue = now.difference(effectiveTime);
    final minutes = overdue.inMinutes;
    if (minutes < 1) return 'Due now';
    if (minutes < 60) return 'Overdue by $minutes min';
    final hours = overdue.inHours;
    final remMinutes = minutes % 60;
    return remMinutes == 0
        ? 'Overdue by $hours hr'
        : 'Overdue by $hours hr $remMinutes min';
  }

  Widget _missedGuidanceCard() {
    final caregiver = widget.supportMode == 'caregiver';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Missed Dose Guidance',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caregiver
                ? '• Do NOT double the next dose unless the prescribing doctor has advised it.'
                : '• Do NOT double the next dose unless your doctor has advised it.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            caregiver
                ? '• Review the medicine instructions or contact the doctor/pharmacist if the next step is unclear.'
                : '• Check your medicine instructions or consult your doctor/pharmacist if unsure.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            caregiver
                ? '• Mark this reminder as reviewed after checking the situation.'
                : '• Try to maintain your regular schedule to avoid future missed doses.',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
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

  Future<void> _markReviewed() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final existingRemarks = widget.event.remarks.trim();
      final updatedRemarks = existingRemarks.isEmpty
          ? 'reviewed'
          : existingRemarks.toLowerCase().contains('reviewed')
              ? existingRemarks
              : '$existingRemarks | reviewed';

      await _doseEventService.updateRemarks(
        eventId: widget.event.id,
        remarks: updatedRemarks,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missed dose marked as reviewed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as reviewed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  bool _isReviewed() {
    return widget.event.remarks.toLowerCase().contains('reviewed');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slotText = _slotText();
    final quantityText = _quantityText();
    final instructions = _instructionsText();
    final displayStatus = _displayStatus();
    final statusColor = _statusColor();
    final dueText = _dueText();
    final caregiver = widget.supportMode == 'caregiver';

    return Container(
      decoration: BoxDecoration(
        color: _softStatusColor(),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 8,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(18),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
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
                          fontSize: 24,
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          displayStatus.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (_isReviewed())
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.blue.withValues(alpha: 0.28),
                            ),
                          ),
                          child: const Text(
                            'REVIEWED',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (dueText.isNotEmpty)
                    Text(
                      dueText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (_isMissed()) ...[
                    const SizedBox(height: 10),
                    _missedGuidanceCard(),
                  ],
                  if (instructions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        instructions,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _busy ? null : _markTaken,
                        child: _busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Taken'),
                      ),
                      OutlinedButton(
                        onPressed: _busy ? null : _snooze,
                        child: Text('Snooze ${widget.defaultSnoozeMinutes}m'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _skip,
                        child: const Text('Skip'),
                      ),
                      if (_isMissed())
                        TextButton(
                          onPressed: _busy ? null : _markReviewed,
                          child: Text(
                            caregiver ? 'Mark Reviewed' : 'Reviewed',
                          ),
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
}

class _NudgeData {
  final String title;
  final String message;
  final Color color;
  final IconData icon;

  const _NudgeData({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });
}

class _NudgePanel extends StatelessWidget {
  final _NudgeData data;

  const _NudgePanel({
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: data.color.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: data.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: TextStyle(
                    color: data.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _AdherenceBar extends StatelessWidget {
  final double percent;
  final Color color;

  const _AdherenceBar({
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final value = (percent / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: value,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: color,
          backgroundColor: color.withValues(alpha: 0.15),
        ),
        const SizedBox(height: 6),
        Text(
          '${percent.toStringAsFixed(0)}%',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
