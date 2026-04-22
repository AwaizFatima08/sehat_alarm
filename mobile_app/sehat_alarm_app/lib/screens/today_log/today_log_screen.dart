import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sehat_alarm_app/models/dose_event_model.dart';
import 'package:sehat_alarm_app/models/schedule_entry_model.dart';
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

  bool _isGenerating = false;
  bool _isSyncing = false;

  Future<void> _generateTodayEvents() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final allSchedules = await _fetchAllSchedules();

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
    setState(() {
      _isSyncing = true;
    });

    try {
      await NotificationService.instance.requestAndroidPermissions();
      final events = await _doseEventService.fetchTodayEventsOnce();
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

  Future<List<ScheduleEntryModel>> _fetchAllSchedules() async {
    final snapshot = await _scheduleService.scheduleCollection
        .where('is_enabled', isEqualTo: true)
        .get();

    return snapshot.docs
        .map((doc) => ScheduleEntryModel.fromFirestore(doc))
        .toList();
  }

  String _formatDateHeader() {
    return DateFormat('EEEE, d MMMM y').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today Log'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _formatDateHeader(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateTodayEvents,
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
                  onPressed: _isSyncing ? null : _syncTodayReminders,
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
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<DoseEventModel>>(
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

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  separatorBuilder: (context, _) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return _DoseEventCard(event: event);
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

class _DoseEventCard extends StatelessWidget {
  final DoseEventModel event;

  const _DoseEventCard({
    required this.event,
  });

  String _formattedTime() {
    if (event.scheduledDateTime == null) return '--:--';
    return DateFormat('hh:mm a').format(event.scheduledDateTime!);
  }

  Color _statusColor() {
    switch (event.status) {
      case 'taken':
        return Colors.green;
      case 'snoozed':
        return Colors.orange;
      case 'skipped':
        return Colors.grey;
      case 'missed':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final doseEventService = DoseEventService();

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
              _formattedTime(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${event.status}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _statusColor(),
              ),
            ),
            if (event.snoozeUntil != null) ...[
              const SizedBox(height: 6),
              Text(
                'Snoozed until: ${DateFormat('hh:mm a').format(event.snoozeUntil!)}',
                style: const TextStyle(fontSize: 15),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await doseEventService.updateStatus(
                      eventId: event.id,
                      status: 'taken',
                    );
                    await NotificationService.instance
                        .cancelNotificationForEvent(event.id);
                  },
                  child: const Text('Taken'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await doseEventService.snoozeEvent(
                      eventId: event.id,
                    );
                    final updated = await doseEventService.getEventById(event.id);
                    if (updated != null) {
                      await NotificationService.instance
                          .scheduleDoseEventNotification(event: updated);
                    }
                  },
                  child: const Text('Snooze'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await doseEventService.updateStatus(
                      eventId: event.id,
                      status: 'skipped',
                    );
                    await NotificationService.instance
                        .cancelNotificationForEvent(event.id);
                  },
                  child: const Text('Skip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
