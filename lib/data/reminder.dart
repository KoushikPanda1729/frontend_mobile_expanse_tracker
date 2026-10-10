import 'package:expensetracker/commons/router/app_router.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// ---------- local notification ("alarm") ----------

final _plugin = FlutterLocalNotificationsPlugin();

NotificationDetails _details(bool loud) => NotificationDetails(
      android: AndroidNotificationDetails(
        loud ? 'month_end_alarm' : 'month_end_quiet',
        loud ? 'Month-end alarm' : 'Month-end reminder',
        importance: loud ? Importance.max : Importance.defaultImportance,
        priority: loud ? Priority.max : Priority.defaultPriority,
        category: loud ? AndroidNotificationCategory.alarm : null,
        fullScreenIntent: loud,
        playSound: loud,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: loud,
        interruptionLevel:
            loud ? InterruptionLevel.timeSensitive : InterruptionLevel.passive,
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
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final path = r.payload;
        if (path != null) goRouter.push(path);
      },
    );
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
  for (var i = 0; i < 14; i++) {
    final at = DateTime(m.year, m.month, _alarmDay(r, m), r.hour, r.minute);
    if (at.isAfter(now)) return at;
    m = DateTime(m.year, m.month + 1);
  }
  return null;
}

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
    while (id < 12) {
      final at = tz.TZDateTime(
          tz.local, m.year, m.month, _alarmDay(r, m), r.hour, r.minute);
      if (at.isAfter(now)) {
        Future<void> put(AndroidScheduleMode mode) => _plugin.zonedSchedule(
              id,
              'Statement time',
              _body(r, at),
              at,
              _details(r.loud),
              payload: '/import',
              androidScheduleMode: mode,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
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
    await _plugin.show(99, 'Statement time', _body(r, DateTime.now()),
        _details(r.loud),
        payload: '/import');
  } catch (e) {
    debugPrint('test alarm failed: $e');
  }
}

// ---------- reminder settings + state ----------

class ReminderState {
  final bool enabled;
  final int hour, minute;
  final int dayMode; // 0 last day, 1 first day, 2 a chosen day
  final int day; // used when dayMode == 2 (1..28)
  final bool loud; // alarm sound + time-sensitive, instead of a quiet banner
  final String? snoozedOn; // yyyy-mm-dd
  final bool setupDismissed;
  const ReminderState({
    this.enabled = false,
    this.hour = 9,
    this.minute = 0,
    this.dayMode = 0,
    this.day = 28,
    this.loud = true,
    this.snoozedOn,
    this.setupDismissed = false,
  });

  ReminderState copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    int? dayMode,
    int? day,
    bool? loud,
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
