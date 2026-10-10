import 'dart:async';

import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/components/sheets/app_sheets.dart';
import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/commons/constants/app_info.dart';
import 'package:expensetracker/data/analysis.dart' show weekdayNames;
import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/data/reminder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Settings screen for the monthly "upload your bank statement" alarm.
/// Changes are edited here freely and only take effect when the user presses Save.
class AlarmPage extends ConsumerStatefulWidget {
  const AlarmPage({super.key});

  @override
  ConsumerState<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends ConsumerState<AlarmPage> {
  late ReminderState _d = ref.read(reminderProvider); // the alarm as edited on screen
  bool _saving = false;
  late final Timer _tick = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {})); // keeps the "in 5 min" banner moving

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  bool _same(ReminderState a, ReminderState b) =>
      a.enabled == b.enabled &&
      a.hour == b.hour &&
      a.minute == b.minute &&
      a.dayMode == b.dayMode &&
      a.day == b.day &&
      a.loud == b.loud &&
      a.months == b.months;

  bool get _dirty => !_same(_d, ref.read(reminderProvider));

  void _edit({bool? enabled, int? hour, int? minute, int? dayMode, int? day, bool? loud, int? months}) {
    setState(() => _d = _d.copyWith(
        enabled: enabled, hour: hour, minute: minute, dayMode: dayMode, day: day, loud: loud, months: months));
  }

  Future<void> _save(DateTime now) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(reminderProvider.notifier).apply(_d);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Allow notifications for this app in the phone Settings, then save again')));
      return;
    }
    final next = nextAlarm(_d, now);
    messenger.showSnackBar(SnackBar(
        content: Text(next == null
            ? 'Alarm turned off'
            : 'Alarm saved. Next: ${weekdayNames[next.weekday - 1]}, ${shortDate(next)}, '
                '${TimeOfDay(hour: _d.hour, minute: _d.minute).format(context)}')));
    setState(() {}); // the Save button now reads "Saved"
  }

  /// Leaving with unsaved changes asks first.
  Future<void> _leave() async {
    if (_dirty) {
      final discard = await confirmSheet(context,
          title: 'Discard changes?',
          message: 'You changed the alarm but did not save it.',
          confirmLabel: 'Discard',
          destructive: true);
      if (!discard || !mounted) return;
    }
    if (mounted) context.canPop() ? context.pop() : context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    // the alarm is loaded from storage a moment after the app starts: follow it until the user edits
    ref.listen<ReminderState>(reminderProvider, (prev, next) {
      if (prev != null && _same(_d, prev)) setState(() => _d = next);
    });
    _tick; // starts the timer
    final r = _d;
    final now = DateTime.now();
    final next = nextAlarm(r, now);
    final time = TimeOfDay(hour: r.hour, minute: r.minute).format(context);
    final dirty = _dirty;

    void toggle(bool on) => _edit(enabled: on);

    Future<void> pickTime() async {
      final t = await pickTimeSheet(context, initial: TimeOfDay(hour: r.hour, minute: r.minute));
      if (t != null) _edit(hour: t.hour, minute: t.minute);
    }

    final every = r.months == 4095 ? 'every month' : 'the months you picked';
    String when() => switch (r.dayMode) {
          0 => 'the last day of $every',
          1 => 'the 1st of $every',
          _ => 'day ${r.day} of $every',
        };

    String nextText() {
      if (next == null) return 'Alarm is off';
      final days = DateTime(next.year, next.month, next.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
      final mins = next.difference(now).inMinutes + 1;
      final away = days == 0
          ? (mins < 60 ? 'in $mins min' : 'in ${mins ~/ 60} h ${mins % 60} min')
          : days == 1
              ? 'tomorrow'
              : 'in $days days';
      return '${weekdayNames[next.weekday - 1]}, ${shortDate(next)}  ·  $away';
    }

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 26, bottom: 10),
          child: Text(t,
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
        );

    /// One-row segmented control, so options never wrap onto a second line.
    Widget segmented(List<String> labels, int sel, ValueChanged<int> onSel) =>
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => onSel(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == sel ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: i == sel
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(labels[i],
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: i == sel
                                  ? AppColors.violet100
                                  : AppColors.dark25)),
                    ),
                  ),
                ),
            ],
          ),
        );

    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      // the Save button stays in view while the page scrolls
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SolidButtonWidget(
            label: _saving
                ? 'Saving...'
                : dirty
                    ? (r.enabled ? 'Save alarm' : 'Save (alarm off)')
                    : 'Saved',
            onPressed: _saving || !dirty ? null : () => _save(now),
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.dark100,
        centerTitle: true,
        title: const Text('Month-end alarm',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: BackButton(onPressed: _leave),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // hero: the time is the main control, like a clock alarm
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.violet80, AppColors.violet100],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.violet100.withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: pickTime,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(time,
                                style: TextStyle(
                                    color: Colors.white
                                        .withOpacity(r.enabled ? 1 : 0.7),
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(width: 8),
                            const Icon(Icons.edit_outlined,
                                color: Colors.white70, size: 18),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(nextText(),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                Switch(
                  value: r.enabled,
                  onChanged: toggle,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.white38,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 4),
            child: Text(
              'Rings on ${when()}, asking you to upload your bank statement.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),

          label('REPEATS'),
          segmented(['Last day', '1st of month', 'Pick a day'], r.dayMode,
              (i) => _edit(dayMode: i)),
          if (r.dayMode == 1)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 4),
              child: Text(
                  "On the 1st it asks for last month's statement, which is ready by then.",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ),
          if (r.dayMode == 2)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: r.day > 1 ? () => _edit(day: r.day - 1) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 150,
                    child: Column(
                      children: [
                        Text('${r.day}',
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.w800)),
                        Text('of every month',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: r.day < 28 ? () => _edit(day: r.day + 1) : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),

          label('MONTHS'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var m = 1; m <= 12; m++)
                FilterChip(
                  label: Text(monthNames[m - 1].substring(0, 3)),
                  selected: r.rings(m),
                  showCheckmark: false,
                  selectedColor: AppColors.violet20,
                  labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: r.rings(m) ? AppColors.violet100 : AppColors.dark25),
                  onSelected: (on) {
                    final bit = 1 << (m - 1);
                    final next = on ? r.months | bit : r.months & ~bit;
                    if (next != 0) _edit(months: next); // at least one month stays on
                  },
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: r.months == 4095 ? null : () => _edit(months: 4095),
              child: const Text('Every month'),
            ),
          ),

          label('STYLE'),
          segmented(['Alarm  (sound)', 'Quiet  (banner)'], r.loud ? 0 : 1,
              (i) => _edit(loud: i == 0)),
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 4),
            child: Text(
              r.loud
                  ? 'Plays a sound and shows on the lock screen.'
                  : 'A silent banner, no sound.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),

          label('PREVIEW'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.light20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.violet100,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      size: 22, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(appName,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600)),
                          Text('now',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text('Statement time',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                          'Upload your ${monthNames[(next ?? now).month - 1]} bank statement',
                          style: TextStyle(color: Colors.grey[800])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text('Tapping it opens the import screen.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => sendTestAlarm(r),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Send a test alarm now'),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
