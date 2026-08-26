import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:mirror_logic/infrastructure/notifications/notification_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

typedef NotificationTapCallback = void Function(String? payload);

/// Fully offline local notifications (OS AlarmManager / iOS). No Dart Timer.
///
/// Android constraints this code respects:
/// - Multiple simultaneous [AndroidScheduleMode.alarmClock] alarms are often
///   collapsed to one by the OS — never queue a burst of alarmClocks.
/// - [AndroidScheduleMode.exactAllowWhileIdle] is rate-limited (~1 / 9 min)
///   while idle — fine for daily production gaps, wrong for 1-minute tests.
/// - 1-minute QA uses a **single repeating** alarm that the plugin re-arms
///   inside [ScheduledNotificationReceiver] even when the app is killed.
class LocalNotificationService {
  LocalNotificationService({
    NotificationConfig config = const NotificationConfig(),
    FlutterLocalNotificationsPlugin? plugin,
    this.onTap,
  }) : _config = config,
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _fingerprintKey = 'local_notification_fingerprint_v4';
  static const _testUntilKey = 'local_notification_test_until_ms';
  static const _testPeriodicId = 9000;
  static const _testMessageIndexKey = 'local_notification_test_msg_index';

  final NotificationConfig _config;
  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationTapCallback? onTap;

  bool _initialized = false;

  bool get isTestMode => _config.testEveryMinute;

