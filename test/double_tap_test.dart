import 'dart:async';

import 'package:expensetracker/commons/components/button/app/solid_button_widget.dart';
import 'package:expensetracker/commons/components/sheets/app_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a button runs its action once for three fast taps, and shows a spinner meanwhile', (t) async {
    var calls = 0;
    final done = Completer<void>(); // the "request" finishes when the test says so
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SolidButtonWidget(
          label: 'Save',
          onPressed: () async {
            calls++;
            await done.future;
          },
        ),
      ),
    ));

    await t.tap(find.text('Save'));
    await t.pump();
    await t.tap(find.byType(CircularProgressIndicator)); // taps 2 and 3, while it is busy
    await t.tap(find.byType(CircularProgressIndicator));
    await t.pump();

    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing); // the label is replaced by the spinner

    done.complete();
    await t.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget); // ready again
    await t.tap(find.text('Save'));
    expect(calls, 2); // and works again afterwards
  });

  testWidgets('a bottom sheet opens once for a double tap, and its button saves once', (t) async {
    var saves = 0;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showAppSheet<void>(
              context: context,
              builder: (sheet) => SheetFrame(
                title: const Text('Form'),
                actions: [
                  TextButton(
                    onPressed: () {
                      saves++;
                      Navigator.pop(sheet);
                    },
                    child: const Text('Save form'),
                  ),
                ],
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await t.tap(find.text('Open'));
    await t.tap(find.text('Open')); // double tap: must not open a second sheet
    await t.pumpAndSettle();
    expect(find.text('Form'), findsOneWidget);

    await t.tap(find.text('Save form'));
    await t.pump(const Duration(milliseconds: 60)); // the sheet is sliding away
    await t.tap(find.text('Save form'), warnIfMissed: false); // a second tap during the exit animation
    await t.pumpAndSettle();
    expect(saves, 1);
    expect(find.text('Form'), findsNothing);
  });
}
