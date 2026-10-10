import 'package:expensetracker/commons/router/app_router.dart';
import 'package:expensetracker/data/ledger.dart';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// ---------- local notification ("alarm") ----------

final _plugin = FlutterLocalNotificationsPlugin();

/// Where the alarm opens: a full-screen "time to upload your statement" page with the Import button.
const alarmRoute = '/alarm-ring';

/// Set when the app was started by tapping the alarm (or by it appearing over the lock screen),
/// so the splash screen can open the alarm page once the user is signed in.
String? launchPayload;

const _kharchaViolet = Color(0xFF7F3DFF);

// The status-bar icon is a native resource. If this build does not have it yet (a hot restart cannot add native
// files), the first notification fails with invalid_icon: fall back to the app icon and try again.
String _icon = 'ic_stat_kharcha';
Future<T> _withIconFallback<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on PlatformException catch (e) {
    if (e.code == 'invalid_icon' && _icon != '@mipmap/ic_launcher') {
      _icon = '@mipmap/ic_launcher';
      return await run();
    }
    rethrow;
  }
}
const _actionImport = 'import';
const _actionSnooze = 'snooze';

// v2 channels: Android keeps a channel's sound and importance fixed once created, so changes need a new id.
NotificationDetails _details(bool loud, {String body = ''}) => NotificationDetails(
      android: AndroidNotificationDetails(
        loud ? 'month_end_alarm_v2' : 'month_end_quiet_v2',
        loud ? 'Month-end alarm' : 'Month-end reminder',
        channelDescription: 'Reminds you to download and import your bank statement',
        icon: _icon,
        color: _kharchaViolet,
        importance: loud ? Importance.max : Importance.defaultImportance,
        priority: loud ? Priority.max : Priority.defaultPriority,
        category: loud ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        // the full-screen page: shows over the lock screen and turns the screen on
        fullScreenIntent: loud,
        playSound: loud,
        // the phone's own alarm tone, at alarm volume, repeating until the user answers
        sound: loud ? const UriAndroidNotificationSound('content://settings/system/alarm_alert') : null,
        audioAttributesUsage: loud ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
        additionalFlags: loud ? Int32List.fromList(<int>[4]) : null, // FLAG_INSISTENT
        enableVibration: true,
        timeoutAfter: loud ? 120000 : null, // stops by itself after 2 minutes
        autoCancel: true,
        styleInformation: BigTextStyleInformation(
          body.isEmpty ? 'Download your statement from your bank app, then import it here.' : body,
          contentTitle: 'Time to upload your statement',
        ),
        actions: const [
          AndroidNotificationAction(_actionImport, 'Import now', showsUserInterface: true),
          AndroidNotificationAction(_actionSnooze, 'Remind in 1 hour', showsUserInterface: true),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentSound: loud,
        interruptionLevel: loud ? InterruptionLevel.timeSensitive : InterruptionLevel.passive,
      ),
    );

Future<void> initReminders() async {
  try {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(
          tz.getLocation(await FlutterTimezone.getLocalTimezone()));
    } catch (_) {} // falls back to UTC; times may be off by the UTC offset
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'), // always exists; each notification sets its own small icon
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.actionId == _actionSnooze) {
          snoozeOneHour();
        } else if (r.actionId == _actionImport) {
          goRouter.push('/import');
        } else {
          final path = r.payload;
          if (path != null) goRouter.push(path);
        }
      },
    );
    // the alarm itself started the app (screen off or app closed): remember where to go
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final response = launch!.notificationResponse;
      launchPayload = response?.actionId == _actionImport ? '/import' : (response?.payload ?? alarmRoute);
    }
  } catch (e) {
    debugPrint('reminder init failed: $e');
  }
}

Future<bool> _askPermission() async {
  try {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? true;
    // Android 12+: exact alarms need their own permission. Without it the alarm
    // still rings, only a few minutes late.
    await android?.requestExactAlarmsPermission();
    await android?.requestFullScreenIntentPermission(); // Android 14: lets the alarm show over the lock screen
    return granted;
  } catch (_) {
    return false;
  }
}

/// Day of [m] the alarm rings on, for the chosen [ReminderState.dayMode].
int _alarmDay(ReminderState r, DateTime m) {
  final lastDay = DateTime(m.year, m.month + 1, 0).day;
  switch (r.dayMode) {
    case 1:
      return 1;
    case 2:
      return r.day > lastDay ? lastDay : r.day;
    default:
      return lastDay;
  }
}

/// Next time the alarm will ring, or null if it is off.
DateTime? nextAlarm(ReminderState r, DateTime now) {
  if (!r.enabled) return null;
  var m = DateTime(now.year, now.month);
  for (var i = 0; i < 26; i++) {
    final at = DateTime(m.year, m.month, _alarmDay(r, m), r.hour, r.minute);
    if (r.rings(m.month) && at.isAfter(now)) return at;
    m = DateTime(m.year, m.month + 1);
  }
  return null;
}