  Future<void> init() async {
    if (!_config.enabled || _initialized) return;
    try {
      tz_data.initializeTimeZones();
      await _setLocalTimezone();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (response) {
          onTap?.call(response.payload);
        },
      );

      await _android?.createNotificationChannel(
        AndroidNotificationChannel(
          _config.androidChannelId,
          _config.androidChannelName,
          description: 'Mirror Logic reminders',
          importance: Importance.high,
        ),
      );

      _initialized = true;
    } catch (error, stack) {
      debugPrint('LocalNotificationService.init failed: $error\n$stack');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> _setLocalTimezone() async {
    try {
      final name = await _localTimezoneName();
      if (tz.timeZoneDatabase.locations.containsKey(name)) {
        tz.setLocalLocation(tz.getLocation(name));
        debugPrint('Notifications timezone: $name');
        return;
      }
      debugPrint('Notifications unknown TZ "$name", trying offsets');
    } catch (error) {
      debugPrint('Notifications TZ lookup failed: $error');
    }
    try {
      // Last resort: device offset as a fixed location name often fails;
      // UTC keeps relative schedules correct.
      tz.setLocalLocation(tz.UTC);
    } catch (_) {}
  }

  Future<bool> requestPermission() async {
    try {
      final android = _android;
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final androidOk = await android?.requestNotificationsPermission() ?? true;
      await android?.requestExactAlarmsPermission();
      final canExact = await android?.canScheduleExactNotifications() ?? true;
      debugPrint('Notifications exact alarms allowed=$canExact');
      if (!canExact) {
        debugPrint(
          'Notifications: open Alarms & reminders for this app if delivery fails',
        );
      }
      final iosOk =
          await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          true;
      return androidOk && iosOk;
    } catch (error, stack) {
      debugPrint('Notification permission failed: $error\n$stack');
      return false;
    }
  }

  /// Call after the first frame — needs an Activity for the permission sheet.
  Future<int> scheduleNotifications() async {
    if (!_config.enabled) return 0;
    await init();
    if (!_initialized) {
      debugPrint('Notifications: init failed, skip schedule');
      return 0;
    }

    final allowed = await requestPermission();
    if (!allowed) {
      debugPrint('Notifications: permission denied');
      return 0;
    }

    try {
      final messages = await _loadMessages();
      if (messages.isEmpty) {
        debugPrint('Notifications: JSON empty');
        return 0;
      }

      final prefs = await SharedPreferences.getInstance();
      await _stopExpiredTestPeriodic(prefs);

      final fingerprint = await _fingerprint(messages);
      final pending = await _plugin.pendingNotificationRequests();

      if (prefs.getString(_fingerprintKey) == fingerprint &&
          pending.isNotEmpty) {
        debugPrint(
          'Notifications: keeping ${pending.length} pending '
          '(ids=${pending.map((p) => p.id).join(",")})',
        );
        return pending.length;
      }

      await _plugin.cancelAll();
      final count = await _scheduleUpcoming(messages, prefs);
      await prefs.setString(_fingerprintKey, fingerprint);

      final after = await _plugin.pendingNotificationRequests();
      debugPrint(
        'Notifications: scheduled=$count pending=${after.length} '
        'ids=${after.map((p) => p.id).toList()} '
        'test=${_config.testEveryMinute}',
      );
      return count;
    } catch (error, stack) {
      debugPrint('scheduleNotifications failed: $error\n$stack');
      return 0;
    }
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fingerprintKey);
      await prefs.remove(_testUntilKey);
      await prefs.remove(_testMessageIndexKey);
    } catch (error, stack) {
      debugPrint('cancelAll notifications failed: $error\n$stack');
    }
  }

  Future<void> _stopExpiredTestPeriodic(SharedPreferences prefs) async {
    final until = prefs.getInt(_testUntilKey);
    if (until == null) return;
    if (DateTime.now().millisecondsSinceEpoch < until) return;
    await _plugin.cancel(id: _testPeriodicId);
    await prefs.remove(_testUntilKey);
    await prefs.remove(_testMessageIndexKey);
    debugPrint('Notifications: test periodic window ended, cancelled');
  }

  Future<List<NotificationMessage>> _loadMessages() async {
    final raw = await rootBundle.loadString(_config.assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final list = decoded['notifications'] as List<dynamic>? ?? const [];
    return list
        .whereType<Map>()
        .map((m) => NotificationMessage.fromJson(Map<String, dynamic>.from(m)))
        .where((m) => m.id.isNotEmpty && m.title.isNotEmpty)
        .toList();
  }

  Future<int> _scheduleUpcoming(
    List<NotificationMessage> messages,
    SharedPreferences prefs,
  ) async {
    if (_config.testEveryMinute) {
      return _scheduleTestEveryMinute(messages, prefs);
    }
    return _scheduleProduction(messages);
  }

  /// One notification per day for [daysToSchedule], alternating 17:00 / 21:00.
  /// Gaps are hours → exactAllowWhileIdle is safe.
  Future<int> _scheduleProduction(List<NotificationMessage> messages) async {
    var scheduled = 0;
    final now = tz.TZDateTime.now(tz.local);
    for (var day = 0; day < _config.daysToSchedule; day++) {
      final time = _timeForDay(day);
      if (time == null) continue;
      final fire = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      ).add(Duration(days: day));
      if (!fire.isAfter(now)) continue;
      final message = messages[day % messages.length];
      final ok = await _scheduleOneShot(
        id: day + 1,
        title: message.title,
        body: message.body,
        payload: message.id,
        fire: fire,
        mode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      if (ok) scheduled++;
    }
    return scheduled;
  }

  /// QA: one repeating OS alarm (re-armed by the plugin when the app is dead).
  /// Multiple alarmClock one-shots get collapsed by Android — do not use those.
  Future<int> _scheduleTestEveryMinute(
    List<NotificationMessage> messages,
    SharedPreferences prefs,
  ) async {
    final count = _config.testBurstCount.clamp(1, 60);
    final index = prefs.getInt(_testMessageIndexKey) ?? 0;
    final message = messages[index % messages.length];
    await prefs.setInt(_testMessageIndexKey, index + 1);

    final until = DateTime.now().add(Duration(minutes: count + 1));
    await prefs.setInt(_testUntilKey, until.millisecondsSinceEpoch);

    debugPrint(
      'Notification TEST: repeating every 1 min for ~$count fires '
      '(alarmClock chain, app may be killed). msg="${message.title}"',
    );

    // Immediate confirmation that permission + channel work.
    await _plugin.show(
      id: _testPeriodicId - 1,
      title: '[TEST] ${message.title}',
      body: message.body,
      notificationDetails: _details(),
      payload: message.id,
    );

    await _plugin.periodicallyShowWithDuration(
      id: _testPeriodicId,
      title: '[TEST] ${message.title}',
      body: message.body,
      repeatDurationInterval: const Duration(minutes: 1),
      notificationDetails: _details(),
      // Single next alarm, re-scheduled natively after each fire.
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      payload: message.id,
    );

    return count;
  }

  NotificationDetails _details() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _config.androidChannelId,
        _config.androidChannelName,
        channelDescription: 'Mirror Logic reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        autoCancel: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  Future<bool> _scheduleOneShot({
    required int id,
    required String title,
    required String body,
    required String payload,
    required tz.TZDateTime fire,
    required AndroidScheduleMode mode,
  }) async {
    final details = _details();
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: fire,
        notificationDetails: details,
        androidScheduleMode: mode,
        payload: payload,
      );
      debugPrint('Scheduled #$id "$title" → ${fire.toIso8601String()} ($mode)');
      return true;
    } catch (error) {
      debugPrint('Schedule #$id failed ($mode): $error');
      try {
        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: fire,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exact,
          payload: payload,
        );
        debugPrint('Scheduled #$id via exact fallback');
        return true;
      } catch (error2) {
        debugPrint('exact fallback failed #$id: $error2');
        return false;
      }
    }
  }

  ({int hour, int minute})? _timeForDay(int dayIndex) {
    final times = _config.scheduleTimes;
    if (times.isEmpty) return null;
    final token = _config.rotationMode == NotificationRotationMode.alternate
        ? times[dayIndex % times.length]
        : times[0];
    final parts = token.split(':');
    if (parts.length != 2) return null;
    return (hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<String> _localTimezoneName() async {
    final info = await FlutterTimezone.getLocalTimezone();
    return info.identifier;
  }

  Future<String> _fingerprint(List<NotificationMessage> messages) async {
    final payload = jsonEncode({
      'tz': await _localTimezoneName(),
      'times': _config.scheduleTimes,
      'mode': _config.rotationMode.name,
      'days': _config.daysToSchedule,
      'testEveryMinute': _config.testEveryMinute,
      'testBurstCount': _config.testBurstCount,
      'messages': messages
          .map((m) => {'id': m.id, 'title': m.title, 'body': m.body})
          .toList(),
    });
    return payload;
  }
}
