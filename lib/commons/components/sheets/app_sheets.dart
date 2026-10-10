import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/ledger.dart' show shortDate;
import 'package:flutter/cupertino.dart' show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInputFormatter;

/// Everything the app asks the user for (confirmations, forms, dates, times) opens as a bottom sheet,
/// never as a centred dialog.

const _sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)));

/// A rounded bottom sheet that rises above the keyboard and stays below the status bar.
DateTime? _lastSheetOpened;

Future<T?> showAppSheet<T>({required BuildContext context, required WidgetBuilder builder}) {
  // a double tap on the button that opens a sheet must not open it twice
  final now = DateTime.now();
  if (_lastSheetOpened != null && now.difference(_lastSheetOpened!) < const Duration(milliseconds: 450)) {
    return Future.value(null);
  }
  _lastSheetOpened = now;
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
    final body = Column(
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
    // once the sheet starts closing, its buttons ignore taps: a second tap cannot save or delete again
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null) return body;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => IgnorePointer(ignoring: animation.status == AnimationStatus.reverse, child: child),
      child: body,
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

/// A form field for sheets: a clear heading above, a filled box with readable text and a visible placeholder.
class SheetField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint, prefix, helper;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final TextCapitalization capitalization;
  final bool autofocus;
  final int minLines, maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;

  const SheetField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.prefix,
    this.helper,
    this.keyboardType,
    this.formatters,
    this.capitalization = TextCapitalization.none,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, double w) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(label,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.dark50)),
        ),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          textCapitalization: capitalization,
          minLines: minLines,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.dark100),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.grey[500]),
            prefixText: prefix,
            prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.dark100),
            helperText: helper,
            helperStyle: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
            counterText: '',
            filled: true,
            fillColor: const Color(0xFFF4F4F8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: border(Colors.transparent, 0),
            enabledBorder: border(Colors.transparent, 0),
            focusedBorder: border(AppColors.violet100, 1.6),
          ),
        ),
      ],
    );
  }
}

/// Two or three big choices in a row; the selected one is filled with its colour.
class SheetChoice extends StatelessWidget {
  final List<(String, Color)> options;
  final int selected;
  final ValueChanged<int> onSelected;
  const SheetChoice({super.key, required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == selected ? options[i].$2 : const Color(0xFFF4F4F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(options[i].$1,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: i == selected ? Colors.white : AppColors.dark50)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
