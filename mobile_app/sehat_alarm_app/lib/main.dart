import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:sehat_alarm_app/core/theme/app_theme.dart';
import 'package:sehat_alarm_app/screens/alarm/alarm_alert_screen.dart';
import 'package:sehat_alarm_app/screens/home/home_screen.dart';
import 'package:sehat_alarm_app/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final initialPayload = await NotificationService.instance.initialize();
  await NotificationService.instance.requestAndroidPermissions();

  runApp(SehatAlarmApp(initialPayload: initialPayload));
}

class SehatAlarmApp extends StatefulWidget {
  final AlarmNavigationPayload? initialPayload;

  const SehatAlarmApp({
    super.key,
    this.initialPayload,
  });

  @override
  State<SehatAlarmApp> createState() => _SehatAlarmAppState();
}

class _SehatAlarmAppState extends State<SehatAlarmApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AlarmNavigationPayload>? _alarmNavigationSub;
  String? _lastOpenedEventId;

  @override
  void initState() {
    super.initState();

    _alarmNavigationSub =
        NotificationService.instance.alarmNavigationStream.listen(
      _handleAlarmNavigation,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final payload = widget.initialPayload;
      if (payload != null) {
        _handleAlarmNavigation(payload);
      }
    });
  }

  @override
  void dispose() {
    _alarmNavigationSub?.cancel();
    super.dispose();
  }

  void _handleAlarmNavigation(AlarmNavigationPayload payload) {
    if (payload.eventId.isEmpty) return;
    if (_lastOpenedEventId == payload.eventId) return;

    _lastOpenedEventId = payload.eventId;

    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AlarmAlertScreen(payload: payload),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sehat Alarm',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
