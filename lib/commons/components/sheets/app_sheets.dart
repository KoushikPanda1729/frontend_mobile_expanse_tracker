import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/ledger.dart' show shortDate;
import 'package:flutter/cupertino.dart' show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';

/// Everything the app asks the user for (confirmations, forms, dates, times) opens as a bottom sheet,
/// never as a centred dialog.

const _sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)));

/// A rounded bottom sheet that rises above the keyboard and stays below the status bar.
Future<T?> showAppSheet<T>({required BuildContext context, required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: _sheetShape,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: builder(ctx),
    ),
  );
}

/// Handle, title, scrolling content and a row of actions: the shape of every sheet in the app.
class SheetFrame extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  const SheetFrame({super.key, this.title, this.content, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: DefaultTextStyle(
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark100),
              child: title!,
            ),
          ),
        if (content != null)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: content,
            ),
          ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: SafeArea(
              top: false,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ),
          )
        else
          SafeArea(top: false, child: const SizedBox(height: 8)),
      ],
    );
  }
}

/// "Are you sure?" as a bottom sheet. Returns true when the user confirms.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final ok = await showAppSheet<bool>(
    context: context,
    builder: (d) => SheetFrame(
      title: Text(title),
      content: Text(message, style: TextStyle(color: Colors.grey[700], height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(d, true),
          child: Text(confirmLabel,
              style: TextStyle(color: destructive ? AppColors.red100 : AppColors.violet100)),
        ),
      ],
    ),
  );
  return ok == true;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// A calendar in a bottom sheet. Returns the picked day, or null when dismissed.
Future<DateTime?> pickDateSheet(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String title = 'Select date',
}) {
  var picked = _day(initial.isBefore(first) ? first : initial.isAfter(last) ? last : initial);
  return showAppSheet<DateTime>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (_, setS) => SheetFrame(
        title: Row(
          children: [
            Expanded(child: Text(title)),
            Text('${shortDate(picked)} ${picked.year}',
                style: const TextStyle(fontSize: 14, color: AppColors.violet100)),
          ],
        ),
        content: CalendarDatePicker(
          initialDate: picked,
          firstDate: first,
          lastDate: last,
          onDateChanged: (v) => setS(() => picked = _day(v)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.violet100),
            onPressed: () => Navigator.pop(d, picked),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}

/// A from/to date range in a bottom sheet (two calendars, one at a time).
Future<DateTimeRange?> pickRangeSheet(
  BuildContext context, {
  required DateTimeRange initial,
  required DateTime first,
  required DateTime last,
}) {
  var from = _day(initial.start.isBefore(first) ? first : initial.start);
  var to = _day(initial.end.isAfter(last) ? last : initial.end);
  var editingFrom = true;
  return showAppSheet<DateTimeRange>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (_, setS) {
        Widget tab(String label, DateTime v, bool on) => Expanded(
              child: GestureDetector(
                onTap: () => setS(() => editingFrom = label == 'From'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: on ? AppColors.violet20 : Colors.grey.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: on ? AppColors.violet100 : Colors.transparent),
                  ),
                  child: Column(
                    children: [
                      Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 2),
                      Text('${shortDate(v)} ${v.year}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            );
        return SheetFrame(
          title: const Text('Select dates'),
          content: Column(
            children: [
              Row(children: [tab('From', from, editingFrom), const SizedBox(width: 10), tab('To', to, !editingFrom)]),
              const SizedBox(height: 4),
              CalendarDatePicker(
                // a new key makes the calendar jump to the date of the tab in use
                key: ValueKey(editingFrom),
                initialDate: editingFrom ? from : to,
                firstDate: first,
                lastDate: last,
                onDateChanged: (v) => setS(() {
                  if (editingFrom) {
                    from = _day(v);
                    if (to.isBefore(from)) to = from;
                    editingFrom = false; // next, pick the end
                  } else {
                    to = _day(v);
                    if (to.isBefore(from)) from = to;
                  }
                }),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.violet100),
              onPressed: () => Navigator.pop(d, DateTimeRange(start: from, end: to)),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    ),
  );
}

/// A time wheel in a bottom sheet.
Future<TimeOfDay?> pickTimeSheet(BuildContext context, {required TimeOfDay initial}) {
  var picked = initial;
  return showAppSheet<TimeOfDay>(
    context: context,
    builder: (d) => SheetFrame(
      title: const Text('Select time'),
      content: SizedBox(
        height: 190,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          initialDateTime: DateTime(2000, 1, 1, initial.hour, initial.minute),
          onDateTimeChanged: (v) => picked = TimeOfDay(hour: v.hour, minute: v.minute),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.violet100),
          onPressed: () => Navigator.pop(d, picked),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