/// The month whose statement the alarm asks for: the month just ended when it rings on the 1st, else the current one.
String statementMonthName(ReminderState r, DateTime at) =>
    r.dayMode == 1 ? monthNames[(at.month + 10) % 12] : monthNames[at.month - 1];

String _body(ReminderState r, DateTime at) {
  // on the 1st the statement to fetch is last month's
  final month = r.dayMode == 1
      ? monthNames[(at.month + 10) % 12]
      : monthNames[at.month - 1];
  return 'Upload your $month bank statement';
}

/// Schedules the next 12 alarms. Rescheduled on every app start, so it keeps rolling forward.
Future<void> scheduleMonthEnd(ReminderState r) async {
  try {
    await _plugin.cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    var m = DateTime(now.year, now.month);
    var id = 0;
    for (var i = 0; i < 60 && id < 12; i++) {
      final at = tz.TZDateTime(
          tz.local, m.year, m.month, _alarmDay(r, m), r.hour, r.minute);
      if (r.rings(m.month) && at.isAfter(now)) {
        Future<void> put(AndroidScheduleMode mode) => _withIconFallback(() => _plugin.zonedSchedule(
              id,
              'Time to upload your statement',
              _body(r, at),
              at,
              _details(r.loud, body: 'Download your ${statementMonthName(r, at)} statement from your bank app, then import it here.'),
              payload: alarmRoute,
              androidScheduleMode: mode,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            ));
        try {
          await put(r.loud
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle);
        } catch (_) {
          // exact alarms not allowed on this phone: fall back to a slightly late one
          await put(AndroidScheduleMode.inexactAllowWhileIdle);
        }
        id++;
      }
      m = DateTime(m.year, m.month + 1);
    }
  } catch (e) {
    debugPrint('schedule failed: $e');
  }
}

/// Fires the alarm right now so the user can see what it looks like.
Future<void> sendTestAlarm(ReminderState r) async {
  try {
    await _askPermission(); // a test needs the permission too, even before the alarm is turned on
    await _withIconFallback(() => _plugin.show(99, 'Time to upload your statement', _body(r, DateTime.now()),
        _details(r.loud,
            body: 'Download your ${statementMonthName(r, DateTime.now())} statement from your bank app, then import it here.'),
        payload: alarmRoute));
  } catch (e) {
    debugPrint('test alarm failed: $e');
  }
}

// ---------- reminder settings + state ----------

/// Silences the alarm that is ringing right now (cancels shown notifications; the coming months stay scheduled).
Future<void> stopRinging() async {
  try {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final active = await android?.getActiveNotifications() ?? const <ActiveNotification>[];
    for (final n in active) {
      if (n.id != null) await _plugin.cancel(n.id!);
    }
  } catch (_) {}
}

/// "Remind in 1 hour": the same alarm once more, in an hour.
Future<void> snoozeOneHour() async {
  try {
    final at = tz.TZDateTime.now(tz.local).add(const Duration(hours: 1));
    await _plugin.cancel(98);
    await _withIconFallback(() => _plugin.zonedSchedule(
          98,
          'Time to upload your statement',
          'Reminder: import your bank statement',
          at,
          _details(true),
          payload: alarmRoute,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        ));
  } catch (e) {
    debugPrint('snooze failed: $e');
  }
}

class ReminderState {
  final bool enabled;
  final int hour, minute;
  final int dayMode; // 0 last day, 1 first day, 2 a chosen day
  final int day; // used when dayMode == 2 (1..28)
  final bool loud; // alarm sound + time-sensitive, instead of a quiet banner
  final int months; // bit 0 = January ... bit 11 = December: the months it rings in
  final String? snoozedOn; // yyyy-mm-dd
  final bool setupDismissed;
  const ReminderState({
    this.enabled = false,
    this.hour = 9,
    this.minute = 0,
    this.dayMode = 0,
    this.day = 28,
    this.loud = true,
    this.months = 4095, // every month
    this.snoozedOn,
    this.setupDismissed = false,
  });

  bool rings(int month) => months & (1 << (month - 1)) != 0;

  ReminderState copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    int? dayMode,
    int? day,
    bool? loud,
    int? months,
    String? snoozedOn,
    bool? setupDismissed,
  }) =>
      ReminderState(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        dayMode: dayMode ?? this.dayMode,
        day: day ?? this.day,
        loud: loud ?? this.loud,
        months: months ?? this.months,
        snoozedOn: snoozedOn ?? this.snoozedOn,
        setupDismissed: setupDismissed ?? this.setupDismissed,
      );
}

String _dayKey(DateTime d) => d.toIso8601String().substring(0, 10);

class ReminderNotifier extends StateNotifier<ReminderState> {
  ReminderNotifier() : super(const ReminderState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = ReminderState(
        enabled: p.getBool('rem_on') ?? false,
        hour: p.getInt('rem_h') ?? 9,
        minute: p.getInt('rem_m') ?? 0,
        dayMode: p.getInt('rem_mode') ?? 0,
        day: p.getInt('rem_day') ?? 28,
        loud: p.getBool('rem_loud') ?? true,
        months: p.getInt('rem_months') ?? 4095,
        snoozedOn: p.getString('rem_snooze'),
        setupDismissed: p.getBool('rem_setup_dismissed') ?? false,
      );
      if (state.enabled) await scheduleMonthEnd(state);
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('rem_on', state.enabled);
      await p.setInt('rem_h', state.hour);
      await p.setInt('rem_m', state.minute);
      await p.setInt('rem_mode', state.dayMode);
      await p.setInt('rem_day', state.day);
      await p.setBool('rem_loud', state.loud);
      await p.setInt('rem_months', state.months);
      await p.setBool('rem_setup_dismissed', state.setupDismissed);
      if (state.snoozedOn != null) await p.setString('rem_snooze', state.snoozedOn!);
    } catch (_) {}
  }

  /// Turns the alarm on. Returns false if notification permission was refused.
  Future<bool> enable({int? hour, int? minute}) async {
    if (!await _askPermission()) return false;
    state = state.copyWith(enabled: true, hour: hour, minute: minute);
    await scheduleMonthEnd(state);
    await _save();
    return true;
  }

  /// Change when/how the alarm rings; reschedules if it is on.
  /// Applies a whole edited alarm at once (the alarm page's Save button).
  /// Returns false when the notification permission was refused.
  Future<bool> apply(ReminderState d) async {
    if (d.enabled) {
      if (!state.enabled && !await _askPermission()) return false;
      state = d;
      await scheduleMonthEnd(state);
    } else {
      try {
        await _plugin.cancelAll();
      } catch (_) {}
      state = d;
    }
    await _save();
    return true;
  }

  Future<void> update({int? hour, int? minute, int? dayMode, int? day, bool? loud}) async {
    state = state.copyWith(
        hour: hour, minute: minute, dayMode: dayMode, day: day, loud: loud);
    if (state.enabled) await scheduleMonthEnd(state);
    await _save();
  }

  Future<void> disable() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
    state = state.copyWith(enabled: false);
    await _save();
  }

  void snoozeToday() {
    state = state.copyWith(snoozedOn: _dayKey(DateTime.now()));
    _save();
  }

  void dismissSetup() {
    state = state.copyWith(setupDismissed: true);
    _save();
  }
}

final reminderProvider =
    StateNotifierProvider<ReminderNotifier, ReminderState>((ref) => ReminderNotifier());

// ---------- what Home should nudge about ----------

enum NudgeKind { due, setup }

class Nudge {
  final NudgeKind kind;
  final String title, sub;
  const Nudge(this.kind, this.title, this.sub);
}

/// Null when there is nothing to show today.
Nudge? nudgeFor(Ledger l, ReminderState r, DateTime today) {
  if (r.snoozedOn == _dayKey(today)) return null;
  if (l.all.isEmpty) {
    return const Nudge(NudgeKind.due, 'Import your first statement',
        'Download it from your bank app, then import it here.');
  }
  final last = l.all.last.date;
  final lastKey = Ledger.keyOf(last);
  final thisKey = Ledger.keyOf(today);
  final prevKey = Ledger.keyOf(DateTime(today.year, today.month - 1));
  final lastDayThis = DateTime(today.year, today.month + 1, 0).day;
  final prevMonthEnd = DateTime(today.year, today.month, 0);

  if (lastKey < prevKey) {
    return Nudge(NudgeKind.due, 'Your statements are behind',
        'Your data ends ${shortDate(last)} ${last.year}. Download the latest statement and import it.');
  }
  if (today.day <= 3 && last.isBefore(prevMonthEnd)) {
    return Nudge(NudgeKind.due, '${monthLabel(prevKey)} statement is ready',
        'Download it from your bank and import it.');
  }
  if (today.day >= lastDayThis - 2 && lastKey < thisKey) {
    return Nudge(NudgeKind.due, 'Month-end reminder',
        'Download your ${monthLabel(thisKey)} statement and import it.');
  }
  if (!r.enabled && !r.setupDismissed) {
    return const Nudge(NudgeKind.setup, 'Never miss a statement',
        'Get an alarm on the last day of every month.');
  }
  return null;
}
